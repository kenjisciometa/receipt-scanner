# Token Refresh Implementation Audit Report

**Date:** 2026-03-07
**Scope:** BOS, CDS, KDS, OSD, POS, SDS, Self Station, TOS

---

## Executive Summary

All 8 applications implement token refresh mechanisms to prevent session expiry during operation. The POS (Next.js) has the most mature implementation with multi-layer deduplication and cross-tab coordination. Flutter apps share similar patterns but vary in completeness. Key issues found: TOS lacks a consecutive failure limit, and the POS in-memory rate limiter does not protect multi-instance deployments. ~~OSD's unencrypted token storage~~ has been resolved (2026-03-07).

---

## Comparison Matrix

| Feature | BOS | KDS | SDS | CDS | OSD | TOS | Self Station | POS |
|---|---|---|---|---|---|---|---|---|
| **Proactive timer refresh** | Yes (5min before) | No | No | No | Yes (5min before) | No | No | No (middleware) |
| **Pre-request expiry check** | Yes | Yes | Yes | Yes | Yes | No | Yes | Yes (middleware) |
| **Reactive 401 retry** | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| **Concurrent refresh lock** | Completer | Completer | Completer | Completer | Completer | Completer | Completer | Promise + flags |
| **Consecutive failure limit** | 3 | 3 | 3 | 3 | 3 | **None** | 3 | N/A (redirect) |
| **Cross-tab/device dedup** | N/A | N/A | N/A | N/A | N/A | N/A | N/A | BroadcastChannel |
| **Server-side dedup** | N/A | N/A | N/A | N/A | N/A | N/A | N/A | 30s cache + in-flight |
| **Token storage** | SecureStorage | SecureStorage | SecureStorage | SecureStorage | SecureStorage | SecureStorage | SecureStorage | Cookies |
| **Rate limiting** | Via POS API | Via POS API | Via POS API | Via POS API | Via POS API | Via POS API | Via POS API | 1000/15min |

---

## Per-App Findings

### 1. BOS (Back Office System) — Flutter/Expo

**Architecture:** Timer-based + on-demand + 401 reactive (3-layer hybrid)

**Implementation files:**
- `order_sys/bos/flutter_app/lib/core/services/supabase_auth_service.dart`
- `order_sys/bos/flutter_app/lib/core/services/http_service_impl.dart`

**Strengths:**
- Most complete Flutter implementation with proactive timer (5 min before expiry)
- `Completer`-based mutex prevents concurrent refresh races
- 3 consecutive failure limit triggers session expiry and logout
- 30-second retry delay after transient failures
- `_AuthInterceptor` adds `_auth_retried` flag to prevent infinite 401 loops

**Issues:**
- No explicit refresh on app resume from background — if the timer fires while app is suspended, token may be expired when app resumes
- Fire-and-forget retry after transient failure (no exponential backoff)
- Timer not rescheduled after a failed retry until the next successful refresh

**Risk Level:** Low

---

### 2. KDS (Kitchen Display System) — Flutter

**Architecture:** Pre-request expiry check + 401 reactive (2-layer)

**Implementation files:**
- `order_sys/kds/flutter_app/lib/core/services/supabase_auth_service.dart`
- `order_sys/kds/flutter_app/lib/core/services/http_service_impl.dart`

**Strengths:**
- Pre-request check refreshes token before API calls if close to expiry
- Completer lock prevents concurrent refreshes
- 3 consecutive failure limit
- Shares same proven patterns as BOS (minus timer)

**Issues:**
- No proactive timer — relies entirely on API call frequency for refresh
- If KDS is idle (no orders), token could expire without triggering refresh
- No exponential backoff on retry

**Risk Level:** Low-Medium (idle periods could cause token expiry)

---

### 3. SDS (Station Display System) — Flutter

**Architecture:** Pre-request expiry check + 401 reactive (2-layer)

**Implementation:** Nearly identical to KDS

