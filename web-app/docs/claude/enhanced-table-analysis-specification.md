# Enhanced Tax Table Analysis - Evidence-Based Fusion Specification

## 概要

フィンランド語レシートの税額テーブル解析を強化し、Subtotal、Tax、Totalを正確に算出するためのEvidence-Based Fusionシステムの改良仕様書です。

## 現在の問題点

### 1. フィンランド語Lidlレシートの税額テーブル未検出
```
現在の検出結果:
- Total: 35.62 ✅ (正しく検出)
- Subtotal: null ❌ (未検出)
- Tax Total: null ❌ (未検出)

期待される結果:
- Total: 35.62
- Subtotal: 31.11 (35.62 - 4.51)
- Tax Total: 4.51 (0.38 + 4.13)
```

### 2. 税額テーブル構造
```
テキスト行例:
"Alv Brutto Netto Vero"          // ヘッダー行
"A 24 % 1,97 1,59 0,38"          // 24%税率: 総額1.97, 税抜き1.59, 税額0.38
"B 14 % 33,65 29.52 4.13"        // 14%税率: 総額33.65, 税抜き29.52, 税額4.13
```

## 解決案: Enhanced Table Evidence Extraction

### 1. Tax Table Pattern Recognition

#### 1.1 テーブルヘッダー検出パターン
```typescript
interface TableHeaderPatterns {
  finnish: /(?:alv|vero|brutto|netto)/i;
  swedish: /(?:moms|brutto|netto)/i;
  english: /(?:vat|tax|gross|net)/i;
  german: /(?:mwst|steuer|brutto|netto)/i;
}
```

#### 1.2 税率行検出パターン
```typescript
interface TaxRateRowPattern {
  // [税率コード] [税率%] [総額] [税抜き] [税額]
  pattern: /([A-Z])\s*(\d+)\s*%\s*([\d,\.]+)\s*([\d,\.]+)\s*([\d,\.]+)/gi;
  groups: {
    code: string;      // "A", "B", "C"
    rate: number;      // 24, 14
    gross: number;     // 1.97, 33.65
    net: number;       // 1.59, 29.52
    tax: number;       // 0.38, 4.13
  };
}
```

### 2. Enhanced Evidence Collection

#### 2.1 新しいEvidence Source: "tax_table"
```typescript
interface TaxTableEvidence extends Evidence {
  source: 'tax_table';
  field: 'subtotal' | 'tax_total' | 'tax_breakdown';
  data: {
    tableRows: TaxTableRow[];
    calculatedSubtotal: number;
    calculatedTaxTotal: number;
    taxBreakdown: TaxBreakdown[];
  };
  spatialInfo: {
    tableRegion: BoundingBox;
    headerLine: number;
    dataLines: number[];
  };
  confidence: number;
}

interface TaxTableRow {
  code: string;
  rate: number;
  gross: number;
  net: number;
  tax: number;
  confidence: number;
  lineIndex: number;
}
```

### 3. Table Detection Algorithm

#### 3.1 空間的解析によるテーブル領域検出
```typescript
interface TableDetectionStrategy {
  // 1. ヘッダー行検出
  detectTableHeader(textLines: TextLine[]): TableHeader | null;
  
  // 2. データ行グループ化 (Y座標近接性)
  groupTableRows(textLines: TextLine[], headerIndex: number): TextLine[];
  
  // 3. 列構造解析 (X座標整列性)
  analyzeColumnStructure(rows: TextLine[]): ColumnStructure;
  
  // 4. 数値抽出と検証
  extractAndValidateNumbers(rows: TextLine[]): TaxTableRow[];
}
```

#### 3.2 列構造解析
```typescript
interface ColumnStructure {
  columns: Column[];
  confidence: number;
}

interface Column {
  type: 'code' | 'rate' | 'gross' | 'net' | 'tax';
  xRange: [number, number];
  alignment: 'left' | 'right' | 'center';
  expectedFormat: RegExp;
}
```

### 4. Mathematical Validation and Cross-Reference

#### 4.1 税額計算検証
```typescript
interface TaxCalculationValidator {
  // 行内検証: gross = net + tax
  validateRowMath(row: TaxTableRow): boolean;
  
  // 合計検証: sum(tax) = total_tax, sum(net) = subtotal
  validateTotals(rows: TaxTableRow[], total: number): ValidationResult;
  
  // 税率検証: tax = net * rate / 100
  validateTaxRates(rows: TaxTableRow[]): ValidationResult;
}
```

