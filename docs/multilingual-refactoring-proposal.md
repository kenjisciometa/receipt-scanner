# 多言語対応効率化提案書

## 1. 現状の問題点

### 1.1 課題
- **複数ファイルに分散**: 言語キーワードが`regex_patterns.dart`と`receipt_parser.dart`に散在
- **重複定義**: 同じキーワードが複数箇所で定義されている
- **保守性の低さ**: 新しい言語を追加する際に複数ファイルを修正する必要がある
- **一貫性の欠如**: 同じ言語でも異なるキーワードが使われている可能性

### 1.2 影響範囲
- `lib/core/constants/regex_patterns.dart`: 正規表現パターン定義
- `lib/services/extraction/receipt_parser.dart`: ローカル正規表現定義（totalLabel, subtotalLabel, taxLabel等）

## 2. 提案する解決策

### 2.1 アーキテクチャ概要

```
┌─────────────────────────────────────────┐
│  LanguageKeywords (一元管理)            │
│  - 言語ごとのキーワードマップ            │
│  - カテゴリ別（Total, Subtotal, Tax等） │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  PatternGenerator (動的生成)            │
│  - キーワードから正規表現を生成          │
│  - 複数言語を統合したパターン生成        │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  RegexPatterns (既存クラス)             │
│  - 生成されたパターンを使用              │
└─────────────────────────────────────────┘
```

### 2.2 実装方針

1. **言語キーワードの一元管理**
   - `LanguageKeywords`クラスで全言語のキーワードを定義
   - カテゴリ別（Total, Subtotal, Tax, Payment, Receipt等）に整理

2. **正規表現パターンの動的生成**
   - `PatternGenerator`クラスでキーワードから正規表現を生成
   - 複数言語を統合したパターンを自動生成

3. **後方互換性の維持**
   - 既存の`RegexPatterns`クラスのインターフェースを維持
   - 内部実装のみ変更

## 3. 実装詳細

### 3.1 言語キーワード定義

```dart
class LanguageKeywords {
  // 言語コード
  static const String en = 'en';
  static const String fi = 'fi';
  static const String sv = 'sv';
  static const String fr = 'fr';
  static const String de = 'de';
  static const String it = 'it';
  static const String es = 'es';

  // カテゴリ別キーワードマップ
  static const Map<String, Map<String, List<String>>> keywords = {
    'total': {
      'en': ['total', 'sum', 'amount', 'grand total', 'amount due'],
      'fi': ['yhteensä', 'summa', 'loppusumma', 'maksettava', 'maksu'],
      'sv': ['totalt', 'summa', 'att betala', 'slutsumma'],
      'fr': ['total', 'montant total', 'somme', 'à payer', 'net à payer', 'total ttc'],
      'de': ['summe', 'gesamt', 'betrag', 'gesamtbetrag', 'endsumme', 'zu zahlen'],
      'it': ['totale', 'importo', 'somma', 'da pagare', 'totale generale', 'saldo'],
      'es': ['total', 'importe', 'suma', 'a pagar', 'total general', 'precio total'],
    },
    'subtotal': {
      'en': ['subtotal', 'sub-total', 'net'],
      'fi': ['välisumma', 'alasumma'],
      'sv': ['delsumma', 'mellansumma'],
      'fr': ['sous-total', 'montant ht'],
      'de': ['zwischensumme', 'netto'],
      'it': ['subtotale', 'imponibile'],
      'es': ['subtotal', 'base imponible'],
    },
    'tax': {
      'en': ['vat', 'tax', 'sales tax'],
      'fi': ['alv', 'arvonlisävero'],
      'sv': ['moms', 'mervärdesskatt'],
      'fr': ['tva', 'taxe'],
      'de': ['mwst', 'umsatzsteuer', 'steuer'],
      'it': ['iva', 'imposta'],
      'es': ['iva', 'impuesto'],
    },
    'payment': {
      'en': ['payment'],
      'fi': ['maksutapa'],
      'sv': ['betalning'],
      'fr': ['paiement'],
      'de': ['zahlung'],
      'it': ['pagamento'],
      'es': ['pago'],
    },
    'payment_method_cash': {
      'en': ['cash'],
      'fi': ['käteinen'],
      'sv': ['kontanter'],
      'fr': ['espèces'],
      'de': ['bar'],
      'it': ['contanti'],
      'es': ['efectivo'],
    },
    'payment_method_card': {
      'en': ['card'],
      'fi': ['kortti'],
      'sv': ['kort'],
      'fr': ['carte'],
      'de': ['karte'],
      'it': ['carta'],
      'es': ['tarjeta'],
    },
    'receipt': {
      'en': ['receipt'],
      'fi': ['kuitti'],
      'sv': ['kvitto'],
      'fr': ['reçu'],
      'de': ['rechnung', 'bon', 'quittung'],
      'it': ['ricevuta'],
      'es': ['recibo'],
    },
  };

  /// 全言語のキーワードを統合して取得
  static List<String> getAllKeywords(String category) {
    final allKeywords = <String>{};
    final categoryMap = keywords[category];
    if (categoryMap != null) {
      for (final langKeywords in categoryMap.values) {
        allKeywords.addAll(langKeywords);
      }
    }
    return allKeywords.toList();
  }

  /// 特定の言語のキーワードを取得
  static List<String> getKeywords(String category, String language) {
    return keywords[category]?[language] ?? [];
  }
}
```

