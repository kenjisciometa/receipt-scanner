# レシート抽出用機械学習モデル提案書

**作成日**: 2026年1月2日  
**バージョン**: 1.0.0

---

## 1. 概要

現在のルールベース抽出では、多様なレシートフォーマットや言語に対応するのが困難です。`textLines`の構造化データを活用した機械学習モデルにより、より汎用的で高精度な抽出を実現します。

### 目標
- **汎用性**: 様々なレシートフォーマットに対応
- **多言語対応**: 言語に依存しない抽出
- **自動学習**: 既存のルールベース結果から学習データを自動生成
- **オンデバイス推論**: Flutterアプリ内で高速に動作

---

## 2. アーキテクチャ提案

### 2.1 モデルタイプの選択

#### オプションA: シーケンスラベリング（NER風）
**推奨度: ⭐⭐⭐⭐⭐**

各`TextLine`に対して以下のラベルを付与：
- `MERCHANT_NAME`
- `DATE`
- `TIME`
- `RECEIPT_NUMBER`
- `ITEM_NAME`
- `ITEM_PRICE`
- `SUBTOTAL`
- `TAX`
- `TOTAL`
- `PAYMENT_METHOD`
- `CURRENCY`
- `OTHER` (無関係なテキスト)

**メリット**:
- 構造化データ（位置情報）を活用しやすい
- 各フィールドを独立して抽出可能
- 実装が比較的シンプル

**モデル構造**:
```
Input: [text, x, y, width, height, confidence, line_index, relative_position]
  ↓
Feature Engineering (Embedding + Position Encoding)
  ↓
BiLSTM or Transformer Encoder
  ↓
Classification Head (Multi-label)
  ↓
Output: [label_probabilities]
```

#### オプションB: 構造化抽出モデル（Graph Neural Network）
**推奨度: ⭐⭐⭐**

`textLines`をグラフ構造として扱い、位置関係を学習：
- ノード: 各`TextLine`
- エッジ: 位置関係（上下左右、距離）

**メリット**:
- レシートの構造を直接学習
- テーブル構造の検出に強い

**デメリット**:
- 実装が複雑
- 訓練時間が長い

#### オプションC: ハイブリッドアプローチ
**推奨度: ⭐⭐⭐⭐**

ルールベース + 軽量MLモデル：
1. ルールベースで高信頼度の抽出を実行
2. 不明確な部分のみMLモデルで補完
3. 最終的に両方の結果を統合

**メリット**:
- 既存システムとの統合が容易
- 段階的導入が可能
- パフォーマンスと精度のバランスが良い

---

## 3. 学習データ自動生成戦略

### 3.1 データ収集パイプライン

```
┌─────────────────────────────────────────┐
│ 1. 既存レシート画像 + OCR結果            │
│    - textLines (構造化データ)           │
│    - boundingBox情報                    │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 2. ルールベース抽出を実行                 │
│    - 高信頼度の抽出結果を教師データ化    │
│    - 信頼度スコアでフィルタリング        │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 3. AI支援ラベリング（オプション）        │
│    - GPT-4/Claudeでラベル補完            │
│    - 不確実な部分の検証                  │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 4. データ拡張                            │
│    - 位置情報のノイズ追加                │
│    - テキストのバリエーション生成        │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 5. 学習データセット完成                  │
│    - JSON形式で保存                      │
│    - バージョン管理                      │
└─────────────────────────────────────────┘
```

### 3.2 データ形式

```json
{
  "receipt_id": "receipt_001",
  "image_path": "assets/images/test_receipt.png",
  "text_lines": [
    {
      "text": "SUPERMARKET ABC",
      "bounding_box": [50.0, 30.0, 300.0, 20.0],
      "confidence": 0.95,
      "line_index": 0,
      "label": "MERCHANT_NAME",
      "extracted_value": "SUPERMARKET ABC"
    },
    {
      "text": "Date: 2026-01-02",
      "bounding_box": [50.0, 60.0, 150.0, 15.0],
      "confidence": 0.92,
      "line_index": 1,
      "label": "DATE",
      "extracted_value": "2026-01-02"
    },
    {
      "text": "Subtotal: €12.58",
      "bounding_box": [50.0, 391.0, 200.0, 15.0],
      "confidence": 0.88,
      "line_index": 11,
      "label": "SUBTOTAL",
      "extracted_value": 12.58
    }
  ],
  "metadata": {
    "language": "en",
    "extraction_confidence": 0.90,
    "extraction_method": "rule_based"
  }
}
```

