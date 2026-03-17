# Token Refresh Infinite Loop 修正定義書

## 概要

ReactRestaurantPOS において、無効なリフレッシュトークンによる無限リトライループを防止するための修正。

## 問題

- Supabase のリフレッシュトークンが無効になった場合（期限切れ、手動削除など）
- クライアントが `refresh_token_not_found` エラーを受け取っても、無限にリトライを続ける
- 結果として Supabase Auth API のレート制限（429エラー）に達する
- ユーザーがログインできなくなる

## 影響を受けるファイル

| ファイル | 変更内容 |
|---------|---------|
| `src/lib/supabase/client.ts` | カスタム fetch でトークンエラーを検出・ブロック |
| `src/contexts/AuthContext.tsx` | ハンドラー登録、セッションクリア処理 |
| `src/app/auth/login/page.tsx` | `session_expired` エラーメッセージの追加 |

## 修正内容（v3 - 2026-02-22）

### v2 が機能しなかった理由

v2 ではカスタム fetch でエラーを検出し、localStorage をクリアしてリダイレクトしていたが：

1. **リダイレクト完了前に次のリクエストが発火**される
2. **Supabase の内部リトライメカニズム**が止まらない
3. `_handleTokenChanged → _notifyAllSubscribers → _removeSession → _callRefreshToken` のループが継続

### 解決策（v3）

エラー検出後は **fetch リクエスト自体をブロック**する。

### 1. カスタム fetch（リクエストブロック機能付き）

**ファイル**: `src/lib/supabase/client.ts`

```typescript
// Flag to prevent multiple parallel redirects on token refresh failure
let isHandlingTokenError = false

// Callback to handle invalid refresh token - will be set by AuthContext
let onInvalidRefreshToken: (() => void) | null = null

export const setInvalidRefreshTokenHandler = (handler: () => void) => {
  onInvalidRefreshToken = handler
}

// Custom fetch that detects refresh token errors and blocks subsequent requests
const createCustomFetch = () => {
  return async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url

    // If we're already handling a token error, block all token refresh requests
    // This prevents the infinite loop caused by Supabase's internal retry mechanism
    if (isHandlingTokenError && url.includes('/auth/v1/token')) {
      console.warn('[Supabase Client] Blocking token refresh request - already handling error')
      // Return a fake response to prevent further retries
      return new Response(JSON.stringify({ error: 'blocked', error_description: 'Token refresh blocked due to previous error' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    const response = await fetch(input, init)

    // Check if this is a token refresh request that failed
    if (url.includes('/auth/v1/token') && (response.status === 400 || response.status === 401)) {
      const clonedResponse = response.clone()
      try {
        const data = await clonedResponse.json()
        if (
          data.error_code === 'refresh_token_not_found' ||
          data.error === 'invalid_grant' ||
          data.error_description?.includes('Refresh Token Not Found') ||
          data.error_description?.includes('Invalid Refresh Token')
        ) {
          console.error('[Supabase Client] Invalid refresh token detected:', data.error_code || data.error)

          if (!isHandlingTokenError) {
            isHandlingTokenError = true

            // Clear all Supabase-related storage immediately
            if (typeof window !== 'undefined' && window.localStorage) {
              Object.keys(localStorage).forEach(key => {
                if (key.startsWith('sb-') || key.startsWith('profile_') || key === 'currentOrgId') {
                  localStorage.removeItem(key)
                }
              })
            }

            // Clear all cookies related to Supabase
            if (typeof document !== 'undefined') {
              document.cookie.split(';').forEach(cookie => {
                const name = cookie.split('=')[0].trim()
                if (name.startsWith('sb-')) {
                  document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/`
                }
              })
            }

            // Call the handler if set, otherwise redirect
            if (onInvalidRefreshToken) {
              onInvalidRefreshToken()
            } else {
              // Fallback: redirect to login
              window.location.replace('/auth/login?error=session_expired')
            }
          }
        }
      } catch {
        // Ignore JSON parse errors
      }
    }

    return response
  }
}

// createBrowserClient に global.fetch を渡す
const ssrClient = createSSRBrowserClient(
  supabaseUrl,
  supabaseAnonKey,
  {
    ...(cookieDomain ? { cookieOptions: { domain: cookieDomain } } : {}),
    global: {
      fetch: createCustomFetch(),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'restaurant-pos-app'
      }
    }
  }
)
```

### 2. AuthContext でハンドラーを登録

**ファイル**: `src/contexts/AuthContext.tsx`

```typescript
import { createClient, setInvalidRefreshTokenHandler } from '@/lib/supabase/client'

