# SDS / KDS / CDS および WebSocket の原作者調査

**調査日**: 2026-09-21
**調査対象リポジトリ**: `order_sys`（commit 4,464件）、`websocket-server`（別リポジトリ）
**調査方法**: `git log --all --diff-filter=A` による各ファイルの初出 commit 追跡

---

## 1. 結論（要約）

| 対象 | オリジナル作製者 |
|---|---|
| **KDS（Kitchen Display System）** | **kenjiyano** — 3系統の原型 |
| **CDS（Customer Display System）** | **kenjiyano** — KDS から派生 |
| **SDS（Service Display System）** | **kenjiyano** — KDS アーキテクチャを参考に設計 |
| **WebSocket 初期デザイン（構想・チャネル設計・クライアント原型）** | **kenjiyano** |
| **WebSocket 統合サーバ（実装・アーキテクチャ文書化）** | **TunaInanamu**（kesuke.jp@gmail.com） |

---

## 2. SDS / KDS / CDS の原作者

`order_sys` リポジトリの最初の commit は `c22d233c8`（2025-08-24, kenjiyano, "first commit"）で、内容は README.md 1ファイルのみ。各ディスプレイアプリはその後、**すべて kenjiyano の手で**追加された。

### 2.1 各アプリの初出

| アプリ | 初出 commit | 日付 | 作者 |
|---|---|---|---|
| **KDS** | `34ca0c167` "fix error RBAC" | 2025-08-29 | kenjiyano |
| **CDS** | `86d06fd28` "basic cds" | 2025-09-04 | kenjiyano |
| **SDS** | `4a93af5f8` "reorg dir" | 2025-09-12 | kenjiyano |

### 2.2 KDS が原型である根拠

KDS は初出 commit `34ca0c167` の時点で既に **58ファイル**が揃っており、その中に最古の設計文書が含まれる。

- **`kds/KITCHEN_DISPLAY_APP_REQUIREMENTS.md`**（初出: `34ca0c167`, 2025-08-29, kenjiyano）
  - 3系統を通じて**最も古い設計文書**
  - Flutter / Android 7.0+ / SQLite ローカルキャッシュ / Supabase バックエンドを規定
  - 注目すべき点として、**この時点で既に "Communication: WebSocket + REST API via WiFi"** と記載があり、リアルタイム通信・自動再接続（exponential backoff）・オフラインキューが要件として設計に組み込まれている

CDS・SDS が KDS からの派生であることは、後続の設計文書自身が明記している。

- `sds/docs/Current_SDS_App_Specification.md`:
  > 「Service Display System (SDS) Flutter Appは、…**KDSアーキテクチャを参考に設計され**、Androidタブレット端末での使用を想定しています。」
- `cds/docs/CDS_Store_ID_Migration_Specification.md`:
  > "...to achieve consistency with the **Kitchen Display System (KDS)**..."

### 2.3 初期の設計文書（すべて kenjiyano 作成）

2025-09-12 に3系統の仕様書が一括で追加された。

| 文書 | 初出 commit | 作者 |
|---|---|---|
| `kds/docs/KDS_Unified_Channel_Migration_Specification.md` | `3bc94bd95` | kenjiyano |
| `cds/docs/CDS_Store_ID_Migration_Specification.md` | `b1e614d95` | kenjiyano |
| `cds/docs/CDS_Migration_Status_Report.md` | `b1e614d95` | kenjiyano |
| `sds/docs/Current_SDS_App_Specification.md` | `b1e614d95` | kenjiyano |

> **注意**: `CDS_Store_ID_Migration_Specification.md` のヘッダには `**Author**: Claude Code Assistant` と記載されているが、これは文書の清書を Claude で行ったことを示すもので、commit 作者・設計者は kenjiyano。

---

## 3. WebSocket の初期デザイン

WebSocket は **2段階**に分かれており、設計者と実装者が異なる。

### 3.1 第1段階：設計・クライアント原型 — kenjiyano（2025-09-09 〜 09-12）

Supabase Realtime から**独自 Socket.io サーバへ置き換える方針転換**と、`store_{storeId}` 統一チャネル構想は kenjiyano の設計。

| ファイル | 初出 commit | 日付 | 作者 |
|---|---|---|---|
| `kds/flutter_app/lib/services/custom_websocket_service.dart` | `e36467207` "fix kds bugs" | 2025-09-09 | kenjiyano |
| `cds/lib/services/websocket_service.dart` | `95725a53a` "fix kds cds webhook" | 2025-09-10 | kenjiyano |
| `cds/lib/services/supabase_websocket_service.dart` | `95725a53a` | 2025-09-10 | kenjiyano |
| `cds/lib/services/cds_websocket_service.dart` | `22bed98b8` "Fix WebSocket System on CDS" | 2025-09-10 | kenjiyano |
| `sds/flutter_app/lib/services/custom_websocket_service.dart` | `4a93af5f8` "reorg dir" | 2025-09-12 | kenjiyano |

方針転換の意図は、最初の CDS WebSocket サービスのコメントに明示されている。

