# アレルゲン情報 登録記録 — Tokyo Street Restaurants Oy

**実施日時**: 2026-09-25 (Europe/Helsinki)
**対象**: Tokyo Street Restaurants Oy (`b9d33e3b-926c-4943-b240-64953199edea`)
**対象店舗**: Hietalahden Kauppahalli / Vallila（両店共通の商品マスタ）
**対象DB**: Supabase project `mcldujatysqrzsdjxpof` (`products.allergens`)
**根拠**: `menu-allergens.en.md` / `menu-allergens.md`（レストラン側でレシピ・原材料確認済み）
**準拠**: EU Regulation 1169/2011（14品目表示義務）

---

## 1. 実施サマリ

| 指標 | 実施前 | 実施後 |
|---|---:|---:|
| 有効商品数 | 129 | 129 |
| **アレルゲン登録あり** | **35 (27%)** | **92 (71%)** |
| 明示的「該当なし」(空配列) | — | 33 |
| 未設定 (null) | 94 | 4 |

- **新規登録: 57商品**
- **既存データの毀損: 0件**（登録済み35商品のアレルゲンは1件も削除・欠落していないことを検証済み）

### 登録後のアレルゲン別商品数

| アレルゲン | 商品数 |
|---|---:|
| Soybean | 68 |
| Gluten | 46 |
| Sesame | 43 |
| Egg | 22 |
| Fish | 17 |
| Celery | 12 |
| Sulphur Dioxide | 11 |
| Crustaceans | 1 |
| Milk | 1 |

> 実施前は Sulphur Dioxide・Milk・Crustaceans がいずれも **0件**であった（EU表示義務項目の全欠落）。

---

## 2. 使用した語彙

アプリケーション定義 `ReactRestaurantPOS/src/constants/allergens.ts` の
`AVAILABLE_ALLERGENS`（EU14品目）に準拠。既存データと同一語彙のため整合性が保たれている。

```
Molluscs / Lupin / Egg / Peanut / Treenuts / Sesame / Milk / Gluten /
Mustard / Fish / Crustaceans / Sulphur Dioxide / Celery / Soybean
```

---

## 3. 登録内容の詳細と根拠

### 3-1. 🔴 最重要 — 是正した重大な欠落

| 商品 | 登録前 | 登録後 | 根拠 |
|---|---|---|---|
| **Vegan Teriyaki Rice Bowl** ×2 | `Soybean` のみ | `Soybean, Gluten, Sesame` | **セイタン＝小麦グルテン**。ヴィーガン客がグルテン回避客と混同されるリスクが最も高い |
| **4 Vegan Bar Bites** | `Soybean` のみ | `Soybean, Gluten` | クリスピーセイタン（小麦）を含む |
| **Chicken Dumplings 全8件** | 未登録 | `Gluten, Soybean, Sesame, Egg` | 餃子の皮＝小麦。主力商品 |
| **Salmon Ramen** ×2 | 未登録 | `Fish, Gluten, Soybean, Egg` | 小麦麺・魚・味玉 |
| **寿司・にぎり 5件** | 未登録 | `Fish, Soybean`（おまかせは `+Crustaceans`） | 生魚・醤油。板長おまかせは海老を含む可能性 |

### 3-2. 酒類 — EU表示義務項目

| 商品群 | 登録内容 | 根拠 |
|---|---|---|
| ビール 4件（Asahi / Kirin 33cl / Sapporo / Kirin生） | `Gluten` | 大麦麦芽 |
| ノンアルコールビール 3件 + キャンペーン2件 | `Gluten` | 大麦由来（ノンアルも同様） |
| ワイン全11件（Chardonnay / Umani Ronchi / Riesling / Kaiken / D'Arenberg / Prosecco 各サイズ） | `Sulphur Dioxide` | **EU表示義務**。実施前は登録ゼロ |
| Highball / Jim Beam / Johnnie Walker | `Gluten` | ウイスキー＝大麦由来 |
| **Kahlúa Milk** | `Milk` | コーヒーリキュール＋牛乳。実施前 Milk 登録はゼロ |

### 3-3. 料理・スナック

| 商品 | 登録内容 | 備考 |
|---|---|---|
| Karaage with rice ×2 | `Soybean` | **片栗粉衣・専用油のため Gluten は付与せず**（店舗確認済みのGF対応） |
| Ginger-Pork ×2 | `Soybean, Gluten, Sesame` | |
| Ginger-Pork Salad ×2 | `Sesame, Celery, Soybean` | |
| Noodle Salad ×2 | `Egg, Sesame, Gluten, Soybean` | 小麦麺 |
| Edamame | `Soybean` | |
| Yakitori (3x) / (5x) | `Soybean, Gluten` | 照焼きタレ |
| 2 Izakaya Chicken Bites / 3 Loaded Izakaya Platter | `Soybean, Gluten` | 衣に小麦 |
| ビールセット 4件 | `Soybean, Gluten` | 構成品＋ビールの大麦 |
| ミートボール系 4件 | `Gluten, Egg, Soybean` | つなぎのパン粉・卵 |

