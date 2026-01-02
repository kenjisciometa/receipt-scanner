# テーブル形式レシート対応の整合性チェック実装要件定義書

**目的**: テーブル形式（Tax Breakdown）と非テーブル形式のレシートの両方で、統合的な整合性チェック機能を実装し、テーブル内外の両方から取得した候補を統合評価して最適解を選択する

---

## 1. 現状の問題点

### 1.1 現在の実装の課題

1. **テーブル抽出と行ベース抽出の分離**
   - `_extractAmountsFromTable`は直接結果を返し、候補として扱われていない
   - `_extractAmountsLineByLine`内でテーブル抽出を呼び出しているが、結果は直接`amounts`に追加される
   - テーブル抽出の結果と行ベース抽出の候補が統合評価されていない

2. **候補の統合不足**
   - テーブルから抽出された値も候補として扱うべき
   - テーブル内外の両方から候補を収集し、整合性チェックで最適な組み合わせを選択すべき

3. **重複処理**
   - テーブル抽出と行ベース抽出で類似のロジックが重複している可能性
   - 共通部分を抽出して効率化が必要

### 1.2 実装目標

1. **統合的な候補収集**
   - テーブル抽出からも候補を生成
   - 行ベース抽出からも候補を生成
   - 両方を統合して`FieldCandidates`に格納

2. **統合的な整合性チェック**
   - テーブル内外の候補を統合評価
   - 最適な組み合わせを選択

3. **効率的な実装**
   - 共通ロジックの抽出
   - 重複処理の削減

---

## 2. アーキテクチャ設計

### 2.1 全体フロー

```
_extractAmountsLineByLine()
  │
  ├─→ _collectAllCandidates()
  │     │
  │     ├─→ _collectTableCandidates()  // テーブルから候補収集
  │     │     └─→ _extractAmountsFromTable() (修正版)
  │     │
  │     └─→ _collectLineBasedCandidates()  // 行ベースから候補収集
  │           └─→ 既存のパターンマッチングロジック
  │
  └─→ _selectBestCandidates()  // 統合的な整合性チェック
        └─→ _calculateConsistencyScore()
```

### 2.2 データフロー

```
入力: lines, textLines
  │
  ├─→ テーブル検出
  │     └─→ テーブル候補: [AmountCandidate, ...]
  │
  ├─→ 行ベース抽出
  │     └─→ 行ベース候補: [AmountCandidate, ...]
  │
  └─→ 統合
        └─→ FieldCandidates {
              total_amount: [候補1, 候補2, ...],
              subtotal_amount: [候補1, 候補2, ...],
              tax_amount: [候補1, 候補2, ...],
            }
        └─→ 整合性チェック
              └─→ 最適な組み合わせを選択
```

---

## 3. 詳細設計

### 3.1 テーブル候補の収集

#### 3.1.1 要件

- テーブルから抽出された値も`AmountCandidate`として扱う
- テーブル抽出の信頼度スコアを設定
- テーブル内外の候補を区別できるように`source`を設定

#### 3.1.2 実装方針

```dart
/// テーブルから候補を収集
List<AmountCandidate> _collectTableCandidates(
  List<String> lines,
  List<TextLine>? textLines,
  List<String> appliedPatterns,
) {
  final candidates = <AmountCandidate>[];
  
  // テーブル検出
  final tableResult = _extractAmountsFromTable(
    lines,
    appliedPatterns,
    textLines: textLines,
  );
  
  if (tableResult.isEmpty) {
    return candidates;  // テーブルなし
  }
  
  // テーブルから抽出された値を候補に変換
  // テーブル抽出は信頼度が高いため、スコアを高く設定
  if (tableResult.containsKey('total_amount')) {
    candidates.add(AmountCandidate(
      amount: tableResult['total_amount']!,
      score: 95,  // テーブル抽出は高信頼度
      lineIndex: -1,  // テーブル行は複数行にまたがる可能性
      source: 'table_extraction_total',
      fieldName: 'total_amount',
      // boundingBoxはテーブル全体の位置情報を使用
    ));
  }
  
  // Subtotal, Taxも同様に処理
  
  return candidates;
}
```

