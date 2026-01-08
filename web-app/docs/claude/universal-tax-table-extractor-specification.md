# Universal Tax Table Extractor - 改修定義書

## 概要

多言語対応・多構造対応・税率別算出可能な汎用税務テーブル抽出システムの設計と実装

**目標**: 言語や構造に依存しない、パターン認識ベースの税務テーブル抽出エンジンの構築

## 現在の問題

### 1. 言語依存の問題
- フィンランド語の「ALV」キーワードが検出されない
- 言語特化パターンによる保守性の低下
- 新言語追加時の工数増大

### 2. 構造固定の問題
- 特定のテーブル構造にのみ対応
- ヘッダー位置やカラム順序の変更に非対応
- 縦横混在レイアウトへの対応不足

### 3. 計算精度の問題
- 税率別の詳細抽出ができない
- 合計値の整合性チェック不足
- 丸め誤差の考慮不足

## 設計方針

### Universal Design Pattern
```
言語非依存 → パターン認識 → 構造解析 → 税率別計算
```

### Core Principles
1. **Language Agnostic**: 数値・記号・位置関係による検出
2. **Structure Flexible**: 動的テーブル構造解析
3. **Rate-Specific**: 税率ごとの詳細抽出と検証

## アーキテクチャ設計

### 1. Universal Tax Table Detector

```typescript
export class UniversalTaxTableDetector {
  // Stage 1: Pattern-based Detection
  detectTaxTables(textLines: TextLine[]): TaxTableCandidate[]
  
  // Stage 2: Structure Analysis  
  analyzeTableStructure(candidate: TaxTableCandidate): TableStructure
  
  // Stage 3: Data Extraction
  extractTaxData(structure: TableStructure): TaxTableData
  
  // Stage 4: Rate-specific Calculation
  calculateByTaxRate(data: TaxTableData): TaxBreakdownResult
}
```

### 2. Language-Keyword Enhanced Pattern Recognition Engine

```typescript
interface UniversalPatterns {
  // 数値パターン（通貨記号・小数点対応）
  amountPattern: RegExp;
  
  // パーセンテージパターン
  percentagePattern: RegExp;
  
  // テーブル境界パターン
  tableBoundaryPattern: RegExp;
  
  // 行区切りパターン
  rowSeparatorPattern: RegExp;
  
  // 言語キーワードベースパターン
  languageKeywordPatterns: LanguageKeywordPatterns;
}

interface LanguageKeywordPatterns {
  // 税務キーワードパターン (ALV, VAT, MOMS, UST, TVA, IVA)
  taxKeywords: Record<SupportedLanguage, RegExp>;
  
  // ネット金額キーワード (NETTO, NET, VEROTON)
  netAmountKeywords: Record<SupportedLanguage, RegExp>;
  
  // グロス金額キーワード (BRUTTO, GROSS, VEROLLINEN)
  grossAmountKeywords: Record<SupportedLanguage, RegExp>;
  
  // 税率キーワード (RATE, SATZ, KANTA)
  taxRateKeywords: Record<SupportedLanguage, RegExp>;
}

const UNIVERSAL_PATTERNS: UniversalPatterns = {
  amountPattern: /\b\d{1,3}(?:[.,\s]\d{3})*[.,]\d{2}\b/g,
  percentagePattern: /\b(\d+(?:[.,]\d+)?)\s*%/g,
  tableBoundaryPattern: /^[-=\s]+$/,
  rowSeparatorPattern: /\s{2,}|\t+/,
  
  // 言語キーワードパターンは既存のCentralizedKeywordConfigから生成
  languageKeywordPatterns: {
    taxKeywords: CentralizedKeywordConfig.generateLanguageKeywordPatterns('tax'),
    netAmountKeywords: CentralizedKeywordConfig.generateLanguageKeywordPatterns('net_amount'),
    grossAmountKeywords: CentralizedKeywordConfig.generateLanguageKeywordPatterns('gross_amount'),
    taxRateKeywords: CentralizedKeywordConfig.generateLanguageKeywordPatterns('tax_rate')
  }
};
```

