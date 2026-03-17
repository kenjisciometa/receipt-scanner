# Token Refresh 無限ループ修正案（log/customer_sessions ブランチ用）

## 対象ブランチ

- **ブランチ名**: `log/customer_sessions`
- **目的**: stage ブランチで実施した v4 修正（トークンリフレッシュ無限ループ防止）と同等の対策を、このブランチの実装に合わせて適用する。

## 現在の実装の状態

### 1. `src/lib/supabase/client.ts`

| 項目 | 現在の状態 |
|------|------------|
| クライアント作成 | `createBrowserClient`（`@supabase/ssr`）を使用。Cookie ドメイン指定あり。 |
| カスタム fetch | **なし**。`global` には `headers` のみ渡している。 |
| トークンエラー検出 | **なし**（client 側では行っていない）。 |
| リクエストブロック | **なし**。 |
| `isHandlingTokenError` / `setInvalidRefreshTokenHandler` | **なし**。 |

→ トークン更新リクエストはすべてそのままサーバーへ出ており、400 後もリトライが止まらない。

### 2. `src/contexts/AuthContext.tsx`

| 項目 | 現在の状態 |
|------|------------|
| トークンエラー検出 | **`window.fetch` の上書き**で実施。レスポンスを読んで `refresh_token_not_found` 等なら `handleInvalidRefreshToken()` を実行。 |
| リクエストブロック | **なし**。検出後にストレージクリア・リダイレクトするだけ。 |
| リダイレクト | `router.push('/auth/login?error=session_expired')`。 |
| ハンドラー登録 | client に `setInvalidRefreshTokenHandler` が存在しないため、**登録なし**。 |

→ ドキュメントの v1 と同様に「`@supabase/ssr` は `window.fetch` を直接使わない」可能性があり、検出自体が動いていない、または検出しても**ブロックしない**ためループが継続する。

### 3. `src/app/auth/callback/page.tsx`

| 項目 | 現在の状態 |
|------|------------|
| クライアント | `createClientComponentClient()`（`@supabase/auth-helpers-nextjs`）を使用。 |

→ `@/lib/supabase/client` の createClient と別クライアントになっており、カスタム fetch が効かない。

---

## stage ブランチの v4 との差分（やること）

1. **client.ts**: カスタム fetch を追加し、**エラー検出**と**以降のトークン更新リクエストのブロック**を行う。`setInvalidRefreshTokenHandler` を export する。
2. **AuthContext**: `window.fetch` インターセプターを**削除**し、client の `setInvalidRefreshTokenHandler` にハンドラーを**登録**。リダイレクトを **`window.location.replace`** に変更。
3. **auth/callback**: **`createClient()`**（`@/lib/supabase/client`）に統一。

---

## 修正案（実施手順）

### 方針: client は SSR のまま、`global.fetch` でカスタム fetch を渡す

このブランチでは `createBrowserClient`（@supabase/ssr）で Cookie ベースの永続化を使っているため、**クライアントは SSR のまま**とし、`global.fetch` にカスタム fetch を渡してトークンエラー検出・ブロックを行う。

（もし `@supabase/ssr` が `global.fetch` を使わない場合は、stage と同様に `createSupabaseClient`（@supabase/supabase-js）＋カスタム fetch に差し替える必要がある。）

---

### 修正 1: `src/lib/supabase/client.ts`

1. **追加する定数・API**
   - `isHandlingTokenError`（モジュールスコープの boolean）
   - `onInvalidRefreshToken: (() => void) | null`
   - `setInvalidRefreshTokenHandler(handler: () => void)` を **export**

