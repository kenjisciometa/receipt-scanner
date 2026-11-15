# メニュー売上貢献度 監査 — Tokyo Street Restaurants Oy

**発行日時**: 2026-11-05 (Europe/Helsinki)
**対象事業者**: Tokyo Street Restaurants Oy (`b9d33e3b-926c-4943-b240-64953199edea`)
**対象店舗**: Hietalahden Kauppahalli (`5ef97cd5-d186-4d5a-8cb7-378a6029ea5a`) / Vallila (`a4c94b60-2267-43e3-a07e-d6de2db5ed1a`)
**データ源**: Sciometa POS 本番データベース (Supabase project `mcldujatysqrzsdjxpof`)
**集計期間**: 2025-09-24 〜 2026-11-03（初回注文日から集計基準日まで、約14か月）
**90日窓**: 2026-08-05 〜 2026-11-03（**固定**。集計基準日 2026-11-03 時点のスナップショット）
**対象取引**: `orders.status = 'completed'` のみ **26,515件**（`refunded` 40件・`cancelled` 1件は除外）
**売上定義**: `order_items.line_total` の合計 **€585,132.02**
**数量定義**: `quantity - COALESCE(refunded_qty, 0)`

> 本監査は「どの商品が売上に貢献していないか」の特定を目的とする。
> 原価・粗利は対象外（§7 参照）。

---

## 1. 結論サマリ

| 指標 | 値 |
|---|---:|
| 商品レコード総数 | 191 |
| **通算販売実績ゼロのレコード** | **50** |
| うち `status = 'active'`（POSで有効） | **31** |
| Food の料理数（実績あり・統合後） | 22 |
| Food 上位3品の売上構成比 | **51.7%** |
| Food 下位11品の売上構成比 合計 | 13.0% |

**要対応は3点。**

1. **販売実績ゼロで有効な31レコード** — 売上リスクなしで無効化可能（§3）
2. **サラダ5品が下位8位内に5枠** — Food売上の 4.06% に5枠を使用（§5）
3. **未分類23レコード** — プリンタ振り分け・レポート帰属が機能しない状態（§3.4）

---

## 2. 時間帯別価格の実装構造（分析の前提）

**`products` に時間帯を示す列は存在しない。** Food の時間帯別価格は、
**同一料理を2つの商品レコードとして別カテゴリに登録する**方式で実装されている。

| カテゴリ（Lunch系） | カテゴリ（After 3PM系） |
|---|---|
| `Lunch Main` | `After 3PM&Sat&Sun Main` |
| `Lunch Salads` | `After 3PM&Sat&Sun Salads` |
| `Lunch Vege` | `After 3PM&Sat&Sun Vege` |
| `Lunch RAMEN` | （`After 3PM&Sat&Sun Main` に同居） |

実例:

| 料理 | Lunch 価格 | After 3PM 価格 |
|---|---:|---:|
| Ginger-Pork | €15.00 | €16.70 |
| Teriyaki Salmon Noodles | €14.50 | €16.00 |
| Chicken Dumpling Soup | €14.50 | €16.50 |

### 2.1 集計上の注意点

この構造により、**1つの弱い料理が「2つの弱いレコード」として現れる**。
本監査では以下の正規化を行い、**料理単位**で評価した。

- 商品名を小文字化 → 末尾の `-1` / ` 1` を除去 → ハイフン・アンダースコアを空白に統一
- 上記により `Shio Ramen` と `Shio-Ramen`（別レコード）が同一料理として統合される
- `Chicken Dumplings (1x/4x/6x/8x)` は**全サイズを1料理として統合**（§5.2 参照）

### 2.2 集計から除外した行

以下は「料理」ではないため Food ランキングから除外した。

| 除外対象 | 理由 |
|---|---|
| `extra, gluten-free shirataki noodles` | €1.50 のトッピング追加（オプション） |
| `extra-portion (salmon, dumplings, meatballs)` | €1.50 の追加分（オプション） |
| `mini-portion` | 分量調整行 |
| `Open Price` | オープン価格の業務用ツール |
| `Little Tokyo Kids Set` (Hietalahti / Vallila) | 店舗別キッズセット（料理単位比較に不適） |

