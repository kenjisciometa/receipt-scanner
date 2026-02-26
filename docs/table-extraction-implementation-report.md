# テーブル抽出実装レポート

## 概要

Subtotal、Tax、Totalをテーブル構造から抽出する実装について調査した結果を報告します。

## 実装の構造

### 1. エントリーポイント: `_extractAmountsFromTable`

**場所**: `receipt_parser.dart` 約690行目

**処理フロー**:
```
_extractAmountsFromTable
├─ textLinesが利用可能？
│  ├─ Yes → _extractAmountsFromTableWithBoundingBox (BBOX情報を使用)
│  └─ No  → _extractAmountsFromTableTextBased (テキストベース)
```

**特徴**:
- BBOX情報がある場合は構造ベースの抽出を優先
- ない場合はテキストベースの抽出にフォールバック

### 2. BBOX情報を使用した抽出: `_extractAmountsFromTableWithBoundingBox`

**場所**: `receipt_parser.dart` 約719行目

**処理ステップ**:

#### Step 1: テーブル構造の検出
- Y座標で行をグループ化（許容誤差: 10px）
- 同じY座標の行を結合

#### Step 2: ヘッダー行の検出
- **条件**: 金額が1つ以下、またはパーセンテージを含む
- 最初に見つかった行をヘッダーとして使用

#### Step 3: データ行の検出
- **条件**: ヘッダーの後、金額が3つ以上
- 複数のデータ行をサポート（複数のTax rateに対応）

#### Step 4: 値の抽出
- 各データ行に対して`_extractTableValuesFromBoundingBox`を呼び出し
- TaxとSubtotalを累積
- 最終的なTotal = 累積Subtotal + 累積Tax

**コード例**:
```dart
// 複数のデータ行を処理
for (int rowIndex = 0; rowIndex < dataRows.length; rowIndex++) {
  final extracted = _extractTableValuesFromBoundingBox(...);
  if (extracted.containsKey('tax_amount')) {
    totalTax += extracted['tax_amount']!;
  }
  if (extracted.containsKey('subtotal_amount')) {
    totalSubtotal += extracted['subtotal_amount']!;
  }
}

// 最終的なTotalを計算
if (totalSubtotal > 0 && totalTax > 0) {
  amounts['total_amount'] = totalSubtotal + totalTax;
}
```

### 3. テーブル値の抽出: `_extractTableValuesFromBoundingBox`

**場所**: `receipt_parser.dart` 約904行目

**処理フロー**:

#### Step 1: ヘッダーの列位置を取得
- ヘッダー行のelementsからX座標を抽出
- elementsがない場合は、ヘッダーのboundingBoxから推定（4列を仮定）

#### Step 2: データ行の値を取得
- データ行のelementsから金額とパーセンテージを抽出
- X座標と共に保存

#### Step 3: 値の割り当て（位置ベース）
```dart
if (amountValues.length >= 3) {
  // 通常: Tax, Subtotal, Total
  amounts['tax_amount'] = amountValues[0];
  amounts['subtotal_amount'] = amountValues[1];
  amounts['total_amount'] = amountValues[2];
} else if (amountValues.length == 2) {
  // Subtotal, Total
  amounts['subtotal_amount'] = amountValues[0];
  amounts['total_amount'] = amountValues[1];
}
```

**問題点**:
- **位置ベースの割り当て**: 列の順序に依存している
- **TaxBreakdown非対応**: 単一の`tax_amount`のみ抽出（複数のTax rateに対応していない）
- **パーセンテージと金額の対応関係が不明確**: パーセンテージは検出されるが、どの金額に対応するかが不明確

### 4. テキストベースの抽出: `_extractAmountsFromTableTextBased`

**場所**: `receipt_parser.dart` 約999行目

**処理ステップ**:

#### Step 1: ヘッダー行の検出
- **条件**: 金額が1つ以下、またはパーセンテージを含む

#### Step 2: データ行の検出
- **条件**: ヘッダーの後、金額が3つ以上
- パーセンテージを含む行もデータ行として扱う

#### Step 3: 値の抽出と累積
```dart
// 各データ行から金額を抽出（パーセンテージを除外）
final amountValues = dataAmountMatches
    .map((m) => m.group(0)!.trim())
    .where((v) => !v.contains('%'))  // パーセンテージを除外
    .map((v) => _parseAmount(v))
    .where((a) => a != null && a! > 0)
    .cast<double>()
    .toList();

if (amountValues.length >= 3) {
  // 通常: Tax, Subtotal, Total
  totalTax += amountValues[0];
  totalSubtotal += amountValues[1];
} else if (amountValues.length == 2) {
  // Subtotal, Total
  totalSubtotal += amountValues[0];
}
```

**問題点**:
- **位置ベースの割り当て**: BBOX版と同様の問題
- **パーセンテージ情報の活用不足**: パーセンテージを除外しているが、TaxBreakdownの抽出に活用していない

## 現在の実装の問題点

### 1. TaxBreakdown非対応

**現状**:
- テーブルからは単一の`tax_amount`のみ抽出
- 複数のTax rate（例: 14%, 24%）がある場合、それぞれの金額を個別に抽出していない

**影響**:
- `Tax 14%: 10, Tax 24%: 5`のようなテーブル形式では、`tax_amount: 15`のみ抽出
- `tax_breakdown`が空になる