### 3-4. 明示的「アレルゲンなし」として登録（空配列）

未設定(null)と「該当なし」を区別するため、以下は**空配列**を明示的に登録した。
これにより「確認の結果、該当なし」であることが記録上判別できる。

| 商品群 | 根拠 |
|---|---|
| French Fries | GF・専用油管理 |
| GF しらたき麺 | GF商品 |
| 日本酒 8件（Kido Ginjo / Kizan 各サイズ） | 米由来・グルテンフリー。**亜硫酸は要確認のため付与せず**（下記 4 参照） |
| ソフトドリンク 6件（コーラ×2 / 緑茶 / Vichy / ジュース / ラムネ） | 該当なし |
| カクテル 12件（ウイスキー系・乳製品系を除く） | 該当なし |

---

## 4. 未設定として残した商品（4件）と理由

以下は**内容が可変または未定義**のため、一律のアレルゲン登録は不適切と判断し未設定のまま残した。

| 商品 | 価格 | 理由 |
|---|---:|---|
| `event-special-1` | €6.00 | イベント都度で内容が変わる |
| `event-special-2` | €10.00 | 同上 |
| `extra-portion-(salmon,-dumplings,-meatballs)` | €1.50 | 追加対象により異なる（サーモン/餃子/ミートボール） |
| `mini-portion` | €8.70 | 本体料理に従属 |

> これらは**運用上、本体商品のアレルゲンに従う**ため、口頭・POS上の本体商品表示で対応する必要がある。

### 追加で確認が必要な事項

| 項目 | 内容 |
|---|---|
| **日本酒の亜硫酸** | 日本酒は米由来でグルテンフリーだが、亜硫酸塩の有無は製造者表示の確認が必要。現在は未付与 |
| **Little Tokyo Kids Set** | トッピング選択（サーモン/唐揚げ/豚バラ/豆腐/ヴィーガン照焼き）により変動。オプション側での表示が適切 |
| **仕入品の原材料表示** | 餃子・ミートボール等の仕入品は、製造業者の原材料表示との定期的な突合が望ましい |

---

## 5. 安全措置

### バックアップ

変更前の全129商品の状態を以下に保全済み。

```sql
-- テーブル: backup_ts_allergens_20260925
-- 内容: id, name, allergens, snapshot_updated_at, backed_up_at
-- 行数: 129
```

**復元方法**:
```sql
UPDATE products p
SET allergens = b.allergens
FROM backup_ts_allergens_20260925 b
WHERE p.id = b.id;
```

### 毀損チェック（実施済み・結果0件）

既存の登録済みアレルゲンが1件も失われていないことを、以下のクエリで検証した。

```sql
SELECT b.name, b.allergens AS before, p.allergens AS after
FROM backup_ts_allergens_20260925 b
JOIN products p ON p.id = b.id
WHERE array_length(b.allergens,1) > 0
  AND (p.allergens IS NULL OR NOT (b.allergens <@ p.allergens));
-- → 0件（既存データの毀損なし）
```

---

## 6. 検査官対応上の位置づけ

本作業は、指摘を受けての**是正措置の記録**として機能する。

- 変更日時・変更内容・根拠がすべて記録されている
- 変更前の状態がバックアップテーブルに保全されている
- 各商品の `updated_at` に変更時刻が記録されている
- 是正に用いた根拠資料（`menu-allergens.en.md`）が併存する

> ⚠️ **注記**: 本登録の内容は、レストラン側で確認されたレシピ・原材料情報に基づく。
> 仕入品については、製造業者の原材料表示との最終的な突合を推奨する。
> 表示内容の法的責任は事業者に帰属する。

---

## 7. 未対応の推奨事項（本作業の範囲外）

`menu-allergens.en.md` の「Data Quality Findings」より、本作業では扱わなかった項目。

| # | 項目 | 影響 |
|---|---|---|
| 1 | **グルテンフリー対応がDB未登録** | `products.tags` が全商品で空。3層のGF体制（片栗粉衣・専用油・GF醤油/タレ）が顧客に不可視。機会損失 |
| 2 | **GFソース選択のオプション未登録** | 現在は口頭対応のみ。KDS に伝達されず伝達ミスのリスク |
| 3 | **`is_alcoholic` フラグ誤り** | 生ビール・カクテル16件・ワイン・日本酒が `false`。年齢確認/酒類報告に影響 |
| 4 | **寿司の価格逆転** | `sushi-small` €25.00 > `sushi-large` €10.00 |
| 5 | **22商品がカテゴリ未設定** | POS カテゴリ画面に表示されず検索でのみ到達可能 |
| 6 | **3商品が全店舗で未割当** | green-tea-330ml / heineken-alcohol-free / chicken-meatballs-noodles |

> 特に **#1・#2 は法令リスクではなく機会損失**だが、GF対応を実施していながら
> システム上に記録がない状態は、検査時に「対応の実在」を示しにくい点で不利になりうる。