> オプション類を売上高で順位付けすると最下位に来るが、評価すべきは付帯率である。
> カテゴリから出すか、別軸で評価すべき。

---

## 3. 販売実績ゼロのレコード（50件 / うち有効31件）

### 3.1 日本酒・ワイン グラス展開（最大の塊）

全て `status = 'active'` かつ通算販売 **0件**。

| 商品 | 価格帯 | カテゴリ |
|---|---:|---|
| Kizan (100% pure rice wine) — 8 / 12 / 16cl + 75cl瓶 | €8〜45 | 未分類 |
| Kido Ginjo (100% pure rice wine) — 8 / 12 / 16cl + 75cl瓶 | €8〜45 | 未分類 |
| Chardonnay — 12 / 24cl + 75cl瓶 | €9〜40 | 未分類 |
| Umani Ronchi 12cl | €9.00 | 未分類 |

### 3.2 ビールセット（8種中4種が実績ゼロ・残り4種は既に無効）

| 商品 | 価格 | 有効店舗数 |
|---|---:|---:|
| Chicken Bites Beer Set | €15.40 | 1 / 2 |
| Karaage Fries Beer Set | €15.40 | 1 / 2 |
| Vegan Bites Beer Set | €15.40 | 1 / 2 |
| Izakaya Platter Beer Set | €17.40 | 1 / 2 |

### 3.3 スピリッツ・寿司・ミートボール系（レガシーレコード）

| 商品 | 価格 | カテゴリ |
|---|---:|---|
| Jim Beam 40% | €9.70 | Specialty Drinks |
| Johnnie Walker Red Label 40% | €9.70 | Specialty Drinks |
| Screwdriver | €7.40 | Specialty Drinks |
| sushi-small / sushi-small-1 / sushi-large | €5〜25 | 未分類 |
| salmon-nigiri-5pcs | €7.00 | 未分類 |
| salmon-nigiri-6pcs + chef-selections-7pcs | €14.00 | 未分類 |
| chicken-meatballs-noodles | €15.00 | 未分類 |
| chicken-meatballs-with-organic-noodles | €13.00 | 未分類 |
| chicken-meatballs-with-rice | €13.00 | 未分類 |
| meatballs-with-rice | €11.00 | 未分類 |
| ramune | €3.50 | 未分類 |
| kirin-beer-campaign | €3.50 | 未分類 |
| event-special-2 | €10.00 | Others |

### 3.4 未分類レコードの構造的リスク

**実績ゼロの有効31件のうち23件が `category_id IS NULL`。**
本システムでは primary category が以下3系統を駆動するため、
これらは**仮に注文されても正しく印刷・集計されない**。

- キッチンプリンタの振り分け
- レポートの売上帰属
- カップラベルの出力

---

## 4. 販売実績はあるが低水準のもの（Food以外）

### 4.1 直近90日ゼロ（実質的に終了・無効化推奨）

| 商品 | 通算売上 | 最終販売日 |
|---|---:|---|
| ginger pork salad（旧・未分類） | €385.00 | 2026-06-30 |
| Umani Ronchi 16/24cl・75cl瓶 | €231.00 | 2025-09〜2026-03 |
| kirin-non-alc-campaign | €85.89 | 2026-05-30 |
| green-tea-330ml | €47.85 | 2026-05-29 |
| heineken-alcohol-free | €33.60 | 2026-05-30 |
| event-special | €6.00 | 2026-04-30 |

> `ginger pork salad`（未分類）は現役の `Ginger-Pork Salad`（Salads）とは**別レコードの重複**。

### 4.2 カクテル類（Specialty Drinks 有効16品）

| 商品 | 90日売上 | 30日数量 |
|---|---:|---:|
| Bulldog | €7.40 | 0 |
| Kahlúa Milk | €7.40 | 0 |
| Gin Rickey | €9.70 | 0 |
| Casis Soda | €14.80 | 1 |
| Cassis Orange | €14.80 | 1 |
| Salty Dog | €24.50 | 0 |
| Highball | €24.50 | 2 |
| Lemon Sour | €46.52 | 5 |
| Umeshu Soda | €98.32 | 1 |
| **Mojito** | €100.80 | **0** |