#### 4.2 Evidence Cross-Reference
```typescript
interface EvidenceCrossReference {
  // テキストベースTotal vs テーブル計算Total
  compareTextVsTable(textTotal: number, tableGrossSum: number): number;
  
  // 複数ソースからの信頼度重み付け
  weightedConfidence(evidences: Evidence[]): number;
  
  // 不整合検出と警告
  detectInconsistencies(evidences: Evidence[]): Warning[];
}
```

### 5. Implementation Plan

#### 5.1 TaxBreakdownFusionEngineの拡張

```typescript
class EnhancedTaxBreakdownFusionEngine extends TaxBreakdownFusionEngine {
  // 新しいEvidence Collector
  async extractTableEvidence(textLines: TextLine[]): Promise<Evidence[]> {
    const tableDetector = new TaxTableDetector();
    const tables = tableDetector.detectTaxTables(textLines);
    
    return tables.map(table => this.createTableEvidence(table));
  }
  
  // Evidence融合の強化
  protected fuseEvidences(evidences: Evidence[]): EvidenceBasedExtractedData {
    const textEvidences = evidences.filter(e => e.source === 'text');
    const tableEvidences = evidences.filter(e => e.source === 'tax_table');
    
    // テーブル優先戦略
    if (tableEvidences.length > 0) {
      return this.fuseWithTablePriority(textEvidences, tableEvidences);
    }
    
    return this.fuseTextOnly(textEvidences);
  }
}
```

#### 5.2 新しいクラス: TaxTableDetector

```typescript
class TaxTableDetector {
  detectTaxTables(textLines: TextLine[]): TaxTable[] {
    // 1. ヘッダー検出
    const headerCandidates = this.findTableHeaders(textLines);
    
    // 2. 各ヘッダーからテーブル構築
    return headerCandidates.map(header => {
      const tableRows = this.extractTableRows(textLines, header);
      return this.buildTaxTable(header, tableRows);
    });
  }
  
  private findTableHeaders(textLines: TextLine[]): TableHeader[] {
    return textLines
      .map((line, index) => ({ line, index }))
      .filter(({ line }) => this.isTableHeader(line.text))
      .map(({ line, index }) => new TableHeader(line, index));
  }
  
  private isTableHeader(text: string): boolean {
    const patterns = [
      /alv\s+(brutto|gross)\s+(netto|net)\s+(vero|tax)/i,
      /tax\s+rate\s+gross\s+net\s+tax/i,
      /moms\s+brutto\s+netto/i
    ];
    
    return patterns.some(pattern => pattern.test(text));
  }
}
```

### 6. フィンランド語レシート対応の具体例

#### 6.1 Lidlレシート解析フロー
```
Input Text Lines:
35: "Alv Brutto Netto Vero"
36: "A 24 % 1,97 1,59 0,38"
37: "B 14 % 33,65 29.52 4.13"

Detection Process:
1. Header Detection: Line 35 → Tax table detected
2. Row Extraction: Lines 36-37 → Tax rate rows
3. Column Analysis: [Code][Rate%][Gross][Net][Tax]
4. Number Extraction:
   - Row A: 24%, 1.97, 1.59, 0.38
   - Row B: 14%, 33.65, 29.52, 4.13
5. Calculation:
   - Total Tax: 0.38 + 4.13 = 4.51
   - Total Net: 1.59 + 29.52 = 31.11
   - Total Gross: 1.97 + 33.65 = 35.62

Output Evidence:
- subtotal: 31.11 (confidence: 0.95)
- tax_total: 4.51 (confidence: 0.95)
- tax_breakdown: [
    {rate: 24, amount: 0.38, net: 1.59},
    {rate: 14, amount: 4.13, net: 29.52}
  ]
```

### 7. Quality Assurance

#### 7.1 テスト戦略
- フィンランド語Lidlレシートでの回帰テスト
- 他言語レシート（スウェーデン語、ドイツ語）での互換性テスト
- 様々な税率パターンでのロバストネステスト

#### 7.2 エラーハンドリング
- テーブル構造が不完全な場合のフォールバック
- 数値抽出エラー時の部分的成功処理
- テキストベースとテーブルベースの不整合時の警告

### 8. Performance Impact

#### 8.1 処理時間への影響
- 空間解析処理の追加: +5-10ms
- 数値検証処理の追加: +2-5ms
- 全体の処理時間増加: 10-15%以内

#### 8.2 メモリ使用量
- テーブル構造データの追加: +1-2KB per receipt
- 影響は軽微

## まとめ

この仕様に基づいてTax Table Analysis機能を実装することで、フィンランド語レシートのSubtotal、Tax、Totalすべてが正確に検出できるようになり、Evidence-Based Fusionの精度が大幅に向上します。