# テーブル検出機能 改修要件定義書

## 1. 概要

### 1.1 目的
現在のテーブル検出機能は、特定の英語キーワード（"Tax rate", "Tax", "Subtotal", "Total"）に依存しているため、他の言語や異なるヘッダー名のテーブルを認識できない。構造ベースの検出方式に改修し、言語非依存で汎用的なテーブル検出を実現する。

### 1.2 背景
- 現在の実装: `_extractAmountsFromTable`メソッドが特定のキーワードに依存
- 問題点: 多言語対応や異なるレシートフォーマットに対応できない
- 解決策: ML Kitの`textLines`の`boundingBox`情報を活用した構造ベースの検出

### 1.3 対応言語
以下のヨーロッパ言語のテーブル形式に対応する必要がある：
- 英語 (English)
- フランス語 (Français)
- ドイツ語 (Deutsch)
- イタリア語 (Italiano)
- スペイン語 (Español)
- フィンランド語 (Suomi)
- スウェーデン語 (Svenska)

## 2. 現状分析

### 2.1 現在の実装
- **メソッド**: `_extractAmountsFromTable(List<String> lines, ...)`
- **検出方法**: 特定の英語キーワード（"Tax rate", "Tax", "Subtotal", "Total"）を検索
- **制約**: 
  - 英語のみ対応
  - ヘッダー名が固定
  - `boundingBox`情報を活用していない

### 2.2 利用可能な情報
- `textLines`: `List<TextLine>` - 各行のテキストと`boundingBox`情報を含む
- `boundingBox`: `[x, y, width, height]` - 各要素の位置情報
- `elements`: `List<TextBlock>` - 行内の各要素（文字/単語レベル）

### 2.3 各言語でのテーブルヘッダー例（参考）
構造ベース検出では、これらのキーワードに依存しないが、参考として記載：

| 言語 | Tax rate | Tax | Subtotal | Total |
|------|----------|-----|----------|-------|
| 英語 | Tax rate | Tax | Subtotal | Total |
| フランス語 | Taux de taxe | Taxe | Sous-total | Total |
| ドイツ語 | Steuersatz | Steuer | Zwischensumme | Gesamt |
| イタリア語 | Aliquota fiscale | Imposta | Subtotale | Totale |
| スペイン語 | Tasa de impuesto | Impuesto | Subtotal | Total |
| フィンランド語 | Veroaste | Vero | Välisumma | Yhteensä |
| スウェーデン語 | Skattsats | Skatt | Delsumma | Totalt |

**重要**: 構造ベース検出では、これらのキーワードを検索せず、テーブル構造（複数の数値/金額が同じ行に並んでいる）のみで判定する。

## 3. 改修要件

### 3.1 機能要件

#### FR-1: 構造ベースのテーブル検出
- **要件**: 同じ行（Y座標が同じ/近い）に複数の数値/金額が並んでいる構造を検出
- **判定基準**:
  - 同じY座標（許容誤差: 5-10ピクセル）に3つ以上の数値/金額がある
  - または、パーセンテージ（%）と金額が同じ行にある
- **優先度**: 高

#### FR-2: ヘッダー行の自動特定
- **要件**: 検出したテーブル構造の中で、ヘッダー行を自動的に特定
- **判定基準**:
  - テキストのみ（数値が少ない/ない行）
  - または、パーセンテージ（%）のみを含む行
  - データ行の直前にある行
- **優先度**: 高

#### FR-3: 列位置に基づく値の抽出
- **要件**: ヘッダー行とデータ行の列位置を対応付けて値を抽出
- **判定基準**:
  - ヘッダー行の各列のX座標を記録
  - データ行の各値のX座標と比較して対応付け
  - 列の順序に基づいて値を割り当て（Tax, Subtotal, Totalなど）
- **優先度**: 高

#### FR-4: 多言語対応
- **要件**: ヘッダー名が異なる言語でもテーブル構造を検出できる
- **判定基準**: キーワードに依存せず、構造のみで判定
- **対応言語**: 
  - 英語 (English): "Tax rate", "Tax", "Subtotal", "Total"
  - フランス語 (Français): "Taux de taxe", "Taxe", "Sous-total", "Total"
  - ドイツ語 (Deutsch): "Steuersatz", "Steuer", "Zwischensumme", "Gesamt"
  - イタリア語 (Italiano): "Aliquota fiscale", "Imposta", "Subtotale", "Totale"
  - スペイン語 (Español): "Tasa de impuesto", "Impuesto", "Subtotal", "Total"
  - フィンランド語 (Suomi): "Veroaste", "Vero", "Välisumma", "Yhteensä"
  - スウェーデン語 (Svenska): "Skattsats", "Skatt", "Delsumma", "Totalt"
