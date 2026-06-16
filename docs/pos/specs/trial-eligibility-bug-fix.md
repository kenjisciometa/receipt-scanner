# Trial Eligibility Bug Fix: 2店舗目へのトライアル重複付与

## 修正対象リポジトリ

**subscription-web** (`/Users/kenjiyano/Documents/Sciometa/vsc/SciometaPOS/subscription-web`)

## 問題の概要

同一Organization内で1店舗目のトライアルを消化済み（有料期間に移行）の状態で、2店舗目を追加した際にも新たなトライアル（14日間無料）が付与されてしまう。

**想定動作:**
- 1つのOrganizationにつき同一`trial_group`のトライアルは1回のみ
- 1店舗目のトライアルが**消化済み** → 2店舗目は即課金
- 1店舗目のトライアルが**進行中** → 2店舗目はトライアル残日数分だけ付与（同じ`trial_end`に揃える）

## 再現されたケース

- アカウント: `hello@tokyostreethelsinki.com`
- Organization: `b9d33e3b-926c-4943-b240-64953199edea`

| Store | Plan | Status | Trial期間 | 問題 |
|-------|------|--------|-----------|------|
| Hietalahden Kauppahalli | SciPOS Premium | `active`（有料中） | 4/27-5/11（消化済み��� | - |
| Vallila | SciPOS Standard | `trialing` | 5/31-6/14（進行中） | 本来はtrial無しで即課金のはず（1店舗目が既に有料移行済み） |

両プランは `trial_group: 'tier'` で同一グループ。

## 根本原因

**ファイル:** `subscription-web/src/lib/subscription/trial-eligibility.ts`

### Line 69-75 のクエリ:

```typescript
let query = supabaseAdmin
  .from('subscription_items')
  .select('id, trial_start, canceled_at, status')
  .in('plan_id', familyPlanIds)
  .or('trial_start.not.is.null,canceled_at.not.is.null')
  // ↓ この行が問題
  .not('status', 'in', '(active,trialing)');
```

**実際の影響:**
1. Store 1は `status: 'active'`（トライアル消化後に有料移行済み）
2. 上記フィルタにより Store 1 のレコードは除外される
3. Step 2b (line 98-106) は `stripe_subscription_id IS NULL` のカードフリートライアルのみ対象 → Store 1は Stripe付きなので通過
4. 結果: `eligible: true` が返され、Store 2にもフル14日間のトライアルが付与される

### 問題の本質

Stripeのトライアル付きチェックアウトの場合、トライアル期間終了後に有料に移行すると `status` は `active` に変わるが、`trial_start` は設定されたまま残る。つまり「トライアルを消費してアクティブ」なレコードが永久に eligibility チェックから除外され続ける。

---

## 修正方針

### 設計: 3つの状態に基づくトライアル判定

| Orgの状態 | 2店舗目の動作 |
|-----------|-------------|
| トライアル履歴なし | フル14日間トライアル付与 |
| 他Store/Planでトライアル**進行中** | 残日数分のトライアル付与（同じ`trial_end`に揃える） |
| トライアル**消化済み**（有料移行 or キャンセル） | 即課金（トライアルなし） |

---

## 修正対象ファイル��覧

| # | フ���イル | 変更内容 |
|---|---------|----------|
| 1 | `src/lib/subscription/trial-eligibility.ts` | 判定ロジック全面変更 + 返り値拡張 |
| 2 | `src/app/api/stripe/checkout/route.ts` | `effectiveTrialDays` に `remainingTrialDays` を使用 |
| 3 | `src/app/api/billing/start-trial/route.ts` | `trialEnd` を `existingTrialEnd` に合わせる |
| 4 | `src/app/page.tsx` (line 149-157) | 同一バグのインラインクエリを修正 |

---

## 修正1: `src/lib/subscription/trial-eligibility.ts`

### 返り値の型を拡張

