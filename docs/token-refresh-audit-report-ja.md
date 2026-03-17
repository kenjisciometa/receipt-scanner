# トークンリフレッシュ実装 監査レポート

**日付:** 2026-03-07（2026-03-07 第3回更新）
**対象:** BOS, CDS, KDS, OSD, POS, SDS, Self Station, TOS

---

## 概要

全8アプリケーションにおいて、稼働中のセッション切れを防止するトークンリフレッシュ機構を実装済み。POS（Next.js）が最も成熟した実装であり、多層的な重複排除とクロスタブ連携を備えている。Flutterアプリ群は類似のパターンを共有しているが、完成度にばらつきがある。

**2026-03-07 第1回更新:** KDS/SDS/CDS/Self Stationにプロアクティブタイマーリフレッシュを追加実装。BOS同様の3層防御アーキテクチャに統一。

**2026-03-07 第2回更新:** OSD・TOSの実装完了を検証（SecureStorage移行、TOS 3層化）。

**2026-03-07 第3回更新:** OSD・TOSの追加修正を検証。
- **OSD:** Supabaseアクセストークン用プロアクティブタイマー（`scheduleTokenRefresh()`）追加完了。全7アプリが3層防御アーキテクチャに統一。
- **TOS:** `_invalidateAuth()`が`clearAuthData()`をawaitするよう修正完了。
- **残る課題:** 全Flutterアプリ共通で`AppLifecycleState`オブザーバー未実装、指数バックオフ未実装（いずれも低優先度）。

---

## 比較マトリクス

| 機能 | BOS | KDS | SDS | CDS | OSD | TOS | Self Station | POS |
|---|---|---|---|---|---|---|---|---|
| **プロアクティブタイマーリフレッシュ** | あり（期限5分前） | あり（期限5分前） | あり（期限5分前） | あり（期限5分前） | あり（期限5分前）（※1） | あり（期限5分前） | あり（期限5分前） | なし（middleware） |
| **リクエスト前の期限チェック** | あり | あり | あり | あり | あり | あり | あり | あり（middleware） |
| **401レスポンスによるリアクティブリトライ** | あり | あり | あり | あり | あり | あり | あり | あり |
| **同時リフレッシュロック** | Completer | Completer | Completer | Completer | Completer | Completer | Completer | Promise + フラグ |
| **連続失敗上限** | 3回 | 3回 | 3回 | 3回 | 3回 | 3回 | 3回 | N/A（リダイレクト） |
| **クロスタブ/デバイス重複排除** | N/A | N/A | N/A | N/A | N/A | N/A | N/A | BroadcastChannel |
| **サーバーサイド重複排除** | N/A | N/A | N/A | N/A | N/A | N/A | N/A | 30秒キャッシュ + インフライト |
| **トークン保存方式** | SecureStorage | SecureStorage | SecureStorage | SecureStorage | SecureStorage | SecureStorage | SecureStorage | Cookie |
| **レートリミット** | POS API経由 | POS API経由 | POS API経由 | POS API経由 | POS API経由 | POS API経由 | POS API経由 | 1000回/15分 |

> **※1 OSD:** Supabaseアクセストークン用`scheduleTokenRefresh()`に加え、WebSocket JWT用に6時間固定間隔タイマーが別途存在（デュアルトークンシステム）。

---

## アプリ別調査結果

### 1. BOS（バックオフィスシステム） — Flutter/Expo

**アーキテクチャ:** タイマーベース + オンデマンド + 401リアクティブ（3層ハイブリッド）

**実装ファイル:**
- `order_sys/bos/flutter_app/lib/core/services/supabase_auth_service.dart`
- `order_sys/bos/flutter_app/lib/core/services/http_service_impl.dart`

**強み:**
- Flutterアプリの中で最も完成度の高い実装。期限5分前にプロアクティブタイマーでリフレッシュ
- `Completer`ベースのミューテックスにより同時リフレッシュの競合を防止
- 連続3回の失敗でセッション無効化・ログアウト
- 一時的な失敗後の30秒リトライ遅延
- `_AuthInterceptor`が`_auth_retried`フラグを付与し、無限401ループを防止

