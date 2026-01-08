# Enhanced Tax Table Detection Implementation Plan
## 現在の実装に適合した詳細修正案

### Overview
現在の税務テーブル抽出実装を3段階の汎用的検出ロジックに再構築します：
1. キーワード検出 (Keyword Detection)
2. テーブル構造認識 (Table Structure Recognition)  
3. Tax rate, Tax amount, Net, Grossの検出 (Column Type Detection)

---

## Stage 1: キーワード検出エンジンの強化

### 1.1 既存実装の活用と拡張

**現在のファイル修正:**
- `src/services/keywords/centralized-keyword-config.ts`
- `src/services/keywords/language-keywords.ts`

```typescript
// Enhanced keyword detection using existing infrastructure
interface TaxKeywordDetectionResult {
  taxKeywords: Array<{
    keyword: string;
    language: SupportedLanguage;
    confidence: number;
    boundingBox: BoundingBox;
    type: 'primary_tax' | 'net_amount' | 'gross_amount' | 'tax_rate';
  }>;
  numericPatterns: Array<{
    value: string;
    type: 'percentage' | 'currency' | 'decimal';
    confidence: number;
    boundingBox: BoundingBox;
  }>;
  structuralKeywords: Array<{
    keyword: string;
    type: 'header' | 'separator' | 'total';
    boundingBox: BoundingBox;
  }>;
}

class EnhancedKeywordDetector {
  constructor(
    private keywordConfig: CentralizedKeywordConfig,
    private languageKeywords: LanguageKeywords
  ) {}

  detectTaxKeywords(textLines: ProcessedTextLine[]): TaxKeywordDetectionResult {
    // 1. Multi-language tax keyword detection using existing config
    // 2. Numeric pattern detection with type classification
    // 3. Structural keyword identification
  }
}
```

### 1.2 パターン検出の強化

```typescript
// Extend existing pattern detection
class TaxPatternDetector {
  private patterns = {
    percentage: /(\d+[.,]?\d*)\s*%/g,
    currency: /([\d.,]+)\s*([€$£¥]|EUR|USD|SEK|DKK)/g,
    decimal: /\b(\d+[.,]\d{2})\b/g,
    taxRate: /(ALV|VAT|MOMS|TVA|IVA|UST|MwSt)[.\s]*(\d+[.,]?\d*)\s*%/gi,
    taxAmount: /(TAX|VERO|IMPOSTA|STEUER)[.\s]*([\d.,]+)/gi
  };

  detectPatterns(text: string): NumericPattern[] {
    // Enhanced pattern detection with confidence scoring
  }
}
```

---

## Stage 2: テーブル構造認識の実装

### 2.1 空間解析エンジンの構築

**新規ファイル:** `src/services/extraction/spatial-table-analyzer.ts`

```typescript
interface TableStructure {
  type: 'horizontal_table' | 'vertical_list' | 'single_line' | 'mixed';
  boundingBox: BoundingBox;
  confidence: number;
  elements: SpatialElement[];
  gridInfo?: {
    rows: number;
    columns: number;
    cellBounds: BoundingBox[][];
  };
}

class SpatialTableAnalyzer {
  analyzeStructure(
    taxKeywords: TaxKeywordDetectionResult,
    textLines: ProcessedTextLine[]
  ): TableStructure[] {
    // 1. Spatial clustering based on bounding box proximity
    // 2. Grid structure detection using coordinate alignment
    // 3. Table type classification
    return this.detectTableTypes(clusteredElements);
  }

  private detectHorizontalTable(elements: SpatialElement[]): TableStructure | null {
    // Detect header row + data rows pattern (ALV VEROTON VERO VEROLLINEN type)
    const headerCandidates = this.findAlignedElements(elements, 'horizontal');
    const dataCandidates = this.findDataRows(headerCandidates, elements);
    
    if (headerCandidates.length >= 3 && dataCandidates.length >= 1) {
      return {
        type: 'horizontal_table',
        confidence: this.calculateConfidence(headerCandidates, dataCandidates),
        elements: [...headerCandidates, ...dataCandidates],
        gridInfo: this.calculateGridInfo(headerCandidates, dataCandidates)
      };
    }
    return null;
  }

  private detectVerticalList(elements: SpatialElement[]): TableStructure | null {
    // Detect multiple single-line tax items (TAX 1...TAX 2... type)
    const taxLines = elements.filter(el => el.containsTaxKeyword);
    const verticallyAligned = this.checkVerticalAlignment(taxLines);
    
    if (taxLines.length >= 2 && verticallyAligned) {
      return {
        type: 'vertical_list',
        confidence: this.calculateListConfidence(taxLines),
        elements: taxLines
      };
    }
    return null;
  }

  private detectSingleLine(elements: SpatialElement[]): TableStructure | null {
    // Detect single line with all tax info (TAX $ 13.37 type)
    const singleLineCandidates = elements.filter(el => 
      el.containsTaxKeyword && el.containsNumericValue
    );
    
    return singleLineCandidates.length === 1 ? {
      type: 'single_line',
      confidence: 0.9,
      elements: singleLineCandidates
    } : null;
  }
}
```