#### 3.1.3 テーブル抽出メソッドの修正

現在の`_extractAmountsFromTable`は直接`Map<String, double>`を返しているが、これを修正して候補を返すようにするか、または別メソッドを追加する。

**方針**: 既存の`_extractAmountsFromTable`は維持し、新しい`_collectTableCandidates`メソッドでラップする。

### 3.2 行ベース候補の収集

#### 3.2.1 要件

- 既存の行ベース抽出ロジックを活用
- 複数候補を保持するように拡張
- テーブル候補と統合可能な形式で返す

#### 3.2.2 実装方針

```dart
/// 行ベースから候補を収集（既存ロジックの拡張）
Map<String, List<AmountCandidate>> _collectLineBasedCandidates(
  List<String> lines,
  String? language,
  List<String> appliedPatterns, {
  List<TextLine>? textLines,
}) {
  final candidates = <String, List<AmountCandidate>>{
    'total_amount': [],
    'subtotal_amount': [],
    'tax_amount': [],
  };
  
  // 既存のパターンマッチングロジックを使用
  // ただし、1つの候補だけを保持するのではなく、すべての候補を保持
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    
    // Total候補の収集
    for (int p = 0; p < RegexPatterns.totalPatterns.length; p++) {
      final match = RegexPatterns.totalPatterns[p].firstMatch(line);
      if (match != null) {
        final amountStr = match.groupCount >= 2 
            ? match.group(2) 
            : match.group(match.groupCount);
        final amount = amountStr != null ? _parseAmount(amountStr) : null;
        
        if (amount != null && amount > 0) {
          candidates['total_amount']!.add(AmountCandidate(
            amount: amount,
            score: 100,  // パターンマッチの基本スコア
            lineIndex: i,
            source: 'total_pattern_$p',
            fieldName: 'total_amount',
            boundingBox: textLines != null && i < textLines.length
                ? textLines[i].boundingBox
                : null,
            confidence: textLines != null && i < textLines.length
                ? textLines[i].confidence
                : null,
          ));
        }
      }
    }
    
    // Subtotal, Taxも同様に処理
  }
  
  // 位置情報によるスコアボーナスを適用
  _applyPositionBonuses(candidates, lines.length);
  
  return candidates;
}
```

### 3.3 統合的な候補収集

#### 3.3.1 要件

- テーブル候補と行ベース候補を統合
- `FieldCandidates`形式に変換
- 重複候補の処理（同じ金額の候補が複数ある場合）

#### 3.3.2 実装方針

```dart
/// すべての候補を統合収集
Map<String, FieldCandidates> _collectAllCandidates(
  List<String> lines,
  String? language,
  List<String> appliedPatterns, {
  List<TextLine>? textLines,
}) {
  // 1. テーブル候補を収集
  final tableCandidates = _collectTableCandidates(
    lines,
    textLines,
    appliedPatterns,
  );
  
  // 2. 行ベース候補を収集
  final lineBasedCandidates = _collectLineBasedCandidates(
    lines,
    language,
    appliedPatterns,
    textLines: textLines,
  );
  
  // 3. 統合
  final allCandidates = <String, List<AmountCandidate>>{
    'total_amount': [],
    'subtotal_amount': [],
    'tax_amount': [],
  };
  
  // テーブル候補を追加
  for (final candidate in tableCandidates) {
    allCandidates[candidate.fieldName]!.add(candidate);
  }
  
  // 行ベース候補を追加
  for (final fieldName in lineBasedCandidates.keys) {
    allCandidates[fieldName]!.addAll(lineBasedCandidates[fieldName]!);
  }
  
  // 4. 重複候補の処理（同じ金額の候補は統合またはスコア調整）
  _mergeDuplicateCandidates(allCandidates);
  
  // 5. FieldCandidatesに変換
  return {
    'total_amount': FieldCandidates(
      fieldName: 'total_amount',
      candidates: allCandidates['total_amount']!,
    ),
    'subtotal_amount': FieldCandidates(
      fieldName: 'subtotal_amount',
      candidates: allCandidates['subtotal_amount']!,
    ),
    'tax_amount': FieldCandidates(
      fieldName: 'tax_amount',
      candidates: allCandidates['tax_amount']!,
    ),
  };
}
```