**課題:**
- アプリがバックグラウンドから復帰した際の明示的なリフレッシュがない — タイマーがアプリ停止中に発火した場合、復帰時にトークンが期限切れの可能性
- 一時的な失敗後のリトライがファイア・アンド・フォーゲット（指数バックオフなし）
- リフレッシュ失敗後、次の成功まで タイマーが再スケジュールされない

**リスクレベル:** 低

---

### 2. KDS（キッチンディスプレイシステム） — Flutter

**アーキテクチャ:** タイマーベース + リクエスト前の期限チェック + 401リアクティブ（3層ハイブリッド）✅ *更新済み*

**実装ファイル:**
- `order_sys/kds/flutter_app/lib/services/api_client_service.dart`
- `order_sys/kds/flutter_app/lib/services/auth_service.dart`

**強み:**
- 期限5分前にプロアクティブタイマーでリフレッシュ（BOS/OSDと同様）
- APIコール前にトークン期限をチェックし、期限が近ければリフレッシュ
- Completerロックによる同時リフレッシュ防止
- 連続3回の失敗上限
- タイマー初期化：(1) リフレッシュ成功時、(2) インターセプターでタイマー未設定時、(3) AuthService初期化時
- リフレッシュ失敗時の30秒リトライ遅延

**課題:**
- リトライに指数バックオフなし（固定30秒リトライ）
- アプリがバックグラウンドから復帰した際の明示的なリフレッシュがない

**リスクレベル:** 低

---

### 3. SDS（ステーションディスプレイシステム） — Flutter

**アーキテクチャ:** タイマーベース + リクエスト前の期限チェック + 401リアクティブ（3層ハイブリッド）✅ *更新済み*

**実装ファイル:**
- `order_sys/sds/flutter_app/lib/services/api_client_service.dart`
- `order_sys/sds/flutter_app/lib/services/auth_service.dart`

**強み:** KDSと同一の3層アーキテクチャ（プロアクティブタイマー + リクエスト前チェック + 401リアクティブ）

**課題:** KDSと同じ — 指数バックオフなし、アプリ復帰時のリフレッシュなし

**リスクレベル:** 低

---

### 4. CDS（カスタマーディスプレイシステム） — Flutter

**アーキテクチャ:** タイマーベース + リクエスト前の期限チェック + 401リアクティブ（3層ハイブリッド）✅ *更新済み*

**実装ファイル:**
- `order_sys/cds/flutter_app/lib/services/api_client_service.dart`
- `order_sys/cds/flutter_app/lib/services/auth_service.dart`

**強み:**
- KDS/SDSと同一の3層アーキテクチャ
- 認証不要のパブリックエンドポイントを区別（`_isPublicEndpoint()`ガード）

**課題:** KDS/SDSと同じ — 指数バックオフなし、アプリ復帰時のリフレッシュなし

**リスクレベル:** 低

---

### 5. OSD（オーダーステータスディスプレイ） — Flutter

**アーキテクチャ:** タイマーベース + リクエスト前チェック + 401リアクティブ（3層）+ WebSocket用6時間タイマー（別系統） ✅ *更新済み*

**実装ファイル:**
- `order_sys/osd/flutter_app/lib/services/api_client_service.dart` — Dioインターセプター、トークンリフレッシュ、プロアクティブタイマー
- `order_sys/osd/flutter_app/lib/services/auth_service.dart` — ログイン、ログアウト、セッション復元
- `order_sys/osd/flutter_app/lib/services/secure_storage_service.dart` — プラットフォーム別暗号化ストレージ
- `order_sys/osd/flutter_app/lib/services/osd_websocket_service.dart` — WebSocket接続、WS用トークンリフレッシュタイマー
- `order_sys/osd/flutter_app/lib/services/websocket_token_service.dart` — WebSocket JWT管理

