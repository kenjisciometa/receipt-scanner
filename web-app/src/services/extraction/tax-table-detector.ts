/**
 * Tax Table Detector - Enhanced tax breakdown table analysis
 * 
 * Detects and analyzes tax tables in receipts to extract accurate
 * subtotal, tax total, and tax breakdown information
 */

import { TextLine } from '@/types/ocr';
import {
  TaxTable,
  TableHeader,
  TaxTableRow,
  TableTotals,
  TableSpatialInfo,
  TaxRateMapping,
  ColumnStructure,
  Column,
  RowValidationResults,
  ValidationResult,
  TAX_VALIDATION_TOLERANCES,
  COUNTRY_TAX_RATES,
  BoundingBox,
  ColumnBoundary,
  HeaderContext,
  RateDeclaration
} from '@/types/tax-table';
import { TaxBreakdown } from '@/types/extraction';
import { TaxBreakdownLocalizationService } from './tax-breakdown-localization';
import { MultilingualPatternGenerator } from '@/services/patterns/multilingual-pattern-generator';
import { CentralizedKeywordConfig } from '@/services/keywords/centralized-keyword-config';
import { SupportedLanguage } from '@/services/keywords/language-keywords';

/**
 * Main Tax Table Detection Class
 */
export class TaxTableDetector {
  private readonly mathTolerance = TAX_VALIDATION_TOLERANCES.MATH_TOLERANCE;
  private readonly rateTolerance = TAX_VALIDATION_TOLERANCES.RATE_TOLERANCE;

  /**
   * Detect tax tables in receipt text lines
   */
  async detectTaxTables(textLines: TextLine[]): Promise<TaxTable[]> {
    console.log(`🔍 [TaxTable] Analyzing ${textLines.length} lines for tax tables`);
    
    const tables: TaxTable[] = [];
    
    // 1. Find table headers
    const headerCandidates = this.findTableHeaders(textLines);
    console.log(`📋 [TaxTable] Found ${headerCandidates.length} header candidates`);
    
    // 2. Build tables from each header
    for (const header of headerCandidates) {
      try {
        const table = await this.buildTaxTable(textLines, header);
        if (table && table.rows.length > 0) {
          tables.push(table);
          console.log(`✅ [TaxTable] Built table with ${table.rows.length} rows, confidence: ${table.confidence}`);
        }
      } catch (error) {
        console.warn(`⚠️ [TaxTable] Failed to build table from header at line ${header.index}:`, error);
      }
    }
    
    console.log(`🎯 [TaxTable] Detected ${tables.length} valid tax tables`);
    console.log(`🌐 [TaxTable] Language detected: ${this.detectLanguage(textLines)}`);
    return tables;
  }

  /**
   * Find potential table headers in text lines
   */
  private findTableHeaders(textLines: TextLine[]): TableHeader[] {
    const headers: TableHeader[] = [];
    
    for (let i = 0; i < textLines.length; i++) {
      const line = textLines[i];
      const text = line.text.toLowerCase().trim();
      
      if (this.isTableHeader(text)) {
        const extractedRates = this.extractHeaderRates(line);
        const structure = this.analyzeHeaderStructure(line);
        
        const header: TableHeader = {
          line,
          index: i,
          extractedRates,
          structure,
          confidence: this.calculateHeaderConfidence(text, extractedRates, structure)
        };
        
        headers.push(header);
        console.log(`📊 [Header] Found at line ${i}: "${text}" (confidence: ${header.confidence})`);
      }
    }
    
    return headers;
  }

  /**
   * Check if a text line is a table header using unified pattern generation
   */
  private isTableHeader(text: string): boolean {
    // Detect language for better pattern matching
    const detectedLanguage = this.detectLanguageFromText(text);
    
    try {
      // Use unified pattern generator for table header detection
      const headerPattern = MultilingualPatternGenerator.generateTableHeaderPattern(detectedLanguage);
      if (headerPattern.test(text)) {
        return true;
      }
    } catch (error) {
      console.warn(`⚠️ [TableHeader] Error using unified pattern for language ${detectedLanguage}:`, error);
    }
    
    // Fallback to legacy patterns if unified system fails
    return this.useLegacyHeaderPatterns(text);
  }

