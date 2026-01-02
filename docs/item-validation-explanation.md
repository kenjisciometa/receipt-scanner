# アイテムの確認方法について

## 質問の意図の確認

「アイテムはアイテムとどのように確認しますか？」という質問について、以下の2つの可能性があります：

1. **アイテム同士の整合性チェック**（各アイテムの内部整合性）
2. **アイテム合計とSubtotal/Totalの整合性チェック**（アイテム全体と金額フィールドの整合性）

両方について説明します。

---

## 1. アイテム同士の整合性チェック（各アイテムの内部整合性）

### 1.1 現在の実装

**実装状況:** ✅ 部分的に実装済み

**場所:** `lib/data/models/receipt_item.dart`

**現在の確認方法:**

```dart
class ReceiptItem {
  // ...
  
  /// Calculated unit price (total / quantity)
  double get calculatedUnitPrice => totalPrice / quantity;
  
  /// Whether unit price matches the calculated value
  bool get hasUnitPriceDiscrepancy {
    if (unitPrice == null) return false;
    return (unitPrice! - calculatedUnitPrice).abs() > 0.01;
  }
}
```

**確認内容:**
- `unitPrice` が設定されている場合、`quantity * unitPrice = totalPrice` の整合性をチェック
- 差が1セント以上の場合、`hasUnitPriceDiscrepancy = true`

**例:**
```dart
// アイテム: 数量2、単価10.00、合計20.00
final item = ReceiptItem.create(
  name: "Bread",
  quantity: 2,
  unitPrice: 10.00,
  totalPrice: 20.00,
);

// 整合性チェック
if (item.hasUnitPriceDiscrepancy) {
  // unitPrice (10.00) * quantity (2) != totalPrice (20.00) の場合
  // または、差が1セント以上の場合
}
```

### 1.2 追加可能な確認方法

#### A. 各アイテムの内部整合性チェック（強化版）

**確認項目:**
1. `quantity * unitPrice = totalPrice` の整合性
2. `totalPrice > 0` の確認
3. `quantity > 0` の確認
4. `unitPrice > 0` の確認（unitPriceが設定されている場合）

**実装例:**
```dart
class ItemValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  
  ItemValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
}

ItemValidationResult validateItem(ReceiptItem item) {
  final errors = <String>[];
  final warnings = <String>[];
  
  // 1. 基本チェック
  if (item.totalPrice <= 0) {
    errors.add('Item totalPrice must be positive: ${item.totalPrice}');
  }
  
  if (item.quantity <= 0) {
    errors.add('Item quantity must be positive: ${item.quantity}');
  }
  
  // 2. unitPriceとtotalPriceの整合性
  if (item.unitPrice != null) {
    if (item.unitPrice! <= 0) {
      errors.add('Item unitPrice must be positive: ${item.unitPrice}');
    }
    
    final expectedTotal = item.unitPrice! * item.quantity;
    final difference = (item.totalPrice - expectedTotal).abs();
    
    if (difference > 0.01) {
      if (difference <= 0.10) {
        warnings.add('Item price discrepancy: expected ${expectedTotal.toStringAsFixed(2)}, got ${item.totalPrice.toStringAsFixed(2)}, diff: ${difference.toStringAsFixed(2)}');
      } else {
        errors.add('Large item price discrepancy: expected ${expectedTotal.toStringAsFixed(2)}, got ${item.totalPrice.toStringAsFixed(2)}, diff: ${difference.toStringAsFixed(2)}');
      }
    }
  }
  
  return ItemValidationResult(
    isValid: errors.isEmpty,
    errors: errors,
    warnings: warnings,
  );
}
```

#### B. アイテムリスト全体の整合性チェック

**確認項目:**
1. アイテムの重複チェック（同じ名前・価格のアイテムが複数ある場合）
2. アイテムの順序チェック（位置情報による）
3. アイテムの合計金額の計算

