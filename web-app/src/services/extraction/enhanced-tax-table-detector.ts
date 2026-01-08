/**
 * Enhanced Tax Table Detector
 * 
 * Implements the new 3-stage tax table detection strategy:
 * Stage 1: Enhanced Keyword Detection
 * Stage 2: Spatial Table Analysis 
 * Stage 3: Column Type Detection
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
import { EnhancedKeywordDetector, TaxKeywordDetectionResult } from './enhanced-keyword-detector';
import { SpatialTableAnalyzer, TableStructure } from './spatial-table-analyzer';
import { ColumnTypeDetector, ColumnTypeMapping } from './column-type-detector';
import { CentralizedKeywordConfig } from '../keywords/centralized-keyword-config';
import { LanguageKeywords } from '../keywords/language-keywords';
import { ProcessedTextLine } from '../../types';

/**
 * Enhanced Tax Table Detector with Header-Context Analysis
 */
export class EnhancedTaxTableDetector extends TaxTableDetector {
  private keywordDetector: EnhancedKeywordDetector;
  private spatialAnalyzer: SpatialTableAnalyzer;
  private columnTypeDetector: ColumnTypeDetector;
  
  constructor() {
    super();
    this.keywordDetector = new EnhancedKeywordDetector(
      CentralizedKeywordConfig,
      new LanguageKeywords()
    );
    this.spatialAnalyzer = new SpatialTableAnalyzer();
    this.columnTypeDetector = new ColumnTypeDetector();
  }

  /**
   * Detect tax tables using new 3-stage detection strategy
   */
  async detectTaxTables(textLines: TextLine[]): Promise<TaxTable[]> {
    console.log(`🧠 [Enhanced] Starting 3-stage tax table detection`);
    
    // Convert TextLine[] to ProcessedTextLine[] format
    const processedLines = this.convertToProcessedTextLines(textLines);
    
    // === 3-STAGE DETECTION STRATEGY ===
    
    // Stage 1: Enhanced Keyword Detection
    console.log(`🔍 [Stage 1] Starting keyword detection on ${processedLines.length} lines`);
    const keywordResults = this.keywordDetector.detectTaxKeywords(processedLines);
    console.log(`📝 [Stage 1] Found ${keywordResults.taxKeywords.length} tax keywords, ${keywordResults.numericPatterns.length} numeric patterns`);
    this.logKeywordDetectionResults(keywordResults);
    
    // Stage 2: Spatial Table Analysis
    console.log(`📐 [Stage 2] Starting spatial analysis`);
    const tableStructures = this.spatialAnalyzer.analyzeStructure(keywordResults, processedLines);
    console.log(`🗂️ [Stage 2] Identified ${tableStructures.length} table structures`);
    this.logTableStructures(tableStructures);
    
    // Stage 3: Column Type Detection & Table Building
    console.log(`🔢 [Stage 3] Starting column type detection`);
    const detectedTables = await this.buildTablesFromStructures(tableStructures, keywordResults, processedLines);
    console.log(`✅ [Stage 3] Built ${detectedTables.length} tax tables`);
    this.logDetectedTables(detectedTables, 'Stage3');
    
    // Fallback to traditional detection for missed cases
    const traditionalTables = await super.detectTaxTables(textLines);
    console.log(`🔄 [Fallback] Traditional detection found ${traditionalTables.length} additional tables`);
    
    // Header-Context detection for edge cases
    const headerContextTables = await this.detectHeaderContextTables(textLines);
    console.log(`🎯 [HeaderContext] Found ${headerContextTables.length} header-context tables`);
    
    // Merge all results (avoiding duplicates)
    const allTables = [...detectedTables, ...traditionalTables, ...headerContextTables];
    const mergedTables = this.deduplicateTables(allTables);
    console.log(`✅ [Enhanced] Total detected tables: ${mergedTables.length}`);
    
    this.logFinalResults(mergedTables);
    return mergedTables;
  }