  /**
   * Legacy pattern matching for table headers (fallback)
   */
  private useLegacyHeaderPatterns(text: string): boolean {
    const patterns = [
      // Enhanced multilingual patterns
      /(?:alv|vero).*(?:brutto|netto)/i,         // Finnish
      /(?:moms).*(?:brutto|netto)/i,             // Swedish  
      /(?:vat|tax).*(?:gross|net)/i,             // English
      /(?:mwst|steuer|ust).*(?:brutto|netto)/i,  // German
      /(?:tva|taxe).*(?:brut|net)/i,             // French
      /(?:iva|imposta).*(?:lordo|netto)/i,       // Italian
      /(?:iva|impuesto).*(?:bruto|neto)/i,       // Spanish
      
      // Generic column headers
      /(?:tax|vat|moms|alv|mwst|ust|tva|iva).*(?:rate|gross|net|amount|%)/i,
      
      // Column pattern matching  
      /(?:brutto|gross|brut|lordo|bruto).*(?:netto|net).*(?:vero|tax|steuer|ust|moms|tva|iva)/i,
      
      // Reverse pattern
      /(?:vero|tax|steuer|ust|moms|tva|iva).*(?:netto|net).*(?:brutto|gross|brut|lordo|bruto)/i
    ];
    
    return patterns.some(pattern => pattern.test(text));
  }

  /**
   * Simple language detection for text lines
   */
  private detectLanguageFromText(text: string): SupportedLanguage {
    const lowerText = text.toLowerCase();
    
    // Language indicators based on characteristic words
    if (/\b(ust|mwst|steuer|zwischensumme|brutto|netto)\b/.test(lowerText)) return 'de';
    if (/\b(alv|arvonlisävero|yhteensä|brutto|netto)\b/.test(lowerText)) return 'fi';
    if (/\b(moms|mervärdesskatt|totalt|brutto|netto)\b/.test(lowerText)) return 'sv';
    if (/\b(tva|taxe|total|brut|net)\b/.test(lowerText)) return 'fr';
    if (/\b(iva|imposta|totale|lordo|netto)\b/.test(lowerText)) return 'it';
    if (/\b(iva|impuesto|total|bruto|neto)\b/.test(lowerText)) return 'es';
    
    return 'en'; // Default
  }

  /**
   * Extract tax rates from header line
   */
  private extractHeaderRates(headerLine: TextLine): TaxRateMapping[] {
    const rates: TaxRateMapping[] = [];
    const text = headerLine.text;
    
    // Pattern 1: "A 24% B 14%" format
    const categoryRatePattern = /([A-Z])\s*(\d+)\s*%/g;
    let match;
    while ((match = categoryRatePattern.exec(text)) !== null) {
      rates.push({
        rate: parseInt(match[2]),
        category: match[1],
        position: match.index,
        confidence: 0.9
      });
    }
    
    // Pattern 2: "Standard 24% Reduced 14%" format
    const namedRatePattern = /(standard|reduced|normal|regular)\s*(\d+)\s*%/gi;
    while ((match = namedRatePattern.exec(text)) !== null) {
      const category = this.mapNamedRateToCategory(match[1]);
      rates.push({
        rate: parseInt(match[2]),
        category,
        position: match.index,
        confidence: 0.85
      });
    }
    
    // Pattern 3: Standalone rates
    const standaloneRatePattern = /(\d+)\s*%/g;
    while ((match = standaloneRatePattern.exec(text)) !== null) {
      const rate = parseInt(match[1]);
      // Only add if not already captured by other patterns
      const alreadyExists = rates.some(r => r.rate === rate);
      if (!alreadyExists && this.isValidTaxRate(rate)) {
        rates.push({
          rate,
          category: this.inferCategoryFromRate(rate),
          position: match.index,
          confidence: 0.6
        });
      }
    }
    
    return rates;
  }

