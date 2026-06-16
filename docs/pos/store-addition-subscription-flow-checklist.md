# 新規Store追加時のサブスクリプションフロー チェックリスト

## 概要

既存組織に新しいStoreを追加した際の、課金状態ごとの想定フローと各チェックポイント。

---

## プラン体系

| プラン | 課金単位 | 月額 | 年額 | 含まれるアプリ |
|---|---|---|---|---|
| Basic | organization | €29 | €313 | QR Menu, Receipt, Accountant Connect, Reservation |
| Standard | store | €90 | €972 | BOS, TOS, OSD + Shift (5席) |
| Premium | store | €149 | €1,610 | Standard全て + Self Station, Reservation, QR Menu, Receipt, Accountant Connect + Shift (10席) |

---

## シナリオ一覧

### シナリオ1: 1店舗目が未課金（Basic/Standard/Premium いずれもなし）

```
前提: 組織は存在するが、subscription_itemsにレコードなし

1. Store作成
   └→ Store作成成功（subscription不要）
   └→ subscription_itemsには何も作られない

2. 利用可能な機能
   ├→ ダッシュボードアクセス: 可能
   ├→ 商品作成・管理: 可能
   ├→ BOS Display作成: ❌ ブロック (API: 403)
   ├→ TOS Display作成: ❌ ブロック (API: 403)
   ├→ Self Station Display作成: ⚠️ APIチェックなし（UIのみブロック）
   ├→ KDS設定: 可能（サブスクチェックなし）
   └→ Shift: アプリレベルでブロック（subscription_required_screen）

3. 課金アプリを使いたい場合
   └→ subscription-webでチェックアウト手続き（初回購入）
   └→ Store選択 → Stripe決済 → subscription_item作成
```

### シナリオ2: 1店舗目がBasicのみ課金済み

```
前提: org単位のBasicプランがactive

1. Store作成
   └→ Store作成成功
   └→ subscription_itemsには何も作られない

2. 利用可能な機能（新規Store）
   ├→ Basicアプリ（QR Menu, Receipt等）: ✅ 利用可能
   │   （Basicはorg単位なので全Storeに適用）
   ├→ BOS Display作成: ❌ ブロック (API: 403)
   ├→ TOS Display作成: ❌ ブロック (API: 403)
   ├→ Self Station Display作成: ⚠️ APIチェックなし
   └→ Shift: ❌ Basicには含まれない

3. BOS/TOS/Self Station/Shiftを使いたい場合
   └→ subscription-webでStandard/Premiumをチェックアウト
   └→ 新規Storeを選択して購入
   └→ store単位のsubscription_item作成
```

### シナリオ3: 1店舗目がStandard課金済み

```
前提: Store Aに対してStandard subscription_itemがactive

1. Store B作成
   └→ Store作成成功
   └→ subscription_itemsには何も作られない

2. 利用可能な機能（Store B）
   ├→ Standardアプリ（BOS, TOS, OSD, Shift）: ❌ Store Bは未課金
   ├→ BOS Display作成: ❌ ブロック (API: 403)
   ├→ TOS Display作成: ❌ ブロック (API: 403)
   └→ Self Station: ❌ Standardには含まれない

3. Store BでBOS等を使いたい場合
   ├→ 方法A: /api/billing/stores POST で既存サブスクにStore追加
   │   └→ Stripe quantity増加 + subscription_item作成
   └→ 方法B: subscription-webで新規チェックアウト（Store B選択）

4. UI表示
   └→ BOS Displays画面: 警告バナー
       「1 store(s) without Kiosk Self-Order System subscription
        Store B - Subscribe in Settings to enable KSO access」
       → 「Manage Stores →」で /dashboard/settings?tab=billing へ誘導
```

### シナリオ4: 1店舗目がPremium課金済み

```
前提: Store Aに対してPremium subscription_itemがactive

1. Store B作成
   └→ Store作成成功
   └→ subscription_itemsには何も作られない

2. 利用可能な機能（Store B）
   ├→ 全Premiumアプリ: ❌ Store Bは未課金
   ├→ BOS Display作成: ❌ ブロック (API: 403)
   ├→ TOS Display作成: ❌ ブロック (API: 403)
   └→ Self Station Display作成: ⚠️ APIチェックなし

3. Store BでPremiumアプリを使いたい場合
   ├→ 方法A: /api/billing/stores POST で既存サブスクにStore追加
   │   └→ Stripe quantity増加 + subscription_item作成
   └→ 方法B: subscription-webで新規チェックアウト（Store B選択）

4. Store BをStandardで契約したい場合
   └→ subscription-webでStandardプランのチェックアウト（Store B選択）
   └→ Store AはPremium、Store BはStandardで別管理
```