### 3. Table Structure Analyzer

```typescript
interface TableStructure {
  headerRow: number;
  dataRows: number[];
  columns: ColumnDefinition[];
  layout: 'horizontal' | 'vertical' | 'mixed';
}

interface ColumnDefinition {
  index: number;
  type: 'rate' | 'subtotal' | 'tax_amount' | 'total' | 'description';
  confidence: number;
  boundingBox: BoundingBox;
}

class TableStructureAnalyzer {
  analyze(textLines: TextLine[]): TableStructure {
    // 1. 数値密度分析
    const numericDensity = this.analyzeNumericDensity(textLines);
    
    // 2. 列構造推定
    const columns = this.inferColumnStructure(textLines);
    
    // 3. 行構造推定  
    const rows = this.inferRowStructure(textLines);
    
    // 4. レイアウト判定
    const layout = this.determineLayout(columns, rows);
    
    return { headerRow, dataRows, columns, layout };
  }
}
```

### 4. Multi-Rate Tax Calculator

```typescript
interface TaxRateCalculation {
  rate: number;
  subtotal: number;
  taxAmount: number;
  total: number;
  confidence: number;
  evidence: CalculationEvidence[];
}

interface TaxBreakdownResult {
  rates: TaxRateCalculation[];
  summary: {
    totalSubtotal: number;
    totalTaxAmount: number;
    grandTotal: number;
  };
  validation: ValidationResult;
  metadata: CalculationMetadata;
}

class MultiRateTaxCalculator {
  calculate(tableData: TaxTableData): TaxBreakdownResult {
    const rates: TaxRateCalculation[] = [];
    
    for (const row of tableData.dataRows) {
      const calculation = this.calculateSingleRate(row);
      
      // 整合性チェック
      if (this.validateCalculation(calculation)) {
        rates.push(calculation);
      }
    }
    
    // 合計計算
    const summary = this.calculateSummary(rates);
    
    // 全体検証
    const validation = this.validateOverall(rates, summary);
    
    return { rates, summary, validation };
  }
  
  private calculateSingleRate(row: TableRowData): TaxRateCalculation {
    const { rate, amounts } = row;
    
    // Pattern 1: subtotal + tax = total
    if (amounts.subtotal && amounts.taxAmount && amounts.total) {
      return this.validateTripleAmount(rate, amounts);
    }
    
    // Pattern 2: rate% of subtotal = tax
    if (amounts.subtotal && rate) {
      const calculatedTax = amounts.subtotal * (rate / 100);
      return this.calculateFromSubtotalAndRate(rate, amounts.subtotal, calculatedTax);
    }
    
    // Pattern 3: reverse calculation from total and rate
    if (amounts.total && rate) {
      const subtotal = amounts.total / (1 + rate / 100);
      const taxAmount = amounts.total - subtotal;
      return this.calculateFromTotalAndRate(rate, subtotal, taxAmount, amounts.total);
    }
    
    throw new Error(`Cannot calculate tax for rate ${rate}%`);
  }
}
```

## 実装段階

### Stage 1: Language-Keyword Enhanced Universal Pattern Detection