**Strengths:** Same as KDS

**Issues:** Same as KDS — idle periods without API calls could cause token expiry

**Risk Level:** Low-Medium

---

### 4. CDS (Customer Display System) — Flutter

**Architecture:** Pre-request expiry check + 401 reactive (2-layer)

**Implementation:** Same pattern as KDS/SDS

**Strengths:**
- Same Completer lock and failure limit pattern
- Distinguishes public endpoints that don't require auth

**Issues:** Same idle-period risk as KDS/SDS

**Risk Level:** Low-Medium

---

### 5. OSD (Order Status Display) — Flutter

**Architecture:** Timer-based + pre-request expiry check + 401 reactive (3-layer hybrid)

**Implementation files:**
- `order_sys/osd/flutter_app/lib/core/services/supabase_auth_service.dart`
- `order_sys/osd/flutter_app/lib/core/services/http_service_impl.dart`

**Strengths:**
- Proactive timer refresh (5 min before expiry) with 30s retry on failure
- Pre-request check refreshes token before API calls if close to expiry
- 3 consecutive failure limit
- Completer lock prevents concurrent refreshes
- Token storage uses `SecureStorageService` with platform-specific backends (Keychain/EncryptedSharedPreferences/Hive AES-256)
- One-time migration from SharedPreferences to SecureStorage for existing users

**Issues:**
- No explicit refresh on app resume from background — if the timer fires while app is suspended, token may be expired when app resumes

**Risk Level:** Low

**Resolved:**
- ~~Token stored in SharedPreferences (unencrypted)~~ — Migrated to `SecureStorageService` (2026-03-07)
- ~~No proactive timer~~ — Added timer-based refresh (2026-03-07)

---

### 6. TOS (Table Order System) — Flutter

**Architecture:** 401 reactive only (1-layer)

**Implementation files:**
- `order_sys/tos/flutter_app/lib/core/services/supabase_auth_service.dart`
- `order_sys/tos/flutter_app/lib/core/services/http_service_impl.dart`

**Strengths:**
- Uses FlutterSecureStorage for token storage
- Completer lock for concurrent refresh prevention

**Issues:**
- **No proactive refresh** — no timer, no pre-request expiry check
- **No consecutive failure limit** — failed refreshes retry indefinitely, risking infinite loop
- Relies entirely on 401 responses to trigger refresh, which means every expired-token request fails once before retry
- Most vulnerable to token expiry during idle periods

**Risk Level:** High

**Recommendations:**
1. Add consecutive failure limit (3, matching other apps)
2. Add pre-request expiry check (at minimum)
3. Consider adding proactive timer if TOS runs for extended periods

---

### 7. Self Station — Flutter

**Architecture:** Pre-request expiry check + 401 reactive (2-layer)

**Implementation files:**
- `order_sys/self_station/flutter_app/lib/core/services/supabase_auth_service.dart`
- `order_sys/self_station/flutter_app/lib/core/services/http_service_impl.dart`

**Strengths:**
- Well-documented with P1-P4 pattern documentation in code
- Completer lock with 3 consecutive failure limit
- FlutterSecureStorage with platform-specific backends
- Rate limiting recently added to server-side endpoints

**Issues:**
- No proactive timer — relies on API call frequency
- Self Station is customer-facing, so idle periods between customers could cause token expiry

**Risk Level:** Low-Medium

---

### 8. POS (ReactRestaurantPOS) — Next.js

**Architecture:** Middleware + custom fetch + server-side dedup + BroadcastChannel (4-layer)

**Implementation files:**
- `ReactRestaurantPOS/src/lib/supabase/client.ts` — Custom fetch wrapper with dedup
- `ReactRestaurantPOS/src/lib/supabase/middleware.ts` — Server-side session refresh
- `ReactRestaurantPOS/src/lib/refresh-dedup.ts` — Server-side deduplication engine
- `ReactRestaurantPOS/src/contexts/AuthContext.tsx` — Client state management
- `ReactRestaurantPOS/middleware.ts` — Main middleware with Bearer passthrough
- `ReactRestaurantPOS/src/app/api/auth/refresh/route.ts` — Explicit refresh API

