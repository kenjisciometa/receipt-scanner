# test_receipt_r1.png 読み込み問題の分析レポート（修正版）

## 正しい値

ユーザー確認済み：
- **Subtotal:** 79.09
- **Tax:** 2.11
- **Total:** 81.20

## レシート構造の分析

### 検出された行とその意味

| Line | テキスト | Y座標 | 実際の意味 | 検出状況 |
|------|---------|-------|-----------|----------|
| 17 | "Sub-total 81.20" | 834.0 | **Total** (ラベルが誤っている) | ❌ Subtotalとして誤検出 |
| 18 | "Total Sales Incl GST 81.26" | 869.0 | 別のTotal（調整前？） | ❌ 誤検出候補 |
| 19 | "lotal After Adj Inc! GSTi 81.20" | 912.0 | **Total** (OCR誤認識) | ❌ パターンマッチ失敗 |
| 23 | "GST Summary Amount Tax" | 1073.0 | テーブルヘッダー | ✅ 検出済み |
| 24 | "SR @ 6% 35.09 2.11" | 1113.0 | テーブルデータ行（税額内訳） | ✅ 検出済み |
| 25 | "ZR & 0% 44.00 0.00" | 1153.0 | テーブルデータ行（税額内訳） | ✅ 検出済み |
| 26 | "Total 79.09 2.11" | 1194.0 | **GST SummaryテーブルのTotal行**<br>79.09=Subtotal, 2.11=Tax | ❌ テーブル内Totalとして誤解釈 |

### レシート構造の特徴

このレシートは**非標準的な構造**を持っています：

1. **メインのTotal/Subtotalが上にある**
   - Line 17: "Sub-total 81.20" → 実際は**Total**
   - Line 19: "lotal After Adj Inc! GSTi 81.20" → 実際は**Total** (OCR誤認識)

2. **GST Summaryテーブルが下にある**
   - Line 23-26: GST Summaryテーブル
   - Line 26の "Total 79.09 2.11" は**テーブル内のTotal行**
   - この行の79.09が**Subtotal**、2.11が**Tax**

3. **ラベルの不一致**
   - Line 17の "Sub-total 81.20" は実際にはTotal
   - レシートのラベルが誤っている可能性がある

## 現在の問題点

### 1. テーブル内のTotal行の誤解釈

**問題:**
- Line 26の "Total 79.09 2.11" がレシート全体のTotalとして誤検出されている
- 実際には、この行はGST Summaryテーブル内のTotal行で、79.09がSubtotal、2.11がTax

**現在の動作:**
- テーブル抽出ロジックが "Total 79.09 2.11" を検出
- 79.09をSubtotalとして抽出（正しい）
- しかし、2.11をTaxとして抽出していない（問題）
- 79.09をTotalとしても誤検出している（問題）

### 2. メインのTotalの検出失敗

**問題:**
- Line 19の "lotal After Adj Inc! GSTi 81.20" がOCR誤認識により検出されていない
- Line 17の "Sub-total 81.20" がSubtotalとして誤検出されている（実際はTotal）

**現在の動作:**
- "lotal" が "total" パターンにマッチしない
- "Sub-total" がSubtotalパターンにマッチし、81.20をSubtotalとして検出

### 3. 位置情報による優先順位の逆転

**問題:**
- 通常、TotalはSubtotalより下にあるが、このレシートでは逆
- Line 17/19のTotal（81.20）がLine 26のTotal（79.09）より上にある
- 位置情報による優先順位ロジックが逆転している

## 改善案

### 1. テーブル内のTotal行の正しい解釈（最優先）

**問題:** GST Summaryテーブル内の "Total 79.09 2.11" 行を正しく解釈する必要がある

**改善案:**
- テーブル内の "Total" 行を検出した場合、その行の値を複数のフィールドとして解釈
  - 例: "Total 79.09 2.11" → Subtotal=79.09, Tax=2.11
- テーブル内のTotal行を、レシート全体のTotalとして扱わない
- テーブル抽出時に、Total行の各列を適切にマッピング
  - ヘッダー "GST Summary Amount Tax" の列順序を考慮
  - "Total 79.09 2.11" → Amount列=79.09 (Subtotal), Tax列=2.11 (Tax)

**実装方針:**
```dart
// テーブル内のTotal行を検出した場合
if (dataRow.text.contains('Total') && isTableRow) {
  // ヘッダーの列順序を確認
  // "GST Summary Amount Tax" → [Tax Rate, Amount, Tax]
  // "Total 79.09 2.11" → [null/Total, 79.09, 2.11]
  // Amount列 = Subtotal
  // Tax列 = Tax
  // レシート全体のTotalとして扱わない
}
```

### 2. OCR誤認識への対応

**問題:** "lotal" → "total" のような誤認識

**改善案:**
- ファジーマッチングを追加
  - "lotal" → "total" として扱う
  - "Inc!" → "Incl" として扱う
  - "GSTi" → "GST" として扱う
- より柔軟なパターンマッチング
  - `.*otal.*` のようなパターンで "total" を検出
  - OCR誤認識の一般的なパターンを考慮

**実装方針:**
```dart
String normalizeForTotal(String text) {
  // OCR誤認識の一般的なパターンを修正
  text = text.replaceAll(RegExp(r'[l|1]otal', caseSensitive: false), 'total');
  text = text.replaceAll(RegExp(r'Inc!'), 'Incl');
  text = text.replaceAll(RegExp(r'GSTi'), 'GST');
  return text;
}
```

### 3. 位置情報による優先順位の調整