```typescript
export interface TrialEligibilityResult {
  eligible: boolean;
  reason: TrialIneligibleReason | null;
  previousItemId?: string;
  /** 進行中のトライアルがある場合、その残日数。eligible=true かつ remainingTrialDays > 0 の場合に使用。 */
  remainingTrialDays?: number;
  /** 進行中のトライアルの trial_end（ISO文字列）。カードフリートライアルの trial_end 合わせに使用。 */
  existingTrialEnd?: string;
}
```

### ロジック全面変更

```typescript
export async function checkTrialEligibility(
  supabaseAdmin: SupabaseClient,
  input: TrialEligibilityInput,
): Promise<TrialEligibilityResult> {
  const { billingUnit, trialGroup, organizationId, userId } = input;

  // Step 1: Find all plan_ids in the same trial_group.
  const { data: familyPlans, error: planError } = await supabaseAdmin
    .from('subscription_plans')
    .select('id')
    .eq('trial_group', trialGroup);

  if (planError || !familyPlans || familyPlans.length === 0) {
    if (planError) console.error('[trial-eligibility] plan lookup error:', planError);
    return { eligible: true, reason: null };
  }

  const familyPlanIds = familyPlans.map((p) => p.id);

  // Step 2: Check for ANY row with trial_start set (regardless of status).
  // This detects both completed trials (active after trial) and in-progress trials.
  let query = supabaseAdmin
    .from('subscription_items')
    .select('id, trial_start, trial_end, canceled_at, status')
    .in('plan_id', familyPlanIds)
    .not('trial_start', 'is', null);

  if (billingUnit === 'user') {
    query = query.eq('user_id', userId);
  } else {
    if (!organizationId) {
      return { eligible: true, reason: null };
    }
    query = query.eq('organization_id', organizationId);
  }

  const { data: rows, error } = await query;

  if (error) {
    console.error('[trial-eligibility] query error:', error);
    return { eligible: false, reason: 'lookup_error' };
  }

  if (!rows || rows.length === 0) {
    // No trial history — also check for canceled_at without trial_start (legacy fallback)
    let cancelQuery = supabaseAdmin
      .from('subscription_items')
      .select('id, canceled_at')
      .in('plan_id', familyPlanIds)
      .not('canceled_at', 'is', null);

    if (billingUnit === 'user') {
      cancelQuery = cancelQuery.eq('user_id', userId);
    } else {
      cancelQuery = cancelQuery.eq('organization_id', organizationId!);
    }

    const { data: canceledRow } = await cancelQuery.limit(1).maybeSingle();

    if (canceledRow) {
      return { eligible: false, reason: 'previously_canceled', previousItemId: canceledRow.id };
    }

    // No history at all → eligible for full trial
    return { eligible: true, reason: null };
  }

  // Found rows with trial_start. Determine if any trial is still in progress.
  const now = new Date();

  // Check for an actively trialing row (status = 'trialing' and trial_end in the future)
  const activeTrialRow = rows.find((row) => {
    if (row.status !== 'trialing') return false;
    if (!row.trial_end) return false;
    return new Date(row.trial_end) > now;
  });

  if (activeTrialRow && activeTrialRow.trial_end) {
    // Trial is in progress on another store — allow trial with remaining days
    const trialEndDate = new Date(activeTrialRow.trial_end);
    const remainingDays = Math.max(
      1, // At least 1 day if trial_end is in the future
      Math.ceil((trialEndDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))
    );

    return {
      eligible: true,
      reason: null,
      remainingTrialDays: remainingDays,
      existingTrialEnd: activeTrialRow.trial_end,
    };
  }

  // Trial was used but is no longer active (expired or moved to paid) → ineligible
  return { eligible: false, reason: 'previously_used', previousItemId: rows[0].id };
}
```

---

## 修正2: `src/app/api/stripe/checkout/route.ts` (line 402-404)

### Before:

```typescript
const configuredTrialDays = plan.trial_period_days || undefined;
const effectiveTrialDays =
  isMetered || !trialEligibility.eligible ? undefined : configuredTrialDays;
```

