# Step 2: ルールベース抽出 + 整合性チェック 実装案

**目的**: MLなしでも精度向上を実現するため、複数候補の保持と整合性スコアリングによる最終決定機能を実装

---

## 1. 概要

### 現状の問題点
- 各フィールド（Total, Subtotal, Tax）に対して1つの候補しか保持していない
- 整合性チェックが限定的（`computed_total`のみ）
- OCR誤りや複数候補がある場合に最適解を選べない

### 実装目標
- 各フィールドに対して複数候補（上位3-5個）を保持
- 整合性スコアで最適な組み合わせを選択
- 矛盾検知と自動修正/要確認フラグ

---

## 2. データ構造の設計

### 2.1 候補データ構造

```dart
/// 金額候補を表すクラス
class AmountCandidate {
  final double amount;
  final int score;           // 信頼度スコア（0-100）
  final int lineIndex;       // 行番号
  final String source;        // 抽出元（pattern名など）
  final String? label;       // ラベル（"TOTAL", "SUBTOTAL"など）
  final double? confidence;  // OCR信頼度（あれば）
  final List<double>? boundingBox; // 位置情報
  
  AmountCandidate({
    required this.amount,
    required this.score,
    required this.lineIndex,
    required this.source,
    this.label,
    this.confidence,
    this.boundingBox,
  });
}

/// フィールドごとの候補リスト
class FieldCandidates {
  final String fieldName;  // 'total_amount', 'subtotal_amount', 'tax_amount'
  final List<AmountCandidate> candidates;
  
  FieldCandidates({
    required this.fieldName,
    required this.candidates,
  });
  
  /// 上位N個の候補を取得
  List<AmountCandidate> getTopN(int n) {
    final sorted = List<AmountCandidate>.from(candidates);
    sorted.sort((a, b) => b.score.compareTo(a.score));
    return sorted.take(n).toList();
  }
  
  /// 最良候補を取得
  AmountCandidate? get best => candidates.isNotEmpty 
      ? getTopN(1).first 
      : null;
}
```

### 2.2 整合性スコアリング結果

```dart
/// 整合性チェック結果
class ConsistencyResult {
  final Map<String, AmountCandidate> selectedCandidates;
  final double consistencyScore;  // 0.0 - 1.0
  final List<String> warnings;     // 警告メッセージ
  final bool needsVerification;   // 要確認フラグ
  final Map<String, double>? correctedValues; // 修正された値（あれば）
  
  ConsistencyResult({
    required this.selectedCandidates,
    required this.consistencyScore,
    this.warnings = const [],
    this.needsVerification = false,
    this.correctedValues,
  });
}
```

---

## 3. 実装詳細

### 3.1 複数候補の収集（既存コードの拡張）

```dart
// lib/services/extraction/receipt_parser.dart

/// 金額抽出（複数候補を保持する版）
Map<String, FieldCandidates> _extractAmountsWithCandidates(
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
  
  // 既存の抽出ロジックを拡張
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
          // 位置情報を取得（textLinesから）
          final bbox = textLines != null && i < textLines.length
              ? textLines[i].boundingBox
              : null;
          
          candidates['total_amount']!.add(AmountCandidate(
            amount: amount,
            score: 100,  // パターンマッチの基本スコア
            lineIndex: i,
            source: 'total_pattern_$p',
            label: 'TOTAL',
            confidence: textLines != null && i < textLines.length
                ? textLines[i].confidence
                : null,
            boundingBox: bbox,
          ));
        }
      }
    }
    
    // Subtotal候補の収集（同様）
    // Tax候補の収集（同様）
  }
  
  // スコアの調整（位置情報によるボーナス）
  _applyPositionBonuses(candidates, lines.length);
  
  // FieldCandidatesに変換
  return {
    'total_amount': FieldCandidates(
      fieldName: 'total_amount',
      candidates: candidates['total_amount']!,
    ),
    'subtotal_amount': FieldCandidates(
      fieldName: 'subtotal_amount',
      candidates: candidates['subtotal_amount']!,
    ),
    'tax_amount': FieldCandidates(
      fieldName: 'tax_amount',
      candidates: candidates['tax_amount']!,
    ),
  };
}

/// 位置情報によるスコアボーナス
void _applyPositionBonuses(
  Map<String, List<AmountCandidate>> candidates,
  int totalLines,
) {
  // Totalは下側にあるほどボーナス
  for (final candidate in candidates['total_amount']!) {
    final positionRatio = candidate.lineIndex / totalLines;
    if (positionRatio > 0.6) {
      candidate.score += 10;  // 下側にいるほど高スコア
    }
  }
  
  // SubtotalはTotalより上にあるほどボーナス
  // （実装は省略）
}
```