#### 3.3.3 重複候補の処理

同じ金額の候補が複数ある場合（例: テーブルと行ベースの両方で検出）、以下の方針で処理：

1. **統合**: 同じ金額の候補は1つに統合し、スコアを高い方に設定
2. **ソース情報の保持**: 複数のソースから検出されたことを記録

```dart
/// 重複候補の統合
void _mergeDuplicateCandidates(
  Map<String, List<AmountCandidate>> candidates,
) {
  for (final fieldName in candidates.keys) {
    final fieldCandidates = candidates[fieldName]!;
    final merged = <double, AmountCandidate>{};
    
    for (final candidate in fieldCandidates) {
      final key = candidate.amount;
      if (merged.containsKey(key)) {
        // 既存の候補と統合（スコアを高い方に）
        final existing = merged[key]!;
        if (candidate.score > existing.score) {
          merged[key] = candidate;
        }
        // ソース情報を更新（複数ソースから検出されたことを記録）
        // existing.source += ', ${candidate.source}';
      } else {
        merged[key] = candidate;
      }
    }
    
    candidates[fieldName] = merged.values.toList();
  }
}
```

### 3.4 統合的な整合性チェック

#### 3.4.1 要件

- テーブル内外の候補を統合評価
- 既存の`_selectBestCandidates`を活用
- テーブル抽出の信頼度を考慮

#### 3.4.2 実装方針

既存の`_selectBestCandidates`メソッドは、`FieldCandidates`を受け取って整合性チェックを行うため、そのまま使用可能。

ただし、テーブル抽出の信頼度を考慮するため、整合性スコアの計算に以下を追加：

```dart
/// 整合性スコアの計算（拡張版）
double _calculateConsistencyScore({
  AmountCandidate? total,
  AmountCandidate? subtotal,
  AmountCandidate? tax,
}) {
  double score = 0.0;
  
  // 1. 基本的な整合性チェック（既存）
  // ... (既存のロジック)
  
  // 2. 候補の信頼度スコア（既存）
  // ... (既存のロジック)
  
  // 3. 位置関係の整合性（既存）
  // ... (既存のロジック)
  
  // 4. OCR信頼度（既存）
  // ... (既存のロジック)
  
  // 5. テーブル抽出の信頼度ボーナス（新規）
  int tableSourceCount = 0;
  if (total?.source.startsWith('table_extraction') == true) tableSourceCount++;
  if (subtotal?.source.startsWith('table_extraction') == true) tableSourceCount++;
  if (tax?.source.startsWith('table_extraction') == true) tableSourceCount++;
  
  // テーブルから複数のフィールドが検出された場合、ボーナス
  if (tableSourceCount >= 2) {
    score += 0.05;  // テーブル抽出の整合性ボーナス
  }
  
  return score.clamp(0.0, 1.0);
}
```

### 3.5 共通部分の抽出

#### 3.5.1 候補生成の共通化

テーブル抽出と行ベース抽出の両方で、`AmountCandidate`を生成する処理が共通化できる。

```dart
/// 共通: AmountCandidateの生成ヘルパー
AmountCandidate _createAmountCandidate({
  required double amount,
  required int baseScore,
  required String source,
  required String fieldName,
  int? lineIndex,
  List<double>? boundingBox,
  double? confidence,
}) {
  return AmountCandidate(
    amount: amount,
    score: baseScore,
    lineIndex: lineIndex ?? -1,
    source: source,
    fieldName: fieldName,
    boundingBox: boundingBox,
    confidence: confidence,
  );
}
```

#### 3.5.2 金額抽出の共通化

テーブル抽出と行ベース抽出の両方で、金額文字列をパースする処理は既に`_parseAmount`で共通化されている。

---

## 4. 実装ステップ

### Phase 1: テーブル候補収集の実装（1-2日）