### After:

```typescript
const configuredTrialDays = plan.trial_period_days || undefined;
let effectiveTrialDays: number | undefined;

if (isMetered || !trialEligibility.eligible) {
  effectiveTrialDays = undefined; // No trial
} else if (trialEligibility.remainingTrialDays !== undefined) {
  // Another store in the same org is currently trialing — match its remaining days
  effectiveTrialDays = trialEligibility.remainingTrialDays;
} else {
  effectiveTrialDays = configuredTrialDays; // Full trial (first store)
}
```

---

## 修正3: `src/app/api/billing/start-trial/route.ts`

### 変更内容

`trialEligibility` のスコープを引き上げ、`trialEnd` 計算に `existingTrialEnd` を使用する。

### Before (line 82-112):

```typescript
// Check trial eligibility
if (trialGroup) {
  const eligibility = await checkTrialEligibility(supabaseAdmin, {
    billingUnit,
    trialGroup,
    organizationId,
    userId: user.id,
  });

  if (!eligibility.eligible) {
    return NextResponse.json(
      { error: 'Trial has already been used for this plan' },
      { status: 400 },
    );
  }
}

// ...

const now = new Date();
const trialEnd = new Date(now);
trialEnd.setDate(trialEnd.getDate() + plan.trial_period_days);
```

### After:

```typescript
// Check trial eligibility
let trialEligibility: TrialEligibilityResult = { eligible: true, reason: null };
if (trialGroup) {
  trialEligibility = await checkTrialEligibility(supabaseAdmin, {
    billingUnit,
    trialGroup,
    organizationId,
    userId: user.id,
  });

  if (!trialEligibility.eligible) {
    return NextResponse.json(
      { error: 'Trial has already been used for this plan' },
      { status: 400 },
    );
  }
}

// ...

const now = new Date();
let trialEnd: Date;

if (trialEligibility.existingTrialEnd) {
  // Match the existing trial's end date (join ongoing trial)
  trialEnd = new Date(trialEligibility.existingTrialEnd);
} else {
  // Full trial period (first store)
  trialEnd = new Date(now);
  trialEnd.setDate(trialEnd.getDate() + plan.trial_period_days);
}
```

※ `TrialEligibilityResult` を import に追加する必要あり。

---

## 修正4: `src/app/page.tsx` (line 149-157)

### 問題

`page.tsx` にはインラインで書かれた同一バグのクエリがある:

```typescript
const { data: historicalItems } = await supabaseAdmin
  .from('subscription_items')
  .select('id')
  .eq('organization_id', organizationId)
  .in('plan_id', tierFamilyPlanIds)
  .not('status', 'in', '(active,trialing)')  // ← 同じバグ
  .or('trial_start.not.is.null,canceled_at.not.is.null')
  .limit(1);
```

これはUI表示用（各Tier planカードに「Start Trial��ボタンを出すかどうか）の判定。

### After:

```typescript
// Check if the org has ever consumed a tier trial (any status, including active).
// An active subscription that went through a trial still counts as "trial consumed".
const { data: historicalItems } = await supabaseAdmin
  .from('subscription_items')
  .select('id')
  .eq('organization_id', organizationId)
  .in('plan_id', tierFamilyPlanIds)
  .or('trial_start.not.is.null,canceled_at.not.is.null')
  .limit(1);

// But if any row is currently trialing (not yet expired), allow partial trial
const { data: activeTrialingItems } = await supabaseAdmin
  .from('subscription_items')
  .select('id, trial_end')
  .eq('organization_id', organizationId)
  .in('plan_id', tierFamilyPlanIds)
  .eq('status', 'trialing')
  .not('trial_end', 'is', null)
  .gt('trial_end', new Date().toISOString())
  .limit(1);

if (historicalItems && historicalItems.length > 0 && (!activeTrialingItems || activeTrialingItems.length === 0)) {
  // Trial fully consumed (no active trialing) → ineligible
  trialIneligibleTiers.add('basic');
  trialIneligibleTiers.add('standard');
  trialIneligibleTiers.add('premium');
}
// Note: if activeTrialingItems exists, leave tiers as trial-eligible
// (the checkout route will handle setting remainingTrialDays via checkTrialEligibility)
```

