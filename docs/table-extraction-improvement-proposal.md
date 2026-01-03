# テーブル抽出改善提案: アイテムテーブルとサマリーテーブルの区別

## 問題の概要

現在のテーブル抽出ロジックは、アイテムテーブル（商品リスト）とサマリーテーブル（Subtotal, Tax, Total）を区別できていません。その結果、以下の問題が発生しています：

1. **アイテムテーブルの誤認識**: アイテムテーブル（QTY, Description, Unit Price, Amount）がサマリーテーブルとして誤認識される
2. **誤った値の抽出**: アイテムテーブルの各行（QTY, Unit Price, Amount）が Tax/Subtotal/Total として誤って解釈される
3. **明示的なラベルマッチの無視**: 正しいサマリー（"Subtotal $250.00", "Total $262.50"）がテーブル抽出の誤った値に負けている

## 修正案

### 0. LanguageKeywordsへの新規カテゴリ追加（前提条件）

**目的**: アイテムテーブル識別用のキーワードを`LanguageKeywords`に追加

**実装場所**: `lib/core/constants/language_keywords.dart`

**追加内容**:

既存の`LanguageKeywords`クラスに、アイテムテーブルのヘッダーキーワード用の新しいカテゴリ`item_table_header`を追加します。これにより、ヨーロッパ言語（英語、フィンランド語、スウェーデン語、フランス語、ドイツ語、イタリア語、スペイン語）のキーワードを一元管理できます。

**メリット**:
- メンテナンス性の向上: キーワードの追加・修正が1箇所で完結
- 多言語対応の一貫性: 既存の多言語対応システムと統合
- 拡張性: 新しい言語の追加が容易

### 1. テーブルタイプの識別

**目的**: アイテムテーブルとサマリーテーブルを区別する

**実装方法**:

#### 1.1 LanguageKeywordsへの新規カテゴリ追加

まず、`LanguageKeywords`クラスにアイテムテーブル用のカテゴリを追加する必要があります：

**`lib/core/constants/language_keywords.dart`への追加**:

```dart
static const Map<String, Map<String, List<String>>> keywords = {
  // ... (既存のカテゴリ) ...
  
  // アイテムテーブルのヘッダーキーワード（新規追加）
  'item_table_header': {
    'en': ['qty', 'quantity', 'description', 'item', 'product', 'unit price', 'unit', 'price', 'amount'],
    'fi': ['määrä', 'kappalemäärä', 'kuvaus', 'tuote', 'yksikköhinta', 'hinta', 'summa'],
    'sv': ['kvantitet', 'antal', 'beskrivning', 'produkt', 'enhetspris', 'pris', 'belopp'],
    'fr': ['quantité', 'description', 'article', 'produit', 'prix unitaire', 'prix', 'montant'],
    'de': ['menge', 'anzahl', 'beschreibung', 'artikel', 'produkt', 'einzelpreis', 'preis', 'betrag'],
    'it': ['quantità', 'descrizione', 'articolo', 'prodotto', 'prezzo unitario', 'prezzo', 'importo'],
    'es': ['cantidad', 'descripción', 'artículo', 'producto', 'precio unitario', 'precio', 'importe'],
  },
};
```

#### 1.2 ヘッダー行の内容チェック（LanguageKeywordsを使用）

```dart
import '../../core/constants/language_keywords.dart';

bool _isItemTableHeader(String headerText) {
  final lower = headerText.toLowerCase();
  
  // LanguageKeywordsからアイテムテーブルのキーワードを取得
  final itemTableKeywords = LanguageKeywords.getAllKeywords('item_table_header');
  
  int keywordCount = 0;
  for (final keyword in itemTableKeywords) {
    if (lower.contains(keyword.toLowerCase())) {
      keywordCount++;
    }
  }
  
  // 2つ以上のキーワードが含まれている場合、アイテムテーブル
  return keywordCount >= 2;
}

bool _isSummaryTableHeader(String headerText) {
  final lower = headerText.toLowerCase();
  
  // LanguageKeywordsから既存のカテゴリを使用
  final totalKeywords = LanguageKeywords.getAllKeywords('total');
  final subtotalKeywords = LanguageKeywords.getAllKeywords('subtotal');
  final taxKeywords = LanguageKeywords.getAllKeywords('tax');
  
  // サマリーテーブルのキーワードを統合
  final summaryTableKeywords = [
    ...totalKeywords,
    ...subtotalKeywords,
    ...taxKeywords,
  ];
  
  for (final keyword in summaryTableKeywords) {
    if (lower.contains(keyword.toLowerCase())) {
      return true;
    }
  }
  
  return false;
}
```