**問題:** このレシートではTotalがSubtotalより上にある

**改善案:**
- 位置情報による優先順位を**緩和**する
- 位置情報は**補助的な指標**として使用し、絶対的な優先順位としない
- 整合性チェックを優先し、位置情報は同点の場合のみ使用

**実装方針:**
```dart
// 位置情報によるボーナスを減らす
// または、位置情報を考慮しない
// 代わりに、整合性チェックとラベルの明確さを優先
```

### 4. ラベルの不一致への対応

**問題:** "Sub-total 81.20" が実際にはTotal

**改善案:**
- ラベルと値の整合性をチェック
- 複数の候補を収集し、整合性チェックで最適な組み合わせを選択（既に実装済み）
- ラベルが誤っている可能性を考慮し、値の整合性を優先

**実装方針:**
- 既存の整合性チェック機能を活用
- 複数の候補を収集し、`Total = Subtotal + Tax` の整合性を満たす組み合わせを選択

### 5. テーブル境界の記録と除外

**問題:** テーブル内の値がレシート全体の値として誤検出されている

**改善案:**
- テーブル検出時に、テーブルの境界（Y座標範囲）を記録
- 行ベース抽出時に、テーブル境界内の候補を**除外しない**（テーブル内のTotal行からSubtotal/Taxを取得するため）
- ただし、テーブル内のTotal行をレシート全体のTotalとして扱わない

**実装方針:**
```dart
class TableInfo {
  final double minY;
  final double maxY;
  final bool isTaxBreakdownTable; // GST Summaryのような税額内訳テーブルか
}

// テーブル情報を記録
final tableInfo = TableInfo(
  minY: headerLine.boundingBox[1],
  maxY: lastDataRow.boundingBox[1] + lastDataRow.boundingBox[3],
  isTaxBreakdownTable: headerLine.text.contains('GST Summary') || 
                      headerLine.text.contains('Tax Breakdown'),
);

// 行ベース抽出時に、テーブル内のTotal行をレシート全体のTotalとして扱わない
if (isInTable && tableInfo.isTaxBreakdownTable && line.contains('Total')) {
  // テーブル内のTotal行は、レシート全体のTotalとして扱わない
  // 代わりに、その行からSubtotal/Taxを抽出
}
```

## 推奨される実装順序

### Phase 1: テーブル内のTotal行の正しい解釈（最優先）

1. **テーブル抽出ロジックの改善**
   - テーブル内の "Total" 行を検出
   - その行の各列を適切にマッピング（Amount列=Subtotal, Tax列=Tax）
   - テーブル内のTotal行をレシート全体のTotalとして扱わない

2. **テーブル情報の記録**
   - テーブルの境界（Y座標範囲）を記録
   - テーブルの種類（税額内訳テーブルかどうか）を記録

### Phase 2: OCR誤認識への対応

1. **テキスト正規化の追加**
   - "lotal" → "total" の変換
   - その他の一般的なOCR誤認識パターンの修正

2. **柔軟なパターンマッチング**
   - `.*otal.*` のようなパターンで "total" を検出

### Phase 3: 整合性チェックの強化

1. **複数候補の収集**（既に実装済み）
2. **整合性チェックでの最適解選択**（既に実装済み）
3. **位置情報の優先順位を緩和**
   - 位置情報は補助的な指標として使用

## 期待される結果

改善後は以下の値が正しく検出されることを期待:

- **Subtotal:** 79.09 (Line 26の "Total 79.09 2.11" から、GST SummaryテーブルのTotal行)
- **Tax:** 2.11 (Line 26の "Total 79.09 2.11" から、GST SummaryテーブルのTotal行)
- **Total:** 81.20 (Line 19の "lotal After Adj Inc! GSTi 81.20" から、OCR誤認識を修正)
- **整合性スコア:** 0.9以上 (79.09 + 2.11 = 81.20 ✅)

## 実装の詳細

### テーブル内のTotal行の処理

```dart
// _extractTableValuesFromBoundingBox 内で
if (dataRow.text.toLowerCase().contains('total') && 
    headerLine.text.toLowerCase().contains('summary')) {
  // これは税額内訳テーブルのTotal行
  // ヘッダーの列順序を確認
  // "GST Summary Amount Tax" → [Tax Rate, Amount, Tax]
  // "Total 79.09 2.11" → [null/Total, 79.09, 2.11]
  
  // Amount列の位置を特定
  final amountColumnIndex = headerColumns.indexOf('Amount');
  final taxColumnIndex = headerColumns.indexOf('Tax');
  
  // データ行から値を抽出
  final amountValue = dataValues[amountColumnIndex]; // 79.09
  final taxValue = dataValues[taxColumnIndex]; // 2.11
  
  // SubtotalとTaxとして返す（Totalとして扱わない）
  return {
    'subtotal_amount': amountValue,
    'tax_amount': taxValue,
    // 'total_amount' は返さない（テーブル内のTotal行はレシート全体のTotalではない）
  };
}
```

### OCR誤認識の修正

```dart
String _normalizeForPatternMatching(String text) {
  // OCR誤認識の一般的なパターンを修正
  text = text.replaceAll(RegExp(r'[l|1]otal', caseSensitive: false), 'total');
  text = text.replaceAll(RegExp(r'Inc!'), 'Incl');
  text = text.replaceAll(RegExp(r'GSTi'), 'GST');
  return text;
}

// パターンマッチング前に正規化
final normalizedLine = _normalizeForPatternMatching(line);
final match = totalPattern.firstMatch(normalizedLine);
```

