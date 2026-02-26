# アイテム合計による整合性チェック 改修要件定義書

## 1. 概要

### 1.1 目的

レシートの各アイテムの合計金額を計算し、抽出されたSubtotal/Totalと整合性をチェックすることで、抽出精度を向上させる。また、アイテム合計からSubtotal/Totalを予測し、候補として追加する。

### 1.2 背景

現在の実装では、以下の整合性チェックが実装されている：
- Total = Subtotal + Tax の整合性チェック
- 複数候補の収集と整合性スコアリング

しかし、以下の整合性チェックが未実装：
- **アイテム合計とSubtotal/Totalの整合性チェック**
- **アイテム合計からSubtotal/Totalを予測する機能**

### 1.3 期待される効果

1. **抽出精度の向上**
   - アイテム合計とSubtotal/Totalの整合性をチェックすることで、誤検出を減らす
   - アイテム合計からSubtotal/Totalを予測することで、検出漏れを減らす

2. **信頼度の向上**
   - アイテム合計とSubtotal/Totalが一致する場合、抽出結果の信頼度が高い
   - 不一致の場合、警告を出して手動確認を促す

3. **自動修正の強化**
   - アイテム合計とSubtotal/Totalの差が小さい場合、自動修正を提案

---

## 2. 現状の実装確認

### 2.1 アイテム抽出機能

**実装状況:** ✅ 実装済み

**場所:** `lib/services/extraction/receipt_parser.dart` の `_extractItems` メソッド

**データ構造:**
```dart
class ReceiptItem {
  final String name;
  final int? quantity;
  final double? unitPrice;
  final double? totalPrice;  // アイテムの合計価格
  // ...
}
```

**抽出される情報:**
- アイテム名
- 数量（オプション）
- 単価（オプション）
- 合計価格（`totalPrice`）

### 2.2 整合性チェック機能

**実装状況:** ✅ 実装済み

**場所:** `lib/services/extraction/receipt_parser.dart` の `_selectBestCandidates` メソッド

**現在の整合性チェック:**
- Total = Subtotal + Tax の整合性
- 候補の信頼度スコア
- 位置情報による優先順位
- OCR信頼度

**未実装の整合性チェック:**
- ❌ アイテム合計とSubtotal/Totalの整合性
- ❌ アイテム合計からSubtotal/Totalを予測

---

## 3. 要件定義

### 3.1 機能要件

#### FR-1: アイテム合計の計算

**説明:**
- 抽出されたすべてのアイテムの `totalPrice` を合計する
- `totalPrice` が `null` のアイテムは除外する
- 計算結果を `itemsSum` として保持

**入力:**
- `List<ReceiptItem> items` - 抽出されたアイテムリスト

**出力:**
- `double? itemsSum` - アイテム合計金額（アイテムがない場合は `null`）

**計算式:**
```dart
double? itemsSum = items
    .where((item) => item.totalPrice != null)
    .map((item) => item.totalPrice!)
    .fold(0.0, (sum, price) => sum + price);
```

**エッジケース:**
- アイテムが0個の場合 → `null` を返す
- すべてのアイテムの `totalPrice` が `null` の場合 → `null` を返す
- アイテムが1個でも `totalPrice` がある場合 → そのアイテムの価格を返す

#### FR-2: アイテム合計とSubtotal/Totalの整合性チェック

**説明:**
- アイテム合計（`itemsSum`）と抽出されたSubtotal/Totalを比較
- 差が許容範囲内（デフォルト: 1セント）かチェック
- 整合性スコアに反映

**入力:**
- `double? itemsSum` - アイテム合計金額
- `AmountCandidate? subtotal` - Subtotal候補
- `AmountCandidate? total` - Total候補

**出力:**
- `double consistencyScore` - 整合性スコア（0.0-1.0）
- `List<String> warnings` - 警告メッセージ（不一致の場合）