### 3.2 パターン生成ユーティリティ

```dart
class PatternGenerator {
  /// 金額パターンを生成（Total, Subtotal, Tax用）
  static List<RegExp> generateAmountPatterns({
    required String category,
    List<String>? specificLanguages,
    String amountPattern = r'([\d,\s]+[.,]\d{1,2})',
    String currencyPattern = r'[€\$£¥₹kr]?',
  }) {
    final keywords = specificLanguages != null
        ? _getKeywordsForLanguages(category, specificLanguages)
        : LanguageKeywords.getAllKeywords(category);

    return [
      // パターン1: "Keyword: €12.34" 形式
      RegExp(
        r'(${keywords.join('|')})[:\s]*$currencyPattern\s*$amountPattern',
        multiLine: true,
        caseSensitive: false,
      ),
      // パターン2: "Keyword: € 12.34" 形式（スペースあり）
      RegExp(
        r'(${keywords.join('|')}):\s*$currencyPattern\s*$amountPattern',
        multiLine: true,
        caseSensitive: false,
      ),
      // パターン3: "Keyword                €12.34" 形式（スペース区切り）
      RegExp(
        r'(${keywords.join('|')}):\s*$currencyPattern*$amountPattern',
        multiLine: true,
        caseSensitive: false,
      ),
    ];
  }

  /// 支払い方法パターンを生成
  static List<RegExp> generatePaymentMethodPatterns() {
    final paymentKeywords = LanguageKeywords.getAllKeywords('payment');
    final cashKeywords = LanguageKeywords.getAllKeywords('payment_method_cash');
    final cardKeywords = LanguageKeywords.getAllKeywords('payment_method_card');

    return [
      // 明示的な支払い方法パターン: "Payment: CARD"
      RegExp(
        r'\b(${paymentKeywords.join('|')})\s*[:\-]?\s*(${cashKeywords.join('|')}|${cardKeywords.join('|')}|cash|card|credit|debit)\b',
        caseSensitive: false,
      ),
      // カードパターン
      RegExp(
        r'\b(${cardKeywords.join('|')}|card|credit|debit|visa|mastercard|maestro)\b',
        caseSensitive: false,
      ),
      // 現金パターン
      RegExp(
        r'\b(${cashKeywords.join('|')}|cash|contant)\b',
        caseSensitive: false,
      ),
    ];
  }

  /// レシート番号パターンを生成
  static List<RegExp> generateReceiptNumberPatterns() {
    final receiptKeywords = LanguageKeywords.getAllKeywords('receipt');

    return [
      RegExp(
        r'\b(${receiptKeywords.join('|')})\s*#?\s*(?:nro|nr|no|number)?\s*[:\-]?\s*([A-Za-z0-9\-]+)\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(invoice|faktura|facture|fattura)\s*#?\s*[:\-]?\s*([A-Za-z0-9\-]+)\b',
        caseSensitive: false,
      ),
      RegExp(r'#(\d{3,})'),
    ];
  }

  /// ラベル検出用の正規表現を生成（totalLabel, subtotalLabel等）
  static RegExp generateLabelPattern(String category) {
    final keywords = LanguageKeywords.getAllKeywords(category);
    return RegExp(
      r'\b(${keywords.join('|')})\b',
      caseSensitive: false,
    );
  }

  static List<String> _getKeywordsForLanguages(
    String category,
    List<String> languages,
  ) {
    final allKeywords = <String>{};
    for (final lang in languages) {
      allKeywords.addAll(LanguageKeywords.getKeywords(category, lang));
    }
    return allKeywords.toList();
  }
}
```