### 2. 位置ベースの割り当て

**現状**:
- 金額の数に基づいて、位置で割り当て
  - 3つ以上: `[0] = Tax, [1] = Subtotal, [2] = Total`
  - 2つ: `[0] = Subtotal, [1] = Total`

**問題**:
- 列の順序が異なる場合（例: Subtotal, Tax, Total）に誤認識
- ヘッダーのラベルを参照していない

### 3. パーセンテージと金額の対応関係が不明確

**現状**:
- パーセンテージは検出されるが、どの金額に対応するかが不明確
- `_extractTableValuesFromBoundingBox`ではパーセンテージを検出するが、金額との対応関係を確立していない

**影響**:
- `Tax 24%: 3.02`のような場合、24%と3.02の対応関係が不明確

## 改善提案

### 1. ヘッダーラベルの活用

**提案**:
- ヘッダー行のラベル（"Tax", "Subtotal", "Total"など）を検出
- ラベルに基づいて列を割り当て

**実装例**:
```dart
// ヘッダー行からラベルを検出
final headerLabels = <String, int>{}; // label -> column index
for (int i = 0; i < headerLine.elements.length; i++) {
  final element = headerLine.elements[i];
  final text = element.text.toLowerCase();
  
  if (taxLabel.hasMatch(text)) {
    headerLabels['tax'] = i;
  } else if (subtotalLabel.hasMatch(text)) {
    headerLabels['subtotal'] = i;
  } else if (totalLabel.hasMatch(text)) {
    headerLabels['total'] = i;
  }
}

// ラベルに基づいて値を割り当て
if (headerLabels.containsKey('tax')) {
  final taxColumnIndex = headerLabels['tax']!;
  amounts['tax_amount'] = dataValues[taxColumnIndex];
}
```

### 2. TaxBreakdownの抽出

**提案**:
- 各データ行からTax rateと金額のペアを抽出
- `tax_breakdown`として保存

**実装例**:
```dart
// 各データ行からTaxBreakdownを抽出
final taxBreakdownList = <Map<String, double>>[];
for (final dataRow in dataRows) {
  final percentMatch = percentPattern.firstMatch(dataRow.text);
  final amountMatch = amountPattern.firstMatch(dataRow.text);
  
  if (percentMatch != null && amountMatch != null) {
    final rate = double.parse(percentMatch.group(0)!.replaceAll('%', ''));
    final amount = _parseAmount(amountMatch.group(0)!);
    
    if (rate != null && amount != null) {
      taxBreakdownList.add({'rate': rate, 'amount': amount});
    }
  }
}

if (taxBreakdownList.isNotEmpty) {
  amounts['tax_breakdown'] = taxBreakdownList;
}
```

### 3. パーセンテージと金額の対応関係の確立

**提案**:
- 同じelementまたは近接するelementからパーセンテージと金額を抽出
- BBOX情報を活用して、位置関係を確認

**実装例**:
```dart
// 同じelementまたは近接するelementからパーセンテージと金額を抽出
for (int i = 0; i < dataLine.elements.length; i++) {
  final element = dataLine.elements[i];
  final text = element.text;
  
  final percentMatch = percentPattern.firstMatch(text);
  if (percentMatch != null) {
    // 同じelementまたは次のelementから金額を探す
    double? amount;
    for (int j = i; j < min(i + 2, dataLine.elements.length); j++) {
      final amountMatch = amountPattern.firstMatch(dataLine.elements[j].text);
      if (amountMatch != null) {
        amount = _parseAmount(amountMatch.group(0)!);
        if (amount != null && amount > 0) {
          break;
        }
      }
    }
    
    if (amount != null) {
      final rate = double.parse(percentMatch.group(0)!.replaceAll('%', ''));
      taxBreakdownList.add({'rate': rate, 'amount': amount});
    }
  }
}
```

## テーブル候補の収集: `_collectTableCandidates`

**場所**: `receipt_parser.dart` 約3795行目

**処理**:
- `_extractAmountsFromTable`の結果を`AmountCandidate`に変換
- スコア: 95（テーブル抽出は高信頼度）
- `source`: `table_extraction_total`, `table_extraction_subtotal`, `table_extraction_tax`

**制限**:
- TaxBreakdownの抽出には対応していない
- 単一の`tax_amount`のみを候補として追加

## 関連メソッド

- `_extractAmountsFromTable`: エントリーポイント（約690行目）
- `_extractAmountsFromTableWithBoundingBox`: BBOX情報を使用（約719行目）
- `_extractAmountsFromTableTextBased`: テキストベース（約999行目）
- `_extractTableValuesFromBoundingBox`: テーブル値の抽出（約904行目）
- `_collectTableCandidates`: テーブル候補の収集（約3795行目）

## まとめ

現在の実装は、テーブル構造から基本的なSubtotal、Tax、Totalの抽出は可能ですが、以下の制限があります：

1. **TaxBreakdown非対応**: 複数のTax rateに対応していない
2. **位置ベースの割り当て**: 列の順序に依存している
3. **パーセンテージと金額の対応関係が不明確**: パーセンテージは検出されるが、どの金額に対応するかが不明確

改善提案として、ヘッダーラベルの活用、TaxBreakdownの抽出、パーセンテージと金額の対応関係の確立を提案しました。

