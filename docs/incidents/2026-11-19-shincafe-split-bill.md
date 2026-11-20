# Shincafe Split Bill インシデント

調査日: 2026-11-19 / 報告元: FlutterPOS (order_sys/pos/flutter_app)
**状態: 原因確定・再現手順確立・修正実装済**
**修正定義書: [split-bill-held-portion-protection-spec.md](../../order_sys/pos/docs/payment/split-bill-held-portion-protection-spec.md)**

## 確定した原因（結論）

**Save & Pay Later で2人目を `on_hold` 保存した後、カートの既存明細の数量を 2 → 1 に減らしたため。**

`resumeFromSplitOrders` は請求可能な残額(pool)を**カートの明細**から計算し、控除する支払い済み情報は**DBの注文**から取る。数量を減らすと:

```
pool = カート(qty 1 = 25.00) − 支払い済み1人目(qty 1 = 25.00) = 0
進捗バー = pool(0) − 2人目の保留金額(25.00) = -25.00
```

割り当てを解除すると2人目が0に再計算され `0 − 0 = 0.00` → `All items assigned`。**観察された反転と完全に一致。**

`buildUnpaidPool` の計算は正しい。欠陥は **25.00 の請求権が確定した後も、その原資となる商品を減らせてしまうこと**。

### 再現手順（確認済み・2通り）

1. 数量2の1行で Create Order → Split Bill で1人目のみ支払い → 2人目は Save & Pay Later
2. カートに戻り**既存明細の数量を 2→1 に減らす**
3. Checkout → Split Bill に復帰 → `Remaining to assign €-<単価>`

**Update Order の有無は無関係**（する/しないの両方で再現）。

---

## 対象の特定

| 項目 | 値 |
|---|---|
| Organization | Shin Finland Oy |
| Organization ID | `307dbd1e-75c4-4ea5-880a-591586fa8965` |
| Store | Bún Chả with Sáng |
| Store ID | `3cb45702-604d-4925-9a51-4919d51a3d51` |
| Table | 5 (table_id `6ae812dc-2f7a-487c-bace-9b76a9982c46`) |
| Table Session ID | `f7ec5865-70b3-445d-bd06-0ee4b4e979e4` |
| Session Code | `A004` |
| 操作ユーザー | bac.tranhoai@gmail.com (role: owner) |
| User ID | `87a232ec-cc0d-4ab8-847b-3a7d17cf7524` |
| Supabase Project | `mcldujatysqrzsdjxpof` |
| 決済端末 ID | `19398fd3-8b3a-4e57-9fe9-71aa5c5af590` (SumUp) |
| 商品 | Bún Chả / product_id `9295343f-aae5-4aeb-a3b4-1078bb28bc2d` |
| 単価 | 税込 25.00 / 税抜 22.03 (VAT 14%) |

## 注文一覧

| Order Number | Order ID | status | total | receipt_no | client_order_id |
|---|---|---|---|---|---|
| ORD-0043 (親) | `6ffcef99-9158-42a2-86ac-0ff7e2cda2cb` | cancelled | 0.00 | 156 | null |
| ORD-0047-1/2 | `2e75a352-62dc-4704-bbd3-dd3e554af9c0` | completed | 25.00 | 160 | `7042a4fc-b0a6-476b-a6c4-db138945ccce` |
| ORD-0047-2/2 | `0135d0f3-5a91-486b-837a-e09d6557fc4a` | cancelled | 25.00 | 161 | `2d500a51-4241-46f0-a011-bc6ca17374ef` |

注: `correlation_id` は全件 null。親の `receipt_number` 156 に対し子が 160/161 と飛んでいる（間の157-159は別注文）。

## 決済

| 項目 | 値 |
|---|---|
| order_payments ID | `7e9b20df-0536-48d4-9cff-c36e67641e69` |
| 対象 | ORD-0047-1/2 のみ |
| 金額 | 25.00 |
| provider | sumup |
| transaction_id | `8dadf50f-7b28-47c3-9335-15c2103729fc` |
| provider_session_id | null |