- **優先度**: 高（構造ベース検出により実現）

#### FR-5: フォールバック機能
- **要件**: 構造ベースの検出が失敗した場合、既存のキーワードベースの検出にフォールバック
- **優先度**: 中

### 3.2 非機能要件

#### NFR-1: パフォーマンス
- テーブル検出処理は既存の処理時間を大幅に増やさない（+10%以内）

#### NFR-2: ログ出力
- テーブル検出の各ステップで詳細なログを出力
- デバッグ時に検出プロセスを追跡可能にする

#### NFR-3: 後方互換性
- 既存の通常形式レシート（test_receipt.png）の処理に影響を与えない

## 4. 技術仕様

### 4.1 メソッドシグネチャの変更

**変更前:**
```dart
Map<String, double> _extractAmountsFromTable(
  List<String> lines,
  List<String> appliedPatterns,
)
```

**変更後:**
```dart
Map<String, double> _extractAmountsFromTable(
  List<String> lines,
  List<String> appliedPatterns, {
  List<TextLine>? textLines,  // 追加: boundingBox情報を活用
})
```

### 4.2 処理フロー

1. **テーブル構造の検出（言語非依存）**
   - `textLines`が利用可能な場合:
     - 各`TextLine`の`boundingBox`からY座標を取得
     - 同じY座標（±10ピクセル）に3つ以上の数値/金額がある行を検出
     - **重要**: キーワードに依存せず、構造のみで判定（多言語対応の核心）
   - `textLines`が利用不可の場合:
     - テキストベースで複数の金額パターンが同じ行にあるか判定
     - 正規表現で金額パターンを検出（通貨記号や数値形式は言語非依存）

2. **ヘッダー行の特定（言語非依存）**
   - 検出したテーブル構造の中で、数値が少ない/ない行をヘッダー行として特定
   - または、パーセンテージ（%）のみを含む行をヘッダー行として特定
   - **重要**: ヘッダー行のテキスト内容（言語）には依存しない

3. **データ行からの値抽出**
   - ヘッダー行の次の行をデータ行として処理
   - 各列のX座標を記録して、値と列の対応付けを行う
   - 列の順序に基づいて値を割り当て
   - **多言語対応**: 列の位置情報（X座標）を使用するため、言語に依存しない

4. **値の割り当て（言語非依存）**
   - 列の位置と値のパターンから、Tax、Subtotal、Totalを判定
   - パーセンテージ（%）がある列 → Tax rate（%記号は言語非依存）
   - 金額が3つある場合 → Tax, Subtotal, Total（順序に基づく）
   - 金額が2つある場合 → Subtotal, Total
   - **多言語対応**: 数値パターンと位置情報のみを使用するため、言語に依存しない

### 4.3 実装詳細

#### 4.3.1 テーブル構造の検出ロジック

```dart
// 疑似コード
bool isTableStructure(List<TextLine> textLines, int lineIndex) {
  final line = textLines[lineIndex];
  final yCoord = line.boundingBox[1];
  final yTolerance = 10.0;
  
  // 同じY座標の要素をカウント
  int amountCount = 0;
  for (final otherLine in textLines) {
    if ((otherLine.boundingBox[1] - yCoord).abs() <= yTolerance) {
      // 金額パターンをチェック
      if (hasAmountPattern(otherLine.text)) {
        amountCount++;
      }
    }
  }
  
  // 3つ以上の金額があればテーブル構造と判定
  return amountCount >= 3;
}
```

#### 4.3.2 ヘッダー行の特定ロジック

```dart
// 疑似コード
bool isHeaderRow(String lineText, String? nextLineText) {
  // 数値が少ない/ない行
  final amountPattern = RegExp(r'[€$£¥₹]?\s*\d+[.,]\d{2}');
  final amountMatches = amountPattern.allMatches(lineText).length;
  
  // テキストのみ、またはパーセンテージのみ
  if (amountMatches == 0 || (amountMatches == 1 && lineText.contains('%'))) {
    // 次の行に複数の金額があるか確認
    if (nextLineText != null) {
      final nextAmountMatches = amountPattern.allMatches(nextLineText).length;
      return nextAmountMatches >= 2;
    }
  }
  
  return false;
}
```

