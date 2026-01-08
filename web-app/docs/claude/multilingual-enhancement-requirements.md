# Web版レシート抽出システム多言語対応改修要件書

**作成日**: 2026-01-06  
**分析対象**: Flutter vs Web版の多言語キーワード検出システム  
**対象レシート**: Walmart USAレシート（Subtotal, Tax, Total検出不良）

## 1. 現状分析

### 1.1 Flutter版の実装状況（✅ 充実）

**language_keywords.dart の特徴**:
- **7言語対応**: EN, FI, SV, FR, DE, IT, ES
- **12カテゴリー**: total, subtotal, tax, payment, payment_method_cash, payment_method_card, receipt, invoice, invoice_specific, receipt_specific, item_table_header
- **包括的な通貨対応**: USD($), EUR(€), GBP(£), SEK(kr), NOK, DKK, CHF
- **動的アクセス**: LanguageKeywords.getKeywords(category, language)
- **パターン生成**: currencyPattern, currencyCodePattern
- **堅牢な通貨抽出**: extractCurrency() with fallback logic

**キーワード例（English）**:
```dart
'total': ['total', 'sum', 'amount', 'grand total', 'amount due']
'subtotal': ['subtotal', 'sub-total', 'net']
'tax': ['vat', 'tax', 'sales tax']
```

### 1.2 Web版の実装状況（⚠️ 不完全）

**advanced-receipt-extractor.ts の問題**:
- ✅ **基本7言語対応済み** 
- ⚠️ **キーワード不足**: 'grand total', 'amount due', 'sales tax' 等のバリエーション不足
- ⚠️ **通貨システム不完全**: ドル記号前置パターン($208.98)の対応不足
- ⚠️ **カテゴリー不足**: item_table_header, invoice_specific 等の重要カテゴリー欠如
- ⚠️ **パターン認識弱い**: US式レイアウト（右寄せ金額）の認識精度低

### 1.3 Walmartレシート検出失敗原因

```
SUBTOTAL    $208.98  ← 検出失敗
TAX         $13.37   ← 検出失敗  
TOTAL       $222.35  ← 検出失敗
```

**失敗要因**:
1. **キーワード不足**: "SUBTOTAL", "TAX", "TOTAL"の大文字形式への対応不足
2. **通貨位置**: $208.98 (前置)vs 10,83€ (後置)のパターン違い
3. **レイアウト**: 右寄せ配置の認識アルゴリズム不足
4. **スコアリング**: 英語キーワードの優先度設定不適切

## 2. 改修要件

### 2.1 Priority 1: キーワードシステム強化

#### 2.1.1 English カテゴリー強化
```typescript
total: {
  en: [
    'total', 'sum', 'amount', 'grand total', 'amount due', 
    'TOTAL', 'SUM', 'GRAND TOTAL', 'AMOUNT DUE',  // 大文字追加
    'total amount', 'final amount', 'balance due'   // バリエーション追加
  ]
}

subtotal: {
  en: [
    'subtotal', 'sub-total', 'sub total', 'net',
    'SUBTOTAL', 'SUB-TOTAL', 'SUB TOTAL', 'NET',  // 大文字追加
    'merchandise total', 'items total'              // バリエーション追加
  ]
}

tax: {
  en: [
    'vat', 'tax', 'sales tax', 'TAX', 'SALES TAX', 'VAT',  // 大文字追加
    'state tax', 'local tax', 'tax amount', 'total tax'    // バリエーション追加
  ]
}
```

#### 2.1.2 新カテゴリー追加
```typescript
item_table_header: {
  en: ['qty', 'quantity', 'description', 'item', 'product', 'unit price', 'price', 'amount']
},
change: {
  en: ['change', 'change due', 'your change', 'cash back']
},
receipt_number: {
  en: ['receipt #', 'receipt no', 'transaction #', 'trans id', 'ref #']
}
```

### 2.2 Priority 1: 通貨システム改修

#### 2.2.1 USD前置パターン対応
```typescript
// 現在: /\d+[.,]\d{2}\s*[€$£]/  (後置のみ)
// 追加: /[$]\d+[.,]\d{2}/       (前置パターン)

const currencyPatterns = {
  prefixed: /[$£]\d+[.,]\d{2}/g,     // $208.98, £15.50
  suffixed: /\d+[.,]\d{2}\s*[€kr]/g, // 10,83€, 15.50kr
}
```