  /**
   * Analyze header structure to understand column layout
   */
  private analyzeHeaderStructure(headerLine: TextLine): ColumnStructure {
    const text = headerLine.text.toLowerCase();
    const columns: Column[] = [];
    
    // Common column keywords and their types
    const columnKeywords = [
      { pattern: /(?:code|category|cat|type)/i, type: 'code' as const },
      { pattern: /(?:rate|%|percent)/i, type: 'rate' as const },
      { pattern: /(?:brutto|gross|total)/i, type: 'gross' as const },
      { pattern: /(?:netto|net|subtotal)/i, type: 'net' as const },
      { pattern: /(?:vero|tax|steuer|moms|vat|ust)/i, type: 'tax' as const }
    ];
    
    for (const keyword of columnKeywords) {
      const match = text.match(keyword.pattern);
      if (match) {
        columns.push({
          type: keyword.type,
          xRange: [match.index || 0, (match.index || 0) + match[0].length],
          alignment: this.inferAlignment(keyword.type),
          expectedFormat: this.getExpectedFormat(keyword.type)
        });
      }
    }
    
    return {
      columns,
      confidence: columns.length >= 3 ? 0.8 : 0.5 // Need at least 3 columns for good confidence
    };
  }

  /**
   * Build complete tax table from header and data rows
   */
  private async buildTaxTable(textLines: TextLine[], header: TableHeader): Promise<TaxTable | null> {
    // Find data rows that belong to this table
    const dataRows = this.findTableDataRows(textLines, header.index);
    
    if (dataRows.length === 0) {
      console.log(`⚠️ [TaxTable] No data rows found for header at line ${header.index}`);
      return null;
    }
    
    // Extract table rows with tax data
    const tableRows: TaxTableRow[] = [];
    
    for (const dataLine of dataRows) {
      const row = this.extractTableRow(dataLine, header);
      if (row) {
        tableRows.push(row);
      }
    }
    
    if (tableRows.length === 0) {
      console.log(`⚠️ [TaxTable] No valid tax rows extracted`);
      return null;
    }
    
    // Calculate totals
    const totals = this.calculateTableTotals(tableRows);
    
    // Calculate spatial info
    const spatialInfo = this.calculateSpatialInfo(header, dataRows);
    
    // Calculate overall table confidence
    const confidence = this.calculateTableConfidence(header, tableRows, totals);
    
    const table: TaxTable = {
      id: `table_${header.index}_${Date.now()}`,
      header,
      rows: tableRows,
      totals,
      confidence,
      spatialInfo
    };
    
    return table;
  }

  /**
   * Find data rows that belong to the table
   */
  private findTableDataRows(textLines: TextLine[], headerIndex: number): TextLine[] {
    const dataRows: TextLine[] = [];
    const maxLookAhead = 10; // Look up to 10 lines ahead
    
    console.log(`🔍 [FindDataRows] Looking for data rows after header at index ${headerIndex}`);
    
    for (let i = headerIndex + 1; i < Math.min(headerIndex + maxLookAhead, textLines.length); i++) {
      const line = textLines[i];
      const text = line.text.trim();
      
      console.log(`📝 [FindDataRows] Line ${i}: "${text}"`);
      
      if (this.isTableDataRow(line)) {
        dataRows.push(line);
        console.log(`✅ [FindDataRows] Added data row ${dataRows.length}: "${text}"`);
      } else if (this.isTableEnd(line, dataRows.length)) {
        // Stop if we hit a clear table end
        console.log(`🛑 [FindDataRows] Table end detected at line ${i}, stopping search`);
        break;
      } else {
        console.log(`⏭️ [FindDataRows] Skipping non-data line: "${text}"`);
      }
    }
    
    console.log(`📊 [FindDataRows] Found ${dataRows.length} data rows total`);
    return dataRows;
  }

