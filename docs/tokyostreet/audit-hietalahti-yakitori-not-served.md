# 監査ログ: Yakitori 非提供の証明 — Hietalahden Kauppahalli 店

**発行日時**: 2026-09-25 14:26 (Europe/Helsinki)
**対象事業者**: Tokyo Street Restaurants Oy (`b9d33e3b-926c-4943-b240-64953199edea`)
**対象店舗**: Hietalahden Kauppahalli — Lönnrotinkatu 34, 00180 Helsinki
**店舗ID**: `5ef97cd5-d186-4d5a-8cb7-378a6029ea5a`
**証明対象**: 当該店舗において商品「Yakitori」が提供されていないこと
**データ源**: Sciometa POS 本番データベース (Supabase project `mcldujatysqrzsdjxpof`)
**検証範囲**: 商品登録日 2026-07-18 〜 2026-09-25（全期間・全取引）

> 本監査は Hietalahden Kauppahalli 店のみを対象とする。同一事業者の Vallila 店では
> Yakitori が提供されているが、本件の対象外であり、比較対照としてのみ参照する。

---

## 1. 結論

**Hietalahden Kauppahalli 店では、Yakitori は提供されていない。**

これは以下の二系統の独立した証拠により裏付けられる。

| 系統 | 証拠 | 結果 |
|------|------|------|
| **A. 設定系（提供できない）** | 店舗別商品有効化テーブル | 全チャネルで無効 (`inactive` / all false) |
| **B. 取引系（提供された事実がない）** | 全注文明細 70営業日・3,877件 | Yakitori の販売実績 **0件** |

設定上「提供不可」であり、かつ取引実績上も「1件も提供されていない」。
両者は独立したテーブルに記録されており、相互に矛盾なく一致する。

---

## 2. 対象商品の特定

事業者の商品マスタに登録されている Yakitori 商品は以下の2件のみである（全言語表記を含む網羅検索により確認）。

| 商品名 | 商品ID | 価格 | カテゴリ | 登録日 |
|--------|--------|------|----------|--------|
| Yakitori (3x) | `d235415c-23ef-425d-ba58-cea2fab61781` | €4.50 | Snacks / おつまみ | 2026-07-18 15:42:38 UTC |
| Yakitori (5x) | `cba10ef7-1895-414d-bb28-fc43f516d180` | €7.50 | Snacks / おつまみ | 2026-07-18 15:56:37 UTC |

多言語登録名（両商品とも4言語で登録）:

- Yakitori (3x) — EN: `Yakitori (3 pcs)` / FI: `Yakitori (3 kpl)` / SV: `Yakitori (3 st)` / JA: `焼き鳥（3本）`
- Yakitori (5x) — EN: `Yakitori (5 pcs)` / FI: `Yakitori (5 kpl)` / SV: `Yakitori (5 st)` / JA: `焼き鳥（5本）`

**検索の網羅性**: 商品名・多言語翻訳フィールド・商品説明文を対象に
`yakitori` / `焼き鳥` / `焼鳥` / `焼` で横断検索し、上記2件以外に該当商品が
存在しないことを確認済み。

---

## 3. 証拠 A — 設定系: 店舗別に無効化されている

本 POS では、商品は組織（事業者）単位で登録され、**店舗ごとに個別の有効化レコード**
(`product_availabilities`) によって提供可否が制御される。同一商品でも店舗ごとに
提供/非提供を独立して設定する構造である。

Yakitori 2商品の店舗別有効化レコードの**全件**（4行、これが全てである）:

| 店舗 | 商品 | status | POS<br>(店頭レジ) | BOS<br>(注文端末) | TOS<br>(テーブル注文) | SPS<br>(セルフ注文) |
|------|------|--------|:---:|:---:|:---:|:---:|
| **Hietalahden Kauppahalli** | Yakitori (3x) | **inactive** | — | **false** | **false** | **false** |
| **Hietalahden Kauppahalli** | Yakitori (5x) | **inactive** | — | **false** | **false** | **false** |
| _(参考)_ Vallila | Yakitori (3x) | active | — | true | true | false |
| _(参考)_ Vallila | Yakitori (5x) | active | — | true | true | false |