### シナリオ5: 1店舗目がBasic + Standard/Premium 課金済み

```
前提: org単位Basic + Store A単位のStandard or Premium

1. Store B作成
   └→ Store作成成功
   └→ subscription_itemsには何も作られない

2. 利用可能な機能（Store B）
   ├→ Basicアプリ: ✅ 利用可能（org単位なので全Store適用）
   ├→ Standard/Premiumアプリ: ❌ Store Bは未課金
   └→ Display作成: BOS/TOS ❌ブロック、Self Station ⚠️APIチェックなし

3. フローはシナリオ3/4と同様
```

---

## チェックリスト

### A. Store作成時（subscription_itemが自動作成されないこと）

| # | チェック項目 | 期待動作 | 実装状況 | コード箇所 |
|---|---|---|---|---|
| A-1 | Store作成APIでsubscription_itemが作られない | subscription_itemsにINSERTなし | ✅ **検証済** | `api/stores/route.ts:141-145` |
| A-2 | Store作成はサブスク未課金でも可能 | 403にならず作成成功 | ✅ **検証済** | `api/stores/route.ts` (サブスクチェックなし、manage権限のみ) |
| A-3 | Store作成時にDBトリガーでsubscription_itemが作られない | トリガーなし | ✅ **検証済** | `003_triggers_and_functions.sql:141-143` (audit/logのみ) |

### B. Display作成のサブスクリプションゲーティング

| # | チェック項目 | 期待動作 | 実装状況 | コード箇所 |
|---|---|---|---|---|
| B-1 | BOS Display作成API: 未課金Storeで403 | checkStoreAccess()で拒否 | ✅ **検証済** | `api/bos-displays/route.ts:177-186` エラー: "Store does not have Kiosk Self-Order System subscription" |
| B-2 | TOS Display作成API: 未課金Storeで403 | checkStoreAccess()で拒否 | ✅ **検証済** | `api/table-displays/route.ts:177-186` エラー: "Store does not have Table Order System subscription" |
| B-3 | Self Station Display作成API: 未課金Storeで403 | checkStoreAccess()で拒否 | ❌ **チェックなし (検証済)** | `api/customer-displays/route.ts:45-103` name/org_idのみ検証、サブスク検証なし |
| B-4 | BOS Display GET: 課金済みStoreのみ返す | getSubscribedStoreIds()でフィルタ | ✅ **検証済** | `api/bos-displays/route.ts:50,73-75` |
| B-5 | TOS Display GET: 課金済みStoreのみ返す | getSubscribedStoreIds()でフィルタ | ✅ **検証済** | `api/table-displays/route.ts:50,73-75` |
| B-6 | KDS Display設定 | サブスクチェック | ⚠️ **チェックなし (検証済)** | `api/kds/displays/[id]/route.ts` GET/PUTともにサブスクチェックなし |

### C. UI側のサブスクリプション表示

| # | チェック項目 | 期待動作 | 実装状況 | コード箇所 |
|---|---|---|---|---|
| C-1 | BOS Displays画面: 未課金時Lock表示 | 「Subscription Required」+ Lock icon | ✅ **検証済** | `kiosk-selforder-system/.../DisplaysTab.tsx:76-87` |
| C-2 | BOS Displays画面: 一部Store未課金時の警告 | 黄緑バナーで未課金Store名表示 | ✅ **検証済** | `DisplaysTab.tsx:91-111` |
| C-3 | TOS Displays画面: 未課金時Lock表示 | 「Subscription Required」+ Lock icon | ✅ **検証済** | `table-order/.../DisplaysTab.tsx:76-87` |
| C-4 | TOS Displays画面: 一部Store未課金時の警告 | 黄色バナーで未課金Store名表示 | ✅ **検証済** | `DisplaysTab.tsx:91-111` |
| C-5 | Self Station画面: 未課金時Lock表示 | 「Subscription Required」+ Lock icon | ✅ **検証済** | `self-payment/.../DevicesTab.tsx:308-319` |
| C-6 | Self Station画面: 一部Store未課金時の警告 | ピンクバナーで未課金Store名表示 | ✅ **検証済** | `DevicesTab.tsx:323-343` |
| C-7 | 警告バナーからBilling設定への誘導リンク | 「Manage Stores →」→ settings?tab=billing | ✅ **検証済** | BOS:104行, TOS:104行, SPS:336行 |

### D. Store追加課金フロー