### 2.2 既存実装との統合

**修正ファイル:** `src/services/extraction/enhanced-tax-table-detector.ts`

```typescript
// Integrate spatial analysis into existing detector
class EnhancedTaxTableDetector {
  constructor(
    private keywordDetector: EnhancedKeywordDetector,
    private spatialAnalyzer: SpatialTableAnalyzer,
    private columnTypeDetector: ColumnTypeDetector // Stage 3
  ) {}

  async detectTaxTables(textLines: ProcessedTextLine[]): Promise<TaxTable[]> {
    // Stage 1: Keyword Detection
    const keywordResults = this.keywordDetector.detectTaxKeywords(textLines);
    
    // Stage 2: Structure Recognition  
    const tableStructures = this.spatialAnalyzer.analyzeStructure(keywordResults, textLines);
    
    // Stage 3: Column Type Detection
    const detectedTables = [];
    for (const structure of tableStructures) {
      const columnTypes = await this.columnTypeDetector.detectColumnTypes(structure);
      detectedTables.push(this.buildTaxTable(structure, columnTypes));
    }
    
    return detectedTables;
  }
}
```

---

## Stage 3: カラムタイプ検出の実装

### 3.1 順序無依存カラム検出

**新規ファイル:** `src/services/extraction/column-type-detector.ts`

```typescript
interface ColumnTypeMapping {
  taxRate?: {
    columnIndex: number;
    confidence: number;
    values: string[];
  };
  netAmount?: {
    columnIndex: number;
    confidence: number;
    values: number[];
  };
  taxAmount?: {
    columnIndex: number;
    confidence: number;
    values: number[];
  };
  grossAmount?: {
    columnIndex: number;
    confidence: number;
    values: number[];
  };
}

class ColumnTypeDetector {
  async detectColumnTypes(tableStructure: TableStructure): Promise<ColumnTypeMapping> {
    switch (tableStructure.type) {
      case 'horizontal_table':
        return this.detectHorizontalTableColumns(tableStructure);
      case 'vertical_list':
        return this.detectVerticalListColumns(tableStructure);
      case 'single_line':
        return this.detectSingleLineColumns(tableStructure);
      default:
        return this.detectMixedStructureColumns(tableStructure);
    }
  }

  private detectHorizontalTableColumns(structure: TableStructure): ColumnTypeMapping {
    const columns = this.extractColumns(structure);
    const mapping: ColumnTypeMapping = {};
    
    // 1. Percentage column detection (tax rate)
    const percentageColumns = columns.filter(col => 
      col.values.some(val => val.includes('%'))
    );
    if (percentageColumns.length === 1) {
      mapping.taxRate = {
        columnIndex: percentageColumns[0].index,
        confidence: 0.95,
        values: percentageColumns[0].values
      };
    }
    
    // 2. Amount column type inference
    const numericColumns = columns.filter(col => 
      col.values.every(val => this.isNumeric(val))
    );
    
    // Use mathematical relationships: net + tax ≈ gross
    const amountMappings = this.inferAmountColumns(numericColumns);
    Object.assign(mapping, amountMappings);
    
    // 3. Keyword proximity inference
    const keywordMappings = this.inferFromKeywordProximity(structure, mapping);
    this.mergeWithConfidence(mapping, keywordMappings);
    
    return mapping;
  }

  private inferAmountColumns(columns: Column[]): Partial<ColumnTypeMapping> {
    // Mathematical relationship detection
    for (let i = 0; i < columns.length; i++) {
      for (let j = 0; j < columns.length; j++) {
        for (let k = 0; k < columns.length; k++) {
          if (i !== j && j !== k && i !== k) {
            const isValidRelation = this.checkSumRelation(
              columns[i].numericValues,
              columns[j].numericValues,
              columns[k].numericValues
            );
            
            if (isValidRelation.confidence > 0.8) {
              return {
                netAmount: { columnIndex: i, confidence: isValidRelation.confidence, values: columns[i].numericValues },
                taxAmount: { columnIndex: j, confidence: isValidRelation.confidence, values: columns[j].numericValues },
                grossAmount: { columnIndex: k, confidence: isValidRelation.confidence, values: columns[k].numericValues }
              };
            }
          }
        }
      }
    }
    
    // Fallback: magnitude-based inference
    return this.inferByMagnitude(columns);
  }

  private checkSumRelation(net: number[], tax: number[], gross: number[]): { confidence: number } {
    let matches = 0;
    const tolerance = 0.01; // 1 cent tolerance
    
    for (let i = 0; i < Math.min(net.length, tax.length, gross.length); i++) {
      const calculatedGross = net[i] + tax[i];
      const difference = Math.abs(calculatedGross - gross[i]);
      if (difference <= tolerance || difference / gross[i] <= 0.001) {
        matches++;
      }
    }
    
    return {
      confidence: matches / Math.min(net.length, tax.length, gross.length)
    };
  }
}
```