#### 1.3 テーブルタイプの判定

```dart
TextLine? headerLine;
bool isItemTable = false;
bool isSummaryTable = false;

if (headerLine != null) {
  final headerText = headerLine.text.toLowerCase();
  
  isItemTable = _isItemTableHeader(headerText);
  isSummaryTable = _isSummaryTableHeader(headerText);
  
  // アイテムテーブルの場合はスキップ
  if (isItemTable && !isSummaryTable) {
    logger.d('📊 Skipping item table (not a summary table)');
    return <String, double>{};
  }
}
```

### 2. ヘッダー検出の改善

**目的**: より厳密な条件でサマリーテーブルのヘッダーを検出

**現在の問題**:
- 条件が緩すぎる: `headerAmountCount <= 1 || headerHasPercent`
- "Your Company Inc."のような会社名がヘッダーとして誤検出される

**改善案**:

```dart
import '../../core/constants/language_keywords.dart';

// より厳密なヘッダー検出条件
bool _isValidSummaryTableHeader(String headerText, int amountCount, bool hasPercent) {
  final lower = headerText.toLowerCase();
  
  // LanguageKeywordsからキーワードを取得
  final totalKeywords = LanguageKeywords.getAllKeywords('total');
  final subtotalKeywords = LanguageKeywords.getAllKeywords('subtotal');
  final taxKeywords = LanguageKeywords.getAllKeywords('tax');
  final itemTableKeywords = LanguageKeywords.getAllKeywords('item_table_header');
  
  // サマリーテーブルのキーワードを統合
  final summaryTableKeywords = [
    ...totalKeywords,
    ...subtotalKeywords,
    ...taxKeywords,
  ];
  
  // サマリーテーブルのキーワードが含まれているか確認
  final hasSummaryKeyword = summaryTableKeywords.any((keyword) => 
    lower.contains(keyword.toLowerCase())
  );
  
  // アイテムテーブルのキーワードが含まれていないか確認
  final hasItemKeyword = itemTableKeywords.any((keyword) => 
    lower.contains(keyword.toLowerCase())
  );
  
  // 条件:
  // 1. サマリーテーブルのキーワードを含む
  // 2. アイテムテーブルのキーワードを含まない
  // 3. 金額が1つ以下、またはパーセンテージを含む
  if (hasItemKeyword && !hasSummaryKeyword) {
    return false; // アイテムテーブル
  }
  
  if (hasSummaryKeyword && (amountCount <= 1 || hasPercent)) {
    return true; // サマリーテーブル
  }
  
  return false;
}
```

### 3. 明示的なラベルマッチの優先

**目的**: テーブル抽出よりも明示的なラベルマッチを優先

**実装方法**:

`_selectBestCandidates`メソッドで、明示的なラベルマッチ（`subtotal_label`, `total_label`）が存在する場合、テーブル抽出の候補を除外またはスコアを下げる：

```dart
// 明示的なラベルマッチが存在する場合、テーブル抽出の候補を除外
bool hasExplicitSubtotal = candidates['subtotal_amount']!
    .any((c) => c.source == 'subtotal_label');
bool hasExplicitTotal = candidates['total_amount']!
    .any((c) => c.source == 'total_label');

if (hasExplicitSubtotal || hasExplicitTotal) {
  // テーブル抽出の候補を除外
  candidates['subtotal_amount']!.removeWhere((c) => c.source.startsWith('table_extraction'));
  candidates['total_amount']!.removeWhere((c) => c.source.startsWith('table_extraction'));
  candidates['tax_amount']!.removeWhere((c) => c.source.startsWith('table_extraction'));
  
  logger.d('🔍 Filtered table extraction candidates (explicit label matches found)');
}
```

### 4. テーブル抽出のスコア調整

**目的**: アイテムテーブルを誤認識した場合のスコアを下げる

**実装方法**:

テーブル抽出の候補に、テーブルタイプの検証結果を反映：

```dart
// テーブル抽出の候補を追加
if (amounts.isNotEmpty) {
  // テーブルタイプの検証
  bool isValidSummaryTable = _isValidSummaryTableHeader(
    headerLine.text,
    headerAmountCount,
    headerHasPercent
  );
  
  if (!isValidSummaryTable) {
    // アイテムテーブルの場合はスコアを下げる
    final score = 70; // 通常は95
    logger.d('📊 Lowering table extraction score (item table detected): $score');
  } else {
    final score = 95; // 通常のスコア
  }
}
```