```typescript
// src/services/extraction/universal-tax-detector.ts
import { LanguageKeywords, SupportedLanguage } from '@/services/keywords/language-keywords';
import { CentralizedKeywordConfig } from '@/services/keywords/centralized-keyword-config';

export class UniversalTaxDetector {
  detectTaxRegions(textLines: TextLine[]): TaxRegion[] {
    const regions: TaxRegion[] = [];
    
    // 0. 言語検出 - 税務キーワードベース
    const detectedLanguage = this.detectLanguageFromTaxKeywords(textLines);
    
    // 1. 数値クラスター検出
    const numericClusters = this.findNumericClusters(textLines);
    
    // 2. パーセンテージ近傍検索
    const percentageRegions = this.findPercentageRegions(textLines);
    
    // 3. 言語キーワードベース税務領域検出（新機能）
    const languageBasedTaxRegions = this.findTaxRegionsByLanguageKeywords(textLines, detectedLanguage);
    
    // 4. クラスター結合（言語コンテキスト付き）
    const combinedRegions = this.combineRegionsWithLanguageContext(
      numericClusters, 
      percentageRegions, 
      languageBasedTaxRegions,
      detectedLanguage
    );
    
    // 5. 税務テーブル判定（言語キーワード強化）
    for (const region of combinedRegions) {
      if (this.isTaxTableRegionWithLanguageValidation(region, detectedLanguage)) {
        regions.push(region);
      }
    }
    
    return regions;
  }
  
  /**
   * 言語キーワードベースの税務領域検出
   * ALV、VAT、MOMS等の言語特化キーワードを活用
   */
  private findTaxRegionsByLanguageKeywords(textLines: TextLine[], language: SupportedLanguage): TaxRegion[] {
    const regions: TaxRegion[] = [];
    
    // 税務キーワード（ALV, VAT, MOMS, UST, TVA, IVA）を取得
    const taxKeywords = LanguageKeywords.getKeywords('tax', language);
    
    for (let i = 0; i < textLines.length; i++) {
      const line = textLines[i];
      
      // 税務キーワードを含む行を検出
      const containsTaxKeyword = taxKeywords.some(keyword => 
        line.text.toLowerCase().includes(keyword.toLowerCase())
      );
      
      if (containsTaxKeyword) {
        // 税務キーワード周辺の構造を分析
        const structureContext = this.analyzeTaxKeywordContext(textLines, i, language);
        
        if (structureContext.hasTableStructure) {
          regions.push({
            startLine: Math.max(0, i - structureContext.headerDistance),
            endLine: Math.min(textLines.length - 1, i + structureContext.dataRowCount),
            language: language,
            taxKeywordLine: i,
            confidence: structureContext.confidence,
            detectedKeywords: structureContext.detectedKeywords
          });
        }
      }
    }
    
    return regions;
  }
  
  /**
   * 税務キーワード周辺のテーブル構造分析
   * 例：ALV VEROTON VERO VEROLLINEN → ヘッダー構造検出
   */
  private analyzeTaxKeywordContext(textLines: TextLine[], keywordLineIndex: number, language: SupportedLanguage): TaxStructureContext {
    const line = textLines[keywordLineIndex];
    
    // 1. ヘッダー構造分析
    const headerStructure = this.analyzeHeaderStructureWithLanguageKeywords(line.text, language);
    
    // 2. データ行検出（キーワード行の後続行）
    const dataRowCount = this.countDataRowsWithLanguageContext(textLines, keywordLineIndex, language);
    
    // 3. 言語特化キーワードの検出
    const detectedKeywords = this.extractLanguageSpecificKeywords(line.text, language);
    
    return {
      hasTableStructure: headerStructure.columnCount >= 3 && dataRowCount >= 1,
      headerDistance: headerStructure.isHeader ? 0 : 1,
      dataRowCount: dataRowCount,
      confidence: this.calculateLanguageKeywordConfidence(headerStructure, dataRowCount, detectedKeywords),
      detectedKeywords: detectedKeywords
    };
  }
  
  /**
   * 言語キーワードを活用したヘッダー構造分析
   * フィンランド語例：ALV VEROTON VERO VEROLLINEN → 4カラム構造
   */
  private analyzeHeaderStructureWithLanguageKeywords(headerText: string, language: SupportedLanguage): HeaderStructureInfo {
    const keywords = [
      ...LanguageKeywords.getKeywords('tax', language),        // ALV, VAT, MOMS
      ...LanguageKeywords.getKeywords('net_amount', language),  // NETTO, VEROTON
      ...LanguageKeywords.getKeywords('tax_amount', language),  // VERO, STEUER
      ...LanguageKeywords.getKeywords('gross_amount', language) // BRUTTO, VEROLLINEN
    ];
    
    const foundKeywords = keywords.filter(keyword => 
      headerText.toLowerCase().includes(keyword.toLowerCase())
    );
    
    // 特別な構造パターンの検出
    const specialPatterns = this.detectSpecialStructurePatterns(headerText, language);
    
    return {
      isHeader: foundKeywords.length >= 2, // 2つ以上のキーワードでヘッダーと判定
      columnCount: Math.max(foundKeywords.length, specialPatterns.estimatedColumns),
      confidence: this.calculateHeaderKeywordConfidence(foundKeywords, specialPatterns),
      detectedColumns: this.mapKeywordsToColumnTypes(foundKeywords, language)
    };
  }
  
  /**
   * 言語検出（税務キーワードベース）
   * 既存のLanguageKeywords.detectLanguageを活用
   */
  private detectLanguageFromTaxKeywords(textLines: TextLine[]): SupportedLanguage {
    const allText = textLines.map(line => line.text).join(' ');
    const detectedLanguage = LanguageKeywords.detectLanguage(allText);
    
    // フォールバック：税務キーワード特化検出
    if (!detectedLanguage) {
      return this.detectLanguageFromSpecificTaxTerms(allText);
    }
    
    return detectedLanguage;
  }
  
  /**
   * 税務専用キーワードによる言語検出
   */
  private detectLanguageFromSpecificTaxTerms(text: string): SupportedLanguage {
    const lowerText = text.toLowerCase();
    
    // フィンランド語：ALV, VEROTON, VEROLLINEN
    if (/\b(alv|veroton|verollinen|arvonlisävero)\b/.test(lowerText)) return 'fi';
    
    // ドイツ語：UST, MWST, NETTO, BRUTTO
    if (/\b(ust|mwst|umsatzsteuer|netto|brutto)\b/.test(lowerText)) return 'de';
    
    // スウェーデン語：MOMS
    if (/\b(moms|mervärdesskatt)\b/.test(lowerText)) return 'sv';
    
    // フランス語：TVA
    if (/\b(tva|taxe)\b/.test(lowerText)) return 'fr';
    
    // イタリア語：IVA
    if (/\b(iva|imposta)\b/.test(lowerText)) return 'it';
    
    // スペイン語：IVA
    if (/\b(iva|impuesto)\b/.test(lowerText)) return 'es';
    
    // デフォルト：英語
    return 'en';
  }
  
  private findNumericClusters(textLines: TextLine[]): NumericCluster[] {
    const clusters: NumericCluster[] = [];
    const threshold = 50; // pixel distance
    
    for (let i = 0; i < textLines.length; i++) {
      const line = textLines[i];
      const amounts = this.extractAmounts(line.text);
      
      if (amounts.length >= 2) { // Multiple amounts suggest table structure
        clusters.push({
          startLine: i,
          amounts: amounts,
          boundingBox: line.boundingBox,
          confidence: this.calculateClusterConfidence(amounts)
        });
      }
    }
    
    return this.mergeNearbyCluster(clusters, threshold);
  }
}
```

