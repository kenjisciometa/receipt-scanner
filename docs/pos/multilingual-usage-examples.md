# 多言語対応システム 使用例

## 1. 基本的な使用方法

### 1.1 キーワードの取得

```dart
import 'package:receipt_scanner/core/constants/language_keywords.dart';

// 全言語のTotalキーワードを取得
final totalKeywords = LanguageKeywords.getAllKeywords('total');
// 結果: ['total', 'sum', 'amount', 'yhteensä', 'summa', 'gesamt', ...]

// 特定の言語のキーワードを取得
final finnishTotalKeywords = LanguageKeywords.getKeywords('total', 'fi');
// 結果: ['yhteensä', 'summa', 'loppusumma', 'maksettava', 'maksu']

// 複数言語のキーワードを取得
final nordicTotalKeywords = LanguageKeywords.getKeywordsForLanguages(
  'total',
  ['fi', 'sv'],
);
// 結果: フィンランド語とスウェーデン語のTotalキーワード
```

### 1.2 パターンの生成

```dart
import 'package:receipt_scanner/core/constants/pattern_generator.dart';

// Totalパターンを生成
final totalPatterns = PatternGenerator.generateAmountPatterns(
  category: 'total',
);
// 全言語のTotalパターンが生成される

// 特定の言語のみのパターンを生成
final finnishTotalPatterns = PatternGenerator.generateAmountPatterns(
  category: 'total',
  specificLanguages: ['fi'],
);

// Taxパターンを生成（パーセンテージ対応）
final taxPatterns = PatternGenerator.generateTaxPatterns();

// 支払い方法パターンを生成
final paymentPatterns = PatternGenerator.generatePaymentMethodPatterns();

// レシート番号パターンを生成
final receiptNumberPatterns = PatternGenerator.generateReceiptNumberPatterns();

// ラベル検出用パターンを生成
final totalLabelPattern = PatternGenerator.generateLabelPattern('total');
final subtotalLabelPattern = PatternGenerator.generateLabelPattern('subtotal');
final taxLabelPattern = PatternGenerator.generateLabelPattern('tax');
```

## 2. 既存コードへの適用例

### 2.1 receipt_parser.dartの修正例

**修正前:**
```dart
final totalLabel = RegExp(
  r'\b(total|amount\s*due|sum|yhteensä|summa|...)\b',
  caseSensitive: false,
);
```

**修正後:**
```dart
import 'package:receipt_scanner/core/constants/pattern_generator.dart';

final totalLabel = PatternGenerator.generateLabelPattern('total');
final subtotalLabel = PatternGenerator.generateLabelPattern('subtotal');
final taxLabel = PatternGenerator.generateLabelPattern('tax');
```

### 2.2 RegexPatternsクラスの修正例

**修正前:**
```dart
static final List<RegExp> totalPatterns = [
  RegExp(r'(total|sum|amount)[:\s]*[€]?\s*([\d,]+[.,]\d{1,2})', ...),
  RegExp(r'(yhteensä|summa)[:\s]*[€]?\s*([\d,]+[.,]?\d*)', ...),
  // ... 各言語ごとに手動定義
];
```

**修正後:**
```dart
import 'package:receipt_scanner/core/constants/pattern_generator.dart';

static List<RegExp>? _cachedTotalPatterns;

static List<RegExp> get totalPatterns {
  _cachedTotalPatterns ??= PatternGenerator.generateAmountPatterns(
    category: 'total',
  );
  return _cachedTotalPatterns!;
}
```

## 3. 新しい言語の追加方法

### 3.1 ステップ1: LanguageKeywordsに追加

```dart
// language_keywords.dart
static const Map<String, Map<String, List<String>>> keywords = {
  'total': {
    'en': ['total', 'sum', ...],
    'fi': ['yhteensä', ...],
    // 新しい言語を追加
    'nl': ['totaal', 'bedrag', 'som'], // オランダ語
  },
  'subtotal': {
    'en': ['subtotal', ...],
    'fi': ['välisumma', ...],
    // 新しい言語を追加
    'nl': ['subtotaal', 'tussenbedrag'],
  },
  // ... 他のカテゴリにも追加
};
```