### 5. データ行の検証

**目的**: データ行がサマリーテーブルの行であることを確認

**実装方法**:

データ行にサマリーテーブルのキーワードが含まれているか確認：

```dart
import '../../core/constants/language_keywords.dart';

bool _isSummaryTableDataRow(String rowText) {
  final lower = rowText.toLowerCase();
  
  // LanguageKeywordsからキーワードを取得
  final totalKeywords = LanguageKeywords.getAllKeywords('total');
  final subtotalKeywords = LanguageKeywords.getAllKeywords('subtotal');
  final taxKeywords = LanguageKeywords.getAllKeywords('tax');
  final itemTableKeywords = LanguageKeywords.getAllKeywords('item_table_header');
  
  // サマリーテーブルのキーワードを統合
  final summaryTableKeywords = [
    ...totalKeywords,
    ...subtotalKeywords,
    ...taxKeywords,
  ];
  
  // サマリーテーブルのキーワードが含まれているか確認
  final hasSummaryKeyword = summaryTableKeywords.any((keyword) => 
    lower.contains(keyword.toLowerCase())
  );
  
  // アイテムテーブルのキーワードが含まれていないか確認
  final hasItemKeyword = itemTableKeywords.any((keyword) => 
    lower.contains(keyword.toLowerCase())
  );
  
  // 条件:
  // 1. サマリーテーブルのキーワードを含む、または
  // 2. アイテムテーブルのキーワードを含まない（かつ金額が3つ以上）
  if (hasItemKeyword && !hasSummaryKeyword) {
    return false; // アイテムテーブルの行
  }
  
  return true; // サマリーテーブルの行
}
```

## 実装の優先順位

### Phase 0: 前提条件（最初に実施）

0. **LanguageKeywordsへの新規カテゴリ追加**: `item_table_header`カテゴリを`lib/core/constants/language_keywords.dart`に追加
   - ヨーロッパ言語（en, fi, sv, fr, de, it, es）のキーワードを定義
   - 既存の多言語対応システムと統合

### Phase 1: 基本的な区別（最優先）

1. **テーブルタイプの識別**: アイテムテーブルとサマリーテーブルを区別（`LanguageKeywords`を使用）
2. **ヘッダー検出の改善**: より厳密な条件でサマリーテーブルのヘッダーを検出（`LanguageKeywords`を使用）
3. **明示的なラベルマッチの優先**: テーブル抽出よりも明示的なラベルマッチを優先

### Phase 2: 精度の向上

4. **データ行の検証**: データ行がサマリーテーブルの行であることを確認（`LanguageKeywords`を使用）
5. **テーブル抽出のスコア調整**: アイテムテーブルを誤認識した場合のスコアを下げる

## 実装例

### 修正後の`_extractAmountsFromTableWithBoundingBox`

```dart
import '../../core/constants/language_keywords.dart';

Map<String, double> _extractAmountsFromTableWithBoundingBox(
  List<TextLine> textLines,
  List<String> appliedPatterns,
  RegExp amountPattern,
  RegExp percentPattern,
) {
  final amounts = <String, double>{};
  const yTolerance = 10.0;
  
  // ... (既存のコード: 行のグループ化) ...
  
  // Step 2: Find table structure - look for header row and all data rows
  TextLine? headerLine;
  int headerIndex = -1;
  final dataRows = <TextLine>[];
  
  for (int i = 0; i < textLines.length; i++) {
    final line = textLines[i];
    final yCoord = line.boundingBox?[1] ?? 0.0;
    
    // ... (既存のコード: 同じY座標の行を結合) ...
    
    // 改善: より厳密なヘッダー検出（LanguageKeywordsを使用）
    if ((headerAmountCount <= 1 || headerHasPercent) && headerLine == null) {
      // テーブルタイプの判定
      final isItemTable = _isItemTableHeader(combinedText);
      final isSummaryTable = _isSummaryTableHeader(combinedText);
      
      if (isItemTable && !isSummaryTable) {
        // アイテムテーブルの場合はスキップ
        logger.d('📊 Skipping item table header at line $i: "${combinedText}"');
        continue;
      }
      
      if (isSummaryTable || (!isItemTable && headerAmountCount <= 1)) {
        // サマリーテーブルのヘッダー
        headerLine = _combineTextLines(sameYLines);
        headerIndex = i;
        logger.d('📊 Found summary table header at line $i: "${combinedText}"');
      }
    } else if (headerLine != null && amountCount >= 3 && i > headerIndex) {
      // データ行の検証（LanguageKeywordsを使用）
      if (_isSummaryTableDataRow(combinedText)) {
        final combinedDataLine = _combineTextLines(sameYLines);
        dataRows.add(combinedDataLine);
        logger.d('📊 Found summary table data row at line $i: "${combinedText}"');
      } else {
        logger.d('📊 Skipping item table data row at line $i: "${combinedText}"');
      }
    }
  }
  
  // ... (既存のコード: データ行の処理) ...
}
```