// ==== Set up handler for invalid refresh token ====
useEffect(() => {
  const handleInvalidRefreshToken = () => {
    if (globalIsHandlingTokenError) return
    globalIsHandlingTokenError = true

    console.error('[AuthProvider] Invalid refresh token detected, clearing session')

    // Clear global cache
    Object.keys(globalFetchCache).forEach(key => {
      delete globalFetchCache[key]
    })

    // Sign out to clear session completely
    supabase.auth.signOut().catch(err => {
      console.error('[AuthProvider] Error during forced signOut:', err)
    })

    setUser(null)
    setProfile(null)
    setAuthState('unauthenticated')

    // Redirect to login
    router.push('/auth/login?error=session_expired')
  }

  // Register the handler with the Supabase client
  setInvalidRefreshTokenHandler(handleInvalidRefreshToken)

  return () => {
    // Clear the handler on cleanup
    setInvalidRefreshTokenHandler(() => {})
  }
}, [router, supabase])
```

### 3. ログイン画面での session_expired エラー表示

**ファイル**: `src/app/auth/login/page.tsx`

```tsx
{error && (
  <div className="mb-4 p-3 rounded-md bg-red-50 text-red-700 border border-red-200 text-sm text-center">
    {error === 'auth_callback_error' && 'Authentication failed. Please try again.'}
    {error === 'access_denied' && 'Access denied. Please contact your administrator.'}
    {error === 'session_expired' && 'Your session has expired. Please log in again.'}
    {error && !['auth_callback_error', 'access_denied', 'session_expired'].includes(error) && 'An error occurred. Please try again.'}
  </div>
)}
```

## 検出するエラーコード

| エラーコード/メッセージ | 説明 |
|------------------------|------|
| `refresh_token_not_found` | リフレッシュトークンがデータベースに存在しない |
| `invalid_grant` | OAuth グラント（トークン）が無効 |
| `Refresh Token Not Found` | エラー説明に含まれる文字列 |
| `Invalid Refresh Token` | エラー説明に含まれる文字列 |

## 修正後の動作フロー（v3）

```
1. 最初の /auth/v1/token リクエスト
   ↓
2. Supabase から 400 エラー + refresh_token_not_found
   ↓
3. カスタム fetch がエラーを検出
   ↓
4. isHandlingTokenError = true に設定
   ↓
5. localStorage & Cookie をクリア
   ↓
6. onInvalidRefreshToken コールバック呼び出し（またはリダイレクト）
   ↓
7. 【重要】次の /auth/v1/token リクエストが来た場合：
   - isHandlingTokenError が true なのでリクエストをブロック
   - 偽の 401 レスポンスを即座に返す
   - 実際の API コールは発生しない
   ↓
8. 無限ループ完全防止
   ↓
9. ログインページにリダイレクト
```

## v1 → v2 → v3 の変遷

### v1: window.fetch interceptor（失敗）

```typescript
// AuthContext.tsx
window.fetch = async (...args) => {
  // Supabase のリクエストをキャッチしようとしたが...
}
```

**問題**: `@supabase/ssr` は `window.fetch` を直接使用しない。

### v2: カスタム fetch を Supabase に渡す（部分的成功）

```typescript
createSSRBrowserClient(url, key, {
  global: {
    fetch: createCustomFetch()
  }
})
```

**問題**: エラー検出後もリクエストが継続。リダイレクト完了前に次のリトライが発火。

### v3: リクエストブロック機能追加（成功）

```typescript
if (isHandlingTokenError && url.includes('/auth/v1/token')) {
  // 偽のレスポンスを返してリクエストをブロック
  return new Response(JSON.stringify({ error: 'blocked' }), { status: 401 })
}
```

**解決**: フラグが立っている間は全ての token refresh リクエストを即座にブロック。

## テスト方法

1. ログイン状態でブラウザの開発者ツールを開く
2. Application → Storage → Local Storage で `sb-*` キーを確認
3. リフレッシュトークンの値を無効な値に変更
4. ページをリロード
5. 期待動作:
   - コンソールに `[Supabase Client] Invalid refresh token detected` が1回表示される
   - 続けて `[Supabase Client] Blocking token refresh request` が表示される
   - 無限ループは発生しない
   - ログイン画面にリダイレクトされる

## Git コミット履歴

```bash
# v3 コミット
git commit -m "fix: block subsequent token refresh requests after error detection

- When refresh_token_not_found is detected, block all further /auth/v1/token requests
- Return fake 401 response to prevent Supabase internal retry loops
- Also clear cookies in addition to localStorage
- Use window.location.replace instead of href for more reliable redirect"
```

## 更新履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2026-02-20 | v1 | 初版 - window.fetch interceptor（機能せず） |
| 2026-02-22 | v2 | カスタム fetch を Supabase クライアントに渡す方式に変更（部分的成功） |
| 2026-02-22 | v3 | リクエストブロック機能追加、Cookie クリア追加 |

## 作成者

Claude Code
