# サブスクリプション関連バグ修正 定義書

## 概要

Store追加サブスクリプションフロー検証で発見された3件のバグの修正定義書。

| # | バグ | 重要度 | 対象リポジトリ |
|---|---|---|---|
| BUG-1 | Self Station API にサブスクリプションチェックがない | HIGH | ReactRestaurantPOS |
| BUG-2 | daily-snapshot cron: 複数Store時の included_seats が合算されない | HIGH | shift-management-app |
| BUG-3 | report-usage cron: 複数Store時に同一orgへ複数回overage報告 | HIGH | shift-management-app |

---

## BUG-1: Self Station (customer-displays) API にサブスクリプションチェックがない

### 問題

BOS/TOS の Display 作成 API は `checkStoreAccess()` でサブスクリプション検証を行い、
未課金 Store には 403 を返すが、Self Station (customer-displays) の POST API には
このチェックが一切存在しない。

UI 側ではロック表示があるが、API を直接叩けば未課金 Store に Display を作成できてしまう。

### 対象ファイル

- `ReactRestaurantPOS/src/app/api/customer-displays/route.ts`

### 現在のコード (POST handler)

```typescript
// route.ts:45-103
export async function POST(request: NextRequest) {
  // ... 認証チェック (authenticateAndAuthorize)
  // ... name, organization_id バリデーション
  // ... store_id の任意取得
  // ← ここにサブスクリプションチェックがない
  // ... customer_displays テーブルに INSERT
}
```

### 修正内容

POST handler 内で、`store_id` が提供された場合に `checkStoreAccess()` を呼び出す。
BOS/TOS と同じパターンに従う。

#### 修正箇所: POST handler 内、INSERT の前に追加

```typescript
// store_id が指定されている場合、サブスクリプションチェックを実行
if (store_id) {
  const serviceClient = createServiceClient();
  const subscriptionService = createSubscriptionService(serviceClient);
  const accessCheck = await subscriptionService.checkStoreAccess(
    organization_id,
    APP_SLUGS.SELF_STATION,
    store_id
  );
  if (!accessCheck.hasAccess) {
    return NextResponse.json(
      {
        error:
          accessCheck.reason ||
          'Store does not have Self Station subscription. Please subscribe first.',
      },
      { status: 403 }
    );
  }
}
```

#### 追加する import

```typescript
// 既存 import を変更:
// before: import { authenticateAndAuthorize } from '../shared/auth';
// after:
import { authenticateAndAuthorize, createServiceClient } from '../shared/auth';
import { createSubscriptionService, APP_SLUGS } from '@/lib/subscription';
```

> **注**: BOS/TOS と同じパターンで `createServiceClient` は `../shared/auth` から、
> `createSubscriptionService` と `APP_SLUGS` は `@/lib/subscription` (barrel export) から import する。

### 参考: BOS での実装パターン

```typescript
// bos-displays/route.ts:177-186
const accessCheck = await subscriptionServiceForPost.checkStoreAccess(
  organization_id,
  APP_SLUGS.BOS,
  store_id
);
if (!accessCheck.hasAccess) {
  return NextResponse.json(
    { error: accessCheck.reason || 'Store does not have Kiosk Self-Order System subscription...' },
    { status: 403 }
  );
}
```

### GET handler への影響

BOS/TOS の GET handler は `getSubscribedStoreIds()` で課金済み Store のみフィルタしている。
customer-displays の GET handler にも同様のフィルタリングを追加するかは今回のスコープ外とする。
（現時点で Self Station Display が未課金 Store に作成されているケースは限定的なため）

### 検証ポイント

- [ ] store_id 指定 + 未課金 Store → 403 が返ること
- [ ] store_id 指定 + 課金済み Store → Display 作成成功
- [ ] store_id 未指定 → 従来通り作成可能（org全体用途）
- [ ] `APP_SLUGS.SELF_STATION` (`'self_station'`) が `store_app_entitlements` ビューで正しく判定されること

---

## BUG-2: daily-snapshot cron — 複数Store時の included_seats 合算バグ

### 問題

同一 org が複数 Store で Standard/Premium に加入している場合、
各 Store の `shift_included_seats` を合算すべきだが、
`Map.set()` で上書きされるため最後の 1 件の値のみが使われる。

### 対象ファイル

- `shift-management-app/src/app/api/cron/daily-snapshot/route.ts`