**実装例:**
```dart
class ItemsValidationResult {
  final bool isValid;
  final double? itemsSum;
  final int itemsCount;
  final List<String> errors;
  final List<String> warnings;
  
  ItemsValidationResult({
    required this.isValid,
    this.itemsSum,
    required this.itemsCount,
    this.errors = const [],
    this.warnings = const [],
  });
}

ItemsValidationResult validateItems(List<ReceiptItem> items) {
  final errors = <String>[];
  final warnings = <String>[];
  
  // 1. 各アイテムの内部整合性チェック
  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    final itemValidation = validateItem(item);
    
    if (!itemValidation.isValid) {
      errors.addAll(itemValidation.errors.map((e) => 'Item $i ($item.name): $e'));
    }
    warnings.addAll(itemValidation.warnings.map((w) => 'Item $i ($item.name): $w'));
  }
  
  // 2. アイテム合計の計算
  final itemsSum = items
      .where((item) => item.totalPrice > 0)
      .fold<double>(0.0, (sum, item) => sum + item.totalPrice);
  
  // 3. 重複チェック（オプション）
  final itemNames = <String, int>{};
  for (final item in items) {
    itemNames[item.name] = (itemNames[item.name] ?? 0) + 1;
  }
  
  for (final entry in itemNames.entries) {
    if (entry.value > 1) {
      warnings.add('Duplicate item name detected: "${entry.key}" appears ${entry.value} times');
    }
  }
  
  return ItemsValidationResult(
    isValid: errors.isEmpty,
    itemsSum: itemsSum > 0 ? itemsSum : null,
    itemsCount: items.length,
    errors: errors,
    warnings: warnings,
  );
}
```

---

## 2. アイテム合計とSubtotal/Totalの整合性チェック

### 2.1 現在の実装

**実装状況:** ✅ 部分的に実装済み（`Receipt` モデル内）

**場所:** `lib/data/models/receipt.dart`

**現在の確認方法:**
```dart
class Receipt {
  // ...
  
  /// Calculated total from items (for verification)
  double? get calculatedTotal {
    if (items.isEmpty) return null;
    return items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
  }
  
  /// Whether there's a discrepancy between stated and calculated totals
  bool get hasTotalDiscrepancy {
    final calculated = calculatedTotal;
    final total = totalAmount;
    if (calculated == null || total == null) return false;
    return (calculated - total).abs() > 0.01;
  }
}
```

**確認内容:**
- アイテムの合計金額を計算
- 抽出されたTotalと比較
- 差が1セント以上の場合、`hasTotalDiscrepancy = true`

**制限:**
- これは**抽出後の検証**であり、抽出プロセス中には使用されていない
- Subtotalとの整合性チェックは未実装

### 2.2 要件定義書で提案している確認方法

**詳細:** `docs/item-sum-consistency-requirements.md` を参照

**主な確認方法:**

#### A. アイテム合計の計算

```dart
double? _calculateItemsSum(List<ReceiptItem> items) {
  if (items.isEmpty) return null;
  
  final itemsWithPrice = items.where((item) => item.totalPrice > 0).toList();
  if (itemsWithPrice.isEmpty) return null;
  
  return itemsWithPrice.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
}
```

#### B. アイテム合計とSubtotal/Totalの整合性チェック

```dart
double _calculateItemsSumConsistencyScore({
  double? itemsSum,
  AmountCandidate? subtotal,
  AmountCandidate? total,
  AmountCandidate? tax,
  List<String> warnings,
}) {
  double score = 0.0;
  
  // 1. アイテム合計とSubtotalの整合性
  if (itemsSum != null && subtotal != null) {
    final difference = (itemsSum - subtotal.amount).abs();
    
    if (difference <= 0.01) {
      // 完全一致または1セント以内
      score += 0.15;  // ボーナス
    } else if (difference <= 0.10) {
      // 10セント以内
      score += 0.10;
      warnings.add('Items sum (${itemsSum.toStringAsFixed(2)}) != Subtotal (${subtotal.amount.toStringAsFixed(2)}), diff: ${difference.toStringAsFixed(2)}');
    } else {
      // 10セント以上
      warnings.add('Large difference between items sum (${itemsSum.toStringAsFixed(2)}) and Subtotal (${subtotal.amount.toStringAsFixed(2)}), diff: ${difference.toStringAsFixed(2)}');
    }
  }
  
  // 2. アイテム合計とTotalの整合性
  if (itemsSum != null && total != null) {
    final difference = (itemsSum - total.amount).abs();
    
    // 同様の処理
    // ただし、Totalは通常 Subtotal + Tax なので、
    // アイテム合計と直接比較する場合は注意が必要
  }
  
  // 3. アイテム合計 + Tax = Total の整合性
  if (itemsSum != null && tax != null && total != null) {
    final expectedTotal = itemsSum + tax.amount;
    final difference = (total.amount - expectedTotal).abs();
    
    if (difference <= 0.01) {
      score += 0.15;  // ボーナス
    } else if (difference <= 0.10) {
      score += 0.10;
      warnings.add('Items sum + Tax (${expectedTotal.toStringAsFixed(2)}) != Total (${total.amount.toStringAsFixed(2)}), diff: ${difference.toStringAsFixed(2)}');
    } else {
      warnings.add('Large difference: Items sum + Tax (${expectedTotal.toStringAsFixed(2)}) != Total (${total.amount.toStringAsFixed(2)}), diff: ${difference.toStringAsFixed(2)}');
    }
  }
  
  return score;
}
```