### 修正後の`_selectBestCandidates`

```dart
Map<String, double> _selectBestCandidates(
  Map<String, List<AmountCandidate>> candidates,
  double? itemsSum,
) {
  // ... (既存のコード) ...
  
  // 改善: 明示的なラベルマッチが存在する場合、テーブル抽出の候補を除外
  bool hasExplicitSubtotal = candidates['subtotal_amount']!
      .any((c) => c.source == 'subtotal_label');
  bool hasExplicitTotal = candidates['total_amount']!
      .any((c) => c.source == 'total_label');
  bool hasExplicitTax = candidates['tax_amount']!
      .any((c) => c.source.startsWith('tax_label') || c.source.startsWith('tax_pattern'));

  if (hasExplicitSubtotal || hasExplicitTotal || hasExplicitTax) {
    // テーブル抽出の候補を除外
    candidates['subtotal_amount']!.removeWhere((c) => c.source.startsWith('table_extraction'));
    candidates['total_amount']!.removeWhere((c) => c.source.startsWith('table_extraction'));
    candidates['tax_amount']!.removeWhere((c) => c.source.startsWith('table_extraction'));
    
    logger.d('🔍 Filtered table extraction candidates (explicit label matches found)');
  }
  
  // ... (既存のコード: 候補の選択) ...
}
```

## 期待される効果

1. **アイテムテーブルの誤認識の防止**: アイテムテーブルがサマリーテーブルとして誤認識されなくなる
2. **正しいサマリーの抽出**: 明示的なラベルマッチ（"Subtotal $250.00", "Total $262.50"）が優先される
3. **精度の向上**: テーブル抽出の精度が向上し、誤った値（136.5, 127.5, 9.0）が生成されなくなる

## テストケース

### テストケース1: アイテムテーブルのスキップ

**入力**: 
- ヘッダー: "QTY Description Unit Price Amount"
- データ行: "1.00 Replacement of spark plugs 40.00 $40.00"

**期待される動作**:
- アイテムテーブルとして識別され、スキップされる
- テーブル抽出の候補が生成されない

### テストケース2: サマリーテーブルの検出

**入力**:
- ヘッダー: "Tax Subtotal Total"
- データ行: "5% 250.00 262.50"

**期待される動作**:
- サマリーテーブルとして識別される
- 正しい値が抽出される: `tax_amount: 12.50, subtotal_amount: 250.00, total_amount: 262.50`

### テストケース3: 明示的なラベルマッチの優先

**入力**:
- 明示的なラベル: "Subtotal $250.00", "Total $262.50"
- テーブル抽出の候補: `subtotal_amount: 127.5, total_amount: 136.5`

**期待される動作**:
- 明示的なラベルマッチが優先される
- テーブル抽出の候補が除外される
- 最終的な値: `subtotal_amount: 250.0, total_amount: 262.5`

## 実装時の注意点

### LanguageKeywordsの使用

1. **キーワードの一元管理**: すべてのキーワードは`LanguageKeywords`クラスで管理し、ハードコードを避ける
2. **多言語対応**: 新しい言語を追加する場合は、`LanguageKeywords`の`item_table_header`カテゴリに追加するだけで対応可能
3. **既存カテゴリの活用**: サマリーテーブルの識別には、既存の`total`、`subtotal`、`tax`カテゴリを使用

### メンテナンス性

- **キーワードの追加**: `LanguageKeywords`に新しいキーワードを追加するだけで、すべての実装に反映される
- **言語の追加**: 新しい言語をサポートする場合は、`LanguageKeywords`の各カテゴリに該当言語のキーワードを追加する
- **一貫性の維持**: 既存の多言語対応システムと統合されているため、一貫性が保たれる

### パフォーマンス

- `LanguageKeywords.getAllKeywords()`は初回呼び出し時にキーワードを収集するため、複数回呼び出す場合は変数にキャッシュすることを推奨
- テーブルタイプの判定は、ヘッダー行の検出時のみ実行されるため、パフォーマンスへの影響は最小限

