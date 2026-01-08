/**
 * Column Type Detector
 * 
 * Phase 1 implementation: Order-independent column type detection
 * Implements Stage 3 of the 3-stage tax table detection strategy
 */

import { TableStructure, SpatialElement } from './spatial-table-analyzer';

/**
 * Column type mapping result
 */
export interface ColumnTypeMapping {
  taxRate?: {
    columnIndex: number;
    confidence: number;
    values: string[];
    pattern: string;
  };
  netAmount?: {
    columnIndex: number;
    confidence: number;
    values: number[];
    currency?: string;
  };
  taxAmount?: {
    columnIndex: number;
    confidence: number;
    values: number[];
    currency?: string;
  };
  grossAmount?: {
    columnIndex: number;
    confidence: number;
    values: number[];
    currency?: string;
  };
  description?: {
    columnIndex: number;
    confidence: number;
    values: string[];
  };
}

/**
 * Column analysis result
 */
interface ColumnAnalysis {
  index: number;
  values: string[];
  numericValues: number[];
  type: 'percentage' | 'currency' | 'text' | 'mixed';
  confidence: number;
  patterns: {
    hasPercentage: boolean;
    hasCurrency: boolean;
    hasKeywords: boolean;
    isNumeric: boolean;
  };
}

/**
 * Mathematical relationship validation
 */
interface MathematicalRelation {
  netIndex: number;
  taxIndex: number;
  grossIndex: number;
  confidence: number;
  tolerance: number;
  matches: number;
  totalRows: number;
}

/**
 * Column type detector implementing Stage 3 of 3-stage detection
 */
export class ColumnTypeDetector {
  private readonly CURRENCY_SYMBOLS = ['$', '€', '£', '¥', 'kr', 'SEK', 'EUR', 'USD'];
  private readonly MATH_TOLERANCE = 0.02; // 2% tolerance for calculations
  private readonly MIN_CONFIDENCE = 0.6;

  /**
   * Main detection method implementing Stage 3 of 3-stage strategy
   */
  async detectColumnTypes(tableStructure: TableStructure): Promise<ColumnTypeMapping> {
    switch (tableStructure.type) {
      case 'horizontal_table':
        return this.detectHorizontalTableColumns(tableStructure);
      case 'vertical_list':
        return this.detectVerticalListColumns(tableStructure);
      case 'single_line':
        return this.detectSingleLineColumns(tableStructure);
      case 'mixed':
        return this.detectMixedStructureColumns(tableStructure);
      default:
        return {};
    }
  }

  /**
   * Detect column types in horizontal table structure
   */
  private detectHorizontalTableColumns(structure: TableStructure): ColumnTypeMapping {
    if (!structure.gridInfo) return {};

    // Step 1: Extract column data
    const columns = this.extractColumns(structure);
    if (columns.length === 0) return {};

    // Step 2: Analyze each column
    const columnAnalyses = columns.map(col => this.analyzeColumn(col, columns.length));

    // Step 3: Percentage column detection (tax rate)
    const mapping: ColumnTypeMapping = {};
    const taxRateColumn = this.findTaxRateColumn(columnAnalyses);
    if (taxRateColumn) {
      mapping.taxRate = taxRateColumn;
    }

    // Step 4: Amount column type inference using mathematical relationships
    const amountMappings = this.inferAmountColumns(columnAnalyses, structure);
    Object.assign(mapping, amountMappings);

    // Step 5: Keyword proximity inference
    const keywordMappings = this.inferFromKeywordProximity(structure, columnAnalyses);
    this.mergeWithConfidence(mapping, keywordMappings);

    // Step 6: Description column detection
    const descriptionColumn = this.findDescriptionColumn(columnAnalyses);
    if (descriptionColumn) {
      mapping.description = descriptionColumn;
    }

    return mapping;
  }