#### 2.2.2 通貨認識強化
```typescript
extractCurrency(text: string): {currency: string, position: 'prefix'|'suffix'} {
  if (/\$/.test(text)) return {currency: 'USD', position: 'prefix'};
  if (/€/.test(text)) return {currency: 'EUR', position: 'suffix'};
  // ... 他通貨
}
```

### 2.3 Priority 2: レイアウト認識改善

#### 2.3.1 右寄せ配置対応
```typescript
detectRightAlignedAmounts(textLines: TextLine[]): AmountCandidate[] {
  // x座標が0.7以上（右端70%以上）の金額を優先
  return textLines
    .filter(line => getBoundingBoxCenter(line.boundingBox).x > 0.7)
    .map(line => extractAmountCandidates(line))
    .filter(candidate => candidate.amount > 0);
}
```

#### 2.3.2 テーブル構造認識
```typescript
recognizeTableStructure(textLines: TextLine[]): TableStructure {
  // SUBTOTAL, TAX, TOTALの垂直配置認識
  const summarySection = textLines.filter(line => 
    /^(SUBTOTAL|TAX|TOTAL)/i.test(line.text) && 
    getBoundingBoxCenter(line.boundingBox).y > 0.6  // 下部60%エリア
  );
}
```

### 2.4 Priority 2: スコアリングロジック改善

#### 2.4.1 言語別重み付け
```typescript
calculateKeywordScore(keyword: string, language: string, context: string): number {
  const baseScore = 1.0;
  const languageBonus = language === 'en' ? 1.2 : 1.0;  // 英語レシート用ボーナス
  const contextBonus = /^[A-Z\s]+$/.test(context) ? 1.1 : 1.0;  // 大文字形式ボーナス
  const positionBonus = isRightAligned(context) ? 1.15 : 1.0;   // 右寄せボーナス
  
  return baseScore * languageBonus * contextBonus * positionBonus;
}
```

#### 2.4.2 整合性チェック強化
```typescript
validateAmountConsistency(subtotal: number, tax: number, total: number): ConsistencyResult {
  const calculatedTotal = subtotal + tax;
  const tolerance = 0.02;  // 2セント許容
  const isConsistent = Math.abs(calculatedTotal - total) <= tolerance;
  
  return {
    isValid: isConsistent,
    confidence: isConsistent ? 0.95 : 0.6,
    needsVerification: !isConsistent
  };
}
```

## 3. 実装計画

### 3.1 Phase 1: 基盤システム改修 (Week 1)
- [ ] LanguageKeywords クラス作成
- [ ] Flutter版キーワードマップ移植
- [ ] USD前置パターン対応
- [ ] 大文字・小文字混在対応

### 3.2 Phase 2: レイアウト認識強化 (Week 2)  
- [ ] 右寄せ配置検出アルゴリズム
- [ ] テーブル構造認識システム
- [ ] 境界ボックス位置解析強化

### 3.3 Phase 3: スコアリング最適化 (Week 3)
- [ ] 多言語重み付けシステム
- [ ] 文脈ベーススコアリング
- [ ] 整合性チェック強化

### 3.4 Phase 4: テスト・検証 (Week 4)
- [ ] Walmart US レシートテスト
- [ ] 多言語レシートテストスイート
- [ ] パフォーマンステスト

## 4. 成功指標

### 4.1 定量指標
- **US レシート抽出精度**: 85% → 95%以上
- **多言語対応精度**: 各言語80%以上維持
- **処理時間**: 2秒以内維持

### 4.2 定性指標  
- **Walmart レシート**: Subtotal, Tax, Total 100%検出
- **Target レシート**: 同様形式での検出成功
- **Best Buy レシート**: 電子機器店形式での検出成功

## 5. リスクと対策

### 5.1 リスク
- **既存精度低下**: フィンランド語レシート精度への影響
- **処理時間増加**: キーワード数増加による性能劣化
- **メンテナンス負荷**: 12カテゴリー管理の複雑化

### 5.2 対策
- **回帰テスト**: 既存フィンランド語レシートでの継続テスト
- **パフォーマンス最適化**: キーワード検索の効率化
- **自動テスト**: 多言語テストスイートの継続実行

