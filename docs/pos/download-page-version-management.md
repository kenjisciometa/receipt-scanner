# Download ページ - アプリバージョン管理 定義書

## 概要

ダウンロードページは、サーバー上のファイルを自動スキャンしてバージョン一覧を生成する。DBや設定ファイルの更新は不要で、**ファイルを所定のディレクトリに配置するだけ**で新バージョンがリリースされる。

## 対象ファイル

| ファイル | 役割 |
|----------|------|
| `src/app/api/app-updates/route.ts` | バージョン情報API（ディレクトリスキャン・マニフェスト生成） |
| `src/app/api/download/[slug]/[platform]/[filename]/route.ts` | 認証付きファイル配信API（private用） |

フロントエンド（`src/app/download/`配下のコンポーネント群）は `/api/app-updates` のレスポンスURLをそのまま使用するため、パスのハードコードはない。

---

## ディレクトリ構造

```
public/downloads/
├── bos/
│   ├── android/
│   │   ├── bell-order-system-1.0.7.apk
│   │   ├── bell-order-system-1.0.8.apk
│   │   ├── bell-order-system-1.0.9.apk
│   │   └── bell-order-system-1.1.0.apk       <- 最新として自動検出
│   └── linux/
│       ├── bell-order-system-1.0.0-x86_64.AppImage
│       ├── bell-order-system-1.0.1-x86_64.AppImage
│       └── bell-order-system-1.0.2-x86_64.AppImage
├── tos/
│   └── android/
│       └── table-order-system-X.Y.Z.apk
├── self_station/
│   └── android/
│       └── self-station-X.Y.Z.apk
└── osd/
    ├── android/
    │   └── order-status-display-X.Y.Z.apk
    └── linux/
        └── order-status-display-X.Y.Z-x86_64.AppImage
```

認証が必要なファイルは `private/downloads/` に同じ構造で配置する（同一バージョンがある場合 private が優先）。

---

## ファイル命名規則

### パス形式

```
{public|private}/downloads/{slug}/{platform}/{filePrefix}-X.Y.Z[-x86_64].{ext}
```

### アプリ別定義

| アプリ | slug | filePrefix | Android | Linux |
|--------|------|------------|---------|-------|
| BOS | `bos` | `bell-order-system` | `bell-order-system-X.Y.Z.apk` | `bell-order-system-X.Y.Z-x86_64.AppImage` |
| TOS | `tos` | `table-order-system` | `table-order-system-X.Y.Z.apk` | - |
| Self Station | `self_station` | `self-station` | `self-station-X.Y.Z.apk` | - |
| OSD | `osd` | `order-status-display` | `order-status-display-X.Y.Z.apk` | `order-status-display-X.Y.Z-x86_64.AppImage` |

- `X.Y.Z` はセマンティックバージョニング（例: `1.2.0`）
- この命名規則に従わないファイルは無視される
- Linux の `-x86_64` サフィックスは必須

### APP_CONFIGS（ソースコード上の定義）

```typescript
const APP_CONFIGS: Record<string, AppConfig> = {
  bos:          { filePrefix: 'bell-order-system' },
  tos:          { filePrefix: 'table-order-system' },
  self_station: { filePrefix: 'self-station' },
  osd:          { filePrefix: 'order-status-display' },
};
```

---

## 新バージョンのリリース手順

1. ファイルを `public/downloads/{slug}/{platform}/` に配置する
   - 例: `public/downloads/bos/android/bell-order-system-1.2.0.apk`
2. 完了。APIが自動でスキャン・最新バージョンを検出する

- 古いバージョンはバージョン履歴に自動表示される
- 最新バージョンはバージョン番号の大小比較で決定される（ファイルの更新日時ではない）

---

## API エンドポイント

### GET /api/app-updates

ダウンロードページ用。全アプリのバージョン情報を返す。

**レスポンス例:**

```json
{
  "apps": {
    "bos": {
      "platforms": {
        "android": {
          "latest_version": "1.1.0",
          "download_url": "https://example.com/downloads/bos/android/bell-order-system-1.1.0.apk",
          "file_size": 53248000,
          "release_date": "2026-03-04",
          "changelog": "Bug fixes and performance improvements",
          "all_versions": [
            {
              "version": "1.1.0",
              "download_url": "...",
              "file_size": 53248000,
              "release_date": "2026-03-04",
              "changelog": "..."
            },
            {
              "version": "1.0.9",
              "download_url": "...",
              "file_size": 52224000,
              "release_date": "2026-02-25",
              "changelog": "..."
            }
          ]
        },
        "linux": { ... }
      }
    },
    "tos": { ... },
    "self_station": { ... },
    "osd": { ... }
  }
}
```

### GET /api/app-updates?platform=android|linux

Flutter アプリ用レガシー形式。BOS のみ返す。

**レスポンス例:**

```json
{
  "android": {
    "latest_version": "1.1.0",
    "min_supported_version": "1.0.0",
    "version_code": 4,
    "apk_url": "https://example.com/downloads/bos/android/bell-order-system-1.1.0.apk",
    "apk_size": 53248000,
    "sha256": "",
    "changelog": "Bug fixes and performance improvements",
    "release_date": "2026-03-04",
    "all_versions": [...]
  }
}
```

### GET /api/download/{slug}/{platform}/{filename}

`private/downloads/` からのファイル配信用。以下の検証を順に行う:

1. slug 検証（`bos`, `tos`, `self_station`, `osd`）
2. platform 検証（`android`, `linux`）
3. パストラバーサル防止
4. 拡張子検証（`.apk`, `.AppImage`）
5. ファイル名パターン検証（slug に対応する prefix と一致するか）
6. 認証（Bearer トークン）
7. 組織ID取得
8. サブスクリプション検証（`subscription_items` テーブルで `app_slug` と `status=active` を確認）
9. ファイル検索・ストリーミング配信

---

## public vs private

| | public/downloads/ | private/downloads/ |
|---|---|---|
| アクセス | 静的ファイルとして直接配信 | API経由（認証必須） |
| URL形式 | `/downloads/{slug}/{platform}/{filename}` | `/api/download/{slug}/{platform}/{filename}` |
| 用途 | 無料アプリ、体験版 | サブスクリプション限定 |
| 優先度 | 低 | 高（同一バージョンは private が優先） |

---

## バージョン解析ロジック

- ファイル名から正規表現でバージョンを抽出: `{prefix}-(X.Y.Z)[-x86_64].(apk|AppImage)`
- バージョンは数値比較でソート（`1.10.0 > 1.9.0`）
- 最新バージョンがページ上部に表示され、古いバージョンは「バージョン履歴」セクションに格納される
- リリース日は最新バージョンを基準に7日間隔で自動生成される（実際のファイル日時は使用しない）

---

## 注意事項

- `public/downloads/android/` に旧形式の `bos-kiosk-*.apk` が残っているが、現在のコードではスキャン対象外（削除可能）
- 新しいアプリを追加する場合は `APP_CONFIGS`（app-updates/route.ts）と `APP_FILE_PREFIXES` / `VALID_SLUGS`（download route.ts）の両方に追加が必要
