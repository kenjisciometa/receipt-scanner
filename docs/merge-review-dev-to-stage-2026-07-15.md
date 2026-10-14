# Dev → Stage マージレビュー (ReactRestaurantPOS)

> レビュー日: 2026-07-15

## ブランチ状態

- dev が stage より **68 コミット** 先行
- stage が dev より **20 コミット** 先行（すべて過去のマージ PR コミット）
- 変更ファイル数: **238 files changed**, +44,642 insertions, -9,131 deletions
- 新規: 169 / 削除: 26 / 変更: 43

## 変更内容サマリー

| カテゴリ | ファイル数 | 主な内容 |
|----------|-----------|---------|
| DB/マイグレーション | 27 | auto-ordering スキーマ、carton_inventory、FIFO消費、lot/expiry追跡、product_type 削除、printer制約緩和 |
| API ルート（新規） | 40+ | suppliers, purchase-orders, recurring-orders, forecast, cron×7, recipe-bom, carton-inventory, po-suggestions |
| API ルート（削除） | 17 | 旧 inventory API 一式（add-product, adjust, alerts, initialize, templates, transactions, transfer 等） |
| API ルート（変更） | 12 | cartons CRUD, printers, products, orders/create, middleware |
| UI コンポーネント（新規） | 20+ | CartonStockTab, SuppliersTabContent, PurchaseOrdersTabContent, RecurringOrdersTabContent, RevenueForecast 等 |
| UI コンポーネント（削除） | 8 | AddProductDialog, BulkInitializeModal, InitializationBanner 等（旧 inventory UI） |
| ビジネスロジック | 25+ | deductInventory 完全書き換え、BOM展開、auto-ordering ライブラリ群、forecast エンジン |
| 設定/環境 | 2 | `.gitignore`, `.github/workflows/deploy-dev.yml` |
| ドキュメント | 17 | auto-ordering, carton, forecast 関連のスペック群 |
| ML パイプライン | 11 | 売上予測 ML モデル（Python） |

---

## ブロッカー（マージ前に解消必須）

### ~~1. `printers_print_server_fields_check` 制約の矛盾~~ → 解決済み

> **2026-07-15 DB 調査により解消確認。対応不要。**
>
> 本番 DB には `20260714121040_relax_print_server_url_constraint` が独自タイムスタンプで**適用済み**。
> dev/stage ブランチのマイグレーションファイルはどちらもそのまま本番には適用されない
> （Supabase はバージョン番号で適用済みを判定するため）。
>
> **現在の DB 制約:**
> ```sql
> CHECK ((connection_type <> 'print_server') OR (shared_secret IS NOT NULL))
> ```
> - `shared_secret IS NOT NULL` のみ必須（url はオプション）
> - 既存 print_server プリンター 2 台とも `shared_secret` あり。`shared_secret=NULL` の行は存在しない
> - dev のアプリケーションコード（`POST /api/printers`）は新規作成時に `shared_secret` を自動生成するため、今後も NULL 行は作られない
>
> stage ブランチの `20260713100000_relax_print_server_url_secret_constraint.sql` は
> DB に未適用のバージョン番号だが、マージ後にこのファイルが再適用されても
> `DROP CONSTRAINT IF EXISTS` + `ADD CONSTRAINT` のため安全に上書きされ、
> その後 `20260714121040` が適用済みとして存在するため最終状態は現在と同じ。

### ~~タイムスタンプ競合~~ → 実害なし

> **2026-07-15 DB 調査により確認。**
>
> 本番 DB のマイグレーション履歴を確認したところ、dev/stage ブランチのタイムスタンプとは
> **異なる独自のバージョン番号**で同等のマイグレーションが適用済み。
> ブランチ上のファイルのタイムスタンプが競合していても、本番 DB への再適用時に
> Supabase がバージョン番号で重複を判定するため実害はない。
>
> 参考: 本番 DB の 2026-07 以降の適用済みマイグレーション（抜粋）:
> ```
> 20260701183058_add_carton_unit
> 20260701210553_create_inventory_alerts_and_carton_inventory
> 20260702065307_add_enabled_in_bos_to_store_payment_type_settings
> 20260710122743_add_print_server_columns_to_printers
> 20260714102718_cartons_fractional_pack_size
> 20260714121040_relax_print_server_url_constraint
> 20260714133234_carton_inventory_row_per_receipt
> 20260714165326_add_printer_mappings_column
> ```
>
> dev/stage ブランチのファイル名（例: `20260701000000`, `20260704000000`）は
> DB に適用済みのバージョンとは一致しないため、マージ時に問題にならない。

### 1. 環境変数の事前設定（6個）