### Stage 2: Dynamic Structure Analysis

```typescript
// src/services/extraction/table-structure-analyzer.ts
export class TableStructureAnalyzer {
  analyzeStructure(region: TaxRegion): TableStructure {
    // 1. 空間分析
    const spatialInfo = this.analyzeSpatialDistribution(region);
    
    // 2. 数値配置分析
    const numericLayout = this.analyzeNumericLayout(region);
    
    // 3. カラム推定
    const columns = this.inferColumns(spatialInfo, numericLayout);
    
    // 4. 行推定
    const rows = this.inferRows(spatialInfo, numericLayout);
    
    return {
      columns,
      rows,
      layout: this.determineLayout(columns, rows),
      confidence: this.calculateStructureConfidence(columns, rows)
    };
  }
  
  private inferColumns(spatial: SpatialInfo, numeric: NumericLayout): ColumnDefinition[] {
    const columns: ColumnDefinition[] = [];
    
    // X座標によるクラスタリング
    const xClusters = this.clusterByXPosition(numeric.positions);
    
    for (let i = 0; i < xClusters.length; i++) {
      const cluster = xClusters[i];
      const columnType = this.inferColumnType(cluster, i, xClusters.length);
      
      columns.push({
        index: i,
        type: columnType,
        xRange: cluster.range,
        confidence: cluster.confidence
      });
    }
    
    return columns;
  }
  
  private inferColumnType(cluster: XCluster, index: number, totalColumns: number, detectedLanguage: SupportedLanguage): ColumnType {
    // 1. 言語キーワードベース推定（最優先）
    const keywordBasedType = this.inferColumnTypeFromLanguageKeywords(cluster, detectedLanguage);
    if (keywordBasedType !== 'unknown') {
      return keywordBasedType;
    }
    
    // 2. パターンベース推定
    const patterns = cluster.values.map(v => this.categorizeValue(v));
    
    // Percentage column
    if (patterns.every(p => p.type === 'percentage')) {
      return 'rate';
    }
    
    // 3. 位置ベース推定（言語コンテキスト付き）
    if (index === 0 && patterns.some(p => p.type === 'percentage')) {
      return 'rate';
    }
    
    if (index === totalColumns - 1) {
      return 'total'; // Last column often total
    }
    
    // 4. 値ベース推定
    const avgValue = cluster.values.reduce((sum, v) => sum + v.amount, 0) / cluster.values.length;
    
    if (avgValue > 100 && index === totalColumns - 2) {
      return 'subtotal';
    }
    
    if (avgValue < 50 && index > 0) {
      return 'tax_amount';
    }
    
    return 'unknown';
  }
  
  /**
   * 言語キーワードベースのカラムタイプ推定
   * 例：ALV VEROTON VERO VEROLLINEN → rate, net, tax, gross
   */
  private inferColumnTypeFromLanguageKeywords(cluster: XCluster, language: SupportedLanguage): ColumnType {
    const nearbyText = this.extractNearbyHeaderText(cluster);
    
    // LanguageKeywords classを活用
    if (LanguageKeywords.containsKeyword(nearbyText, 'tax_rate', language)) {
      return 'rate';
    }
    
    if (LanguageKeywords.containsKeyword(nearbyText, 'net_amount', language) || 
        this.matchesSpecialKeywords(nearbyText, ['veroton', 'netto', 'net'], language)) {
      return 'net';
    }
    
    if (LanguageKeywords.containsKeyword(nearbyText, 'tax_amount', language) ||
        this.matchesSpecialKeywords(nearbyText, ['vero', 'steuer', 'tax'], language)) {
      return 'tax';
    }
    
    if (LanguageKeywords.containsKeyword(nearbyText, 'gross_amount', language) ||
        this.matchesSpecialKeywords(nearbyText, ['verollinen', 'brutto', 'gross'], language)) {
      return 'gross';
    }
    
    // 税務キーワード（ALV、VAT等）の存在確認
    if (LanguageKeywords.containsKeyword(nearbyText, 'tax', language)) {
      // 文脈から具体的なタイプを推定
      return this.refineKeywordBasedType(nearbyText, language);
    }
    
    return 'unknown';
  }
  
  /**
   * フィンランド語特化キーワード対応
   * VEROTON → net, VERO → tax, VEROLLINEN → gross
   */
  private matchesSpecialKeywords(text: string, keywords: string[], language: SupportedLanguage): boolean {
    const normalizedText = text.toLowerCase();
    return keywords.some(keyword => normalizedText.includes(keyword.toLowerCase()));
  }
}
```