**Mojito は90日では€101あるが直近30日が0** で失速している。
残す候補は Yuzu Soda（90日 €176.10 / 30日2）と Kyoto Yuzu（€235.00 / 30日6）のみ。

### 4.3 その他

| 商品 | 90日売上 | 備考 |
|---|---:|---|
| Prosecco Extra Dry 瓶 | €96.00 | 30日 0本 |
| French Fries | €115.50 | 30日 5食。サイドとして弱い |

---

## 5. Food 全22品 売上ランキング（Lunch / After 3PM 統合）

**基準**: 直近90日（2026-08-05 〜 2026-11-03）売上の降順
**日€**: 90日売上 ÷ 90日

| # | 品目 | 分類 | 90日€ | 90日数量 | 日€ | 構成比 | 累計 | 30日€ | 30日数量 | 通算€ | 通算数量 | 投入 |
|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | Teriyaki Salmon Noodles | Main | 33,382.78 | 2,267 | 370.92 | 22.61% | 22.6% | 9,022.95 | 602 | 130,987.59 | 8,870 | — |
| 2 | Teriyaki Salmon Rice | Main | 26,946.45 | 1,847 | 299.41 | 18.25% | 40.9% | 6,967.35 | 466 | 88,979.16 | 6,067 | — |
| 3 | Karaage with rice | Main | 15,928.10 | 1,029 | 176.98 | 10.79% | 51.7% | 4,444.52 | 291 | 50,906.90 | 3,301 | — |
| 4 | Chicken Dumplings（全サイズ） | Main | 9,497.38 | 885 | 105.53 | 6.43% | 58.1% | 2,314.70 | 210 | 32,674.90 | 4,890 | — |
| 5 | Salmon Ramen | Main/RAMEN | 9,445.23 | 640 | 104.95 | 6.40% | 64.5% | 2,241.63 | 151 | 35,294.52 | 2,413 | — |
| 6 | Tofu Noodles | Vege | 8,756.10 | 632 | 97.29 | 5.93% | 70.4% | 2,308.00 | 166 | 29,781.63 | 2,184 | — |
| 7 | Ginger-Pork | Main | 5,843.48 | 381 | 64.93 | 3.96% | 74.4% | 2,141.94 | 141 | 34,187.08 | 2,250 | — |
| 8 | Grilled Salmon Rice | Main | 5,815.95 | 387 | 64.62 | 3.94% | 78.3% | 1,572.30 | 104 | 10,068.25 | 676 | 2026-05 |
| 9 | Chicken Dumpling Soup | Main | 4,360.50 | 282 | 48.45 | 2.95% | 81.3% | 1,317.75 | 86 | 15,259.34 | 984 | — |
| 10 | Sweet Soy Braised Pork Belly Bowl | Main | 4,292.25 | 271 | 47.69 | 2.91% | 84.2% | 1,134.00 | 72 | 7,315.50 | 465 | 2026-06 |
| 11 | Tofu with Rice | Vege | 4,133.80 | 301 | 45.93 | 2.80% | 87.0% | 1,260.00 | 92 | 15,835.71 | 1,176 | — |
| 12 | Noodle Salad | Main | 3,870.58 | 267 | 43.01 | 2.62% | 89.6% | 1,098.65 | 76 | 17,866.29 | 1,256 | — |
| 13 | Grilled Salmon Noodle | Main | 3,679.70 | 245 | 40.89 | 2.49% | 92.1% | 965.30 | 64 | 6,466.45 | 429 | 2026-05 |
| 14 | Rice Salad | Main | 2,803.66 | 195 | 31.15 | 1.90% | 94.0% | 967.55 | 67 | 12,713.67 | 894 | — |
| 15 | Salmon Salad | Salads | 2,160.30 | 138 | 24.00 | 1.46% | 95.5% | 444.00 | 28 | 4,243.80 | 272 | 2026-06 |
| 16 | Vegan Teriyaki Rice Bowl | Vege | 1,931.65 | 127 | 21.46 | 1.31% | 96.8% | 489.50 | 32 | 2,474.65 | 163 | 2026-06 |
| 17 | Chicken Salad | Salads | 1,326.50 | 86 | 14.74 | 0.90% | 97.7% | 263.00 | 17 | 2,527.50 | 163 | 2026-06 |
| 18 | Karaage Salad | Salads | 1,198.00 | 76 | 13.31 | 0.81% | 98.5% | 365.00 | 23 | 2,873.00 | 183 | 2026-06 |
| 19 | Miso Ramen | Main/RAMEN | 784.80 | 51 | 8.72 | 0.53% | 99.0% | 784.80 | 51 | 784.80 | 51 | **2026-10-16** |
| 20 | Ginger-Pork Salad | Salads | 697.50 | 45 | 7.75 | 0.47% | 99.5% | 220.00 | 14 | 1,267.00 | 82 | 2026-07 |
| 21 | Tofu Salad | Salads | 615.00 | 39 | 6.83 | 0.42% | 99.9% | 154.00 | 10 | 1,489.50 | 95 | 2026-06 |
| 22 | Shio Ramen | Main/RAMEN | 150.60 | 10 | 1.67 | 0.10% | 100.0% | 150.60 | 10 | 150.60 | 10 | **2026-10-17** |

