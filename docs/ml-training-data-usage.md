# 擬似ラベルと正解データの使用方法

## 概要

このドキュメントでは、シーケンスラベリングモデルの学習において、擬似ラベル（Pseudo Labels）と正解データ（Ground Truth）をどのように使用するか、およびTFLiteでの読み込み方法について説明します。

---

## 重要なポイント

**⚠️ TFLiteは推論（inference）専用です。学習（training）は行いません。**

### 学習の流れ

1. **学習（Python側）**: 擬似ラベルと正解データを使用してモデルを学習
2. **モデル変換**: 学習済みモデルをTFLite形式に変換
3. **推論（Flutter側）**: TFLiteモデルを読み込んで推論を実行

---

## 1. データの構造

### 1.1 擬似ラベルデータ（Pseudo Labels）

- **保存先**: `training_data/raw/`
- **特徴**: ルールベースで自動生成されたラベル
- **信頼度**: `label_confidence`フィールドで管理（0.0-1.0）
- **フラグ**: `is_verified: false`（または未設定）

```json
{
  "receipt_id": "receipt_001",
  "text_lines": [
    {
      "text": "TOTAL: €15.60",
      "label": "TOTAL",
      "label_confidence": 0.85,
      "features": {
        "feature_vector": [0.5, 0.7, ...]
      }
    }
  ],
  "metadata": {
    "is_verified": false
  }
}
```

### 1.2 正解データ（Ground Truth）

- **保存先**: `training_data/verified/`
- **特徴**: ユーザーが手動で修正・確認したデータ
- **信頼度**: 常に1.0（完全に信頼できる）
- **フラグ**: `is_verified: true`

```json
{
  "receipt_id": "receipt_001",
  "text_lines": [
    {
      "text": "TOTAL: €15.60",
      "label": "TOTAL",
      "label_confidence": 1.0,
      "features": {
        "feature_vector": [0.5, 0.7, ...]
      }
    }
  ],
  "metadata": {
    "is_verified": true,
    "verified_by": "user",
    "verified_at": "2026-01-03T10:00:00Z"
  }
}
```

---

## 2. Python側での学習方法

### 2.1 データの読み込み

```python
import json
import glob
import numpy as np
from tensorflow import keras
import tensorflow as tf

def load_training_data(file_path):
    """学習データを読み込む"""
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # feature_vectorとlabelを抽出
    X = []  # 特徴量ベクトル
    y = []  # ラベル
    weights = []  # サンプル重み
    is_verified = data['metadata'].get('is_verified', False)
    
    for line in data['text_lines']:
        # 特徴量ベクトル（20次元）
        feature_vector = line['features']['feature_vector']
        X.append(feature_vector)
        
        # ラベル
        label = line['label']
        y.append(label)
        
        # サンプル重み
        if is_verified:
            # 正解データは重み1.0
            weights.append(1.0)
        else:
            # 擬似ラベルは信頼度に応じて重みを設定
            confidence = line.get('label_confidence', 0.5)
            weight = confidence * 0.7  # 最大0.7まで
            weights.append(weight)
    
    return X, y, weights, is_verified

# データの収集
X_train = []
y_train = []
weights_train = []

# 1. 正解データを優先的に読み込み（重み: 1.0）
verified_files = glob.glob('training_data/verified/*.json')
for file in verified_files:
    X, y, w, _ = load_training_data(file)
    X_train.extend(X)
    y_train.extend(y)
    weights_train.extend(w)

# 2. 擬似ラベルを追加（重み: 0.3-0.7）
pseudo_label_files = glob.glob('training_data/raw/*.json')
for file in pseudo_label_files:
    X, y, w, _ = load_training_data(file)
    X_train.extend(X)
    y_train.extend(y)
    weights_train.extend(w)

# NumPy配列に変換
X_train = np.array(X_train, dtype=np.float32)
y_train = np.array(y_train)
weights_train = np.array(weights_train)
```

### 2.2 ラベルのエンコーディング

```python
from sklearn.preprocessing import LabelEncoder

# ラベルを数値に変換
label_encoder = LabelEncoder()
y_train_encoded = label_encoder.fit_transform(y_train)

# ラベル名のマッピングを保存（推論時に使用）
label_mapping = {i: label for i, label in enumerate(label_encoder.classes_)}
with open('label_mapping.json', 'w') as f:
    json.dump(label_mapping, f)

print(f"ラベル数: {len(label_encoder.classes_)}")
print(f"ラベル: {label_encoder.classes_}")
```

### 2.3 モデルの定義

```python
# ラベル数
num_labels = len(label_encoder.classes_)

# モデル定義（BiLSTM + Softmax）
model = keras.Sequential([
    keras.layers.Dense(128, activation='relu', input_shape=(20,)),
    keras.layers.Dropout(0.3),
    keras.layers.Dense(64, activation='relu'),
    keras.layers.Dropout(0.2),
    keras.layers.Dense(num_labels, activation='softmax')
])

model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=0.001),
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
)

model.summary()
```

