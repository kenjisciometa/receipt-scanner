# Web版 OCR＋高精度抽出システム 仕様書

## 1. 目的
- レシート / Invoice の画像・PDFを Web 経由でアップロードし
- OCR → 高精度な情報抽出（Subtotal / Tax / Total 等）を行い
- 業務用の支出管理・監査・学習データ生成に耐える基盤を構築する

本仕様は **Flutter / Web 共通で使えるバックエンド基準**となる。

---

## 2. 対象ドキュメント
- Receipt（レシート）
- Invoice（請求書）
※ 初期は Receipt 優先、Invoice は同一パイプラインで拡張対応

---

## 3. 全体アーキテクチャ概要

Client（Web / Mobile）
  ↓
Upload API（署名付き）
  ↓
Object Storage（画像 / PDF）
  ↓
OCR & Extraction Job（非同期）
  ↓
Database（結果・状態）
  ↓
Result API
  ↓
Review UI / Mobile 表示

---

## 4. 処理フロー（詳細）

### 4.1 アップロード
1. クライアントが Upload API を呼び出す
2. サーバが署名付きアップロードURLを返却
3. クライアントが画像/PDFを Object Storage に直接アップロード
4. 完了後、`create_job` API を呼び出す

---

### 4.2 OCR & 抽出ジョブ（非同期）
- ジョブは Queue / Worker で処理
- UI はブロックしない

#### ステップ
1. 画像/PDF 読み込み
2. OCR 実行
3. textLines（bbox付き）生成
4. 正規化（言語・数値・通貨）
5. ルール＋整合性チェックによる抽出
6. 結果保存
7. status 更新
8. 完了通知（ポーリング / Webhook / Push）

---

## 5. OCR仕様

### 5.1 必須要件
- text（全文）
- textLines（1行単位）
  - text
  - boundingBox（x, y, w, h）
  - confidence（任意）

### 5.2 OCRエンジン
- 初期：クラウドOCR（Google / Azure / AWS など）
- 将来：自前OCR or ハイブリッド

---

## 6. 抽出仕様（高精度）

### 6.1 抽出対象フィールド
| フィールド | 必須 | 備考 |
|---|---|---|
| merchant_name | ○ | 店舗名 |
| date | ○ | 購入日 |
| currency | ○ | EUR / GBP 等 |
| subtotal | △ | 無い場合あり |
| tax_total | △ | VAT合算 |
| total | ○ | 最重要 |
| receipt_number | △ | REF / No |
| payment_method | △ | CARD / CASH |

---

### 6.2 抽出ロジック（初期）
- ルールベース中心
- textLines + 位置 + キーワード
- 金額整合性チェック：
  - subtotal + tax == total（誤差許容）
  - VAT breakdown 合算チェック

### 6.3 多言語対応
- 対応言語：英語、フィンランド語、スウェーデン語、フランス語、ドイツ語、イタリア語、スペイン語
- キーワードベース抽出（言語ごとのパターン）
- 通貨対応：EUR, SEK, NOK, DKK, USD, GBP

### 6.4 抽出品質保証
- 候補スコアリング（位置、キーワード、パターンマッチ）
- 整合性チェック結果による検証要求フラグ
- 信頼度スコア算出（0.0-1.0）

---

## 7. データモデル仕様

### 7.1 API共通データ構造

#### 7.1.1 OCR結果
```json
{
  "text": "string",           // 全認識テキスト
  "textLines": [           // 行ごとの認識結果
    {
      "text": "string",
      "confidence": 0.95,
      "boundingBox": [x, y, width, height]
    }
  ],
  "confidence": 0.89,      // 全体信頼度
  "detected_language": "fi", // 検出言語
  "processing_time": 1250,  // 処理時間(ms)
  "success": true          // 処理成功フラグ
}
```

#### 7.1.2 抽出結果
```json
{
  "merchant_name": "K-Market Keskus",
  "date": "2024-01-15T14:30:00Z",
  "currency": "EUR",
  "subtotal": 18.50,
  "tax_breakdown": [
    {"rate": 14.0, "amount": 2.59},
    {"rate": 24.0, "amount": 4.44}
  ],
  "tax_total": 7.03,
  "total": 25.53,
  "receipt_number": "TR001234",
  "payment_method": "card",
  "confidence": 0.87,
  "status": "completed",
  "needs_verification": false,
  "extracted_items": [
    {
      "name": "Maito 1L",
      "quantity": 2,
      "total_price": 3.80,
      "unit_price": 1.90,
      "tax_rate": 14.0
    }
  ]
}
```

### 7.2 ステータス管理
| ステータス | 説明 |
|---|---|
| pending | 待機中 |
| processing | 処理中 |
| completed | 完了 |
| failed | 失敗 |
| needs_verification | 要検証 |

---

## 8. API仕様

### 8.1 アップロードAPI
```
POST /api/v1/upload/signed-url
```
**Request:**
```json
{
  "file_type": "image/jpeg",
  "file_size": 1024000,
  "document_type": "receipt"
}
```
**Response:**
```json
{
  "upload_url": "https://...",
  "file_id": "uuid",
  "expires_in": 3600
}
```

### 8.2 ジョブ作成API
```
POST /api/v1/jobs
```
**Request:**
```json
{
  "file_id": "uuid",
  "document_type": "receipt",
  "language_hint": "fi"
}
```
**Response:**
```json
{
  "job_id": "uuid",
  "status": "pending",
  "created_at": "2024-01-15T14:30:00Z"
}
```

### 8.3 結果取得API
```
GET /api/v1/jobs/{job_id}/result
```
**Response:**
```json
{
  "job_id": "uuid",
  "status": "completed",
  "ocr_result": { /* OCR結果 */ },
  "extraction_result": { /* 抽出結果 */ },
  "processing_time": 2500,
  "created_at": "2024-01-15T14:30:00Z",
  "completed_at": "2024-01-15T14:30:02Z"
}
```

---

## 9. 品質保証・整合性チェック

### 9.1 金額整合性
- `subtotal + tax_total ≈ total` (誤差±0.02許容)
- Tax breakdown合算 = tax_total
- 商品合計 ≈ subtotal

### 9.2 必須フィールド検証
- merchant_name: 必須
- date: 必須  
- total: 必須
- currency: 必須

### 9.3 信頼度評価
- OCR信頼度 × 抽出パターンマッチ度 × 整合性スコア
- 閾値: 0.7未満で needs_verification フラグ

---

## 10. Flutter連携仕様

### 10.1 共通パイプライン
- FlutterアプリのOCRサービスをWeb API互換形式に標準化
- 同一の抽出ロジック・パターンを使用
- 結果形式統一（JSON互換）

### 10.2 オフライン対応
- Flutterアプリはローカル処理
- 結果をWebバックエンドと同期可能
- API形式でのエクスポート/インポート

### 10.3 学習データ生成
- 両プラットフォームからの処理結果を統合
- モデル改善のためのフィードバックループ
- ユーザー修正データの収集

---

## 11. 実装ロードマップ

### Phase 1: 基盤構築
- [x] Flutter OCR実装完了
- [ ] Web API基盤構築
- [ ] 共通データモデル実装

### Phase 2: 統合
- [ ] Flutter→Web API形式変換
- [ ] 抽出ロジック共通化
- [ ] 品質保証システム

### Phase 3: 最適化
- [ ] ML模型統合
- [ ] 性能最適化
- [ ] 多言語拡張

---

## 12. パフォーマンス要件

- OCR処理：2秒以内
- 抽出処理：1秒以内  
- API応答：500ms以内
- 同時処理：100ジョブ
- 精度目標：95%（主要フィールド）