  /**
   * Detect column types in vertical list structure
   */
  private detectVerticalListColumns(structure: TableStructure): ColumnTypeMapping {
    // For vertical lists, each line is essentially a single "row"
    // Extract patterns from each line
    const mapping: ColumnTypeMapping = {};
    const taxRates: string[] = [];
    const taxAmounts: number[] = [];

    for (const element of structure.elements) {
      const lineData = this.extractLineData(element.text);
      
      if (lineData.percentage) {
        taxRates.push(lineData.percentage);
      }
      if (lineData.amounts.length > 0) {
        taxAmounts.push(...lineData.amounts);
      }
    }

    // Set tax rate mapping if found
    if (taxRates.length > 0) {
      mapping.taxRate = {
        columnIndex: 0, // Virtual column for vertical structure
        confidence: 0.9,
        values: taxRates,
        pattern: 'vertical_list'
      };
    }

    // Set tax amount mapping if found
    if (taxAmounts.length > 0) {
      mapping.taxAmount = {
        columnIndex: 1, // Virtual column
        confidence: 0.85,
        values: taxAmounts
      };
    }

    return mapping;
  }

  /**
   * Detect column types in single line structure
   */
  private detectSingleLineColumns(structure: TableStructure): ColumnTypeMapping {
    if (structure.elements.length !== 1) return {};

    const element = structure.elements[0];
    const lineData = this.extractLineData(element.text);
    const mapping: ColumnTypeMapping = {};

    // Extract all data from single line
    if (lineData.percentage) {
      mapping.taxRate = {
        columnIndex: 0,
        confidence: 0.9,
        values: [lineData.percentage],
        pattern: 'single_line'
      };
    }

    if (lineData.amounts.length > 0) {
      // In single line, usually just the tax amount
      mapping.taxAmount = {
        columnIndex: 1,
        confidence: 0.8,
        values: lineData.amounts
      };
    }

    return mapping;
  }

  /**
   * Detect column types in mixed structure
   */
  private detectMixedStructureColumns(structure: TableStructure): ColumnTypeMapping {
    // Try both horizontal and vertical analysis and merge results
    const horizontalResult = this.detectHorizontalTableColumns(structure);
    const verticalResult = this.detectVerticalListColumns(structure);

    // Merge results, preferring higher confidence values
    const mapping: ColumnTypeMapping = {};
    
    for (const key of ['taxRate', 'netAmount', 'taxAmount', 'grossAmount'] as const) {
      const horizontal = horizontalResult[key];
      const vertical = verticalResult[key];

      if (horizontal && vertical) {
        mapping[key] = (horizontal.confidence >= vertical.confidence ? horizontal : vertical) as any;
      } else {
        mapping[key] = (horizontal || vertical) as any;
      }
    }

    return mapping;
  }

  /**
   * Extract column data from table structure
   */
  private extractColumns(structure: TableStructure): Array<{
    index: number;
    values: string[];
    elements: SpatialElement[];
  }> {
    if (!structure.gridInfo) return [];

    const columns: Array<{ index: number; values: string[]; elements: SpatialElement[] }> = [];
    const numColumns = structure.gridInfo.columns;

    // Group elements by their X position to form columns
    const sortedElements = structure.elements.sort((a, b) => a.boundingBox[0] - b.boundingBox[0]);
    
    // Simple column detection based on X position
    const columnGroups: SpatialElement[][] = [];
    const columnWidth = numColumns > 0 ? 1.0 / numColumns : 1.0;

    for (let col = 0; col < numColumns; col++) {
      columnGroups[col] = [];
    }

    for (const element of sortedElements) {
      const relativeX = element.boundingBox[0] / (structure.boundingBox[2] || 1);
      const columnIndex = Math.min(Math.floor(relativeX / columnWidth), numColumns - 1);
      
      if (columnIndex >= 0 && columnIndex < numColumns) {
        columnGroups[columnIndex].push(element);
      }
    }

    // Convert to column format
    for (let i = 0; i < columnGroups.length; i++) {
      if (columnGroups[i].length > 0) {
        columns.push({
          index: i,
          values: columnGroups[i].map(el => el.text),
          elements: columnGroups[i]
        });
      }
    }

    return columns;
  }

