# Token Refresh 無限ループ修正 実装案（v4）

## 概要

v3 修正後も「Invalid Refresh Token: Refresh Token Not Found」による無限ループが発生する場合の追加対策。本ドキュメントは実装案を定義し、実施内容を記録する。

関連: [fix-token-refresh-infinite-loop.md](./fix-token-refresh-infinite-loop.md)（v1〜v3 の定義）

## 現状の問題

- ログ上、`/auth/v1/token?grant_type=refresh_token` への POST が 400 のまま繰り返し発生
- ループ経路: `_handleTokenChanged` → `_notifyAllSubscribers` → `_removeSession` → `_callRefreshToken` → 再び token リクエスト
- v3 のカスタム fetch（リクエストブロック）が効いていない、または効く前に複数リクエストが発火している可能性

## 想定原因

1. **認証に別クライアントが使われている**  
   ブラウザで `getSession()` やトークン更新が動く経路で、`@/lib/supabase/client` の `createClient()` 以外（例: `createClientComponentClient`）が使われていると、カスタム fetch が通らない。

2. **フラグを立てるタイミングが遅い**  
   最初の 400 を受け取ってから `isHandlingTokenError = true` を立てるまでに、並行して別の getSession/refresh が走り、複数リクエストがサーバーに届いている。

3. **リダイレクト方法**  
   `router.push()` では Next のクライアント遷移のため、完了前に再レンダーや effect で `getSession()` が再度呼ばれうる。

4. **URL 判定**  
   環境によっては `url.includes('/auth/v1/token')` だけではトークン更新リクエストを一意に判定できない場合がある。

## 実装方針（優先順）

| 優先度 | 方針 | 内容 |
|--------|------|------|
| 1 | 認証は単一クライアントに統一 | ブラウザの認証・getSession は必ず `@/lib/supabase/client` の `createClient()` を使用する。`createClientComponentClient` 等は使わない。 |
| 2 | フラグを最優先で立てる | 無効トークンと判定したら、ストレージクリアやハンドラー呼び出しより**先に** `isHandlingTokenError = true` を代入する。 |
| 3 | リダイレクトを replace に統一 | 無効トークン検出時のログイン画面への遷移は `window.location.replace()` に統一し、遷移前に追加の getSession を防ぐ。 |
| 4 | URL 判定の強化 | トークン更新リクエストのブロック条件に `grant_type=refresh_token` を含め、誤検知・取りこぼしを防ぐ。 |

## 変更対象ファイルと内容

### 1. `src/lib/supabase/client.ts`

- **フラグを最優先で立てる**  
  無効トークン（`refresh_token_not_found` / `invalid_grant` / 該当 `error_description`）と判定した直後、同期的に**最初の一行**で `isHandlingTokenError = true` を代入する。  
  その後、localStorage・Cookie クリア、ハンドラー呼び出しを行う。

- **URL 判定の強化**  
  トークン更新リクエストのブロック条件を、  
  `url.includes('/auth/v1/token')` に加え、  
  `url.includes('grant_type=refresh_token')` も満たす場合にブロックする（または `/auth/v1/token` と `refresh_token` の両方を含む場合とする）。  
  これによりトークン更新のみを確実にブロックする。

### 2. `src/contexts/AuthContext.tsx`

- **無効トークン時のリダイレクト**  
  `handleInvalidRefreshToken` 内で、ログイン画面へ遷移する処理を `router.push('/auth/login?error=session_expired')` から  
  `window.location.replace('/auth/login?error=session_expired')` に変更する。  
  クライアント遷移による再レンダー・再 getSession を防ぐ。

### 3. `src/app/auth/callback/page.tsx`

- **クライアントの統一**  
  `createClientComponentClient()`（`@supabase/auth-helpers-nextjs`）の使用をやめ、  
  `createClient()` を `@/lib/supabase/client` から import して使用する。  
  メール確認・OAuth コールバックでもカスタム fetch 付きの同一クライアントを使い、トークン更新が必ずカスタム fetch を経由するようにする。

## 実装後の確認

- 無効なリフレッシュトークンでリロードしたとき:
  - コンソールに `[Supabase Client] Invalid refresh token detected` が 1 回出る
  - 続けて `[Supabase Client] Blocking token refresh request` が出る
  - `/auth/v1/token` への POST が繰り返し発生しない
  - ログイン画面に遷移し、`session_expired` メッセージが表示される

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2026-02-22 | v4 実装案作成。単一クライアント化・フラグ最優先・replace 統一・URL 判定強化を定義。 |
| 2026-02-22 | v4 実装完了。client.ts（フラグ最優先・isTokenRefreshRequest）、AuthContext（window.location.replace）、auth/callback（createClient に統一）を変更。 |