### Stage 3: Rate-Specific Calculation Engine

```typescript
// src/services/calculation/multi-rate-calculator.ts
export class MultiRateCalculator {
  calculate(structure: TableStructure, region: TaxRegion): TaxBreakdownResult {
    const calculations: TaxRateCalculation[] = [];
    
    for (const row of structure.rows) {
      const rowData = this.extractRowData(row, structure.columns, region);
      const calculation = this.calculateRateSpecific(rowData);
      
      if (calculation.confidence > 0.7) {
        calculations.push(calculation);
      }
    }
    
    // 合計計算
    const summary = this.calculateSummary(calculations);
    
    // 検証
    const validation = this.validateCalculations(calculations, summary);
    
    return {
      rates: calculations,
      summary,
      validation,
      metadata: {
        method: 'universal_multi_rate',
        processingTime: Date.now() - startTime,
        structureConfidence: structure.confidence
      }
    };
  }
  
  private calculateRateSpecific(rowData: TableRowData): TaxRateCalculation {
    const { rate, amounts } = rowData;
    
    // 複数の計算方法を試行
    const methods = [
      () => this.calculateFromComplete(rate, amounts),
      () => this.calculateFromSubtotalRate(rate, amounts),
      () => this.calculateFromTotalRate(rate, amounts),
      () => this.calculateFromPartial(rate, amounts)
    ];
    
    for (const method of methods) {
      try {
        const result = method();
        if (this.validateSingleCalculation(result)) {
          return result;
        }
      } catch (error) {
        continue; // Try next method
      }
    }
    
    throw new Error(`Cannot calculate for rate ${rate}%`);
  }
  
  private calculateFromComplete(rate: number, amounts: AmountSet): TaxRateCalculation {
    const { subtotal, taxAmount, total } = amounts;
    
    // 整合性チェック
    const calculatedTotal = subtotal + taxAmount;
    const calculatedTax = subtotal * (rate / 100);
    
    const totalDiff = Math.abs(total - calculatedTotal);
    const taxDiff = Math.abs(taxAmount - calculatedTax);
    
    // 許容誤差（丸め対応）
    if (totalDiff <= 0.02 && taxDiff <= 0.02) {
      return {
        rate,
        subtotal,
        taxAmount,
        total,
        confidence: 0.95,
        evidence: [
          { type: 'arithmetic_consistency', value: totalDiff },
          { type: 'rate_consistency', value: taxDiff }
        ]
      };
    }
    
    throw new Error('Amounts not consistent');
  }
  
  private validateCalculations(calculations: TaxRateCalculation[], summary: TaxSummary): ValidationResult {
    const warnings: string[] = [];
    let overallConfidence = 0.8;
    
    // 個別税率の妥当性チェック
    for (const calc of calculations) {
      if (calc.rate < 0 || calc.rate > 50) {
        warnings.push(`Unusual tax rate: ${calc.rate}%`);
        overallConfidence -= 0.1;
      }
      
      if (calc.taxAmount > calc.subtotal) {
        warnings.push(`Tax amount (${calc.taxAmount}) exceeds subtotal (${calc.subtotal}) for rate ${calc.rate}%`);
        overallConfidence -= 0.2;
      }
    }
    
    // 合計の妥当性チェック
    const calculatedTotal = summary.totalSubtotal + summary.totalTaxAmount;
    const totalDiff = Math.abs(calculatedTotal - summary.grandTotal);
    
    if (totalDiff > 0.05) {
      warnings.push(`Total mismatch: calculated ${calculatedTotal}, found ${summary.grandTotal}`);
      overallConfidence -= 0.3;
    }
    
    return {
      isValid: overallConfidence > 0.5,
      confidence: Math.max(overallConfidence, 0.1),
      warnings,
      errors: overallConfidence < 0.3 ? ['Low confidence in calculations'] : []
    };
  }
}
```