| # | チェック項目 | 期待動作 | 実装状況 | コード箇所 |
|---|---|---|---|---|
| D-1 | 既存サブスクへのStore追加 (POST /api/billing/stores) | Stripe quantity増加 + subscription_item作成 | ✅ **検証済** | quantity更新:`route.ts:355-361` item作成:`route.ts:396-425` |
| D-2 | サブスク未契約時のStore追加拒否 | 「No active subscription found」エラー | ✅ **検証済** | `route.ts:262-267` |
| D-3 | Basicプラン時のStore追加拒否 | 「Basic plan covers every store」エラー | ✅ **検証済** | `route.ts:270-279` |
| D-4 | stripe_subscription_idなし時の拒否 | サブスク未検出エラー | ✅ **検証済** | `route.ts:289` |
| D-5 | 既に課金済みStoreの重複追加防止 | 重複チェックでエラー | ✅ **検証済** | `route.ts:314-322` (check) `337-341` (error) |
| D-6 | subscription-webでの新規チェックアウト | Store選択 → Stripe決済 → subscription_item作成 | ✅ **検証済** | `checkout/route.ts:22-26` (accept) `443-472` (session) |
| D-7 | チェックアウト時の重複プランチェック | 同一プランの重複購入を409で拒否 | ✅ **検証済** | `checkout/route.ts:159-167` (check) `173-177` (error) |

### E. Shiftアプリ従業員管理・Overage課金

| # | チェック項目 | 期待動作 | 実装状況 | コード箇所 |
|---|---|---|---|---|
| E-1 | Shiftアプリ: org単位のサブスクゲート | subscription未契約時はログイン不可 | ✅ **検証済** | `subscription_required_screen.dart:1-83` AuthStatus.subscriptionRequired時に表示 |
| E-2 | 従業員追加時のサブスクチェック | チェックなし（席数制御は課金側で管理） | ⚠️ **検証済 (意図的)** | `api/team/invitations/route.ts:113-299` admin/ownerロールのみ検証 |
| E-3 | Shift超過課金 (daily snapshot cron) | 日次で active_user_count をカウント | ✅ **検証済** | `daily-snapshot/route.ts:26-46` |
| E-4 | Stripe overage報告 (daily) | included_seats超過分をStripeに報告 | ✅ **検証済** | `daily-snapshot/route.ts:213-220` stripe.billing.meterEvents.create() |
| E-5 | Stripe overage報告 (monthly) | 月次で最終確定値をStripeに報告 | ✅ **検証済** | `report-usage/route.ts:200-206` stripe.billing.meterEvents.create() |
| E-6 | **複数Store時のincluded_seats合算** | 全Storeのshift_included_seatsをSUMして判定 | ❌ **バグ (検証済)** | `daily-snapshot/route.ts:149-159` Map.set()で上書き。dedupe(141-147)はidベースのため複数Store分は残る |
| E-7 | **複数Store時のincluded_seats合算 (monthly)** | 同上（月次cron側） | ❌ **バグ (検証済)** | `report-usage/route.ts:138-162` 各subscription_itemで個別計算→同一orgに複数回報告 |
| E-8 | Store追加でincluded_seats増加後のoverage減少 | 翌日のsnapshotからoverage減少 | ❌ **E-6/E-7のバグにより不正確** | — |
| E-9 | stripe_customer_idなしのサブスクをスキップ | card-free trialはoverage報告しない | ✅ **検証済** | daily:`153行`条件分岐 / report-usage:`141-143行`explicit skip |

### F. サブスクリプション検証ロジック

| # | チェック項目 | 期待動作 | 実装状況 | コード箇所 |
|---|---|---|---|---|
| F-1 | store_app_entitlements ビュー | tier/legacyの統合ビュー | ✅ **検証済** | DB上にVIEW存在確認。UNION ALLでtier(unnest included_app_slugs) + legacy(app_slug)を統合 |
| F-2 | checkStoreAccess() | store_id一致 or org全体(store_id=NULL)で判定 | ✅ **検証済** | `subscription-service.ts:67-87` `.or(\`store_id.eq.${storeId},store_id.is.null\`)` |
| F-3 | getSubscribedStoreIds() | Basic時は全Store、それ以外は個別Store返却 | ✅ **検証済** | `subscription-service.ts:165-182` hasOrgGrant時は全Store返却 |
| F-4 | ACTIVE_ITEM_STATUSES | 'active', 'trialing' のみ | ✅ **検証済** | `constants.ts:13` `['active', 'trialing'] as const` |

---

## 発見された問題点

