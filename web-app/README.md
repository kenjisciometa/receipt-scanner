# Receipt Web ML System

Web版レシートOCR＋機械学習システムの実装プロジェクト

## 📁 プロジェクト構造

```
receipt-web-ml/
├── web-app/                    # Next.js Web アプリケーション
│   ├── src/
│   │   ├── app/                # App Router
│   │   ├── lib/                # ユーティリティ・設定
│   │   ├── types/              # TypeScript型定義
│   │   └── services/           # ビジネスロジック
│   ├── prisma/                 # データベーススキーマ・マイグレーション
│   ├── data/training/          # 機械学習用データ
│   │   ├── raw/               # 自動抽出結果 (JSON)
│   │   ├── verified/          # 検証済みground truth (JSON)
│   │   └── exports/           # ML用統合エクスポート
│   └── uploads/               # 画像ファイル保存
├── ml-service/                # Python ML サービス (今後追加)
└── README.md
```

## 🚀 セットアップ手順

### 1. 依存関係インストール

```bash
cd web-app
npm install
```

### 2. 環境変数設定

`.env`ファイルを編集してください：

```bash
# Database
DATABASE_URL="file:./dev.db"

# OCR Service (Google Cloud Vision)
GOOGLE_CLOUD_PROJECT_ID="your-project-id"
GOOGLE_CLOUD_PRIVATE_KEY="your-private-key"
GOOGLE_CLOUD_CLIENT_EMAIL="your-client-email"

# File Storage
STORAGE_TYPE="local"
LOCAL_STORAGE_PATH="./uploads"

# ML Service
ML_API_URL="http://localhost:8000"
ML_API_KEY="your-ml-api-key"
```

### 3. データベース初期化

```bash
npx prisma migrate dev --name init
npx prisma generate
```

### 4. 開発サーバー起動

```bash
npm run dev
```

## 📋 実装済み機能

### ✅ Phase 1: 基盤構築
- [x] Next.js 14 + TypeScript プロジェクト
- [x] PostgreSQL + Prisma ORM設定
- [x] SQLiteローカル開発環境
- [x] 基本TypeScript型定義
- [x] データベーススキーマ設計
- [x] 環境変数設定

### 🔄 実装中
- [ ] OCR Service (Google Cloud Vision統合)
- [ ] 画像アップロード機能
- [ ] 基本UI実装
- [ ] 抽出ロジック移植

### 📅 今後の実装予定
- [ ] 手動修正・検証システム
- [ ] 学習データ収集機能
- [ ] Python ML パイプライン
- [ ] モデル訓練・評価
- [ ] 高精度抽出API

## 🗄️ データベーススキーマ

### 主要テーブル

- **processing_jobs**: 処理ジョブ管理
- **ocr_results**: OCR処理結果
- **extraction_results**: 抽出結果・検証データ
- **training_data**: 機械学習用データ

### 特徴

- Receipt/Invoice自動分類対応
- 多言語サポート (EN/FI/SV/FR/DE/IT/ES)
- 金額整合性チェック
- 学習データ品質管理

## 🔧 技術スタック

- **Frontend**: Next.js 14, TypeScript, Tailwind CSS
- **Backend**: Next.js API Routes
- **Database**: SQLite (開発) → Supabase (本番)
- **ORM**: Prisma
- **OCR**: Google Cloud Vision API
- **ML**: Python + FastAPI (予定)
- **Storage**: Local → Cloud Storage
- **State Management**: Zustand, React Query

## 📚 参考実装

このWebシステムはFlutterアプリの実装を参考にしています：

- **OCR Service**: `flutter_app/lib/services/ocr/ml_kit_service.dart`
- **抽出ロジック**: `flutter_app/lib/services/extraction/receipt_parser.dart`
- **学習データ収集**: `flutter_app/lib/services/training_data/training_data_collector.dart`
- **UI実装**: `flutter_app/lib/presentation/screens/preview/preview_screen.dart`

## 🎯 開発目標

### 精度目標
- 文書分類精度: 95%以上
- 主要フィールド抽出: 95%以上
- 処理時間: 3秒以内
- 学習データ: 1,000件以上

### 運用目標
- 月間処理能力: 1,000レシート
- システム稼働率: 99.9%
- ユーザー満足度: 90%以上

## 📖 次のステップ

1. **OCR統合**: Google Cloud Vision API実装
2. **UI開発**: アップロード・結果表示画面
3. **抽出ロジック**: ルールベース処理移植
4. **データ収集**: Raw/Verified JSON出力
5. **ML開発**: Python学習パイプライン構築