### 3.3 RegexPatternsクラスの改修

```dart
class RegexPatterns {
  // キャッシュされたパターン（初回生成時に計算）
  static List<RegExp>? _cachedTotalPatterns;
  static List<RegExp>? _cachedSubtotalPatterns;
  static List<RegExp>? _cachedTaxPatterns;
  static List<RegExp>? _cachedPaymentMethodPatterns;
  static List<RegExp>? _cachedReceiptNumberPatterns;

  /// Total amount patterns (動的生成)
  static List<RegExp> get totalPatterns {
    _cachedTotalPatterns ??= PatternGenerator.generateAmountPatterns(
      category: 'total',
    );
    return _cachedTotalPatterns!;
  }

  /// Subtotal amount patterns (動的生成)
  static List<RegExp> get subtotalPatterns {
    _cachedSubtotalPatterns ??= PatternGenerator.generateAmountPatterns(
      category: 'subtotal',
    );
    return _cachedSubtotalPatterns!;
  }

  /// Tax patterns (動的生成)
  static List<RegExp> get taxPatterns {
    _cachedTaxPatterns ??= PatternGenerator.generateAmountPatterns(
      category: 'tax',
      amountPattern: r'([\d,\s]+[.,]\d{1,2})',
    );
    return _cachedTaxPatterns!;
  }

  /// Payment method patterns (動的生成)
  static List<RegExp> get paymentMethodPatterns {
    _cachedPaymentMethodPatterns ??= PatternGenerator.generatePaymentMethodPatterns();
    return _cachedPaymentMethodPatterns!;
  }

  /// Receipt number patterns (動的生成)
  static List<RegExp> get receiptNumberPatterns {
    _cachedReceiptNumberPatterns ??= PatternGenerator.generateReceiptNumberPatterns();
    return _cachedReceiptNumberPatterns!;
  }

  // その他のパターン（日付、通貨等）は既存のまま
  // ...
}
```

### 3.4 receipt_parser.dartの改修

```dart
// ローカル定義を削除し、PatternGeneratorを使用
class ReceiptParser {
  // 修正前:
  // final totalLabel = RegExp(r'\b(total|...)\b', ...);
  
  // 修正後:
  final totalLabel = PatternGenerator.generateLabelPattern('total');
  final subtotalLabel = PatternGenerator.generateLabelPattern('subtotal');
  final taxLabel = PatternGenerator.generateLabelPattern('tax');

  PaymentMethod? _extractPaymentMethod(String text, List<String> appliedPatterns) {
    // PatternGeneratorを使用してパターンを生成
    final explicitPattern = PatternGenerator.generatePaymentMethodPatterns().first;
    // ...
  }
}
```

## 4. メリット

### 4.1 保守性の向上
- **一元管理**: 全言語のキーワードが1箇所に集約
- **追加が容易**: 新しい言語を追加する際は`LanguageKeywords`に1箇所追加するだけ
- **一貫性**: 同じキーワードが複数箇所で定義されることがない

### 4.2 拡張性
- **新しいカテゴリの追加**: カテゴリを追加するだけで新しいパターンを生成可能
- **言語の追加**: 既存のカテゴリに新しい言語を追加するだけ
- **パターンのカスタマイズ**: `PatternGenerator`でパターン形式を変更可能

### 4.3 テスト容易性
- **単体テスト**: キーワード定義とパターン生成を個別にテスト可能
- **回帰テスト**: 既存のパターンが壊れていないことを確認しやすい

## 5. 移行計画

### フェーズ1: 基盤構築
1. `LanguageKeywords`クラスを作成
2. `PatternGenerator`クラスを作成
3. 既存のキーワードを`LanguageKeywords`に移行

### フェーズ2: 段階的移行
1. `RegexPatterns`クラスを改修（後方互換性を維持）
2. `receipt_parser.dart`のローカル定義を削除
3. テストを実行して動作確認

### フェーズ3: 最適化
1. パターンのキャッシュ最適化
2. パフォーマンステスト
3. ドキュメント更新

## 6. 注意事項

- **後方互換性**: 既存のコードが動作することを確認
- **パフォーマンス**: パターン生成のオーバーヘッドを最小化（キャッシュ使用）
- **テスト**: 既存のテストが全てパスすることを確認