  /**
   * Analyze individual column characteristics
   */
  private analyzeColumn(column: { values: string[] }, totalColumns: number): ColumnAnalysis {
    const values = column.values;
    const numericValues: number[] = [];
    
    let hasPercentage = false;
    let hasCurrency = false;
    let hasKeywords = false;
    let numericCount = 0;

    for (const value of values) {
      const text = value.toLowerCase();
      
      // Check for percentage
      if (text.includes('%')) {
        hasPercentage = true;
        const percentMatch = text.match(/(\d+(?:[.,]\d+)?)\s*%/);
        if (percentMatch) {
          const numValue = parseFloat(percentMatch[1].replace(',', '.'));
          if (!isNaN(numValue)) {
            numericValues.push(numValue);
            numericCount++;
          }
        }
      }
      
      // Check for currency
      const hasCurrencySymbol = this.CURRENCY_SYMBOLS.some(symbol => text.includes(symbol.toLowerCase()));
      if (hasCurrencySymbol) {
        hasCurrency = true;
        const amount = this.extractCurrencyAmount(text);
        if (amount !== null) {
          numericValues.push(amount);
          numericCount++;
        }
      } else {
        // Check for plain numeric values
        const numericMatch = text.match(/\b(\d+(?:[.,]\d{2})?)\b/);
        if (numericMatch) {
          const numValue = parseFloat(numericMatch[1].replace(',', '.'));
          if (!isNaN(numValue)) {
            numericValues.push(numValue);
            numericCount++;
          }
        }
      }

      // Check for keywords
      const taxKeywords = ['alv', 'vat', 'moms', 'tva', 'iva', 'ust', 'tax', 'vero', 'net', 'gross', 'brutto', 'netto'];
      if (taxKeywords.some(keyword => text.includes(keyword))) {
        hasKeywords = true;
      }
    }

    // Determine column type
    let type: 'percentage' | 'currency' | 'text' | 'mixed';
    if (hasPercentage && numericCount === values.length) {
      type = 'percentage';
    } else if (hasCurrency || (numericCount > values.length * 0.7 && !hasPercentage)) {
      type = 'currency';
    } else if (numericCount === 0) {
      type = 'text';
    } else {
      type = 'mixed';
    }

    // Calculate confidence
    let confidence = 0.5;
    if (type === 'percentage' && hasPercentage) confidence = 0.95;
    else if (type === 'currency' && hasCurrency) confidence = 0.9;
    else if (numericCount === values.length) confidence = 0.85;
    else if (numericCount > values.length * 0.5) confidence = 0.7;

    return {
      index: -1, // Will be set by caller
      values,
      numericValues,
      type,
      confidence,
      patterns: {
        hasPercentage,
        hasCurrency,
        hasKeywords,
        isNumeric: numericCount > values.length * 0.7
      }
    };
  }

  /**
   * Find tax rate column (contains percentages)
   */
  private findTaxRateColumn(analyses: ColumnAnalysis[]): ColumnTypeMapping['taxRate'] | null {
    const percentageColumns = analyses.filter(col => col.type === 'percentage');
    
    if (percentageColumns.length === 1) {
      const col = percentageColumns[0];
      return {
        columnIndex: col.index,
        confidence: col.confidence,
        values: col.values,
        pattern: 'percentage_detection'
      };
    } else if (percentageColumns.length === 0) {
      // Look for columns with percentage patterns even if mixed type
      const mixedWithPercent = analyses.filter(col => col.patterns.hasPercentage);
      if (mixedWithPercent.length === 1) {
        const col = mixedWithPercent[0];
        return {
          columnIndex: col.index,
          confidence: col.confidence * 0.8, // Reduce confidence for mixed type
          values: col.values,
          pattern: 'mixed_percentage_detection'
        };
      }
    }

    return null;
  }

