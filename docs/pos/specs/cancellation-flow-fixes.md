# 解約フロー修正定義書

## 概要

サブスクリプション解約後に有料機能のAPIが引き続き利用可能な問題の修正定義書。

### 前提: 無料 vs 有料の境界

| 分類 | 機能 | サブスクチェック |
|------|------|-----------------|
| **無料（基本POS）** | POS注文作成・編集、支払い記録、メニュー管理、KDS、CDS、SDS、店舗管理、予約（Free tier） | **不要** — 解約後も利用可能 |
| **有料（サブスク必須）** | BOS (Kiosk Self-Order)、TOS (Table Order / QR注文)、Self Station、Shift、Receipt Scanner、Account Connect | **必要** — 解約後はブロック |

### 判定基準

- `source` が有料アプリに紐づく注文のみブロック
- POS（スタッフ操作）からの基本注文は常に許可
- QR注文は TOS サブスクに依存 → 解約後はブロック
- Self Station の注文完了・決済操作は Self Station サブスクに依存 → 解約後はブロック
---

## 修正一覧

| # | 対象 | 重要度 | 内容 | 状態 |
|---|------|--------|------|------|
| FIX-1 | QR注文: セッション内サブスク再チェック | HIGH | `qr-order/orders` POST, `add-items` POST, `checkout-session` POST | ✅ 実装済み |
| FIX-2 | Self Station: 注文完了・決済・一覧にサブスクチェック追加 | HIGH | `self-station/app/orders/[id]/complete` POST, `split-payment` POST, `orders` GET | ✅ 実装済み |
| 対象外 | `epassi/payment` POST | — | BOS キオスク決済。サブスクチェック不要（ユーザー判断） |
| 対象外 | `orders/create`, `orders/create-with-table` | — | `source==='tos'` のチェック済み。POS/BOS からの注文は基本機能なのでチェック不要 |
| 対象外 | `payments` POST/PUT, `order-items` POST | — | POS基本機能。スタッフ操作の支払い記録・アイテム追加は無料機能 |
| 対象外 | `payment-terminals/checkout` (SumUp) | — | POS基本機能。端末決済は無料 |
| 対象外 | `bos-display-payment-terminals`, `table-display-payment-terminals` | — | Display自体のサブスクチェックで間接的に保護済み |
| 対象外 | `bos-displays/validate`, `table-displays/validate` | — | デバイス認証ハンドシェイク。サブスクチェックはDisplay CRUD側で実施済み |

---

## FIX-1: QR注文セッション内サブスク再チェック

### 問題

`/api/qr-order/resolve` で新規セッション発行時にサブスクチェックしているが、
セッション取得後の注文作成(`orders` POST)、アイテム追加(`add-items` POST)、
Stripe決済開始(`checkout-session` POST) ではサブスク再チェックがない。

解約前に発行されたセッショントークンで解約後も操作継続可能。

### 修正方針

3エンドポイントに共通のサブスクチェックヘルパーを追加する。
セッショントークンから取得できる `store_id`, `organization_id` を使い、
`checkStoreAccess(org, APP_SLUGS.TOS, storeId)` を呼ぶ。

### 修正対象ファイル

#### 1. `ReactRestaurantPOS/src/app/api/qr-order/orders/route.ts` (POST)

セッショントークン検証の直後（demo チェックの後）に追加:

```typescript
// 追加 import
import { createSubscriptionService, APP_SLUGS } from '@/lib/subscription';

// validateSessionToken 成功後、demo チェックの後に追加:
// Check TOS subscription access
const subscriptionService = createSubscriptionService(supabase);
const accessCheck = await subscriptionService.checkStoreAccess(
  organization_id, APP_SLUGS.TOS, store_id
);
if (!accessCheck.hasAccess) {
  return NextResponse.json(
    { error: 'QR ordering is not available', error_code: 'SUBSCRIPTION_INACTIVE' },
    { status: 403 }
  );
}
```

注: `supabase` はこのファイルで既に service role client として作成済み。

#### 2. `ReactRestaurantPOS/src/app/api/qr-order/orders/[orderId]/add-items/route.ts` (POST)

同一パターン。demo チェックの後に同じサブスクチェックを追加。

#### 3. `ReactRestaurantPOS/src/app/api/qr-order/checkout-session/route.ts` (POST)

同一パターン。demo チェックの後に同じサブスクチェックを追加。

---

## FIX-2: Self Station 注文完了・決済・一覧にサブスクチェック追加

### 問題