「投入」欄の `—` は初回注文日（2025-09-24）から存在する商品。

### 5.1 売上の集中度

- **上位3品で 51.7%**（Teriyaki 2品 + Karaage）
- 上位6品で 70.4% / 上位11品で 87.0%
- **下位11品の合計は 13.0%**

### 5.2 Chicken Dumplings はサイズ統合が必須

サイズ別に分離すると `(1x)` は下位3位に現れるが、**これは誤読を招く**。

| 見方 | 90日売上 | 順位 |
|---|---:|---|
| `(1x)` 単独 | €89.95 | 下位3位（弱い商品に見える） |
| **全サイズ統合** | **€9,497.38** | **22品中4位（主力商品）** |

通算 4,890食・€32,674.90。`(1x)` は**1つの強い商品の内訳**であり、
単独の数量減（通算2,349個 → 90日49個）は `(4x)(6x)(8x)` への移行を示すにすぎない。

### 5.3 客単価はメニュー全体でほぼ一定

1位から22位まで **1食あたり €13.73〜€15.84** に収まる。

> **価格で稼いでいる品は存在せず、順位は純粋に注文数で決まる。**
> メニューの取捨選択は「どれだけ客を呼べるか」の判断に等しい。

例外は Chicken Dumplings の €10.73 のみ（€1.75 の1個売りと €15.20 の8個売りが混在するため）。

### 5.4 サラダ5品が下位8位内に5枠

| 品目 | 日€ | 投入 |
|---|---:|---|
| Salmon Salad (15位) | 24.00 | 2026-06-10 |
| Chicken Salad (17位) | 14.74 | 2026-06-10 |
| Karaage Salad (18位) | 13.31 | 2026-06-11 |
| Ginger-Pork Salad (20位) | 7.75 | 2026-07-16 |
| **Tofu Salad (21位)** | **6.83** | 2026-06-13 |

**5枠を使って Food売上の 4.06%。** 全て2026年6〜7月投入で4〜5か月経過しており、
立ち上がり途上とは言いにくい。下位2品（Tofu / Ginger-Pork）は Salmon Salad の**3分の1未満**。

---

## 6. Miso / Shio Ramen — 新商品の評価（2026-10 投入）

両品は **2026-10-16 / 10-17 投入**。通算値では存在しなかった13か月分だけ不利になるため、
**投入後の営業日あたり**で既存の Salmon Ramen と同一期間比較した。

**比較期間**: 2026-10-16 〜 2026-11-03 / **営業日 19日**（完了注文が存在する日数）

| ラーメン | 投入日 | 数量 | 日販個数 | 日販€ | 売上 |
|---|---|---:|---:|---:|---:|
| Salmon Ramen（既存） | — | 93 | 4.89 | 72.46 | €1,376.80 |
| **Miso Ramen** | 2026-10-16 | 51 | **2.68** | 41.31 | €784.80 |
| **Shio Ramen** | 2026-10-17 | 10 | **0.53** | 7.93 | €150.60 |

### 6.1 Miso Ramen は成功

**3週間で既存 Salmon Ramen の日販個数の 55% に到達。**
13か月の認知を持つ定番商品に対してこの数字であり、日販ベースでは既に多くのサラダ類を上回る。

