# Tax抽出改善提案

## 問題の概要

現在、`Tax 24%: 3.02`のような記載で、Tax amountが24と誤認識されています。

### 現状の問題

1. **ログから確認された問題**:
   - `"VAT 24%: €3.02"`という行で、24%と3.02が別のブロック（elements）に分かれている
   - 現在のロジックでは、パーセンテージの値（24）と金額の値（3.02）を区別できていない
   - ログ: `Found 1 percentage matches, 2 amount matches` → `Adding tax breakdown candidate: 24.0% = 24.0`

2. **現在の実装の問題点**:
   - `:`マークを境界として使用していない
   - BBOX情報（elements）を活用して、Taxラベルと金額の位置関係を考慮していない
   - パーセンテージの値と金額の値の比較が不十分（24と3.02は明らかに異なるが、最初に見つかった値が選ばれている）

## 修正案

### アプローチ1: `:`マークを境界として使用（推奨）

**実装方針**:
1. Tax行に`:`マークがある場合、`:`の後の金額を優先的に抽出
2. `:`マークがない場合でも、パーセンテージの値と金額の値を厳密に比較

**実装詳細**:
```dart
if (taxLabel.hasMatch(lower)) {
  // 1. `:`マークの位置を確認
  final colonIndex = line.indexOf(':');
  final hasColon = colonIndex != -1;
  
  // 2. パーセンテージを抽出
  final percentPattern = RegExp(r'(\d+(?:[.,]\d+)?)\s*%');
  final percentMatch = percentPattern.firstMatch(line);
  double? percent;
  if (percentMatch != null) {
    final percentStr = percentMatch.group(1)!.replaceAll(',', '.');
    percent = double.tryParse(percentStr);
    if (percent != null && (percent <= 0 || percent > 100)) {
      percent = null;
    }
  }
  
  // 3. 金額を抽出
  double? directAmount;
  final allAmountMatches = amountCapture.allMatches(line).toList();
  
  if (allAmountMatches.isNotEmpty) {
    if (hasColon) {
      // `:`マークがある場合、`:`の後の金額を優先
      for (final match in allAmountMatches) {
        final matchStart = match.start;
        if (matchStart > colonIndex) {
          // `:`の後の金額
          final amountStr = match.group(0)!;
          final amount = _parseAmount(amountStr);
          if (amount != null && amount > 0) {
            // パーセンテージの値と一致しないことを確認
            if (percent == null || (amount - percent).abs() > 0.1) {
              directAmount = amount;
              break;
            }
          }
        }
      }
    } else {
      // `:`マークがない場合、既存のロジックを使用（パーセンテージの値を除外）
      // ... 既存のロジック ...
    }
  }
}
```

**メリット**:
- シンプルで実装が容易
- `:`マークがある場合の精度が高い
- 既存のロジックとの互換性が高い

**デメリット**:
- `:`マークがない場合の精度が低い可能性

### アプローチ2: BBOX情報を活用（推奨）

**実装方針**:
1. Taxラベルを含むTextLineのelementsを確認
2. Taxラベルの右側にある金額を優先的に抽出
3. パーセンテージの値と金額の値を厳密に比較