### 2.4 学習の実行

#### 方法1: 統合学習（推奨）

```python
# データを統合して学習
# 正解データと擬似ラベルを混ぜて学習（サンプル重みで優先度を制御）

# データ分割
from sklearn.model_selection import train_test_split

X_train_split, X_val_split, y_train_split, y_val_split, w_train_split, w_val_split = \
    train_test_split(X_train, y_train_encoded, weights_train, test_size=0.2, random_state=42)

# 学習
history = model.fit(
    X_train_split, y_train_split,
    sample_weight=w_train_split,  # 正解データを優先
    validation_data=(X_val_split, y_val_split),
    epochs=50,
    batch_size=32,
    callbacks=[
        keras.callbacks.EarlyStopping(patience=10, restore_best_weights=True),
        keras.callbacks.ModelCheckpoint('best_model.h5', save_best_only=True)
    ]
)
```

#### 方法2: 段階的学習（高精度）

```python
# Step 1: 擬似ラベルで事前学習
X_pseudo = []
y_pseudo = []
w_pseudo = []

for file in pseudo_label_files:
    X, y, w, _ = load_training_data(file)
    X_pseudo.extend(X)
    y_pseudo.extend(y)
    w_pseudo.extend(w)

X_pseudo = np.array(X_pseudo, dtype=np.float32)
y_pseudo_encoded = label_encoder.transform(y_pseudo)
w_pseudo = np.array(w_pseudo)

# 事前学習
model.fit(
    X_pseudo, y_pseudo_encoded,
    sample_weight=w_pseudo,
    epochs=30,
    batch_size=32
)

# Step 2: 正解データで微調整（学習率を下げる）
X_verified = []
y_verified = []

for file in verified_files:
    X, y, _, _ = load_training_data(file)
    X_verified.extend(X)
    y_verified.extend(y)

X_verified = np.array(X_verified, dtype=np.float32)
y_verified_encoded = label_encoder.transform(y_verified)

# 学習率を下げて微調整
model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=0.0001),
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
)

model.fit(
    X_verified, y_verified_encoded,
    epochs=20,
    batch_size=16
)
```

### 2.5 TFLiteへの変換

```python
# KerasモデルをTFLiteに変換
converter = tf.lite.TFLiteConverter.from_keras_model(model)

# 最適化オプション（オプション）
converter.optimizations = [tf.lite.Optimize.DEFAULT]

# 変換
tflite_model = converter.convert()

# 保存
with open('receipt_labeling_model.tflite', 'wb') as f:
    f.write(tflite_model)

print(f"モデルサイズ: {len(tflite_model) / 1024:.2f} KB")
```

---

## 3. Flutter側での使用方法（TFLite推論）

### 3.1 依存関係の追加

```yaml
# pubspec.yaml
dependencies:
  tflite_flutter: ^0.10.4  # TFLite推論用
```

### 3.2 TFLiteモデルサービスの実装

```dart
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';
import 'dart:convert';

class MLModelService {
  Interpreter? _interpreter;
  Map<int, String>? _labelMapping;
  
  /// モデルとラベルマッピングを読み込む
  Future<void> loadModel() async {
    try {
      // TFLiteモデルを読み込む
      _interpreter = await Interpreter.fromAsset('receipt_labeling_model.tflite');
      
      // ラベルマッピングを読み込む
      final labelMappingJson = await rootBundle.loadString('assets/label_mapping.json');
      final labelMappingData = json.decode(labelMappingJson) as Map<String, dynamic>;
      _labelMapping = labelMappingData.map((key, value) => 
        MapEntry(int.parse(key), value as String)
      );
      
      logger.i('✅ ML Model loaded successfully');
    } catch (e) {
      logger.e('Failed to load ML model: $e');
      rethrow;
    }
  }
  
  /// 特徴量ベクトルからラベルを予測
  List<String> predictLabels(List<List<double>> featureVectors) {
    if (_interpreter == null || _labelMapping == null) {
      throw Exception('Model not loaded');
    }
    
    // 入力: [batch_size, 20] (feature_vector)
    // 出力: [batch_size, num_labels] (各ラベルの確率)
    
    final input = featureVectors.map((fv) => 
      Float32List.fromList(fv)
    ).toList();
    
    final output = List.generate(
      featureVectors.length,
      (_) => List.filled(_labelMapping!.length, 0.0),
    );
    
    // 推論実行
    _interpreter!.run(input, output);
    
    // 最も確率の高いラベルを選択
    final predictions = output.map((probs) {
      double maxProb = probs[0];
      int maxIndex = 0;
      
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > maxProb) {
          maxProb = probs[i];
          maxIndex = i;
        }
      }
      
      return _labelMapping![maxIndex] ?? 'OTHER';
    }).toList();
    
    return predictions;
  }
  
  /// TextLineのリストからラベルを予測
  List<String> predictLabelsFromTextLines(List<Map<String, dynamic>> textLines) {
    // feature_vectorを抽出
    final featureVectors = textLines.map((line) {
      final features = line['features'] as Map<String, dynamic>;
      final featureVector = features['feature_vector'] as List;
      return featureVector.map((v) => (v as num).toDouble()).toList();
    }).toList();
    
    return predictLabels(featureVectors);
  }
  
  void dispose() {
    _interpreter?.close();
  }
}
```

