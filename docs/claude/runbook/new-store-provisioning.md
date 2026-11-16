# 新規店舗プロビジョニング手順

**作成 2026-11-16** / 読み手: 社内
初版は **Forno by Casa Italia**（Train Factory 共通QR）の実作業から起こしたもの。
実例: `marketing/docs/claude/prospects/train-factory/Docs/forno-setup-plan.md`

> **適用範囲**: 弊社がセットアップを代行して店舗に引き渡す新規アカウント。
> org / store / 税率 / 商品 / トライアルを一通り作る。
>
> ⚠️ **自動化スクリプトは存在しない。** 一部の古い資料が
> `scripts/provision-organization.ts` を参照しているが、**このリポジトリには無い**
> （履歴にも無い）。本書の手順は**手作業の記録**である。

---

## 0. 事前に確定させること

| 項目 | なぜ必要 |
|---|---|
| **請求先の登記社名** | `organizations.name` はレシートと請求書の宛名。店名ではない |
| **Y-tunnus / 事業者番号** | `organizations.business_id`。**レシートの法定記載**に関わる |
| **国 / 通貨 / タイムゾーン** | 税率体系が決まる。既定は FI / EUR / Europe/Helsinki |
| **メニュー（価格・税率）** | 税込/税抜のどちらで掲載されているか必ず確認 |
| **酒類の有無** | 税率が分かれる。モバイル注文の年齢確認は別途論点 |

🔴 **法人名が未確定でも着手できる。** 暫定で登録し、
**初回請求の発行より前に**確定させて修正する（無料トライアル期間が猶予になる）。
その場合**どこを直すことになるかを先に書き出しておく**:
`organizations.name` / `business_id` / 請求情報 / Stripe 顧客情報。

### 💡 法人名の調べ方（Wolt 掲載店なら1発で引ける）

**Wolt の venue ペイロードに加盟店の法人情報が入っている** — Wolt が決済相手として
保持している値なので、屋号ではなく**登記社名と Y-tunnus**が返る。

```bash
curl -sS -H "User-Agent: Mozilla/5.0" -H "Referer: https://wolt.com/" \
  "https://consumer-api.wolt.com/order-xp/web/v1/pages/venue/slug/<slug>/static" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['venue']['merchant'])"
# -> {'name': 'Fintecso Oy', 'business_id': '2251659-3', ...}
```

**裏取りは PRH 公式API**（認証不要）:

```bash
curl -sS "https://avoindata.prh.fi/opendata-ytj-api/v3/companies?businessId=<y-tunnus>"
```

`names` に **type:1 = 登記社名 / type:3 = 補助商号（aputoiminimi）** が並ぶ。
`status: 2` が現役。

🔴 **屋号で検索しても見つからないことが多い。** 実例: 「Dragon Sticks」は
PRH 名称検索で**0件**、northdata / finder / proff でも**ヒットしない**。
運営は `Fintecso Oy`（補助商号は別ブランドの「Ravintola Mala」）だった。
**PRH の住所検索も当てにならない**（00510 Helsinki を1200社走査して該当0件）。

⚠️ **登記住所が店舗住所と一致しない場合がある**（本社住所やチェーン本部）。
不一致そのものは異常ではない。**`organizations.name` は登記社名、`stores.name` は店舗名**
で、両者が違うのは正常。

---

## 1. Supabase Auth の最小パスワード長を確認

🔴 **コードの `PASSWORD_MIN_LENGTH = 8`（`src/lib/password-policy.ts`）は上限を決めない。**
**最終的な強制点は Supabase ダッシュボードの Auth 設定**で、そこが6なら実効6。
アカウントを作る前に見る。

---

## 2. auth ユーザーを作成（パスワードは後）

メールは **`hello+<店舗名>@sciometa.com`**。`+` エイリアスなので
システムメール（招待・再設定・レシート）は全て `hello@sciometa.com` に届き、
**宛先でどの店舗向けか判別できる**。

```ts
// 一時スクリプトとして ReactRestaurantPOS/ 直下で実行する。
// ⚠️ scratchpad に置くと @supabase/supabase-js が解決できない
//    （モジュール解決がスクリプトの位置基準）。
const { data, error } = await admin.auth.admin.createUser({
  email: 'hello+<slug>@sciometa.com',
  email_confirm: true,
  user_metadata: { full_name: '<Store> Owner', app: 'pos' },
})
```