### 3.2 整合性スコアリング

```dart
/// 整合性チェックと最適解の選択
ConsistencyResult _selectBestCandidates(
  Map<String, FieldCandidates> allCandidates,
) {
  // 各フィールドの上位候補を取得
  final totalCandidates = allCandidates['total_amount']!.getTopN(3);
  final subtotalCandidates = allCandidates['subtotal_amount']!.getTopN(3);
  final taxCandidates = allCandidates['tax_amount']!.getTopN(3);
  
  double bestScore = -1.0;
  Map<String, AmountCandidate> bestSelection = {};
  List<String> warnings = [];
  
  // 全組み合わせを評価（最大3×3×3 = 27通り）
  for (final total in totalCandidates) {
    for (final subtotal in subtotalCandidates) {
      for (final tax in taxCandidates) {
        final score = _calculateConsistencyScore(
          total: total,
          subtotal: subtotal,
          tax: tax,
        );
        
        if (score > bestScore) {
          bestScore = score;
          bestSelection = {
            'total_amount': total,
            'subtotal_amount': subtotal,
            'tax_amount': tax,
          };
        }
      }
    }
  }
  
  // 警告の生成
  if (bestScore < 0.7) {
    warnings.add('Low consistency score: ${bestScore.toStringAsFixed(2)}');
  }
  
  // 矛盾検知
  final total = bestSelection['total_amount']!.amount;
  final subtotal = bestSelection['subtotal_amount']!.amount;
  final tax = bestSelection['tax_amount']!.amount;
  final expectedTotal = subtotal + tax;
  final difference = (total - expectedTotal).abs();
  
  Map<String, double>? correctedValues;
  if (difference > 0.01) {  // 1セント以上の差
    warnings.add('Amount mismatch: total ($total) != subtotal ($subtotal) + tax ($tax)');
    
    // 自動修正の試行
    if (difference < 0.10) {  // 10セント以内なら修正を試みる
      correctedValues = {
        'total_amount': expectedTotal,
      };
      warnings.add('Auto-corrected total: $total → $expectedTotal');
    } else {
      warnings.add('Large difference ($difference), manual verification required');
    }
  }
  
  return ConsistencyResult(
    selectedCandidates: bestSelection,
    consistencyScore: bestScore,
    warnings: warnings,
    needsVerification: bestScore < 0.6 || difference > 0.10,
    correctedValues: correctedValues,
  );
}

/// 整合性スコアの計算
double _calculateConsistencyScore({
  required AmountCandidate total,
  required AmountCandidate subtotal,
  required AmountCandidate tax,
}) {
  double score = 0.0;
  
  // 1. 基本的な整合性チェック（最重要）
  final expectedTotal = subtotal.amount + tax.amount;
  final difference = (total.amount - expectedTotal).abs();
  final tolerance = 0.01;  // 1セントの許容誤差
  
  if (difference <= tolerance) {
    score += 0.5;  // 完全一致
  } else if (difference <= 0.10) {
    score += 0.3;  // 10セント以内
  } else if (difference <= 1.0) {
    score += 0.1;  // 1ユーロ以内
  }
  // それ以上は0点
  
  // 2. 候補の信頼度スコア（正規化）
  final avgCandidateScore = (total.score + subtotal.score + tax.score) / 3.0;
  score += (avgCandidateScore / 100.0) * 0.3;  // 最大0.3点
  
  // 3. 位置関係の整合性
  // TotalはSubtotalより下にあるべき
  if (total.lineIndex > subtotal.lineIndex) {
    score += 0.1;
  }
  
  // 4. OCR信頼度（あれば）
  if (total.confidence != null && 
      subtotal.confidence != null && 
      tax.confidence != null) {
    final avgConfidence = (total.confidence! + 
                          subtotal.confidence! + 
                          tax.confidence!) / 3.0;
    score += avgConfidence * 0.1;  // 最大0.1点
  }
  
  return score.clamp(0.0, 1.0);
}
```

### 3.3 既存コードへの統合

```dart
// _parseWithStructuredData メソッドの修正

Map<String, double> _extractAmountsLineByLine(
  List<String> lines,
  String? language,
  List<String> appliedPatterns, {
  List<TextLine>? textLines,
}) {
  // 1. 複数候補を収集
  final allCandidates = _extractAmountsWithCandidates(
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
    } else {
      amounts[fieldName] = candidate.amount;
      appliedPatterns.add('${fieldName}_${candidate.source}');
    }
  }
  
  // 4. 警告をログに記録
  if (consistencyResult.warnings.isNotEmpty) {
    logger.w('Consistency warnings: ${consistencyResult.warnings.join(", ")}');
  }
  
  // 5. 要確認フラグをメタデータに追加
  if (consistencyResult.needsVerification) {
    appliedPatterns.add('needs_verification');
    logger.w('⚠️ Receipt needs manual verification');
  }
  
  return amounts;
}
```