### 3.2 ステップ2: 自動的にパターンが生成される

`PatternGenerator`を使用している場合、新しい言語を追加するだけで自動的にパターンに含まれます。

```dart
// 既存のコードは変更不要
final totalPatterns = PatternGenerator.generateAmountPatterns(
  category: 'total',
);
// オランダ語のパターンも自動的に含まれる
```

## 4. 新しいカテゴリの追加方法

### 4.1 ステップ1: LanguageKeywordsにカテゴリを追加

```dart
// language_keywords.dart
static const Map<String, Map<String, List<String>>> keywords = {
  // ... 既存のカテゴリ
  'discount': {  // 新しいカテゴリ: 割引
    'en': ['discount', 'rebate', 'reduction'],
    'fi': ['alennus', 'alennusprosentti'],
    'de': ['rabatt', 'nachlass'],
    // ... 他の言語
  },
};
```

### 4.2 ステップ2: パターンを生成

```dart
// 新しいカテゴリのパターンを生成
final discountPatterns = PatternGenerator.generateAmountPatterns(
  category: 'discount',
);

// ラベル検出用パターン
final discountLabelPattern = PatternGenerator.generateLabelPattern('discount');
```

## 5. パフォーマンス最適化

### 5.1 パターンのキャッシュ

```dart
class RegexPatterns {
  // キャッシュされたパターン
  static List<RegExp>? _cachedTotalPatterns;
  static List<RegExp>? _cachedSubtotalPatterns;
  
  static List<RegExp> get totalPatterns {
    _cachedTotalPatterns ??= PatternGenerator.generateAmountPatterns(
      category: 'total',
    );
    return _cachedTotalPatterns!;
  }
}
```

### 5.2 特定の言語のみを使用する場合

```dart
// アプリで検出された言語が分かっている場合
final detectedLanguage = 'fi'; // フィンランド語

// その言語のみのパターンを生成（パフォーマンス向上）
final totalPatterns = PatternGenerator.generateAmountPatterns(
  category: 'total',
  specificLanguages: [detectedLanguage],
);
```

## 6. テスト例

### 6.1 キーワードのテスト

```dart
void main() {
  test('LanguageKeywords should return correct keywords', () {
    final totalKeywords = LanguageKeywords.getAllKeywords('total');
    expect(totalKeywords, contains('total'));
    expect(totalKeywords, contains('yhteensä'));
    expect(totalKeywords, contains('gesamt'));
  });
  
  test('LanguageKeywords should return language-specific keywords', () {
    final fiKeywords = LanguageKeywords.getKeywords('total', 'fi');
    expect(fiKeywords, contains('yhteensä'));
    expect(fiKeywords, isNot(contains('total')));
  });
}
```

### 6.2 パターンのテスト

```dart
void main() {
  test('PatternGenerator should match Finnish total', () {
    final patterns = PatternGenerator.generateAmountPatterns(
      category: 'total',
      specificLanguages: ['fi'],
    );
    
    final text = 'Yhteensä: €15.60';
    final matches = patterns.any((pattern) => pattern.hasMatch(text));
    expect(matches, isTrue);
  });
}
```

## 7. 移行チェックリスト

- [ ] `LanguageKeywords`クラスを作成
- [ ] `PatternGenerator`クラスを作成
- [ ] 既存のキーワードを`LanguageKeywords`に移行
- [ ] `RegexPatterns`クラスを改修（後方互換性を維持）
- [ ] `receipt_parser.dart`のローカル定義を削除
- [ ] 既存のテストが全てパスすることを確認
- [ ] パフォーマンステストを実行
- [ ] ドキュメントを更新