### 現在のコード (行 149-159)

```typescript
const subByOrg = new Map<string, { stripeCustomerId: string; includedSeats: number }>();
for (const sub of activeSubscriptions) {
  const plan = (sub as any).subscription_plans;
  if (sub.organization_id && sub.stripe_customer_id) {
    subByOrg.set(sub.organization_id, {          // ← 同一 orgId で上書き
      stripeCustomerId: sub.stripe_customer_id,
      includedSeats: plan?.shift_included_seats ?? 0,  // ← 最後の 1 件の値のみ残る
    });
  }
}
```

### バグ発生メカニズム

1. subscription_items テーブルから Shift 対象のサブスクを取得（行 120-131）
2. dedupe は `subscription_item.id` ベース（行 141-147）
   - Store A Premium と Store B Premium は異なる `id` → 両方残る
3. `subByOrg` への格納で `Map.set(orgId, ...)` が上書き → 最後の 1 件のみ

### 具体例

```
org に 12 人の従業員
Store A: Premium (shift_included_seats = 10)
Store B: Premium (shift_included_seats = 10)

期待: includedSeats = 10 + 10 = 20 → overage = 0
現在: includedSeats = 10（上書き）→ overage = 2 → €10 過剰課金
```

### 修正内容

`Map.set()` を既存エントリの `includedSeats` に加算するロジックに変更する。

#### 修正後コード (行 149-159 を置換)

```typescript
const subByOrg = new Map<string, { stripeCustomerId: string; includedSeats: number }>();
for (const sub of activeSubscriptions) {
  const plan = (sub as any).subscription_plans;
  if (sub.organization_id && sub.stripe_customer_id) {
    const existing = subByOrg.get(sub.organization_id);
    if (existing) {
      // 同一 org の included_seats を合算
      existing.includedSeats += (plan?.shift_included_seats ?? 0);
    } else {
      subByOrg.set(sub.organization_id, {
        stripeCustomerId: sub.stripe_customer_id,
        includedSeats: plan?.shift_included_seats ?? 0,
      });
    }
  }
}
```

### 変更の影響範囲

- 行 200-206: `orgSub.includedSeats` を参照する箇所 → 変更なし（合算値が正しく入る）
- 行 205: `Math.max(0, count - orgSub.includedSeats)` → 合算値で正しく計算される

### 前提条件

- **同一 org の全 subscription_item は同一の `stripe_customer_id` を持つ**
  - DB 実データで検証済み: 複数の異なる `stripe_customer_id` を持つ org は存在しない
  - `stripe_customer_id` は org のオーナーの Stripe Customer に紐づくため、org 単位で一意
  - 修正後コードでは最初に処理された item の `stripeCustomerId` が使われるが、
    全 item で同一値のため問題なし

### 検証ポイント

- [ ] 1 Store Premium (10席) + 12人 → overage = 2
- [ ] 2 Store Premium (10+10=20席) + 12人 → overage = 0
- [ ] Store A Premium (10) + Store B Standard (5) + 12人 → overage = 0 (15席)
- [ ] Store A Premium (10) + Store B Standard (5) + 18人 → overage = 3
- [ ] 1 Store のみの org → 従来通り動作（回帰なし）
- [ ] Standalone Shift プラン (included_seats=0) → 全員 billable（回帰なし）
- [ ] stripe_customer_id が NULL → スキップ（回帰なし）

---

## BUG-3: report-usage cron — 複数Store時に同一orgへ複数回overage報告

### 問題

`activeSubscriptions` を subscription_item 単位でループし、各 item の
`shift_included_seats` だけで overage を計算して Stripe に報告している。
同一 org に複数の subscription_item がある場合:

1. included_seats が合算されないため過大な overage が計算される
2. 同一 org に対して複数回 Stripe meter event が報告される

### 対象ファイル

- `shift-management-app/src/app/api/cron/report-usage/route.ts`

### 現在のコード (行 137-220)