| 変数名 | 用途 | 必須度 |
|--------|------|--------|
| `CRON_API_KEY` | Cron エンドポイント認証（7 ルート）。`INTERNAL_API_KEY` にフォールバック | 高 |
| `INTERNAL_API_KEY` | Cron フォールバック認証。※既存の `INTERNAL_API_SECRET` とは別物 | 高 |
| `BOM_SYNC_SERVICE_KEY` | Recipe App との BOM 同期認証 | 中（Recipe App 未使用なら不要） |
| `RECIPE_APP_API_URL` | Recipe App API の Base URL | 中（同上） |
| `LOW_CARTON_PUSH_SECRET` | Low carton push webhook 認証 | 中 |
| `SUPPLIER_API_ENCRYPTION_KEY` | Supplier API 通信の暗号化キー | 中（Supplier 連携未使用なら不要） |

---

## 破壊的変更

### DB マイグレーション

| 変更 | リスク | ファイル |
|------|--------|---------|
| `DROP TABLE ingredient_carton_links CASCADE` | HIGH | `20260706000000` |
| `DROP COLUMN products.product_type` | HIGH | `20260704000000` |
| `carton_inventory` ユニーク制約削除（1行/バッチ → 1行/入荷モデル） | HIGH | `20260714100000` |
| `cartons.product_id` が NULL 許容に変更 | MEDIUM | `20260630000001` |
| `inventory_alerts.inventory_id` が NULL 許容に変更 | MEDIUM | `20260707000000` |
| `cartons.units_per_carton` が INTEGER → NUMERIC(10,4) に変更 | LOW | `20260714000000` |
| `transfer_carton_inventory` 関数シグネチャ変更（7引数 → 9引数） | MEDIUM | `20260710000002` |

### セキュリティ

| テーブル | 問題 | ファイル |
|---------|------|---------|
| `carton_inventory`, `carton_inventory_history` | RLS 無効 + `GRANT ALL` to `anon` → 匿名ユーザーが在庫データを読み書き可能 | `20260707000000` |

### API 破壊的変更

| エンドポイント | 変更内容 | リスク |
|---|---|---|
| `POST /api/cartons/issue` | `remaining_quantity` が商品単位→カートン単位に変更 | HIGH |
| `POST /api/cartons/receive` | `history_id` フィールド削除、`old_quantity`/`new_quantity` セマンティクス変更 | HIGH |
| `GET /api/cartons` | `product_id=null` のカートンが返却される | MEDIUM |
| 在庫処理コア | RPC が `process_inventory_changes` → `process_carton_inventory_changes` に完全移行 | CRITICAL |

### 削除された API / コンポーネント

旧 `/api/inventory/*` 17エンドポイント、旧 inventory UI 8コンポーネントが削除。
→ **dev 内に残存参照なし（安全）**。ただし外部クライアント（Self Station, Partner App 等）からの呼び出しがないか要確認。

---

## コンフリクト予測

- **Git テキストコンフリクト**: なし（stage 側は全てマージ PR コミットのため）
- **~~DB 制約コンフリクト~~**: ~~`printers_print_server_fields_check`~~ → 解決済み（DB に dev 版が適用済み）
- **~~マイグレーション順序~~**: ~~タイムスタンプ競合~~ → 実害なし（DB は独自バージョン番号で管理）

---

## 機能整合性

### 要確認事項

1. **在庫処理パイプラインの完全書き換え**
   - `deductInventory`, `restoreInventory`, `processOrderUpdateInventory` がすべて `carton_inventory` ベースに移行
   - マイグレーション未適用でコードデプロイすると**注文処理の在庫引き落としが全て Silent Fail する**
   - `expandBomConsumption` は `recipe_bom_cache` テーブルにデータが必要（空なら材料の在庫引き落とし不発）

2. **外部クライアントの互換性**
   - Self Station (`order_sys`) が旧 `/api/inventory/*` や `/api/stores/[id]/inventory` を呼んでいないか
   - Partner App が同様のエンドポイントを使用していないか
   - `cartons/issue`, `cartons/receive` のレスポンス形状変更の影響

3. **Carton BarcodeScanner の動作確認**
   - `CartonBarcodeScanner.tsx` が `cartons/receive` と `cartons/issue` の新レスポンスに対応済みか

4. **Supabase 拡張の確認**
   - `vault` (decrypted_secrets) と `pg_net` (http_post) が stage プロジェクトで有効か
   - push 通知マイグレーション (`20260714000001`, `20260714120000`) で必要

---

## デプロイ前チェックリスト

### マージ前（必須）

- [x] ~~`printers_print_server_fields_check` 制約の統一~~ → DB 調査により対応不要と確認
- [x] ~~マイグレーション タイムスタンプ競合~~ → DB は独自バージョン番号で管理しており実害なし
- [x] 外部クライアントが旧 `/api/inventory/*` を呼んでいないか確認 → **⚠️ POS Flutter app が大量に使用中**（詳細は後述）

### デプロイ時（DB 先行 → コードデプロイの順序を厳守）