## 6. 参考実装

### 6.1 Flutter版参考コード
```dart
// receipt-scanner/flutter_app/lib/core/constants/language_keywords.dart
static const Map<String, Map<String, List<String>>> keywords = {
  'total': {
    'en': ['total', 'sum', 'amount', 'grand total', 'amount due'],
    // ... 他言語
  },
}
```

### 6.2 Web版現行コード
```typescript
// receipt-scanner/web-app/src/services/extraction/advanced-receipt-extractor.ts
private readonly languageKeywords = {
  total: {
    en: ['total', 'sum', 'amount'], // ← 不完全
    // ... 
  }
}
```

## 7. Flutter Tax Breakdown システム解析

### 7.1 Tax Breakdown データモデル

**TaxBreakdown クラス**: `/flutter_app/lib/data/models/tax_breakdown.dart`
```dart
class TaxBreakdown {
  final double rate;   // 税率 (例: 14.0 = 14%)
  final double amount; // 税額
}
```

**Receipt モデル統合**:
```dart
// receipt.g.dart より
'taxBreakdown': instance.taxBreakdown.map((e) => e.toJson()).toList(),
'taxTotal': instance.taxTotal,
```

### 7.2 Tax Breakdown 検出システム

#### 7.2.1 ハイブリッド検出方式

**1. テーブルベース検出**: `_extractAmountsFromTable()`
- **構造認識**: ヘッダーとデータ行の位置情報を解析
- **複数税率対応**: 行ごとに `tax_breakdown: {rate: 14.0, amount: 12.50}` 抽出
- **スコア**: 95点 (高精度)

**2. テキストベース検出**: `_collectTaxBreakdownCandidates()`
- **パターンマッチング**: `税率パターン + 金額パターン` 組み合わせ
- **計算検証**: subtotal × 税率 = 税額の整合性チェック
- **スコア**: 80点 (中精度)

#### 7.2.2 検出フロー

```typescript
// Flutter実装フロー
1. テーブル構造検出 → tax_breakdown抽出 (高精度)
2. テキスト行解析 → 追加tax_breakdown抽出 (補完)
3. 重複排除 → rate・amount差分0.01以内は統合
4. Tax Total計算 → 全税額の合計
5. 整合性検証 → subtotal + taxTotal = total
```

#### 7.2.3 主要検出パターン

**税率抽出パターン**:
```javascript
// Flutter参考パターン
const percentPattern = /(\d+(?:[.,]\d+)?)\s*%/;

// 例: "14% VAT" → rate: 14.0
// 例: "税率 25,5%" → rate: 25.5
```

**税額計算パターン**:
```javascript
// 方式1: 直接抽出 (税率と金額が同一行)
"14% VAT   $12.50" → {rate: 14.0, amount: 12.50}

// 方式2: 計算検証 (subtotalから計算)
"14% VAT" + subtotal:100 → {rate: 14.0, amount: 14.00}
```

### 7.3 Web版への実装要件

#### 7.3.1 Priority 1: Evidence-Based Fusion System (証拠統合システム)

**従来のスコア選択方式の問題**: 
- 95点のテーブル検出が80点のテキスト検出を無視
- 部分的に正しい情報の組み合わせができない
- 単一検出失敗時に代替手段がない

**改善案: マルチソース証拠統合**

```typescript
// データモデル拡張
interface TaxEvidence {
  source: 'table' | 'text' | 'calculation' | 'pattern' | 'bbox' | 'summary_calculation';
  rate?: number;
  amount?: number;
  confidence: number;
  position?: BoundingBox;
  rawText: string;
  supportingData?: any;
}

interface TaxBreakdown {
  rate: number;    // 税率 (%)
  amount: number;  // 税額
  confidence: number;
  supportingEvidence: number;
}

interface ExtractedData {
  // 既存フィールド...
  tax_breakdown?: TaxBreakdown[];  // 複数税率対応
  tax_total?: number;              // 全税額合計
  evidence_summary?: EvidenceSummary;  // 証拠追跡
}
```

#### 7.3.2 Priority 1: マルチソース証拠収集システム