**判定**: Hietalahti 店では両商品とも `status = inactive` であり、かつ全ての販売
チャネル（BOS・TOS・SPS）のフラグが `false` である。この設定下では、
当該商品は店舗の販売画面・顧客向けメニューのいずれにも表示されず、
**そもそも注文・販売の操作が不可能**である。

### 3-1. 設定は登録時から一度も変更されていない

| 店舗 | 商品 | created_at | updated_at | 変更履歴 |
|------|------|-----------|-----------|---------|
| Hietalahti | Yakitori (3x) | 2026-07-18 15:42:38.499819 UTC | 2026-07-18 15:42:38.499819 UTC | **変更なし** |
| Hietalahti | Yakitori (5x) | 2026-07-18 15:56:37.816544 UTC | 2026-07-18 15:56:37.816544 UTC | **変更なし** |

`updated_at` が `created_at` とマイクロ秒単位で完全に一致する。これは当該レコードが
**作成された瞬間から現在まで一度も更新されていない**ことを意味する。

したがって「過去に一時的に有効化されていた期間があり、後から無効に戻された」という
可能性は、データ上排除される。Hietalahti 店では、商品登録初日（2026-07-18）から
本監査日（2026-09-25）まで**一貫して無効**であった。

---

## 4. 証拠 B — 取引系: 販売実績が1件も存在しない

### 4-1. Yakitori の販売実績（全期間・全店舗）

| 店舗 | 明細行数 | 販売数量 | 初回販売 | 最終販売 |
|------|---------:|---------:|----------|----------|
| **Hietalahden Kauppahalli** | **0** | **0** | — | — |
| _(参考)_ Vallila | 100 | 104 | 2026-07-18 17:28 UTC | 2026-09-25 10:35 UTC |

Hietalahti 店の注文明細には、Yakitori 2商品の**いずれも1行も存在しない**。
同期間に Vallila 店では 104点の販売実績が記録されており、
記録システム自体は正常に稼働している（記録漏れではない）ことが示される。

### 4-2. 商品ID以外の経路からの網羅検証

商品IDによる紐付けを経由しない提供経路についても、以下の全てを検証し、
Hietalahti 店での該当を **0件** と確認した。

| 検証経路 | 内容 | 結果 |
|---------|------|------|
| 自由入力コメント | 注文明細の `comment` に "yakitori" を含むもの | **0件** |
| オプション記述 | `product_options` に "yakitori" / "焼き鳥" を含むもの | **0件** |
| セット商品名 | `set_product_name` に "yakitori" を含むもの | **0件** |
| 商品名の横断照合 | 全注文明細を商品マスタと結合し、商品名・翻訳に `yakitori` / `焼` を含むもの | **0件** |
| セット構成品 | Yakitori を構成品として含むセット商品の登録 | **存在しない** |
| オプション選択肢 | 選択肢名に "yakitori" / "焼き鳥" を含むもの | **存在しない** |

**判定**: 通常の商品販売のみならず、セット商品の構成品、オプション選択肢、
手入力コメントを含む**あらゆる経路**において、Hietalahti 店での Yakitori の
提供記録は存在しない。

---

## 5. 対照検証 — 「記録が無い」ことが不提供を意味する根拠

「販売記録が0件」という事実が「提供していない」ことの証明として成立するためには、
当該店舗がそもそも営業し、販売記録が正常に蓄積されていたことを示す必要がある。

### 5-1. Hietalahti 店は同期間に正常営業していた

商品登録日（2026-07-18）以降の Hietalahti 店の営業実績:

| 指標 | Hietalahden Kauppahalli |
|------|------------------------:|
| 総注文件数 | **3,877 件** |
| 営業日数 | **70 日** |
| 販売された商品種類数 | **63 種類** |
| 最初の注文 | 2026-07-18 08:03:58 UTC |
| 最後の注文 | 2026-09-25 11:02:04 UTC |
| 店舗有効化商品数 | 90 商品 |
| 店舗ステータス | 稼働中 (`is_active = true`) |