---

## Webhook への影響（変更不要）

`src/lib/stripe/webhook-handlers/checkout-completed.ts` は Stripe から通知される `subscription.trial_start` / `subscription.trial_end` をそのまま DB に保存するだけなので、**変更不要**。

Stripeが `trial_period_days` に基づいて `trial_start` / `trial_end` を自動計算し、webhook経由でDBに反映される流れは既存のまま正常動作する。

---

## 動作まとめ

| ケース | eligibility結果 | Stripe trial_period_days | 動作 |
|--------|----------------|--------------------------|------|
| Org初回: 1店舗目 | `eligible: true`, `remainingTrialDays: undefined` | 14 (full) | フル14日トライアル |
| 1店舗目がtrialing中 (残8日) → 2店舗目��加 | `eligible: true`, `remainingTrialDays: 8` | 8 | 残り8日間トライアル |
| 1店舗目がactive (有料移行済み) → 2店舗目追加 | `eligible: false`, reason: `previously_used` | undefined | 即課金 |
| キャンセル後再サブスク | `eligible: false`, reason: `previously_canceled` | undefined | 即課金 |
| 異なるtrial_group (tier使用済み → shift) | `eligible: true`, `remainingTrialDays: undefined` | 14 (full) | フルトライアル |

---

## Stripe Checkout画面への影響

| ケース | Stripe表示 |
|--------|-----------|
| フルトライアル (14日) | 「14日間の無料トライアル後に課金」 |
| 残日数トライアル (8日) | 「8日間の無料トライアル後に課金」 |
| 即課金 | 「今すぐ ¥X/月」（トライアル表記なし） |

---

## エッジケースの考慮

| ケース | 動作 |
|--------|------|
| 残日数が1日未満（当日中に期限切れ） | `Math.ceil` + `Math.max(1, ...)` で最低1日を保証 |
| 複数ストアが同時にtrialing（同一trial_end） | `find()` で最初の1つを使用（全て同じtrial_endのはず） |
| カードフリートライアルが期限切れだがstatus未更新 | `trial_end < now` なので activeTrialRow にマッチしない → `previously_used` |
| 1店舗目 Standard trialing中 → 2店舗目 Premium checkout | trial_group: 'tier' が同じ → 残日数トライアル付与 |
| page.tsx UI表示: trial進行中に別ストア追加 | トライアルボタン表示 → checkout後にremainingTrialDays適用 |

---

## 既存データの対応

Vallila (Store 2) に誤って付与されたトライアル (`sub_1TdEtvHWFR5mj4coOjrqMJrU`):
- Stripeサブスクリプションのトライアル期間は既に開始済み
- 手動でStripe側のトライアルを終了させるか、そのまま14日間消化させるかはビジネス判断

---

## テスト確認事項

1. 新規Org → フル14日トライアル付与
2. 1店舗目trialing中(残8日) → 2店舗目checkout → Stripe画面に「8日間トライアル」表示
3. 1店舗目trialing中(残8日) → 2店舗目カードフリートライアル → `trial_end` が1店舗目と同じ
4. 1店舗目active(有料移行済み) → 2店舗目checkout → Stripe画面に即課金表示
5. 異なるtrial_group → 影響なし（フルトライアル）
6. canceled_at付き行のみ → `eligible: false` (previously_canceled)
7. カードフリートライアル期限切れ(status未更新) → `eligible: false`
8. page.tsx: トライアル消化済みOrgに「Start Trial」ボタンが出ないこと
9. page.tsx: トライアル進行中Orgに「Start Trial」ボタンが出ること（残日数でcheckout）