  /**
   * Infer amount columns using mathematical relationships
   */
  private inferAmountColumns(analyses: ColumnAnalysis[], structure: TableStructure): Partial<ColumnTypeMapping> {
    const numericColumns = analyses.filter(col => col.patterns.isNumeric);
    
    if (numericColumns.length < 2) {
      return this.inferByMagnitude(numericColumns);
    }

    // Try to find mathematical relationships: net + tax = gross
    const relations = this.findMathematicalRelations(numericColumns);
    
    if (relations.length > 0) {
      // Use the best mathematical relationship
      const bestRelation = relations.reduce((best, current) => 
        current.confidence > best.confidence ? current : best
      );

      return {
        netAmount: {
          columnIndex: bestRelation.netIndex,
          confidence: bestRelation.confidence,
          values: numericColumns[bestRelation.netIndex].numericValues
        },
        taxAmount: {
          columnIndex: bestRelation.taxIndex,
          confidence: bestRelation.confidence,
          values: numericColumns[bestRelation.taxIndex].numericValues
        },
        grossAmount: {
          columnIndex: bestRelation.grossIndex,
          confidence: bestRelation.confidence,
          values: numericColumns[bestRelation.grossIndex].numericValues
        }
      };
    }

    // Fallback to magnitude-based inference
    return this.inferByMagnitude(numericColumns);
  }

  /**
   * Find mathematical relationships between columns
   */
  private findMathematicalRelations(columns: ColumnAnalysis[]): MathematicalRelation[] {
    const relations: MathematicalRelation[] = [];

    for (let i = 0; i < columns.length; i++) {
      for (let j = 0; j < columns.length; j++) {
        for (let k = 0; k < columns.length; k++) {
          if (i !== j && j !== k && i !== k) {
            const relation = this.checkSumRelation(
              columns[i].numericValues,
              columns[j].numericValues,
              columns[k].numericValues,
              i, j, k
            );

            if (relation.confidence > 0.7) {
              relations.push(relation);
            }
          }
        }
      }
    }

    return relations.sort((a, b) => b.confidence - a.confidence);
  }

  /**
   * Check if col1 + col2 ≈ col3 (net + tax = gross)
   */
  private checkSumRelation(
    values1: number[],
    values2: number[],
    values3: number[],
    index1: number,
    index2: number,
    index3: number
  ): MathematicalRelation {
    let matches = 0;
    const minLength = Math.min(values1.length, values2.length, values3.length);
    
    if (minLength === 0) {
      return {
        netIndex: index1,
        taxIndex: index2,
        grossIndex: index3,
        confidence: 0,
        tolerance: this.MATH_TOLERANCE,
        matches: 0,
        totalRows: 0
      };
    }

    for (let i = 0; i < minLength; i++) {
      const sum = values1[i] + values2[i];
      const target = values3[i];
      
      if (target > 0) {
        const difference = Math.abs(sum - target);
        const relativeError = difference / target;
        
        if (relativeError <= this.MATH_TOLERANCE) {
          matches++;
        }
      }
    }

    const confidence = minLength > 0 ? matches / minLength : 0;

    return {
      netIndex: index1,
      taxIndex: index2,
      grossIndex: index3,
      confidence,
      tolerance: this.MATH_TOLERANCE,
      matches,
      totalRows: minLength
    };
  }

  /**
   * Infer column types by amount magnitude
   */
  private inferByMagnitude(columns: ColumnAnalysis[]): Partial<ColumnTypeMapping> {
    if (columns.length === 0) return {};

    // Sort by average amount (ascending)
    const sortedColumns = columns
      .map((col, index) => ({
        ...col,
        index,
        avgAmount: col.numericValues.reduce((sum, val) => sum + val, 0) / col.numericValues.length || 0
      }))
      .sort((a, b) => a.avgAmount - b.avgAmount);

    const result: Partial<ColumnTypeMapping> = {};

    if (sortedColumns.length >= 3) {
      // Assume: smallest = tax, middle = net, largest = gross
      result.taxAmount = {
        columnIndex: sortedColumns[0].index,
        confidence: 0.7,
        values: sortedColumns[0].numericValues
      };
      result.netAmount = {
        columnIndex: sortedColumns[1].index,
        confidence: 0.7,
        values: sortedColumns[1].numericValues
      };
      result.grossAmount = {
        columnIndex: sortedColumns[2].index,
        confidence: 0.7,
        values: sortedColumns[2].numericValues
      };
    } else if (sortedColumns.length === 2) {
      // Assume: smaller = tax/net, larger = gross/total
      result.netAmount = {
        columnIndex: sortedColumns[0].index,
        confidence: 0.6,
        values: sortedColumns[0].numericValues
      };
      result.grossAmount = {
        columnIndex: sortedColumns[1].index,
        confidence: 0.6,
        values: sortedColumns[1].numericValues
      };
    }

    return result;
  }