**実装詳細**:
```dart
if (taxLabel.hasMatch(lower) && textLines != null && i < textLines.length) {
  final textLine = textLines[i];
  final elements = textLine.elements;
  
  if (elements != null && elements.isNotEmpty) {
    // 1. Taxラベルを含むelementを特定
    int? taxLabelElementIndex;
    for (int j = 0; j < elements.length; j++) {
      if (taxLabel.hasMatch(elements[j].text.toLowerCase())) {
        taxLabelElementIndex = j;
        break;
      }
    }
    
    if (taxLabelElementIndex != null) {
      // 2. Taxラベルの右側にある金額を探す
      final taxLabelBbox = elements[taxLabelElementIndex].boundingBox;
      if (taxLabelBbox != null && taxLabelBbox.length >= 4) {
        final taxLabelRightX = taxLabelBbox[0] + taxLabelBbox[2];
        
        // 3. Taxラベルの右側にある金額を抽出
        for (int j = taxLabelElementIndex + 1; j < elements.length; j++) {
          final elementBbox = elements[j].boundingBox;
          if (elementBbox != null && elementBbox.length >= 4) {
            final elementLeftX = elementBbox[0];
            
            // Taxラベルの右側にある要素
            if (elementLeftX > taxLabelRightX) {
              final amountMatch = amountCapture.firstMatch(elements[j].text);
              if (amountMatch != null) {
                final amountStr = amountMatch.group(0)!;
                final amount = _parseAmount(amountStr);
                if (amount != null && amount > 0) {
                  // パーセンテージの値と一致しないことを確認
                  if (percent == null || (amount - percent).abs() > 0.1) {
                    directAmount = amount;
                    break;
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

**メリット**:
- BBOX情報を活用して、位置関係を正確に判断
- `:`マークがない場合でも動作
- より堅牢な実装

**デメリット**:
- 実装が複雑
- elements情報が必要（textLinesがnullの場合に対応が必要）

### アプローチ3: ハイブリッド（推奨）

**実装方針**:
1. まず`:`マークを境界として使用（アプローチ1）
2. `:`マークがない場合、BBOX情報を活用（アプローチ2）
3. どちらも使えない場合、既存のロジックを使用（パーセンテージの値を除外）

**実装詳細**:
```dart
if (taxLabel.hasMatch(lower)) {
  // 1. パーセンテージを抽出
  final percentPattern = RegExp(r'(\d+(?:[.,]\d+)?)\s*%');
  final percentMatch = percentPattern.firstMatch(line);
  double? percent;
  if (percentMatch != null) {
    final percentStr = percentMatch.group(1)!.replaceAll(',', '.');
    percent = double.tryParse(percentStr);
    if (percent != null && (percent <= 0 || percent > 100)) {
      percent = null;
    }
  }
  
  // 2. 金額を抽出（優先順位: `:`マーク > BBOX情報 > 既存ロジック）
  double? directAmount;
  final allAmountMatches = amountCapture.allMatches(line).toList();
  
  if (allAmountMatches.isNotEmpty) {
    // 優先順位1: `:`マークを境界として使用
    final colonIndex = line.indexOf(':');
    if (colonIndex != -1) {
      for (final match in allAmountMatches) {
        final matchStart = match.start;
        if (matchStart > colonIndex) {
          final amountStr = match.group(0)!;
          final amount = _parseAmount(amountStr);
          if (amount != null && amount > 0) {
            if (percent == null || (amount - percent).abs() > 0.1) {
              directAmount = amount;
              break;
            }
          }
        }
      }
    }
    
    // 優先順位2: BBOX情報を活用（`: `マークがない場合）
    if (directAmount == null && textLines != null && i < textLines.length) {
      final textLine = textLines[i];
      final elements = textLine.elements;
      
      if (elements != null && elements.isNotEmpty) {
        // Taxラベルを含むelementを特定
        int? taxLabelElementIndex;
        for (int j = 0; j < elements.length; j++) {
          if (taxLabel.hasMatch(elements[j].text.toLowerCase())) {
            taxLabelElementIndex = j;
            break;
          }
        }
        
        if (taxLabelElementIndex != null) {
          final taxLabelBbox = elements[taxLabelElementIndex].boundingBox;
          if (taxLabelBbox != null && taxLabelBbox.length >= 4) {
            final taxLabelRightX = taxLabelBbox[0] + taxLabelBbox[2];
            
            // Taxラベルの右側にある金額を探す
            for (int j = taxLabelElementIndex + 1; j < elements.length; j++) {
              final elementBbox = elements[j].boundingBox;
              if (elementBbox != null && elementBbox.length >= 4) {
                final elementLeftX = elementBbox[0];
                
                if (elementLeftX > taxLabelRightX) {
                  final amountMatch = amountCapture.firstMatch(elements[j].text);
                  if (amountMatch != null) {
                    final amountStr = amountMatch.group(0)!;
                    final amount = _parseAmount(amountStr);
                    if (amount != null && amount > 0) {
                      if (percent == null || (amount - percent).abs() > 0.1) {
                        directAmount = amount;
                        break;
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    
    // 優先順位3: 既存のロジック（パーセンテージの値を除外）
    if (directAmount == null) {
      // ... 既存のロジック ...
    }
  }
}
```

**メリット**:
- 複数のアプローチを組み合わせて、高い精度を実現
- 様々なケースに対応可能
- 既存のロジックとの互換性が高い

**デメリット**:
- 実装が複雑
- パフォーマンスへの影響を考慮する必要がある

## 推奨実装

**アプローチ3（ハイブリッド）を推奨**します。理由：
1. `:`マークがある場合の精度が高い
2. `:`マークがない場合でも、BBOX情報を活用して対応可能
3. 既存のロジックとの互換性が高い

## 実装時の注意点

1. **パーセンテージの値と金額の値の比較**:
   - 現在のロジックでは、`(amountValue - percent).abs() < 0.01`で比較しているが、24と3.02は明らかに異なる
   - より厳密な比較が必要（例: `(amount - percent).abs() > 0.1`）

2. **BBOX情報の可用性**:
   - `textLines`がnullの場合や、`elements`が空の場合に対応が必要
   - フォールバックロジックを実装

3. **複数のTax rateがある場合**:
   - `Tax 14% 10, Tax 24% 5`のような場合、各Tax rateに対応する金額を正確に抽出する必要がある
   - BBOX情報を活用して、各Tax rateと金額の対応関係を確認

4. **ログの改善**:
   - どのアプローチが使用されたかをログに記録
   - デバッグを容易にする

## テストケース

1. **`:`マークがある場合**:
   - `Tax 24%: 3.02` → Tax amount: 3.02
   - `VAT 24%: €3.02` → Tax amount: 3.02

2. **`:`マークがない場合**:
   - `Tax 24% 3.02` → Tax amount: 3.02
   - `VAT 24% €3.02` → Tax amount: 3.02

3. **複数のTax rateがある場合**:
   - `Tax 14% 10, Tax 24% 5` → TaxBreakdown: [{rate: 14.0, amount: 10.0}, {rate: 24.0, amount: 5.0}]

4. **パーセンテージのみの場合**:
   - `Tax 24%` → Subtotalから計算

## 現在の実装の詳細

### 問題のあるコード（約2780-2797行目）

```dart
// このパーセンテージに対応する金額を探す
double? matchedAmount;
for (final amountMatch in allAmountMatches) {
  final amountStr = amountMatch.group(0)!;
  final cleanedAmountStr = amountStr.replaceAll(RegExp(r'[€$£¥₹\s-]'), '');
  final amountValue = double.tryParse(cleanedAmountStr.replaceAll(',', '.'));
  
  // パーセンテージの値と一致する場合はスキップ
  if (amountValue != null && (amountValue - percent).abs() < 0.01) {
    continue;
  }
  
  final amount = _parseAmount(amountStr);
  if (amount != null && amount > 0) {
    matchedAmount = amount;
    break;  // ← 問題: 最初に見つかった金額を選んでいる
  }
}
```

**問題点**:
1. `:`マークの位置を考慮していない
2. BBOX情報（elements）を活用していない
3. 最初に見つかった金額を選んでいるため、24が選ばれてしまう
4. パーセンテージの値（24）と金額の値（3.02）の比較が不十分（24 - 3.02 = 20.98 > 0.01なので、スキップされない）

### ログから確認された動作

```
Found 1 percentage matches, 2 amount matches
Adding tax breakdown candidate: 24.0% = 24.0 (line: 12)
```

- 2つの金額マッチ（24と3.02）があるが、最初の24が選ばれている
- `:`マークやBBOX情報を活用していない

## 関連ファイル

- `flutter_app/lib/services/extraction/receipt_parser.dart`: `_collectLineBasedCandidates`メソッド（約2762行目）
- `flutter_app/lib/services/ocr/ml_kit_service.dart`: TextLineとelementsの生成（約164-309行目）

## 実装の優先順位

1. **即座に実装すべき**: アプローチ1（`:`マークを境界として使用）
   - 実装が簡単で、多くのケースで有効
   - ログから`:`マークがあることが確認されている

2. **次に実装すべき**: アプローチ2（BBOX情報を活用）
   - `:`マークがない場合に対応
   - より堅牢な実装

3. **最終的に**: アプローチ3（ハイブリッド）
   - すべてのケースに対応
   - 最高の精度を実現