---

## 4. 拡張機能

### 4.1 VAT Breakdown（税内訳）の整合性チェック

```dart
/// VAT Breakdownテーブルがある場合の整合性チェック
double _calculateVatBreakdownConsistency({
  required List<VatBreakdownRow> vatRows,
  required AmountCandidate? tax,
  required AmountCandidate? subtotal,
}) {
  if (vatRows.isEmpty) return 0.0;
  
  double score = 0.0;
  
  // VAT Breakdownから税額を再計算
  final calculatedTax = vatRows
      .map((row) => row.taxAmount)
      .fold(0.0, (sum, amount) => sum + amount);
  
  // 税額の整合性
  if (tax != null) {
    final taxDifference = (tax.amount - calculatedTax).abs();
    if (taxDifference <= 0.01) {
      score += 0.3;
    } else if (taxDifference <= 0.10) {
      score += 0.2;
    }
  }
  
  // 課税対象額の整合性（店による）
  final calculatedSubtotal = vatRows
      .map((row) => row.baseAmount)
      .fold(0.0, (sum, amount) => sum + amount);
  
  if (subtotal != null) {
    final subtotalDifference = (subtotal.amount - calculatedSubtotal).abs();
    if (subtotalDifference <= 0.01) {
      score += 0.2;
    }
  }
  
  return score;
}
```

### 4.2 候補の優先順位調整

```dart
/// キーワードの明示性によるスコア調整
void _adjustScoreByExplicitness(
  List<AmountCandidate> candidates,
  List<String> lines,
) {
  final totalLabel = PatternGenerator.generateLabelPattern('total');
  final subtotalLabel = PatternGenerator.generateLabelPattern('subtotal');
  
  for (final candidate in candidates) {
    final line = lines[candidate.lineIndex].toLowerCase();
    
    // 明示的なラベルがある場合にボーナス
    if (candidate.fieldName == 'total_amount' && 
        totalLabel.hasMatch(line)) {
      candidate.score += 5;
    }
    
    if (candidate.fieldName == 'subtotal_amount' && 
        subtotalLabel.hasMatch(line)) {
      candidate.score += 5;
    }
  }
}
```

---

## 5. 実装ステップ

### Phase 1: データ構造の追加（1-2日）
1. `AmountCandidate`クラスの作成
2. `FieldCandidates`クラスの作成
3. `ConsistencyResult`クラスの作成

### Phase 2: 複数候補収集の実装（2-3日）
1. `_extractAmountsWithCandidates`メソッドの実装
2. 既存の`_extractAmountsLineByLine`を拡張
3. 位置情報ボーナスの実装

### Phase 3: 整合性チェックの実装（2-3日）
1. `_calculateConsistencyScore`メソッドの実装
2. `_selectBestCandidates`メソッドの実装
3. 自動修正ロジックの実装

### Phase 4: 統合とテスト（1-2日）
1. 既存コードへの統合
2. テストレシートでの検証
3. エッジケースの処理

---

## 6. 期待される効果

### 精度向上
- **OCR誤りの吸収**: 複数候補から最適解を選択
- **整合性による検証**: 会計ロジックで正しさを保証
- **自動修正**: 小さな誤差を自動で修正

### ユーザー体験
- **要確認フラグ**: 矛盾がある場合に明確に表示
- **候補の提示**: ユーザーが手動で選択可能
- **信頼度の可視化**: 整合性スコアを表示

---

## 7. 注意点

### パフォーマンス
- 組み合わせの評価は最大27通り（3×3×3）なので問題なし
- 計算時間は数ミリ秒程度

### エッジケース
- 免税レシート（tax = 0）の処理
- 複数のTotal候補（割引前/後など）
- VAT Breakdownがない場合の処理

### 段階的導入
- まずはTotal/Subtotal/Taxのみ実装
- VAT Breakdownは後で追加
- ユーザーフィードバックで調整

---

## 8. 次のステップ（Step 3への準備）

この実装により、以下が可能になります：
- 複数候補の保持 → MLモデルの学習データとして活用可能
- 整合性スコア → MLモデルの信頼度指標として使用可能
- 要確認フラグ → ユーザー修正データの収集が容易

Step 3（擬似ラベル収集）では、この実装結果をログとして保存し、MLモデルの学習データとして活用します。

