# 訓練データ検証レポート

## 検証日: 2026-01-06

## 検証対象データ

1. **Rawデータ**: `receipt_receipt_en_4_1767705655161_1767705655187.json`
2. **Verifiedデータ**: `verified_receipt_receipt_en_4_1767705667214_1767705667246.json`

---

## ✅ 学習可能な要素

### 1. データ構造
- ✅ `text_lines`配列が正しく存在
- ✅ 各行に必要なフィールドがすべて含まれている：
  - `text`: テキスト内容
  - `bounding_box`: 位置情報
  - `label`: ラベル（MERCHANT_NAME, ITEM_NAME, SUBTOTAL, TAX, TOTAL, OTHER等）
  - `label_confidence`: 信頼度
  - `features`: 特徴量オブジェクト
  - `feature_vector`: 20次元の特徴量ベクトル

### 2. 特徴量ベクトル
- ✅ 20次元の`feature_vector`が正しく計算されている
- ✅ 正規化された値（0.0-1.0範囲）が使用されている
- ✅ 位置情報、キーワードマッチ、数値パターンなどの特徴量が含まれている

### 3. Tax Breakdown対応
- ✅ Verifiedデータに`tax_breakdown`配列が正しく保存されている
- ✅ 2つのTax行が正しく`label: "TAX"`として設定されている
- ✅ Tax Breakdownの金額（2.90, 1.28）が正しく保存されている

### 4. ラベルの種類
- ✅ 必要なラベルがすべて含まれている：
  - MERCHANT_NAME
  - ITEM_NAME
  - SUBTOTAL
  - TAX（複数行対応）
  - TOTAL
  - OTHER
  - TIME

---

## ⚠️ 改善が必要な点

### 1. Verifiedデータの`label_confidence`が不適切

**問題点:**
- VerifiedデータでもTAX行の`label_confidence`が`0.8`になっている
- Verifiedデータは手動で確認・修正したデータなので、`label_confidence`は`1.0`であるべき

**影響:**
- 学習時にVerifiedデータの重みが適切に設定されない可能性
- モデルがVerifiedデータを完全に信頼しない可能性

**推奨修正:**
```dart
// training_data_collector.dart の _generatePseudoLabel 関数
// Verifiedデータの場合、label_confidenceを1.0に設定
if (isVerified) {
  return {'label': 'TAX', 'confidence': 1.0};
}
```

**現在の状態:**
- Rawデータ: `label_confidence: 0.8` ✅ 適切
- Verifiedデータ: `label_confidence: 0.8` ❌ 1.0であるべき

### 2. Tax Breakdownの金額マッチング確認

**確認事項:**
- Verifiedデータの`tax_breakdown`:
  - Rate 7.9% → Amount 2.9 ✅
  - Rate 4.9% → Amount 1.28 ✅
- テキスト行の金額:
  - "TAX 1 7.89% 2.90" → 2.90 ✅
  - "TAX 2 4.90% 1.28" → 1.28 ✅

**注意点:**
- Verifiedデータの`tax_breakdown`の`rate`が`7.9`だが、テキスト行は`7.89%`
- これはユーザーが手動で修正した可能性がある（許容範囲内）

---

## 📊 データ品質評価

### Rawデータ
- **ラベル精度**: 良好（主要なラベルが正しく設定されている）
- **信頼度設定**: 適切（0.3-0.9の範囲で適切に設定）
- **特徴量**: 完全（20次元の特徴量ベクトルが正しく計算されている）

### Verifiedデータ
- **ラベル精度**: 良好（手動修正により正確）
- **信頼度設定**: ⚠️ 改善が必要（TAX行が0.8のまま）
- **Tax Breakdown**: ✅ 正しく保存されている
- **特徴量**: 完全（Rawデータと同じ特徴量が使用されている）

---

## ✅ 学習に使用可能か？

**結論: はい、学習に使用可能です。**

ただし、以下の改善を推奨します：

1. **即座に修正すべき点:**
   - Verifiedデータの`label_confidence`を1.0に設定

2. **推奨される改善:**
   - Verifiedデータ保存時に、すべてのラベルの`label_confidence`を1.0に設定
   - Tax Breakdownの金額マッチングをより厳密に検証

---

## 🔧 推奨される修正

### `training_data_collector.dart`の修正

```dart
// Verifiedデータの場合、label_confidenceを1.0に設定
Map<String, dynamic> _generatePseudoLabel(
  TextLine line,
  Map<String, dynamic> extractedData,
  bool isVerified,
) {
  // ... 既存のロジック ...
  
  // Verifiedデータの場合、confidenceを1.0に設定
  final confidenceBase = isVerified ? 1.0 : 0.9;
  
  // Taxの処理
  final taxKeywords = LanguageKeywords.getAllKeywords('tax');
  for (final keyword in taxKeywords) {
    if (text.contains(keyword.toLowerCase())) {
      if (isVerified && taxBreakdowns != null && taxBreakdowns.isNotEmpty && lineAmount != null) {
        // ... 既存のマッチングロジック ...
        if (matchesBreakdown) {
          return {'label': 'TAX', 'confidence': 1.0}; // ✅ 1.0に設定
        }
      }
      // Verifiedデータの場合も1.0に設定
      final confidence = isVerified ? 1.0 : 
          (taxAmount != null && lineAmount != null &&
           (lineAmount - taxAmount).abs() < 0.01 ? confidenceBase : 0.8);
      return {'label': 'TAX', 'confidence': confidence};
    }
  }
  
  // 他のラベルも同様に処理
  // ...
}
```

---

## 📝 学習時の使用方法

### Python側でのデータ読み込み例

```python
import json
import numpy as np

def load_training_data(file_path):
    """学習データを読み込む"""
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    X = []  # 特徴量ベクトル
    y = []  # ラベル
    weights = []  # サンプル重み
    is_verified = data.get('is_verified', False) or data['metadata'].get('is_verified', False)
    
    for line in data['text_lines']:
        # 特徴量ベクトル（20次元）
        feature_vector = line['feature_vector']
        X.append(feature_vector)
        
        # ラベル
        label = line['label']
        y.append(label)
        
        # サンプル重み
        if is_verified:
            # Verifiedデータは重み1.0
            weights.append(1.0)
        else:
            # Rawデータは信頼度に応じて重みを設定
            confidence = line.get('label_confidence', 0.5)
            weight = confidence * 0.7  # 最大0.7まで
            weights.append(weight)
    
    return X, y, weights

# 使用例
X_train = []
y_train = []
weights_train = []

# Verifiedデータを優先的に読み込み
verified_files = glob.glob('verified_data/verified_*.json')
for file in verified_files:
    X, y, w = load_training_data(file)
    X_train.extend(X)
    y_train.extend(y)
    weights_train.extend(w)

# Rawデータを追加
raw_files = glob.glob('training_data/receipt_*.json')
for file in raw_files:
    X, y, w = load_training_data(file)
    X_train.extend(X)
    y_train.extend(y)
    weights_train.extend(w)

# NumPy配列に変換
X_train = np.array(X_train, dtype=np.float32)
y_train = np.array(y_train)
weights_train = np.array(weights_train)
```

---

## まとめ

1. **データ構造**: ✅ 完全に学習可能な形式
2. **特徴量**: ✅ 20次元の特徴量ベクトルが正しく計算されている
3. **Tax Breakdown**: ✅ 複数のTax行が正しく処理されている
4. **改善点**: Verifiedデータの`label_confidence`を1.0に設定することを推奨

**結論: 現在のデータでも学習は可能ですが、Verifiedデータの`label_confidence`を1.0に設定することで、より効果的な学習が期待できます。**