## テスト戦略

### 1. Multi-Language Test Cases

```typescript
// tests/universal-tax-extractor.test.ts
describe('Universal Tax Extractor with Language Keywords', () => {
  const testCases = [
    {
      language: 'Finnish',
      format: 'ALV table',
      languageKeywords: ['ALV', 'VEROTON', 'VERO', 'VEROLLINEN'],
      keywordMapping: {
        'ALV': 'tax_identifier',
        'VEROTON': 'net_amount', 
        'VERO': 'tax_amount',
        'VEROLLINEN': 'gross_amount'
      },
      input: [
        'ALV VEROTON VERO VEROLLINEN',  // Header with language keywords
        'ALV 24 % 55.65 13.35 69.00',   // Data row 1
        'ALV 14 % 76.23 10.57 86.90'    // Data row 2
      ],
      expected: {
        detectedLanguage: 'fi',
        columnStructure: ['tax_identifier', 'rate', 'net_amount', 'tax_amount', 'gross_amount'],
        rates: [
          { rate: 24, subtotal: 55.65, taxAmount: 13.35, total: 69.00 },
          { rate: 14, subtotal: 76.23, taxAmount: 10.57, total: 86.90 }
        ]
      }
    },
    {
      language: 'German',
      format: 'MwSt table',
      languageKeywords: ['MWST', 'NETTO', 'BRUTTO'],
      keywordMapping: {
        'MWST': 'tax_identifier',
        'NETTO': 'net_amount',
        'BRUTTO': 'gross_amount'
      },
      input: [
        'Netto MwSt Brutto',     // German keywords
        '19% 100.00 19.00 119.00',
        '7% 50.00 3.50 53.50'
      ],
      expected: {
        detectedLanguage: 'de',
        columnStructure: ['rate', 'net_amount', 'tax_amount', 'gross_amount'],
        rates: [
          { rate: 19, subtotal: 100.00, taxAmount: 19.00, total: 119.00 },
          { rate: 7, subtotal: 50.00, taxAmount: 3.50, total: 53.50 }
        ]
      }
    },
    {
      language: 'English',
      format: 'Tax summary',
      input: [
        'Tax Rate Subtotal Tax Total',
        '8.25% $150.00 $12.38 $162.38',
        '0% $25.00 $0.00 $25.00'
      ],
      expected: {
        rates: [
          { rate: 8.25, subtotal: 150.00, taxAmount: 12.38, total: 162.38 },
          { rate: 0, subtotal: 25.00, taxAmount: 0.00, total: 25.00 }
        ]
      }
    }
  ];

  testCases.forEach(testCase => {
    it(`should extract ${testCase.language} ${testCase.format}`, async () => {
      const extractor = new UniversalTaxExtractor();
      const result = await extractor.extract(testCase.input);
      
      expect(result.rates).toHaveLength(testCase.expected.rates.length);
      
      testCase.expected.rates.forEach((expectedRate, index) => {
        const actualRate = result.rates[index];
        expect(actualRate.rate).toBeCloseTo(expectedRate.rate, 2);
        expect(actualRate.subtotal).toBeCloseTo(expectedRate.subtotal, 2);
        expect(actualRate.taxAmount).toBeCloseTo(expectedRate.taxAmount, 2);
        expect(actualRate.total).toBeCloseTo(expectedRate.total, 2);
      });
    });
  });
});
```