**ORD-0047-2/2 には order_payments 行が存在しない**（未払いのまま）。

## 時系列（Helsinki = UTC+2）

| 現地時刻 | UTC | 出来事 |
|---|---|---|
| **18:54:43** | 16:54:43 | セッション開始。親 ORD-0043 作成、Bún Chả ×2 = 50.00（1行、qty 2.000） |
| **19:54:11** | 17:54:11 | Split Bill: 基準番号を新規採番 (ORD-0047)。1人目 25.00 を SumUp 決済完了 → `ORD-0047-1/2` = completed |
| **19:54:27** | 17:54:27 | 2人目を Save & Pay Later で保存 → `ORD-0047-2/2` = on_hold、決済行なし |
| **19:54:27〜19:56:21 の間** | — | **復帰 → 進捗バーが `Remaining to assign €-25.00` → `Total Mismatch — off by €25.00` で進行不可**（スタッフ報告・DB記録なし） |
| **19:56:21** | 17:56:21 | 通常カート画面から Bún Chả ×1 (25.00) を親 ORD-0043 に追加（Update Order）。display_status `{seq:1,status:pending}` 付き＝KDS送信あり |
| **20:31:18.52** | 18:31:18.52 | テーブル閉鎖/全キャンセル。親と on_hold の 2/2 が**同一タイムスタンプ**で同時 cancelled |
| **20:31:18.78** | 18:31:18.78 | セッション completed。total_amount 25.00 / paid_amount 25.00 |

## order_items

| 所属 | item_id | qty | line_total | item status | display_status | 作成(現地) |
|---|---|---|---|---|---|---|
| ORD-0043 | `6b9b82da-820a-46b9-84c2-f64c8b51ef2a` | 2.000 | 50.00 | cancelled | `{seq:1,status:pending}` | 18:54:43 |
| ORD-0047-1/2 | `53696e2e-7a81-4c60-a519-8e68ea61fcc7` | 1.000 | 25.00 | active | **null** | 19:54:11 |
| ORD-0047-2/2 | `45d4d27e-de33-4eb8-83b4-78ad3e59e950` | 1.000 | 25.00 | cancelled | **null** | 19:54:27 |
| ORD-0043 | `9073cf19-dbb3-43bc-b1b2-8f3a8cf72010` | 1.000 | 25.00 | cancelled | `{seq:1,status:pending}` | **19:56:21** |

全行 product_options / set_group_id / comment は null。

## split_bill_info

ORD-0047-1/2:
```json
{"splitMethod":"equal","original_order_id":"6ffcef99-9158-42a2-86ac-0ff7e2cda2cb","participantNumber":1,"totalParticipants":2}
```
ORD-0047-2/2:
```json
{"splitMethod":"equal","original_order_id":"6ffcef99-9158-42a2-86ac-0ff7e2cda2cb","participantNumber":2,"totalParticipants":2}
```
親 ORD-0043: **`null`**

重要: `option_allocations` が**両子注文に存在しない**。`splitMethod` は **`equal`**。

## 金額の帰結

| 項目 | 金額 |
|---|---|
| 実提供（Bún Chả ×3） | **75.00** |
| セッション記録 total_amount | **25.00** |
| セッション記録 paid_amount | **25.00** |
| **未請求に終わった金額** | **50.00** |