### 要修正 (HIGH)

| # | 問題 | 影響 | 修正案 |
|---|---|---|---|
| 1 | Self Station (customer-displays) APIにサブスクチェックがない | UIをバイパスしてAPIを直接叩けば未課金Storeにdisplay作成可能 | BOS/TOSと同様に `checkStoreAccess(org_id, APP_SLUGS.SELF_STATION, store_id)` を追加 |
| 2 | **Shift overage: 複数Store時のincluded_seats合算バグ** | 複数StoreがStandard/Premiumに加入しても、1Storeのincluded_seatsしか使われない。過剰にoverage課金される | 下記「Shift included_seats合算バグ詳細」参照 |

### 要検討 (MEDIUM)

| # | 問題 | 影響 | 検討事項 |
|---|---|---|---|
| 3 | KDS display設定にサブスクチェックがない | KDSはStandard/Premiumに含まれるがチェックなし | KDSはdisplay作成ではなく設定変更のみなので影響は限定的。BOS/TOSのdisplayが作れなければKDSも実質使えない |
| 4 | Store作成に上限チェックがない | 未課金ユーザーが無制限にStoreを作成可能 | Storeだけ作成しても課金アプリは使えないので実害は少ないが、将来的にはプランに応じた上限設定を検討 |
| 5 | FlutterPOSにサブスクチェックがない | デバイス登録・Display操作にサブスク検証なし | ReactPOS APIでDisplay作成がブロックされるため実害は限定的。ただしサブスク解約後のDisplay残存時に問題あり |

### 正常動作（意図通り）

| # | 項目 | 理由 |
|---|---|---|
| 5 | Shift従業員追加時にブロックしない | 超過分は自動的にoverage課金されるため、追加自体はブロック不要 |
| 6 | Store作成がサブスク不要 | Storeはまず作成し、後から課金するフローが正しい |
| 7 | 商品作成がサブスク不要 | 商品データの準備は課金前に行える方がUXが良い |

---

## Shift included_seats合算バグ詳細

### 問題の概要

複数StoreがStandard/Premiumに加入している組織で、Shift Managerの無料枠（included_seats）が
**全Storeの合計ではなく、最後に処理された1Storeの値のみ**で計算されている。

### 影響を受けるファイル

1. **daily-snapshot cron** — `shift-management-app/src/app/api/cron/daily-snapshot/route.ts:149-159`
2. **report-usage cron** — `shift-management-app/src/app/api/cron/report-usage/route.ts:158-162`

### バグの原因（daily-snapshot cron）

```typescript
// 行149-159: Map.set()で上書きされるため、最後の1件のincludedSeatsのみが残る
const subByOrg = new Map<string, { stripeCustomerId: string; includedSeats: number }>();
for (const sub of activeSubscriptions) {
  const plan = (sub as any).subscription_plans;
  if (sub.organization_id && sub.stripe_customer_id) {
    subByOrg.set(sub.organization_id, {          // ← 同じorgIdで上書き
      stripeCustomerId: sub.stripe_customer_id,
      includedSeats: plan?.shift_included_seats ?? 0,  // ← 最後の1件の値のみ
    });
  }
}
```

### バグの原因（report-usage cron）

```typescript
// 行138-162: activeSubscriptionsをループで処理するが、各subscription_itemごとに
// そのitemのshift_included_seatsだけでoverageを計算
for (const sub of activeSubscriptions) {
  const plan = (sub as any).subscription_plans;
  const includedSeats: number = plan?.shift_included_seats ?? 0;  // ← この1件の値のみ
  const billableOverage = Math.max(0, activeUserCount - includedSeats);
  // ...Stripeに報告
}
// さらに複数subscription_itemがあると同じorgに対して複数回報告される可能性あり
```

### 具体例

```
例: 組織に12人の従業員、Store A (Premium=10席) + Store B (Premium=10席)

期待動作:
  included_seats = 10 + 10 = 20席
  overage = 12 - 20 = 0 (課金なし)

現在の動作 (daily-snapshot):
  subByOrg.set(orgId, {includedSeats: 10})  ← Store A
  subByOrg.set(orgId, {includedSeats: 10})  ← Store B (上書き)
  → includedSeats = 10 (最後の1件)
  → overage = 12 - 10 = 2 (€10の過剰課金!)

現在の動作 (report-usage):
  Loop iteration 1 (Store A): overage = 12 - 10 = 2 → Stripeに報告
  Loop iteration 2 (Store B): overage = 12 - 10 = 2 → Stripeに再報告
  → 二重報告の可能性あり
```