### 2. Structure Variation Tests

```typescript
describe('Structure Variations', () => {
  it('should handle vertical layout', () => {
    const input = [
      'Tax Rate: 24%',
      'Subtotal: 55.65',
      'Tax: 13.35',  
      'Total: 69.00'
    ];
    // Test implementation
  });
  
  it('should handle mixed layouts', () => {
    const input = [
      'Rate 24% | Subtotal 55.65 | Tax 13.35 | Total 69.00',
      'Rate 14% | Subtotal 76.23 | Tax 10.57 | Total 86.90'
    ];
    // Test implementation
  });
  
  it('should handle minimal information', () => {
    const input = [
      '24%: 69.00 (incl. 13.35 tax)',
      '14%: 86.90 (incl. 10.57 tax)'
    ];
    // Test implementation
  });
});
```

## 実装スケジュール

### Phase 1: Core Engine (Week 1-2)
- [ ] UniversalTaxDetector の実装
- [ ] Pattern Recognition Engine の実装
- [ ] 基本的なテストケースの作成

### Phase 2: Structure Analysis (Week 3-4)
- [ ] TableStructureAnalyzer の実装
- [ ] 動的カラム推定ロジック
- [ ] レイアウト判定機能

### Phase 3: Calculation Engine (Week 5-6)
- [ ] MultiRateCalculator の実装
- [ ] 検証ロジックの実装
- [ ] エラーハンドリング

