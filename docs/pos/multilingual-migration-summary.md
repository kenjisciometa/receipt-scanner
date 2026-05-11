# 多言語対応システム 移行完了サマリー

## 移行完了日
2024年（実装日）

## 実装内容

### 1. 新規作成ファイル

#### `lib/core/constants/language_keywords.dart`
- 全言語のキーワードを一元管理
- カテゴリ別（total, subtotal, tax, payment等）に整理
- 7言語対応（英語、フィンランド語、スウェーデン語、フランス語、ドイツ語、イタリア語、スペイン語）

#### `lib/core/constants/pattern_generator.dart`
- キーワードから正規表現パターンを動的生成
- カテゴリ別のパターン生成メソッド
- パフォーマンス最適化（エスケープ処理、文字列補間）

### 2. 改修ファイル

#### `lib/core/constants/regex_patterns.dart`
- **変更前**: 静的定義された正規表現パターン（各言語ごとに手動定義）
- **変更後**: `PatternGenerator`を使用した動的生成（getter経由）
- **後方互換性**: 既存のコードは変更不要（インターフェース維持）
- **キャッシュ**: 初回生成時にキャッシュしてパフォーマンス最適化

**移行したパターン:**
- `totalPatterns` → 動的生成
- `subtotalPatterns` → 動的生成
- `taxPatterns` → 動的生成（パーセンテージ対応）
- `paymentMethodPatterns` → 動的生成
- `receiptNumberPatterns` → 動的生成

**未移行（既存のまま）:**
- `datePatterns` - 日付形式は言語非依存のため現状維持
- `currencyPatterns` - 通貨記号は言語非依存のため現状維持
- `merchantPatterns` - 店舗名パターンは現状維持
- `itemLinePatterns` - アイテム行パターンは現状維持
- `numberPattern`, `amountPattern` - ユーティリティパターンは現状維持

#### `lib/services/extraction/receipt_parser.dart`
- ローカル定義の正規表現を`PatternGenerator`に置き換え
- `totalLabel`, `subtotalLabel`, `taxLabel` → `PatternGenerator.generateLabelPattern()`
- `_extractPaymentMethod()` → `PatternGenerator.generatePaymentMethodPatterns()`
- `_extractReceiptNumber()` → `PatternGenerator.generateReceiptNumberPatterns()`

## メリット

### 1. 保守性の向上
- ✅ 全言語のキーワードが1箇所（`LanguageKeywords`）に集約
- ✅ 新しい言語を追加する際は1箇所の修正のみ
- ✅ キーワードの重複定義がなくなる

### 2. 拡張性
- ✅ 新しいカテゴリを追加するだけですぐに使用可能
- ✅ 言語の追加が容易（`LanguageKeywords`に追加するだけ）
- ✅ パターン形式の変更が容易（`PatternGenerator`で一元管理）

### 3. 一貫性
- ✅ 同じキーワードが複数箇所で定義されることがない
- ✅ 言語ごとのキーワードが統一管理される

## 使用方法

### 新しい言語の追加

1. `LanguageKeywords`クラスにキーワードを追加:
```dart
'total': {
  'en': ['total', 'sum', ...],
  'nl': ['totaal', 'bedrag'], // オランダ語を追加
},
```

2. 自動的にパターンに反映される（コード変更不要）

### 新しいカテゴリの追加

1. `LanguageKeywords`にカテゴリを追加:
```dart
'discount': {
  'en': ['discount', 'rebate'],
  'fi': ['alennus'],
  // ...
},
```

2. `PatternGenerator`でパターンを生成:
```dart
final discountPatterns = PatternGenerator.generateAmountPatterns(
  category: 'discount',
);
```

## テスト

### 動作確認項目
- [x] 既存のテストが全てパスする
- [x] リンターエラーなし
- [x] 後方互換性が維持されている

### 推奨テスト
- 各言語のレシートで正しく抽出できることを確認
- パフォーマンステスト（パターン生成のオーバーヘッド確認）

## 今後の改善点

1. **パフォーマンス最適化**
   - パターンのキャッシュをより効率的に
   - 特定の言語のみを使用する場合の最適化

2. **テストの追加**
   - `LanguageKeywords`の単体テスト
   - `PatternGenerator`の単体テスト
   - 統合テスト

3. **ドキュメント**
   - APIドキュメントの更新
   - 使用例の追加

## 注意事項

- 既存のコードは変更不要（後方互換性維持）
- パターンは初回アクセス時に生成・キャッシュされる
- 新しい言語を追加する際は、既存のテストで動作確認を推奨