```typescript
class TaxBreakdownFusionEngine {
  // 1. 全ソースからの証拠収集
  collectAllEvidence(textLines: TextLine[]): TaxEvidence[] {
    const evidence: TaxEvidence[] = [];
    
    // テーブル構造からの証拠
    evidence.push(...this.extractTableEvidence(textLines));
    
    // テキストパターンからの証拠  
    evidence.push(...this.extractTextEvidence(textLines));
    
    // Tax Breakdown → Summary 計算による証拠
    evidence.push(...this.extractSummaryCalculationEvidence(textLines));
    
    // 位置情報による証拠
    evidence.push(...this.extractPositionalEvidence(textLines));
    
    // 数値計算による証拠
    evidence.push(...this.extractMathematicalEvidence(textLines));
    
    return evidence;
  }
  
  // 2. Tax Breakdown → Subtotal/Tax/Total 計算証拠
  extractSummaryCalculationEvidence(textLines: TextLine[]): TaxEvidence[] {
    const evidence: TaxEvidence[] = [];
    const taxBreakdowns = this.extractRawTaxBreakdowns(textLines);
    
    if (taxBreakdowns.length > 0) {
      // Tax Total計算
      const calculatedTaxTotal = taxBreakdowns.reduce((sum, tb) => sum + tb.amount, 0);
      
      // Subtotal逆算 (Total - Tax = Subtotal)
      const totalCandidates = this.findTotalCandidates(textLines);
      for (const total of totalCandidates) {
        const calculatedSubtotal = total - calculatedTaxTotal;
        
        // Subtotal証拠として追加
        evidence.push({
          source: 'summary_calculation',
          amount: calculatedSubtotal,
          confidence: 0.85,
          rawText: `Calculated from Total(${total}) - TaxTotal(${calculatedTaxTotal})`,
          supportingData: {
            method: 'total_minus_tax_breakdown',
            totalUsed: total,
            taxBreakdowns: taxBreakdowns,
            calculatedTaxTotal: calculatedTaxTotal
          }
        });
        
        // Tax証拠として追加
        evidence.push({
          source: 'summary_calculation',
          amount: calculatedTaxTotal,
          confidence: 0.90,
          rawText: `Sum of tax breakdowns: ${taxBreakdowns.map(tb => `${tb.rate}%=${tb.amount}`).join(', ')}`,
          supportingData: {
            method: 'tax_breakdown_sum',
            breakdowns: taxBreakdowns
          }
        });
        
        // Total検証証拠として追加
        evidence.push({
          source: 'summary_calculation',
          amount: total,
          confidence: 0.88,
          rawText: `Verified Total: Subtotal(${calculatedSubtotal}) + Tax(${calculatedTaxTotal})`,
          supportingData: {
            method: 'subtotal_plus_tax_verification',
            subtotal: calculatedSubtotal,
            tax: calculatedTaxTotal
          }
        });
      }
    }
    
    return evidence;
  }
  
  // 3. 証拠の相互検証
  crossValidateEvidence(evidence: TaxEvidence[]): ValidationResult {
    const clusters = this.clusterSimilarEvidence(evidence);
    
    for (const cluster of clusters) {
      // 数値的整合性チェック
      const mathConsistency = this.checkMathematicalConsistency(cluster);
      
      // 位置的整合性チェック  
      const spatialConsistency = this.checkSpatialConsistency(cluster);
      
      // Tax Breakdown整合性チェック
      const taxBreakdownConsistency = this.checkTaxBreakdownConsistency(cluster);
      
      cluster.consolidatedConfidence = this.calculateConsolidatedConfidence(
        mathConsistency, spatialConsistency, taxBreakdownConsistency
      );
    }
    
    return { clusters, overallConfidence: this.calculateOverallConfidence(clusters) };
  }
  
  // 4. 最適値の統合決定
  fuseToOptimalValue(validatedClusters: EvidenceCluster[]): ExtractedData {
    const results: ExtractedData = {};
    
    // Tax Breakdown統合
    const taxBreakdownCluster = validatedClusters.find(c => c.type === 'tax_breakdown');
    if (taxBreakdownCluster) {
      results.tax_breakdown = this.fuseTaxBreakdowns(taxBreakdownCluster);
      results.tax_total = results.tax_breakdown.reduce((sum, tb) => sum + tb.amount, 0);
    }
    
    // Summary値統合（Tax Breakdown計算証拠を優先）
    results.subtotal = this.fuseValue(validatedClusters, 'subtotal');
    results.tax_amount = results.tax_total; // Tax Breakdownから計算済み
    results.total = this.fuseValue(validatedClusters, 'total');
    
    // 最終整合性検証
    results.consistency_check = this.performFinalConsistencyCheck(results);
    
    return results;
  }
}
```