⚠️ **`tsx` は top-level await を拒否する**（cjs 出力）。`async function main()` で包む。

**パスワードはこの段階で設定しない**（§7）。

---

## 3. organization を作成

```sql
insert into organizations (name, slug, email, business_id, country, currency, timezone, website, address)
values ('<登記社名>', '<kebab-slug>', 'hello+<slug>@sciometa.com',
        '<Y-tunnus>', 'FI', 'EUR', 'Europe/Helsinki', '<url>', '<住所>')
returning id;
```

**慣例**（既存 org 実測）: `name` は**登記社名**（例 `Syriana Finland Oy`）、
`slug` はそれを kebab 化、`business_id` に Y-tunnus。

---

## 4. users 行を作って org に紐付け

🔴 **`users` 行は DBトリガーが auth ユーザー作成時に自動で作る。**
`role='owner'` / `organization_id=null` の行が既にあるので、**INSERT ではなく UPDATE**。
INSERT すると `users_pkey` 重複で落ちる（実際に落ちた・2026-11-16）。

```sql
update users
set organization_id = '<org-id>', full_name = '<Store> Owner', role = 'owner'
where id = '<auth-user-id>';
```

⚠️ **CTE の中に混ぜると、1本でも失敗したとき org 作成ごと巻き戻る。**
org/store/tax とまとめて1本の CTE で書くなら、users は UPDATE にしておくこと。

🔴 **`users.role` の列既定は `'user'`。** トリガー経由では `owner` が入るが、
別経路で作った場合は明示しないと権限が付かない。

---

## 5. tax_settings を作成（**商品投入より前**）

🔴 **`tax_settings` は org スコープ**（`organization_id` NOT NULL）。
**新 org は税率設定が0件の状態で始まる。**

```sql
insert into tax_settings (organization_id, name, rate, is_default, is_active) values
  ('<org-id>', 'VAT 13.5% (Foods)',   0.135, true,  true),
  ('<org-id>', 'VAT 25.5% (Alcohol)', 0.255, false, true);
```

🔴 **`tax_setting_id` は表示ラベルで、計算に使うのは `products.tax_rate`。**
両方入れる。片方だけだと**レシートの法定内訳が狂う**。

---

## 6. store を作成

```sql
insert into stores (organization_id, name, address, short_code, timezone, is_active, menu_slug)
values ('<org-id>', '<店舗名>', '<住所>',
        substr(md5(gen_random_uuid()::text), 1, 7),  -- 既存は7桁hex
        'Europe/Helsinki', true, '<menu-slug>')
returning id, short_code;
```

🔴 **`short_code` は NOT NULL で既定値が無い。** 必ず渡す。

---

## 7. パスワードを設定

**20文字程度のランダム生成を推奨。** ただし**セットアップ時にタブレット手入力・
口頭伝達する運用**があるなら短くする判断もある（既存アカウントは6〜8文字）。

- **記号なし・曖昧文字（O/0, I/l/1）を除いた英数字**にする
- 保存先は **`marketing/.secrets/<案件>.credentials.md`**
  （`marketing/.gitignore` が `.secrets/` を除外。`git check-ignore` で確認する）
- **計画書・仕様書には保管先だけ書く。パスワード本体は転記しない**

🔴 **先方に引き渡す際は長いパスワードに変更する**（Owner 移管とセット）。
弊社セットアップ期間限定の短さ、という整理にする。

**設定後に必ず `signInWithPassword` で実際にログインを確認する。**

---

## 8. 商品を投入

正典: `scripts/qopla-import/import-product-master.ts`

```bash
cd ReactRestaurantPOS
# dry run が既定
npx tsx scripts/qopla-import/import-product-master.ts \
  --input <products.json> --org-id <uuid> --store-id <uuid>
# 問題なければ
npx tsx scripts/qopla-import/import-product-master.ts \
  --input <products.json> --org-id <uuid> --store-id <uuid> --apply
```

### 入力 JSON は `Item` のフラット配列

```json
[{ "name": "...", "category": "...", "price_gross": 14.50, "tax_rate": 0.135,
   "sku": "XX-CAT-NAME", "grid_number": 1, "is_alcoholic": false,
   "description": "...", "options": [] }]
```

