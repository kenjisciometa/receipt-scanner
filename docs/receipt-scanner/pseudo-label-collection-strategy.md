# 擬似ラベルの効率的な収集戦略

## 目次
1. [概要](#1-概要)
2. [効率的な収集方法](#2-効率的な収集方法)
3. [AIによるデータ拡張](#3-aiによるデータ拡張)
4. [実装方法](#4-実装方法)
5. [品質管理](#5-品質管理)

---

## 1. 概要

### 1.1 擬似ラベルとは

擬似ラベル（Pseudo-label）は、ルールベースの抽出結果から自動的に生成されるラベルです。現在の実装では、`TrainingDataCollector`が以下の情報から擬似ラベルを生成しています：

- OCR結果（`textLines`、位置情報、信頼度）
- 抽出結果（merchant_name, date, total_amount, subtotal_amount, tax_amountなど）
- 特徴量（位置情報、テキスト特徴量）

### 1.2 収集の課題

**現状の課題：**
- 実際のレシートを1枚ずつ処理する必要がある
- OCR品質が低いレシートは擬似ラベルの品質も低い
- 多様なレシートフォーマットをカバーするには大量のデータが必要
- 手動でのデータ収集は時間がかかる

**解決策：**
- 少数の高品質なレシートから、AIでバリエーションを生成
- データ拡張（Data Augmentation）を活用
- 半自動的なデータ生成パイプライン

---

## 2. 効率的な収集方法

### 2.1 段階的アプローチ

**Phase 1: 高品質なベースデータの収集（15-25件）**

1. **多様なドキュメントタイプを選択**
   - **レシート（小売店向け）**: 10-15件
     - スーパーマケット（テーブル形式）
     - レストラン（アイテムリスト形式）
     - ガソリンスタンド（シンプル形式）
     - 小売店（複雑なレイアウト）
   - **領収書（BtoB向け）**: 5-10件
     - サービス業（コンサルティング、ソフトウェアライセンスなど）
     - 製造業（部品、材料など）
     - 複雑なテーブル形式の領収書

2. **各言語から2-3件ずつ（レシートと領収書の両方を含む）**
   - 英語: レシート3件 + 領収書2件
   - フィンランド語: レシート2件 + 領収書1件
   - スウェーデン語: レシート2件 + 領収書1件
   - フランス語: レシート2件 + 領収書1件
   - ドイツ語: レシート2件 + 領収書1件
   - イタリア語: レシート2件 + 領収書1件
   - スペイン語: レシート2件 + 領収書1件

3. **手動でverified dataを作成**
   - 各レシート/領収書を手動で修正
   - ラベルの精度を1.0に設定
   - これが「ゴールドスタンダード」データになる
   - **重要**: レシートと領収書の比率は60-70%:30-40%を維持

### 2.2 データ拡張による増量

**ベースデータから10-20倍に増量可能**

以下の方法で、1件のレシートから10-20件のバリエーションを生成：

1. **OCRエラーのシミュレーション**
2. **レイアウトのバリエーション**
3. **テキストの置換**
4. **位置情報のノイズ追加**

---

## 3. AIによるデータ拡張

### 3.1 実現可能性：**高い**

**理由：**
- 現在の実装は位置情報ベースの特徴量を使用
- テキスト内容よりも位置情報が重要
- OCRエラーやレイアウトのバリエーションをシミュレート可能

### 3.2 データ拡張の方法

#### 3.2.1 OCRエラーのシミュレーション

**よくあるOCRエラー：**
- 文字の誤認識（`0` → `O`, `1` → `I`, `8` → `B`など）
- 数字の誤認識（`5` → `S`, `0` → `O`など）
- スペースの欠落・追加
- 改行の誤認識

**実装例：**

```python
def simulate_ocr_errors(text: str, error_rate: float = 0.05) -> str:
    """OCRエラーをシミュレート"""
    import random
    
    # よくあるOCRエラーのマッピング
    ocr_error_map = {
        '0': ['O', 'o', 'D'],
        '1': ['I', 'l', '|'],
        '5': ['S', 's'],
        '8': ['B', 'b'],
        'O': ['0', 'o'],
        'I': ['1', 'l', '|'],
        'S': ['5', 's'],
        'B': ['8', 'b'],
    }
    
    result = list(text)
    for i, char in enumerate(result):
        if random.random() < error_rate and char in ocr_error_map:
            # エラーを適用
            result[i] = random.choice(ocr_error_map[char])
    
    return ''.join(result)
```

#### 3.2.2 レイアウトのバリエーション

**位置情報の調整：**

```python
def augment_bounding_box(bbox: List[float], noise_level: float = 0.05) -> List[float]:
    """バウンディングボックスにノイズを追加"""
    import random
    
    x, y, w, h = bbox
    
    # 位置にノイズを追加（±5%）
    x_noise = random.uniform(-noise_level, noise_level) * w
    y_noise = random.uniform(-noise_level, noise_level) * h
    w_noise = random.uniform(-noise_level, noise_level) * w
    h_noise = random.uniform(-noise_level, noise_level) * h
    
    return [x + x_noise, y + y_noise, w + w_noise, h + h_noise]
```

#### 3.2.3 テキストの置換

**店名、金額、日付の置換：**

```python
def replace_merchant_name(text: str, merchant_name: str, new_merchant: str) -> str:
    """店名を置換"""
    return text.replace(merchant_name, new_merchant)

def replace_amounts(text: str, amount_map: Dict[str, str]) -> str:
    """金額を置換（整合性を保つ）"""
    result = text
    for old_amount, new_amount in amount_map.items():
        result = result.replace(old_amount, new_amount)
    return result

def replace_date(text: str, old_date: str, new_date: str) -> str:
    """日付を置換"""
    return text.replace(old_date, new_date)
```

#### 3.2.4 シーケンスの順序変更（限定的）

**アイテムリストの順序変更：**

```python
def shuffle_items(text_lines: List[Dict], item_start_idx: int, item_end_idx: int) -> List[Dict]:
    """アイテムリストの順序を変更（整合性を保つ）"""
    items = text_lines[item_start_idx:item_end_idx]
    header = text_lines[:item_start_idx]
    footer = text_lines[item_end_idx:]
    
    import random
    random.shuffle(items)
    
    return header + items + footer
```

### 3.3 統合的なデータ拡張パイプライン

**`data_augmentation.py`の例：**

```python
import json
import random
from typing import List, Dict
import copy

class ReceiptDataAugmenter:
    """レシートデータの拡張"""
    
    def __init__(self, ocr_error_rate: float = 0.05, bbox_noise: float = 0.05):
        self.ocr_error_rate = ocr_error_rate
        self.bbox_noise = bbox_noise
    
    def augment_receipt(self, receipt_data: Dict, num_variations: int = 10) -> List[Dict]:
        """1件のレシートから複数のバリエーションを生成"""
        variations = []
        
        for i in range(num_variations):
            variation = copy.deepcopy(receipt_data)
            
            # 1. OCRエラーのシミュレーション
            variation = self._simulate_ocr_errors(variation)
            
            # 2. 位置情報のノイズ追加
            variation = self._add_bbox_noise(variation)
            
            # 3. テキストの置換（店名、金額、日付）
            variation = self._replace_text_fields(variation, i)
            
            # 4. アイテムリストの順序変更（限定的）
            if random.random() < 0.3:  # 30%の確率で適用
                variation = self._shuffle_items(variation)
            
            # 5. メタデータの更新
            variation['receipt_id'] = f"{variation['receipt_id']}_aug_{i}"
            variation['metadata']['is_augmented'] = True
            variation['metadata']['augmentation_id'] = i
            variation['metadata']['original_receipt_id'] = receipt_data['receipt_id']
            
            variations.append(variation)
        
        return variations
    
    def _simulate_ocr_errors(self, receipt: Dict) -> Dict:
        """OCRエラーをシミュレート"""
        for line in receipt['text_lines']:
            original_text = line['text']
            # OCRエラーを適用（金額や日付は除外）
            if not self._is_amount_or_date(original_text):
                line['text'] = self._apply_ocr_errors(original_text)
                # 信頼度を少し下げる
                line['confidence'] = max(0.7, line['confidence'] - 0.1)
        
        return receipt
    
    def _add_bbox_noise(self, receipt: Dict) -> Dict:
        """位置情報にノイズを追加"""
        for line in receipt['text_lines']:
            if 'bounding_box' in line and len(line['bounding_box']) == 4:
                line['bounding_box'] = self._add_noise_to_bbox(
                    line['bounding_box'], 
                    self.bbox_noise
                )
        
        return receipt
    
    def _replace_text_fields(self, receipt: Dict, variation_id: int) -> Dict:
        """テキストフィールドを置換（整合性を保つ）"""
        # 店名の置換（例：SUPERMARKET ABC → MARKET XYZ）
        merchant_name = receipt['extraction_result']['extracted_data'].get('merchant_name')
        if merchant_name:
            new_merchant = self._generate_merchant_name(merchant_name, variation_id)
            # text_lines内の店名を置換
            for line in receipt['text_lines']:
                if merchant_name.lower() in line['text'].lower():
                    line['text'] = line['text'].replace(merchant_name, new_merchant)
            # extraction_resultも更新
            receipt['extraction_result']['extracted_data']['merchant_name'] = new_merchant
        
        # 金額の置換（整合性を保つ：total = subtotal + tax）
        # 注意：金額の置換は整合性を保つ必要がある
        # ここでは簡単な例を示す
        amounts = self._generate_consistent_amounts(variation_id)
        receipt = self._replace_amounts(receipt, amounts)
        
        return receipt
    
    def _shuffle_items(self, receipt: Dict) -> Dict:
        """アイテムリストの順序を変更"""
        # アイテムセクションを特定
        item_start = None
        item_end = None
        
        for i, line in enumerate(receipt['text_lines']):
            if line['label'] == 'ITEM_NAME' and item_start is None:
                item_start = i
            elif item_start is not None and line['label'] not in ['ITEM_NAME', 'ITEM_PRICE']:
                item_end = i
                break
        
        if item_start is not None and item_end is not None:
            # アイテムをシャッフル
            items = receipt['text_lines'][item_start:item_end]
            random.shuffle(items)
            receipt['text_lines'] = (
                receipt['text_lines'][:item_start] + 
                items + 
                receipt['text_lines'][item_end:]
            )
        
        return receipt
    
    def _apply_ocr_errors(self, text: str) -> str:
        """OCRエラーを適用"""
        ocr_error_map = {
            '0': ['O', 'o'],
            '1': ['I', 'l'],
            '5': ['S', 's'],
            '8': ['B', 'b'],
            'O': ['0'],
            'I': ['1'],
            'S': ['5'],
            'B': ['8'],
        }
        
        result = list(text)
        for i, char in enumerate(result):
            if random.random() < self.ocr_error_rate and char in ocr_error_map:
                result[i] = random.choice(ocr_error_map[char])
        
        return ''.join(result)
    
    def _add_noise_to_bbox(self, bbox: List[float], noise_level: float) -> List[float]:
        """バウンディングボックスにノイズを追加"""
        x, y, w, h = bbox
        x_noise = random.uniform(-noise_level, noise_level) * w
        y_noise = random.uniform(-noise_level, noise_level) * h
        w_noise = random.uniform(-noise_level, noise_level) * w
        h_noise = random.uniform(-noise_level, noise_level) * h
        
        return [x + x_noise, y + y_noise, w + w_noise, h + h_noise]
    
    def _is_amount_or_date(self, text: str) -> bool:
        """金額や日付かどうかを判定"""
        import re
        # 金額パターン
        amount_pattern = r'[\d,.\s]+[€$£kr]|[\d,.\s]+%'
        # 日付パターン
        date_pattern = r'\d{1,2}[.\/-]\d{1,2}[.\/-]\d{2,4}|\d{4}[.\/-]\d{1,2}[.\/-]\d{1,2}'
        
        return bool(re.search(amount_pattern, text) or re.search(date_pattern, text))
    
    def _generate_merchant_name(self, original: str, variation_id: int) -> str:
        """店名を生成（簡単な例）"""
        # 実際の実装では、より洗練された方法を使用
        merchants = [
            'SUPERMARKET ABC', 'MARKET XYZ', 'STORE 123',
            'SHOP DEF', 'MART GHI', 'STORE JKL'
        ]
        return merchants[variation_id % len(merchants)]
    
    def _generate_consistent_amounts(self, variation_id: int) -> Dict[str, float]:
        """整合性のある金額を生成"""
        # 簡単な例：variation_idに基づいて金額を生成
        base_subtotal = 10.0 + (variation_id * 2.5)
        base_tax = base_subtotal * 0.24
        base_total = base_subtotal + base_tax
        
        return {
            'subtotal': round(base_subtotal, 2),
            'tax': round(base_tax, 2),
            'total': round(base_total, 2)
        }
    
    def _replace_amounts(self, receipt: Dict, amounts: Dict[str, float]) -> Dict:
        """金額を置換（整合性を保つ）"""
        # 実装は複雑になるため、簡略化
        # 実際には、text_lines内の金額を検出して置換する必要がある
        return receipt
```

### 3.4 使用例

```python
# 1. ベースデータ（verified data）を読み込む
with open('training_data/verified/verified_receipt_001.json', 'r') as f:
    base_receipt = json.load(f)

# 2. データ拡張を実行
augmenter = ReceiptDataAugmenter(
    ocr_error_rate=0.05,
    bbox_noise=0.05
)

variations = augmenter.augment_receipt(base_receipt, num_variations=15)

# 3. 拡張データを保存
for i, variation in enumerate(variations):
    output_path = f'training_data/augmented/receipt_aug_{i:03d}.json'
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(variation, f, ensure_ascii=False, indent=2)
```

---

## 4. 実装方法

### 4.1 Pythonスクリプトの作成

**`scripts/augment_training_data.py`の例：**

```python
#!/usr/bin/env python3
"""
Training data augmentation script
Usage: python augment_training_data.py --input-dir training_data/verified --output-dir training_data/augmented --num-variations 10
"""

import argparse
import json
import os
from pathlib import Path
from data_augmentation import ReceiptDataAugmenter

def main():
    parser = argparse.ArgumentParser(description='Augment training data')
    parser.add_argument('--input-dir', required=True, help='Input directory (verified data)')
    parser.add_argument('--output-dir', required=True, help='Output directory (augmented data)')
    parser.add_argument('--num-variations', type=int, default=10, help='Number of variations per receipt')
    parser.add_argument('--ocr-error-rate', type=float, default=0.05, help='OCR error rate')
    parser.add_argument('--bbox-noise', type=float, default=0.05, help='Bounding box noise level')
    
    args = parser.parse_args()
    
    # 出力ディレクトリを作成
    os.makedirs(args.output_dir, exist_ok=True)
    
    # データ拡張器を初期化
    augmenter = ReceiptDataAugmenter(
        ocr_error_rate=args.ocr_error_rate,
        bbox_noise=args.bbox_noise
    )
    
    # 入力ファイルを処理
    input_files = list(Path(args.input_dir).glob('verified_*.json'))
    
    print(f"Found {len(input_files)} verified receipts")
    
    total_generated = 0
    for input_file in input_files:
        print(f"Processing {input_file.name}...")
        
        # レシートデータを読み込む
        with open(input_file, 'r', encoding='utf-8') as f:
            receipt_data = json.load(f)
        
        # データ拡張を実行
        variations = augmenter.augment_receipt(
            receipt_data, 
            num_variations=args.num_variations
        )
        
        # 拡張データを保存
        for i, variation in enumerate(variations):
            output_file = Path(args.output_dir) / f"augmented_{input_file.stem}_{i:03d}.json"
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(variation, f, ensure_ascii=False, indent=2)
            
            total_generated += 1
        
        print(f"  Generated {len(variations)} variations")
    
    print(f"\nTotal generated: {total_generated} augmented receipts")

if __name__ == '__main__':
    main()
```

### 4.2 Flutter側での自動収集

**現在の実装を拡張：**

```dart
// preview_screen.dart の拡張
// バッチモードで複数のレシートを処理
Future<void> _processBatchReceipts(List<String> imagePaths) async {
  for (final imagePath in imagePaths) {
    // 通常の処理フロー
    final result = await _processReceipt(imagePath);
    
    // 高品質なデータのみ保存
    if (result.confidence >= 0.8) {
      await _trainingDataCollector.saveTrainingData(...);
    }
  }
}
```

---

## 5. 品質管理

### 5.1 データ拡張の品質チェック

**必須チェック：**

1. **整合性の確認**
   - `total == subtotal + tax` が維持されているか
   - 日付フォーマットが有効か
   - 金額が正の数か

2. **位置情報の妥当性**
   - バウンディングボックスが画像範囲内か
   - 行の順序が論理的か（上から下へ）

3. **ラベルの妥当性**
   - 擬似ラベルが正しいか
   - 重要なフィールド（TOTAL, DATE）が欠落していないか

### 5.2 品質フィルタリング

```python
def validate_augmented_data(receipt: Dict) -> bool:
    """拡張データの品質をチェック"""
    
    # 1. 整合性チェック
    extracted = receipt['extraction_result']['extracted_data']
    subtotal = extracted.get('subtotal_amount', 0)
    tax = extracted.get('tax_amount', 0)
    total = extracted.get('total_amount', 0)
    
    if abs(total - (subtotal + tax)) > 0.01:  # 許容誤差
        return False
    
    # 2. 必須フィールドの確認
    required_fields = ['merchant_name', 'date', 'total_amount']
    for field in required_fields:
        if field not in extracted or not extracted[field]:
            return False
    
    # 3. 位置情報の妥当性
    for line in receipt['text_lines']:
        bbox = line.get('bounding_box', [])
        if len(bbox) != 4:
            return False
        if any(x < 0 for x in bbox):
            return False
    
    return True
```

### 5.3 推奨ワークフロー

**効率的なデータ収集ワークフロー：**

1. **ベースデータの収集（1-2週間）**
   - 15-25件の高品質なドキュメントを手動で修正
     - レシート: 10-15件（60-70%）
     - 領収書: 5-10件（30-40%）
   - 各言語から2-3件ずつ（レシートと領収書の両方を含む）

2. **データ拡張（1日）**
   - 各ベースデータから10-15件のバリエーションを生成
   - 合計150-375件の拡張データ
   - **重要**: レシートと領収書の比率を維持（60-70%:30-40%）

3. **品質チェック（1日）**
   - 自動的な品質フィルタリング
   - 手動でのサンプル確認（10-20件）
   - レシートと領収書の両方で整合性を確認

4. **学習と評価（1週間）**
   - 混合データ（レシート+領収書）で学習
   - レシートと領収書の両方で評価
   - 必要に応じて追加のベースデータを収集

---

## 6. まとめ

### 6.1 推奨アプローチ

**✅ AIによるデータ拡張を推奨**

**理由：**
- 少数の高品質なデータから大量のバリエーションを生成可能
- OCRエラーやレイアウトのバリエーションを効率的にカバー
- 位置情報ベースの特徴量を使用しているため、拡張が容易
- 整合性を保ったままデータを生成可能

### 6.2 実装の優先順位

1. **Phase 1: ベースデータの収集**
   - 15-25件の高品質なドキュメントを手動で修正
     - レシート: 10-15件（60-70%）
     - 領収書: 5-10件（30-40%）
   - 各言語から2-3件ずつ（レシートと領収書の両方を含む）

2. **Phase 2: データ拡張の実装**
   - Pythonスクリプトでデータ拡張を実装
   - レシートと領収書の両方に対応
   - 品質チェック機能を追加（レシートと領収書の両方で整合性を確認）

3. **Phase 3: 学習と評価**
   - 混合データ（レシート+領収書）で学習
   - レシートと領収書の両方で評価
   - 必要に応じて追加のベースデータを収集

### 6.3 注意点

- **整合性の維持**: 金額の置換時は `total == subtotal + tax` を維持（レシートと領収書の両方で）
- **品質の確認**: 自動的な品質チェックと手動でのサンプル確認
- **レシートと領収書のバランス**: 拡張後も推奨比率（60-70%:30-40%）を維持
- **過度な拡張を避ける**: 現実的でないデータは学習に悪影響を与える可能性がある
- **ベースデータの重要性**: 拡張データの品質はベースデータの品質に依存
- **レイアウトの多様性**: レシートと領収書の両方から多様なレイアウトを含める

---

## 参考資料

- [ml-training-guide.md](./ml-training-guide.md)
- [Sequence_Labeling_from_textLines.md](./Sequence_Labeling_from_textLines.md)
- Data Augmentation in NLP: https://arxiv.org/abs/1901.11196

