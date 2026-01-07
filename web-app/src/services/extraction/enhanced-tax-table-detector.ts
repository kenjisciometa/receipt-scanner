/**
 * Enhanced Tax Table Detector
 * 
 * Extends TaxTableDetector with header-context detection capabilities
 * for tables where header contains tax rate info but data rows lack % symbols
 */

import { TextLine } from '@/types/ocr';
import { 
  TaxTable, 
  TaxTableRow, 
  TaxRateMapping,
  HeaderContext,
  RateDeclaration,
  TableStructureInfo,
  ContextualRateInfo,
  COUNTRY_TAX_RATES
} from '@/types/tax-table';
import { TaxBreakdown } from '@/types/extraction';
import { TaxTableDetector } from './tax-table-detector';
import { TaxBreakdownLocalizationService } from './tax-breakdown-localization';

/**
 * Enhanced Tax Table Detector with Header-Context Analysis
 */
export class EnhancedTaxTableDetector extends TaxTableDetector {

  /**
   * Detect tax tables including header-context analysis
   */
  async detectTaxTables(textLines: TextLine[]): Promise<TaxTable[]> {
    console.log(`🧠 [Enhanced] Starting enhanced tax table detection`);
    
    // 1. Traditional pattern detection
    const standardTables = await super.detectTaxTables(textLines);
    console.log(`📊 [Enhanced] Standard detection found ${standardTables.length} tables`);
    
    // 2. Header-Context detection for missing cases
    const headerContextTables = await this.detectHeaderContextTables(textLines);
    console.log(`🎯 [Enhanced] Header-context detection found ${headerContextTables.length} tables`);
    
    // 3. Merge results (avoiding duplicates)
    const mergedTables = this.mergeTableDetections(standardTables, headerContextTables);
    console.log(`✅ [Enhanced] Total detected tables: ${mergedTables.length}`);
    
    return mergedTables;
  }

  /**
   * Detect tables using header-context analysis
   */
  private async detectHeaderContextTables(textLines: TextLine[]): Promise<TaxTable[]> {
    const tables: TaxTable[] = [];
    
    // Find header candidates with contextual analysis
    const headerCandidates = this.findHeaderCandidatesWithContext(textLines);
    
    for (let i = 0; i < headerCandidates.length; i++) {
      const header = headerCandidates[i];
      const headerIndex = textLines.indexOf(header);
      
      // Extract header rates and context  
      const headerContext = this.analyzeHeaderContext(textLines, headerIndex);
      
      if (headerContext.rateDeclarations.length > 0) {
        // Find associated data rows - use inherited method from base class
        const dataRows = super['findTableDataRows'](textLines, headerIndex);
        
        // Build table using header rates
        const table = await this.buildTableWithHeaderRates(
          header,
          headerContext,
          dataRows
        );
        
        if (table) {
          tables.push(table);
          console.log(`✅ [HeaderContext] Built table with ${table.rows.length} rows from header context`);
        }
      }
    }
    
    return tables;
  }

  /**
   * Find header candidates using enhanced context analysis
   */
  private findHeaderCandidatesWithContext(textLines: TextLine[]): TextLine[] {
    const candidates: TextLine[] = [];
    
    for (let i = 0; i < textLines.length; i++) {
      const line = textLines[i];
      const text = line.text.trim();
      
      // Look for headers that might contain rate information
      if (this.isHeaderWithRateContext(text)) {
        candidates.push(line);
        console.log(`🎯 [HeaderContext] Rate context header candidate: "${text}"`);
      }
    }
    
    return candidates;
  }

  /**
   * Check if header contains rate context information
   */
  private isHeaderWithRateContext(text: string): boolean {
    const patterns = [
      // Headers with rate categories: "A 24% B 14% Brutto Netto Vero"
      /[A-Z]\s*\d+\s*%.*(?:brutto|netto|gross|net|tax|vero|alv)/i,
      
      // Named rate headers: "Standard 24% Reduced 14% Gross Net Tax"
      /(standard|reduced|normal)\s*\d+\s*%.*(?:gross|net|tax)/i,
      
      // Multi-word rate declarations
      /(?:standard|normal).*\d+%.*(?:reduced|lower).*\d+%/i,
      
      // Simple rate listing with amounts structure
      /\d+\s*%.*\d+\s*%.*(?:brutto|netto|gross|net)/i
    ];
    
    return patterns.some(pattern => pattern.test(text));
  }