### スクリプトが担保していること

| 項目 | 内容 |
|---|---|
| `price` | **GROSS（税込）で保存**。これが契約（`src/lib/qr-order/server-side-prices.ts`） |
| `sku` | **冪等キー**。再実行で重複0（`products.name` に UNIQUE 制約は無い） |
| チャネル旗 | **明示指定**。`active_in_tos` は列既定が `true` なので省略すると TOS 全公開 |
| `is_alcoholic` | NOT NULL。**リテラル null は拒否** |
| `grid_number` | POS ボタン順（`nullsFirst:false` なので null は順序不定） |
| 文字検証 | サーマルプリンタ非対応文字を **hard fail**（`€` を含む商品名は弾かれる） |

### 🔴 既存 SKU は「スキップ」であって「更新」ではない

冪等性の根拠そのものなので正しい挙動だが、
**初回 `--apply` の後に JSON へ項目を足しても反映されない。**

→ **`description` / `options` まで入れ終えてから `--apply` する。**
後から足す場合は sku 一致で `products` を直接 UPDATE して追い付かせる。

### カテゴリ設計の不変条件

🔴 **1カテゴリ = 1税率。** 酒類は専用カテゴリに分離する
（例: `Soft Drinks` 13.5% と `Beer & Seltzer` 25.5% を混ぜない）。
混ぜると税率の誤打が構造的に起きる。和食とも案件での事故を受けた方針。

### 投入しないもの

- **価格が不明な品目**（「€4〜6.50」のような範囲表記のみ）
- **required な選択肢で候補リストが未入手のもの**
  → **空の required グループは注文を進行不能にする**

---

## 9. 商品投入の検証（SQL）

```sql
-- カテゴリ単位で税率が単一か / 本数 / 説明の有無
select c.name, count(p.id) as items,
       array_agg(distinct p.tax_rate) as tax_rates,
       count(*) filter (where p.is_alcoholic) as alcoholic,
       count(*) filter (where p.description is not null) as with_desc
from products p join categories c on c.id = p.category_id
where p.organization_id = '<org-id>'
group by c.name, c.sort_order order by c.sort_order;

-- availability と tax_setting_id の欠落
select count(*) as products,
  (select count(*) from product_availabilities pa join products p2 on p2.id = pa.product_id
    where p2.organization_id = '<org-id>') as availability_rows,
  count(*) filter (where tax_setting_id is null) as missing_tax_setting
from products where organization_id = '<org-id>';
```

**`tax_rates` が複数値のカテゴリがあれば設計ミス。** `missing_tax_setting` は0であること。

---

## 10. サブスクリプション（トライアル）を追加

正典テーブルは **`subscription_items`**。

```sql
insert into subscription_items (
  organization_id, item_type, store_id, plan_id, status,
  trial_start, trial_end, current_period_start, current_period_end,
  payment_provider, cancel_at_period_end
) values (
  '<org-id>', 'store', '<store-id>',
  '<plan-id>',          -- §10-1 で引く
  'trialing',
  now(), now() + interval '<N> months',
  now(), now() + interval '<N> months',
  'stripe', false
);
```

**慣例**（既存トライアル実測）: `item_type = 'store'`・Stripe 未連携
（`stripe_subscription_id` = null）・**`trial_end` と `current_period_end` を揃える**。

### 10-1. plan_id は毎回引く（UUID を覚えない）

**同じ tier に月額と年額の2行がある。** `interval` で絞らないと年額を掴む。

```sql
select id, name, tier, price, interval from subscription_plans
where tier = 'standard' and interval = 'month' and is_active;
```

2026-11-16 時点: 月額 `467470f1-1b2e-401a-96fc-0744db23fc99`（€90）/
年額 `9b17f3c1-70b8-4102-81c1-b1dbd98d622f`（€972）。
**この UUID は参考値。実行時に必ず引き直す。**

| 要点 | 内容 |
|---|---|
| `trialing` は全機能有効 | `ACTIVE_ITEM_STATUSES = ['active','trialing']`（`src/lib/subscription/constants.ts:36`） |
| プランの既定は14日 | `subscription_plans.trial_period_days = 14`。**直接 `trial_end` を書く場合は無関係** |
| 🔴 Stripe 連携時 | **Stripe 側のトライアル終了日をこの日付に合わせる。** ズレると二重課金か無課金 |
| ギフトカード上限 | Standard は**月10枚**（fail-closed）。繁忙期に当たるなら事前説明 |