**計算式:**
```dart
if (itemsSum != null && subtotal != null) {
  final difference = (itemsSum - subtotal.amount).abs();
  if (difference <= 0.01) {
    // 完全一致または1セント以内の差
    consistencyScore += 0.15;  // ボーナス
  } else if (difference <= 0.10) {
    // 10セント以内の差
    consistencyScore += 0.10;
    warnings.add('Items sum (${itemsSum}) != Subtotal (${subtotal.amount}), diff: ${difference.toStringAsFixed(2)}');
  } else {
    // 10セント以上の差
    warnings.add('Large difference between items sum (${itemsSum}) and Subtotal (${subtotal.amount}), diff: ${difference.toStringAsFixed(2)}');
  }
}

if (itemsSum != null && total != null) {
  final difference = (itemsSum - total.amount).abs();
  // 同様の処理
}
```

**許容範囲:**
- 完全一致または1セント以内: ボーナス +0.15
- 10セント以内: ボーナス +0.10
- 10セント以上: 警告のみ（ボーナスなし）

#### FR-3: アイテム合計からSubtotal/Totalを予測

**説明:**
- アイテム合計（`itemsSum`）からSubtotal/Totalの候補を生成
- 既存の候補リストに追加
- 信頼度スコアを設定（アイテム合計の信頼度に基づく）

**入力:**
- `double? itemsSum` - アイテム合計金額
- `List<ReceiptItem> items` - 抽出されたアイテムリスト
- `List<TextLine>? textLines` - テキスト行情報（位置情報用）

**出力:**
- `List<AmountCandidate>` - Subtotal/Total候補リストに追加される候補

**信頼度スコアの計算:**
```dart
int calculateItemsSumScore(List<ReceiptItem> items) {
  if (items.isEmpty) return 0;
  
  // アイテム数によるボーナス
  int score = 60;  // ベーススコア
  if (items.length >= 3) {
    score += 10;  // 3個以上のアイテムがある場合
  }
  if (items.length >= 5) {
    score += 10;  // 5個以上のアイテムがある場合
  }
  
  // すべてのアイテムにtotalPriceがある場合のボーナス
  final allHavePrice = items.every((item) => item.totalPrice != null);
  if (allHavePrice) {
    score += 10;
  }
  
  return score.clamp(0, 100);
}
```

**候補の生成:**
```dart
if (itemsSum != null && itemsSum > 0) {
  // Subtotal候補として追加
  subtotalCandidates.add(AmountCandidate(
    amount: itemsSum,
    score: calculateItemsSumScore(items),
    lineIndex: -1,  // アイテム合計は特定の行にない
    source: 'items_sum_subtotal',
    fieldName: 'subtotal_amount',
    label: 'Items Sum',
  ));
  
  // Total候補としても追加（Taxが検出されていない場合）
  // または、Taxが検出されている場合は itemsSum + tax をTotal候補として追加
}
```

#### FR-4: アイテム合計とTaxの整合性チェック

**説明:**
- アイテム合計（`itemsSum`）とTaxからTotalを計算
- 抽出されたTotalと比較
- 整合性スコアに反映

**入力:**
- `double? itemsSum` - アイテム合計金額
- `AmountCandidate? tax` - Tax候補
- `AmountCandidate? total` - Total候補

**出力:**
- `double consistencyScore` - 整合性スコア（0.0-1.0）
- `List<String> warnings` - 警告メッセージ（不一致の場合）

**計算式:**
```dart
if (itemsSum != null && tax != null && total != null) {
  final expectedTotal = itemsSum + tax.amount;
  final difference = (total.amount - expectedTotal).abs();
  
  if (difference <= 0.01) {
    // 完全一致または1セント以内の差
    consistencyScore += 0.15;  // ボーナス
  } else if (difference <= 0.10) {
    // 10セント以内の差
    consistencyScore += 0.10;
    warnings.add('Items sum + Tax (${expectedTotal}) != Total (${total.amount}), diff: ${difference.toStringAsFixed(2)}');
  } else {
    // 10セント以上の差
    warnings.add('Large difference: Items sum + Tax (${expectedTotal}) != Total (${total.amount}), diff: ${difference.toStringAsFixed(2)}');
  }
}
```