**Strengths:**
- Most comprehensive implementation across all apps
- **Client-side dedup:** `isRefreshingToken` flag + `refreshPromise` reuse + 2s debounce
- **`isHandlingTokenError` hard block:** Breaks infinite retry loops (v3 fix for `refresh_token_not_found` cascade)
- **BroadcastChannel cross-tab coordination:** `REFRESH_STARTED`, `REFRESH_COMPLETED`, `REFRESH_FAILED_INVALID` messages prevent multi-tab cascades
- **Server-side `dedupRefresh`:** SHA-256 hash-based in-flight deduplication + 30s result cache
- **Middleware fail-open:** Transient errors allow request through; only fatal auth errors redirect
- 12-second initialization timeout prevents permanently loading UI
- Auth event logging with device detection for debugging
- `skipSuccessfulRequests: true` on rate limiter prevents legitimate user lockout

**Issues:**

| Priority | Issue | Detail |
|---|---|---|
| High | In-memory rate limiter | No protection in multi-instance/worker deployments. Each Node.js process has independent counters. |
| High | `X-Forwarded-For` spoofing | `getClientIp` trusts first value of `X-Forwarded-For` unconditionally. Without a trusted proxy stripping this header, attackers bypass IP-based rate limits. |
| High | Bearer token middleware bypass | `middleware.ts` passes through any request with `Authorization: Bearer` header without validation. API routes that forget to call `authenticateAndAuthorize` become unprotected. |
| Medium | `refreshPromise` body consumption | Concurrent callers sharing the same `refreshPromise` receive the same `Response` object. If multiple callers attempt to read the response body (via `.json()`, `.text()`, etc.), only the first succeeds — subsequent reads fail with "body already used". The custom fetch itself does not read the shared body, but downstream Supabase SDK consumers may. |
| Medium | `isHandlingTokenError` persistence | This flag is a module singleton. A `resetRefreshState()` function exists (`client.ts` lines 43-48) but is not automatically called between page sessions — it requires explicit invocation from `AuthContext` on `TOKEN_REFRESHED` events. Without a hard reload or this event, the flag persists and blocks all subsequent refresh attempts. |
| Low | Failed results cached 30s | Server-side `refreshCache` holds 401 responses for 30s. A legitimate user with a new valid session may get cached failure during this window. |
| Low | Dead code | `siteUrl` variable in `client.ts` declared but never used. |
| Low | Dual `getSession()` + `getUser()` | `authenticateAndAuthorize` calls both sequentially; `getSession()` is redundant since `getUser()` validates the JWT. |

**Risk Level:** Low (well-protected despite noted issues)

---

## Priority Action Items

### Critical (Address Soon)

1. **TOS: Add consecutive failure limit**
   - Add `_consecutiveFailures` counter with max 3 to `supabase_auth_service.dart`
   - On 3 failures, expire session and redirect to login
   - Without this, TOS can enter infinite refresh loops

2. ~~**OSD: Migrate to FlutterSecureStorage**~~ **DONE (2026-03-07)**
   - ~~Replace `SharedPreferences` with `FlutterSecureStorage` for token storage~~
   - Migrated to `SecureStorageService` with one-time migration for existing users

### Recommended

3. **TOS: Add pre-request expiry check**
   - Add `ensureValidToken()` call before API requests in `http_service_impl.dart`
   - Prevents unnecessary 401 round-trips

4. **KDS/SDS/CDS: Consider proactive timer**
   - These display apps may have idle periods
   - A timer refresh (like BOS/OSD) would prevent token expiry during idle

5. **POS: Move rate limiter to Redis**
   - Current in-memory `Map` is not shared across instances
   - Use Redis or similar distributed store for production rate limiting