#### 7.3.3 Priority 1: Tax Breakdown → Summary 計算システム

**核心アイデア**: Tax Breakdownから逆算してSubtotal/Tax/Totalの証拠を生成

```typescript
class SummaryCalculationEngine {
  // Tax Breakdown → Summary値計算
  generateSummaryEvidence(taxBreakdowns: TaxBreakdown[], totalCandidates: number[]): TaxEvidence[] {
    const evidence: TaxEvidence[] = [];
    
    if (taxBreakdowns.length === 0) return evidence;
    
    // 1. Tax Total = Sum of all tax breakdowns
    const calculatedTaxTotal = taxBreakdowns.reduce((sum, tb) => sum + tb.amount, 0);
    
    for (const total of totalCandidates) {
      // 2. Subtotal = Total - Tax Total
      const calculatedSubtotal = total - calculatedTaxTotal;
      
      // Subtotal証拠
      evidence.push({
        source: 'summary_calculation',
        field: 'subtotal',
        amount: calculatedSubtotal,
        confidence: this.calculateSubtotalConfidence(taxBreakdowns, total),
        rawText: `Subtotal calculated: ${total} - ${calculatedTaxTotal} = ${calculatedSubtotal}`,
        supportingData: {
          method: 'total_minus_tax_breakdown',
          taxBreakdowns: taxBreakdowns,
          totalUsed: total,
          calculatedTaxTotal: calculatedTaxTotal,
          // 整合性指標
          taxRateConsistency: this.checkTaxRateConsistency(taxBreakdowns, calculatedSubtotal)
        }
      });
      
      // Tax証拠 (Tax Breakdownsの合計)
      evidence.push({
        source: 'summary_calculation', 
        field: 'tax_amount',
        amount: calculatedTaxTotal,
        confidence: 0.92, // Tax Breakdownから直接計算なので高信頼度
        rawText: `Tax total from breakdown: ${taxBreakdowns.map(tb => `${tb.rate}%=${tb.amount}`).join(' + ')} = ${calculatedTaxTotal}`,
        supportingData: {
          method: 'tax_breakdown_sum',
          breakdowns: taxBreakdowns,
          breakdownCount: taxBreakdowns.length
        }
      });
      
      // Total検証証拠
      const recalculatedTotal = calculatedSubtotal + calculatedTaxTotal;
      evidence.push({
        source: 'summary_calculation',
        field: 'total',
        amount: total,
        confidence: this.calculateTotalVerificationConfidence(total, recalculatedTotal),
        rawText: `Total verification: ${calculatedSubtotal} + ${calculatedTaxTotal} = ${recalculatedTotal} (vs original: ${total})`,
        supportingData: {
          method: 'subtotal_plus_tax_verification',
          subtotal: calculatedSubtotal,
          tax: calculatedTaxTotal,
          recalculated: recalculatedTotal,
          deviation: Math.abs(total - recalculatedTotal),
          deviationPercent: Math.abs(total - recalculatedTotal) / total * 100
        }
      });
    }
    
    return evidence;
  }
  
  // Tax Rate整合性チェック
  checkTaxRateConsistency(taxBreakdowns: TaxBreakdown[], subtotal: number): number {
    if (subtotal <= 0) return 0;
    
    let consistencyScore = 0;
    for (const breakdown of taxBreakdowns) {
      // 各税率から期待税額を計算
      const expectedTaxAmount = subtotal * breakdown.rate / 100;
      const deviation = Math.abs(expectedTaxAmount - breakdown.amount) / breakdown.amount;
      consistencyScore += Math.max(0, 1 - deviation);
    }
    
    return consistencyScore / taxBreakdowns.length;
  }
  
  // Subtotal信頼度計算
  calculateSubtotalConfidence(taxBreakdowns: TaxBreakdown[], total: number): number {
    let confidence = 0.8; // ベース信頼度
    
    // Tax Breakdown数による信頼度向上
    if (taxBreakdowns.length >= 2) confidence += 0.05;
    if (taxBreakdowns.length >= 3) confidence += 0.05;
    
    // Tax率の一般的な範囲チェック
    const rates = taxBreakdowns.map(tb => tb.rate);
    const isReasonableRates = rates.every(rate => rate >= 0 && rate <= 50);
    if (isReasonableRates) confidence += 0.05;
    
    // 総額との整合性
    const taxTotal = taxBreakdowns.reduce((sum, tb) => sum + tb.amount, 0);
    const subtotalRatio = (total - taxTotal) / total;
    if (subtotalRatio >= 0.7 && subtotalRatio <= 0.95) confidence += 0.05;
    
    return Math.min(confidence, 0.95);
  }
}
```