Hietalahti 店は対象期間中、70日間にわたり 3,877件の注文を処理し、63種類の商品を
販売している。**販売記録システムは正常に稼働していた**。
その中に Yakitori が1件も含まれないことは、記録の欠落ではなく、
**提供の事実が存在しないこと**を示す。

### 5-2. カテゴリ全体の停止ではなく、Yakitori 個別の非提供である

Yakitori が属する「Snacks / おつまみ」カテゴリは、Hietalahti 店で**有効**である。

| 項目 | Hietalahti 店の設定・実績 |
|------|--------------------------|
| Snacks カテゴリ 店頭レジ (POS) | **有効** (`active_in_pos = true`) |
| Snacks カテゴリ テーブル注文 (TOS) | **有効** (`active_in_tos = true`) |
| 同カテゴリの実販売 | **Edamame を3件販売** |

同一カテゴリの他商品（Edamame）は実際に販売されている。
したがって Yakitori の非提供は、カテゴリ単位の一括停止や設定不備の副作用ではなく、
**Yakitori という商品に固有の、意図的な店舗別設定**である。

---

## 6. 証拠の相互独立性

本監査の結論は、相互に独立した4つのデータ源が一致することによって支持される。

| # | データ源 | 記録の性質 | 示す事実 |
|---|---------|-----------|---------|
| 1 | `product_availabilities` | 店舗別の提供可否設定 | 全チャネルで提供不可 |
| 2 | 同テーブルの `updated_at` | 変更履歴のタイムスタンプ | 登録以来一度も有効化されていない |
| 3 | `orders` / `order_items` | 実取引の記録 | 70営業日・3,877注文中 販売0件 |
| 4 | 同カテゴリ他商品の販売実績 | 対照群 | カテゴリは稼働、Yakitori のみ不在 |

「設定上提供できない」(1・2) と「実際に提供されていない」(3) が独立に成立し、
かつ「記録システムは正常だった」(3・4) ことが確認される。
これらは単一の設定ミスや記録漏れでは同時に説明できない。

---

## 7. 検証に使用したクエリ

再現性確保のため、本監査で実行した主要な検証クエリを記載する。
対象DB: Supabase project `mcldujatysqrzsdjxpof` (Sciometa POS 本番)