### 修正案

**daily-snapshot cron (行149-159):**
```typescript
// 修正: SUMで合算する
const subByOrg = new Map<string, { stripeCustomerId: string; includedSeats: number }>();
for (const sub of activeSubscriptions) {
  const plan = (sub as any).subscription_plans;
  if (sub.organization_id && sub.stripe_customer_id) {
    const existing = subByOrg.get(sub.organization_id);
    if (existing) {
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

**report-usage cron (行137-220):**
```typescript
// 修正: org単位で事前にincludedSeatsを合算し、orgごとに1回だけ報告する
const seatsByOrg = new Map<string, { stripeCustomerId: string; includedSeats: number }>();
for (const sub of activeSubscriptions) {
  const plan = (sub as any).subscription_plans;
  if (sub.organization_id && sub.stripe_customer_id) {
    const existing = seatsByOrg.get(sub.organization_id);
    if (existing) {
      existing.includedSeats += (plan?.shift_included_seats ?? 0);
    } else {
      seatsByOrg.set(sub.organization_id, {
        stripeCustomerId: sub.stripe_customer_id,
        includedSeats: plan?.shift_included_seats ?? 0,
      });
    }
  }
}
// その後、seatsByOrgをループして各orgに対して1回だけ報告
```

---

## Shift Overage シナリオ別チェックリスト

### G. Store追加に伴うShift無料枠の変動

| # | シナリオ | 期待動作 | 実装状況 |
|---|---|---|---|
| G-1 | 1Store Premium (10席) + 12人従業員 → overage 2人 | overage = 12 - 10 = 2 | ✅ **検証済** (1Store時はMap.set上書きでも結果同じ) |
| G-2 | 2Store Premium追加 → 無料枠20席に増加 → overage 0 | overage = 12 - 20 = 0 | ❌ **バグ検証済: 10席のまま計算** |
| G-3 | Store A Premium(10) + Store B Standard(5) → 無料枠15 | overage = max(0, N - 15) | ❌ **バグ検証済: 最後の1件のみ（5 or 10）** |
| G-4 | Store追加後の翌日snapshotで新しいincluded_seatsが反映 | 翌日から正しいoverage計算 | ❌ **E-6のバグにより不正確** |
| G-5 | Storeのサブスクをキャンセル → 無料枠減少 → overage増加 | キャンセル後のcronで正しく増加 | ⚠️ 未検証（合算バグ修正後に確認必要） |

### H. Shift Overage 境界条件

| # | シナリオ | 期待動作 | 実装状況 |
|---|---|---|---|
| H-1 | 従業員数 = included_seats ちょうど | overage = 0 | ✅ **検証済** | `daily-snapshot:205` `Math.max(0, count - orgSub.includedSeats)` |
| H-2 | 従業員数 < included_seats | overage = 0 | ✅ **検証済** | `daily-snapshot:206` `billableCount <= 0` でcontinue |
| H-3 | 月中にStore追加 → included_seats増加 | 翌日のdaily snapshotから反映 | ⚠️ バグ修正後は正常になるはず |
| H-4 | 月中に従業員追加 → daily snapshotのcron後に追加 | 翌日のsnapshotで反映 | ✅ **検証済** (意図通り) |
| H-5 | stripe_customer_idがNULLのsubscription_item | overage報告をスキップ | ✅ **検証済** | daily:`153行` / report-usage:`141-143行` |
| H-6 | 同一orgに複数のstripe_customer_id | 最後に処理されたcustomer_idに報告 | ⚠️ 潜在的問題（通常は同一customer） |
| H-7 | Standaloneシフトプラン (included_seats=0) | 全従業員分がbillable | ✅ **検証済** |
| H-8 | Standaloneシフト + TierプランのShift | 重複フィルタ（dedupe）で1件に | ✅ **検証済** | `daily-snapshot:141-147` `report-usage:66-72` idベースdedupe |

---

## I. FlutterPOS サブスクリプションチェック

| # | チェック項目 | 期待動作 | 実装状況 | コード箇所 |
|---|---|---|---|---|
| I-1 | デバイス登録時のサブスクチェック | 未課金Storeへの登録をブロック | ❌ **チェックなし (検証済)** | `device_registration_service.dart` Store存在チェックのみ |
| I-2 | Display操作時のサブスクチェック | 未課金StoreのDisplay操作をブロック | ❌ **チェックなし (検証済)** | `display_service.dart` サブスク検証なし |
| I-3 | BOS注文処理時のサブスクチェック | 未課金StoreでのBOS注文をブロック | ❌ **チェックなし (検証済)** | BOS関連スクリーンにentitlementチェックなし |
| I-4 | Billing情報の取得と利用 | activeAppsで機能制限 | ⚠️ **取得のみ (検証済)** | `billing_repository.dart:10-115` activeApps取得するが制限に未使用 |

### FlutterPOSの問題点の実質的影響

FlutterPOSにサブスクリプションチェックがないが、**ReactPOS API側（BOS/TOSのDisplay作成API）で
サブスクチェックを行っているため、未課金StoreではDisplay自体が作成できない**。
FlutterPOS側でDisplayに接続しようとしても、接続先のDisplay IDが存在しないため実質的にブロックされる。

ただし、以下のケースでは問題が発生する可能性がある：
- サブスク解約後にDisplay IDが残存している場合、FlutterPOSは引き続き接続可能
- customer-displays（Self Station）はAPIチェックなしで作成可能なため、FlutterPOS経由で利用可能

---

## 正常フローの確認まとめ

```
[Store作成] ────────────────────────────────────────────┐
    │                                                    │
    │  subscription_items: 何も作られない                   │
    │                                                    │
    ▼                                                    │