#### C. アイテム合計からSubtotal/Totalを予測

```dart
List<AmountCandidate> _generateCandidatesFromItemsSum(
  double itemsSum,
  List<ReceiptItem> items,
  List<TextLine>? textLines,
) {
  final candidates = <AmountCandidate>[];
  
  // 信頼度スコアの計算
  int score = 60;  // ベーススコア
  if (items.length >= 3) score += 10;
  if (items.length >= 5) score += 10;
  
  final allHavePrice = items.every((item) => item.totalPrice > 0);
  if (allHavePrice) score += 10;
  
  // Subtotal候補として追加
  candidates.add(AmountCandidate(
    amount: itemsSum,
    score: score.clamp(0, 100),
    lineIndex: -1,  // アイテム合計は特定の行にない
    source: 'items_sum_subtotal',
    fieldName: 'subtotal_amount',
    label: 'Items Sum',
  ));
  
  return candidates;
}
```

---

## 3. 推奨される確認方法の統合

### 3.1 確認の階層構造

```
Level 1: 各アイテムの内部整合性
  ├─ quantity * unitPrice = totalPrice?
  ├─ totalPrice > 0?
  └─ quantity > 0?

Level 2: アイテムリスト全体の整合性
  ├─ アイテムの重複チェック
  ├─ アイテム合計の計算
  └─ アイテムの順序チェック（位置情報）

Level 3: アイテム合計とSubtotal/Totalの整合性
  ├─ Items Sum = Subtotal?
  ├─ Items Sum + Tax = Total?
  └─ Items Sum = Total? (Taxがない場合)
```

### 3.2 実装の統合ポイント

**推奨される実装順序:**

1. **Phase 1: 各アイテムの内部整合性チェック**（抽出時）
   - `_extractItems` メソッド内で、各アイテムを追加する前に整合性をチェック
   - 整合性に問題があるアイテムは警告を出して追加

2. **Phase 2: アイテムリスト全体の整合性チェック**（抽出後）
   - `_extractItems` の戻り値に対して `validateItems` を実行
   - エラーや警告をログに記録

3. **Phase 3: アイテム合計とSubtotal/Totalの整合性チェック**（整合性チェック時）
   - `_calculateConsistencyScore` メソッド内で実行
   - 整合性スコアに反映

---

## 4. 実装例

### 4.1 統合された確認メソッド