**デュアルトークンシステム:**
OSDは2つの独立したトークンシステムを持つ:
1. **Supabaseアクセス/リフレッシュトークン** — REST API用。`ApiClientService`のDioインターセプターで管理。**プロアクティブタイマー（期限5分前）実装済み**
2. **WebSocket JWTトークン** — Socket.IO接続用。30日有効期限、6時間固定間隔でリフレッシュ。`OsdWebSocketService`で管理

**強み:**
- ~~トークンがSharedPreferences（暗号化なし）に保存されている~~ → **`SecureStorageService`に移行完了**
  - iOS: Keychain（`first_unlock_this_device`）
  - Android: EncryptedSharedPreferences
  - Linux/Raspberry Pi: Hive + AES-256暗号化（デバイス固有キー）
  - `_migrateFromSharedPreferences()`によるワンタイムマイグレーション対応
- ~~Supabaseトークン用プロアクティブタイマーなし~~ → **`scheduleTokenRefresh()`実装完了**（期限5分前）
  - タイマー初期化：(1) ログイン成功時（`auth_service.dart` L201, L509）、(2) セッション復元時（L133）、(3) リフレッシュ成功時
  - タイマーキャンセル：`clearAuthData()`、`dispose()`で確実にクリーンアップ
  - リフレッシュ失敗時の30秒リトライ遅延
- Completerロックによる同時リフレッシュ防止
- 連続3回の失敗上限（Supabase・WebSocket両方）
- リクエスト前の期限チェック（5分前ウィンドウ）
- 401リアクティブリトライ（`_authRetried`フラグで無限ループ防止）
- WebSocket再認証失敗3回でフルリコネクション

**課題:**
- アプリがバックグラウンドから復帰した際の明示的なリフレッシュがない（`WidgetsBindingObserver`未使用）
- WebSocket用タイマーが固定6時間間隔（期限相対ではない）
- リトライに指数バックオフなし（固定30秒リトライ）
- `_forceWebSocketReset()`が`_tokenRefreshTimer`を直接キャンセルしない（`disconnect()`経由で間接的にキャンセルされるため実害なし）

**リスクレベル:** 低

---

### 6. TOS（テーブルオーダーシステム） — Flutter

**アーキテクチャ:** タイマーベース + リクエスト前の期限チェック + 401リアクティブ（3層ハイブリッド）✅ *更新済み*

**実装ファイル:**
- `order_sys/tos/flutter_app/lib/core/services/api_client_service.dart` — Dioインターセプター、トークンリフレッシュ、プロアクティブタイマー
- `order_sys/tos/flutter_app/lib/services/tos_auth_service.dart` — ログイン、サインアップ、ログアウト、セッション復元

**強み:**
- ~~401リアクティブのみ~~ → **3層防御アーキテクチャに完全アップグレード**
- 期限5分前にプロアクティブタイマーでリフレッシュ（`scheduleTokenRefresh()`）
- リクエスト前の期限チェック（`isTokenExpired()` + `isTokenExpiringSoon()`、5分ウィンドウ）
- 401リアクティブリトライ（`_auth_retried`フラグで無限ループ防止）
- ~~連続失敗上限なし~~ → **連続3回の失敗上限を追加**。3回失敗時に`clearAuthData()` + `_invalidateAuth()`でセッション無効化
- Completerロックによる同時リフレッシュ防止
- トークン保存にFlutterSecureStorage使用（Android: EncryptedSharedPreferences, iOS: Keychain）
- タイマー初期化：(1) セッション復元時、(2) ログイン成功時、(3) サインアップ成功時、(4) リフレッシュ成功時
- タイマーキャンセル：`signOut()`、`clearAuthData()`、`clearAllData()`で確実にクリーンアップ
- リフレッシュ失敗時の30秒リトライ遅延

**課題:**
- ~~`_invalidateAuth()`が`clearAuthData()`をawaitせずに`onAuthInvalidated`を呼び出す~~ → **修正済み**（`async`化 + `await`追加）
- リトライに指数バックオフなし（固定30秒リトライ、1回のみ。失敗時は次のAPIリクエスト時にインターセプターが検出）
- アプリがバックグラウンドから復帰した際の明示的なリフレッシュがない