  /**
   * Check if a line is a table data row using unified pattern system
   */
  private isTableDataRow(line: TextLine): boolean {
    const text = line.text.trim();
    
    // Try language-specific patterns first
    const detectedLanguage = this.detectLanguageFromText(text);
    
    try {
      // Generate language-specific data row patterns
      const languagePatterns = this.generateDataRowPatterns(detectedLanguage);
      
      for (const pattern of languagePatterns) {
        if (pattern.test(text)) {
          console.log(`✅ [DataRow] Unified pattern matched for ${detectedLanguage}: "${text}"`);
          return true;
        }
      }
    } catch (error) {
      console.warn(`⚠️ [DataRow] Error using unified patterns for language ${detectedLanguage}:`, error);
    }
    
    // Fallback to comprehensive legacy patterns
    return this.useLegacyDataRowPatterns(text, line);
  }

  /**
   * Generate data row patterns for specific language
   */
  private generateDataRowPatterns(language: SupportedLanguage): RegExp[] {
    const numberFormat = CentralizedKeywordConfig.getNumberFormat(language);
    const patterns = [];
    
    // Build number pattern based on language format
    const decimalSep = numberFormat.decimal === ',' ? ',' : '\\.';
    const numberPattern = `[\\d${decimalSep}]+`;
    
    // Pattern variations for different languages and formats
    const variations = [
      // Standard format: "A 24% 1,97 1,59 0,38"
      `^([A-Z])\\s+(\\d+)\\s*%\\s+(${numberPattern})\\s+(${numberPattern})\\s+(${numberPattern})$`,
      
      // Without letter code: "24% 1,97 1,59 0,38" 
      `^(\\d+)\\s*%\\s+(${numberPattern})\\s+(${numberPattern})\\s+(${numberPattern})$`,
      
      // German format: "20 12,50 2,50 15,00"
      `^(\\d+)\\s+(${numberPattern})\\s+(${numberPattern})\\s+(${numberPattern})$`,
      
      // With tax keywords: "VAT 24% 10.50"
      `^(?:${CentralizedKeywordConfig.getKeywordTexts('tax', language).join('|')})\\s+(\\d+)\\s*%\\s+(${numberPattern})$`,
      
      // Flexible spacing
      `^([A-Z])\\s*(\\d+)\\s*%?\\s+(${numberPattern})\\s+(${numberPattern})\\s+(${numberPattern})$`
    ];
    
    return variations.map(pattern => new RegExp(pattern, 'i'));
  }

  /**
   * Legacy data row pattern matching (comprehensive fallback)
   */
  private useLegacyDataRowPatterns(text: string, line: TextLine): boolean {
    // Enhanced patterns for tax table rows with better number format support
    const patterns = [
      // Pattern 1: With percentage: "A 24 % 1,97 1,59 0,38" or "B 14 % 33,65 29.52 4.13"
      /^([A-Z])\s+(\d+)\s*%\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/,
      
      // Pattern 2: Without percentage: "A 1,97 1,59 0,38"  
      /^([A-Z])\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/,
      
      // Pattern 3: With named rates: "Standard 24% 10,50 8,82 1,68"
      /^(standard|reduced|normal|regular)\s+(\d+)\s*%\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/i,
      
      // Pattern 4: Flexible spacing and percentage: "B  14%  33,65  29.52  4.13"
      /^([A-Z])\s*(\d+)\s*%?\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/,
      
      // Pattern 5: Category with description: "A Standard 24% 10,50 8,82 1,68"
      /^([A-Z])\s+(standard|reduced|normal|regular)?\s*(\d+)\s*%\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/i,
      
      // Pattern 6: German format - just rate and amounts: "20 12,50 2,50 15,00"
      /^(\d+)\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/,
      
      // Pattern 7: French format variations
      /^([A-Z])\s+(\d+)\s*%\s+([\d\s,\.]+)\s+([\d\s,\.]+)\s+([\d\s,\.]+)$/,
      
      // Pattern 8: Finnish format variations  
      /^([A-Z])\s+(\d+)\s*%\s+([\d\s,]+)\s+([\d\s,]+)\s+([\d\s,]+)$/
    ];
    
    const matches = patterns.some(pattern => {
      const result = pattern.test(text);
      if (result) {
        console.log(`✅ [DataRow] Pattern matched for: "${text}"`);
      }
      return result;
    });
    
    // Additional validation: check if line contains tax-related features
    if (!matches && line.features?.has_percent && line.features?.has_amount_like) {
      console.log(`🔍 [DataRow] Checking features for potential tax row: "${text}"`);
      // Try a more lenient pattern for edge cases
      const lenientPattern = /([A-Z])\s+.*(\d+)\s*%.*(\d+[,\.]\d+)/;
      if (lenientPattern.test(text)) {
        console.log(`⚡ [DataRow] Lenient pattern matched: "${text}"`);
        return true;
      }
    }
    
    return matches;
  }

