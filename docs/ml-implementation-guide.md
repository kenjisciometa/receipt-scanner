# 機械学習モデル実装ガイド

**作成日**: 2026年1月2日  
**実装ステップバイステップガイド**

---

## ステップ1: 学習データ生成ツールの作成

### 1.1 データ収集スクリプト

```python
# scripts/collect_training_data.py
"""
既存のレシート画像とOCR結果から学習データを自動生成
"""
import json
import sqlite3
from pathlib import Path
from typing import List, Dict, Optional

def collect_from_database(db_path: str, output_dir: Path):
    """データベースから既存の抽出結果を収集"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # レシートデータを取得
    cursor.execute("""
        SELECT id, original_image_path, raw_ocr_text, 
               merchant_name, purchase_date, total_amount,
               subtotal_amount, tax_amount, payment_method,
               currency, detected_language, confidence
        FROM receipts
        WHERE confidence > 0.7  -- 高信頼度のデータのみ
        ORDER BY created_at DESC
        LIMIT 1000
    """)
    
    training_samples = []
    for row in cursor.fetchall():
        sample = create_training_sample(row)
        if sample:
            training_samples.append(sample)
    
    # JSONファイルとして保存
    output_dir.mkdir(parents=True, exist_ok=True)
    for idx, sample in enumerate(training_samples):
        output_path = output_dir / f"sample_{idx:04d}.json"
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(sample, f, ensure_ascii=False, indent=2)
    
    print(f"Generated {len(training_samples)} training samples")
    conn.close()

def create_training_sample(row: tuple) -> Optional[Dict]:
    """データベースの行から学習サンプルを作成"""
    # OCR結果のJSONをパース（textLinesを含む）
    # 抽出結果と照合してラベルを付与
    pass
```

### 1.2 ラベル推論ロジック

```python
# scripts/label_inference.py
"""
textLinesと抽出結果からラベルを自動推論
"""
def infer_labels_for_lines(
    text_lines: List[Dict],
    extraction_result: Dict
) -> List[Dict]:
    """各textLineにラベルを付与"""
    labeled_lines = []
    
    for line in text_lines:
        label = infer_label(line, extraction_result)
        labeled_lines.append({
            **line,
            "label": label,
            "extracted_value": get_extracted_value(label, extraction_result)
        })
    
    return labeled_lines

def infer_label(line: Dict, extraction_result: Dict) -> str:
    """ルールベースでラベルを推論"""
    text = line["text"].lower()
    
    # マーチャント名
    merchant = extraction_result.get("merchant_name", "").lower()
    if merchant and merchant in text:
        return "MERCHANT_NAME"
    
    # 日付
    date = extraction_result.get("date", "")
    if date and date in text:
        return "DATE"
    
    # 金額（位置情報も考慮）
    # Subtotal, Total, Taxの判定
    if "subtotal" in text or "välisumma" in text or "zwischensumme" in text:
        return "SUBTOTAL"
    if "total" in text or "yhteensä" in text or "gesamt" in text:
        return "TOTAL"
    if "vat" in text or "tax" in text or "alv" in text or "mwst" in text:
        return "TAX"
    
    # 支払い方法
    payment = extraction_result.get("payment_method", "").lower()
    if payment and payment in text:
        return "PAYMENT_METHOD"
    
    return "OTHER"
```

---

## ステップ2: モデル訓練環境のセットアップ

### 2.1 必要なパッケージ

```bash
# requirements.txt
tensorflow>=2.13.0
numpy>=1.24.0
pandas>=2.0.0
scikit-learn>=1.3.0
matplotlib>=3.7.0
```

### 2.2 プロジェクト構造

```
ml_receipt_extractor/
├── data/
│   ├── raw/              # 生データ
│   ├── processed/        # 前処理済みデータ
│   └── training/         # 学習データセット
├── models/
│   ├── checkpoints/      # 訓練中のチェックポイント
│   └── exported/         # エクスポートされたモデル
├── scripts/
│   ├── collect_training_data.py
│   ├── train_model.py
│   └── evaluate_model.py
└── notebooks/
    └── exploration.ipynb  # データ探索用
```

---

## ステップ3: モデル実装

### 3.1 特徴量エンジニアリング

