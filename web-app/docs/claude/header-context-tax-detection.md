# Header-Context Tax Rate Detection Strategy

## 概要
テーブルヘッダーに税率情報があるが、データ行に％表記がない場合の検出戦略

## 解決策1: Header Rate Propagation

### 1.1 ヘッダー税率抽出
```typescript
interface HeaderTaxRateExtractor {
  extractRatesFromHeader(headerLine: string): TaxRateMapping[];
  extractPositionalRates(headerLines: string[]): ColumnTaxRate[];
}

interface TaxRateMapping {
  rate: number;           // 24, 14
  category: string;       // "A", "B", "Standard", "Reduced"
  position: number;       // Column index
  confidence: number;
}

// 例: "A 24% | B 14% | NET | TAX"
const headerRates = [
  { rate: 24, category: "A", position: 0, confidence: 0.95 },
  { rate: 14, category: "B", position: 1, confidence: 0.95 }
];
```

### 1.2 空間的マッピング
```typescript
interface SpatialColumnMapper {
  mapHeaderToDataColumns(
    headerLine: TextLine,
    dataLines: TextLine[]
  ): ColumnMapping[];
  
  calculateColumnBoundaries(
    headerPositions: number[]
  ): ColumnBoundary[];
}

interface ColumnBoundary {
  start: number;
  end: number;
  taxRate?: number;
  columnType: 'category' | 'net' | 'tax' | 'gross';
}
```

## 解決策2: Pattern-Based Rate Association

### 2.1 Multi-Line Header Analysis
```typescript
class MultiLineHeaderAnalyzer {
  // 複数行にわたるヘッダー情報を統合
  analyzeHeaderContext(
    candidateLines: TextLine[],
    contextRange: number = 3
  ): HeaderContext {
    
    const rateLines = this.findRateDeclarationLines(candidateLines);
    const structureLines = this.findTableStructureLines(candidateLines);
    
    return this.mergeHeaderContext(rateLines, structureLines);
  }
  
  private findRateDeclarationLines(lines: TextLine[]): RateDeclaration[] {
    const patterns = [
      /(?:standard|normal|regular)\s*(?:rate|vat|tax)?\s*:?\s*(\d+)%/i,
      /(?:reduced|lower|minimum)\s*(?:rate|vat|tax)?\s*:?\s*(\d+)%/i,
      /([A-Z])\s*(?:category|rate)?\s*:?\s*(\d+)%/i,
      /(\d+)%\s*(?:standard|normal|vat|tax)/i
    ];
    
    return lines.filter(line => 
      patterns.some(pattern => pattern.test(line.text))
    ).map(line => this.extractRateDeclaration(line));
  }
}
```

### 2.2 Contextual Rate Inference
```typescript
interface ContextualRateInferrer {
  // 国別標準税率からの推定
  inferFromCountryStandards(
    detectedRates: number[],
    country: string
  ): TaxRateStandardization;
  
  // 周辺テキストからの推定
  inferFromSurroundingText(
    dataLine: TextLine,
    contextLines: TextLine[]
  ): InferredTaxRate;
}

// 例: フィンランドの標準税率
const FINLAND_TAX_RATES = {
  standard: 24,      // 標準税率
  reduced: [14, 10], // 軽減税率
  zero: 0           // 非課税
};
```

## 解決策3: Numeric Pattern Validation

### 3.1 逆算による税率推定
```typescript
class TaxRateCalculationValidator {
  // Tax = Net * Rate / 100 から税率を逆算
  calculateImpliedTaxRate(net: number, tax: number): number {
    if (net <= 0) return 0;
    return Math.round((tax / net) * 100 * 100) / 100; // 小数点2位まで
  }
  
  // 計算された税率と既知の標準税率をマッチング
  matchToStandardRates(
    calculatedRate: number,
    standardRates: number[],
    tolerance: number = 0.5
  ): number | null {
    return standardRates.find(rate => 
      Math.abs(rate - calculatedRate) <= tolerance
    ) || null;
  }
}

// 例: 
// Net: 29.52, Tax: 4.13
// Implied Rate: (4.13 / 29.52) * 100 = 13.99% ≈ 14%
```

## 解決策4: Template-Based Detection

### 4.1 レシート形式テンプレート
```typescript
interface ReceiptTemplatePattern {
  merchantPattern: RegExp;
  country: string;
  expectedTaxRates: number[];
  tableStructure: TableStructureTemplate;
}

interface TableStructureTemplate {
  headerPatterns: string[];
  dataRowPattern: RegExp;
  columnMapping: {
    [columnIndex: number]: 'category' | 'net' | 'tax' | 'gross';
  };
  rateAssignment: {
    [categoryCode: string]: number;
  };
}

// フィンランドLidlテンプレート例
const LIDL_FINLAND_TEMPLATE: ReceiptTemplatePattern = {
  merchantPattern: /lidl/i,
  country: 'FI',
  expectedTaxRates: [24, 14, 10, 0],
  tableStructure: {
    headerPatterns: ['alv', 'brutto', 'netto', 'vero'],
    dataRowPattern: /([A-Z])\s*(\d+)\s*([\d,.]+)\s*([\d,.]+)\s*([\d,.]+)/,
    columnMapping: {
      0: 'category',  // A, B
      1: 'rate',      // 24, 14 (often missing %)
      2: 'gross',     // 1.97, 33.65
      3: 'net',       // 1.59, 29.52
      4: 'tax'        // 0.38, 4.13
    },
    rateAssignment: {
      'A': 24,  // Aカテゴリは通常24%
      'B': 14   // Bカテゴリは通常14%
    }
  }
};
```