1. `_collectTableCandidates`メソッドの実装
   - `_extractAmountsFromTable`をラップ
   - 抽出結果を`AmountCandidate`に変換
   - テーブル抽出の信頼度スコアを設定

2. テスト
   - `test_receipt_v2.png`でテーブル候補が正しく収集されることを確認
   - `test_receipt_v3.png`で複数税率のテーブル候補が正しく収集されることを確認

### Phase 2: 行ベース候補収集の拡張（1-2日）

1. `_collectLineBasedCandidates`メソッドの実装
   - 既存の`_extractAmountsLineByLine`のロジックを拡張
   - 複数候補を保持するように修正
   - 位置情報ボーナスの適用

2. テスト
   - 既存のテストレシートで候補が正しく収集されることを確認

### Phase 3: 統合的な候補収集の実装（1-2日）

1. `_collectAllCandidates`メソッドの実装
   - テーブル候補と行ベース候補を統合
   - 重複候補の処理
   - `FieldCandidates`への変換

2. `_mergeDuplicateCandidates`メソッドの実装
   - 同じ金額の候補の統合
   - スコアの調整

3. テスト
   - テーブルと行ベースの両方から候補が収集されることを確認
   - 重複候補が正しく統合されることを確認

### Phase 4: 整合性チェックの拡張（1日）

1. `_calculateConsistencyScore`の拡張
   - テーブル抽出の信頼度ボーナスを追加

2. `_extractAmountsLineByLine`の修正
   - `_collectAllCandidates`を呼び出すように変更
   - 既存の`_selectBestCandidates`を使用

3. テスト
   - テーブル形式レシートで整合性チェックが正しく動作することを確認
   - 非テーブル形式レシートでも既存の動作が維持されることを確認

### Phase 5: 統合テストと最適化（1-2日）

1. 全テストレシートでの検証
   - `test_receipt.png` (非テーブル)
   - `test_receipt_v2.png` (テーブル、単一税率)
   - `test_receipt_v3.png` (テーブル、複数税率)
   - その他のテストレシート

2. パフォーマンス最適化
   - 不要な処理の削減
   - キャッシュの活用

3. ログ出力の改善
   - テーブル候補と行ベース候補の区別が分かるように
   - 統合プロセスの可視化

---

## 5. 期待される効果

### 5.1 精度向上

- **テーブル内外の統合評価**: テーブルと行ベースの両方から候補を収集し、最適な組み合わせを選択
- **整合性による検証**: テーブル抽出の結果と行ベース抽出の結果を統合的に評価

### 5.2 堅牢性の向上

- **フォールバック**: テーブル抽出が失敗しても行ベース抽出で補完
- **検証**: テーブル抽出と行ベース抽出の結果を相互検証

### 5.3 保守性の向上

- **共通化**: テーブル抽出と行ベース抽出の共通部分を抽出
- **一貫性**: 統合的なアプローチで一貫した実装

---

## 6. 注意点

### 6.1 パフォーマンス

- テーブル抽出と行ベース抽出の両方を実行するため、処理時間が若干増加する可能性
- ただし、候補の収集は軽量な処理のため、影響は限定的

### 6.2 エッジケース

- **テーブルと行ベースの矛盾**: テーブル抽出と行ベース抽出で異なる値が検出された場合、整合性スコアで判断
- **テーブル部分的な検出**: テーブルの一部しか検出できない場合、行ベース抽出で補完

### 6.3 後方互換性

- 既存の非テーブル形式レシートでの動作は維持
- 既存のAPIは変更しない

---

## 7. 実装例

### 7.1 統合的な候補収集の例