### 3.3 自動生成スクリプトの実装

```python
# scripts/generate_training_data.py
import json
from pathlib import Path
from typing import List, Dict

def extract_from_receipt(
    image_path: str,
    ocr_result: Dict,
    extraction_result: Dict
) -> Dict:
    """既存の抽出結果から学習データを生成"""
    training_sample = {
        "receipt_id": Path(image_path).stem,
        "image_path": image_path,
        "text_lines": [],
        "metadata": {
            "language": extraction_result.get("detected_language", "unknown"),
            "extraction_confidence": extraction_result.get("confidence", 0.0),
            "extraction_method": "rule_based"
        }
    }
    
    # textLinesからラベルを付与
    for idx, line in enumerate(ocr_result.get("text_lines", [])):
        label = infer_label(line, extraction_result)
        training_sample["text_lines"].append({
            "text": line["text"],
            "bounding_box": line.get("bounding_box", []),
            "confidence": line.get("confidence", 0.0),
            "line_index": idx,
            "label": label,
            "extracted_value": extraction_result.get(label.lower(), None)
        })
    
    return training_sample

def infer_label(line: Dict, extraction_result: Dict) -> str:
    """ルールベースの抽出結果からラベルを推論"""
    text = line["text"].lower()
    
    # 抽出結果と照合
    if matches_field(text, extraction_result.get("merchant_name")):
        return "MERCHANT_NAME"
    elif matches_field(text, extraction_result.get("date")):
        return "DATE"
    elif matches_field(text, extraction_result.get("subtotal_amount")):
        return "SUBTOTAL"
    # ... 他のフィールド
    
    return "OTHER"
```

---

## 4. モデル実装アプローチ

### 4.1 フレームワーク選択

#### オプション1: TensorFlow Lite（推奨）
- **メリット**: Flutter統合が容易、オンデバイス推論が高速
- **デプロイ**: `.tflite`モデルをアセットに含める
- **パッケージ**: `tflite_flutter`

#### オプション2: ONNX Runtime
- **メリット**: フレームワーク非依存、最適化が容易
- **デプロイ**: `.onnx`モデルを使用
- **パッケージ**: `onnxruntime` (Dart bindingが必要)

#### オプション3: PyTorch Mobile
- **メリット**: 柔軟なモデル設計
- **デプロイ**: `.ptl`モデルを使用
- **パッケージ**: カスタム実装が必要

### 4.2 モデルアーキテクチャ（TensorFlow/Keras例）

```python
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

def create_receipt_extraction_model(
    vocab_size: int = 10000,
    embedding_dim: int = 128,
    num_labels: int = 12
):
    """レシート抽出用モデル"""
    
    # 入力層
    text_input = keras.Input(shape=(None,), name="text")
    position_input = keras.Input(shape=(4,), name="position")  # x, y, w, h
    confidence_input = keras.Input(shape=(1,), name="confidence")
    
    # テキスト埋め込み
    text_embedding = layers.Embedding(vocab_size, embedding_dim)(text_input)
    text_lstm = layers.Bidirectional(
        layers.LSTM(64, return_sequences=True)
    )(text_embedding)
    text_pooled = layers.GlobalMaxPooling1D()(text_lstm)
    
    # 位置情報の処理
    position_dense = layers.Dense(32, activation="relu")(position_input)
    
    # 特徴量の結合
    combined = layers.Concatenate()([
        text_pooled,
        position_dense,
        confidence_input
    ])
    
    # 分類層
    dense1 = layers.Dense(128, activation="relu")(combined)
    dropout = layers.Dropout(0.3)(dense1)
    dense2 = layers.Dense(64, activation="relu")(dropout)
    output = layers.Dense(
        num_labels,
        activation="softmax",
        name="label"
    )(dense2)
    
    model = keras.Model(
        inputs=[text_input, position_input, confidence_input],
        outputs=output
    )
    
    return model
```