#### FR-5: 自動修正の強化

**説明:**
- アイテム合計とSubtotal/Totalの差が小さい場合、自動修正を提案
- 既存の自動修正機能（Total = Subtotal + Tax）と統合

**入力:**
- `double? itemsSum` - アイテム合計金額
- `AmountCandidate? subtotal` - Subtotal候補
- `AmountCandidate? total` - Total候補

**出力:**
- `Map<String, double>? correctedValues` - 修正された値（あれば）

**修正ロジック:**
```dart
if (itemsSum != null && subtotal != null) {
  final difference = (itemsSum - subtotal.amount).abs();
  
  // 10セント以内の差の場合、アイテム合計でSubtotalを修正
  if (difference <= 0.10 && difference > 0.01) {
    correctedValues['subtotal_amount'] = double.parse(itemsSum.toStringAsFixed(2));
    warnings.add('Auto-corrected Subtotal: ${subtotal.amount} → $itemsSum (based on items sum)');
  }
}

if (itemsSum != null && tax != null && total != null) {
  final expectedTotal = itemsSum + tax.amount;
  final difference = (total.amount - expectedTotal).abs();
  
  // 10セント以内の差の場合、アイテム合計 + Tax でTotalを修正
  if (difference <= 0.10 && difference > 0.01) {
    correctedValues['total_amount'] = double.parse(expectedTotal.toStringAsFixed(2));
    warnings.add('Auto-corrected Total: ${total.amount} → $expectedTotal (based on items sum + tax)');
  }
}
```

### 3.2 非機能要件

#### NFR-1: パフォーマンス

- アイテム合計の計算は O(n) で完了（n = アイテム数）
- 整合性チェックの追加による処理時間の増加は 10ms 以内

#### NFR-2: 信頼性

- アイテムが0個の場合でもエラーを発生させない
- アイテムの `totalPrice` が `null` の場合でもエラーを発生させない

#### NFR-3: 保守性

- 既存の整合性チェック機能と統合し、コードの重複を避ける
- 設定可能な許容範囲（デフォルト: 1セント、10セント）

---

## 4. 設計

### 4.1 データ構造の拡張

#### 4.1.1 `ConsistencyResult` の拡張（既存）

既存の `ConsistencyResult` クラスに以下の情報を追加：

```dart
class ConsistencyResult {
  // 既存のフィールド
  final Map<String, AmountCandidate> selectedCandidates;
  final double consistencyScore;
  final List<String> warnings;
  final bool needsVerification;
  final Map<String, double>? correctedValues;
  
  // 新規追加
  final double? itemsSum;  // アイテム合計金額
  final int itemsCount;    // アイテム数
  final bool itemsSumMatchesSubtotal;  // アイテム合計とSubtotalが一致するか
  final bool itemsSumMatchesTotal;     // アイテム合計とTotalが一致するか
}
```

#### 4.1.2 新しいメソッドの追加

```dart
// lib/services/extraction/receipt_parser.dart

/// アイテム合計を計算
double? _calculateItemsSum(List<ReceiptItem> items);

/// アイテム合計からSubtotal/Total候補を生成
List<AmountCandidate> _generateCandidatesFromItemsSum(
  double itemsSum,
  List<ReceiptItem> items,
  List<TextLine>? textLines,
);

/// アイテム合計とSubtotal/Totalの整合性スコアを計算
double _calculateItemsSumConsistencyScore({
  double? itemsSum,
  AmountCandidate? subtotal,
  AmountCandidate? total,
  AmountCandidate? tax,
  List<String> warnings,
});

/// アイテム合計に基づく自動修正
Map<String, double>? _correctValuesBasedOnItemsSum({
  double? itemsSum,
  AmountCandidate? subtotal,
  AmountCandidate? total,
  AmountCandidate? tax,
  List<String> warnings,
});
```

### 4.2 統合ポイント

#### 4.2.1 `_collectAllCandidates` メソッドの拡張