  /**
   * Analyze header context including multi-line context
   */
  private analyzeHeaderContext(textLines: TextLine[], headerIndex: number, contextRange: number = 3): HeaderContext {
    // Look at lines before and after header for additional context
    const contextStart = Math.max(0, headerIndex - contextRange);
    const contextEnd = Math.min(textLines.length, headerIndex + contextRange + 1);
    const contextLines = textLines.slice(contextStart, contextEnd);
    
    // Extract rate declarations from all context lines
    const rateDeclarations = this.findRateDeclarationLines(contextLines);
    
    // Analyze table structure
    const structureInfo = this.findTableStructureLines(contextLines);
    
    // Merge context information
    const mergedContext = this.mergeHeaderContext(rateDeclarations, structureInfo);
    
    const confidence = this.calculateContextConfidence(rateDeclarations, structureInfo);
    
    return {
      rateDeclarations,
      structureInfo,
      mergedContext,
      confidence
    };
  }

  /**
   * Find rate declaration lines in context
   */
  private findRateDeclarationLines(contextLines: TextLine[]): RateDeclaration[] {
    const declarations: RateDeclaration[] = [];
    
    const patterns = [
      // Standard rate patterns
      { 
        regex: /(?:standard|normal|regular)\s*(?:rate|vat|tax)?\s*:?\s*(\d+)%/gi,
        type: 'standard'
      },
      // Reduced rate patterns  
      {
        regex: /(?:reduced|lower|minimum)\s*(?:rate|vat|tax)?\s*:?\s*(\d+)%/gi,
        type: 'reduced'
      },
      // Category patterns: "A 24%", "B 14%"
      {
        regex: /([A-Z])\s*(?:category|rate)?\s*:?\s*(\d+)%/gi,
        type: 'category'
      },
      // Reverse patterns: "24% standard"
      {
        regex: /(\d+)%\s*(?:standard|normal|vat|tax)/gi,
        type: 'standard'
      }
    ];
    
    for (const line of contextLines) {
      const text = line.text;
      
      for (const pattern of patterns) {
        let match;
        while ((match = pattern.regex.exec(text)) !== null) {
          const rate = pattern.type === 'category' ? parseInt(match[2]) : parseInt(match[1]);
          const category = pattern.type === 'category' ? match[1] : this.mapTypeToCategory(pattern.type, rate);
          
          declarations.push({
            rate,
            category,
            pattern: match[0],
            position: match.index,
            confidence: this.calculateDeclarationConfidence(pattern.type, match[0])
          });
        }
      }
    }
    
    return declarations;
  }

  /**
   * Find table structure information in context
   */
  private findTableStructureLines(contextLines: TextLine[]): TableStructureInfo {
    let columnCount = 0;
    let hasHeaders = false;
    let dataRowPattern = /^([A-Z])\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)/;
    const expectedStructure: string[] = [];
    
    for (const line of contextLines) {
      const text = line.text.toLowerCase();
      
      // Count potential columns based on keywords
      const columnKeywords = ['brutto', 'gross', 'netto', 'net', 'vero', 'tax', 'alv', 'moms'];
      const foundKeywords = columnKeywords.filter(keyword => text.includes(keyword));
      
      if (foundKeywords.length > columnCount) {
        columnCount = foundKeywords.length;
        expectedStructure.push(...foundKeywords);
        hasHeaders = true;
      }
    }
    