#### 4.3.3 列位置に基づく値の抽出

```dart
// 疑似コード
Map<String, double> extractValuesFromTableRow(
  TextLine headerLine,
  TextLine dataLine,
) {
  // ヘッダー行の各要素のX座標を記録
  final headerColumns = <double>[];
  for (final element in headerLine.elements) {
    headerColumns.add(element.boundingBox[0]);
  }
  
  // データ行の各値のX座標と対応付け
  final values = <String, double>{};
  for (final element in dataLine.elements) {
    final xCoord = element.boundingBox[0];
    // 最も近いヘッダー列を見つける
    final columnIndex = findNearestColumn(headerColumns, xCoord);
    // 列の位置に基づいて値を割り当て
    assignValueByColumn(values, columnIndex, element.text);
  }
  
  return values;
}
```

## 5. テスト要件

### 5.1 テストケース

#### TC-1: 英語テーブル（test_receipt_v2.png）
- **入力**: Tax Breakdownテーブル（英語）
- **期待結果**: Tax, Subtotal, Totalが正しく抽出される

#### TC-2: 多言語テーブル
- **入力**: 異なる言語のヘッダー名を持つテーブル
- **期待結果**: 構造ベースで検出され、値が正しく抽出される
- **テスト対象言語**:
  - フランス語: "Taux de taxe | Taxe | Sous-total | Total"
  - ドイツ語: "Steuersatz | Steuer | Zwischensumme | Gesamt"
  - イタリア語: "Aliquota fiscale | Imposta | Subtotale | Totale"
  - スペイン語: "Tasa de impuesto | Impuesto | Subtotal | Total"
  - フィンランド語: "Veroaste | Vero | Välisumma | Yhteensä"
  - スウェーデン語: "Skattsats | Skatt | Delsumma | Totalt"

#### TC-3: 通常形式レシート（test_receipt.png）
- **入力**: VAT 24%: €3.02 形式
- **期待結果**: 既存の処理が正常に動作し、影響を受けない

#### TC-4: テーブル構造なし
- **入力**: テーブル構造がないレシート
- **期待結果**: テーブル検出がスキップされ、通常の抽出処理が実行される

### 5.2 パフォーマンステスト
- 処理時間が既存実装の+10%以内であることを確認

## 6. 実装計画

### 6.1 フェーズ1: 構造ベース検出の実装
- `_extractAmountsFromTable`メソッドに`textLines`パラメータを追加
- テーブル構造の検出ロジックを実装
- ログ出力を追加

### 6.2 フェーズ2: ヘッダー行特定の実装
- ヘッダー行の自動特定ロジックを実装
- 列位置の記録機能を実装

### 6.3 フェーズ3: 値の抽出と割り当て
- 列位置に基づく値の抽出ロジックを実装
- 値の割り当てロジックを実装

### 6.4 フェーズ4: テストと検証
- テストケースの実行
- パフォーマンステスト
- 既存機能への影響確認

## 7. リスクと対策

### 7.1 リスク
- **リスク1**: `boundingBox`情報が不正確な場合、テーブル構造を誤検出する可能性
- **対策**: 許容誤差を調整可能にし、複数の判定基準を組み合わせる

- **リスク2**: 処理時間が増加する可能性
- **対策**: 早期リターンやキャッシュを活用して最適化

- **リスク3**: 既存の通常形式レシートの処理に影響を与える可能性
- **対策**: フォールバック機能を実装し、既存処理を維持

## 8. 成功基準

- ✅ 多言語のテーブルヘッダーでもテーブル構造を検出できる
  - 英語、フランス語、ドイツ語、イタリア語、スペイン語、フィンランド語、スウェーデン語の全てで動作
- ✅ 異なるヘッダー名のテーブルでも値を正しく抽出できる
  - キーワードに依存せず、構造ベースで検出
- ✅ 既存の通常形式レシートの処理に影響がない
  - test_receipt.png（VAT 24%: €3.02形式）が正常に動作
- ✅ 処理時間が既存実装の+10%以内
- ✅ テストケースが全てパスする
  - 各言語でのテーブル形式のテストケースが全てパス