店舗別では **Vallila が Hietalahti の約5倍**（43食 対 8食）。理由はデータからは読めない。

### 6.2 Shio Ramen は「新しいから弱い」のではない

週次推移（投入週は部分期間）:

| 週 | Salmon | Miso | Shio |
|---|---:|---:|---:|
| 10/12〜 | 32 | 13 | 2 |
| 10/19〜 | 40 | 22 | 5 |
| 10/26〜 | 32 | 13 | 1 |
| 11/02〜（2日） | 7 | 3 | 2 |

**3週間を通して 2 / 5 / 1 で上昇トレンドがなく、同週の Miso は 13 / 22 / 13。**

掲載条件は同一であることを確認済み（＝見えない・選べないという設定の問題ではない）。

| 確認項目 | Miso | Shio |
|---|---|---|
| `product_availabilities.status` | 両店 `active` | 両店 `active` |
| `active_in_tos` / `active_in_bos` | 有効 | 有効 |
| 実売のあった店舗 | 両店 | 両店 |

**1日違いの投入・同一掲載条件で Miso が Shio を 5:1 で上回る** → 需要の差。
ただし3週間は評価期間として短いため、**試用期間を区切って判断**すべき。

---

## 7. 本監査の制約

| 制約 | 内容 |
|---|---|
| **原価・粗利は未評価** | 全て `order_items.line_total` ベースの売上高。`products.cost` にデータは存在するため粗利ベースでの再集計は可能。低原価品（Tofu系）と高原価品（Salmon系）では順序が変わる可能性がある |
| **オプション付帯率は未評価** | §2.2 で除外した行は売上高では評価できない |
| **キッズセット2品は季節変動の可能性** | 90日 55食・56食 → 30日 9食・8食 と急落。学校休暇終了の影響と推測されるが未検証 |
| **Miso Ramen の店舗差は原因不明** | Vallila 43食 対 Hietalahti 8食。現場の運用差の可能性 |

---

## 8. 推奨アクション

| 優先 | 対応 | 根拠 | リスク |
|---|---|---|---|
| 1 | **実績ゼロの有効31レコードを `inactive` に** | 通算販売0件 | **なし**（定義上売上影響ゼロ） |
| 2 | **未分類23レコードにカテゴリ付与または削除** | プリンタ振り分け・レポート帰属が不能 | なし |
| 3 | **日本酒・ワイン グラス展開の方針決定** | 2銘柄8レコードが実績ゼロ | 「提供していない」のか「POSで見つけられない」のかを**現場に確認**。前者なら削除、後者なら再分類 |
| 4 | **カクテル下位6品の廃止**（Bulldog / Gin Rickey / Casis Soda / Cassis Orange / Salty Dog / Kahlúa Milk） | 90日で1〜3杯 | 低。Yuzu Soda / Kyoto Yuzu / Lemon Sour は残す |
| 5 | **サラダ枠の見直し** | 5枠で売上4.06%。下位2品は最上位の1/3未満 | 中。Tofu / Ginger-Pork が候補 |
| 6 | **Shio Ramen の試用期間を設定** | 日販0.53食・3週間で上昇なし | 期間を区切り、定着しなければ撤退 |
| 7 | **Miso Ramen の店舗差を現場確認** | Vallila が Hietalahti の5倍 | Hietalahti 側の訴求改善余地 |

### 8.1 重要な注意

**デッドウェイト整理は売上を増やさない。**
Teriyaki Salmon 2品だけで Food売上の 40.9%、全売上の約38%を占め、
§3〜§4 の対象全てを合計しても通算€2,000未満（Teriyaki Salmon Noodles の**約1.5日分**）。

得られる効果は売上増ではなく、以下である。

- 商品グリッドの短縮（レジ操作の高速化）
- 棚卸リストの簡素化
- 誤振り分けチケットの減少

---

## 付録: 再現用クエリ

> **注意**: 以下のクエリは `now()-interval '90 days'` による**ローリング窓**を使用する。
> 本文の数値は **2026-11-03 時点の固定スナップショット**であるため、
> 後日実行すると窓がずれて値が一致しない。本文の再現には
> `now()` を `'2026-11-04'::timestamptz` に置き換えること。