```dart
Map<String, FieldCandidates> _collectAllCandidates(
  List<String> lines,
  String? language,
  List<String> appliedPatterns, {
  List<TextLine>? textLines,
  List<ReceiptItem>? items,  // 新規追加
}) {
  // 1. テーブル候補を収集（既存）
  final tableCandidates = _collectTableCandidates(...);
  
  // 2. 行ベース候補を収集（既存）
  final lineBasedCandidates = _collectLineBasedCandidates(...);
  
  // 3. アイテム合計から候補を生成（新規追加）
  if (items != null && items.isNotEmpty) {
    final itemsSum = _calculateItemsSum(items);
    if (itemsSum != null && itemsSum > 0) {
      final itemsSumCandidates = _generateCandidatesFromItemsSum(
        itemsSum,
        items,
        textLines,
      );
      
      // 候補リストに追加
      for (final candidate in itemsSumCandidates) {
        allCandidates[candidate.fieldName]!.add(candidate);
      }
    }
  }
  
  // 4. 統合（既存）
  // ...
}
```

#### 4.2.2 `_calculateConsistencyScore` メソッドの拡張

```dart
double _calculateConsistencyScore({
  AmountCandidate? total,
  AmountCandidate? subtotal,
  AmountCandidate? tax,
  double? itemsSum,  // 新規追加
  List<ReceiptItem>? items,  // 新規追加
}) {
  double score = 0.0;
  
  // 1. 基本整合性チェック（既存）
  if (total != null && subtotal != null && tax != null) {
    final expectedTotal = subtotal.amount + tax.amount;
    final difference = (total.amount - expectedTotal).abs();
    // ...
  }
  
  // 2. アイテム合計との整合性チェック（新規追加）
  if (itemsSum != null) {
    score += _calculateItemsSumConsistencyScore(
      itemsSum: itemsSum,
      subtotal: subtotal,
      total: total,
      tax: tax,
      warnings: warnings,
    );
  }
  
  // 3. 候補の信頼度（既存）
  // ...
  
  // 4. 位置情報（既存）
  // ...
  
  // 5. OCR信頼度（既存）
  // ...
  
  // 6. テーブル抽出の信頼度ボーナス（既存）
  // ...
  
  return score.clamp(0.0, 1.0);
}
```

#### 4.2.3 `_selectBestCandidates` メソッドの拡張

```dart
ConsistencyResult _selectBestCandidates(
  Map<String, FieldCandidates> allCandidates, {
  List<ReceiptItem>? items,  // 新規追加
}) {
  // アイテム合計を計算
  final itemsSum = items != null && items.isNotEmpty
      ? _calculateItemsSum(items)
      : null;
  
  // 既存のロジック
  // ...
  
  // 整合性スコア計算時に itemsSum を渡す
  score = _calculateConsistencyScore(
    total: total,
    subtotal: subtotal,
    tax: tax,
    itemsSum: itemsSum,  // 新規追加
    items: items,  // 新規追加
  );
  
  // 自動修正時に itemsSum を考慮
  if (bestSelection.containsKey('total_amount') &&
      bestSelection.containsKey('subtotal_amount') &&
      bestSelection.containsKey('tax_amount')) {
    // 既存の自動修正ロジック
    // ...
    
    // アイテム合計に基づく自動修正（新規追加）
    final itemsSumCorrections = _correctValuesBasedOnItemsSum(
      itemsSum: itemsSum,
      subtotal: bestSelection['subtotal_amount'],
      total: bestSelection['total_amount'],
      tax: bestSelection['tax_amount'],
      warnings: warnings,
    );
    
    if (itemsSumCorrections != null) {
      correctedValues ??= {};
      correctedValues.addAll(itemsSumCorrections);
    }
  }
  
  return ConsistencyResult(
    selectedCandidates: bestSelection,
    consistencyScore: bestScore,
    warnings: warnings,
    needsVerification: bestScore < 0.6 || (correctedValues == null && warnings.isNotEmpty),
    correctedValues: correctedValues,
    itemsSum: itemsSum,  // 新規追加
    itemsCount: items?.length ?? 0,  // 新規追加
    itemsSumMatchesSubtotal: itemsSum != null && 
        bestSelection.containsKey('subtotal_amount') &&
        (itemsSum - bestSelection['subtotal_amount']!.amount).abs() <= 0.01,  // 新規追加
    itemsSumMatchesTotal: itemsSum != null && 
        bestSelection.containsKey('total_amount') &&
        (itemsSum - bestSelection['total_amount']!.amount).abs() <= 0.01,  // 新規追加
  );
}
```