**活用例: Walmartレシート**
```
Tax Breakdown検出: [{rate: 6.4, amount: 13.37}]
Total候補: [222.35]

→ 生成される証拠:
1. Subtotal = 222.35 - 13.37 = 208.98 (confidence: 0.87)
2. Tax = 13.37 (confidence: 0.92) 
3. Total = 222.35 検証済み (confidence: 0.95)
```

#### 7.3.4 Priority 2: テーブル構造認識強化

```typescript
recognizeTableStructure(textLines: TextLine[]): TableStructure {
  // 1. ヘッダー行認識
  const headers = textLines.filter(line => 
    /qty|description|price|tax|rate/i.test(line.text) &&
    line.boundingBox.y < 0.3  // 上部30%エリア
  );
  
  // 2. データ行認識 (tax rate含む)
  const dataRows = textLines.filter(line =>
    /%/.test(line.text) &&  // 税率記号含む
    line.boundingBox.y > 0.3  // 中部以降
  );
  
  // 3. tax_breakdown抽出
  return new TableStructure(headers, dataRows);
}
```

### 7.4 実装計画更新 (Evidence-Based Fusion)

#### Phase 1 (Week 1) - Evidence Collection System
- [ ] **TaxEvidence データモデル作成**
- [ ] **マルチソース証拠収集エンジン**
  - テーブル構造証拠抽出
  - テキストパターン証拠抽出  
  - Tax Breakdown → Summary計算証拠
  - 位置情報証拠抽出
- [ ] **基本的な証拠クラスタリング**

#### Phase 2 (Week 2) - Evidence Validation System  
- [ ] **相互検証システム**
  - 数値的整合性チェック
  - 空間的整合性チェック
  - Tax Breakdown整合性チェック
- [ ] **動的重み付けシステム**
- [ ] **アウトライア除去機構**

#### Phase 3 (Week 3) - Evidence Fusion System
- [ ] **証拠統合アルゴリズム**
  - 加重平均による値統合
  - 中央値・最頻値の活用
  - 最終値決定システム
- [ ] **Summary計算システム強化**
  - Tax Breakdown → Subtotal逆算
  - Tax Total計算・検証
  - Total整合性確認
- [ ] **信頼度追跡システム**

#### Phase 4 (Week 4) - Testing & Optimization
- [ ] **Walmartレシートテスト** (単一税率)
- [ ] **EU VATレシートテスト** (複数税率: 6%/12%/24%)
- [ ] **US Sales Taxテスト** (State+Local税率)
- [ ] **Evidence追跡・デバッグシステム**
- [ ] **パフォーマンス最適化**

### 7.5 成功指標更新

#### 定量指標
- **単一税率精度**: 95%以上維持
- **複数税率精度**: 85%以上 (新規)
- **Tax Total整合性**: 98%以上 (新規)

#### 定性指標
- **EU レシート**: VAT複数税率の正確な分離
- **US レシート**: State Tax + Local Tax の分離
- **フィンランド**: 複数税率食品レシート対応

## 8. 参考実装 (Flutter)

### 8.1 Tax Breakdown 検出コード
```dart
// receipt_parser.dart - _collectTaxBreakdownCandidates()
final taxBreakdownCandidates = <TaxBreakdownCandidate>[];
final percentPattern = RegExp(r'(\d+(?:[.,]\d+)?)\s*%');

for (int i = 0; i < lines.length; i++) {
  final percentMatch = percentPattern.firstMatch(lines[i]);
  if (percentMatch != null) {
    final percent = double.parse(percentMatch.group(1)!.replaceAll(',', '.'));
    final matchedAmount = _extractTaxAmountFromLine(lines[i], percent, allAmountMatches, textLines);
    
    if (matchedAmount != null) {
      taxBreakdownCandidates.add(TaxBreakdownCandidate(
        rate: percent,
        amount: matchedAmount,
        score: 80,
        source: 'tax_label_with_rate',
      ));
    }
  }
}
```