  /**
   * Infer column types from keyword proximity
   */
  private inferFromKeywordProximity(
    structure: TableStructure,
    analyses: ColumnAnalysis[]
  ): Partial<ColumnTypeMapping> {
    const result: Partial<ColumnTypeMapping> = {};

    // Map keyword patterns to column types
    const keywordMappings = [
      { keywords: ['net', 'netto', 'veroton', 'ht'], type: 'netAmount' as const },
      { keywords: ['gross', 'brutto', 'verollinen', 'ttc'], type: 'grossAmount' as const },
      { keywords: ['tax', 'vero', 'tva', 'iva', 'ust', 'steuer'], type: 'taxAmount' as const }
    ];

    for (const analysis of analyses) {
      for (const { keywords, type } of keywordMappings) {
        const hasKeyword = keywords.some(keyword =>
          analysis.values.some(value => value.toLowerCase().includes(keyword))
        );

        if (hasKeyword && analysis.patterns.isNumeric) {
          result[type] = {
            columnIndex: analysis.index,
            confidence: 0.8,
            values: analysis.numericValues
          };
        }
      }
    }

    return result;
  }

  /**
   * Find description/text column
   */
  private findDescriptionColumn(analyses: ColumnAnalysis[]): ColumnTypeMapping['description'] | null {
    const textColumns = analyses.filter(col => col.type === 'text' || (col.type === 'mixed' && !col.patterns.isNumeric));
    
    if (textColumns.length === 1) {
      const col = textColumns[0];
      return {
        columnIndex: col.index,
        confidence: col.confidence,
        values: col.values
      };
    }

    return null;
  }

  /**
   * Extract data from a single text line
   */
  private extractLineData(text: string): {
    percentage: string | null;
    amounts: number[];
    keywords: string[];
  } {
    const result = {
      percentage: null as string | null,
      amounts: [] as number[],
      keywords: [] as string[]
    };

    // Extract percentage
    const percentMatch = text.match(/(\d+(?:[.,]\d+)?)\s*%/);
    if (percentMatch) {
      result.percentage = percentMatch[0];
    }

    // Extract amounts
    const amountMatches = text.matchAll(/(?:\$|€|£|¥|kr)?\s*(\d+(?:[.,]\d{2})?)/g);
    for (const match of amountMatches) {
      const amount = parseFloat(match[1].replace(',', '.'));
      if (!isNaN(amount)) {
        result.amounts.push(amount);
      }
    }

    // Extract keywords
    const taxKeywords = ['alv', 'vat', 'moms', 'tva', 'iva', 'ust', 'tax', 'steuer'];
    const lowerText = text.toLowerCase();
    for (const keyword of taxKeywords) {
      if (lowerText.includes(keyword)) {
        result.keywords.push(keyword);
      }
    }

    return result;
  }

  /**
   * Extract currency amount from text
   */
  private extractCurrencyAmount(text: string): number | null {
    const patterns = [
      /(?:\$|€|£|¥)\s*(\d+(?:[.,]\d{3})*(?:[.,]\d{2})?)/,
      /(\d+(?:[.,]\d{3})*(?:[.,]\d{2})?)\s*(?:€|kr|SEK|EUR|USD)/,
      /(\d+(?:[.,]\d{2})?)/
    ];

    for (const pattern of patterns) {
      const match = text.match(pattern);
      if (match) {
        const amount = match[1].replace(/,/g, '').replace(',', '.');
        const numValue = parseFloat(amount);
        if (!isNaN(numValue)) {
          return numValue;
        }
      }
    }

    return null;
  }

  /**
   * Merge mapping results with confidence-based precedence
   */
  private mergeWithConfidence(
    target: ColumnTypeMapping,
    source: Partial<ColumnTypeMapping>
  ): void {
    for (const key of ['taxRate', 'netAmount', 'taxAmount', 'grossAmount', 'description'] as const) {
      const sourceValue = source[key];
      const targetValue = target[key];

      if (sourceValue && (!targetValue || sourceValue.confidence > targetValue.confidence)) {
        target[key] = sourceValue as any;
      }
    }
  }
}