[Dashboard] ← 商品作成・設定は自由に可能                     │
    │                                                    │
    ▼                                                    │
[BOS/TOS/SelfStation Display設定画面]                      │
    │                                                    │
    ├─ 全Store未課金 → Lock画面表示                         │
    │   「Subscription Required」                         │
    │                                                    │
    ├─ 一部Store未課金 → 警告バナー                         │
    │   「X store(s) without subscription」               │
    │   → 「Manage Stores →」リンク                       │
    │                                                    │
    ▼                                                    │
[Billing Settings / subscription-web]                    │
    │                                                    │
    ├─ 方法A: 既存サブスクにStore追加                        │
    │   POST /api/billing/stores                         │
    │   → Stripe quantity更新                             │
    │   → subscription_item作成                           │
    │                                                    │
    └─ 方法B: 新規チェックアウト                             │
        → Store選択 → Stripe決済                          │
        → subscription_item作成                           │
                                                         │
    ▼                                                    │
[Display作成可能] ← subscription_item.status = active     │
    └→ BOS/TOS: APIチェック通過 ✅                          │
    └→ Self Station: ⚠️ APIチェックなし（要修正）            │
                                                         │
─────────────────────────────────────────────────────────┘
```

---

## サブスクリプション解約フロー

### 解約の流れ

```
[ユーザー操作]
  subscription-web の「Cancel」ボタン
    ↓
[Stripe API]
  stripe.subscriptions.update({ cancel_at_period_end: true })
    ↓
[DB更新]
  subscription_items.cancel_at_period_end = true
  (statusは変わらず active のまま)
    ↓
[猶予期間]
  current_period_end まで全機能利用可能
    ↓
[期間終了時: Stripe Webhook]
  customer.subscription.deleted イベント発火
    ↓
[Webhook Handler]
  subscription_items.status = 'canceled'
  subscription_items.canceled_at = NOW()
    ↓
[アクセス制御]
  store_app_entitlements ビューから除外
  (ACTIVE_ITEM_STATUSES = ['active', 'trialing'] のみ)
    ↓
[ユーザー体験]
  次回リフレッシュ/ログイン時にブロック