```sql
-- [1] 対象商品の特定（多言語・説明文を含む網羅検索）
SELECT id, name, status, price, created_at, updated_at, translations
FROM products
WHERE organization_id = 'b9d33e3b-926c-4943-b240-64953199edea'
  AND (name ILIKE '%yakitori%' OR name ILIKE '%焼き鳥%' OR name ILIKE '%焼鳥%'
       OR translations::text ILIKE '%yakitori%' OR description ILIKE '%yakitori%');

-- [2] 証拠A: 店舗別提供可否設定（全レコード）
SELECT s.name AS store_name, p.name AS product_name,
       pa.status, pa.active_in_bos, pa.active_in_tos, pa.active_in_sps,
       pa.created_at, pa.updated_at
FROM product_availabilities pa
JOIN products p ON p.id = pa.product_id
JOIN stores   s ON s.id = pa.store_id
WHERE pa.product_id IN ('d235415c-23ef-425d-ba58-cea2fab61781',
                        'cba10ef7-1895-414d-bb28-fc43f516d180')
ORDER BY s.name, p.name;

-- [3] 証拠B: 販売実績の集計
SELECT s.name AS store_name, COUNT(*) AS line_count,
       COALESCE(SUM(oi.quantity),0) AS total_qty,
       MIN(o.created_at) AS first_sale, MAX(o.created_at) AS last_sale
FROM order_items oi
JOIN orders o ON o.id = oi.order_id
JOIN stores s ON s.id = o.store_id
WHERE oi.product_id IN ('d235415c-23ef-425d-ba58-cea2fab61781',
                        'cba10ef7-1895-414d-bb28-fc43f516d180')
GROUP BY s.name;
-- → Hietalahti は結果に現れない（0件）

-- [4] 商品ID を経由しない経路の網羅検証（Hietalahti 店）
SELECT COUNT(*) AS hits
FROM order_items oi
JOIN orders o ON o.id = oi.order_id
WHERE o.store_id = '5ef97cd5-d186-4d5a-8cb7-378a6029ea5a'
  AND (oi.product_options   ILIKE '%yakitori%'
    OR oi.comment           ILIKE '%yakitori%'
    OR oi.set_product_name  ILIKE '%yakitori%'
    OR oi.product_options   ILIKE '%焼き鳥%');
-- → 0

-- [5] 商品名による全注文明細の横断照合（Hietalahti 店・全期間）
SELECT COUNT(*) AS any_yakitori_lines_ever
FROM order_items oi
JOIN orders   o ON o.id = oi.order_id
JOIN products p ON p.id = oi.product_id
WHERE o.store_id = '5ef97cd5-d186-4d5a-8cb7-378a6029ea5a'
  AND (p.name ILIKE '%yakitori%' OR p.translations::text ILIKE '%yakitori%'
       OR p.name ILIKE '%焼%');
-- → 0

-- [6] 対照検証: Hietalahti 店の営業実績
SELECT COUNT(DISTINCT o.id) AS orders,
       COUNT(DISTINCT DATE(o.created_at)) AS trading_days,
       COUNT(DISTINCT oi.product_id) AS distinct_products_sold,
       MIN(o.created_at) AS first_order, MAX(o.created_at) AS last_order
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.store_id = '5ef97cd5-d186-4d5a-8cb7-378a6029ea5a'
  AND o.created_at >= '2026-07-18';
-- → 3,877 orders / 70 days / 63 products

-- [7] 対照検証: Snacks カテゴリは Hietalahti で稼働している
SELECT p.name, COUNT(*) AS lines, SUM(oi.quantity) AS qty
FROM order_items oi
JOIN orders   o ON o.id = oi.order_id
JOIN products p ON p.id = oi.product_id
WHERE o.store_id   = '5ef97cd5-d186-4d5a-8cb7-378a6029ea5a'
  AND p.category_id = '93893e7b-0f4b-408a-9880-32b5dfe11bf8'
GROUP BY p.name;
-- → Edamame 3件（カテゴリは稼働、Yakitori のみ不在）
```

---

## 8. 監査対象データの同一性確認

| 項目 | 値 |
|------|-----|
| データベース | Supabase project `mcldujatysqrzsdjxpof` (Sciometa POS 本番環境) |
| 組織ID | `b9d33e3b-926c-4943-b240-64953199edea` (Tokyo Street Restaurants Oy) |
| 店舗ID | `5ef97cd5-d186-4d5a-8cb7-378a6029ea5a` (Hietalahden Kauppahalli) |
| 店舗短縮コード | `fae3eff` |
| 店舗タイムゾーン | Europe/Helsinki |
| 商品ID | `d235415c-23ef-425d-ba58-cea2fab61781` (Yakitori 3x) |
| 商品ID | `cba10ef7-1895-414d-bb28-fc43f516d180` (Yakitori 5x) |
| 検証実施日時 | 2026-09-25 14:26 (Europe/Helsinki) |

本監査ログに記載された全ての数値は、上記データベースに対する読み取り専用クエリの
実行結果であり、第三者が同一クエリを実行することで再現・検証が可能である。

---

## 付記: タイムスタンプの取り扱いについて

本文中の日時は、特記なき場合 UTC で記載している。Hietalahden Kauppahalli 店の
店舗タイムゾーンは Europe/Helsinki（UTC+3、夏時間期間）である。
営業日数の算定（70日）は UTC 基準の日付でグルーピングしているため、
現地時間基準では境界日において ±1 日の差が生じうるが、
本監査の結論（販売実績 0件）は日付の区切り方に依存しない。