  /**
   * Extract tax table row data
   */
  private extractTableRow(dataLine: TextLine, header: TableHeader): TaxTableRow | null {
    const text = dataLine.text.trim();
    
    // Try different parsing patterns with enhanced number format support
    const patterns = [
      // Pattern 1: "A 24 % 1,97 1,59 0,38" or "B 14 % 33,65 29.52 4.13"
      {
        regex: /^([A-Z])\s+(\d+)\s*%\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/,
        groups: ['code', 'rate', 'gross', 'net', 'tax']
      },
      // Pattern 2: "A 1,97 1,59 0,38" (rate from header)
      {
        regex: /^([A-Z])\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/, 
        groups: ['code', 'gross', 'net', 'tax'],
        useHeaderRate: true
      },
      // Pattern 3: Flexible spacing: "B  14%  33,65  29.52  4.13"
      {
        regex: /^([A-Z])\s*(\d+)\s*%?\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/,
        groups: ['code', 'rate', 'gross', 'net', 'tax']
      },
      // Pattern 4: With category description: "A Standard 24% 10,50 8,82 1,68"
      {
        regex: /^([A-Z])\s+(?:standard|reduced|normal|regular)?\s*(\d+)\s*%\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/i,
        groups: ['code', 'rate', 'gross', 'net', 'tax']
      },
      // Pattern 5: German format - rate, net, tax, gross: "20 12,50 2,50 15,00" 
      {
        regex: /^(\d+)\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/,
        groups: ['rate', 'net', 'tax', 'gross'],
        isGermanFormat: true
      }
    ];
    
    for (const pattern of patterns) {
      const match = text.match(pattern.regex);
      if (match) {
        try {
          let code: string;
          let rate: number;
          let gross: number;
          let net: number; 
          let tax: number;
          
          if (pattern.isGermanFormat) {
            // German format: rate, net, tax, gross
            code = 'A'; // Default code since German format doesn't have letter codes
            rate = parseInt(match[1]);
            net = this.parseGermanNumber(match[2]);
            tax = this.parseGermanNumber(match[3]);
            gross = this.parseGermanNumber(match[4]);
          } else {
            code = match[1];
            
            if (pattern.useHeaderRate) {
              // Get rate from header mapping
              const headerRate = header.extractedRates.find(r => r.category === code);
              rate = headerRate ? headerRate.rate : this.inferRateFromCode(code);
            } else {
              rate = parseInt(match[2]);
            }
            
            const grossIndex = pattern.useHeaderRate ? 2 : 3;
            const netIndex = grossIndex + 1;
            const taxIndex = netIndex + 1;
            
            gross = this.parseGermanNumber(match[grossIndex]);
            net = this.parseGermanNumber(match[netIndex]);
            tax = this.parseGermanNumber(match[taxIndex]);
          }
          
          // Validate that all numbers were parsed successfully
          if (isNaN(gross) || isNaN(net) || isNaN(tax) || gross <= 0) {
            console.warn(`⚠️ [Row] Invalid numbers in: "${text}" - gross:${gross}, net:${net}, tax:${tax}`);
            continue;
          }
          
          // Validate the row
          const validationResults = this.validateRow(rate, gross, net, tax);
          
          const row: TaxTableRow = {
            code,
            rate,
            gross,
            net,
            tax,
            confidence: this.calculateRowConfidence(validationResults, pattern.isGermanFormat ? 0.85 : (pattern.useHeaderRate ? 0.8 : 0.9)),
            lineIndex: (dataLine as any).line_index || 0,
            validationResults
          };
          
          console.log(`✅ [Row] ${code}: ${rate}% | €${gross} (gross) | €${net} (net) | €${tax} (tax) | confidence: ${row.confidence}`);
          return row;
          
        } catch (error) {
          console.warn(`⚠️ [Row] Failed to parse row: "${text}"`, error);
          continue;
        }
      }
    }
    
    console.warn(`❌ [Row] No pattern matched for: "${text}"`);
    return null;
  }