2. **追加する関数**
   - `createCustomFetch()`:
     - 引数: `(input, init)` の fetch と同様。
     - **ブロック**: `isHandlingTokenError === true` かつ URL が `/auth/v1/token` かつ `grant_type=refresh_token` を含む場合、**即座に** 偽の 401 Response を返す（実際の `fetch` は呼ばない）。
     - 上記でない場合は `fetch(input, init)` を実行。
     - レスポンスが 400 または 401 かつ URL がトークン更新リクエストの場合、body を JSON でパースし、  
       `refresh_token_not_found` / `invalid_grant` / "Refresh Token Not Found" / "Invalid Refresh Token" のいずれかなら:
       - **最初に** `isHandlingTokenError = true` を代入。
       - コンソールに `[Supabase Client] Invalid refresh token detected` を出力。
       - localStorage の `sb-*` / `profile_*` / `currentOrgId` を削除。
       - Cookie の `sb-*` を削除。
       - `onInvalidRefreshToken` が設定されていれば呼び出し、なければ `window.location.replace('/auth/login?error=session_expired')`。
     - 最後にレスポンスをそのまま return。

3. **既存の createClient の変更**
   - `createSSRBrowserClient` の第3引数 `options` の `global` に、**既存の `headers` に加えて** `fetch: createCustomFetch()` を渡す。
   - 例: `global: { fetch: createCustomFetch(), headers: { ... } }`

これで、このブランチでも「検出 → フラグ → 以降のトークン更新はブロック」が client 経由の fetch に適用される。

---

### 修正 2: `src/contexts/AuthContext.tsx`

1. **import**
   - `createClient` に加え、**`setInvalidRefreshTokenHandler`** を `@/lib/supabase/client` から import。

2. **削除**
   - 「Global fetch interceptor to detect refresh token failures」の **useEffect 全体**（`window.fetch` の上書きと、その中での `handleInvalidRefreshToken` の呼び出し、クリーンアップの `window.fetch = originalFetch`）を削除。

3. **追加**
   - 新しい **useEffect** を 1 つ追加:
     - 中で `handleInvalidRefreshToken` を定義（既存と同様に `globalIsHandlingTokenError` のガード、ストレージ・キャッシュクリア、`signOut`、`setUser(null)` / `setProfile(null)` / `setAuthState('unauthenticated')`）。
     - **リダイレクトは `router.push` ではなく `window.location.replace('/auth/login?error=session_expired')` に変更。**
     - `setInvalidRefreshTokenHandler(handleInvalidRefreshToken)` を実行。
     - cleanup で `setInvalidRefreshTokenHandler(() => {})` を実行。
   - 依存配列は `[router, supabase]` または `[supabase]`（router は replace では使わないので省略可）。

4. **既存の `handleInvalidRefreshToken` のリダイレクト**
   - 上記の新しいハンドラー内で `window.location.replace('/auth/login?error=session_expired')` を使う（すでに上に含む）。

---

### 修正 3: `src/app/auth/callback/page.tsx`

1. **import**
   - `createClientComponentClient` を削除。
   - `import { createClient } from '@/lib/supabase/client'` を追加。

2. **コード内**
   - `createClientComponentClient()` を **`createClient()`** に置き換え（コールバック処理内で supabase を取得している箇所）。

---

## 実装後の確認

- 無効なリフレッシュトークンでリロードしたとき:
  - コンソールに `[Supabase Client] Invalid refresh token detected` が **1 回** 出る。
  - 続けて `[Supabase Client] Blocking token refresh request` が出る。
  - `/auth/v1/token` への POST が繰り返し発生**しない**。
  - ログイン画面に遷移し、`session_expired` のメッセージが表示される。

---

## 変更ファイル一覧

| ファイル | 変更内容 |
|----------|----------|
| `src/lib/supabase/client.ts` | カスタム fetch 追加、`isHandlingTokenError` / `setInvalidRefreshTokenHandler` 追加、`global.fetch` にカスタム fetch を渡す。 |
| `src/contexts/AuthContext.tsx` | `window.fetch` インターセプター削除、`setInvalidRefreshTokenHandler` でハンドラー登録、リダイレクトを `window.location.replace` に変更。 |
| `src/app/auth/callback/page.tsx` | `createClientComponentClient` → `createClient`（`@/lib/supabase/client`）に変更。 |

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2026-02-22 | log/customer_sessions ブランチの現状を確認し、v4 相当の修正案を作成。 |
| 2026-02-22 | 修正案に沿って実装完了。client.ts（カスタム fetch + global.fetch）、AuthContext（ハンドラー登録 + replace）、auth/callback（createClient）を変更。 |