    return {
      columnCount,
      hasHeaders,
      dataRowPattern,
      expectedStructure
    };
  }

  /**
   * Merge header context information
   */
  private mergeHeaderContext(rateDeclarations: RateDeclaration[], structureInfo: TableStructureInfo): ContextualRateInfo {
    const standardRates = rateDeclarations.map(d => d.rate);
    const countryContext = this.inferCountryFromRates(standardRates);
    
    // Create rate mappings based on declarations
    const inferredMappings: TaxRateMapping[] = rateDeclarations.map(declaration => ({
      rate: declaration.rate,
      category: declaration.category,
      position: declaration.position,
      confidence: declaration.confidence
    }));
    
    return {
      standardRates,
      countryContext,
      inferredMappings
    };
  }

  /**
   * Build table using header rates for data rows without % symbols
   */
  private async buildTableWithHeaderRates(
    header: TextLine,
    headerContext: HeaderContext,
    dataRows: TextLine[]
  ): Promise<TaxTable | null> {
    
    const tableRows: TaxTableRow[] = [];
    
    for (const dataLine of dataRows) {
      const row = this.extractRowWithHeaderRates(dataLine, headerContext);
      if (row) {
        tableRows.push(row);
      }
    }
    
    if (tableRows.length === 0) {
      console.log(`⚠️ [HeaderContext] No valid rows extracted from header context`);
      return null;
    }
    
    // Build table structure similar to standard detection
    const totals = super['calculateTableTotals'](tableRows);
    const spatialInfo = this.calculateSimpleSpatialInfo(header, dataRows);
    const confidence = this.calculateHeaderContextTableConfidence(headerContext, tableRows);
    
    const table: TaxTable = {
      id: `header_context_${Date.now()}`,
      header: {
        line: header,
        index: (dataRows[0] as any)?.line_index || 0,
        extractedRates: headerContext.mergedContext.inferredMappings,
        structure: { columns: [], confidence: 0.7 },
        confidence: headerContext.confidence
      },
      rows: tableRows,
      totals,
      confidence,
      spatialInfo
    };
    
    return table;
  }

  /**
   * Extract row using header rate mappings
   */
  private extractRowWithHeaderRates(dataLine: TextLine, headerContext: HeaderContext): TaxTableRow | null {
    const text = dataLine.text.trim();
    
    // Try to extract: [Category] [Gross] [Net] [Tax]
    const patterns = [
      // Pattern 1: "A 1,97 1,59 0,38"
      {
        regex: /^([A-Z])\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)/,
        groups: ['code', 'gross', 'net', 'tax']
      },
      // Pattern 2: "A 24 1,97 1,59 0,38" (ignoring the rate number)
      {
        regex: /^([A-Z])\s+\d+\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)/,
        groups: ['code', 'gross', 'net', 'tax']
      }
    ];
    
    for (const pattern of patterns) {
      const match = text.match(pattern.regex);
      if (match) {
        try {
          const code = match[1];
          
          // Get rate from header context
          const rateMapping = headerContext.mergedContext.inferredMappings.find(
            mapping => mapping.category === code
          );
          
          if (!rateMapping) {
            console.warn(`⚠️ [HeaderContext] No rate mapping found for category: ${code}`);
            continue;
          }
          
          const rate = rateMapping.rate;
          const gross = parseFloat(match[2].replace(',', '.'));
          const net = parseFloat(match[3].replace(',', '.'));
          const tax = parseFloat(match[4].replace(',', '.'));
          
          // Validate the row
          const validationResults = super['validateRow'](rate, gross, net, tax);
          
          const row: TaxTableRow = {
            code,
            rate,
            gross,
            net,
            tax,
            confidence: this.calculateHeaderContextRowConfidence(validationResults, rateMapping.confidence),
            lineIndex: (dataLine as any).line_index || 0,
            validationResults
          };
          
          console.log(`✅ [HeaderContext] ${code}: ${rate}% | €${gross} | €${net} | €${tax} | confidence: ${row.confidence}`);
          return row;
          
        } catch (error) {
          console.warn(`⚠️ [HeaderContext] Failed to parse row: "${text}"`, error);
          continue;
        }
      }
    }
    
    return null;
  }

  /**
   * Merge standard and header-context detections avoiding duplicates
   */
  private mergeTableDetections(standardTables: TaxTable[], headerContextTables: TaxTable[]): TaxTable[] {
    const merged = [...standardTables];
    
    for (const contextTable of headerContextTables) {
      // Check if this table overlaps with any standard table
      const hasOverlap = standardTables.some(standardTable => 
        this.tablesOverlap(standardTable, contextTable)
      );
      
      if (!hasOverlap) {
        merged.push(contextTable);
        console.log(`➕ [Merge] Added header-context table with ${contextTable.rows.length} rows`);
      } else {
        console.log(`🔄 [Merge] Skipped overlapping header-context table`);
      }
    }
    
    return merged;
  }

  /**
   * Check if two tables overlap spatially or logically
   */
  private tablesOverlap(table1: TaxTable, table2: TaxTable): boolean {
    // Simple overlap check based on line indices
    const lines1 = [table1.header.index, ...table1.spatialInfo.dataLineIndices];
    const lines2 = [table2.header.index, ...table2.spatialInfo.dataLineIndices];
    
    return lines1.some(line => lines2.includes(line));
  }

  // Helper methods - removed duplicate, using inline parsing

  private mapTypeToCategory(type: string, rate: number): string {
    if (type === 'standard' || rate >= 20) return 'A';
    if (type === 'reduced' || rate >= 10) return 'B';
    return 'C';
  }

  private inferCountryFromRates(rates: number[]): string {
    // Simple country inference based on rate combinations
    if (rates.includes(24) && rates.includes(14)) return 'FI'; // Finland
    if (rates.includes(25) && rates.includes(12)) return 'SE'; // Sweden
    if (rates.includes(19) && rates.includes(7)) return 'DE';  // Germany
    return 'unknown';
  }

  private calculateDeclarationConfidence(type: string, matchText: string): number {
    let confidence = 0.5;
    
    if (type === 'category') confidence += 0.3; // Category patterns are more specific
    if (matchText.includes('%')) confidence += 0.2;
    if (/\d+\s*%/.test(matchText)) confidence += 0.1;
    
    return Math.min(confidence, 1.0);
  }

  private calculateContextConfidence(declarations: RateDeclaration[], structure: TableStructureInfo): number {
    let confidence = 0.3;
    
    confidence += Math.min(declarations.length * 0.15, 0.4);
    confidence += structure.hasHeaders ? 0.2 : 0;
    confidence += Math.min(structure.columnCount * 0.05, 0.1);
    
    return Math.min(confidence, 1.0);
  }

  private calculateHeaderContextRowConfidence(validation: any, rateMappingConfidence: number): number {
    let confidence = rateMappingConfidence * 0.6; // Start with rate mapping confidence
    
    if (validation.mathConsistent) confidence += 0.2;
    if (validation.rateConsistent) confidence += 0.2;
    
    return Math.min(confidence, 1.0);
  }

  private calculateHeaderContextTableConfidence(headerContext: HeaderContext, rows: TaxTableRow[]): number {
    const contextConfidence = headerContext.confidence;
    const avgRowConfidence = rows.reduce((sum, row) => sum + row.confidence, 0) / rows.length;
    
    return (contextConfidence * 0.4 + avgRowConfidence * 0.6);
  }

  private calculateSimpleSpatialInfo(header: TextLine, dataRows: TextLine[]): any {
    // Simplified spatial info calculation
    return {
      region: { x: 0, y: 0, width: 0, height: 0 },
      headerLineIndex: (header as any).line_index || 0,
      dataLineIndices: dataRows.map(row => (row as any).line_index || 0),
      columnBoundaries: []
    };
  }

  /**
   * Convert enhanced table to multilingual tax breakdown
   */
  convertToEnhancedTaxBreakdown(table: TaxTable, language: string = 'en'): TaxBreakdown[] {
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
   * Get comprehensive tax summary with multilingual support
   */
  getEnhancedTaxSummary(table: TaxTable, language?: string): {
    breakdown: TaxBreakdown[];
    totalTax: number;
    totalNet: number;
    totalGross: number;
    summary: string;
    detectedLanguage: string;
  } {
    // Detect language if not provided
    const detectedLanguage = language || this.detectLanguageFromTable(table);
    
    const breakdown = this.convertToEnhancedTaxBreakdown(table, detectedLanguage);
    const totalTax = table.totals.totalTax;
    const totalNet = table.totals.totalNet;
    const totalGross = table.totals.totalGross;
    
    const summary = TaxBreakdownLocalizationService.generateSummaryDescription(
      breakdown.map(b => ({ category: b.category!, rate: b.rate, amount: b.amount })),
      'EUR',
      detectedLanguage
    );
    
    return {
      breakdown,
      totalTax,
      totalNet,
      totalGross,
      summary,
      detectedLanguage
    };
  }

  /**
   * Detect language from table content
   */
  private detectLanguageFromTable(table: TaxTable): string {
    const headerText = table.header.line.text;
    return TaxBreakdownLocalizationService.detectLanguageFromTaxKeywords(headerText);
  }
}