```dart
Map<String, double> _extractAmountsLineByLine(
  List<String> lines,
  String? language,
  List<String> appliedPatterns, {
  List<TextLine>? textLines,
}) {
  logger.d('Starting unified amount extraction with consistency checking');
  
  // 1. すべての候補を統合収集
  final allCandidates = _collectAllCandidates(
    lines,
    language,
    appliedPatterns,
    textLines: textLines,
  );
  
  // 2. 整合性チェックで最適解を選択
  final consistencyResult = _selectBestCandidates(allCandidates);
  
  // 3. 結果をマップに変換
  final amounts = <String, double>{};
  for (final entry in consistencyResult.selectedCandidates.entries) {
    final fieldName = entry.key;
    final candidate = entry.value;
    
    // 修正された値があればそれを使用
    if (consistencyResult.correctedValues?.containsKey(fieldName) == true) {
      amounts[fieldName] = consistencyResult.correctedValues![fieldName]!;
      appliedPatterns.add('${fieldName}_corrected');
      logger.d('✅ Using corrected value for $fieldName: ${amounts[fieldName]}');
    } else {
      amounts[fieldName] = candidate.amount;
      appliedPatterns.add('${fieldName}_${candidate.source}');
      logger.d('✅ Selected $fieldName: ${candidate.amount} (source: ${candidate.source}, score: ${candidate.score})');
    }
  }
  
  // 4. 警告をログに記録
  if (consistencyResult.warnings.isNotEmpty) {
    for (final warning in consistencyResult.warnings) {
      logger.w('⚠️ Consistency warning: $warning');
    }
  }
  
  // 5. 要確認フラグをメタデータに追加
  if (consistencyResult.needsVerification) {
    appliedPatterns.add('needs_verification');
    logger.w('⚠️ Receipt needs manual verification');
  }
  
  logger.d('Unified extraction completed. Found amounts: $amounts');
  logger.d('Consistency score: ${consistencyResult.consistencyScore.toStringAsFixed(2)}');
  
  return amounts;
}
```

### 7.2 テーブル候補収集の例

```dart
List<AmountCandidate> _collectTableCandidates(
  List<String> lines,
  List<TextLine>? textLines,
  List<String> appliedPatterns,
) {
  final candidates = <AmountCandidate>[];
  
  // テーブル検出（既存メソッドを使用）
  final tableAmounts = _extractAmountsFromTable(
    lines,
    appliedPatterns,
    textLines: textLines,
  );
  
  if (tableAmounts.isEmpty) {
    logger.d('📊 No table detected, skipping table candidate collection');
    return candidates;
  }
  
  logger.d('📊 Table detected, converting to candidates: $tableAmounts');
  
  // テーブルから抽出された値を候補に変換
  // テーブル抽出は構造的に信頼度が高いため、スコアを高く設定
  if (tableAmounts.containsKey('total_amount')) {
    candidates.add(AmountCandidate(
      amount: tableAmounts['total_amount']!,
      score: 95,  // テーブル抽出は高信頼度
      lineIndex: -1,  // テーブル行は複数行にまたがる可能性
      source: 'table_extraction_total',
      fieldName: 'total_amount',
      boundingBox: null,  // テーブル全体の位置情報は複雑なため省略
      confidence: 1.0,  // テーブル抽出は構造的に信頼度が高い
    ));
    logger.d('📊 Added table candidate: total_amount=${tableAmounts['total_amount']}');
  }
  
  if (tableAmounts.containsKey('subtotal_amount')) {
    candidates.add(AmountCandidate(
      amount: tableAmounts['subtotal_amount']!,
      score: 95,
      lineIndex: -1,
      source: 'table_extraction_subtotal',
      fieldName: 'subtotal_amount',
      boundingBox: null,
      confidence: 1.0,
    ));
    logger.d('📊 Added table candidate: subtotal_amount=${tableAmounts['subtotal_amount']}');
  }
  
  if (tableAmounts.containsKey('tax_amount')) {
    candidates.add(AmountCandidate(
      amount: tableAmounts['tax_amount']!,
      score: 95,
      lineIndex: -1,
      source: 'table_extraction_tax',
      fieldName: 'tax_amount',
      boundingBox: null,
      confidence: 1.0,
    ));
    logger.d('📊 Added table candidate: tax_amount=${tableAmounts['tax_amount']}');
  }
  
  return candidates;
}
```

---

## 8. まとめ

この実装により、テーブル形式と非テーブル形式のレシートの両方で、統合的な整合性チェックが可能になります。テーブル内外の両方から候補を収集し、最適な組み合わせを選択することで、精度と堅牢性が向上します。