  /**
   * Convert TextLine[] to ProcessedTextLine[] format
   */
  private convertToProcessedTextLines(textLines: TextLine[]): ProcessedTextLine[] {
    return textLines.map((line, index) => ({
      text: line.text,
      confidence: 0.8, // Default confidence for converted lines
      boundingBox: [0, index * 20, 400, 16], // Estimated bounding box
      merged: true,
      line_index: index,
      elements: [],
      label: 'OTHER',
      label_confidence: 0.8,
      features: {
        x_center: 0.5,
        y_center: (index * 20) / 800,
        width: 0.8,
        height: 0.02,
        is_right_side: false,
        is_bottom_area: false,
        is_middle_section: false,
        line_index_norm: index / Math.max(1, textLines.length - 1),
        has_currency_symbol: /[\$€£¥]/.test(line.text),
        has_percent: /%/.test(line.text),
        has_amount_like: /\d+[.,]\d{2}/.test(line.text),
        has_total_keyword: /total|sum|gesamt/i.test(line.text),
        has_tax_keyword: /tax|alv|moms|tva|iva|ust/i.test(line.text),
        has_subtotal_keyword: /subtotal|zwischen/i.test(line.text),
        has_date_like: /\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}/.test(line.text),
        has_quantity_marker: false,
        has_item_like: true,
        digit_count: (line.text.match(/\d/g) || []).length,
        alpha_count: (line.text.match(/[a-zA-Z]/g) || []).length,
        contains_colon: line.text.includes(':')
      },
      feature_vector: [] // Will be populated if needed
    }));
  }

  /**
   * Build tax tables from detected structures
   */
  private async buildTablesFromStructures(
    structures: TableStructure[],
    keywordResults: TaxKeywordDetectionResult,
    processedLines: ProcessedTextLine[]
  ): Promise<TaxTable[]> {
    const tables: TaxTable[] = [];

    for (const structure of structures) {
      console.log(`🏗️  [TableBuilder] Building table from ${structure.type} structure with confidence ${structure.confidence}`);
      
      // Stage 3: Column Type Detection
      const columnMapping = await this.columnTypeDetector.detectColumnTypes(structure);
      this.logColumnTypeMapping(columnMapping, structure.type);
      
      // Convert to TaxTable format
      const table = await this.convertStructureToTaxTable(structure, columnMapping, keywordResults);
      
      if (table) {
        tables.push(table);
        console.log(`✅ [TableBuilder] Built table with ${table.rows.length} rows, confidence: ${table.confidence}`);
      }
    }

    return tables;
  }

  /**
   * Convert TableStructure to TaxTable format
   */
  private async convertStructureToTaxTable(
    structure: TableStructure,
    columnMapping: ColumnTypeMapping,
    keywordResults: TaxKeywordDetectionResult
  ): Promise<TaxTable | null> {
    try {
      const tableRows: TaxTableRow[] = [];
      
      // Extract data based on structure type
      if (structure.type === 'horizontal_table') {
        const rows = this.extractHorizontalTableRows(structure, columnMapping);
        tableRows.push(...rows);
      } else if (structure.type === 'vertical_list') {
        const rows = this.extractVerticalListRows(structure, columnMapping);
        tableRows.push(...rows);
      } else if (structure.type === 'single_line') {
        const row = this.extractSingleLineRow(structure, columnMapping);
        if (row) tableRows.push(row);
      } else if (structure.type === 'mixed') {
        const rows = this.extractMixedStructureRows(structure, columnMapping);
        tableRows.push(...rows);
      }

      if (tableRows.length === 0) {
        console.log(`⚠️ [TableBuilder] No valid rows extracted from structure`);
        return null;
      }

      // Calculate totals
      const totals = {
        totalTax: tableRows.reduce((sum, row) => sum + row.tax, 0),
        totalNet: tableRows.reduce((sum, row) => sum + row.net, 0),
        totalGross: tableRows.reduce((sum, row) => sum + row.gross, 0)
      };

      // Build spatial info
      const spatialInfo = {
        region: { 
          x: structure.boundingBox[0], 
          y: structure.boundingBox[1], 
          width: structure.boundingBox[2], 
          height: structure.boundingBox[3] 
        },
        headerLineIndex: structure.elements[0]?.lineIndex || 0,
        dataLineIndices: structure.elements.map(el => el.lineIndex),
        columnBoundaries: []
      };

      // Create header info
      const headerElement = structure.elements[0];
      const header = {
        line: this.createTextLineFromElement(headerElement),
        index: headerElement.lineIndex,
        extractedRates: this.extractRatesFromMapping(columnMapping),
        structure: { columns: [], confidence: structure.confidence },
        confidence: structure.confidence
      };

      const table: TaxTable = {
        id: `enhanced_3stage_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        header,
        rows: tableRows,
        totals,
        confidence: this.calculateOverallTableConfidence(structure, tableRows),
        spatialInfo
      };

      return table;
    } catch (error) {
      console.error(`❌ [TableBuilder] Error converting structure to table:`, error);
      return null;
    }
  }

  /**
   * Extract rows from horizontal table structure
   */
  private extractHorizontalTableRows(structure: TableStructure, columnMapping: ColumnTypeMapping): TaxTableRow[] {
    const rows: TaxTableRow[] = [];

    if (!structure.gridInfo || !columnMapping) return rows;

    // Extract data rows (skip header if identified)
    const dataElements = structure.elements.filter((el, index) => {
      if (structure.gridInfo?.headerRow !== undefined) {
        return index !== structure.gridInfo.headerRow;
      }
      return el.containsNumericValue; // Only elements with numbers are likely data
    });

    for (const element of dataElements) {
      const row = this.extractRowFromElement(element, columnMapping, 'horizontal');
      if (row) rows.push(row);
    }

    return rows;
  }

  /**
   * Extract rows from vertical list structure
   */
  private extractVerticalListRows(structure: TableStructure, columnMapping: ColumnTypeMapping): TaxTableRow[] {
    const rows: TaxTableRow[] = [];

    for (const element of structure.elements) {
      if (element.containsTaxKeyword && element.containsNumericValue) {
        const row = this.extractRowFromElement(element, columnMapping, 'vertical');
        if (row) rows.push(row);
      }
    }

    return rows;
  }

  /**
   * Extract single row from single line structure
   */
  private extractSingleLineRow(structure: TableStructure, columnMapping: ColumnTypeMapping): TaxTableRow | null {
    if (structure.elements.length !== 1) return null;
    
    const element = structure.elements[0];
    return this.extractRowFromElement(element, columnMapping, 'single');
  }

  /**
   * Extract rows from mixed structure
   */
  private extractMixedStructureRows(structure: TableStructure, columnMapping: ColumnTypeMapping): TaxTableRow[] {
    const rows: TaxTableRow[] = [];

    // Try both horizontal and vertical extraction approaches
    const horizontalRows = this.extractHorizontalTableRows(structure, columnMapping);
    const verticalRows = this.extractVerticalListRows(structure, columnMapping);

    // Use the approach that yields more rows, or combine both
    if (horizontalRows.length >= verticalRows.length) {
      rows.push(...horizontalRows);
    } else {
      rows.push(...verticalRows);
    }

    return rows;
  }

  /**
   * Extract individual row from element based on column mapping
   */
  private extractRowFromElement(
    element: any,
    columnMapping: ColumnTypeMapping,
    extractionType: 'horizontal' | 'vertical' | 'single'
  ): TaxTableRow | null {
    try {
      const text = element.text;
      
      // Extract values based on extraction type
      let rate: number = 0;
      let net: number = 0;
      let tax: number = 0;
      let gross: number = 0;
      let code: string = '';

      if (extractionType === 'vertical' || extractionType === 'single') {
        // For vertical/single line: extract from single text line
        const lineData = this.parseLineForTaxData(text);
        rate = lineData.rate || 0;
        net = lineData.net || 0;
        tax = lineData.tax || 0;
        gross = lineData.gross || net + tax;
        code = lineData.code || '';
      } else {
        // For horizontal: extract from column positions (simplified)
        const values = this.extractNumericValuesFromText(text);
        if (values.length >= 3) {
          // Assume order: net, tax, gross (or gross, net, tax)
          if (columnMapping.taxRate?.values) {
            rate = parseFloat(columnMapping.taxRate.values[0]?.replace('%', '') || '0');
          }
          net = values[0];
          tax = values[1];
          gross = values[2];
          code = this.extractCodeFromText(text);
        }
      }

      // Validate extracted data
      if (rate <= 0 || (net <= 0 && tax <= 0 && gross <= 0)) {
        return null;
      }

      // Auto-correct missing values using mathematical relationships
      if (net === 0 && tax > 0 && gross > 0) {
        net = gross - tax;
      }
      if (tax === 0 && net > 0 && gross > 0) {
        tax = gross - net;
      }
      if (gross === 0 && net > 0 && tax > 0) {
        gross = net + tax;
      }

      // Calculate confidence based on consistency
      const confidence = this.calculateRowConfidence(rate, net, tax, gross);

      const row: TaxTableRow = {
        code: code || `${rate}%`,
        rate,
        gross,
        net,
        tax,
        confidence,
        lineIndex: element.lineIndex,
        validationResults: {
          mathConsistent: Math.abs((net + tax) - gross) < 0.02,
          rateConsistent: Math.abs((tax / net * 100) - rate) < 1,
          isValid: true
        }
      };

      console.log(`🔍 [RowExtract] ${code}: ${rate}% | Net: ${net} | Tax: ${tax} | Gross: ${gross} | Confidence: ${confidence}`);
      return row;

    } catch (error) {
      console.warn(`⚠️ [RowExtract] Failed to extract row from element:`, error);
      return null;
    }
  }

  /**
   * Deduplicate tables to avoid overlapping results
   */
  private deduplicateTables(tables: TaxTable[]): TaxTable[] {
    const deduplicated: TaxTable[] = [];
    const processedLines = new Set<number>();

    // Sort by confidence (highest first)
    const sortedTables = tables.sort((a, b) => b.confidence - a.confidence);

    for (const table of sortedTables) {
      const tableLines = [table.header.index, ...table.spatialInfo.dataLineIndices];
      
      // Check if this table overlaps with already processed lines
      const hasOverlap = tableLines.some(line => processedLines.has(line));
      
      if (!hasOverlap) {
        deduplicated.push(table);
        tableLines.forEach(line => processedLines.add(line));
        console.log(`✅ [Dedupe] Added table with ${table.rows.length} rows (confidence: ${table.confidence})`);
      } else {
        console.log(`🔄 [Dedupe] Skipped overlapping table (confidence: ${table.confidence})`);
      }
    }

    return deduplicated;
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

  // === 3-STAGE DETECTION HELPER METHODS ===

  /**
   * Parse line text to extract tax data
   */
  private parseLineForTaxData(text: string): {
    rate: number | null;
    net: number | null;
    tax: number | null;
    gross: number | null;
    code: string | null;
  } {
    // Extract percentage
    const rateMatch = text.match(/(\d+(?:[.,]\d+)?)\s*%/);
    const rate = rateMatch ? parseFloat(rateMatch[1].replace(',', '.')) : null;

    // Extract numeric values
    const numbers = this.extractNumericValuesFromText(text);
    
    // Extract code
    const codeMatch = text.match(/^([A-Z])\s/);
    const code = codeMatch ? codeMatch[1] : null;

    // Simple logic: if we have 3+ numbers, assume they are net, tax, gross
    let net: number | null = null;
    let tax: number | null = null;
    let gross: number | null = null;

    if (numbers.length >= 3) {
      net = numbers[0];
      tax = numbers[1]; 
      gross = numbers[2];
    } else if (numbers.length === 2) {
      // Could be tax + total, or net + gross
      if (rate && numbers[0] * (rate / 100) > numbers[1] * 0.8 && numbers[0] * (rate / 100) < numbers[1] * 1.2) {
        net = numbers[0];
        tax = numbers[1];
        gross = net + tax;
      } else {
        tax = numbers[0];
        gross = numbers[1];
        net = gross - tax;
      }
    } else if (numbers.length === 1) {
      // Single number, likely tax amount
      tax = numbers[0];
    }

    return { rate, net, tax, gross, code };
  }

  /**
   * Extract numeric values from text
   */
  private extractNumericValuesFromText(text: string): number[] {
    const numbers: number[] = [];
    const patterns = [
      /\b(\d+(?:[.,]\d{2})?)\b/g,
      /(\d+(?:[.,]\d{3})*(?:[.,]\d{2})?)/g
    ];

    for (const pattern of patterns) {
      let match;
      while ((match = pattern.exec(text)) !== null) {
        const numStr = match[1].replace(/,/g, '').replace(',', '.');
        const num = parseFloat(numStr);
        if (!isNaN(num) && num > 0) {
          numbers.push(num);
        }
      }
      pattern.lastIndex = 0; // Reset regex
    }

    // Remove duplicates and sort
    return [...new Set(numbers)].sort((a, b) => a - b);
  }

  /**
   * Extract code from text
   */
  private extractCodeFromText(text: string): string {
    const codeMatch = text.match(/^([A-Z]+)\s/);
    return codeMatch ? codeMatch[1] : '';
  }

  /**
   * Calculate row confidence
   */
  private calculateRowConfidence(rate: number, net: number, tax: number, gross: number): number {
    let confidence = 0.5;

    // Check mathematical consistency
    const mathError = Math.abs((net + tax) - gross);
    if (mathError < 0.01) confidence += 0.3;
    else if (mathError < 0.1) confidence += 0.2;
    else if (mathError < 1) confidence += 0.1;

    // Check rate consistency
    if (net > 0) {
      const calculatedRate = (tax / net) * 100;
      const rateError = Math.abs(calculatedRate - rate);
      if (rateError < 0.1) confidence += 0.2;
      else if (rateError < 1) confidence += 0.1;
    }

    return Math.min(confidence, 0.98);
  }

  /**
   * Calculate overall table confidence
   */
  private calculateOverallTableConfidence(structure: TableStructure, rows: TaxTableRow[]): number {
    const structureConf = structure.confidence;
    const avgRowConf = rows.reduce((sum, row) => sum + row.confidence, 0) / Math.max(rows.length, 1);
    
    return (structureConf * 0.4 + avgRowConf * 0.6);
  }

  /**
   * Create TextLine from SpatialElement
   */
  private createTextLineFromElement(element: any): any {
    return {
      text: element.text,
      line_index: element.lineIndex,
      boundingBox: element.boundingBox
    };
  }

  /**
   * Extract tax rates from column mapping
   */
  private extractRatesFromMapping(columnMapping: ColumnTypeMapping): any[] {
    const rates: any[] = [];
    
    if (columnMapping.taxRate) {
      for (const value of columnMapping.taxRate.values) {
        const rateMatch = value.match(/(\d+(?:[.,]\d+)?)/);
        if (rateMatch) {
          const rate = parseFloat(rateMatch[1].replace(',', '.'));
          rates.push({
            rate,
            category: `${rate}%`,
            position: 0,
            confidence: columnMapping.taxRate.confidence
          });
        }
      }
    }

    return rates;
  }

  // === DETAILED LOGGING METHODS ===

  /**
   * Log keyword detection results with details
   */
  private logKeywordDetectionResults(results: TaxKeywordDetectionResult): void {
    console.log(`\n📋 [Stage 1 Details] Keyword Detection Results:`);
    
    // Log detected languages
    console.log(`🌍 Detected Languages:`);
    results.detectedLanguages.forEach((lang, index) => {
      console.log(`  ${index + 1}. ${lang.language.toUpperCase()}: confidence ${lang.confidence.toFixed(2)} (${lang.evidenceCount} evidence)`);
    });

    // Log tax keywords by type
    const keywordsByType = new Map<string, typeof results.taxKeywords>();
    results.taxKeywords.forEach(kw => {
      if (!keywordsByType.has(kw.type)) {
        keywordsByType.set(kw.type, []);
      }
      keywordsByType.get(kw.type)!.push(kw);
    });

    console.log(`🏷️  Tax Keywords by Type:`);
    keywordsByType.forEach((keywords, type) => {
      console.log(`  📌 ${type}: ${keywords.length} keywords`);
      keywords.forEach(kw => {
        console.log(`    Line ${kw.lineIndex}: "${kw.keyword}" (${kw.language}, conf: ${kw.confidence.toFixed(2)})`);
      });
    });

    // Log numeric patterns by type
    const numbersByType = new Map<string, typeof results.numericPatterns>();
    results.numericPatterns.forEach(np => {
      if (!numbersByType.has(np.type)) {
        numbersByType.set(np.type, []);
      }
      numbersByType.get(np.type)!.push(np);
    });

    console.log(`🔢 Numeric Patterns by Type:`);
    numbersByType.forEach((patterns, type) => {
      console.log(`  📊 ${type}: ${patterns.length} patterns`);
      patterns.forEach(np => {
        console.log(`    Line ${np.lineIndex}: "${np.value}" → ${np.normalizedValue} (conf: ${np.confidence.toFixed(2)})`);
      });
    });

    // Log structural keywords
    if (results.structuralKeywords.length > 0) {
      console.log(`🏗️  Structural Keywords:`);
      results.structuralKeywords.forEach(sk => {
        console.log(`    Line ${sk.lineIndex}: "${sk.keyword}" (${sk.type}, conf: ${sk.confidence.toFixed(2)})`);
      });
    }
  }

  /**
   * Log table structures with details
   */
  private logTableStructures(structures: TableStructure[]): void {
    console.log(`\n🗂️  [Stage 2 Details] Table Structure Analysis:`);
    
    if (structures.length === 0) {
      console.log(`  ⚠️  No table structures detected`);
      return;
    }

    structures.forEach((structure, index) => {
      console.log(`\n  📋 Structure ${index + 1}: ${structure.type.toUpperCase()}`);
      console.log(`    🎯 Confidence: ${structure.confidence.toFixed(2)}`);
      console.log(`    📍 Elements: ${structure.elements.length}`);
      console.log(`    📦 Bounding Box: [${structure.boundingBox.map(n => n.toFixed(1)).join(', ')}]`);
      
      // Log grid info if available
      if (structure.gridInfo) {
        console.log(`    🔲 Grid: ${structure.gridInfo.rows}×${structure.gridInfo.columns}`);
        if (structure.gridInfo.headerRow !== undefined) {
          console.log(`    📄 Header Row: ${structure.gridInfo.headerRow}`);
        }
        if (structure.gridInfo.dataRows.length > 0) {
          console.log(`    📊 Data Rows: [${structure.gridInfo.dataRows.join(', ')}]`);
        }
      }

      // Log metadata
      if (structure.metadata) {
        console.log(`    🏷️  Language: ${structure.metadata.detectedLanguage || 'unknown'}`);
        console.log(`    🎯 Primary Keyword: ${structure.metadata.primaryTaxKeyword || 'unknown'}`);
        console.log(`    📈 Structure Score: ${structure.metadata.structureScore.toFixed(2)}`);
        console.log(`    📐 Alignment Score: ${structure.metadata.alignmentScore.toFixed(2)}`);
      }

      // Log elements
      console.log(`    📝 Elements:`);
      structure.elements.forEach((element, elemIndex) => {
        const hasKeyword = element.containsTaxKeyword ? '🏷️ ' : '';
        const hasNumber = element.containsNumericValue ? '🔢' : '';
        console.log(`      ${elemIndex + 1}. Line ${element.lineIndex}: ${hasKeyword}${hasNumber}"${element.text.substring(0, 40)}${element.text.length > 40 ? '...' : ''}" (conf: ${element.confidence.toFixed(2)})`);
      });
    });
  }

  /**
   * Log detected tables with column mapping details
   */
  private logDetectedTables(tables: TaxTable[], stage: string): void {
    console.log(`\n📊 [${stage} Details] Tax Table Detection Results:`);
    
    if (tables.length === 0) {
      console.log(`  ⚠️  No tax tables detected in ${stage}`);
      return;
    }

    tables.forEach((table, index) => {
      console.log(`\n  📋 Table ${index + 1} (ID: ${table.id})`);
      console.log(`    🎯 Overall Confidence: ${table.confidence.toFixed(2)}`);
      console.log(`    📄 Header Line ${table.header.index}: "${table.header.line.text}"`);
      console.log(`    📊 Data Rows: ${table.rows.length}`);
      
      // Log totals
      console.log(`    💰 Totals:`);
      console.log(`      Net: ${table.totals.totalNet.toFixed(2)}`);
      console.log(`      Tax: ${table.totals.totalTax.toFixed(2)}`);
      console.log(`      Gross: ${table.totals.totalGross.toFixed(2)}`);

      // Log each row
      console.log(`    📝 Tax Breakdown:`);
      table.rows.forEach((row, rowIndex) => {
        const mathCheck = Math.abs((row.net + row.tax) - row.gross) < 0.02 ? '✅' : '❌';
        const rateCheck = Math.abs((row.tax / row.net * 100) - row.rate) < 1 ? '✅' : '❌';
        console.log(`      Row ${rowIndex + 1}: ${row.code || row.rate + '%'} | Rate: ${row.rate}% | Net: ${row.net} | Tax: ${row.tax} | Gross: ${row.gross} | Conf: ${row.confidence.toFixed(2)} ${mathCheck}${rateCheck}`);
      });
    });
  }

  /**
   * Log final merged results with deduplication info
   */
  private logFinalResults(tables: TaxTable[]): void {
    console.log(`\n🏁 [Final Results] Merged Tax Table Detection Summary:`);
    
    if (tables.length === 0) {
      console.log(`  ❌ No tax tables detected in entire process`);
      return;
    }

    // Group by detection method
    const byMethod = new Map<string, TaxTable[]>();
    tables.forEach(table => {
      const method = table.id.includes('enhanced_3stage') ? '3-Stage' : 
                    table.id.includes('header_context') ? 'Header-Context' : 
                    'Traditional';
      if (!byMethod.has(method)) {
        byMethod.set(method, []);
      }
      byMethod.get(method)!.push(table);
    });

    console.log(`  📈 Detection Method Summary:`);
    byMethod.forEach((tables, method) => {
      const avgConf = tables.reduce((sum, t) => sum + t.confidence, 0) / tables.length;
      const totalRows = tables.reduce((sum, t) => sum + t.rows.length, 0);
      console.log(`    ${method}: ${tables.length} tables, ${totalRows} total rows, avg confidence: ${avgConf.toFixed(2)}`);
    });

    // Overall statistics
    const totalRows = tables.reduce((sum, t) => sum + t.rows.length, 0);
    const avgConfidence = tables.reduce((sum, t) => sum + t.confidence, 0) / tables.length;
    const totalTaxAmount = tables.reduce((sum, t) => sum + t.totals.totalTax, 0);
    
    console.log(`\n  📊 Overall Statistics:`);
    console.log(`    Total Tables: ${tables.length}`);
    console.log(`    Total Tax Rows: ${totalRows}`);
    console.log(`    Average Confidence: ${avgConfidence.toFixed(2)}`);
    console.log(`    Total Tax Amount: ${totalTaxAmount.toFixed(2)}`);

    // Highlight best table
    const bestTable = tables.reduce((best, current) => 
      current.confidence > best.confidence ? current : best
    );
    console.log(`\n  🏆 Best Table:`);
    console.log(`    ID: ${bestTable.id}`);
    console.log(`    Confidence: ${bestTable.confidence.toFixed(2)}`);
    console.log(`    Rows: ${bestTable.rows.length}`);
    console.log(`    Method: ${bestTable.id.includes('enhanced_3stage') ? '3-Stage Detection' : bestTable.id.includes('header_context') ? 'Header-Context Detection' : 'Traditional Detection'}`);

    // Show detected patterns
    console.log(`\n  🔍 Detected Patterns:`);
    tables.forEach((table, index) => {
      const patterns = this.analyzeDetectedPatterns(table);
      console.log(`    Table ${index + 1}: ${patterns.join(', ')}`);
    });
  }

  /**
   * Log column type detection results
   */
  private logColumnTypeMapping(mapping: ColumnTypeMapping, structureType: string): void {
    console.log(`\n🔢 [Column Detection] ${structureType} Column Mapping:`);
    
    if (mapping.taxRate) {
      console.log(`  📊 Tax Rate Column ${mapping.taxRate.columnIndex}: confidence ${mapping.taxRate.confidence.toFixed(2)}`);
      console.log(`    Values: [${mapping.taxRate.values.join(', ')}]`);
    }
    
    if (mapping.netAmount) {
      console.log(`  💚 Net Amount Column ${mapping.netAmount.columnIndex}: confidence ${mapping.netAmount.confidence.toFixed(2)}`);
      console.log(`    Values: [${mapping.netAmount.values.join(', ')}]`);
    }
    
    if (mapping.taxAmount) {
      console.log(`  🔴 Tax Amount Column ${mapping.taxAmount.columnIndex}: confidence ${mapping.taxAmount.confidence.toFixed(2)}`);
      console.log(`    Values: [${mapping.taxAmount.values.join(', ')}]`);
    }
    
    if (mapping.grossAmount) {
      console.log(`  💙 Gross Amount Column ${mapping.grossAmount.columnIndex}: confidence ${mapping.grossAmount.confidence.toFixed(2)}`);
      console.log(`    Values: [${mapping.grossAmount.values.join(', ')}]`);
    }
    
    if (mapping.description) {
      console.log(`  📝 Description Column ${mapping.description.columnIndex}: confidence ${mapping.description.confidence.toFixed(2)}`);
    }
  }

  /**
   * Analyze detected patterns for summary
   */
  private analyzeDetectedPatterns(table: TaxTable): string[] {
    const patterns: string[] = [];
    
    // Pattern 1: Single line tax
    if (table.rows.length === 1) {
      patterns.push('Single Line Tax');
    }
    
    // Pattern 2: Multi-tier tax
    if (table.rows.length > 1) {
      patterns.push('Multi-Tier Tax');
    }
    
    // Pattern 3: By language keywords
    const headerText = table.header.line.text.toLowerCase();
    if (headerText.includes('alv')) {
      patterns.push('Finnish ALV Table');
    } else if (headerText.includes('moms')) {
      patterns.push('Swedish MOMS Table');
    } else if (headerText.includes('tva')) {
      patterns.push('French TVA Table');
    } else if (headerText.includes('iva')) {
      patterns.push('Italian/Spanish IVA Table');
    } else if (headerText.includes('ust') || headerText.includes('mwst')) {
      patterns.push('German UST/MwSt Table');
    } else if (headerText.includes('vat') || headerText.includes('tax')) {
      patterns.push('English VAT/Tax Table');
    }
    
    // Pattern 4: Structure type
    if (table.id.includes('enhanced_3stage')) {
      patterns.push('3-Stage Detection');
    } else if (table.id.includes('header_context')) {
      patterns.push('Header-Context Detection');
    } else {
      patterns.push('Traditional Detection');
    }
    
    // Pattern 5: Mathematical consistency
    const mathConsistent = table.rows.every(row => 
      Math.abs((row.net + row.tax) - row.gross) < 0.02
    );
    if (mathConsistent) {
      patterns.push('Math Consistent');
    }
    
    return patterns.length > 0 ? patterns : ['Unknown Pattern'];
  }
}