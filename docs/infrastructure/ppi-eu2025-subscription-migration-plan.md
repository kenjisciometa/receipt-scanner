# ppi.eu2025@gmail.com サブスクリプション移行計画

## 概要

ppi.eu2025@gmail.com アカウント（組織: 87350b41）を手動登録からStripe正式サブスクリプションへ移行する。

## 現状（2026-04-22 時点）

| # | subscription_items.id | app_slug | tier | item_type | store | status | stripe_subscription_id | trial_start | 作成日 |
|---|----------------------|----------|------|-----------|-------|--------|----------------------|-------------|--------|
| 1 | `a1760b52-be30-48ae-a2f8-2b9d1714c546` | bos | standard | store | KATANA (`2ed980f5`) | active | NULL（手動） | NULL | 2026-02-25 |
| 2 | `b43697b6-220b-42b5-b15c-ae003c680e48` | shift | - | user | - | active | NULL（手動） | 2026-03-25 | 2026-03-25 |

- 両レコードとも `stripe_subscription_id = NULL`（Stripe に紐付かない手動登録）
- `payment_provider = 'stripe'` だが実際の Stripe サブスクは存在しない
- クレジットカードが現時点で登録できない状態

## 方針: Option B（トライアル無し・即時課金サブスク）

手動レコードをキャンセル → カード取得後に通常の Stripe Checkout で正式サブスクを開始する。

### Option A（不採用）との比較

| | Option A（手動トライアル → 正式化） | Option B（キャンセル → 即時課金サブスク） |
|---|---|---|
| DB手動操作 | 2回（trialing化 + checkout後の整合性調整） | 1回（キャンセルのみ） |
| Stripe整合性 | 手動trialing中はStripe側にレコード無し | 常にStripe経由で整合 |
| 複雑さ | 高 | 低 |
| トライアル | card-required実装済みのため手動設定が必要 | 不要（既に手動期間を利用済み） |

### トライアルが適用されない理由

`checkTrialEligibility()` は以下の条件でトライアルを不適格と判定する：

1. `trial_start IS NOT NULL` — Shift レコードに設定済み
2. `canceled_at IS NOT NULL` — キャンセル後に設定される

いずれかに該当すると、Checkout 時に `effectiveTrialDays = undefined` となりトライアル期間なしで処理される。ただし **Checkout 自体はブロックされない**（UI が「Subscribe now」に変わるだけ）。

## 実行手順

### Phase 1: 手動レコードのキャンセル（管理者がDBで実行）

ユーザーのサービス利用を止めてよいタイミングで実行する。

```sql
-- 1. BOS Standard (store-level, KATANA)
UPDATE subscription_items
SET status = 'canceled',
    canceled_at = NOW(),
    updated_at = NOW()
WHERE id = 'a1760b52-be30-48ae-a2f8-2b9d1714c546';

-- 2. Shift (user-level)
UPDATE subscription_items
SET status = 'canceled',
    canceled_at = NOW(),
    updated_at = NOW()
WHERE id = 'b43697b6-220b-42b5-b15c-ae003c680e48';
```

**確認クエリ:**

```sql
SELECT id, app_slug, tier, status, canceled_at
FROM subscription_items
WHERE organization_id = '87350b41-bac7-4d92-a0bc-415bc50777d1';
```

### Phase 2: ユーザーによる正式サブスク登録（カード取得後）

ユーザーがクレジットカードを取得したら、以下の手順で案内する。

#### BOS Standard（店舗レベル）

1. subscription-web にログイン
2. Standard プランの「Subscribe now」ボタンをクリック
3. 対象店舗（KATANA）を選択
4. Stripe Checkout でカード情報入力 → 即時課金
5. Webhook が `subscription_items` に正式レコードを自動作成

#### Shift Manager（ユーザーレベル）

1. accountant-app（またはShift Managementアプリ）から再サブスク
2. Stripe Checkout でカード情報入力 → 即時課金
3. `subscription_items` に正式レコードが自動作成

### Phase 3: 完了確認

```sql
-- 正式サブスクが作成されていることを確認
SELECT id, app_slug, tier, item_type, status, payment_provider, stripe_subscription_id, created_at
FROM subscription_items
WHERE organization_id = '87350b41-bac7-4d92-a0bc-415bc50777d1'
  AND status IN ('active', 'trialing')
ORDER BY created_at;
```

- `stripe_subscription_id` が NULL でないことを確認
- `status = 'active'` であることを確認

## リスクと注意点

1. **Phase 1 → Phase 2 の間はサービス利用不可** — キャンセル後、正式サブスク完了まで BOS/Shift の機能が使えなくなる。ユーザーへの事前連絡が必要。
2. **Shift のトライアル履歴** — `trial_start` が設定済みのため、再サブスク時にトライアルは適用されない（即時課金）。
3. **BOS のトライアル** — `trial_start = NULL` だが `canceled_at` が設定されるため、cross-tier チェックによりトライアル不適格になる。
4. **旧レコードの残存** — キャンセル済みレコードは `subscription_items` に残る（履歴として）。新しいサブスクは別レコードとして作成される。

## タイムライン

| フェーズ | タイミング | 実行者 |
|---------|-----------|--------|
| Phase 1 | ユーザーと合意した日 | 管理者（SQL実行） |
| Phase 2 | カード取得後 | ユーザー自身 |
| Phase 3 | Phase 2 直後 | 管理者（確認） |