---

## 10-2. Food Court に参加させる（共同QRを使う店舗のみ）

```sql
insert into food_court_members
  (food_court_id, store_id, organization_id, consent_status, consent_granted_at,
   display_name, cuisine_tags, display_order, is_visible)
values ('<food-court-id>', '<store-id>', '<org-id>',
        'approved', now(),          -- 弊社セットアップ時は承認済みで投入する
        '<表示名>', '{italian,pizza}', <順序>, true);
```

**Train Factory venue**: `140cdec2-e014-44aa-8597-8d55fa6ad6d9`
（`member_sort: rotate` / 60分・`seat_prefix: TF`・`list_menu_only_members: true` 設定済み）

| 列 | 注意 |
|---|---|
| `consent_status` | 既定は **`pending`**。弊社代行セットアップでは **`approved` を明示** |
| `display_name` | **null だと店舗名がそのまま出る**。「iNoodles & Poke Konepaja」のような長い店舗名は短縮形を入れる |
| `cuisine_tags` | 既定は空配列。**絞り込みに使われるので必ず入れる** |
| `display_order` | `member_sort: rotate` なら表示順の初期値にすぎない |
| `stall_label` | 区画表記（例 "A-3"）。未入手なら null のままでよい |

### 🔴 承認は2テーブルへの書き込み — `order_token` を忘れると一覧から消える

**ハブは `order_token` が null のメンバーを問答無用で落とす。**
`src/app/api/food-court/resolve/route.ts:317`:

```ts
const offerable = members.filter(m => !!m.order_token)
```

これは **consent / Stripe / サブスクのどのゲートよりも前**にある。
つまり `consent_status='approved'` だけ書いても**カードは出ない**
（実際にこれで Klandestina と Dragon Sticks が消えていた・2026-11-16）。

正典は `src/app/api/food-court/consent/route.ts` の approve 分岐。
**トークン行を先に作り、あとでメンバー行から指す**（逆順だと
「承認済みなのに開けないカード」が出る、とコードのコメントが明記）。

```sql
with target as (
  select m.id, m.store_id, m.organization_id,
         'fc_' || encode(gen_random_bytes(24), 'hex') as new_token   -- fc_ + 48 hex = 51文字
  from food_court_members m
  where m.food_court_id = '<venue-id>' and m.order_token is null
    and m.consent_status = 'approved'
), issued as (
  insert into table_access_tokens
    (store_id, organization_id, table_number, channel, token, is_active)
  select store_id, organization_id, 0, 'food_court', new_token, true from target
  returning token, store_id
)
update food_court_members m
set order_token = i.token, updated_at = now()
from issued i
where m.store_id = i.store_id and m.food_court_id = '<venue-id>';
```

| 列 | 値 | 理由 |
|---|---|---|
| `channel` | **`food_court`** | 既定は `'qr'`。間違えると通常QRの一意制約に当たる |
| `table_number` | **0** | 座席は venue トークンが持つ。ハンドオフはトークン自体 |
| `token` | `fc_` + 48桁hex | `generateOrderToken()` = `fc_${randomBytes(24).toString('hex')}` |

⚠️ **1店舗が複数 venue に属する場合、venue ごとに別トークンになる**のが正常
（実例: Tokyo Street Vallila は Kamppi Food Court と Train Factory の2本を持つ）。
「同一店舗に複数のライブトークン」= 即異常ではない。**venue 単位で1本**かを見る。

### 🔴 check 制約: `approved` には監査証跡が必須

`food_court_members_consent_trail_required`:

```
CHECK (consent_status <> 'approved' OR (consent_granted_at IS NOT NULL AND consent_granted_by IS NOT NULL))
```

**`consent_granted_by` を省くと INSERT/UPDATE が失敗する。**
弊社がセットアップする店舗は**その店舗の owner user id** を入れる慣例
（既存4件がそうなっている）。

🔴 **他社組織の店舗を代理で承認する場合は、先方のユーザーIDを入れない。**
この列は「誰が同意したか」の監査証跡なので、本人がクリックしていない同意を
本人の操作として記録することになる。**弊社側のユーザーID**を入れて
「弊社が代理で記録した」という事実を残す（実例: Klandestina は口頭許可を得て
`hello@sciometa.com` で記録・2026-11-16）。