### 8.2 テーブル抽出統合
```dart
// 既存テーブル抽出とtax_breakdown統合
if (taxBreakdowns.isNotEmpty) {
  amounts['_tax_breakdowns'] = taxBreakdowns;
  logger.d('📊 Tax breakdowns from table: $taxBreakdowns');
}

final taxTotal = taxBreakdownCandidates
    .map((c) => c.amount)
    .fold(0.0, (sum, amount) => sum + amount);
extractedData['tax_total'] = double.parse(taxTotal.toStringAsFixed(2));
```

## 9. Evidence-Based Fusion の革新性

### 9.1 従来手法との比較

| 項目 | 従来のスコア選択方式 | Evidence-Based Fusion |
|-----|-------------------|----------------------|
| **情報利用** | 最高スコア1つのみ | 全証拠を統合活用 |
| **精度** | 単一検出失敗で破綻 | 相互補完で高精度 |
| **透明性** | ブラックボックス | 証拠追跡可能 |
| **拡張性** | 新手法追加困難 | 証拠源を容易に追加 |
| **ロバスト性** | OCRエラーに脆弱 | 複数証拠で耐性向上 |

### 9.2 Tax Breakdown → Summary の威力

**核心的利点**: Tax Breakdownが正確に抽出できれば、そこからSubtotal/Tax/Totalを逆算できる

```
例: Walmart Receipt
Tax Breakdown: [6.4% = $13.37]
Total: $222.35

→ 自動計算される証拠:
- Subtotal = $222.35 - $13.37 = $208.98 (confidence: 0.87)
- Tax = $13.37 (confidence: 0.92)
- Total = $222.35 verified (confidence: 0.95)
```

**これにより**:
1. **SUBTOTALの直接抽出に失敗してもOK** - Tax Breakdownから逆算
2. **TAXの直接抽出に失敗してもOK** - Tax Breakdownから合計  
3. **TOTALの整合性を数学的に検証** - 計算結果との比較
4. **複数の証拠源による相互検証** - 単一エラーの影響を最小化

### 9.3 実装上の革新

#### 9.3.1 証拠収集の網羅性
```typescript
// 1つの値に対して複数の証拠を収集
subtotalEvidence = [
  {source: 'table', amount: 208.98, confidence: 0.85},
  {source: 'text', amount: 208.90, confidence: 0.70},  
  {source: 'summary_calculation', amount: 208.98, confidence: 0.87}, // Tax Breakdown由来
  {source: 'bbox', amount: 209.00, confidence: 0.60}
]

// 統合結果: 208.98 (multiple evidence convergence)
```

#### 9.3.2 数学的整合性の活用
```typescript
// Tax Breakdown [6.4% = $13.37] + Subtotal $208.98 の整合性
expectedTax = 208.98 * 6.4 / 100 = 13.375
actualTax = 13.37
deviation = |13.375 - 13.37| / 13.37 = 0.04% → 極めて整合的
```

### 9.4 期待される改善効果

#### 9.4.1 Walmartレシート問題の解決
- **現状**: SUBTOTAL, TAX, TOTAL 検出失敗
- **改善後**: Tax Breakdown検出 → Summary値逆算 → 100%検出成功

#### 9.4.2 汎用的な精度向上
- **単一税率レシート**: 従来85% → 95%+
- **複数税率レシート**: 従来60% → 85%+
- **OCRエラー耐性**: 従来低 → 高 (複数証拠による補完)

#### 9.4.3 開発・運用効率
- **デバッグ**: 証拠追跡により問題箇所特定容易
- **改善**: 新しい証拠源を簡単に追加
- **検証**: 各証拠の妥当性を個別評価

---

**Next Action**: Phase 1のEvidence-Based Fusion System実装から開始
**担当**: Claude Code AI Assistant  
**レビュー**: 各Phase完了時にWalmartレシート + 複数税率レシートでの検証実施
**革新性**: Tax Breakdownを活用した逆算システムにより、従来困難だったレシートの抽出精度を大幅改善