  /**
   * Validate tax table row mathematics
   */
  private validateRow(rate: number, gross: number, net: number, tax: number): RowValidationResults {
    // Check: gross = net + tax (with tolerance)
    const grossSum = net + tax;
    const grossDiff = Math.abs(gross - grossSum);
    const mathConsistent = grossDiff <= this.mathTolerance;
    
    // Check: tax = net * rate / 100 (with tolerance)
    const expectedTax = (net * rate) / 100;
    const taxDiff = Math.abs(tax - expectedTax);
    const rateConsistent = taxDiff <= this.mathTolerance;
    
    const maxDiscrepancy = Math.max(grossDiff, taxDiff);
    
    return {
      mathConsistent,
      rateConsistent,
      toleranceUsed: this.mathTolerance,
      discrepancy: maxDiscrepancy > 0.001 ? maxDiscrepancy : undefined
    };
  }

  /**
   * Calculate table totals from all rows
   */
  private calculateTableTotals(rows: TaxTableRow[]): TableTotals {
    const totalGross = rows.reduce((sum, row) => sum + row.gross, 0);
    const totalNet = rows.reduce((sum, row) => sum + row.net, 0);
    const totalTax = rows.reduce((sum, row) => sum + row.tax, 0);
    
    // Calculate confidence based on validation results
    const validRows = rows.filter(row => 
      row.validationResults.mathConsistent && row.validationResults.rateConsistent
    );
    const confidence = validRows.length / rows.length;
    
    return {
      totalGross: Math.round(totalGross * 100) / 100,
      totalNet: Math.round(totalNet * 100) / 100,
      totalTax: Math.round(totalTax * 100) / 100,
      calculatedFromRows: true,
      confidence
    };
  }

  /**
   * Calculate spatial information for the table
   */
  private calculateSpatialInfo(header: TableHeader, dataRows: TextLine[]): TableSpatialInfo {
    const allLines = [header.line, ...dataRows];
    
    // Calculate bounding box
    const minX = Math.min(...allLines.map(line => line.boundingBox[0]));
    const minY = Math.min(...allLines.map(line => line.boundingBox[1]));
    const maxX = Math.max(...allLines.map(line => line.boundingBox[0] + line.boundingBox[2]));
    const maxY = Math.max(...allLines.map(line => line.boundingBox[1] + line.boundingBox[3]));
    
    const region: BoundingBox = {
      x: minX,
      y: minY, 
      width: maxX - minX,
      height: maxY - minY
    };
    
    return {
      region,
      headerLineIndex: header.index,
      dataLineIndices: dataRows.map(row => (row as any).line_index || 0),
      columnBoundaries: [] // TODO: Implement column boundary detection
    };
  }