### 3.2 既存融合エンジンとの統合

**修正ファイル:** `src/services/extraction/tax-breakdown-fusion-engine.ts`

```typescript
// Enhance existing fusion engine with new detection results
class TaxBreakdownFusionEngine {
  async fuseTaxEvidence(
    textLines: ProcessedTextLine[],
    detectedTables: TaxTable[], // From new 3-stage detection
    existingEvidence: TaxEvidence[]
  ): Promise<TaxBreakdown[]> {
    
    // Combine new table-based evidence with existing evidence
    const enhancedEvidence = [
      ...existingEvidence,
      ...this.convertTablesToEvidence(detectedTables)
    ];
    
    // Apply enhanced confidence scoring
    const weightedEvidence = this.applyTableStructureWeighting(enhancedEvidence);
    
    // Existing fusion logic with enhanced inputs
    return this.performFusion(weightedEvidence);
  }

  private convertTablesToEvidence(tables: TaxTable[]): TaxEvidence[] {
    return tables.flatMap(table => 
      this.extractEvidenceFromTable(table)
    );
  }

  private applyTableStructureWeighting(evidence: TaxEvidence[]): TaxEvidence[] {
    return evidence.map(ev => {
      // Boost confidence for evidence from well-structured tables
      if (ev.source === 'table_structure') {
        ev.confidence *= 1.2; // 20% confidence boost
      }
      return ev;
    });
  }
}
```

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
1. **Enhance keyword detection**
   - Extend `CentralizedKeywordConfig` with new tax patterns
   - Add numeric pattern detection to `language-keywords.ts`
   - Create `EnhancedKeywordDetector` class

2. **Implement spatial analysis**
   - Create `SpatialTableAnalyzer` with bounding box clustering
   - Add grid structure detection algorithms
   - Implement table type classification

### Phase 2: Core Detection (Week 3-4)
1. **Build column type detector**
   - Implement mathematical relationship inference
   - Add keyword proximity analysis
   - Create order-independent column mapping

2. **Integration testing**
   - Test against all 8 discovered patterns
   - Validate with actual receipt data
   - Performance optimization

### Phase 3: Enhancement (Week 5-6)
1. **Fusion engine integration**
   - Enhance existing `TaxBreakdownFusionEngine`
   - Add table-based evidence weighting
   - Implement confidence scoring improvements

2. **Edge case handling**
   - OCR error tolerance
   - Partial table detection
   - Multi-language mixed receipts

### Phase 4: Validation (Week 7-8)
1. **Comprehensive testing**
   - Test all language combinations
   - Validate column order variations
   - Performance benchmarking

2. **Documentation and deployment**
   - Update API documentation
   - Create migration guide
   - Production deployment

---

## Success Metrics

### Accuracy Targets
- **Finnish ALV tables**: 95% accurate detection
- **Swedish MOMS structures**: 90% accurate detection  
- **Multi-tier English tax**: 95% accurate detection
- **French TVA tables**: 85% accurate detection
- **Column order variations**: 90% accuracy regardless of order

### Performance Targets
- **Detection time**: < 500ms per receipt
- **Memory usage**: < 50MB peak during processing
- **CPU utilization**: < 80% during peak load

### Robustness Targets  
- **OCR error tolerance**: 80% accuracy with 10% OCR errors
- **Partial table handling**: 70% accuracy with 30% missing data
- **Multi-language receipts**: 85% accuracy in mixed-language scenarios

---

## Risk Mitigation

### Technical Risks
1. **Performance degradation**: Implement caching and lazy evaluation
2. **Memory consumption**: Use streaming processing for large receipts
3. **False positives**: Add validation layers and confidence thresholds

### Data Risks
1. **Unseen patterns**: Design extensible architecture for new patterns
2. **Language variations**: Maintain comprehensive keyword databases
3. **Format changes**: Implement adaptive learning mechanisms

### Integration Risks
1. **Breaking changes**: Maintain backward compatibility
2. **API changes**: Implement versioned endpoints
3. **Database migrations**: Plan incremental migration strategy