### 4.3 訓練パイプライン

```python
# scripts/train_model.py
import tensorflow as tf
from pathlib import Path
import json

def load_training_data(data_dir: Path) -> tuple:
    """学習データの読み込み"""
    X_text, X_position, X_confidence = [], [], []
    y_labels = []
    
    for json_file in data_dir.glob("*.json"):
        with open(json_file) as f:
            data = json.load(f)
            
        for line in data["text_lines"]:
            X_text.append(tokenize(line["text"]))
            X_position.append(line["bounding_box"])
            X_confidence.append([line["confidence"]])
            y_labels.append(label_to_index(line["label"]))
    
    return (
        (X_text, X_position, X_confidence),
        tf.keras.utils.to_categorical(y_labels)
    )

def train_model():
    """モデルの訓練"""
    model = create_receipt_extraction_model()
    model.compile(
        optimizer="adam",
        loss="categorical_crossentropy",
        metrics=["accuracy"]
    )
    
    X, y = load_training_data(Path("data/training"))
    X_train, X_val, y_train, y_val = train_test_split(X, y, test_size=0.2)
    
    # データ拡張
    train_dataset = create_dataset(X_train, y_train, augment=True)
    val_dataset = create_dataset(X_val, y_val, augment=False)
    
    # 訓練
    history = model.fit(
        train_dataset,
        validation_data=val_dataset,
        epochs=50,
        callbacks=[
            tf.keras.callbacks.EarlyStopping(patience=5),
            tf.keras.callbacks.ModelCheckpoint("models/best_model.h5")
        ]
    )
    
    # TensorFlow Liteに変換
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    
    with open("models/receipt_extractor.tflite", "wb") as f:
        f.write(tflite_model)
    
    print("Model saved to models/receipt_extractor.tflite")
```

---

## 5. Flutterアプリへの統合

### 5.1 パッケージ追加

```yaml
# pubspec.yaml
dependencies:
  tflite_flutter: ^0.10.4
  # または
  # onnxruntime: ^1.0.0
```

### 5.2 ML抽出サービスの実装

```dart
// lib/services/extraction/ml_extraction_service.dart
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../data/models/processing_result.dart';

class MLExtractionService {
  Interpreter? _interpreter;
  final Map<String, int> _labelToIndex = {
    'MERCHANT_NAME': 0,
    'DATE': 1,
    'TIME': 2,
    // ... 他のラベル
  };
  
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('models/receipt_extractor.tflite');
      print('ML model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
    }
  }
  
  Map<String, dynamic> extractFromTextLines(List<TextLine> textLines) {
    if (_interpreter == null) {
      throw Exception('Model not loaded');
    }
    
    final extractedData = <String, dynamic>{};
    
    for (final line in textLines) {
      // 特徴量の準備
      final textFeatures = _tokenize(line.text);
      final positionFeatures = line.boundingBox ?? [0, 0, 0, 0];
      final confidenceFeatures = [line.confidence];
      
      // 推論実行
      final input = [
        textFeatures,
        positionFeatures,
        confidenceFeatures
      ];
      final output = List.filled(_labelToIndex.length, 0.0).reshape([1, _labelToIndex.length]);
      
      _interpreter!.run(input, output);
      
      // 最も確率の高いラベルを取得
      final predictedIndex = output[0].indexOf(output[0].reduce((a, b) => a > b ? a : b));
      final predictedLabel = _labelToIndex.entries
          .firstWhere((e) => e.value == predictedIndex)
          .key;
      
      // 抽出データに追加
      if (predictedLabel != 'OTHER') {
        extractedData[predictedLabel.toLowerCase()] = _extractValue(
          line.text,
          predictedLabel
        );
      }
    }
    
    return extractedData;
  }
  
  List<int> _tokenize(String text) {
    // トークン化の実装
    // 簡易版: 文字列を文字コードに変換
    return text.codeUnits.take(100).toList(); // 最大100文字
  }
  
  dynamic _extractValue(String text, String label) {
    // ラベルに応じた値の抽出
    switch (label) {
      case 'DATE':
        return _parseDate(text);
      case 'SUBTOTAL':
      case 'TOTAL':
      case 'TAX':
        return _parseAmount(text);
      default:
        return text;
    }
  }
}
```