```dart
class ItemConsistencyChecker {
  /// アイテムの整合性をチェックし、結果を返す
  static ItemsValidationResult validateItems(List<ReceiptItem> items) {
    final errors = <String>[];
    final warnings = <String>[];
    
    // Level 1: 各アイテムの内部整合性
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final itemResult = _validateSingleItem(item, i);
      errors.addAll(itemResult.errors);
      warnings.addAll(itemResult.warnings);
    }
    
    // Level 2: アイテムリスト全体の整合性
    final itemsSum = _calculateItemsSum(items);
    final duplicateCheck = _checkDuplicates(items);
    warnings.addAll(duplicateCheck);
    
    return ItemsValidationResult(
      isValid: errors.isEmpty,
      itemsSum: itemsSum,
      itemsCount: items.length,
      errors: errors,
      warnings: warnings,
    );
  }
  
  /// 単一アイテムの整合性をチェック
  static ItemValidationResult _validateSingleItem(ReceiptItem item, int index) {
    final errors = <String>[];
    final warnings = <String>[];
    
    // 基本チェック
    if (item.totalPrice <= 0) {
      errors.add('Item $index: totalPrice must be positive');
    }
    
    if (item.quantity <= 0) {
      errors.add('Item $index: quantity must be positive');
    }
    
    // unitPriceとtotalPriceの整合性
    if (item.unitPrice != null) {
      final expectedTotal = item.unitPrice! * item.quantity;
      final difference = (item.totalPrice - expectedTotal).abs();
      
      if (difference > 0.01) {
        if (difference <= 0.10) {
          warnings.add('Item $index: price discrepancy (${difference.toStringAsFixed(2)})');
        } else {
          errors.add('Item $index: large price discrepancy (${difference.toStringAsFixed(2)})');
        }
      }
    }
    
    return ItemValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
  
  /// アイテム合計を計算
  static double? _calculateItemsSum(List<ReceiptItem> items) {
    if (items.isEmpty) return null;
    
    final validItems = items.where((item) => item.totalPrice > 0).toList();
    if (validItems.isEmpty) return null;
    
    return validItems.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
  }
  
  /// 重複チェック
  static List<String> _checkDuplicates(List<ReceiptItem> items) {
    final warnings = <String>[];
    final itemMap = <String, List<int>>{};  // 名前 -> インデックスのリスト
    
    for (int i = 0; i < items.length; i++) {
      final name = items[i].name.toLowerCase();
      itemMap.putIfAbsent(name, () => []).add(i);
    }
    
    for (final entry in itemMap.entries) {
      if (entry.value.length > 1) {
        warnings.add('Duplicate item: "${entry.key}" appears ${entry.value.length} times at indices: ${entry.value.join(", ")}');
      }
    }
    
    return warnings;
  }
}
```

### 4.2 整合性チェックへの統合

```dart
// _extractAmountsLineByLine メソッド内で
Map<String, double> _extractAmountsLineByLine(
  List<String> lines,
  String? language,
  List<String> appliedPatterns, {
  List<TextLine>? textLines,
  List<ReceiptItem>? items,  // 新規追加
}) {
  // 1. アイテムの整合性チェック（新規追加）
  ItemsValidationResult? itemsValidation;
  if (items != null && items.isNotEmpty) {
    itemsValidation = ItemConsistencyChecker.validateItems(items);
    
    // エラーをログに記録
    if (itemsValidation.errors.isNotEmpty) {
      for (final error in itemsValidation.errors) {
        logger.w('⚠️ Item validation error: $error');
      }
    }
    
    // 警告をログに記録
    if (itemsValidation.warnings.isNotEmpty) {
      for (final warning in itemsValidation.warnings) {
        logger.w('⚠️ Item validation warning: $warning');
      }
    }
  }
  
  // 2. すべての候補を統合収集（itemsSum を含む）
  final allCandidates = _collectAllCandidates(
    lines,
    language,
    appliedPatterns,
    textLines: textLines,
    items: items,  // 新規追加
    itemsSum: itemsValidation?.itemsSum,  // 新規追加
  );
  
  // 3. 整合性チェックで最適解を選択
  final consistencyResult = _selectBestCandidates(
    allCandidates,
    items: items,  // 新規追加
    itemsSum: itemsValidation?.itemsSum,  // 新規追加
  );
  
  // ...
}
```

---

## 5. まとめ

### 現在の実装状況

1. ✅ **各アイテムの内部整合性**: 部分的に実装済み（`hasUnitPriceDiscrepancy`）
2. ❌ **アイテムリスト全体の整合性**: 未実装
3. ✅ **アイテム合計とTotalの整合性**: 部分的に実装済み（`Receipt.calculatedTotal`, `hasTotalDiscrepancy`）
4. ❌ **アイテム合計とSubtotalの整合性**: 未実装
5. ❌ **抽出プロセス中の整合性チェック**: 未実装（抽出後の検証のみ）

### 推奨される実装

1. **各アイテムの内部整合性チェック**を強化
2. **アイテムリスト全体の整合性チェック**を追加
3. **アイテム合計とSubtotal/Totalの整合性チェック**を抽出プロセス中に統合
4. **アイテム合計からSubtotal/Totalを予測**する機能を追加

これにより、アイテムの整合性を多層的にチェックし、抽出精度を向上させることができます。