### 4.3 呼び出し元の修正

#### 4.3.1 `_extractAmountsLineByLine` メソッドの修正

```dart
Map<String, double> _extractAmountsLineByLine(
  List<String> lines,
  String? language,
  List<String> appliedPatterns, {
  List<TextLine>? textLines,
  List<ReceiptItem>? items,  // 新規追加
}) {
  // 1. すべての候補を統合収集（items を渡す）
  final allCandidates = _collectAllCandidates(
    lines,
    language,
    appliedPatterns,
    textLines: textLines,
    items: items,  // 新規追加
  );
  
  // 2. 整合性チェックで最適解を選択（items を渡す）
  final consistencyResult = _selectBestCandidates(
    allCandidates,
    items: items,  // 新規追加
  );
  
  // 3. 結果をマップに変換（既存）
  // ...
}
```

#### 4.3.2 `_parseWithStructuredData` メソッドの修正

```dart
Future<ExtractionResult> _parseWithStructuredData(
  String ocrText,
  String? detectedLanguage,
  double? ocrConfidence,
  List<Map<String, dynamic>> textBlocks, {
  List<TextLine>? textLines,
}) async {
  // ...
  
  // アイテム抽出（既存）
  final items = _extractItems(ocrText, appliedPatterns);
  
  // 金額抽出（items を渡す）
  final amounts = _extractAmountsLineByLine(
    lines,
    detectedLanguage,
    appliedPatterns,
    textLines: textLines,
    items: items,  // 新規追加
  );
  
  // ...
}
```

---

## 5. 実装計画

### Phase 1: アイテム合計の計算機能（優先度: 高）

**タスク:**
1. `_calculateItemsSum` メソッドの実装
2. エッジケースの処理（アイテムが0個、totalPriceがnullなど）

**見積もり:** 0.5日

### Phase 2: アイテム合計から候補を生成（優先度: 高）

**タスク:**
1. `_generateCandidatesFromItemsSum` メソッドの実装
2. 信頼度スコアの計算ロジック
3. `_collectAllCandidates` への統合

**見積もり:** 1日

### Phase 3: アイテム合計との整合性チェック（優先度: 高）

**タスク:**
1. `_calculateItemsSumConsistencyScore` メソッドの実装
2. `_calculateConsistencyScore` への統合
3. 警告メッセージの生成

**見積もり:** 1日

### Phase 4: 自動修正の強化（優先度: 中）

**タスク:**
1. `_correctValuesBasedOnItemsSum` メソッドの実装
2. `_selectBestCandidates` への統合
3. 既存の自動修正機能との統合

**見積もり:** 0.5日

### Phase 5: データ構造の拡張（優先度: 中）

**タスク:**
1. `ConsistencyResult` クラスの拡張
2. 呼び出し元の修正（`_extractAmountsLineByLine`, `_parseWithStructuredData`）

**見積もり:** 0.5日

### Phase 6: テストとデバッグ（優先度: 高）

**タスク:**
1. 単体テストの作成
2. 統合テストの実行
3. 既存のテストレシートでの検証

**見積もり:** 1日

**合計見積もり:** 4.5日

---

## 6. テストケース

### 6.1 正常系

#### TC-1: アイテム合計とSubtotalが一致する場合

**入力:**
- アイテム: [Item1: 10.00, Item2: 20.00, Item3: 30.00]
- アイテム合計: 60.00
- Subtotal候補: 60.00