```python
# scripts/feature_engineering.py
import numpy as np
from sklearn.preprocessing import StandardScaler, LabelEncoder

class FeatureEngineer:
    def __init__(self):
        self.text_tokenizer = None
        self.position_scaler = StandardScaler()
        self.label_encoder = LabelEncoder()
    
    def prepare_features(self, text_lines: List[Dict]) -> Dict:
        """textLinesから特徴量を準備"""
        texts = [line["text"] for line in text_lines]
        positions = [line["bounding_box"] for line in text_lines]
        confidences = [[line["confidence"]] for line in text_lines]
        
        # テキストのトークン化
        text_features = self._tokenize_texts(texts)
        
        # 位置情報の正規化
        position_features = self.position_scaler.fit_transform(positions)
        
        return {
            "text": text_features,
            "position": position_features,
            "confidence": np.array(confidences)
        }
    
    def _tokenize_texts(self, texts: List[str]) -> np.ndarray:
        """テキストをトークン化"""
        # 簡易版: 文字列を文字コードに変換
        max_length = 100
        tokenized = []
        for text in texts:
            tokens = [ord(c) for c in text[:max_length]]
            tokens += [0] * (max_length - len(tokens))
            tokenized.append(tokens)
        return np.array(tokenized)
```

### 3.2 モデル定義

```python
# scripts/model.py
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

def create_model(
    vocab_size: int = 10000,
    max_text_length: int = 100,
    num_labels: int = 12
):
    """レシート抽出モデル"""
    
    # 入力
    text_input = keras.Input(shape=(max_text_length,), name="text")
    position_input = keras.Input(shape=(4,), name="position")
    confidence_input = keras.Input(shape=(1,), name="confidence")
    
    # テキスト処理
    text_embed = layers.Embedding(vocab_size, 64)(text_input)
    text_lstm = layers.Bidirectional(
        layers.LSTM(32, return_sequences=False)
    )(text_embed)
    
    # 位置情報処理
    position_dense = layers.Dense(16, activation="relu")(position_input)
    
    # 結合
    concat = layers.Concatenate()([
        text_lstm,
        position_dense,
        confidence_input
    ])
    
    # 分類層
    dense1 = layers.Dense(64, activation="relu")(concat)
    dropout = layers.Dropout(0.3)(dense1)
    dense2 = layers.Dense(32, activation="relu")(dropout)
    output = layers.Dense(num_labels, activation="softmax")(dense2)
    
    model = keras.Model(
        inputs=[text_input, position_input, confidence_input],
        outputs=output
    )
    
    return model
```

### 3.3 訓練スクリプト

```python
# scripts/train_model.py
import tensorflow as tf
from pathlib import Path
import json
import numpy as np
from sklearn.model_selection import train_test_split

def load_dataset(data_dir: Path):
    """データセットの読み込み"""
    X_text, X_pos, X_conf = [], [], []
    y = []
    
    label_to_idx = {
        "MERCHANT_NAME": 0, "DATE": 1, "TIME": 2,
        "RECEIPT_NUMBER": 3, "ITEM_NAME": 4, "ITEM_PRICE": 5,
        "SUBTOTAL": 6, "TAX": 7, "TOTAL": 8,
        "PAYMENT_METHOD": 9, "CURRENCY": 10, "OTHER": 11
    }
    
    for json_file in sorted(data_dir.glob("*.json")):
        with open(json_file) as f:
            data = json.load(f)
        
        for line in data["text_lines"]:
            # 特徴量
            text_tokens = [ord(c) for c in line["text"][:100]]
            text_tokens += [0] * (100 - len(text_tokens))
            X_text.append(text_tokens)
            
            bbox = line.get("bounding_box", [0, 0, 0, 0])
            X_pos.append(bbox[:4])
            X_conf.append([line.get("confidence", 0.0)])
            
            # ラベル
            label = line.get("label", "OTHER")
            y.append(label_to_idx.get(label, 11))
    
    return (
        [np.array(X_text), np.array(X_pos), np.array(X_conf)],
        tf.keras.utils.to_categorical(y, num_classes=12)
    )

def main():
    # データ読み込み
    data_dir = Path("data/training")
    X, y = load_dataset(data_dir)
    
    # 訓練/検証分割
    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    # モデル作成
    model = create_model()
    model.compile(
        optimizer="adam",
        loss="categorical_crossentropy",
        metrics=["accuracy", "top_k_categorical_accuracy"]
    )
    
    # 訓練
    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=50,
        batch_size=32,
        callbacks=[
            tf.keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True),
            tf.keras.callbacks.ModelCheckpoint(
                "models/checkpoints/best_model.h5",
                save_best_only=True
            )
        ]
    )
    
    # TensorFlow Liteに変換
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    
    output_path = Path("models/exported/receipt_extractor.tflite")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(tflite_model)
    
    print(f"Model saved to {output_path}")

if __name__ == "__main__":
    main()
```