### 5.3 ハイブリッド抽出の実装

```dart
// lib/services/extraction/receipt_parser.dart (修正版)
class ReceiptParser {
  final MLExtractionService _mlService = MLExtractionService();
  final ReceiptParser _ruleBasedParser = ReceiptParser();
  
  Future<ExtractionResult> parseReceiptText({
    required String ocrText,
    List<TextLine>? textLines,
    // ... 他のパラメータ
  }) async {
    // 1. ルールベース抽出を実行
    final ruleBasedResult = await _ruleBasedParser.parseReceiptText(
      ocrText: ocrText,
      textLines: textLines,
    );
    
    // 2. 信頼度が低いフィールドを特定
    final lowConfidenceFields = _identifyLowConfidenceFields(ruleBasedResult);
    
    // 3. ML抽出を実行（必要に応じて）
    if (lowConfidenceFields.isNotEmpty && textLines != null) {
      final mlResult = _mlService.extractFromTextLines(textLines);
      
      // 4. 結果を統合（ML結果で低信頼度フィールドを補完）
      return _mergeResults(ruleBasedResult, mlResult, lowConfidenceFields);
    }
    
    return ruleBasedResult;
  }
}
```

---

## 6. 実装ロードマップ

### Phase 1: データ収集・準備（1-2週間）
- [ ] 既存レシートから学習データを自動生成
- [ ] データ品質の検証
- [ ] データ拡張の実装

### Phase 2: モデル開発（2-3週間）
- [ ] モデルアーキテクチャの設計
- [ ] 訓練パイプラインの実装
- [ ] ハイパーパラメータの調整

### Phase 3: 統合・テスト（1-2週間）
- [ ] Flutterアプリへの統合
- [ ] ハイブリッド抽出の実装
- [ ] パフォーマンステスト

### Phase 4: 改善・最適化（継続的）
- [ ] モデルの再訓練（新しいデータで）
- [ ] モデルの最適化（量子化など）
- [ ] A/Bテストによる評価

---

## 7. 推奨事項

### 7.1 段階的アプローチ
1. **まずはハイブリッド方式を採用**: ルールベースをベースに、MLで補完
2. **データを蓄積**: 実際の使用から学習データを収集
3. **段階的にMLの割合を増やす**: 精度が向上したらMLの信頼度を上げる

### 7.2 データ品質の重要性
- 高品質な教師データが成功の鍵
- ルールベースの高信頼度結果を優先的に使用
- 定期的なデータの見直しとクレンジング

### 7.3 モデルの軽量化
- 量子化（INT8）でモデルサイズを削減
- 不要な層の削除
- モバイル向けの最適化

---

## 8. 参考リソース

- [TensorFlow Lite ガイド](https://www.tensorflow.org/lite)
- [Flutter ML パッケージ](https://pub.dev/packages/tflite_flutter)
- [NER (Named Entity Recognition) チュートリアル](https://huggingface.co/docs/transformers/tasks/token_classification)

---

## 9. 次のステップ

1. **学習データ生成スクリプトの作成**: `scripts/generate_training_data.py`
2. **小規模プロトタイプの開発**: 簡単な分類モデルで概念実証
3. **データセットの構築**: 最低100-200サンプルから開始
4. **ベースラインモデルの訓練**: シンプルなアーキテクチャで開始