- [ ] 環境変数 6 個の設定（ブロッカー #1）
- [ ] Supabase 拡張の確認（`vault`, `pg_net`）
- [ ] DB マイグレーション実行（27 ファイル）
- [ ] コードデプロイ

### デプロイ後（動作確認）

- [ ] 注文作成 → 在庫引き落とし（BOM 展開含む）
- [ ] 注文キャンセル → 在庫復元
- [ ] Carton バーコードスキャン（受入/払出）
- [ ] Carton Stock 画面（lot/expiry 表示、FIFO 消費順序）
- [ ] プリンター設定（WS relay 作成が制約違反にならないか）
- [ ] Purchase Order 作成 → 承認 → 送信 → 受入
- [ ] Recurring Order 設定 → cron 実行
- [ ] Low carton / Expiry push 通知
- [ ] Revenue Forecast 画面
- [ ] Supplier 管理画面

### セキュリティ（後日対応可）

- [ ] `carton_inventory` / `carton_inventory_history` の RLS + anon 権限のレビュー

---

## 総合判定: ⚠️ 条件付きで可能

Git コンフリクトは発生しない見込み。機能的な整合性は dev ブランチ内で完結している（旧 API/コンポーネントの参照は全てクリーンアップ済み）。

当初のブロッカー 3 点のうち 2 点は DB 調査により解消済み:

1. ~~Printer 制約の矛盾~~ → DB に dev 版が適用済み。対応不要
2. ~~マイグレーション タイムスタンプ競合~~ → DB は独自バージョン番号で管理。実害なし
3. **環境変数 6 個を事前設定する** → 未対応

**新たに判明した問題:**

4. ~~POS Flutter app が旧 `/api/inventory/*` を使用~~ → **在庫管理機能は未使用のため影響なし**（2026-07-15 確認）

**残りの条件:**
- 環境変数 6 個の事前設定

デプロイは **DB マイグレーション先行 → コードデプロイ** の順序を厳守すること。

---

## 付録: POS Flutter app の旧 `/api/inventory/*` 依存（2026-07-15 調査）

### 調査結果

| 対象 | 結果 |
|------|------|
| **POS Flutter app** (`order_sys/pos/flutter_app`) | **16 エンドポイントへの参照あり** — 在庫管理機能が壊れる |
| **PartnerApp** | 参照なし — 影響なし |

### 影響を受けるサービス

| ファイル | 使用エンドポイント |
|---------|-------------------|
| `lib/data/services/inventory/inventory_service.dart` | `/api/inventory` (CRUD), `/api/inventory/adjust`, `/api/inventory/transactions`, `/api/inventory/movements`, `/api/inventory/export`, `/api/inventory/import` |
| `lib/data/services/inventory/inventory_adjustment.dart` | `/api/inventory/adjust`, `/api/inventory/remove`, `/api/inventory/check-initialization`, `/api/inventory/initialize`, `/api/inventory/initialize/bulk`, `/api/inventory/transactions` |
| `lib/data/services/inventory/inventory_export.dart` | `/api/inventory/export`, `/api/inventory/import`, `/api/inventory/import/validate`, `/api/inventory/import/template` |

### 影響を受ける UI

| ファイル | 機能 |
|---------|------|
| `lib/presentation/pages/inventory/widgets/add_product_to_inventory_dialog.dart` | 在庫商品追加 |
| `lib/presentation/pages/inventory/widgets/adjust_quantity_dialog.dart` | 数量調整 |
| `lib/presentation/pages/inventory/widgets/low_stock_alerts_dialog.dart` | 低在庫アラート |
| `lib/presentation/pages/inventory/widgets/bulk_operations_dialog.dart` | 一括操作 |
| `lib/presentation/pages/products/widgets/product_form/product_availability_section.dart` | 商品在庫表示 |

### 対応方針の選択肢

**判定: マージ可能**（2026-07-15 確認）。POS Flutter app で在庫管理機能は現在使われていないため、旧エンドポイント削除の影響はない。Flutter 側の在庫コードは後日クリーンアップすればよい。

---

## 付録: 本番 DB の現在の状態（2026-07-15 時点）

### `printers_print_server_fields_check` 制約

```sql
-- 現在の本番 DB に適用されている制約（20260714121040_relax_print_server_url_constraint）
CHECK ((connection_type <> 'print_server') OR (shared_secret IS NOT NULL))
```

- `shared_secret` が NOT NULL であれば OK（`url` はオプション）
- print_server 以外の connection_type には制約なし
- 既存 print_server 行: 2 台とも `shared_secret` あり（1 台は `url` あり / 1 台は `url` なし）

### マイグレーション管理

本番 DB のマイグレーションは `supabase_migrations.schema_migrations` テーブルで管理されている。
dev/stage ブランチのマイグレーションファイルのタイムスタンプとは**異なる独自のバージョン番号**で
適用されているため、ブランチ間のファイル名・タイムスタンプの競合は本番 DB には影響しない。