Self Station の注文完了 (`complete`)、分割決済 (`split-payment`)、注文一覧 (`orders` GET) に
サブスクリプションチェックがなく、解約後も操作可能。

### 修正方針

- `complete`: 注文の `store_id` と `stores.organization_id` を取得 → `checkStoreAccess(org, SELF_STATION, storeId)`
- `split-payment`, `orders` GET: `table_sessions` の `store_id` と `stores.organization_id` を取得 → 同上

### 修正対象ファイル

#### 1. `ReactRestaurantPOS/src/app/api/self-station/app/orders/[id]/complete/route.ts` (POST)

```typescript
// 追加 import
import { createServiceClient } from '../../../../../shared/auth';
import { createSubscriptionService, APP_SLUGS } from '@/lib/subscription';

// authenticateAndAuthorize の後、order update の前に追加:
const { data: orderForCheck } = await supabase!
  .from('orders')
  .select('store_id, stores!inner(organization_id)')
  .eq('id', id)
  .single();

if (orderForCheck?.store_id) {
  const serviceSupabase = createServiceClient();
  const subscriptionService = createSubscriptionService(serviceSupabase);
  const orgId = (orderForCheck as any).stores?.organization_id;
  const accessCheck = await subscriptionService.checkStoreAccess(
    orgId, APP_SLUGS.SELF_STATION, orderForCheck.store_id
  );
  if (!accessCheck.hasAccess) {
    return NextResponse.json(
      { error: accessCheck.reason || 'Self Station subscription is not active' },
      { status: 403 }
    );
  }
}
```

#### 2. `ReactRestaurantPOS/src/app/api/self-station/app/orders/split-payment/route.ts` (POST)

```typescript
// 追加 import
import { createServiceClient } from '../../../../shared/auth';
import { createSubscriptionService, APP_SLUGS } from '@/lib/subscription';

// authenticateAndAuthorize の後、unpaid orders クエリの前に追加:
const { data: sessionForCheck } = await supabase!
  .from('table_sessions')
  .select('store_id, stores!inner(organization_id)')
  .eq('id', session_id)
  .single();

if (sessionForCheck?.store_id) {
  const serviceSupabase = createServiceClient();
  const subscriptionService = createSubscriptionService(serviceSupabase);
  const orgId = (sessionForCheck as any).stores?.organization_id;
  const accessCheck = await subscriptionService.checkStoreAccess(
    orgId, APP_SLUGS.SELF_STATION, sessionForCheck.store_id
  );
  if (!accessCheck.hasAccess) {
    return NextResponse.json(
      { error: accessCheck.reason || 'Self Station subscription is not active' },
      { status: 403 }
    );
  }
}
```

#### 3. `ReactRestaurantPOS/src/app/api/self-station/app/orders/route.ts` (GET)

同一パターン。`table_sessions` → `stores` 経由で取得。

---

## Webhook ステータス不整合（情報のみ）

| Webhook 処理元 | `customer.subscription.deleted` 時のステータス |
|---|---|
| ReactRestaurantPOS (2箇所) | `removed` |
| subscription-web | `canceled` |

いずれも `ACTIVE_ITEM_STATUSES = ['active', 'trialing']` に含まれないため
**アクセス遮断は正常に動作する**。統一は望ましいが、今回の修正スコープ外とする。

---

## テスト方針

各修正について以下を確認:

1. **サブスクactive時**: 従来通り正常動作すること
2. **サブスクcanceled/removed時**: 403が返ること
3. **store_id が null の場合**: チェックをスキップし、既存動作を維持すること
4. **POS基本機能**: `orders/create`（source未指定）、`payments` POST、`order-items` POST が引き続き正常に動作すること（リグレッションなし）

---

## 修正対象ファイル一覧

| ファイル | FIX # |
|----------|-------|
| `ReactRestaurantPOS/src/app/api/qr-order/orders/route.ts` | FIX-1 |
| `ReactRestaurantPOS/src/app/api/qr-order/orders/[orderId]/add-items/route.ts` | FIX-1 |
| `ReactRestaurantPOS/src/app/api/qr-order/checkout-session/route.ts` | FIX-1 |
| `ReactRestaurantPOS/src/app/api/self-station/app/orders/[id]/complete/route.ts` | FIX-2 |
| `ReactRestaurantPOS/src/app/api/self-station/app/orders/split-payment/route.ts` | FIX-2 |
| `ReactRestaurantPOS/src/app/api/self-station/app/orders/route.ts` | FIX-2 |