🔴 **店舗が自分で承認する場合は代行できない**（`consent` ルートは admin allowlist を見ない）。
既存顧客を後から招待する場合は `pending` で作り、先方に承認を依頼する。

### 検証SQL

```sql
select m.display_name, m.consent_status,
       m.order_token is not null as has_token,
       t.channel, t.table_number, t.is_active,
       (t.token = m.order_token) as paired
from food_court_members m
left join table_access_tokens t on t.token = m.order_token
where m.food_court_id = '<venue-id>';
```

**`has_token` と `paired` が全て true** であること。false の行は一覧に出ない。

---

## 10-3. Customer Notifications を有効化

「できました」通知（WhatsApp / メール）。**フードコートでは唯一の通知経路**
（ブラウザ内ポーリングは pay-after 専用で、pay-before only のフードコートでは動かない）。

```sql
insert into store_notification_settings
  (organization_id, store_id, whatsapp_enabled, whatsapp_template_name,
   whatsapp_template_language, email_order_ready_enabled)
select '<org-id>', '<store-id>', true, 'order_ready_pickup', 'en', true
where not exists (
  select 1 from store_notification_settings where store_id = '<store-id>'
);
```

⚠️ **`store_id` に UNIQUE 制約が無いので `on conflict` は使えない。**
`where not exists` で冪等にする（重複行を作ると設定の読み出しが壊れる）。

| 列 | 値 |
|---|---|
| `whatsapp_enabled` | `true`（既定は false） |
| `email_order_ready_enabled` | `true`（既定は false） |
| `whatsapp_template_name` | `order_ready_pickup`（既定値のまま） |
| `whatsapp_phone_number_id` / `whatsapp_access_token` | **店舗ごとには設定しない**。本番既存店も全て null |

**通知の仕様**（正典: `src/app/api/kds/orders/[id]/notify-first-batch/route.ts`）:

- **オンライン注文のみ**・連絡先が**1つ以上**必要
- 連絡先は**任意入力**なので、入力しなかった客には届かない（400で拒否される）
- 同一注文に**2回まで**（`MAX_SEND_COUNT=2`）。KDS/SDS でカウンタ共有
- **店舗側が KDS の Notify Customer を押す運用**が定着しないと飛ばない → 研修項目

---

## 11. 先方作業（代行できないもの）

| 作業 | なぜ代行できない |
|---|---|
| **Stripe Connect 接続** | 先方の法人・口座情報が必要。**リードタイムが最長** |
| **食事券/共通QR の consent 承認** | `consent` ルートは admin allowlist を見ない |
| **メニューの最終確認** | Web 掲載が古い可能性。価格は先方しか確定できない |

🔴 **フードコートに出す場合は pay-before only。**
`online_payment_enabled = true` かつ Stripe credentials が解決できないと
**一覧から消える**（メニュー閲覧のみモードは未実装）。

---

## 12. 引き渡し

| 作業 |
|---|
| 先方のメールで**別アカウント**を作成し Owner を移す |
| パスワードを長いものに変更 |
| `hello+<slug>@` は弊社管理用として残すか削除するか決める |

⚠️ **`hello+<slug>@` を先方に共有しない。**
弊社の受信箱に先方の業務メールが流れ続け、かつ**先方が弊社アカウントの
パスワードを握る**ことになる。

---

## 付録: 実作業で踏んだ落とし穴

| 症状 | 原因 / 対処 |
|---|---|
| `Top-level await is currently not supported` | `tsx` の cjs 出力。`async function main()` で包む |
| `Cannot find module '@supabase/supabase-js'` | スクリプトを scratchpad に置いた。**`ReactRestaurantPOS/` 配下で実行する** |
| `npx tsc` が大量のエラー | プロジェクト設定を使っていない。**`npm run type-check`** を使う（素の `tsc` は OOM にもなる） |
| JSON に項目を足したのに反映されない | 既存 SKU はスキップ（§8）。直接 UPDATE で追い付かせる |
| 説明文が `...bufala Gluten-free base...` | 文末の句点が無いまま連結した。生成時に `.` を補う |