```typescript
// 5. Process each active subscription
for (const sub of activeSubscriptions) {         // ← subscription_item 単位ループ
  results.processed++;

  // ... stripe_customer_id / organization_id チェック ...

  const plan = (sub as any).subscription_plans;
  const includedSeats: number = plan?.shift_included_seats ?? 0;  // ← この item の値のみ
  const billableOverage = Math.max(0, activeUserCount - includedSeats);

  try {
    // ... snapshot upsert ...

    if (billableOverage <= 0) {
      // ... mark as reported ...
      continue;
    }

    // Report billable overage meter event to Stripe
    await stripe.billing.meterEvents.create({     // ← 同一 org で複数回呼ばれる可能性
      event_name: 'active_users',
      payload: {
        stripe_customer_id: sub.stripe_customer_id,
        value: String(billableOverage),
      },
    });
    // ...
  }
}
```

### バグ発生メカニズム

```
org に 12 人の従業員
Store A: Premium (shift_included_seats = 10)
Store B: Premium (shift_included_seats = 10)

期待: included_seats = 20 → overage = 0 → Stripe 報告なし

現在:
  Loop 1 (Store A): overage = 12 - 10 = 2 → Stripe に報告
  Loop 2 (Store B): overage = 12 - 10 = 2 → Stripe に再報告
  → 二重報告 + 過大課金
```

### 修正内容

ループ前に org 単位で `includedSeats` を合算し、org 単位で 1 回だけ処理する。

#### 修正後コード (行 137-220 を置換)

```typescript
// 5. Pre-aggregate included seats per org
const orgAgg = new Map<
  string,
  { stripeCustomerId: string; includedSeats: number }
>();
for (const sub of activeSubscriptions) {
  if (!sub.organization_id || !sub.stripe_customer_id) continue;
  const plan = (sub as any).subscription_plans;
  const seats = plan?.shift_included_seats ?? 0;
  const existing = orgAgg.get(sub.organization_id);
  if (existing) {
    existing.includedSeats += seats;
  } else {
    orgAgg.set(sub.organization_id, {
      stripeCustomerId: sub.stripe_customer_id,
      includedSeats: seats,
    });
  }
}

// 6. Process each org (not each subscription_item)
for (const [orgId, orgInfo] of orgAgg) {
  results.processed++;

  const yearMonth =
    yearMonthByOrg.get(orgId) || formatInTimeZone(now, 'UTC', 'yyyy-MM');
  const prevYearMonth = prevYearMonthByOrg.get(orgId) || '';
  const activeUserCount =
    countsByOrgAndMonth.get(`${orgId}:${yearMonth}`) || 0;
  const previousCount =
    prevCountsByOrgAndMonth.get(`${orgId}:${prevYearMonth}`) ?? null;

  const billableOverage = Math.max(
    0,
    activeUserCount - orgInfo.includedSeats
  );

  try {
    // Save/update snapshot (always record total active count)
    const { error: upsertError } = await dataClient
      .from('billing_usage_snapshots')
      .upsert(
        {
          organization_id: orgId,
          year_month: yearMonth,
          active_user_count: activeUserCount,
          previous_user_count: previousCount,
          stripe_reported: false,
          snapshot_date: now.toISOString(),
        },
        { onConflict: 'organization_id,year_month' }
      );

    if (upsertError) {
      results.errors.push(
        `Snapshot upsert failed for org ${orgId}: ${upsertError.message}`
      );
      continue;
    }

    // Only report to Stripe if there is billable overage
    if (billableOverage <= 0) {
      // Within included seats — mark as reported with zero overage
      await dataClient
        .from('billing_usage_snapshots')
        .update({ stripe_reported: true })
        .eq('organization_id', orgId)
        .eq('year_month', yearMonth);
      results.reported++;
      continue;
    }

    // Report billable overage meter event to Stripe (once per org)
    await stripe.billing.meterEvents.create({
      event_name: 'active_users',
      payload: {
        stripe_customer_id: orgInfo.stripeCustomerId,
        value: String(billableOverage),
      },
    });

    // Mark as reported
    await dataClient
      .from('billing_usage_snapshots')
      .update({ stripe_reported: true })
      .eq('organization_id', orgId)
      .eq('year_month', yearMonth);

    results.reported++;
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    results.errors.push(`Org ${orgId}: ${message}`);
  }
}
```

### 変更の影響範囲

- ループの単位が `subscription_item` → `org` に変更
- Stripe meter event は org 単位で 1 回のみ送信
- `billing_usage_snapshots` の upsert/update も org 単位で 1 回のみ
- `results.processed` のカウント基準が subscription_item 数 → org 数に変更

### 前提条件