### 3.3 使用例

```dart
// サービスの初期化
final mlModelService = MLModelService();
await mlModelService.loadModel();

// OCR結果からラベルを予測
final ocrResult = await mlKitService.recognizeTextFromFile(imagePath);
final textLines = ocrResult.textLines.map((line) => {
  'text': line.text,
  'features': {
    'feature_vector': extractFeatures(line), // 特徴量抽出
  }
}).toList();

// MLモデルでラベルを予測
final predictedLabels = mlModelService.predictLabelsFromTextLines(textLines);

// 予測結果を使用
for (int i = 0; i < textLines.length; i++) {
  final label = predictedLabels[i];
  final text = textLines[i]['text'];
  logger.d('Line $i: "$text" → $label');
}
```

---

## 4. 学習戦略の推奨

### 4.1 データの優先順位

1. **正解データ（is_verified: true）**
   - 重み: 1.0（完全に信頼）
   - 優先度: 最高
   - 用途: 微調整、最終評価

2. **高信頼度擬似ラベル（label_confidence >= 0.8）**
   - 重み: 0.7
   - 優先度: 高
   - 用途: 事前学習の主要データ

3. **中信頼度擬似ラベル（0.5 <= label_confidence < 0.8）**
   - 重み: 0.4-0.6
   - 優先度: 中
   - 用途: データ拡張、汎化性能向上

4. **低信頼度擬似ラベル（label_confidence < 0.5）**
   - 重み: 0.0-0.3（または除外）
   - 優先度: 低
   - 用途: 基本的に使用しない

### 4.2 段階的学習の推奨フロー

```
1. 擬似ラベルで事前学習（大量データ、重み0.3-0.7）
   ↓
2. 正解データで微調整（少量データ、重み1.0、学習率を下げる）
   ↓
3. 検証データで評価
   ↓
4. 必要に応じて追加の正解データで再学習
```

### 4.3 データ拡張（Data Augmentation）

擬似ラベルデータに対して以下の拡張を適用可能：

- **金額の表記ゆれ**: `12.34` ↔ `12,34` ↔ `1 234,56`
- **OCR誤りシミュレーション**: `0↔O`, `1↔I`, `8↔B`
- **位置の微調整**: bbox座標に小さなノイズを追加

---

## 5. 現在の実装状況

### ✅ 実装済み

- [x] 学習データの保存（`training_data/raw/`）
- [x] 行特徴量の抽出（`feature_vector`）
- [x] 擬似ラベルの生成（`label`, `label_confidence`）
- [x] JSON形式でのデータ出力

### ❌ 未実装

- [ ] 正解データ保存機能（`training_data/verified/`）
- [ ] Python学習スクリプト
- [ ] TFLite統合（Flutter側）
- [ ] ラベルマッピングの管理

---

## 6. 次のステップ

### 優先度: 高

1. **正解データ保存機能の実装**
   - プレビュー画面に「修正して保存」ボタンを追加
   - `is_verified: true`フラグを付与
   - `training_data/verified/`に保存

2. **Python学習スクリプトの作成**
   - データ読み込み機能
   - モデル定義
   - 学習パイプライン
   - TFLite変換

### 優先度: 中

3. **TFLite統合（Flutter側）**
   - `tflite_flutter`パッケージの追加
   - `MLModelService`の実装
   - 推論パイプラインの統合

4. **ラベルマッピングの管理**
   - ラベル一覧の定義
   - マッピングファイルの生成・管理

---

## 7. 参考資料

- [TensorFlow Lite公式ドキュメント](https://www.tensorflow.org/lite)
- [tflite_flutterパッケージ](https://pub.dev/packages/tflite_flutter)
- [Sequence Labeling from textLines](./Sequence_Labeling_from_textLines.md)

---

## 8. よくある質問

### Q: 擬似ラベルだけで学習できますか？

A: 可能ですが、精度は限定的です。正解データを追加することで大幅に精度が向上します。

### Q: 正解データはどのくらい必要ですか？

A: 最低でも50-100サンプル、理想的には200-500サンプルあると良いです。ただし、擬似ラベルと組み合わせることで、より少ないデータでも効果があります。

### Q: TFLiteモデルのサイズはどのくらいですか？

A: シンプルなBiLSTMモデルで約100-500KB程度です。Transformerモデルの場合は1-5MB程度になる可能性があります。

### Q: 学習はどのくらいの時間がかかりますか？

A: データ量とモデルサイズによりますが、一般的には：
- 擬似ラベル（1000サンプル）: 10-30分
- 正解データでの微調整（100サンプル）: 1-5分

---

**最終更新**: 2026-01-03