## 解決策5: Machine Learning Approach

### 5.1 税率予測モデル
```typescript
interface TaxRatePredictor {
  // 特徴量ベースの税率予測
  predictTaxRate(features: TaxRateFeatures): TaxRatePrediction;
  
  // 履歴データからの学習
  trainFromHistoricalData(samples: TaxRateSample[]): void;
}

interface TaxRateFeatures {
  merchantName: string;
  country: string;
  categoryCode: string;      // A, B, C
  netAmount: number;
  taxAmount: number;
  calculatedRate: number;
  contextKeywords: string[]; // ['standard', 'reduced', etc.]
}

interface TaxRatePrediction {
  predictedRate: number;
  confidence: number;
  rationale: string;
}
```

## 統合実装例

### Enhanced Tax Table Detector
```typescript
class EnhancedTaxTableDetector extends TaxTableDetector {
  
  async detectTaxTables(textLines: TextLine[]): Promise<TaxTable[]> {
    // 1. 従来のパターン検出
    const standardTables = super.detectTaxTables(textLines);
    
    // 2. Header-Context検出
    const headerContextTables = this.detectHeaderContextTables(textLines);
    
    // 3. 結果をマージ
    return this.mergeTableDetections(standardTables, headerContextTables);
  }
  
  private detectHeaderContextTables(textLines: TextLine[]): TaxTable[] {
    const tables: TaxTable[] = [];
    
    // ヘッダー候補を検出
    const headerCandidates = this.findHeaderCandidates(textLines);
    
    for (const header of headerCandidates) {
      // ヘッダーから税率情報を抽出
      const headerRates = this.extractHeaderRates(header);
      
      if (headerRates.length > 0) {
        // データ行を検出
        const dataRows = this.findAssociatedDataRows(header, textLines);
        
        // 税率を適用してテーブル構築
        const table = this.buildTableWithHeaderRates(
          header, 
          headerRates, 
          dataRows
        );
        
        if (table) tables.push(table);
      }
    }
    
    return tables;
  }
  
  private extractHeaderRates(header: TextLine): TaxRateMapping[] {
    const rates: TaxRateMapping[] = [];
    const text = header.text;
    
    // パターン1: "A 24% B 14%" 形式
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
    
    // パターン2: "Standard 24% Reduced 14%" 形式
    const namedRatePattern = /(standard|reduced|normal)\s*(\d+)\s*%/gi;
    while ((match = namedRatePattern.exec(text)) !== null) {
      const category = this.mapNamedRateToCategory(match[1]);
      rates.push({
        rate: parseInt(match[2]),
        category,
        position: match.index,
        confidence: 0.85
      });
    }
    
    return rates;
  }
  
  private buildTableWithHeaderRates(
    header: TextLine,
    headerRates: TaxRateMapping[],
    dataRows: TextLine[]
  ): TaxTable | null {
    
    const tableRows: TaxTableRow[] = [];
    
    for (const dataLine of dataRows) {
      // 数値を抽出
      const numbers = this.extractNumbersFromLine(dataLine);
      
      if (numbers.length >= 3) { // 最低限 net, tax, gross
        // カテゴリコードを特定
        const categoryMatch = dataLine.text.match(/^([A-Z])/);
        const category = categoryMatch ? categoryMatch[1] : null;
        
        // ヘッダーから対応する税率を取得
        const matchingRate = headerRates.find(r => 
          r.category === category
        );
        
        if (matchingRate) {
          const row: TaxTableRow = {
            code: category,
            rate: matchingRate.rate,
            gross: numbers[0],
            net: numbers[1], 
            tax: numbers[2],
            confidence: 0.8,
            lineIndex: dataLine.line_index || 0
          };
          
          // 数学的検証
          if (this.validateRowMath(row)) {
            tableRows.push(row);
          }
        }
      }
    }
    
    if (tableRows.length > 0) {
      return new TaxTable(header, tableRows);
    }
    
    return null;
  }
}
```

## テスト戦略

### 1. パターン別テストケース
```typescript
const TEST_CASES = [
  {
    name: "Finnish Lidl with category rates",
    header: "A 24% B 14% Brutto Netto Vero",
    dataRows: [
      "A 1,97 1,59 0,38",
      "B 33,65 29,52 4,13"
    ],
    expected: {
      totalTax: 4.51,
      totalNet: 31.11,
      breakdown: [
        {rate: 24, tax: 0.38, net: 1.59},
        {rate: 14, tax: 4.13, net: 29.52}
      ]
    }
  },
  {
    name: "German format with named rates",
    header: "Standard 19% Ermäßigt 7% Brutto Netto Steuer", 
    dataRows: [
      "Standard 10,50 8,82 1,68",
      "Ermäßigt 2,14 2,00 0,14"
    ],
    expected: {
      totalTax: 1.82,
      totalNet: 10.82,
      breakdown: [
        {rate: 19, tax: 1.68, net: 8.82},
        {rate: 7, tax: 0.14, net: 2.00}
      ]
    }
  }
];
```

この包括的なアプローチにより、％表記のないテーブルでも正確な税率検出が可能になります。