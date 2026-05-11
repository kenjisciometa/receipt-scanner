# AWS バックアップ設定ガイド（初心者向け）

SciometaPOS のオンプレ環境を AWS にバックアップするための手順書です。

---

## 目次

1. [全体構成](#1-全体構成)
2. [前提条件](#2-前提条件)
3. [Step 1: AWS アカウント作成と初期設定](#step-1-aws-アカウント作成と初期設定)
4. [Step 2: S3 バケットの作成](#step-2-s3-バケットの作成)
5. [Step 3: IAM ユーザーの作成](#step-3-iam-ユーザーの作成)
6. [Step 4: AWS CLI のインストールと設定](#step-4-aws-cli-のインストールと設定)
7. [Step 5: PostgreSQL (Supabase) のバックアップ](#step-5-postgresql-supabase-のバックアップ)
8. [Step 6: Docker イメージのバックアップ (ECR)](#step-6-docker-イメージのバックアップ-ecr)
9. [Step 7: NAS ファイルのバックアップ（オプション）](#step-7-nas-ファイルのバックアップオプション)
10. [Step 8: cron による自動化](#step-8-cron-による自動化)
11. [Step 9: S3 ライフサイクルポリシー（コスト最適化）](#step-9-s3-ライフサイクルポリシーコスト最適化)
12. [Step 10: バックアップの検証](#step-10-バックアップの検証)
13. [復旧手順](#復旧手順)
14. [コスト見積もり](#コスト見積もり)
15. [トラブルシューティング](#トラブルシューティング)

---

## 1. 全体構成

```
┌─────────────────────────────────┐
│        オンプレサーバー           │
│                                 │
│  ┌───────────┐  ┌────────────┐  │
│  │ Next.js   │  │ NAS        │  │
│  │ (Docker)  │  │ /mnt/...   │  │
│  └─────┬─────┘  └─────┬──────┘  │
│        │              │         │
└────────┼──────────────┼─────────┘
         │              │
    ┌────▼────┐    ┌────▼─────┐
    │ ECR     │    │ S3       │
    │ (Docker │    │ (DB dump │
    │  image) │    │  + NAS)  │
    └─────────┘    └──────────┘
                        │
              ┌─────────▼──────────┐
              │ S3 Glacier         │
              │ (90日後に自動移行)   │
              └────────────────────┘

  ※ DB は Supabase Cloud 上にあるため
    pg_dump は Supabase 障害への保険
```

### バックアップ対象

| 対象 | 保存先 | 頻度 | 必須度 |
|------|--------|------|--------|
| PostgreSQL (Supabase) | S3 | 日次 | 推奨（Supabase 障害への保険） |
| Docker イメージ | ECR | デプロイ時 | 推奨 |
| NAS ファイル (receipts/invoices) | S3 | 毎時 | オプション（※後述） |

> **NAS について**: レシート画像 (`/mnt/receipts`) と請求書画像 (`/mnt/invoices`) がNASに保存されています。Order History のデータ自体は Supabase にあるため、画像ファイルが不要であればこのステップはスキップできます。ただし、監査・税務対応で原本画像が必要な場合はバックアップを推奨します。

---

## 2. 前提条件

- オンプレサーバーにインターネット接続がある
- SSH でオンプレサーバーにアクセスできる
- Docker がインストール済み
- クレジットカード（AWS アカウント作成に必要）

---

## Step 1: AWS アカウント作成と初期設定

### 1.1 アカウント作成

1. https://aws.amazon.com/ にアクセス
2. 「アカウントを作成」をクリック
3. メールアドレス、パスワード、アカウント名を入力
4. クレジットカード情報を登録（無料利用枠あり）
5. 本人確認（電話番号認証）
6. サポートプランは「ベーシック（無料）」を選択

### 1.2 リージョンの選択

AWS コンソール右上のリージョンセレクターで選択：

| リージョン | 用途 |
|-----------|------|
| `eu-north-1` (ストックホルム) | EU データ居住要件がある場合に推奨 |
| `eu-central-1` (フランクフルト) | EU 内で低レイテンシが必要な場合 |
| `us-east-1` (バージニア) | 最も安価。データ居住要件がなければ推奨 |

> 以降の手順ではリージョンを `eu-north-1` として記載します。環境に応じて読み替えてください。

### 1.3 MFA（多要素認証）の有効化

**必ず実施してください。** ルートアカウントが乗っ取られると全リソースが危険にさらされます。

1. AWS コンソール → 右上のアカウント名 → 「セキュリティ認証情報」
2. 「MFA デバイスの割り当て」をクリック
3. 「認証アプリケーション」を選択（Google Authenticator 等）
4. QR コードをスキャンし、コード2つを入力して有効化

---

## Step 2: S3 バケットの作成

### 2.1 バケット作成

1. AWS コンソール → S3 → 「バケットを作成」
2. 以下の設定で作成：

| 項目 | 値 |
|------|-----|
| バケット名 | `sciometa-pos-backup`（グローバルで一意にする） |
| リージョン | `eu-north-1` |
| オブジェクト所有者 | ACL 無効 |
| パブリックアクセス | **すべてブロック**（デフォルトのまま） |
| バケットのバージョニング | **有効** |
| デフォルトの暗号化 | SSE-S3（Amazon S3 マネージドキー） |

### 2.2 フォルダ構成の作成

バケット内に以下のプレフィックス（フォルダ）を作成：

```
sciometa-pos-backup/
├── db-dumps/          ← PostgreSQL バックアップ
├── docker-images/     ← Docker イメージのタグ記録（実体は ECR）
├── receipts/          ← レシート画像（オプション）
└── invoices/          ← 請求書画像（オプション）
```

S3 コンソールで「フォルダの作成」をクリックし、上記の名前で作成します。

---

## Step 3: IAM ユーザーの作成

バックアップ専用ユーザーを作成し、最小権限を付与します。

### 3.1 ポリシーの作成

1. AWS コンソール → IAM → ポリシー → 「ポリシーを作成」
2. JSON タブに以下を貼り付け：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3BackupAccess",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::sciometa-pos-backup",
        "arn:aws:s3:::sciometa-pos-backup/*"
      ]
    },
    {
      "Sid": "ECRAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:BatchGetImage",
        "ecr:CreateRepository",
        "ecr:DescribeRepositories"
      ],
      "Resource": "*"
    }
  ]
}
```

3. ポリシー名: `SciometaPOS-Backup-Policy`
4. 「ポリシーを作成」をクリック

### 3.2 ユーザーの作成

1. IAM → ユーザー → 「ユーザーを作成」
2. ユーザー名: `sciometa-backup`
3. 「AWS マネジメントコンソールへのアクセス」は **無効** のまま（CLI のみ使用）
4. 「許可を直接アタッチする」→ `SciometaPOS-Backup-Policy` を選択
5. 作成完了

### 3.3 アクセスキーの発行

1. 作成したユーザー → 「セキュリティ認証情報」タブ
2. 「アクセスキーを作成」→ ユースケース: 「コマンドラインインターフェイス (CLI)」
3. **アクセスキー ID** と **シークレットアクセスキー** をメモ

> **重要**: シークレットアクセスキーはこの画面でしか確認できません。安全な場所に保管してください。

---

## Step 4: AWS CLI のインストールと設定

オンプレサーバーで実行します。

### 4.1 インストール

```bash
# Linux (x86_64)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 確認
aws --version
```

### 4.2 認証情報の設定

```bash
aws configure
```

以下を入力：

```
AWS Access Key ID: （Step 3.3 のアクセスキー ID）
AWS Secret Access Key: （Step 3.3 のシークレットアクセスキー）
Default region name: eu-north-1
Default output format: json
```

### 4.3 接続テスト

```bash
aws s3 ls s3://sciometa-pos-backup/
```

フォルダ一覧が表示されれば成功です。

---

## Step 5: PostgreSQL (Supabase) のバックアップ

Supabase Cloud はデフォルトで日次バックアップを提供していますが、追加の保険として自前でもバックアップを取ります。

### 5.1 Supabase DB 接続情報の確認

1. Supabase ダッシュボード → Settings → Database
2. 「Connection string」の URI をコピー（`postgres://postgres.[ref]:[password]@...`）

### 5.2 バックアップスクリプトの作成

オンプレサーバーに以下のスクリプトを作成：

```bash
sudo mkdir -p /opt/sciometa/backup/scripts
sudo chown $(whoami):$(whoami) /opt/sciometa/backup/scripts
```

`/opt/sciometa/backup/scripts/backup-db.sh`:

```bash
#!/bin/bash
set -euo pipefail

# --- 設定 ---
SUPABASE_DB_URL="postgres://postgres.[your-ref]:[your-password]@aws-0-eu-north-1.pooler.supabase.com:5432/postgres"
S3_BUCKET="s3://sciometa-pos-backup/db-dumps"
BACKUP_DIR="/tmp/sciometa-db-backup"
DATE=$(date +%Y-%m-%d_%H%M%S)
FILENAME="supabase_backup_${DATE}.sql.gz"
LOG_FILE="/var/log/sciometa-backup.log"

# --- 実行 ---
echo "[$(date)] DB backup started" >> "$LOG_FILE"

mkdir -p "$BACKUP_DIR"

# pg_dump でダンプを取得し、gzip で圧縮
pg_dump "$SUPABASE_DB_URL" \
  --no-owner \
  --no-privileges \
  --format=plain \
  | gzip > "${BACKUP_DIR}/${FILENAME}"

# S3 にアップロード
aws s3 cp "${BACKUP_DIR}/${FILENAME}" "${S3_BUCKET}/${FILENAME}"

# ローカルの一時ファイルを削除
rm -f "${BACKUP_DIR}/${FILENAME}"

echo "[$(date)] DB backup completed: ${FILENAME}" >> "$LOG_FILE"
```

```bash
chmod +x /opt/sciometa/backup/scripts/backup-db.sh
```

### 5.3 手動テスト

```bash
# pg_dump が使えるか確認（なければインストール）
which pg_dump || sudo apt-get install -y postgresql-client

# スクリプト実行
/opt/sciometa/backup/scripts/backup-db.sh

# S3 に保存されたか確認
aws s3 ls s3://sciometa-pos-backup/db-dumps/
```

---

## Step 6: Docker イメージのバックアップ (ECR)

### 6.1 ECR リポジトリの作成

```bash
aws ecr create-repository \
  --repository-name sciometa-pos/restaurant-pos \
  --region eu-north-1 \
  --image-scanning-configuration scanOnPush=true
```

### 6.2 バックアップスクリプト

`/opt/sciometa/backup/scripts/backup-docker.sh`:

```bash
#!/bin/bash
set -euo pipefail

# --- 設定 ---
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="eu-north-1"
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_NAME="sciometa-pos/restaurant-pos"
DATE_TAG=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/var/log/sciometa-backup.log"

# --- 実行 ---
echo "[$(date)] Docker backup started" >> "$LOG_FILE"

# ECR にログイン
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REPO"

# 現在稼働中のイメージを取得
RUNNING_IMAGE=$(docker inspect restaurant-pos-prod --format='{{.Image}}' 2>/dev/null || echo "")

if [ -z "$RUNNING_IMAGE" ]; then
  echo "[$(date)] Warning: No running container found. Skipping." >> "$LOG_FILE"
  exit 0
fi

# タグ付け & プッシュ
docker tag "$RUNNING_IMAGE" "${ECR_REPO}/${IMAGE_NAME}:${DATE_TAG}"
docker tag "$RUNNING_IMAGE" "${ECR_REPO}/${IMAGE_NAME}:latest"

docker push "${ECR_REPO}/${IMAGE_NAME}:${DATE_TAG}"
docker push "${ECR_REPO}/${IMAGE_NAME}:latest"

echo "[$(date)] Docker backup completed: ${DATE_TAG}" >> "$LOG_FILE"
```

```bash
chmod +x /opt/sciometa/backup/scripts/backup-docker.sh
```

### 6.3 手動テスト

```bash
/opt/sciometa/backup/scripts/backup-docker.sh

# 確認
aws ecr describe-images \
  --repository-name sciometa-pos/restaurant-pos \
  --region eu-north-1
```

---

## Step 7: NAS ファイルのバックアップ（オプション）

> **このステップはオプションです。** レシート・請求書の原本画像が監査や税務で必要な場合のみ実施してください。Order History のデータ自体は Supabase に保存されています。

### 7.1 バックアップスクリプト

`/opt/sciometa/backup/scripts/backup-nas.sh`:

```bash
#!/bin/bash
set -euo pipefail

S3_BUCKET="s3://sciometa-pos-backup"
LOG_FILE="/var/log/sciometa-backup.log"

echo "[$(date)] NAS backup started" >> "$LOG_FILE"

# receipts の同期（差分のみ転送）
if [ -d "/mnt/receipts" ]; then
  aws s3 sync /mnt/receipts "${S3_BUCKET}/receipts/" --delete
  echo "[$(date)] Receipts synced" >> "$LOG_FILE"
fi

# invoices の同期
if [ -d "/mnt/invoices" ]; then
  aws s3 sync /mnt/invoices "${S3_BUCKET}/invoices/" --delete
  echo "[$(date)] Invoices synced" >> "$LOG_FILE"
fi

echo "[$(date)] NAS backup completed" >> "$LOG_FILE"
```

```bash
chmod +x /opt/sciometa/backup/scripts/backup-nas.sh
```

---

## Step 8: cron による自動化

### 8.1 crontab の編集

```bash
crontab -e
```

以下を追加：

```cron
# SciometaPOS バックアップ
# DB: 毎日 AM 3:00 (UTC)
0 3 * * * /opt/sciometa/backup/scripts/backup-db.sh 2>&1

# Docker: 毎週日曜 AM 4:00 (UTC)
0 4 * * 0 /opt/sciometa/backup/scripts/backup-docker.sh 2>&1

# NAS（オプション）: 毎日 AM 5:00 (UTC)
# 0 5 * * * /opt/sciometa/backup/scripts/backup-nas.sh 2>&1
```

### 8.2 動作確認

```bash
# cron が登録されたか確認
crontab -l

# ログを監視（別ターミナルで開いておく）
tail -f /var/log/sciometa-backup.log
```

---

## Step 9: S3 ライフサイクルポリシー（コスト最適化）

古いバックアップを自動的に安価なストレージに移行します。

### 9.1 AWS コンソールで設定

1. S3 → `sciometa-pos-backup` → 「管理」タブ → 「ライフサイクルルールを作成」
2. 以下のルールを作成：

**ルール名**: `archive-old-backups`

| アクション | 条件 |
|-----------|------|
| S3 Glacier Flexible Retrieval に移行 | 作成から 90 日後 |
| オブジェクトの有効期限切れ（削除） | 作成から 365 日後 |

3. フィルターは「バケット内のすべてのオブジェクトに適用」
4. バージョニングが有効なので「現在のバージョン」と「以前のバージョン」両方に適用

### 9.2 CLI で設定する場合

```bash
cat > /tmp/lifecycle.json << 'EOF'
{
  "Rules": [
    {
      "ID": "archive-old-backups",
      "Status": "Enabled",
      "Filter": {},
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ],
      "Expiration": {
        "Days": 365
      },
      "NoncurrentVersionTransitions": [
        {
          "NoncurrentDays": 30,
          "StorageClass": "GLACIER"
        }
      ],
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 180
      }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket sciometa-pos-backup \
  --lifecycle-configuration file:///tmp/lifecycle.json
```

---

## Step 10: バックアップの検証

バックアップは「復元できる」ことを確認して初めて意味があります。月に1回は検証を行ってください。

### 10.1 DB バックアップの検証

```bash
# 最新のバックアップをダウンロード
aws s3 ls s3://sciometa-pos-backup/db-dumps/ --recursive | sort | tail -1
aws s3 cp s3://sciometa-pos-backup/db-dumps/supabase_backup_YYYY-MM-DD_HHMMSS.sql.gz /tmp/

# 解凍して中身を確認
gunzip -k /tmp/supabase_backup_*.sql.gz
head -100 /tmp/supabase_backup_*.sql

# テスト用 DB に復元（ローカル PostgreSQL がある場合）
# createdb test_restore
# psql test_restore < /tmp/supabase_backup_*.sql
```

### 10.2 Docker イメージの検証

```bash
# ECR からプルできるか確認
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region eu-north-1 \
  | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.eu-north-1.amazonaws.com"

docker pull "${AWS_ACCOUNT_ID}.dkr.ecr.eu-north-1.amazonaws.com/sciometa-pos/restaurant-pos:latest"
```

---

## 復旧手順

オンプレサーバーが完全に障害を起こした場合の復旧手順です。

### 方法 A: 新しいオンプレサーバーへの復旧

```bash
# 1. AWS CLI をインストール & 設定（Step 4 参照）

# 2. Docker イメージをプル
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region eu-north-1 \
  | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.eu-north-1.amazonaws.com"

docker pull "${AWS_ACCOUNT_ID}.dkr.ecr.eu-north-1.amazonaws.com/sciometa-pos/restaurant-pos:latest"

# 3. docker-compose.prod.yml のイメージを ECR のものに変更して起動
docker compose -f docker-compose.prod.yml up -d

# 4. NAS ファイルの復元（バックアップしていた場合）
aws s3 sync s3://sciometa-pos-backup/receipts/ /mnt/receipts/
aws s3 sync s3://sciometa-pos-backup/invoices/ /mnt/invoices/
```

### 方法 B: AWS EC2 への一時的な復旧

```bash
# 1. EC2 インスタンスを起動（AWS コンソールまたは CLI）
#    - AMI: Amazon Linux 2023 または Ubuntu 22.04
#    - インスタンスタイプ: t3.large（4GB RAM）以上を推奨
#    - ストレージ: 50GB 以上
#    - セキュリティグループ: ポート 443, 9001 を開放

# 2. EC2 に SSH 接続後、Docker をインストール
sudo yum install -y docker   # Amazon Linux
sudo systemctl start docker

# 3. 以降は方法 A の手順 2〜4 と同じ
```

> **注意**: DB は Supabase Cloud 上にあるため、DB の復元は不要です。`.env.production` の環境変数を正しく設定すれば、新しいサーバーからそのまま Supabase に接続できます。

---

## コスト見積もり

| サービス | 用途 | 月額目安 |
|---------|------|---------|
| S3 Standard | DB ダンプ保存 (~1GB) | ~$0.02 |
| S3 Standard | NAS ファイル (~10GB) | ~$0.23 |
| S3 Glacier | 90日以降のアーカイブ | ~$0.004/GB |
| ECR | Docker イメージ (~2GB) | ~$0.20 |
| データ転送（IN） | アップロード | 無料 |
| **合計** | | **~$1-5/月** |

> NAS バックアップなしの場合、月額 $1 以下で収まります。

---

## トラブルシューティング

### `aws s3 cp` でタイムアウトする

```bash
# タイムアウト値を延長
aws configure set default.s3.max_concurrent_requests 5
aws configure set default.connect_timeout 300
```

### `pg_dump` で接続エラー

```bash
# Supabase のプーリングモード接続を使用（ポート 6543）
# Direct connection（ポート 5432）が失敗する場合に試す
pg_dump "postgres://postgres.[ref]:[password]@aws-0-eu-north-1.pooler.supabase.com:6543/postgres" ...
```

### ECR ログインが失敗する

```bash
# トークンの有効期限切れ。再ログインする
aws ecr get-login-password --region eu-north-1 \
  | docker login --username AWS --password-stdin "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.eu-north-1.amazonaws.com"
```

### cron が動かない

```bash
# cron サービスが起動しているか確認
sudo systemctl status cron    # Ubuntu/Debian
sudo systemctl status crond   # CentOS/Amazon Linux

# スクリプトのパスが正しいか確認
which aws       # → /usr/local/bin/aws
which pg_dump   # → /usr/bin/pg_dump

# cron では PATH が限定的なので、スクリプト冒頭に追加
# export PATH=/usr/local/bin:/usr/bin:$PATH
```

### バックアップの容量が急増した

```bash
# S3 のバケットサイズを確認
aws s3 ls s3://sciometa-pos-backup/ --recursive --summarize | tail -2

# 不要な古いバックアップを手動削除
aws s3 rm s3://sciometa-pos-backup/db-dumps/ --recursive \
  --exclude "*" --include "supabase_backup_2024-01*"
```
