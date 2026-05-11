# テストレシート読み込み問題 - 調査報告書

**調査日**: 2025年1月  
**対象**: `flutter_app/assets/images/test_receipt.png`

---

## 1. レシートの内容

テストレシートには以下の情報が含まれています：

- **店舗名**: SUPERMARKET ABC
- **日付**: 2026-01-02 (YYYY-MM-DD形式)
- **時間**: 13:30:15
- **レシート番号**: 001234
- **商品**: 
  - Bread €2.50
  - Milk 1L €1.89
  - Apples 1kg €3.20
  - Coffee €4.99
- **Subtotal**: €12.58
- **VAT 24%**: €3.02
- **TOTAL**: €15.60
- **支払い方法**: CARD

---

## 2. 発見された問題点

### 2.1 VAT/Taxパターンのマッチング失敗 ⚠️ **重大**

**問題**: "VAT 24%: €3.02" という形式にマッチする正規表現パターンが存在しない

**現在のパターン** (`regex_patterns.dart`):
```dart
// パターン1: VATの後に直接金額が来る形式
RegExp(r'(tax|vat|sales tax)[:\s]*[€\$£¥₹]?\s*([\d,]+[.,]\d{1,2})', ...)
// → "VAT: €3.02" にはマッチするが、"VAT 24%: €3.02" にはマッチしない

// パターン2: パーセンテージが先に来る形式
RegExp(r'(\d+%.*tax)[:\s]*[€\$£¥₹]?\s*([\d,]+[.,]\d{1,2})', ...)
// → "24% tax: €3.02" にはマッチするが、"VAT 24%: €3.02" にはマッチしない
```

**原因**: VATとパーセンテージの間にスペースがあり、その後にコロンが来る形式に対応していない

**影響**: VAT金額が抽出されない → 税額計算の検証が失敗する可能性

---

### 2.2 TOTALパターンの潜在的問題

**問題**: "TOTAL: €15.60" の場合、パターンはマッチするはずだが、通貨記号の位置によっては問題が起きる可能性

**現在のパターン**:
```dart
RegExp(r'(total|sum|amount|grand total)[:\s]*[€\$£¥₹]?\s*([\d,]+[.,]\d{1,2})', ...)
```

**潜在的な問題**:
- `[:\s]*` の後に `[€\$£¥₹]?` があるため、コロンとスペースの後に通貨記号が来る形式にはマッチする
- しかし、`\s*` がオプショナルなため、スペースがない場合に問題が起きる可能性

**実際のテキスト**: "TOTAL: €15.60" → この形式にはマッチするはず

---

### 2.3 日付の検証による警告

**問題**: 2026年は未来の日付（現在から約1年後）のため、検証ロジックで警告が出る可能性

**検証ロジック** (`receipt_parser.dart:597`):
```dart
if (difference < -730 || difference > 365 * 5) { // Future date > 2 years or > 5 years old
  warnings.add('Date seems unusual: ${date.toIso8601String()}');
}
```

**影響**: 
- 警告は出るが、処理は続行される
- データ抽出自体は成功する

---

### 2.4 金額パース処理の問題

**問題**: `_parseAmount` メソッドで、通貨記号が前に来る場合の処理に問題がある可能性

**現在の処理** (`receipt_parser.dart:328-350`):
```dart
String cleaned = amountStr
    .replaceAll(RegExp(r'[€$£¥₹kr\s]'), '') // Remove currency symbols
    .replaceAll(RegExp(r'[^\d,.-]'), ''); // Keep only digits, commas, dots, dashes
```

**潜在的な問題**:
- 正規表現で金額を抽出する際、通貨記号が含まれた文字列が `match.group(match.groupCount)` で取得される
- その後、`_parseAmount` で通貨記号を除去するが、正規表現のグループ番号が正しくない可能性

---

### 2.5 正規表現グループの取得方法の問題

**問題**: `match.group(match.groupCount)` で最後のグループを取得しているが、これが正しい金額グループかどうか不明確

**現在のコード** (`receipt_parser.dart:310`):
```dart
final amountStr = match.group(match.groupCount);
```

**問題点**:
- `match.groupCount` はグループの総数（0ベースではない）
- 最後のグループを取得するには `match.group(match.groupCount)` ではなく、実際のグループ番号を指定する必要がある
- 正規表現パターンでは、金額は通常グループ2（`([\d,]+[.,]\d{1,2})`）にマッチする

**例**:
- パターン: `(total)[:\s]*[€]?\s*([\d,]+[.,]\d{1,2})`
- グループ0: 全体マッチ "TOTAL: €15.60"
- グループ1: "total"
- グループ2: "15.60" ← これが金額

**修正が必要**: `match.group(2)` または `match.group(match.groupCount)` の代わりに、正しいグループ番号を使用する

---

## 3. 推奨される修正

### 3.1 VATパターンの追加

```dart
// regex_patterns.dart の taxPatterns に追加
RegExp(r'(vat|tax)\s*\d+%[:\s]*[€\$£¥₹]?\s*([\d,]+[.,]\d{1,2})', multiLine: true, caseSensitive: false),
RegExp(r'(vat|tax)\s*\d+%[:\s]*([€\$£¥₹]?\s*[\d,]+[.,]\d{1,2})', multiLine: true, caseSensitive: false),
```

### 3.2 金額グループの取得方法の修正

```dart
// receipt_parser.dart の _extractAmountByType メソッド
// 現在:
final amountStr = match.group(match.groupCount);

// 修正後:
// パターンによって金額が含まれるグループを特定
// 通常は最後の数値グループが金額
final amountStr = match.groupCount >= 2 ? match.group(2) : match.group(match.groupCount);
```

### 3.3 デバッグログの追加

OCR結果と抽出過程の詳細なログを追加して、実際に何が起きているかを確認できるようにする

---

## 4. 次のステップ

1. **実際のOCR結果を確認**: ML Kitが実際にどのようなテキストを抽出しているかを確認
2. **正規表現パターンのテスト**: 実際のOCRテキストに対して各パターンをテスト
3. **グループ番号の修正**: 正規表現のグループ番号を正しく取得するように修正
4. **VATパターンの追加**: "VAT 24%: €3.02" 形式に対応するパターンを追加

---

## 5. 確認が必要な項目

- [ ] 実際のOCR結果テキスト
- [ ] 各正規表現パターンのマッチング結果
- [ ] 金額パース処理の動作確認
- [ ] エラーログの内容