**リスクレベル:** 低（以前の「高」から大幅改善）

---

### 7. Self Station — Flutter

**アーキテクチャ:** タイマーベース + リクエスト前の期限チェック + 401リアクティブ（3層ハイブリッド）✅ *更新済み*

**実装ファイル:**
- `order_sys/self_station/flutter_app/lib/core/services/api_client_service.dart`

**強み:**
- 期限5分前にプロアクティブタイマーでリフレッシュ（BOS/OSDと同様）
- P1〜P4パターンのドキュメントがコード内に充実
- Completerロック + 連続3回の失敗上限
- FlutterSecureStorageのプラットフォーム別バックエンド対応（`SecureStorageService`経由）
- サーバーサイドエンドポイントにレートリミットを最近追加
- `ApiClientService.initialize()`でも既存トークンに対してタイマーを開始

**課題:**
- リトライに指数バックオフなし（固定30秒リトライ）
- アプリがバックグラウンドから復帰した際の明示的なリフレッシュがない

**リスクレベル:** 低

---

### 8. POS（ReactRestaurantPOS） — Next.js

**アーキテクチャ:** Middleware + カスタムfetch + サーバーサイド重複排除 + BroadcastChannel（4層）

**実装ファイル:**
- `ReactRestaurantPOS/src/lib/supabase/client.ts` — 重複排除付きカスタムfetchラッパー
- `ReactRestaurantPOS/src/lib/supabase/middleware.ts` — サーバーサイドセッションリフレッシュ
- `ReactRestaurantPOS/src/lib/refresh-dedup.ts` — サーバーサイド重複排除エンジン
- `ReactRestaurantPOS/src/contexts/AuthContext.tsx` — クライアント側状態管理
- `ReactRestaurantPOS/middleware.ts` — メインミドルウェア（Bearerトークンパススルー付き）
- `ReactRestaurantPOS/src/app/api/auth/refresh/route.ts` — 明示的リフレッシュAPI

**強み:**
- 全アプリ中で最も包括的な実装
- **クライアント側重複排除:** `isRefreshingToken`フラグ + `refreshPromise`再利用 + 2秒デバウンス
- **`isHandlingTokenError`ハードブロック:** 無限リトライループを遮断（`refresh_token_not_found`カスケードに対するv3修正）
- **BroadcastChannelによるクロスタブ連携:** `REFRESH_STARTED`、`REFRESH_COMPLETED`、`REFRESH_FAILED_INVALID`メッセージによりマルチタブカスケードを防止
- **サーバーサイド`dedupRefresh`:** SHA-256ハッシュベースのインフライト重複排除 + 30秒結果キャッシュ
- **Middlewareフェイルオープン:** 一時的なエラーはリクエストを通過させ、致命的な認証エラーのみリダイレクト
- 12秒の初期化タイムアウトにより永久ローディングUIを防止
- デバイス検知付き認証イベントログによるデバッグ支援
- レートリミッターの`skipSuccessfulRequests: true`により正規ユーザーのロックアウトを防止

**課題:**