  // Helper methods
  private parseGermanNumber(numberStr: string): number {
    // Handle mixed number formats: "1,97" = 1.97, "29.52" = 29.52
    // First, normalize the string by removing any spaces
    let normalized = numberStr.trim();
    
    // Check if it contains both comma and period
    const hasComma = normalized.includes(',');
    const hasPeriod = normalized.includes('.');
    
    if (hasComma && hasPeriod) {
      // European format: "1.234,56" -> "1234.56"
      // Find the last separator (should be decimal)
      const lastCommaIndex = normalized.lastIndexOf(',');
      const lastPeriodIndex = normalized.lastIndexOf('.');
      
      if (lastCommaIndex > lastPeriodIndex) {
        // Comma is decimal separator: "1.234,56"
        normalized = normalized.replace(/\./g, '').replace(',', '.');
      } else {
        // Period is decimal separator: "1,234.56"
        normalized = normalized.replace(/,/g, '');
      }
    } else if (hasComma && !hasPeriod) {
      // Only comma - assume it's decimal separator
      normalized = normalized.replace(',', '.');
    }
    // If only period or neither, use as-is
    
    const result = parseFloat(normalized);
    if (isNaN(result)) {
      console.warn(`⚠️ [Parse] Failed to parse number: "${numberStr}" -> "${normalized}"`);
      return 0;
    }
    
    console.log(`🔢 [Parse] "${numberStr}" -> ${result}`);
    return result;
  }

  private mapNamedRateToCategory(name: string): string {
    const mapping: { [key: string]: string } = {
      'standard': 'A',
      'normal': 'A', 
      'regular': 'A',
      'reduced': 'B',
      'lower': 'B',
      'minimum': 'C'
    };
    return mapping[name.toLowerCase()] || name.toUpperCase();
  }

  private isValidTaxRate(rate: number): boolean {
    // Common EU tax rates
    const commonRates = [0, 5, 6, 7, 10, 12, 14, 15, 19, 20, 21, 22, 23, 24, 25, 27];
    return commonRates.includes(rate);
  }

  private inferCategoryFromRate(rate: number): string {
    // Infer category based on common rate patterns
    if (rate >= 20) return 'A'; // Standard rate
    if (rate >= 10) return 'B'; // Reduced rate
    return 'C'; // Zero/low rate
  }

  private inferRateFromCode(code: string): number {
    // Fallback inference - would be better to use country context
    const rateMap: { [key: string]: number } = {
      'A': 24, // Finnish standard
      'B': 14, // Finnish reduced
      'C': 0   // Zero rate
    };
    return rateMap[code] || 0;
  }

  private inferAlignment(type: Column['type']): 'left' | 'right' | 'center' {
    return type === 'code' ? 'left' : 'right';
  }

  private getExpectedFormat(type: Column['type']): RegExp {
    const formats = {
      'code': /^[A-Z]$/,
      'rate': /^\d+\s*%?$/,
      'gross': /^[\d,\.]+$/,
      'net': /^[\d,\.]+$/,
      'tax': /^[\d,\.]+$/
    };
    return formats[type] || /.*/;
  }

  private isTableEnd(line: TextLine, currentRowCount: number): boolean {
    const text = line.text.toLowerCase().trim();
    
    // Don't end table if we haven't found any rows yet
    if (currentRowCount === 0) {
      return false;
    }
    
    // Be more specific about table end patterns to avoid false positives
    const endPatterns = [
      // Clear total/sum indicators at line start
      /^(total|yhteens[äa]|summa|summe)\s*[:=]?\s*[\d,\.]+/i,
      
      // Receipt end indicators
      /^(kiitos|thank|danke|tack).*(käynti|visit|besuch)/i,
      
      // Payment completion indicators  
      /^(maksu|payment|zahlung|betalning).*(completed|abgeschlossen|slutförd)/i,
      
      // Date/time at end (but not if it looks like a tax row)
      /^\d{2}[\.\/]\d{2}[\.\/]\d{2,4}\s+\d{1,2}:\d{2}$/,
      
      // Clear non-table content (phone numbers, websites, etc.)
      /^(www\.|http|tel:|phone:|telefon:)/i
    ];
    
    // Additional check: if line looks like a tax row, don't end the table
    if (this.isTableDataRow(line)) {
      console.log(`🔄 [TableEnd] Line "${text}" looks like tax row, continuing table`);
      return false;
    }
    
    const isEnd = endPatterns.some(pattern => pattern.test(text));
    
    if (isEnd) {
      console.log(`🛑 [TableEnd] Table ended at line: "${text}" (after ${currentRowCount} rows)`);
    }
    
    return isEnd;
  }