- **同一 org の全 subscription_item は同一の `stripe_customer_id` を持つ**（BUG-2 と同様）
- 現在のループ内変数 `yearMonth`, `prevYearMonth`, `activeUserCount`, `previousCount` は
  全て `organization_id` のみに依存しており、subscription_item 固有の値は使っていない
  → org 単位ループへの変更で情報の欠落なし

### 検証ポイント

- [ ] 1 Store Premium (10席) + 12人 → overage = 2, Stripe 報告 1 回
- [ ] 2 Store Premium (10+10=20席) + 12人 → overage = 0, Stripe 報告なし
- [ ] 2 Store Premium (10+10=20席) + 25人 → overage = 5, Stripe 報告 1 回
- [ ] Store A Premium (10) + Store B Standard (5) → included_seats = 15
- [ ] stripe_customer_id が NULL の item → orgAgg に含まれず、スキップ
- [ ] organization_id が NULL の item → orgAgg に含まれず、スキップ
- [ ] 1 org に 1 subscription_item → 従来通り動作（回帰なし）
- [ ] billing_usage_snapshots が org ごとに 1 レコード（重複なし）

---

## 修正の優先順位

| 優先度 | バグ | 理由 |
|---|---|---|
| 1 | BUG-2 (daily-snapshot) | 日次で実行され、過剰課金が毎日発生する可能性がある |
| 2 | BUG-3 (report-usage) | 月次だが二重報告の影響が大きい |
| 3 | BUG-1 (Self Station API) | セキュリティリスクだが、実質的影響は UI ロックで軽減されている |

## 修正の依存関係

- BUG-2 と BUG-3 は独立しており、並行して修正可能
- BUG-1 は完全に独立（別リポジトリ）
- BUG-2 と BUG-3 の修正パターンは同一（included_seats の合算ロジック）

---

## 定義書検証結果

### BUG-1 検証

| 検証項目 | 結果 |
|---|---|
| POST handler の位置 (行 45-103) | ✅ 正確 |
| サブスクチェックが存在しないこと | ✅ 確認済 |
| `store_id` の変数名・抽出位置 (行 55) | ✅ 正確 |
| import パス (`../shared/auth`, `@/lib/subscription`) | ✅ BOS と同一パターンに修正済 |
| `APP_SLUGS.SELF_STATION` = `'self_station'` | ✅ constants.ts:22 で確認 |
| `checkStoreAccess` メソッドシグネチャ | ✅ subscription-service.ts:116-139 で確認 |
| `createSubscriptionService` のエクスポート | ✅ subscription-service.ts:653 + index.ts:53 で確認 |
| `store_app_entitlements` で `self_station` が存在 | ✅ DB クエリで確認 (store 単位) |

### BUG-2 検証

| 検証項目 | 結果 |
|---|---|
| 並列クエリ (行 120-131) | ✅ 正確 |
| dedupe が `subscription_item.id` ベース (行 141-147) | ✅ 正確 (異なる Store の item は残る) |
| `Map.set()` 上書きバグ (行 149-159) | ✅ バグ確認済 |
| `orgSub.includedSeats` 参照 (行 200, 205) | ✅ 正確 |
| 修正案の合算ロジック | ✅ 正しく動作する |
| `stripe_customer_id` の一意性前提 | ✅ DB 実データで検証済 (同一 org で複数の異なる customer_id なし) |

### BUG-3 検証

| 検証項目 | 結果 |
|---|---|
| dedupe コード (行 66-72) | ✅ 正確 |
| subscription_item 単位ループ (行 138) | ✅ 正確 |
| `stripe_customer_id` null スキップ (行 141-143) | ✅ 正確 |
| 個別 `includedSeats` 計算 (行 158-162) | ✅ バグ確認済 |
| snapshot upsert の上書き (行 164-178, onConflict) | ✅ 確認済 (最後の item で上書き) |
| Stripe meter event の複数報告 (行 199-206) | ✅ バグ確認済 |
| ループ内変数の org 依存性 | ✅ yearMonth/activeUserCount 等は org のみに依存 |
| 修正案の org 単位ループ変換 | ✅ 情報の欠落なし |
| `stripe_customer_id` の一意性前提 | ✅ DB 実データで検証済 |

---

*作成日: 2026-05-31*
*検証日: 2026-05-31*
*関連ドキュメント: [Store追加サブスクリプションフロー チェックリスト](../store-addition-subscription-flow-checklist.md)*