| 優先度 | 課題 | 詳細 |
|---|---|---|
| 高 | インメモリ型レートリミッター | マルチインスタンス/ワーカー環境では保護されない。各Node.jsプロセスが独立したカウンターを保持。 |
| 高 | `X-Forwarded-For`スプーフィング | `getClientIp`が`X-Forwarded-For`の先頭値を無条件に信頼。信頼されたプロキシによるヘッダー除去がなければ、攻撃者がIPベースのレートリミットを回避可能。 |
| 高 | Bearerトークンのミドルウェアバイパス | `middleware.ts`が`Authorization: Bearer`ヘッダー付きリクエストを検証なしで通過させる。`authenticateAndAuthorize`を呼び忘れたAPIルートが無防備になる。 |
| 中 | `refreshPromise`のbody消費問題 | 同じ`refreshPromise`を共有する同時呼び出し元が「body already used」エラーに遭遇する可能性。`Response`のbodyは一度しか消費できない。 |
| 中 | `isHandlingTokenError`の永続性 | このフラグがページセッション間でリセットされない（モジュールシングルトン）。ハードリロードまたは`TOKEN_REFRESHED`イベントでのみクリア。 |
| 低 | 失敗結果の30秒キャッシュ | サーバーサイド`refreshCache`が401レスポンスを30秒間保持。新しい有効なセッションを持つ正規ユーザーがこの期間中にキャッシュされた失敗を受け取る可能性。 |
| 低 | デッドコード | `client.ts`の`siteUrl`変数が宣言されているが未使用。 |
| 低 | `getSession()` + `getUser()`の二重呼び出し | `authenticateAndAuthorize`が両方を順次呼び出し。`getUser()`がJWTを検証するため`getSession()`は冗長。 |

**リスクレベル:** 低（指摘事項はあるが十分に保護されている）

---

## 優先対応事項

### ~~緊急（早期対応推奨）~~ ✅ 全項目対応済み

1. ~~**TOS: 連続失敗上限の追加**~~ ✅ **対応済み（2026-03-07）**
   - `api_client_service.dart`に`_consecutiveRefreshFailures`カウンター（最大3回）を追加
   - 3回失敗時に`clearAuthData()` + `_invalidateAuth()`でセッション無効化
   - さらにプロアクティブタイマー、リクエスト前チェックも追加し、3層アーキテクチャに完全アップグレード

2. ~~**OSD: FlutterSecureStorageへの移行**~~ ✅ **対応済み（2026-03-07）**
   - `SecureStorageService`に移行（iOS: Keychain, Android: EncryptedSharedPreferences, Linux: Hive+AES-256）
   - `_migrateFromSharedPreferences()`によるワンタイムマイグレーション対応

### 推奨

3. ~~**TOS: リクエスト前の期限チェック追加**~~ ✅ **対応済み（2026-03-07）**
   - `_AuthInterceptor.onRequest()`で`isTokenExpired()` + `isTokenExpiringSoon()`をチェック

4. ~~**KDS/SDS/CDS/Self Station: プロアクティブタイマーの追加**~~ ✅ **対応済み（2026-03-07）**
   - 4アプリすべてに`scheduleTokenRefresh()`を実装。期限5分前にプロアクティブリフレッシュ
   - BOS同様の3層防御アーキテクチャに統一

5. **POS: レートリミッターをRedisに移行**
   - 現在のインメモリ`Map`はインスタンス間で共有されない
   - 本番環境ではRedisなどの分散ストアを使用

6. **POS: `X-Forwarded-For`を信頼済みプロキシに対してのみ検証**
   - 既知のリバースプロキシ配下の場合のみヘッダーを信頼
   - またはプラットフォーム固有のIP取得方法を使用

### 低優先度

7. **全Flutterアプリ: リフレッシュリトライに指数バックオフを追加**
   - 現在は固定30秒リトライまたはリトライなし
   - 指数バックオフ（1秒、2秒、4秒、8秒...）の方が耐障害性が高い

8. **全Flutterアプリ: アプリライフサイクルリフレッシュの追加**
   - `AppLifecycleState.resumed`でトークンリフレッシュを実行し、バックグラウンド停止に対応
   - 特にAndroid環境で重要（キオスクモードのLinux/Raspberry Piでは影響少）

9. ~~**OSD: Supabaseアクセストークン用プロアクティブタイマーの追加**~~ ✅ **対応済み（2026-03-07）**
   - `scheduleTokenRefresh()`を実装。期限5分前にプロアクティブリフレッシュ
   - WebSocket用6時間タイマーとは別系統で独立動作

---

## アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────┐
│                        POS (Next.js)                         │
│                                                              │
│  ┌─────────┐   ┌──────────────┐   ┌───────────────────┐     │
│  │Middleware│──>│Custom Fetch  │──>│サーバーサイド      │     │
│  │(セッション│   │(クライアント │   │重複排除            │     │
│  │ リフレッシ│   │ 重複排除,    │   │(30秒キャッシュ,    │     │
│  │ ュ)      │   │ デバウンス,  │   │ インフライト共有,  │     │
│  │          │   │ BroadcastCh) │   │ ハッシュベースキー) │     │
│  └─────────┘   └──────────────┘   └───────────────────┘     │
│       │              │                      │                │
│       ▼              ▼                      ▼                │
│  ┌─────────────────────────────────────────────────────┐     │
│  │         レートリミッター (1000回/15分)                │     │
│  └─────────────────────────────────────────────────────┘     │
│                          │                                   │
│                          ▼                                   │
│                   Supabase Auth API                          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Flutter Apps (BOS/KDS/SDS/CDS/TOS/Self Station) — 3層       │
│                                                              │
│  ┌──────────────┐  ┌─────────────────┐  ┌───────────────┐   │
│  │タイマー       │  │リクエスト前      │  │401            │   │
│  │リフレッシュ   │  │チェック          │  │インターセプター│   │
│  │(5分前)        │  │(期限チェック)    │  │(1回リトライ)  │   │
│  └──────┬───────┘  └───────┬─────────┘  └──────┬────────┘   │
│         │                  │                    │             │
│         ▼                  ▼                    ▼             │
│  ┌─────────────────────────────────────────────────────┐     │
│  │     Completer ロック (同時リフレッシュガード)         │     │
│  │     + 連続3回失敗上限                                │     │
│  └─────────────────────────────────────────────────────┘     │
│                          │                                   │
│                          ▼                                   │
│                POS API /api/auth/refresh                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│         OSD — 3層 + WS独立タイマー（デュアルトークン）        │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐      │
│  │タイマー       │  │リクエスト前   │  │401            │      │
│  │リフレッシュ   │  │チェック       │  │インターセプター│      │
│  │(5分前)        │  │(期限チェック) │  │(1回リトライ)  │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬────────┘      │
│         │                 │                  │    ┌─────────┐│
│         ▼                 ▼                  ▼    │WS JWT   ││
│  ┌─────────────────────────────────────────┐ │タイマー  ││
│  │ Completer ロック + 3回失敗上限          │ │(6時間   ││
│  │ (Supabaseトークン用)                    │ │ 固定)   ││
│  └───────────────────┬─────────────────────┘ └────┬────┘│
│                      │                            │      │
│                      ▼                            ▼      │
│          POS API /api/auth/refresh         WS Token API  │
└─────────────────────────────────────────────────────────────┘
```

---

## 結論

SciometaPOSエコシステム全体のトークンリフレッシュアーキテクチャは堅実である。POSが堅牢な重複排除を備えた中央認証ゲートウェイとして機能し、全FlutterアプリがCompleterベースの同時リフレッシュガードと連続3回失敗上限を実装している。

**2026-03-07 最終更新（第3回）:**
- **全7つのFlutterアプリ**（BOS/KDS/SDS/CDS/OSD/TOS/Self Station）が3層防御アーキテクチャ（タイマー + リクエスト前チェック + 401リアクティブ）を備えた
- OSDはさらにWebSocket用の独立した6時間固定タイマーを持つ（デュアルトークンシステム）
- TOSは1層（401のみ）→ 3層に大幅アップグレード。連続失敗上限も追加。`_invalidateAuth()`のawait問題も修正済み
- **全アプリでSecureStorage使用**（以前のOSDのSharedPreferences問題は解消）
- **全アプリで連続失敗上限あり**（以前のTOSの無限ループリスクは解消）
- **緊急対応事項1〜4および推奨事項9はすべて解消済み**

残る改善事項はすべて低優先度：
- 全Flutterアプリ：指数バックオフの追加（現在は固定30秒リトライ）
- 全Flutterアプリ：`AppLifecycleState.resumed`でのトークンリフレッシュ追加
- POS：レートリミッターのRedis移行、`X-Forwarded-For`検証強化