```dart
/// WebSocket service for connecting to custom WebSocket server
/// Replaces Supabase Realtime for CDS functionality
class WebSocketService extends ChangeNotifier {
  ...
  static const String _serverUrl = 'http://10.0.2.2:9000';
```

この時点では再接続（`maxReconnectAttempts = 5`、`reconnectDelay = 2s`）、ハートビート、セッション系コールバックなど、現行設計の骨格が既に存在する。

**統一チャネル構想**も同時期の kenjiyano 作成文書で定義された。`KDS_Unified_Channel_Migration_Specification.md`（2025-09-12）は、アプリごとに分離していたチャネルを `store_{storeId}` に統合する移行計画である。

```
分離型（廃止）           →   統合型（現行）
KDS: kds_orders_{storeId}
CDS: cds_display_{displayId}  →  ALL: store_{storeId}
SDS: sds_orders_{storeId}
```

### 3.2 第2段階：統合サーバ実装・基盤化 — TunaInanamu（2025-09-23 〜）

`websocket-server` は **order_sys とは別のリポジトリ**として、TunaInanamu により新規作成された。

| 項目 | 内容 |
|---|---|
| Initial commit | `7d17f8d` — 2025-09-23, TunaInanamu (kesuke.jp@gmail.com) |
| 同梱文書 | `docs/ARCHITECTURE.md` / `docs/API.md` / `docs/UNIFIED_CHANNELS.md` |

この初回 commit の `ARCHITECTURE.md` が、現行アーキテクチャを定義している。

- **技術スタック**: Node.js 18+ / Express.js / Socket.io / PostgreSQL LISTEN/NOTIFY / JWT / Winston
- **主要機能**: 統一チャネル管理（`store_{storeId}`）、JWT 認証、PostgreSQL トリガー連携、デバイス種別によるメッセージルーティング、レート制限・チャネル暗号化・セッション管理

続く `aa42e8922`（2025-09-24, TunaInanamu）"Unified WebSocket approach: Replace KDS/SDS with CDS-style implementation" により、KDS/SDS のクライアント実装が CDS 方式へ統一され、`kds_websocket_service.dart` / `sds_websocket_service.dart` が新設された（旧実装は `.backup` として退避）。

**websocket-server リポジトリの commit 数（作者別）**

| 作者 | commit 数 |
|---|---|
| TunaInanamu | 113 |
| kenjisciometa | 44 |
| kenjiyano | 36 |
| Akihiro Tanaka | 8 |
| Sokirates | 1 |

---

## 4. その後の主な貢献者

`order_sys` リポジトリ全体の commit 数（作者別、全ブランチ）

| 作者 | commit 数 |
|---|---|
| Akihiro Tanaka (akihiro.fin@gmail.com) | 1,938 |
| TunaInanamu (kesuke.jp@gmail.com) | 1,865 |
| kenjiyano | 1,373 |
| kenjisciometa (kenji@sciometa.com) | 467 |
| Akihiro Tanaka (GitHub noreply) | 195 |
| Sokirates | 68 |
| Soki Tanaka | 59 |
| github-actions[bot] | 18 |
| Sciometa | 11 |
| Soki | 8 |

> `kenjiyano` と `kenjisciometa` / `Sciometa` は同一人物の別 identity（マシンローカル設定と GitHub アカウント）。合算すると約 1,851 commit。

KDS/SDS/CDS の後続開発では、Akihiro Tanaka が POS 側との連携仕様（`pos/docs/order/kds-cross-device-order-ready-sync-spec.md` 等）を、kenjiyano が表示系のリファクタリングと機能仕様（テーブル+時刻グルーピング、ドリンクフィルタ、会計要求通知等）を主に担当している。

---

## 5. 補足：WebSocket の変遷まとめ

```
2025-08-29  KDS 要件定義書に「WebSocket + REST API」を規定          [kenjiyano]
2025-09-09  KDS に custom_websocket_service.dart（Socket.io）       [kenjiyano]
2025-09-10  CDS の WebSocket 実装、Supabase Realtime を置換         [kenjiyano]
2025-09-12  store_{storeId} 統一チャネル移行仕様書を3系統分作成      [kenjiyano]
2025-09-19  POS に pos_websocket_service.dart                       [TunaInanamu]
2025-09-23  websocket-server リポジトリ新設 + アーキテクチャ文書     [TunaInanamu]
2025-09-24  KDS/SDS を CDS 方式へ統一                               [TunaInanamu]
2025-09-27  ReliableMessaging（MAC アドレス対応）                   [TunaInanamu]
2025-10-23  Unified WebSocket Server API/Architecture 文書整備       [TunaInanamu]
2025-10-29  BOS に WebSocket 接続を追加                             [TunaInanamu]
2026-02-04  PosWebSocketService を専用マネージャへ分割              [TunaInanamu]
2026-03-18  全アプリの WebSocket 再接続デッドコード修正             [kenjiyano]
2026-05-10  KDS/SDS の WebSocket 通知を kds_notification_helper に統一 [kenjiyano]
2026-08-14  KDS/SDS の WebSocket/イベントハンドラを mixin 化         [kenjiyano]
```