### Phase 4: Integration & Testing (Week 7-8)
- [ ] 既存システムとの統合
- [ ] 包括的テスト実施
- [ ] パフォーマンス最適化

## 成果物

1. **Universal Tax Extractor**: 多言語・多構造対応抽出エンジン
2. **Rate-Specific Calculator**: 税率別詳細計算機能
3. **Comprehensive Test Suite**: 多言語・多構造テストセット
4. **Performance Benchmarks**: 既存システムとの性能比較
5. **Migration Guide**: 既存システムからの移行手順

## 期待効果

- **精度向上**: 90% → 95% の抽出精度向上
- **対応言語拡大**: 7言語 → 無制限（パターンベース）
- **構造対応**: 固定3パターン → 動的対応
- **保守性向上**: 言語追加時の開発工数 80% 削減
- **税率別詳細**: 合計値のみ → 税率別詳細抽出

## 📋 言語キーワードファイル活用方針

### **既存ファイルの活用**
```typescript
// 既存の言語キーワードファイルを最大活用
import { LanguageKeywords, SupportedLanguage } from '@/services/keywords/language-keywords';
import { CentralizedKeywordConfig } from '@/services/keywords/centralized-keyword-config';

// 1. 税務キーワードでテーブル領域検出
const taxKeywords = LanguageKeywords.getKeywords('tax', detectedLanguage);  // ALV, VAT, MOMS

// 2. カラム構造推定に活用
const netKeywords = LanguageKeywords.getKeywords('net_amount', detectedLanguage);    // VEROTON, NETTO
const taxAmountKeywords = LanguageKeywords.getKeywords('tax_amount', detectedLanguage); // VERO, STEUER  
const grossKeywords = LanguageKeywords.getKeywords('gross_amount', detectedLanguage); // VEROLLINEN, BRUTTO

// 3. 言語検出に活用
const detectedLanguage = LanguageKeywords.detectLanguage(receiptText);
```

### **フィンランドALVテーブル対応例**
```
ALV VEROTON VERO VEROLLINEN  ← 言語キーワードでカラム構造推定
├─ ALV: tax identifier (fi)
├─ VEROTON: net_amount (fi) 
├─ VERO: tax_amount (fi)
└─ VEROLLINEN: gross_amount (fi)

ALV 24 % 55.65 13.35 69.00   ← データ行：構造に基づいて値抽出
ALV 14 % 76.23 10.57 86.90   ← データ行：税率別計算実行
```

### **多言語対応の統一**
| 言語 | 税務識別子 | Net | Tax | Gross |
|------|------------|-----|-----|-------|
| フィンランド語 | ALV | VEROTON | VERO | VEROLLINEN |
| ドイツ語 | MWST/UST | NETTO | STEUER | BRUTTO |
| スウェーデン語 | MOMS | NETTO | SKATT | BRUTTO |
| 英語 | VAT/TAX | NET | TAX | GROSS |

### **実装優先度**

**Phase 1: 言語キーワード強化検出** ✅
- `LanguageKeywords.getKeywords()` 活用
- 税務領域の言語ベース検出
- カラム構造の言語キーワード推定

**Phase 2: 動的構造解析** 🚀  
- 言語コンテキスト付きカラム推定
- 税率別計算エンジン
- 数学的整合性検証

**Phase 3: テスト・検証** 🎯
- 多言語テストケース
- 実際のレシートデータでの検証
- 既存システムとの性能比較

これにより、現在の**centralized-keyword-config.ts**と**language-keywords.ts**を最大活用した、言語キーワードベースの構造検出が実現します。