### A. 販売実績ゼロのレコード

```sql
SELECT p.name, p.price, p.status, c.name AS category
FROM products p
LEFT JOIN categories c ON c.id = p.category_id
WHERE p.organization_id = 'b9d33e3b-926c-4943-b240-64953199edea'
  AND NOT EXISTS (
    SELECT 1 FROM order_items oi
    JOIN orders o ON o.id = oi.order_id
    WHERE oi.product_id = p.id
      AND o.organization_id = 'b9d33e3b-926c-4943-b240-64953199edea'
  )
ORDER BY p.status, c.name NULLS LAST, p.name;
```

### B. Food ランキング（Lunch / After 3PM 統合・餃子サイズ統合）

```sql
WITH s AS (
  SELECT oi.product_id,
    SUM(oi.quantity - COALESCE(oi.refunded_qty,0)) qty,
    SUM(oi.line_total) rev,
    -- 本文を再現する場合は now() を '2026-11-04'::timestamptz に置換
    SUM(CASE WHEN o.created_at >= now()-interval '90 days'
             THEN oi.quantity - COALESCE(oi.refunded_qty,0) ELSE 0 END) qty90,
    SUM(CASE WHEN o.created_at >= now()-interval '90 days'
             THEN oi.line_total ELSE 0 END) rev90
  FROM order_items oi
  JOIN orders o ON o.id = oi.order_id
  WHERE o.organization_id = 'b9d33e3b-926c-4943-b240-64953199edea'
    AND o.status = 'completed'
  GROUP BY 1
),
food AS (
  SELECT p.id, p.name,
    CASE WHEN lower(p.name) ~ 'chicken dumplings \(' THEN 'chicken dumplings (all sizes)'
         ELSE trim(regexp_replace(regexp_replace(regexp_replace(
                lower(trim(p.name)),'[- ]1$',''),'[-_]+',' ','g'),'\s+',' ','g'))
    END AS dish_key
  FROM products p
  JOIN categories c ON c.id = p.category_id
  WHERE p.organization_id = 'b9d33e3b-926c-4943-b240-64953199edea'
    AND p.status = 'active'
    AND c.name ~* '^(Lunch|After 3PM&Sat&Sun)'
    AND lower(p.name) NOT LIKE 'extra%'
    AND lower(p.name) NOT LIKE 'mini-portion%'
    AND lower(p.name) NOT LIKE 'open price%'
    AND lower(p.name) NOT LIKE '%kids set%'
)
SELECT f.dish_key,
  ROUND(SUM(COALESCE(s.rev90,0)),2) rev_90d,
  SUM(COALESCE(s.qty90,0)) qty_90d,
  ROUND(SUM(COALESCE(s.rev,0)),2) rev_life
FROM food f
LEFT JOIN s ON s.product_id = f.id
GROUP BY f.dish_key
HAVING SUM(COALESCE(s.qty,0)) > 0
ORDER BY rev_90d DESC;
```

### C. 新商品の営業日あたり比較

```sql
-- 営業日数 = 完了注文が存在する日数
WITH tradedays AS (
  SELECT COUNT(DISTINCT o.created_at::date) d
  FROM orders o
  WHERE o.organization_id = 'b9d33e3b-926c-4943-b240-64953199edea'
    AND o.status = 'completed'
    AND o.created_at >= '2026-10-16'
)
SELECT p.name,
  SUM(oi.quantity - COALESCE(oi.refunded_qty,0)) qty,
  ROUND(SUM(oi.quantity - COALESCE(oi.refunded_qty,0)) / (SELECT d FROM tradedays), 2) units_per_day,
  ROUND(SUM(oi.line_total) / (SELECT d FROM tradedays), 2) eur_per_day
FROM products p
JOIN order_items oi ON oi.product_id = p.id
JOIN orders o ON o.id = oi.order_id
WHERE p.organization_id = 'b9d33e3b-926c-4943-b240-64953199edea'
  AND p.name ILIKE '%ramen%'
  AND o.status = 'completed'
  AND o.created_at >= '2026-10-16'
GROUP BY p.name
ORDER BY eur_per_day DESC;
```