セッションの `paid_amount` は実際の入金 25.00 を正しく記録している（`settledTotal` = 生存する `completed` 注文の合計から算出、[cancel/route.ts:296-315](../../ReactRestaurantPOS/src/app/api/table-sessions/[id]/cancel/route.ts#L296-L315)）。**記録の欠損ではなく「未請求」**。ただし提供した 50.00 分が請求されずに終わったため、実質的な取りこぼしである（2人目から実際に集金できたかは店舗確認が必要）。

## 症状（スタッフ報告・画面実見）

復帰直後、2人目に割り当てがある状態で:
- 進捗バー: `Remaining to assign €-25.00`（**マイナス**）
- Proceed ボタン: `Total Mismatch — off by €25.00` で無効

割り当てを解除すると:
- 進捗バー: `All items assigned €0.00`

**正常時と反転**している（正常: 復帰=All assigned / 解除=Remaining €25.00）。

## サーバー側で確認したいこと

1. **19:54:27 の `POST /api/orders`**（ORD-0047-2/2 作成、`client_order_id=2d500a51-4241-46f0-a011-bc6ca17374ef`）
   → リクエストボディの `items[].quantity` / `line_total` / `split_bill_info` / `holdOrder` フラグ、特に **option_allocations が送られていたか**
2. **19:54:11 の `POST /api/orders`**（ORD-0047-1/2、`client_order_id=7042a4fc-b0a6-476b-a6c4-db138945ccce`）
3. **19:54:27〜19:56:21 の `GET /api/table-sessions/f7ec5865-70b3-445d-bd06-0ee4b4e979e4/orders`**
   → 復帰時に返した注文と order_items の中身（ここで2人目に何円返したかが決定的）
4. **20:31:18 の `PUT /api/table-sessions/f7ec5865-.../cancel`**
   → 対象に含まれた order_ids（on_hold の 2/2 が含まれたことの確認）
5. recalculate_order_totals トリガーの発火履歴（親 total が 0.00 になった経緯）

## 未解明の点

進捗バーが表示する「割当済み金額」は [split_bill_items_step.dart:209](order_sys/pos/flutter_app/lib/presentation/widgets/split_bill/split_bill_items_step.dart#L209) で `assignedTotal = paymentsSum` と定義されており、**実際の割り当て量ではなく参加者金額の合計**を読んでいる。復帰時は held 参加者の金額が保存済み注文から pin 復元される（[split_bill_notifier.dart:292-301](order_sys/pos/flutter_app/lib/presentation/providers/split_bill/split_bill_notifier.dart#L292-L301)）。

DB上 2/2 の line_total は 25.00 だが、pin 復元後に 50.00 として扱われれば −25.00 が再現する（ユニットテストで確認済み）。**その変換経路が未特定** — サーバーが復帰時に返す JSON の確認が必要。

再現試行: 以下はいずれも**再現せず**
- assign モード / 商品追加あり
- equal モード / 商品追加なし
- 親を qty 2.000 の単一行にする

## 確定している欠陥（再現と独立）

1. ~~**`/cancel` が `on_hold` を巻き込むのはバグ**~~ → **誤り。意図された動作。**
   [split-bill-close-session-preserve-paid-spec.md](../../order_sys/pos/docs/payment/split-bill-close-session-preserve-paid-spec.md) 受入基準2が `on_hold` のキャンセルを明示的に要求している（「`on_hold` が唯一残る注文の場合: キャンセルされる」）。`complete-split-bill` との非対称も意図的で、*complete*（会計完了）は未払いを取り落としてはいけないが、*cancel*（テーブルを閉じて未払いを破棄）は破棄が命令そのもの。
   ただし**無言で消える**点は改善対象とし、Close Session の確認ダイアログに警告を追加した。
2. **進捗バーが割り当てではなく金額合計を読む** — `assignedTotal = paymentsSum`（[split_bill_items_step.dart:209](../../order_sys/pos/flutter_app/lib/presentation/widgets/split_bill/split_bill_items_step.dart#L209)）。今回の症状の**直接原因ではない**（pool=0 なら割当ベースでも残額0）が、乖離を見えにくくした。別タスクとして残す。
3. **pool 不足が「Total Mismatch」として表示される** — 原因が分からず詰む。不足を明示するメッセージを追加した。