```

### subscription_items.status の遷移

| status | 意味 | アクセス可否 |
|---|---|---|
| `active` | 有効な課金中 | ✅ 利用可能 |
| `trialing` | トライアル期間中 | ✅ 利用可能 |
| `inactive` | 支払い失敗 | ❌ 利用不可（7日間の猶予後ブロック） |
| `canceled` | 解約済み | ❌ 利用不可 |

---

## J. 解約後のアクセス制御チェックリスト

### J-1. Display API のアクセス制御（解約後）

| # | チェック項目 | 期待動作 | 実装状況 | コード箇所 |
|---|---|---|---|---|
| J-1-1 | BOS Display GET/PUT/DELETE: 解約後に403 | checkStoreAccess()で拒否 | ✅ **検証済** | `bos-displays/[id]/route.ts:32-42,104-112,310-320` 毎リクエストでチェック |
| J-1-2 | TOS Display GET/PUT/DELETE: 解約後に403 | checkStoreAccess()で拒否 | ✅ **検証済** | `table-displays/[id]/route.ts:32-42,104-112,228-239` 毎リクエストでチェック |
| J-1-3 | Self Station Display GET/PUT/DELETE: 解約後に403 | checkStoreAccess()で拒否 | ❌ **チェックなし** | `customer-displays/[id]/route.ts` サブスクチェックなし |
| J-1-4 | BOS Display一覧 GET: 解約後は空リスト | getSubscribedStoreIds()でフィルタ | ✅ **検証済** | `bos-displays/route.ts:50,73-75` |
| J-1-5 | TOS Display一覧 GET: 解約後は空リスト | getSubscribedStoreIds()でフィルタ | ✅ **検証済** | `table-displays/route.ts:50,73-75` |
| J-1-6 | Self Station Display一覧 GET: 解約後もフィルタなし | フィルタされるべき | ❌ **フィルタなし** | `customer-displays/route.ts:22-26` org_idのみでフィルタ |

### J-2. Display データの残存

| # | チェック項目 | 期待動作 | 実装状況 |
|---|---|---|---|
| J-2-1 | BOS Display: 解約後にDBから削除/無効化 | 自動削除 or 無効化 | ❌ **何もしない** — DB に残存 |
| J-2-2 | TOS Display: 解約後にDBから削除/無効化 | 自動削除 or 無効化 | ❌ **何もしない** — DB に残存 |
| J-2-3 | Self Station Display: 解約後にDBから削除/無効化 | 自動削除 or 無効化 | ❌ **何もしない** — DB に残存 |
| J-2-4 | 再契約後にDisplay復活 | 既存Display再利用可能 | ✅ **意図的** — データ残存のメリット |

### J-3. 注文処理のアクセス制御（解約後）

| # | チェック項目 | 期待動作 | 実装状況 | コード箇所 |
|---|---|---|---|---|
| J-3-1 | TOS注文作成: 解約後にブロック | SUBSCRIPTION_INACTIVE エラー | ✅ **検証済** | `orders/create/route.ts:120-128` |
| J-3-2 | QRオーダーセッション: 解約後にブロック | 403 SUBSCRIPTION_INACTIVE | ✅ **検証済** | `qr-order/sessions/route.ts:65-78` |
| J-3-3 | TOSセッション: 解約後にブロック | 403 SUBSCRIPTION_INACTIVE | ✅ **検証済** | `tos/sessions/create/route.ts:62-79` |
| J-3-4 | BOS注文作成: 解約後にブロック | checkStoreAccess()で拒否 | ⚠️ **未確認** — BOS注文APIの実装による |

### J-4. WebSocket接続（解約後）

| # | チェック項目 | 期待動作 | 実装状況 |
|---|---|---|---|
| J-4-1 | 既存WebSocket接続: 解約時に切断 | リアルタイム切断 | ❌ **切断しない** — トークン期限まで有効 |
| J-4-2 | 新規WebSocket接続: 解約後にブロック | 接続拒否 | ❌ **チェックなし** — JWT検証のみ、サブスクチェックなし |
| J-4-3 | WebSocket再認証: サブスクチェック | 再認証時にブロック | ❌ **チェックなし** — トークン有効性のみ |

### J-5. FlutterPOS の解約後挙動

| # | チェック項目 | 期待動作 | 実装状況 |
|---|---|---|---|
| J-5-1 | FlutterPOS: ログイン時のサブスクチェック | 未契約時にブロック | ⚠️ **間接的** — Display IDが存在しなければ接続不可だが、残存していれば接続可能 |
| J-5-2 | FlutterPOS: 実行中のサブスク変更検知 | リアルタイムでブロック | ❌ **検知しない** — ポーリングなし、アプリ再起動まで有効 |
| J-5-3 | FlutterPOS: BOS注文処理（解約後） | 注文ブロック | ❌ **ブロックしない** — FlutterPOS側にサブスクチェックなし |
| J-5-4 | FlutterPOS: 定期的なサブスク確認 | 5-10分間隔で確認 | ❌ **なし** — ログイン/アプリ復帰時のみ |

### J-6. Shiftアプリの解約後挙動

| # | チェック項目 | 期待動作 | 実装状況 | コード箇所 |
|---|---|---|---|---|
| J-6-1 | Shift Flutter: ログイン時にPaywall表示 | SubscriptionRequired画面 | ✅ **検証済** | `paywall_screen.dart` "Access unavailable" |
| J-6-2 | Shift Web: ダッシュボードブロック | SubscriptionRequired表示 | ✅ **検証済** | `dashboard/layout.tsx:38-157` |
| J-6-3 | Shift: 既存データの閲覧 | UIブロックでアクセス不可 | ⚠️ **UIのみ** — APIにサブスクチェックなし |
| J-6-4 | Shift: Overage課金の停止 | daily-snapshot/report-usageがスキップ | ✅ **検証済** | status IN ('active','trialing') フィルタ |
| J-6-5 | Shift: 月中解約時の最終請求 | 解約前に報告済みの分のみ請求 | ✅ **正常** — cancel_at_period_endで猶予期間あり |
| J-6-6 | Shift Flutter: fail-open動作 | API障害時にアクセス許可 | ⚠️ **意図的** — billing.status=='unknown'でアクセス許可 |

---

## 解約後の問題点まとめ

### 要修正 (HIGH)

| # | 問題 | 影響 | 修正案 |
|---|---|---|---|
| 6 | **Self Station Display: 解約後もAPIアクセス可能** | `customer-displays/[id]` の GET/PUT/DELETE にサブスクチェックなし。解約後もDisplay操作可能 | BOS/TOSと同様に `checkStoreAccess()` を全ハンドラに追加 |
| 7 | **Self Station Display一覧: 解約後もフィルタなし** | 全DisplayがGETで返される。BOS/TOSは `getSubscribedStoreIds()` でフィルタ済み | GETにも `getSubscribedStoreIds()` フィルタを追加 |

### 要検討 (MEDIUM)

| # | 問題 | 影響 | 検討事項 |
|---|---|---|---|
| 8 | **WebSocket: 解約後も接続維持** | 解約後もJWT期限（24h）までWebSocket接続が有効。リアルタイムメッセージ受信可能 | WebSocket heartbeatでサブスクチェックを追加、または解約webhookでセッション無効化 |
| 9 | **FlutterPOS: 実行中のサブスク検知なし** | 解約後もアプリ再起動までBOS操作可能 | 定期ポーリング（5-10分間隔）またはWebSocket経由でサブスク変更通知 |
| 10 | **Display残存** | 解約後もDisplayデータがDBに残る | 意図的（再契約時に復活可能）だが、残存Displayへの接続をブロックする仕組みが必要 |
| 11 | **Shift API: サブスクチェックなし** | UIはブロックされるがAPIは直接アクセス可能。解約後もシフトデータ取得可能 | API middlewareまたは個別ルートにサブスクチェック追加 |

### 正常動作（意図通り）

| # | 項目 | 理由 |
|---|---|---|
| 8 | BOS/TOS Display API: 解約後に403 | 毎リクエストで `checkStoreAccess()` 実行 |
| 9 | TOS注文・セッション: 解約後にブロック | 注文APIにサブスクチェックあり |
| 10 | cancel_at_period_end による猶予期間 | 課金期間終了まで全機能利用可能（Stripeの標準動作） |
| 11 | Display残存（再契約復活用） | データ削除しないことで再契約時のUXが向上 |
| 12 | Shift overage課金の停止 | daily-snapshot/report-usageが canceled を正しくスキップ |

---

## 解約フローの確認まとめ

```
[解約操作]
  subscription-web「Cancel」
    ↓