---

## ステップ4: Flutter統合

### 4.1 モデルファイルの配置

```
flutter_app/
├── assets/
│   └── models/
│       └── receipt_extractor.tflite
```

### 4.2 pubspec.yamlの更新

```yaml
flutter:
  assets:
    - assets/models/
```

### 4.3 ML抽出サービスの実装

```dart
// lib/services/extraction/ml_extraction_service.dart
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../data/models/processing_result.dart';

class MLExtractionService {
  Interpreter? _interpreter;
  bool _isLoaded = false;
  
  final Map<int, String> _indexToLabel = {
    0: 'MERCHANT_NAME',
    1: 'DATE',
    2: 'TIME',
    3: 'RECEIPT_NUMBER',
    4: 'ITEM_NAME',
    5: 'ITEM_PRICE',
    6: 'SUBTOTAL',
    7: 'TAX',
    8: 'TOTAL',
    9: 'PAYMENT_METHOD',
    10: 'CURRENCY',
    11: 'OTHER',
  };
  
  Future<void> loadModel() async {
    if (_isLoaded) return;
    
    try {
      _interpreter = await Interpreter.fromAsset('models/receipt_extractor.tflite');
      _isLoaded = true;
      print('✅ ML model loaded successfully');
    } catch (e) {
      print('❌ Error loading ML model: $e');
      rethrow;
    }
  }
  
  Map<String, dynamic> extract(List<TextLine> textLines) {
    if (!_isLoaded || _interpreter == null) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }
    
    final extractedData = <String, dynamic>{};
    
    for (final line in textLines) {
      // 特徴量の準備
      final textInput = _tokenizeText(line.text);
      final positionInput = line.boundingBox ?? [0.0, 0.0, 0.0, 0.0];
      final confidenceInput = [line.confidence];
      
      // 推論
      final output = List.filled(12, 0.0).reshape([1, 12]);
      _interpreter!.run([
        textInput,
        [positionInput],
        [confidenceInput]
      ], output);
      
      // 最も確率の高いラベル
      final probabilities = output[0] as List<double>;
      final maxIndex = probabilities.indexOf(probabilities.reduce((a, b) => a > b ? a : b));
      final predictedLabel = _indexToLabel[maxIndex]!;
      
      // 信頼度が高い場合のみ抽出
      if (probabilities[maxIndex] > 0.5 && predictedLabel != 'OTHER') {
        final value = _extractValue(line.text, predictedLabel);
        if (value != null) {
          extractedData[_toSnakeCase(predictedLabel)] = value;
        }
      }
    }
    
    return extractedData;
  }
  
  List<List<int>> _tokenizeText(String text) {
    final tokens = <int>[];
    for (int i = 0; i < text.length && i < 100; i++) {
      tokens.add(text.codeUnitAt(i));
    }
    while (tokens.length < 100) {
      tokens.add(0);
    }
    return [tokens];
  }
  
  dynamic _extractValue(String text, String label) {
    // ラベルに応じた値の抽出ロジック
    switch (label) {
      case 'DATE':
        return _parseDate(text);
      case 'SUBTOTAL':
      case 'TOTAL':
      case 'TAX':
        return _parseAmount(text);
      default:
        return text.trim();
    }
  }
  
  String _toSnakeCase(String label) {
    return label.toLowerCase();
  }
}
```

---

## ステップ5: 評価と改善

### 5.1 評価スクリプト

```python
# scripts/evaluate_model.py
def evaluate_model(model_path: str, test_data_dir: Path):
    """モデルの評価"""
    # テストデータの読み込み
    # 推論実行
    # 精度、再現率、F1スコアの計算
    pass
```

### 5.2 A/Bテストの実装

```dart
// ルールベースとMLの結果を比較
final ruleBasedResult = await ruleBasedParser.parse(...);
final mlResult = await mlService.extract(textLines);

// 信頼度に応じて選択
final finalResult = ruleBasedResult.confidence > 0.8
    ? ruleBasedResult
    : mergeResults(ruleBasedResult, mlResult);
```

---

## 次のアクション

1. **学習データ生成スクリプトを作成**: `scripts/collect_training_data.py`
2. **小規模プロトタイプを訓練**: 10-20サンプルで動作確認
3. **Flutter統合の準備**: `tflite_flutter`パッケージの追加
4. **段階的にデータを拡張**: 100 → 500 → 1000サンプル

