# シーケンスラベリングモデル学習ガイド

## 目次
1. [必要なデータ量](#1-必要なデータ量)
2. [言語の扱い方](#2-言語の扱い方)
3. [学習方法](#3-学習方法)
4. [実装手順](#4-実装手順)

---

## 1. 必要なデータ量

### 1.1 最小限のデータ量（プロトタイプ・概念実証）

**推奨データ量：**
- **擬似ラベルデータ（raw）**: 100-200件
- **手動修正データ（verified）**: 20-30件

**理由：**
- シーケンスラベリングは比較的少ないデータでも動作する
- 現状のルールベース抽出が比較的精度が高いため、擬似ラベルの品質が良い
- 20-30件のverified dataで微調整（fine-tuning）が可能

### 1.2 本番レベルのデータ量（推奨）

**推奨データ量：**
- **擬似ラベルデータ（raw）**: 500-1000件
- **手動修正データ（verified）**: 100-200件

**理由：**
- 多様なレシートフォーマットに対応
- OCRエラーやレイアウトのバリエーションをカバー
- より高い精度と汎用性を実現

### 1.3 データの質とバランス

**重要なポイント：**

1. **多様性の確保**
   - 異なるレシートフォーマット（テーブル有無、レイアウトの違い）
   - 異なる店舗タイプ（スーパーマーケット、レストラン、ガソリンスタンドなど）
   - 異なるOCR品質（高品質、中品質、低品質）

2. **ラベルのバランス**
   - 各ラベル（TOTAL, SUBTOTAL, TAX, DATE, MERCHANT_NAME, ITEM_NAME, ITEM_PRICEなど）が均等に含まれる
   - 特に重要なラベル（TOTAL, DATE）は多めに含める

3. **verified dataの優先順位**
   - ルールベースで誤検出が多いケースを優先的に修正
   - 複雑なレイアウトのレシート/領収書を優先的に修正
   - レシートと領収書の両方から多様なケースを含める

### 1.4 段階的なデータ収集戦略

**Phase 1: プロトタイプ（1-2週間）**
- 擬似ラベル: 50-100件（レシート60-70%、領収書30-40%）
- Verified: 10-15件（レシート7-10件、領収書3-5件）
- 目標: 基本的な動作確認（レシートと領収書の両方で）

**Phase 2: 改善（2-4週間）**
- 擬似ラベル: 200-300件（レシート120-210件、領収書60-120件）
- Verified: 30-50件（レシート18-35件、領収書9-20件）
- 目標: 主要なエラーケースの改善（レシートと領収書の両方で）

**Phase 3: 本番準備（1-2ヶ月）**
- 擬似ラベル: 500-1000件（レシート300-700件、領収書150-400件）
- Verified: 100-200件（レシート60-140件、領収書30-80件）
- 目標: 本番レベルの精度達成（レシートと領収書の両方で）

---

## 2. 言語の扱い方

### 2.1 推奨アプローチ：多言語混合学習

**現状の実装に最適な方法：多言語を混合して学習**

**理由：**

1. **現状の実装状況**
   - 7言語をサポート（en, fi, sv, fr, de, it, es）
   - 多言語キーワードシステムが実装済み
   - 位置情報（bounding box）ベースの特徴量を使用

2. **位置情報ベースの特徴量の利点**
   - 言語に依存しない特徴量（x_center, y_center, is_right_side, is_bottom_areaなど）
   - テキスト内容よりも位置情報が重要
   - 多言語でも共通のパターン（TOTALは下部、金額は右側など）

3. **実用的な利点**
   - 1つのモデルで全言語に対応可能
   - モデルサイズが小さい（TFLiteでオンデバイス推論に適している）
   - メンテナンスが容易

### 2.2 多言語混合学習の実装方法

**データの構成：**

```
training_data/
├── raw/
│   ├── receipt_en_*.json      # 英語レシート
│   ├── receipt_fi_*.json       # フィンランド語レシート
│   ├── receipt_sv_*.json       # スウェーデン語レシート
│   ├── receipt_fr_*.json       # フランス語レシート
│   ├── receipt_de_*.json       # ドイツ語レシート
│   ├── receipt_it_*.json       # イタリア語レシート
│   ├── receipt_es_*.json       # スペイン語レシート
│   ├── invoice_en_*.json       # 英語領収書
│   ├── invoice_fi_*.json       # フィンランド語領収書
│   └── ...                     # 他の言語の領収書
└── verified/
    ├── verified_receipt_en_*.json
    ├── verified_receipt_fi_*.json
    ├── verified_invoice_en_*.json
    ├── verified_invoice_fi_*.json
    └── ...
```

**言語のバランス：**
- 各言語から均等にデータを収集（理想的）
- 実際の使用頻度に応じて重み付け（英語を多めに、など）

**特徴量の設計：**
- 言語固有の特徴量は最小限に（テキスト内容は使わない）
- 位置情報、数値パターン、キーワードマッチ（多言語対応）を重視

### 2.3 英語統一学習のデメリット

**英語統一学習は推奨しない理由：**

1. **実用性の問題**
   - 実際の使用環境が多言語
   - 英語のみのモデルでは他の言語で精度が低下

2. **特徴量の有効活用**
   - 現状の実装は位置情報ベース
   - 言語に依存しない特徴量を活用すべき

3. **メンテナンスの複雑さ**
   - 言語ごとにモデルを管理する必要がある
   - モデルサイズが増加

### 2.4 ハイブリッドアプローチ（オプション）

**将来的な拡張案：言語識別 + 言語固有の微調整**

1. **言語識別モデル**（軽量）
   - レシートの言語を自動識別
   - 必要に応じて言語固有の微調整モデルを適用

2. **言語固有の微調整**
   - ベースモデル（多言語）を学習
   - 各言語で少量のデータで微調整（fine-tuning）

**現時点では推奨しない理由：**
- 複雑さが増す
- 現状の多言語混合学習で十分な精度が期待できる
- 必要に応じて後から追加可能

---

## 3. 学習方法

### 3.1 シーケンスラベリングモデルの選択

**推奨モデル：BiLSTM-CRF または Transformer（軽量版）**

**理由：**
- シーケンス（行の順序）を考慮できる
- 位置情報とテキスト特徴量の両方を活用
- TFLiteに変換可能

**モデルアーキテクチャ：**

```
Input: [batch_size, sequence_length, feature_dim]
  ↓
BiLSTM Layer (128-256 units)
  ↓
Dense Layer (num_labels)
  ↓
CRF Layer (optional, 精度向上)
  ↓
Output: [batch_size, sequence_length, num_labels]
```

**注意点：**
- `sequence_length`はレシートと領収書の両方に対応できる長さに設定（推奨: 50行）
- レシート: 10-30行、領収書: 20-50行を考慮
- 短いシーケンスはパディング、長いシーケンスはトリミング

### 3.2 学習の流れ

**Step 1: データ前処理**

```python
# 1. JSONファイルの読み込み（レシートと領収書の両方）
# 2. textLinesの特徴量ベクトルを抽出
# 3. ラベルのエンコーディング（BIO形式推奨）
# 4. シーケンス長の正規化（パディング/トリミング）
#    - レシート: 10-30行 → 50行にパディング
#    - 領収書: 20-50行 → 50行にトリミングまたはパディング
# 5. レシートと領収書の比率を調整（60-70%:30-40%）
```
<｜tool▁calls▁begin｜><｜tool▁call▁begin｜>
read_file

**Step 2: 擬似ラベルでの事前学習**

```python
# 1. 擬似ラベルデータ（raw）で学習
# 2. 学習率: 0.001-0.01
# 3. エポック数: 10-20
# 4. バッチサイズ: 16-32
```

**Step 3: Verified dataでの微調整**

```python
# 1. 事前学習済みモデルを読み込み
# 2. Verified dataで微調整（fine-tuning）
# 3. 学習率: 0.0001-0.001（より小さい）
# 4. エポック数: 5-10
# 5. Early stoppingで過学習を防止
```

### 3.3 ラベル設計（BIO形式推奨）

**BIO形式の例：**

```
O: その他
B-TOTAL: Totalの開始
I-TOTAL: Totalの継続
B-SUBTOTAL: Subtotalの開始
I-SUBTOTAL: Subtotalの継続
B-TAX: Taxの開始
I-TAX: Taxの継続
B-DATE: Dateの開始
I-DATE: Dateの継続
B-MERCHANT_NAME: Merchant名の開始
I-MERCHANT_NAME: Merchant名の継続
B-ITEM_NAME: アイテム名の開始
I-ITEM_NAME: アイテム名の継続
B-ITEM_PRICE: アイテム価格の開始
I-ITEM_PRICE: アイテム価格の継続
```

**理由：**
- 標準的なNER（Named Entity Recognition）形式
- 複数行にまたがるエンティティに対応可能
- 多くのライブラリでサポート

---

#### BIO形式の詳細解説

**なぜ開始（B-）と継続（I-）ラベルが必要なのか？**

レシートや領収書では、1つの情報が複数行にまたがることがよくあります。例えば：

```
行1: "SUPER"          → B-MERCHANT_NAME（店舗名の開始）
行2: "MARKET"         → I-MERCHANT_NAME（店舗名の継続）
行3: "123 Main St"    → I-MERCHANT_NAME（店舗名の継続）
行4: ""               → O（その他）
行5: "Total: 100.00"  → B-TOTAL（Totalの開始）
```

もし開始と継続の区別がなければ：
- モデルは「MARKET」が新しい店舗名の開始なのか、前の行の継続なのか判断できない
- エンティティの境界が曖昧になり、複数のエンティティが混在する場合に誤検出が増える

**BIO形式の使用例：**

実際のレシートのラベリング例：

```
行番号 | テキスト内容          | ラベル
-------|---------------------|------------------
1      | "ABC"                | B-MERCHANT_NAME
2      | "SUPERMARKET"        | I-MERCHANT_NAME
3      | ""                   | O
4      | "2024-01-15"         | B-DATE
5      | ""                   | O
6      | "Apple"              | B-ITEM_NAME
7      | "1.50"               | B-ITEM_PRICE
8      | "Banana"             | B-ITEM_NAME
9      | "2.00"               | B-ITEM_PRICE
10     | ""                   | O
11     | "Subtotal: 3.50"     | B-SUBTOTAL
12     | "Tax: 0.35"          | B-TAX
13     | "Total: 3.85"        | B-TOTAL
```

**BIO形式の利点：**

1. **エンティティの境界が明確**
   - B-でエンティティの開始位置を明示
   - I-で同じエンティティの継続を表現
   - Oでエンティティ外を表現

2. **複数エンティティの区別が容易**
   - 連続する同じタイプのエンティティ（例：複数のITEM_NAME）を区別可能
   - 例：「Apple」と「Banana」は両方B-ITEM_NAMEで、別々のエンティティとして認識

3. **モデルの学習が効率的**
   - シーケンスラベリングモデル（BiLSTMなど）が前後の文脈を考慮してラベルを予測
   - B-の後はI-またはOが続く、という制約を学習できる

4. **後処理が簡単**
   - B-から次のB-またはOまでの範囲を1つのエンティティとして抽出可能
   - エンティティの結合処理が直感的

**モデルでの使用の流れ：**

1. **入力**: 各行の特徴量ベクトル（位置情報、数値パターンなど）
2. **処理**: BiLSTMが前後の行の情報を考慮して各行にラベルを予測
3. **出力**: 各行にB-、I-、Oのいずれかのラベルが付与される
4. **後処理**: B-から次のB-またはOまでの範囲を1つのエンティティとして抽出

**注意点：**

- 通常、1行で完結する情報（例：「Total: 100.00」）はB-のみで、I-は不要
- ただし、BIO形式では開始と継続を区別するため、I-も定義しておく必要がある
- 実際の使用では、B-の後にI-が続かない場合（1行完結）も正常な動作

### 3.4 評価指標

**主要な評価指標：**

1. **Token-level Accuracy**
   - 各トークン（行）のラベル予測精度

2. **Entity-level F1 Score**
   - エンティティ全体の検出精度
   - より実用的な指標

3. **Per-label F1 Score**
   - 各ラベル（TOTAL, SUBTOTAL, TAXなど）ごとの精度
   - どのラベルが苦手か把握

4. **Consistency Score**
   - 抽出された金額の整合性（total == subtotal + tax）
   - 実用性を測る重要な指標
   - レシートと領収書の両方で評価

5. **Document Type Performance**
   - レシートと領収書で別々に評価
   - 各タイプでの精度を確認

### 3.5 学習のベストプラクティス

**1. データ拡張（Data Augmentation）**

```python
# 位置情報のノイズ追加（±5%）
# テキストの部分的な置換（OCRエラーをシミュレート）
# シーケンスの順序変更（限定的）
```

**2. クラス不均衡の対策**

```python
# 重要なラベル（TOTAL, DATE）に重み付け
# Focal Lossの使用
# サンプリングの調整
```

**3. 過学習の防止**

```python
# Dropout (0.3-0.5)
# Early stopping
# L2正則化
# クロスバリデーション
```

---

## 4. 実装手順

### 4.1 Python環境のセットアップ

**必要なライブラリ：**

```bash
pip install tensorflow>=2.10.0
pip install tensorflow-addons  # CRF layer用
pip install numpy
pip install pandas
pip install scikit-learn
pip install matplotlib
pip install tqdm
```

### 4.2 データローダーの実装

**`data_loader.py`の例：**

```python
import json
import numpy as np
from typing import List, Dict, Tuple

def load_training_data(data_dir: str, is_verified: bool = False) -> List[Dict]:
    """訓練データを読み込む"""
    data = []
    pattern = "verified_*.json" if is_verified else "receipt_*.json"
    
    for file_path in glob.glob(f"{data_dir}/{pattern}"):
        with open(file_path, 'r', encoding='utf-8') as f:
            data.append(json.load(f))
    
    return data

def extract_features_and_labels(data: List[Dict]) -> Tuple[np.ndarray, np.ndarray]:
    """特徴量とラベルを抽出"""
    features = []
    labels = []
    
    for receipt in data:
        text_lines = receipt['text_lines']
        
        # 特徴量ベクトルを抽出
        feature_vectors = [line['feature_vector'] for line in text_lines]
        features.append(feature_vectors)
        
        # ラベルを抽出
        label_list = [line['label'] for line in text_lines]
        labels.append(label_list)
    
    # パディング/トリミング
    max_length = 50  # 最大シーケンス長
    features = pad_sequences(features, maxlen=max_length)
    labels = pad_sequences(labels, maxlen=max_length)
    
    return np.array(features), np.array(labels)
```

### 4.3 モデルの実装

**`model.py`の例：**

```python
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import tensorflow_addons as tfa

def create_bilstm_crf_model(
    feature_dim: int,
    num_labels: int,
    max_sequence_length: int,
    lstm_units: int = 128
) -> keras.Model:
    """BiLSTM-CRFモデルを作成"""
    
    inputs = keras.Input(shape=(max_sequence_length, feature_dim))
    
    # BiLSTM層
    lstm = layers.Bidirectional(
        layers.LSTM(lstm_units, return_sequences=True)
    )(inputs)
    lstm = layers.Dropout(0.3)(lstm)
    
    # Dense層
    dense = layers.Dense(num_labels)(lstm)
    
    # CRF層（オプション）
    crf = tfa.layers.CRF(num_labels)
    outputs = crf(dense)
    
    model = keras.Model(inputs, outputs)
    return model
```

### 4.4 学習スクリプト

**`train.py`の例：**

```python
from data_loader import load_training_data, extract_features_and_labels
from model import create_bilstm_crf_model

# 1. データの読み込み
raw_data = load_training_data('training_data/raw', is_verified=False)
verified_data = load_training_data('training_data/verified', is_verified=True)

# 2. 特徴量とラベルの抽出
X_raw, y_raw = extract_features_and_labels(raw_data)
X_verified, y_verified = extract_features_and_labels(verified_data)

# 3. モデルの作成
model = create_bilstm_crf_model(
    feature_dim=20,  # feature_vectorの次元
    num_labels=15,   # ラベルの数
    max_sequence_length=50
)

# 4. 事前学習（擬似ラベル）
model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=0.001),
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
)

model.fit(
    X_raw, y_raw,
    epochs=20,
    batch_size=32,
    validation_split=0.2
)

# 5. 微調整（verified data）
model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=0.0001),
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
)

model.fit(
    X_verified, y_verified,
    epochs=10,
    batch_size=16,
    validation_split=0.2,
    callbacks=[keras.callbacks.EarlyStopping(patience=3)]
)

# 6. モデルの保存
model.save('receipt_ner_model.h5')

# 7. TFLiteへの変換
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
with open('receipt_ner_model.tflite', 'wb') as f:
    f.write(tflite_model)
```

### 4.5 推論の実装（Flutter側）

**`ml_inference_service.dart`の例：**

```dart
import 'package:tflite_flutter/tflite_flutter.dart';

class MLInferenceService {
  late Interpreter _interpreter;
  
  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('receipt_ner_model.tflite');
  }
  
  List<String> predictLabels(List<List<double>> featureVectors) {
    // 入力テンソルの準備
    final input = [featureVectors];
    final output = List.filled(featureVectors.length, 0).reshape([1, featureVectors.length, numLabels]);
    
    // 推論
    _interpreter.run(input, output);
    
    // ラベルのデコード
    final labels = output[0].map((probabilities) {
      return _decodeLabel(probabilities);
    }).toList();
    
    return labels;
  }
}
```

---

## 5. まとめ

### 5.1 推奨アプローチ

1. **データ量**: 擬似ラベル500-1000件、Verified 100-200件（レシート60-70%、領収書30-40%）
2. **言語**: 多言語混合学習（現状の実装に最適）
3. **ドキュメントタイプ**: レシートと領収書の混合学習（推奨比率: 60-70%:30-40%）
4. **モデル**: BiLSTM-CRF（軽量でTFLite変換可能、max_sequence_length=50でレシートと領収書の両方に対応）
5. **学習**: 擬似ラベルで事前学習 → Verified dataで微調整

### 5.2 次のステップ

1. **データ収集の開始**
   - アプリを使用して擬似ラベルデータを収集（レシートと領収書の両方）
   - 重要なケースを手動で修正してverified dataを作成
   - レシートと領収書の比率を維持（60-70%:30-40%）

2. **Python環境のセットアップ**
   - データローダーとモデルの実装（レシートと領収書の混合対応）
   - 小規模データで動作確認（レシートと領収書の両方で）

3. **段階的な改善**
   - プロトタイプ → 改善 → 本番準備
   - 継続的なデータ収集とモデルの改善
   - レシートと領収書の両方で評価と改善

### 5.3 注意点

- **データの質が重要**: 量よりも質を重視
- **継続的な改善**: 一度学習したら終わりではなく、継続的にデータを収集して改善
- **実用性の確認**: 精度だけでなく、整合性スコアも重要
- **モデルサイズ**: TFLiteでオンデバイス推論するため、モデルサイズに注意

---

## 参考資料

- [Sequence_Labeling_from_textLines.md](./Sequence_Labeling_from_textLines.md)
- [ml-model-proposal.md](./ml-model-proposal.md)
- TensorFlow Lite公式ドキュメント: https://www.tensorflow.org/lite
- BiLSTM-CRF論文: https://arxiv.org/abs/1603.01360