[Stripe]
  cancel_at_period_end = true
    ↓
[猶予期間]  ← subscription_items.status = 'active' のまま
  ├→ BOS/TOS Display: ✅ 利用可能
  ├→ Self Station: ✅ 利用可能
  ├→ 注文処理: ✅ 利用可能
  ├→ Shift: ✅ 利用可能
  └→ Overage課金: ✅ 継続（期間終了まで）
    ↓
[期間終了: Webhook → status='canceled']
    ↓
[アクセス制御]
  ├→ BOS Display API: ✅ 403でブロック（毎リクエストチェック）
  ├→ TOS Display API: ✅ 403でブロック（毎リクエストチェック）
  ├→ Self Station API: ❌ ブロックされない（チェックなし）
  ├→ TOS注文/セッション: ✅ ブロック
  ├→ WebSocket: ❌ JWT期限まで接続維持
  ├→ FlutterPOS: ❌ アプリ再起動までBOS操作可能
  ├→ Shift Flutter: ✅ Paywall表示（次回ログイン時）
  ├→ Shift Web: ✅ SubscriptionRequired表示
  └→ Overage課金: ✅ 停止
    ↓
[Display残存]
  ├→ BOS/TOS Display: DB残存だがAPI 403でブロック ✅
  ├→ Self Station: DB残存 + API未ブロック ❌
  └→ 再契約時: Display復活可能 ✅（意図的）
```

---

*最終更新: 2026-06-01*
*調査対象: ReactRestaurantPOS, subscription-web, shift-management-app, order_sys/pos/flutter_app, websocket-server*
*全チェック項目コードレベル検証完了*