6. **POS: Validate `X-Forwarded-For` against trusted proxies**
   - Only trust the header when behind a known reverse proxy
   - Or use a platform-specific IP extraction method

### Low Priority

7. **All Flutter apps: Add exponential backoff on refresh retry**
   - Currently use fixed 30s retry or no retry
   - Exponential backoff (1s, 2s, 4s, 8s...) is more resilient

8. **BOS: Add app lifecycle refresh**
   - Refresh token on `AppLifecycleState.resumed` to handle background suspension

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        POS (Next.js)                         │
│                                                              │
│  ┌─────────┐   ┌──────────────┐   ┌───────────────────┐     │
│  │Middleware│──>│Custom Fetch  │──>│Server-side Dedup  │     │
│  │(session  │   │(client dedup,│   │(30s cache,        │     │
│  │ refresh) │   │ debounce,    │   │ in-flight sharing,│     │
│  │          │   │ BroadcastCh) │   │ hash-based key)   │     │
│  └─────────┘   └──────────────┘   └───────────────────┘     │
│       │              │                      │                │
│       ▼              ▼                      ▼                │
│  ┌─────────────────────────────────────────────────────┐     │
│  │              Rate Limiter (1000/15min)               │     │
│  └─────────────────────────────────────────────────────┘     │
│                          │                                   │
│                          ▼                                   │
│                   Supabase Auth API                          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   Flutter Apps (BOS/OSD)                       │
│                                                              │
│  ┌──────────────┐  ┌─────────────────┐  ┌───────────────┐   │
│  │Timer Refresh  │  │Pre-request Check│  │401 Interceptor│   │
│  │(5min before)  │  │(expiry check)   │  │(retry once)   │   │
│  └──────┬───────┘  └───────┬─────────┘  └──────┬────────┘   │
│         │                  │                    │             │
│         ▼                  ▼                    ▼             │
│  ┌─────────────────────────────────────────────────────┐     │
│  │        Completer Lock (concurrent refresh guard)     │     │
│  │        + 3 consecutive failure limit                 │     │
│  └─────────────────────────────────────────────────────┘     │
│                          │                                   │
│                          ▼                                   │
│                POS API /api/auth/refresh                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│            Flutter Apps (KDS/SDS/CDS/Self Station)            │
│                                                              │
│  ┌─────────────────┐  ┌───────────────┐                     │
│  │Pre-request Check│  │401 Interceptor│                     │
│  │(expiry check)   │  │(retry once)   │                     │
│  └───────┬─────────┘  └──────┬────────┘                     │
│          │                   │                               │
│          ▼                   ▼                               │
│  ┌─────────────────────────────────────────────────────┐     │
│  │        Completer Lock + 3 failure limit              │     │
│  └─────────────────────────────────────────────────────┘     │
│                          │                                   │
│                          ▼                                   │
│                POS API /api/auth/refresh                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                        TOS (⚠️)                              │
│                                                              │
│  ┌───────────────┐                                          │
│  │401 Interceptor│  ← Only layer, no pre-request check      │
│  │(retry once)   │  ← No consecutive failure limit          │
│  └──────┬────────┘                                          │
│         │                                                    │
│         ▼                                                    │
│  ┌─────────────────────────────────────────────────────┐     │
│  │        Completer Lock (no failure limit ⚠️)          │     │
│  └─────────────────────────────────────────────────────┘     │
│                          │                                   │
│                          ▼                                   │
│                POS API /api/auth/refresh                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Conclusion

The overall token refresh architecture across the SciometaPOS ecosystem is solid. The POS serves as the central auth gateway with robust deduplication, and most Flutter apps implement a reliable Completer-based concurrent refresh guard with failure limits. The remaining critical item requiring attention is **TOS's missing failure limit** (risk of infinite refresh loops). ~~OSD's unencrypted token storage~~ has been resolved (2026-03-07) by migrating to `SecureStorageService`. All other issues are incremental improvements.