**期待結果:**
- 整合性スコアに +0.15 のボーナス
- 警告なし
- `itemsSumMatchesSubtotal = true`

#### TC-2: アイテム合計からSubtotalを予測

**入力:**
- アイテム: [Item1: 10.00, Item2: 20.00]
- アイテム合計: 30.00
- Subtotal候補: なし

**期待結果:**
- アイテム合計（30.00）がSubtotal候補として追加される
- 信頼度スコア: 60-80（アイテム数とtotalPriceの有無による）

#### TC-3: アイテム合計 + Tax = Total の整合性

**入力:**
- アイテム合計: 60.00
- Tax: 6.00
- Total: 66.00

**期待結果:**
- 整合性スコアに +0.15 のボーナス
- 警告なし

### 6.2 異常系

#### TC-4: アイテム合計とSubtotalが不一致（10セント以内）

**入力:**
- アイテム合計: 60.00
- Subtotal: 60.05

**期待結果:**
- 整合性スコアに +0.10 のボーナス
- 警告: "Items sum (60.00) != Subtotal (60.05), diff: 0.05"

#### TC-5: アイテム合計とSubtotalが不一致（10セント以上）

**入力:**
- アイテム合計: 60.00
- Subtotal: 70.00

**期待結果:**
- ボーナスなし
- 警告: "Large difference between items sum (60.00) and Subtotal (70.00), diff: 10.00"
- `needsVerification = true`

#### TC-6: アイテムが0個の場合

**入力:**
- アイテム: []

**期待結果:**
- `itemsSum = null`
- アイテム合計による整合性チェックはスキップ
- エラーなし

#### TC-7: すべてのアイテムのtotalPriceがnullの場合

**入力:**
- アイテム: [Item1(totalPrice: null), Item2(totalPrice: null)]

**期待結果:**
- `itemsSum = null`
- アイテム合計による整合性チェックはスキップ
- エラーなし

### 6.3 エッジケース

#### TC-8: アイテムが1個の場合

**入力:**
- アイテム: [Item1: 10.00]

**期待結果:**
- アイテム合計: 10.00
- 信頼度スコア: 60（ベーススコア）

#### TC-9: アイテムが5個以上の場合

**入力:**
- アイテム: [Item1: 10.00, Item2: 20.00, Item3: 30.00, Item4: 40.00, Item5: 50.00]

**期待結果:**
- アイテム合計: 150.00
- 信頼度スコア: 80（ベース60 + アイテム数ボーナス20）

#### TC-10: 一部のアイテムのtotalPriceがnullの場合

**入力:**
- アイテム: [Item1: 10.00, Item2: null, Item3: 30.00]

**期待結果:**
- アイテム合計: 40.00（nullのアイテムは除外）
- 信頼度スコア: 60-70（すべてのアイテムにtotalPriceがないため、ボーナスなし）

---

## 7. 設定項目

### 7.1 許容範囲の設定

```dart
class ConsistencyConfig {
  // アイテム合計とSubtotal/Totalの許容範囲
  static const double itemsSumToleranceExact = 0.01;  // 1セント（完全一致）
  static const double itemsSumToleranceClose = 0.10;   // 10セント（近い）
  
  // ボーナススコア
  static const double itemsSumBonusExact = 0.15;  // 完全一致の場合
  static const double itemsSumBonusClose = 0.10;  // 近い場合
}
```

### 7.2 信頼度スコアの設定

```dart
class ItemsSumScoreConfig {
  static const int baseScore = 60;           // ベーススコア
  static const int bonusFor3Items = 10;   // 3個以上のアイテム
  static const int bonusFor5Items = 10;   // 5個以上のアイテム
  static const int bonusAllHavePrice = 10; // すべてのアイテムにtotalPriceがある場合
}
```

---

## 8. ログ出力

### 8.1 デバッグログ