  private calculateHeaderConfidence(text: string, rates: TaxRateMapping[], structure: ColumnStructure): number {
    let confidence = 0.3; // Base confidence
    
    // Boost for clear tax keywords
    if (/(?:tax|vat|alv|moms|mwst)/i.test(text)) confidence += 0.3;
    
    // Boost for amount keywords
    if (/(?:gross|net|brutto|netto)/i.test(text)) confidence += 0.2;
    
    // Boost for extracted rates
    confidence += Math.min(rates.length * 0.1, 0.3);
    
    // Boost for good structure
    confidence += structure.confidence * 0.2;
    
    return Math.min(confidence, 1.0);
  }

  private calculateRowConfidence(validation: RowValidationResults, baseConfidence: number): number {
    let confidence = baseConfidence;
    
    if (!validation.mathConsistent) confidence -= 0.3;
    if (!validation.rateConsistent) confidence -= 0.2;
    
    // Penalize based on discrepancy size
    if (validation.discrepancy && validation.discrepancy > 0.05) {
      confidence -= Math.min(validation.discrepancy * 2, 0.3);
    }
    
    return Math.max(confidence, 0.1);
  }

  private calculateTableConfidence(header: TableHeader, rows: TaxTableRow[], totals: TableTotals): number {
    const headerConfidence = header.confidence;
    const avgRowConfidence = rows.reduce((sum, row) => sum + row.confidence, 0) / rows.length;
    const totalsConfidence = totals.confidence;
    
    // Weighted average
    return (headerConfidence * 0.3 + avgRowConfidence * 0.5 + totalsConfidence * 0.2);
  }

  /**
   * Convert tax table to enhanced tax breakdown format with localization
   */
  convertToTaxBreakdown(table: TaxTable, language: string = 'en'): TaxBreakdown[] {
    return table.rows.map(row => {
      const category = row.code;
      const formattedDescription = TaxBreakdownLocalizationService.getFormattedCategoryDescription(category, row.rate, language);
      
      return {
        rate: row.rate,
        amount: row.tax,
        net: row.net,
        gross: row.gross,
        category: category,
        confidence: row.confidence,
        description: formattedDescription
      };
    });
  }

  /**
   * Get total tax amount from table
   */
  getTotalTaxAmount(table: TaxTable): number {
    return table.totals.totalTax;
  }

  /**
   * Get comprehensive tax summary with rate-specific breakdown
   */
  getTaxSummary(table: TaxTable, language: string = 'en'): {
    breakdown: TaxBreakdown[];
    totalTax: number;
    totalNet: number;
    totalGross: number;
    summary: string;
  } {
    const breakdown = this.convertToTaxBreakdown(table, language);
    const totalTax = table.totals.totalTax;
    const totalNet = table.totals.totalNet;
    const totalGross = table.totals.totalGross;
    
    const summary = TaxBreakdownLocalizationService.generateSummaryDescription(
      breakdown.map(b => ({ category: b.category!, rate: b.rate, amount: b.amount })),
      'EUR',
      language
    );
    
    return {
      breakdown,
      totalTax,
      totalNet,
      totalGross,
      summary
    };
  }

  /**
   * Detect language from tax-related keywords in the text
   */
  private detectLanguage(textLines: TextLine[]): string {
    const allText = textLines.map(line => line.text).join(' ').toLowerCase();
    return TaxBreakdownLocalizationService.detectLanguageFromTaxKeywords(allText);
  }
}