```
🐛 Calculating items sum from ${items.length} items
🐛 Items sum: ${itemsSum} (from ${itemsWithPrice.length} items with price)
🐛 Generated ${candidates.length} candidates from items sum
🐛 Items sum consistency: score=${score}, matches_subtotal=${matchesSubtotal}, matches_total=${matchesTotal}
🐛 Auto-corrected ${fieldName}: ${oldValue} → ${newValue} (based on items sum)
```

### 8.2 警告ログ

```
⚠️ Items sum (${itemsSum}) != Subtotal (${subtotal.amount}), diff: ${difference.toStringAsFixed(2)}
⚠️ Large difference between items sum (${itemsSum}) and Subtotal (${subtotal.amount}), diff: ${difference.toStringAsFixed(2)}
```

---

## 9. 既存機能への影響

### 9.1 既存の整合性チェック機能

**影響:** なし（追加機能として実装）

**統合方法:**
- 既存の `_calculateConsistencyScore` メソッドにアイテム合計の整合性チェックを追加
- 既存のスコア計算ロジックに影響を与えない

### 9.2 既存の自動修正機能

**影響:** 強化（既存の自動修正機能と統合）

**統合方法:**
- 既存の `correctedValues` にアイテム合計に基づく修正を追加
- 既存の自動修正（Total = Subtotal + Tax）と競合しないようにする

### 9.3 既存の候補収集機能

**影響:** 拡張（アイテム合計から候補を追加）

**統合方法:**
- 既存の `_collectAllCandidates` メソッドにアイテム合計からの候補生成を追加
- 既存の候補収集ロジックに影響を与えない

---

## 10. リスクと対策

### 10.1 リスク

#### R-1: アイテム抽出が不完全な場合

**リスク:**
- アイテムが一部しか抽出されていない場合、アイテム合計が不正確になる
- 不正確なアイテム合計に基づく整合性チェックが誤った結果を導く

**対策:**
- アイテム合計の信頼度スコアを低く設定（ベーススコア: 60）
- アイテム数が少ない場合（1-2個）は、アイテム合計による候補の信頼度を下げる
- アイテム合計とSubtotal/Totalの差が大きい場合（10セント以上）は警告を出し、自動修正を行わない

#### R-2: アイテムのtotalPriceが抽出されていない場合

**リスク:**
- アイテムの `totalPrice` が `null` の場合、アイテム合計を計算できない
- アイテム合計による整合性チェックが機能しない

**対策:**
- `totalPrice` が `null` のアイテムは除外して計算
- すべてのアイテムの `totalPrice` が `null` の場合は、アイテム合計による整合性チェックをスキップ
- エラーを発生させず、警告のみを出力

#### R-3: パフォーマンスへの影響

**リスク:**
- アイテム数が多い場合（100個以上）、アイテム合計の計算に時間がかかる

**対策:**
- アイテム合計の計算は O(n) で完了（n = アイテム数）
- 通常のレシートではアイテム数は10-20個程度のため、パフォーマンスへの影響は小さい
- 必要に応じて、アイテム数の上限を設定（例: 100個）

---

## 11. 成功基準

### 11.1 機能的な成功基準

1. ✅ アイテム合計が正しく計算される
2. ✅ アイテム合計とSubtotal/Totalの整合性がチェックされる
3. ✅ アイテム合計からSubtotal/Totalの候補が生成される
4. ✅ アイテム合計に基づく自動修正が機能する
5. ✅ 既存の整合性チェック機能と統合されている

### 11.2 非機能的な成功基準

1. ✅ パフォーマンス: アイテム合計の計算が 10ms 以内で完了
2. ✅ 信頼性: アイテムが0個やtotalPriceがnullの場合でもエラーを発生させない
3. ✅ 保守性: 既存のコードとの統合がスムーズで、コードの重複がない

---

## 12. 参考資料

- [Step 2: ルールベース抽出 + 整合性チェック 実装案](./step2-consistency-check-implementation.md)
- [テーブル整合性チェック要件定義書](./table-consistency-check-requirements.md)
- `lib/services/extraction/receipt_parser.dart` - 既存の実装
- `lib/data/models/receipt_item.dart` - ReceiptItemのデータ構造

