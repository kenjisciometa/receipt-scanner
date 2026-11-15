# Klandestina — プロトタイプ Web サイト制作プラン

調査日 2026-10-29 / 対象 `HP/restaurant-sites/sites/klandestina`（新規）

Klandestina は Helsinki Konepaja のメキシカン・カンティーナ。すでに Sciometa POS を
使用しており、**公開 API からメニューと営業時間が実データで取れることを実機確認済み**。
`sites/taro-group` を雛形に 6 番目のサイトとして追加する。

---

## 1. POS 実装の確認結果（実測）

### 組織・店舗

| 項目 | 値 |
|---|---|
| Organization | **Klande Oy** `badb316b-a6ec-4bbd-aec5-b27bfff43cf3` |
| Store | **Klandestina** `0fd8bf5b-7c49-42ca-b243-46bd7ed86fe6` |
| Business ID | `3398758-5`（FI / EUR） |
| 住所 | Aleksis Kiven katu 17（Konepaja, Helsinki） |
| Timezone | `Europe/Helsinki` |
| Email | `andres@klande.fi` |
| 電話 | **`null`**（未登録） |
| `menu_slug` | `klandestina-konepaja` |
| POS 登録 | 2026-06-19 |

ブランド資産が POS 側に揃っている（サイトに流用可）:

- **組織ロゴ** — `https://pos.sciometa.com/img/logo_images/badb316b-.../org-logo-1783427798864-5dxdud.jpg`
- **ストアフロント背景画像** — `storefront_background_image` バケットに 1 枚
- **Google Maps embed URL** — `stores.map_embed_url` に設定済み（そのまま使える）
- **SNS** — Instagram `klandestinacantina` / Facebook `klandecantina`
- `supported_languages: ["fi", "en"]` → **サイトも fi/en の 2 言語**

> `latitude` / `longitude` は共に `"0"`。JSON-LD の `geo` に使うなら実座標を入れ直す必要がある
> （`map_embed_url` には 60.1929, 24.9433 が埋まっているのでそこから取れる）。

### 公開 API — 両方 200 で実データが返ることを確認

```
GET https://pos.sciometa.com/api/public-menu/0fd8bf5b-7c49-42ca-b243-46bd7ed86fe6?all=true
→ HTTP 200 / 31.5 KB / 10 categories / 52 products
GET https://pos.sciometa.com/api/public-reservation/0fd8bf5b-7c49-42ca-b243-46bd7ed86fe6
→ HTTP 200
```

カテゴリ構成（API が実際に返した順＝`sort_order` は全件 0 なので POS 側の順序）:

| カテゴリ | 商品数 | 写真あり |
|---|---|---|
| Starters | 5 | 1 |
| Tacos | 9 | 4 |
| Dessert | 1 | 0 |
| Soft Drinks | 3 | 0 |
| Beer | 6 | 0 |
| Cocktails | 5 | 0 |
| Red Wine | 8 | 0 |
| White Wine | 8 | 0 |
| Sparkling & Rose | 6 | 0 |
| Killers Chilaquiles | 1 | 1 |

- `active_in_web` は**カテゴリ・商品とも全件 true** → 追加の POS 設定なしでサイトに出る。
- フィンランド語は `description_translations` に入っている（`translations`=商品名は null、
  名前は英語のみ）。**fi ロケールでも料理名は英語表示**になる点は想定どおりでよいか要確認。
- 価格は €3.50〜€56.00。`products.price` は FI 慣例どおり税込。

### 予約（Reservation）は有効

| 設定 | 値 |
|---|---|
`is_enabled` | **true**
`max_party_size` | 10
`auto_confirm` | true
`slot_duration_minutes` | 30
`max_advance_days` | 30（`rolling`）
`free_cancellation_hours` | 24
`course_menus` | `[]`（なし）

→ **サイトに予約導線を置ける**。`packages/core/src/pos/reservation-info.ts` が既にあるので
実装コストはほぼゼロ。他サイトの前例に倣い、人数上限などを本文に書く場合は `fresh: true`
で取得する（同モジュールの docblock がこの理由を明記している）。

### 営業時間（`stores.opening_hours`）

| 曜日 | |
|---|---|
| 月 | **休** |
| 火 | 17:00–22:00 |
| 水 | 17:00–22:30 |
| 木 | 17:00–22:30 |
| 金 | 17:00–**00:00** |
| 土 | 17:00–**00:00** |
| 日 | **休** |

日跨ぎ（`00:00` close）がある。`packages/core/src/hours/` はこれを扱える実装だが、
「Mon–Fri …」形式の compact summary が金土の深夜閉店をどう出すかは実装時に目視確認する。

---

## 2. 判断が必要な論点（先に詰めるべき 3 点）

### ⚠️ 2-1. ドメイン — `klande.fi` は既に Squarespace で存在する

```
https://klande.fi → 301 → https://www.klande.fi
   server: Squarespace / HTTP 401 / <title>Private Site</title>
klandestina.fi / www.klandestina.fi / klandestinacantina.fi → NXDOMAIN
```

`www.klande.fi` は**パスワード保護された未公開の Squarespace サイト**（401 + "Private Site"）。
つまり先方は Squarespace で作りかけて公開していない状態。ここから次のどれかを選ぶ必要がある:

1. `klande.fi` を当社サイトに向け替える（Squarespace は解約。DNS は先方所有）
2. `klandestina.fi` を新規取得（未登録。ブランド名と一致し SEO 上も素直）
3. サブドメイン（`www.klande.fi` を残し `menu.klande.fi` 等）

**推奨は 2 + 1**（`klandestina.fi` を正とし `klande.fi` から 301）。ただし
**ドメインは先方資産なので、プロトタイプ段階では決めない**。他サイトと同じく
`PREVIEW_TOKEN` 付きの社内プレビューで出し、公開時に確定させる。

> 既存 Squarespace が「非公開」である事実は提案の武器になる。先方は自作を途中で
> 止めている可能性が高く、こちらが POS 連携込みで出せば乗り換え動機になる。

### ✅ 2-2. 写真 → 先方提供素材で解決（§7 参照）

`~/Downloads/Klandestina/` に**プロ撮影の 8 点 + ロゴ**が提供された。これを正とする。
POS 側の写真（52 品中 6 品）はサイトでは使わず、提供素材で構成する。
詳細・使い分け・注意点は **§7 アートディレクション**に記載。

### ⚠️ 2-3. Burritos カテゴリが API に出てこない

POS には `Burritos` カテゴリと 4 商品（各 €17.00、fi 翻訳付き）が登録されているが、
`public-menu` の応答に現れない。原因は商品そのものではなく**店舗別の在庫状態**:

| 層 | 値 |
|---|---|
| `products.status` | `active`（4件とも） |
| `products.active_in_web` | `true`（4件とも） |
| **`product_availabilities.status`** | **`inactive`（4件とも / この店舗行）** |
| `product_availabilities.active_in_tos` | `false` |

つまり商品マスタは生きていて、**この店舗で「提供停止」にされている**状態。
POS 側で該当店舗の availability を `active` に戻せば、コード変更なしでサイトに出る。

同様に `Quesabirria` `Beef Taquitos` `Churros` は `status='active'` だが
`active_in_tos=false`。`?all=true`（MARKETING モード）は TOS ゲートを無視するので
**サイトには出る** — つまり「店では今出していないがサイトには載る」状態になりうる。

→ **先方に確認すべき事項**: Burritos は廃止か季節休止か。サイトに載せるべき品は何か。
バグではなく POS の運用状態なので、コードで直す話ではない。

---

## 3. 制作プラン

### 前提: monorepo のルールに従う

`HP/restaurant-sites` は「共通コードは `packages/`、サイト固有は `sites/<name>/`」という
明確な構成。`AGENTS.md` と `README.md` の規約を守る:

- `packages/core` は framework-free を維持（next/React を持ち込まない）
- サイト間でコンポーネントをコピーしたくなったら `packages/ui` に移す
- `packages/` を触ると**全サイトが再デプロイされる** → ルートで `npm test` と
  `npm run type-check` を通してからコミット
- Node 24 必須（`.nvmrc`）。npm 10 / Node 20 ではインストールが壊れる
- Next.js は 16.4 系で、学習データと差異がある。実装前に
  `node_modules/next/dist/docs/` の該当ガイドを読む（`AGENTS.md` の指示）

### Phase 0 — 足場（0.5 日）

1. `sites/taro-group` → `sites/klandestina` をコピー、`package.json` の `name` を
   `klandestina-site` に変更
2. **ポート 3600 / サブネット `192.168.242.0/24`** を確保（README の表で未使用を確認済み）。
   `package.json` の dev/start スクリプトと `docker-compose.yml` に設定し、
   **README の表に行を追加**（規約で求められている）
3. taro-group 固有の資産を削除 — `src/photos/**`、`messages/{es,et,ru,zh}.json`、
   `src/config/group.ts`、`[restaurant]` ルート、`CollectionIntro` / `StoreCard` 等の
   グループ専用コンポーネント
4. `messages/` は **fi.json / en.json のみ**（`supported_languages` に一致）。
   `packages/ui/src/messages` に fi/en は既存なので cookie banner はそのまま動く
5. ルートで `npm install`（lockfile にサイトを認識させる）

> taro-group は「複数レストラン・複数拠点のグループサイト」なので階層が 1 枚多い。
> Klandestina は**単店舗**なので、構造的には `katana` / `wagocoro` の単店舗型が近い。
> 実装前に両方を読み、単店舗に素直な方を雛形にするのが早い可能性がある。

### Phase 1 — データ配線（0.5 日）

1. `.env.example` / `.env`:
   ```
   NEXT_PUBLIC_SITE_URL=http://localhost:3600   # 公開ドメイン確定まで
   NEXT_PUBLIC_POS_ORIGIN=https://pos.sciometa.com
   POS_STORE_ID=0fd8bf5b-7c49-42ca-b243-46bd7ed86fe6
   PREVIEW_TOKEN=<生成>                          # 公開まで必ず設定
   ```
2. `src/config/restaurant.ts` を新規作成。taro-group の `group.ts` の docblock 作法に倣い
   **出典と確認日を明記**する。内容: 住所・SNS・`map_embed_url`・営業時間フォールバック・
   交通（最寄り Konepaja / Vallila 周辺の停留所を要調査）
3. `fetchPublicMenu` / `fetchReservationInfo` を配線。両 API は 200 を確認済みなので
   フォールバック経路は「POS 不達時」のみ
4. `next.config.js` の `images.remotePatterns` に `pos.sciometa.com/img/**` が入っていること
   を確認（共通 `posImagePattern` が入れている）

**写真の扱い（前例に従う重要点）**: taro-group の docblock が明記するとおり、
**ヒーローとフォールバック画像は POS URL ではなくローカルファイルにする**。
理由は「ヒーローは fetch 前に描画されねばならない」「フォールバックは POS 不達時のもの
なのに、その POS から画像を引いては意味がない」。
→ POS の 6 枚とロゴ・背景は `src/photos/` にダウンロードしてコミットする。

**価格フォールバックの禁則**: taro-group が「架空価格は店が履行義務を負う主張になる」
として、フォールバック時は料理名と写真のみ・価格なしにしている。これに倣う。

### Phase 2 — デザイン / ページ（2〜3 日）

単店舗 1 ページ構成（アンカーで移動）+ 法務ページ:

| セクション | 内容 | データ源 |
|---|---|---|
| Hero | 店名・一言・予約 CTA | 背景画像（ローカル化） |
| Story | カンティーナの紹介文 | **先方から要取得**（現状テキストなし） |
| Menu | Food = 写真カード / Drinks = 価格表 | POS ライブ |
| Hours & Info | 営業時間・住所・SNS | POS ライブ + config |
| Map | 同意ゲート付き埋め込み | `map_embed_url` |
| Reserve | 予約導線 | POS reservation |
| Footer | 法務リンク・SNS | `packages/ui/src/legal` |

- **Cookie banner / 同意ゲート地図 / 法務ページは `packages/ui` の既存品を使う**
  （`@restaurant-sites/ui/consent`）。独自実装しない。consent cookie は `site_consent`
- **トーン**: メキシカン・カンティーナ。既存 5 サイトは全て日本料理店なので、
  ここは**配色・書体を新規に起こす**価値がある。ただしコンポーネントは共有のまま、
  `--rs-*` トークンでテーマするのが規約（`README.md`）
- アクセシビリティ: 本文コントラストは **4.5:1 以上**を満たす。
  （社内に「金色をライト背景の本文に使って 2.02:1 だった」前例がある。彩度の高い
  ブランド色は見出し・黒背景限定にし、必ず実測する）

### Phase 3 — 検証・デプロイ（0.5〜1 日）

1. ルートで `npm test` + `npm run type-check`
2. fi / en 両ロケールで全セクション目視。**金土の `00:00` 閉店表示**を重点確認
3. POS 不達時のフォールバック（`POS_STORE_ID` を空にして確認）
4. `robots.ts` / `sitemap.ts` は **build 時の `NEXT_PUBLIC_SITE_URL` を焼き込む**ので、
   ドメイン確定後に必ず再ビルドする（社内で踏んだ罠）
5. `PREVIEW_TOKEN` を入れたまま社内 + 先方プレビュー（全ページ 404 + noindex、
   `?k=<token>` で開通）
6. GitHub Environment `klandestina` を作成し `SITE_ENV` を設定、nginx vhost を用意。
   `main` への push で該当サイトのみ自動デプロイされる

---

## 4. 先方に確認すべきこと

| # | 項目 | なぜ必要か |
|---|---|---|
| 1 | **ドメイン** | `klande.fi` は先方の Squarespace（非公開）。`klandestina.fi` は未登録 |
| 2 | **Squarespace の扱い** | 解約するのか、残すのか。DNS 切替の段取りに関わる |
| 3 | **店紹介テキスト（fi/en）** | 現在 POS にもどこにも無い。Story セクションが埋まらない |
| 4 | **料理写真** | 52 品中 6 品のみ。撮影の可否、または既存素材の提供 |
| 5 | **Burritos** | 4 品すべて `inactive`。廃止か季節休止か |
| 6 | **TOS 非公開の 3 品** | Quesabirria / Beef Taquitos / Churros をサイトに載せるか |
| 7 | **電話番号** | POS が `null`。サイトに載せるなら要取得（JSON-LD にも効く） |
| 8 | **料理名の fi 訳** | 説明文は fi 訳済みだが**料理名は英語のみ**。これで可か |
| 9 | **予約導線** | POS 予約は有効。サイトから受けるか、Instagram DM 運用のままか |

## 5. 工数見積

| Phase | 内容 | 工数 |
|---|---|---|
| 0 | 足場・ポート・雛形整理 | 0.5 日 |
| 1 | POS 配線・config・写真ローカル化 | 0.5 日 |
| 2 | デザイン・ページ実装（fi/en） | 2〜3 日 |
| 3 | 検証・プレビュー・デプロイ | 0.5〜1 日 |
| | **合計** | **3.5〜5 日** |

素材（紹介文・写真）が揃っていれば下限、こちらで起こすなら上限。
POS 連携が実機で動いている分、他サイトより立ち上がりは速い。

## 6. 補足 — POS 利用状況

`orders` は 85 件（2026-07-09〜2026-09-01）で、**直近 30 日は 0 件**。
内訳は `source=null` 79 件（〜08-18）、`source='tos'` 6 件（08-28〜09-01）。
POS が現在稼働していない可能性があるため、Web 制作の前提として
**POS 契約が現役かどうかを営業側で確認**しておくこと。メニューと予約の設定自体は
生きているので、サイト制作の技術的障害にはならない。

---

## 7. アートディレクション — 提供写真を軸にした「イケてる・格好いい」方向

出典 `~/Downloads/Klandestina/`（9 ファイル / 2026-10-29 受領）。
**全点を実際に目視して分類した**。プロ撮影で、素材の質は既存 5 サイトのどれより高い。

### 7-1. 素材一覧

| ファイル | 実寸 | 内容 | 用途 |
|---|---|---|---|
| `This kind of vibe.jpg` | 1088×1440 **縦** | タトゥーのバーテンダーがクープグラスに注ぐ。奥に談笑する客。琥珀色の照明 | **ヒーロー最有力** |
| `The place to be.jpg` | 4096×3056 | 暗い店内、光る **KLANDESTINA** サイン、バックバー。赤青紫のネオン | 中間の帯 / Story 背景 |
| `Hawaiian Salmon Tacos.jpg` | 3966×2231 | 紫キャベツ + パイナップル、ティール皿。**最も鮮やか** | Menu 筆頭 |
| `Beef Taquitos.jpg` | 4096×2304 | 細長皿に5つ並ぶ。マゼンタの紅玉ねぎ | Menu / 横長バナー |
| `Quesabirria tacos.jpg` | 2304×1296 | 青絵付けの小鉢とコンソメ添え | Menu |
| `Pork in Chilli Ancho Sauce.jpg` | 4023×2263 | 白皿、ソースが滴る瞬間 | Menu |
| `Sea Bass in Mango Salsa.jpg` | 4071×2290 | 白身魚 + フライドポテト | Menu |
| `Minced beef with Spanish chorizo.jpg` | 3897×2192 | ひき肉 + ライス、サワークリーム | Menu（優先度低） |
| `images.jpeg` | 225×225 | ロゴ。**濃紺 `#29455A` に黒のワードマーク** | 配色の典拠のみ |

**料理 6 点は同一シリーズ**：店内で**手に持った皿**を、工業的な内装のボケを背景に浅い被写界
深度で撮っている。構図が揃っているので**グリッドに並べると非常に強い**。
左に皿・右に腕という共通構図のため、**切り抜きは右側を落とす**と腕が切れて不自然。
`object-position: left center` 寄りのトリミングが安全。

### 7-2. 配色（ロゴから実測・コントラスト検証済み）

ロゴの地色をピクセル抽出 → **`#29455A`**（濃紺）。これをブランド基調にする。
料理写真の皿がティール/ネイビー、内装が黒鉄骨なので**写真と配色が最初から噛み合う**。

| 役割 | 色 | 根拠 |
|---|---|---|
| 基調（面） | `#29455A` ロゴ濃紺 | ロゴ実測 |
| 背景（地） | `#0E1A24` 更に濃いインク | 暗い店内写真に合わせる。ダーク基調 |
| 本文 | `#F5F0E6` 温白 | 濃紺上 **8.83:1** |
| 見出し/強調 | `#E8B33C` 琥珀 | 濃紺上 **5.23:1**。`This kind of vibe` の照明色と一致 |
| 差し色 | マゼンタ `#D94F70` | 紅玉ねぎ・ラディッシュの色。**本文禁止（2.53:1）** |

> ⚠️ **ロゴの黒ワードマークを濃紺の上に置くと 2.07:1 で判読不能**。
> ロゴ原画はそのまま使わず、**白または温白抜きのワードマーク**を別途用意する。
> 社内で「金色を白地の本文に使って 2.02:1」を踏んだ前例があるため、実装時に全ペア実測する。

### 7-3. トーン

ダークモード基調の一枚画面。既存 5 サイト（全て和食）とは意図的に別物にする。

- **暗い地に写真を浮かせる**。料理写真は彩度が高いので、地を沈めるほど映える
- 大きめのサンセリフ大文字 + 広めのトラッキング（ロゴのワードマークに呼応）
- 余白を広く、要素を詰めない。「隠れ家（clandestine）」の含意に合う
- アニメーションは抑制。ヒーローの微速ズーム程度に留める

### 7-4. セクション割付（§3 Phase 2 の表を更新）

| セクション | 画像 |
|---|---|
| Hero | `This kind of vibe.jpg`（縦構図でモバイル有利。デスクトップは右寄せ構図） |
| Story | `The place to be.jpg` を暗く敷き、テキストを重ねる |
| Menu — Food | 料理 6 点のグリッド |
| Menu — Drinks | 写真なしの価格表（36 品）。`This kind of vibe` のカクテルを帯に |
| Hours / Map / Reserve | 画像なし。濃紺の面で締める |

### 7-5. ⚠️ 料理写真 3 点が POS メニューに存在しない

ファイル名と POS 商品名を突き合わせた結果:

| 写真 | POS 商品 | 価格 |
|---|---|---|
| Beef Taquitos | ✅ `Beef Taquitos (5 tacos)` | €20 |
| Hawaiian Salmon Tacos | ✅ `Hawaiian Salmon (3 tacos)` | €17 |
| Quesabirria tacos | ✅ `Quesabirria (3 tacos)` | €18 |
| **Sea Bass in Mango Salsa** | ❌ **該当なし** | — |
| **Pork in Chilli Ancho Sauce** | ❌ **該当なし** | — |
| **Minced beef with Spanish chorizo** | ❌ **該当なし** | — |

`%bass%` `%mango%` `%chorizo%` `%minced%` `%ancho%` で全商品を検索しても
ヒットは `Pork Barbacoa` 2 件のみ。**この 3 品は現行メニューに無い**。

考えられるのは「撮影後に終売」「名称変更」「まだ POS 未登録」のいずれか。
→ **写真を商品カードに紐付けてはいけない**。価格や注文導線が付くと、
提供していない品を売っていることになる。扱いは次のどちらか:

- **A（安全・推奨）**: 3 点は**商品名を出さず**、Story や帯の「雰囲気写真」として使う
- **B**: 先方に確認し、現行名が判明したものだけ商品カードに昇格させる

一致した 3 点（Beef Taquitos / Hawaiian Salmon / Quesabirria）は
**POS の商品名・価格と結んでよい**。

### 7-6. 実装上の注意

1. **ローカルにコミットする**。§3 の原則どおりヒーローとフォールバックは
   POS URL ではなく `src/photos/` に置く（POS 不達時に出ないのでは意味がない）
2. **元画像が大きい**（最大 3.5 MB / 4096px）。`next/image` に通し、
   ヒーローのみ `priority`、他は遅延。長辺 2000px 程度に再エンコードして committed size を抑える
3. **POS 写真と二重に出さない**。`listProducts({ requireImage: true })` をそのまま使うと
   POS 側の 6 枚が出る。提供写真を商品名で引き当てる**ローカル優先のマッピング**を
   `src/config/restaurant.ts` に持ち、POS 画像はフォールバックに回す
4. `images.jpeg` は 225px と小さく**ロゴ用途には使えない**。POS の組織ロゴ
   （`org-logo-...jpg`）か、先方からベクター（SVG/AI）を取得する
5. **人物が写り込んでいる**（`This kind of vibe` の客、`The place to be` のスタッフ）。
   公開前に**被写体の掲載可否を先方に確認**する。GDPR 上も、客の顔が判別できる写真の
   公開には根拠が要る。背景の客はボケているが、手前のバーテンダーは判別可能

## 8. 更新された確認事項

§4 の表を以下で置き換える（写真関連が解決し、新たな論点が出た）。

| # | 項目 | 状態 |
|---|---|---|
| 1 | ドメイン | ⚠️ 未決。`klande.fi` は先方 Squarespace（非公開）/ `klandestina.fi` 未登録 |
| 2 | Squarespace の扱い | ⚠️ 未決 |
| 3 | 店紹介テキスト（fi/en） | ⚠️ **未取得**。Story セクションに必要 |
| 4 | 料理写真 | ✅ **解決**（8 点受領） |
| 5 | **写真 3 点の料理名** | ⚠️ **新規**。Sea Bass / Ancho Pork / Chorizo が POS に無い |
| 6 | **人物写真の掲載許諾** | ⚠️ **新規**。客・スタッフが写り込み |
| 7 | **ロゴのベクターデータ** | ⚠️ **新規**。提供は 225px のみ |
| 8 | Burritos | ⚠️ 店舗 availability が `inactive`。再開するか |
| 9 | TOS 非公開の 3 品 | ⚠️ Quesabirria / Beef Taquitos / Churros をサイトに載せるか |
| 10 | 電話番号 | ⚠️ POS が `null` |
| 11 | 料理名の fi 訳 | ⚠️ 説明文のみ fi 化。名前は英語 |
| 12 | 予約導線 | ⚠️ POS 予約は有効。サイトから受けるか |

## 9. 工数（写真取得を反映）

素材が揃ったことで Phase 2 の撮影待ちリスクが消え、**3.5〜4.5 日**に収束。
ただしダークテーマの配色を新規に起こす分、Phase 2 は下限側には振れにくい。

| Phase | 工数 |
|---|---|
| 0 足場 | 0.5 日 |
| 1 POS 配線 + 画像最適化・コミット | 0.5〜1 日 |
| 2 デザイン実装（ダーク基調 / fi・en） | 2〜2.5 日 |
| 3 検証・プレビュー・デプロイ | 0.5〜1 日 |
| **合計** | **3.5〜4.5 日** |

---

## 10. 現行の仮ページと、その置き換え（追記 2026-10-29）

> 先方の自社サイトが落ちており、暫定として
> **https://klandestina-konepaja.menu.sciometa.com/** を当社が公開中。
> 新サイトはこれを**置き換える**形で公開する。

### 10-1. 仮ページの正体 — 別サイトではなく POS 本体

実機で確認した結果、この URL は**独立したサイトではなく ReactRestaurantPOS 本体**が
出している「ストアフロント・ハブ」ページだった。

```
GET https://klandestina-konepaja.menu.sciometa.com/
→ 200 / server: nginx/1.18.0 (Ubuntu) / x-powered-by: Next.js
→ x-middleware-rewrite: /s/d4355c1      ← 店舗 short_code
```

経路は **nginx（リポジトリ外） → middleware → `/s/[storeId]`**:

| 層 | 処理 | 場所 |
|---|---|---|
| nginx | `<slug>.menu.sciometa.com/*` → `/menu/by-slug/<slug>` | **サーバ上のみ。Git 管理外** |
| middleware | `menu_slug` で `stores` を引き `short_code` を得る | `ReactRestaurantPOS/src/middleware.ts:226-274` |
| middleware | `/s/<short_code>` へ internal rewrite | 同 `:271-273` |
| page | ストアフロント・ハブを描画 | `src/app/s/[storeId]/page.tsx` |

- 解決キーは **`stores.menu_slug`**（`klandestina-konepaja` → `d4355c1`）。
  `stores.subdomain` 列は存在するが**全店舗 null で routing 未接続**（休眠列）。
- **`/menu/by-slug/[slug]` に実ページは無い**。rewrite 専用の仮想パス。
- `*.menu.sciometa.com` は**ワイルドカード DNS** で `194.157.26.62` に解決。
  存在しない slug でも DNS は引ける（＝DNS で公開可否は判断できない）。

現行ページが出しているもの: ヒーロー（背景画像・ロゴ・住所・営業状態バッジ）/
Reserve CTA / Menu CTA / おすすめ商品 / ギャラリー / 連絡先 / SNS / 営業時間 /
地図 / Google レビュー / Oiva リンク。
**メニュー明細自体はこのページには無く**、`/menu/<short_code>` へ CTA で送る構造。

### 10-2. ⚠️ 最重要 — このページは既に Google に送信されている

```
https://pos.sciometa.com/sitemap.xml  → 200 / 64 URL
  https://klandestina-konepaja.menu.sciometa.com/   ← 掲載あり
```

さらに実測で:

- **`<meta name="robots">` は無い** → 完全にインデックス可能
- **自己正規化している** — `<link rel="canonical" href="https://klandestina-konepaja.menu.sciometa.com/">`
- OG 一式あり（`og:image` は組織ロゴ）
- **`/robots.txt` が HTML を返す**（`content-type: text/html`）。nginx が全パスを
  rewrite するため robots.txt が存在せず、**このサブドメインにクロール制御が無い**

社内の `client-onboarding.md` §3 は、この URL を **GSC で Request indexing** し
**GBP の Website 欄に設定する**ことを標準手順としている。
→ **既に被リンク・インデックス・GBP 登録が付いている可能性が高い**。
実際の掲載状況を GSC で確認してから切り替え方を決める。

### 10-3. 置き換え方式の比較

`194.157.26.62` は **restaurant-sites の本番 VPS と同一ホスト**（deploy.yml の
`right=194.157.26.62`）。つまり**サーバ移転は不要で、nginx の vhost 切替だけ**で済む。

| 案 | 内容 | 評価 |
|---|---|---|
| **A** | 独自ドメイン（`klandestina.fi` 等）で新サイト公開 + 仮 URL から **301** | **推奨**。SEO 資産を引き継ぎ、ブランドも正す |
| **B** | 仮 URL 自体を新サイトへ向ける（`menu.sciometa.com` 配下のまま） | ドメインが当社のまま。先方資産にならない。暫定措置の恒久化 |
| C | 両方残す | **不可**。同一内容が2 URL で重複。canonical 管理が破綻 |

**A を推奨**。ただし §2-1 のとおりドメインが未決なので、**先に §8-1 を決める必要がある**。
ドメイン確定までは `PREVIEW_TOKEN` 付きプレビューで進め、仮 URL は**現状維持**。

### 10-4. 切替手順（案 A の場合）

nginx 設定は**Git 管理外でサーバ上にしか無い**（`embed-nginx-handover.md` が明記）。
作業はサーバ上で行うため、**手順を文書化してから実施**する。

1. 新サイトを独自ドメインで公開（`PREVIEW_TOKEN` をクリア、DNS を `194.157.26.62`）
2. 新サイト側が正しく `canonical` を自ドメインで出していることを確認
3. nginx に `klandestina-konepaja.menu.sciometa.com` の **301 → 新ドメイン**を追加
   - **`/` だけでなく全パス**を対象にする（現行 nginx は全パスを rewrite している）
   - POS 本体（`/s/d4355c1`）への経路は**他店舗が使い続ける**ので壊さない。
     この slug に限った vhost で上書きする
4. **`stores.menu_slug` を null にしない** — null にすると sitemap から消えるが、
   **301 を出す主体も消える**（nginx が rewrite 先を失う）。
   301 が効いた後、GSC で移行完了を確認してから判断する
5. POS の `sitemap.ts` は `menu_slug` が非 null の店舗を自動で載せる
   （`src/app/sitemap.ts:103-142`, `revalidate = 3600`）。
   **301 後もしばらく sitemap に残る**点に注意。Google には 301 が優先されるが、
   最終的には slug を外して sitemap から落とすのが綺麗
6. **GBP の Website 欄を新ドメインに更新**（`client-onboarding.md` §3.2 の逆操作）
7. GSC に新ドメインの property を追加し、サイトマップ送信。
   旧 URL の「カバレッジ」が 301 に移るのを 2〜4 週間監視

### 10-5. 仮ページから引き継ぐべき実装上の示唆

現行ページには、新サイトに**無いと劣化する**要素がいくつかある:

| 要素 | 現行 | 新サイトでの扱い |
|---|---|---|
| 構造化データ | `WebSite` + `Restaurant`（`parentOrganization` 付き） | `packages/core/src/jsonld.ts` で同等以上を出す |
| 営業状態バッジ | 「Closed」等をリアルタイム表示 | `packages/core/src/hours/` にロジックあり。**実装する** |
| Google レビュー | opt-in で表示 | `stores.google_rating` は **null**。現状データ無し |
| Oiva リンク | 食品安全（フィンランド法） | **引き継ぐ**。FI の飲食店サイトでは実質必須 |
| 多言語 | `?lang=` 12 言語 | 新サイトは fi/en の 2 言語（`supported_languages` に一致） |

> **メニュー明細は現行ページに無い**（CTA で `/menu/<code>` へ送る）。
> 新サイトは §7-4 のとおり**ページ内にメニューを持つ**ので、この点は純粋な改善になる。

### 10-6. 追加の確認事項（§8 に追補）

| # | 項目 | なぜ |
|---|---|---|
| 13 | **GSC の現行インデックス状況** | 301 の価値と緊急度を決める。切替前に必ず取得 |
| 14 | **GBP の Website 欄が仮 URL か** | 手順書が設定を指示している。切替漏れは流入を失う |
| 15 | **仮 URL 宛の被リンク / Instagram のリンク** | SNS プロフィールの URL も更新対象 |
| 16 | **nginx 設定の現物** | Git 管理外。301 を足す前にサーバ上の現状を読む |

---

## 11. 公開先 — sciometa.com への相乗り（追記 2026-10-29 / 方針決定）

> **決定**: 独自ドメインは据え置き。まず **sciometa.com 配下**に相乗りさせて公開する。

### 11-1. 前提の整理 — `*.menu.sciometa.com` は使えない

**仮ページの URL をそのまま新サイトに向けることはできない。**
`*.menu.sciometa.com` は nginx が**全パスを `/menu/by-slug/<slug>` に rewrite** し、
POS 本体の middleware が `stores.menu_slug` を引いて `/s/<short_code>` を描画する
**POS 専用の経路**だから（§10-1）。ここに別アプリを差し込むには nginx 側で
この slug だけを例外にする必要があり、**他店舗が使う共通経路に穴を開ける**ことになる。

→ **新サイトには別のホスト名を与え、仮 URL からはそこへ 301 する**のが正しい形。
これは §10-3 案 A の構造そのままで、**宛先が独自ドメインでなく sciometa.com になるだけ**。
将来 `klandestina.fi` 等が決まったら、同じ手順をもう一度行えばよい。

### 11-2. sciometa.com の現状（実測）

| ホスト | 解決 | 状態 |
|---|---|---|
| `sciometa.com` / `www.sciometa.com` | `194.157.26.62`（www のみ） | **HTTPS 応答なし**（apex は A レコードも無し） |
| `pos.sciometa.com` | `194.157.26.62` | POS 本体 |
| `web.sciometa.com` | `194.157.26.62` | **ScioWeb**（hp-builder / 製品 LP） |
| `*.menu.sciometa.com` | `194.157.26.62`（ワイルドカード） | POS ストアフロント専用 |

- 全て **`194.157.26.62`** = restaurant-sites の本番 VPS と同一ホスト。
  **サーバ調達も DNS 移転も不要**で、nginx の vhost 追加だけで載る。
- `web.sciometa.com/demos/<name>/index.html` に**旧プロトタイプの静的 HTML** が置かれている
  （`/demos/ramentaro` が現存。taro-group サイトの原型）。`/demos/klandestina` は 404。
- `web.sciometa.com` は **robots.txt / sitemap.xml ともに 404**。
  クロール制御が無い点は menu サブドメインと同じ。

### 11-3. 公開先の候補

| 案 | URL | 評価 |
|---|---|---|
| **A** | **`klandestina.sciometa.com`**（新規サブドメイン） | **推奨** |
| B | `web.sciometa.com/klandestina/`（パス配下） | 非推奨 |
| C | `web.sciometa.com/demos/klandestina/` に静的で置く | プロトタイプ確認用としてのみ可 |

**A を推奨する理由**:

1. **既存 5 サイトと同じ形で載る**。`docker-compose.yml` + nginx vhost で完結し、
   `restaurant-sites` の仕組み（ポート・サブネット・CI 自動デプロイ）をそのまま使える
2. **B はパス配下のため `basePath` が要る**。`packages/core/next-config.cjs` は
   `basePath` を持たず、入れると `next/image`・`sitemap.ts`・`robots.ts`・
   next-intl のルーティングに影響が波及する。**共通パッケージを触ると全5サイトが再デプロイ**
   されるので（`AGENTS.md`）、1サイトの都合で入れるべきでない
3. **A なら将来の独自ドメイン移行が 301 を足すだけ**で済む。B だとパス構造ごと変わる

> `menu.sciometa.com` 配下に揃える案（`klandestina.menu.sciometa.com`）は
> **採らない**。そこはワイルドカードで POS に吸われる領域で、slug 単位の例外を
> 積むと将来 POS 側の rewrite 変更で静かに壊れる。

### 11-4. 手順（案 A）

既存サイトの追加手順（§3 Phase 0〜3）に、以下を上乗せする。

1. **DNS**: `klandestina.sciometa.com` A レコード → `194.157.26.62`
   （sciometa.com のゾーンは当社管理なので先方調整が不要 — **これが相乗りの利点**）
2. `.env`（GitHub Environment `klandestina` の `SITE_ENV`）:
   ```
   NEXT_PUBLIC_SITE_URL=https://klandestina.sciometa.com
   NEXT_PUBLIC_POS_ORIGIN=https://pos.sciometa.com
   POS_STORE_ID=0fd8bf5b-7c49-42ca-b243-46bd7ed86fe6
   PREVIEW_TOKEN=<生成>      ← 先方確認が済むまで維持
   ```
   `NEXT_PUBLIC_SITE_URL` は **build 時に robots/sitemap に焼き込まれる**ので、
   `docker-compose.yml` の build args にも渡す（washoku-tomo の compose に前例あり）
3. **nginx vhost**: `klandestina.sciometa.com` → `127.0.0.1:3600` へ proxy。
   TLS は Let's Encrypt。既存サイトの vhost をひな形にする
4. 先方確認 → `PREVIEW_TOKEN` をクリアして公開
5. **仮 URL から 301**（§10-4 の手順 3〜7）。
   `klandestina-konepaja.menu.sciometa.com/*` → `https://klandestina.sciometa.com/`
6. **GBP の Website 欄**と Instagram プロフィールの URL を新 URL に更新

### 11-5. この方針での SEO 上の注意

- **301 は必ず出す**。仮 URL は POS の sitemap に載っており（§10-2）、
  単に放置すると**同内容が 2 URL で並ぶ**。新サイトは自ドメインで canonical を出すので、
  301 と合わせて初めて評価が寄る
- **`stores.menu_slug` は当面そのまま**にする。null にすると sitemap からは消えるが、
  **301 を出す nginx の rewrite 先も失われる**（§10-4 手順 4）
- `sciometa.com` は**当社ドメイン**なので、被リンク・評価は当社側に貯まる。
  独自ドメインへ移す際に**もう一度 301 が必要**になる点は、先方に説明しておく
  （「ひとまず相乗り」はこのコストを先送りする判断であって、無コストではない）

### 11-6. 据え置きにより変わらない点

- §7 のアートディレクション、§3 の実装計画は**そのまま有効**
- 工数 **3.5〜4.5 日**も据え置き（DNS が当社管理になる分、むしろ調整待ちが減る）
- §8 の確認事項から **#1 ドメイン / #2 Squarespace は「保留」**に降りる。
  残る未取得素材は**店紹介テキスト（fi/en）**と、§7 で挙げた写真 3 点の料理名・掲載許諾・ロゴ原画

---

## 12. Web からの素材取得 調査結果（追記 2026-10-29）

§8 の未取得 4 点（紹介文 / 写真3点の料理名 / 掲載許諾 / ロゴ原画）について、
公開情報から取得できるかを調査した。**2 点は実質解決、2 点は Web では解決不能**。

### 12-1. 【重大】そもそも店舗が移転している

アグリゲータの情報が食い違っていたので追ったところ、**Klandestina は移転していた**。

| | 旧 | 現（POS の店舗） |
|---|---|---|
| 住所 | **Harjutori 2, 00500**（Kallio）/ Hakaniemi UG | **Aleksis Kiven katu 17, 00510**（Vallila / Konepaja） |
| 形態 | 独立した小規模店 | **Konepaja Train Factory Market Hall** 内（22 店のフードホール） |
| 営業時間 | 平日ランチ 10:30–14:30 + 夜 17:00–24:00 | 火〜土の夜のみ（§1 参照） |

- フードホールは **2026-05-27 開業**、20 店超。Klandestina はメキシコ料理枠で入居
  （avecmedia: 「Klandestina meksikolaista ja Casa Italia italialaista keittiötä.」）
- POS の店舗作成が **2026-06-19** で開業時期と整合する

> ⚠️ **ここが最大の落とし穴**。Tripadvisor / eat.fi / restaurantguru / MapQuest /
> Google の多くが**旧店舗の住所・営業時間・説明文**を載せたままになっている。
> 「Mon–Fri 11:00–21:00」「Harjutori 2」「Hakaniemi メトロ構内」等は**すべて古い**。
> **これらをサイトの文面に流用してはいけない**。正は POS と先方。

副次的効果として、**サイトを出す価値が調査前より高い**。現在ネット上の情報が
旧店舗のまま散らばっており、正しい情報源が実質 §10 の仮ページしかない。

### 12-2. 取得できたもの

#### (a) 店紹介テキスト → **素材として十分なものが集まった**

ブランド自身の言葉として使えるもの:

| 出典 | テキスト |
|---|---|
| Instagram bio | **"Contemporary Mexican Cuisine \| Bar Casual dining \| Come for the food stay for the drinks"** |
| Tripadvisor（店舗登録文） | "Casual Mexican Dinner! Authentic Mexican food made with love! Join us for the best Mexican experience in Helsinki!" |
| 同（ブランド文） | "tacos are our passion" / "the best ingredients available to give you an extraordinary mexican experience" |
| MyHelsinki（公的観光サイト） | "Klandestina is Mexican restaurant located in the Train Factory in Konepaja, in the Vallila neighbourhood. The restaurant serves Mexican food, beers, drinks and cocktails." |

**Instagram の bio が最も使える**。"Come for the food stay for the drinks" は
そのままヒーローのコピーになる強さがあり、§7 のダーク基調・バー寄りの方向とも一致する。

→ **これで Story セクションは書ける**。ただし**これらは当社が書いた文ではない**ので、
ドラフトを起こして**先方承認を取る**手順は必要（引用元が旧店舗時代の文の可能性もある）。

#### (b) 電話番号 → **取得できた（要確認）**

**+358 40 6520808** — Tripadvisor / restaurantguru / cylex / MapQuest で一致。
POS の `stores.phone` は null なので、**裏が取れれば POS にも入れる**のが望ましい
（JSON-LD とレシートにも効く）。

> ただし**旧店舗時代から変わっていない保証はない**。§12-1 のとおり他の情報は
> 軒並み古いので、**この番号も先方に一言確認する**。

#### (c) ロゴ → **実像が判明。ただし使える原画は依然無い**

POS の `storefront_background_image`（1600×600）を開いたところ、
**本当のブランドマークが写っていた**:

- **白のロバ/ゼブラのマスコット** + その下に **KLANDESTINA のワードマーク**
- 背景はタコス・ワカモレ・ライムを俯瞰で並べたコラージュ

§7-2 で「ロゴは濃紺地に黒ワードマーク」と書いたが、**あれは縮小版の簡易ロゴ**だった。
実際のロゴは**白抜き**で、暗い背景に載せる前提の設計。
→ §7-2 の「白抜きワードマークを別途用意」という結論は**正しかった**が、
理由が変わる。**作る必要はなく、既存の白ロゴを入手すればよい**。

| 入手元 | 解像度 | 可否 |
|---|---|---|
| `images.jpeg`（先方提供） | 225×225 | ✗ 小さすぎ |
| POS `org-logo` | **200×200** | ✗ 小さすぎ（実測） |
| POS `storefront-bg` | 1600×600（**ロゴは一部**） | △ 切り出せばヒーロー用には足りる可能性 |
| 先方のベクター（AI/SVG/PNG） | — | **要依頼** |

→ **ロゴ原画は Web からは取得不能**。先方依頼のまま。
ただし**背景画像から切り出せば暫定的には足りる**ので、プロトタイプは止まらない。

### 12-3. 取得できなかったもの

#### (d) 写真 3 点の料理名 → **Web では解決不能**

`Sea Bass in Mango Salsa` / `Pork in Chilli Ancho Sauce` /
`Minced beef with Spanish chorizo` は、Wolt・Quandoo・restaurantguru 等を当たっても
**現行メニューとして確認できなかった**。アグリゲータのメニューは §12-1 のとおり
**旧店舗のものが混在**しており、仮に一致しても**根拠にならない**。

→ §7-5 の判断は変えない。**この 3 点は商品名を出さず雰囲気写真として使う**（案 A）。
先方確認が取れたものだけ商品カードに昇格させる。

#### (e) 人物写真の掲載許諾 → **原理的に Web で解決できない**

`This kind of vibe.jpg` のバーテンダー、`The place to be.jpg` のスタッフは
顔が判別できる。**掲載可否は本人と先方にしか決められない**。GDPR 上も同じ。
→ 先方確認のまま。

### 12-4. 確認事項の更新（§8 / §10-6 を更新）

| # | 項目 | 調査後の状態 |
|---|---|---|
| 3 | 店紹介テキスト | 🟡 **Web 素材で起案可能**。ドラフト→先方承認に変更 |
| 5 | 写真 3 点の料理名 | 🔴 Web 不能。**先方確認必須**（当面は雰囲気写真） |
| 6 | 人物の掲載許諾 | 🔴 Web 不能。**先方確認必須** |
| 7 | ロゴのベクター | 🟡 実像判明。背景画像から暫定切り出し可。**原画は要依頼** |
| 10 | 電話番号 | 🟢 **+358 40 6520808** を取得。要裏取り |
| — | **旧店舗情報の氾濫** | 🔴 **新規**。Tripadvisor 等が旧住所・旧営業時間のまま |

### 12-5. この調査が制作計画に与える影響

- **ブロッカーは実質 2 件**（写真3点の料理名 / 人物許諾）に減った。
  どちらも**回避策があり制作は止まらない**（名前を出さない・人物写真を使わない）
- 工数 **3.5〜4.5 日**は据え置き
- **公開後のタスクが 1 つ増える**: Google ビジネスプロフィール・Tripadvisor・
  MyHelsinki 等の**旧情報の是正**。サイトを出しても、検索結果が旧住所を
  指していては意味が薄い。§11-4 手順 6（GBP 更新）を**旧住所の訂正まで含める**

> なお eat.fi・restaurantguru 等の第三者サイトの説明文を**サイトに転載してはいけない**。
> 著作権の問題に加え、§12-1 のとおり**内容が旧店舗のもの**。
> 使うのは Instagram bio（ブランド自身の言葉）と、そこから起こす当社ドラフト。

---

## 13. 実装完了（2026-10-29）

`HP/restaurant-sites/sites/klandestina/` に構築済み。**人物写真は一切不使用**。

### 13-1. 検証済みの項目

| 検証 | 結果 |
|---|---|
| リポジトリ全体 `npm run type-check` | ✅ 全6ワークスペース通過 |
| `npm test`（packages/core） | ✅ 4ファイル / 11テスト |
| 本番ビルド | ✅ 8ページ生成。robots/sitemap は動的 |
| `/` `/en` `/privacy` `/en/cookies` | ✅ すべて 200 |
| POS ライブ連携 | ✅ 実データ描画を確認 |
| プレビューゲート | ✅ 無token=404+noindex / `?k=` で200 |

POS 連携の実描画（fi）:
`Hawaiian Salmon (3 tacos) 17 €` / `Quesabirria (3 tacos) 18 €` /
`Beef Taquitos (5 tacos) 20 €`、カテゴリ10件、**フィンランド語説明文**
（`Limellä maustettu kuha, kiivi...`）、価格は `9,50 €` のFI書式。
営業時間は `ti 17:00–22:00 / ke–to 17:00–22:30 / pe–la 17:00–00:00` と
**日跨ぎを正しく集約**。JSON-LD は `openingHoursSpecification` 5件、
`telephone` と `aggregateRating` は**意図的に不在**。

### 13-2. 人物の非掲載（ご指示対応）

- `This kind of vibe.jpg`（バーテンダー）→ **不使用**
- `The place to be.jpg` → **カウンターより上だけを切り出し**
  （元 4096×3056 の y=1000..1520）。人物のいない 2000×254 のバンドにして
  ヒーローに使用。看板とネオンは残っている
- 判断理由は `src/config/site.ts` と `AGENTS.md` に明記。
  将来同意が取れた場合は**元画像の方が良い写真**である旨も併記

### 13-3. 設計判断

- **ダークテーマ**（`ink #0E1A24` / ロゴ由来 `navy #29455A` / `amber #E8B33C`）。
  既存5サイトは全て明るい和食系なので意図的に差別化
- **コントラストは全ペア実測**。`chilli #D94F70` は 4.45:1 で**AA不適合**と判明し、
  大きい文字専用に限定（当初 4.52:1 でAA可と書いたのは誤りで訂正済み）
- **メニューは2層構成** — 写真付き6点の「シグネチャー」＋ POS全52品の価格リスト。
  ドリンク36品に写真が無いため1つのグリッドでは破綻する
- **未特定の料理写真3点は名前も価格も出さない**。雰囲気写真として配置し、
  alt属性のみ内容を説明（提供していない料理の注文を招かないため）
- 価格のフォールバックは**一切持たない**（POS不達時は該当セクションごと非表示）

### 13-4. 作業中に見つけて直した不具合

1. **地図の「Näytä kartta」ボタンが空の琥珀色の塊**になっていた。
   `--rs-accent-text` を amber にしたため `.rs-btn--solid` が
   「琥珀地に琥珀文字」になっていた。`ink`（9.18:1）に修正
2. 共有UIの `rs.*` メッセージ未マージで `MISSING_MESSAGE` が発生。
   `withUiMessages` を `i18n/request.ts` に追加
3. 共有スタイルシート未読み込みで Cookie バナーと地図が無装飾だった

### 13-5. 残課題（先方確認）

| # | 項目 | 影響 |
|---|---|---|
| 1 | **店紹介テキストの承認** | 現在は Instagram bio 等からの当社ドラフト |
| 2 | **写真3点の料理名** | 判明すれば `site.photoDishes` に追記で商品化 |
| 3 | **人物写真の同意** | 取得できれば最良のヒーロー写真が使える |
| 4 | **電話番号** | +358 40 6520808 を未掲載。POSに入れれば自動反映 |
| 5 | **ロゴのベクター** | 現在ワードマークはテキスト描画 |
| 6 | **登記住所** | `organizations.address` が null。YTJ要確認 |
| 7 | fi コピーのネイティブ校正 | ヒーロー訳など |

### 13-6. 公開手順

1. GitHub Environment `klandestina` を作成し `SITE_ENV` を設定
   （`.env.example` 参照。**`PREVIEW_TOKEN` は設定したまま**）
2. DNS: `klandestina.sciometa.com` A → `194.157.26.62`
3. nginx vhost → `127.0.0.1:3600`、Let's Encrypt
4. 先方確認 → `PREVIEW_TOKEN` をクリアして再作成（**リビルド不要**）
5. 仮URLから301（§10-4）。`menu_slug` は当面残すこと

---

## 14. 人物写真の解禁に伴う差し替え（2026-10-29 追記）

先方より**提供写真はそのまま使用可**との確認。§13-2 の制約を撤回し、
人物の写った2点を**全画面で採用**した。

| 用途 | 変更前 | 変更後 |
|---|---|---|
| ヒーロー | 看板だけの切り出し帯（2000×254） | **`bar-pour.jpg`**（1209×1600・縦） |
| Story | 店舗コラージュ（ロゴ入り） | **`interior-full.jpg`**（2000×1492・全景） |

- **`interior-sign.jpg`（切り出し版）は削除**。参照ゼロを確認済み
- `storefront-collage.jpg` は**残置**。実ロゴが使えるサイズで存在する唯一の
  ファイルなので、ベクター入手までの保険として保持

### 14-1. レイアウトの変更理由

`bar-pour.jpg` は**縦長(3:4)**。横長のヒーロー帯に切ると「腕の一部」になるため、
**2カラム分割**（左=見出し/右=写真）に変更。モバイルでは写真がコピーの**下**に回る。
Story 側は暗い全景なので、ヒーロー（明るい・寄り）との**対比**が成立する。

### 14-2. alt 属性

人物写真2点は**装飾ではなく内容を説明**する扱いにした（`alt=""` にしない）。
見出しの「jää juomien takia（飲みに残っていって）」という主張を支えているのは
この写真であり、スクリーンリーダー利用者がテキストだけでは得られないため。

```
alt="Baarimikko sekoittaa cocktailia baaritiskillä, taustalla vieraita pöydissä"
alt="Klandestinan baari illalla: valaistu kyltti juomahyllyn yläpuolella, ..."
```

### 14-3. 記録として残した注意

`src/config/site.ts` と `AGENTS.md` に以下を明記:

> 解禁の対象は**この2ファイル**。ヒーロー背景に写り込んだ**客**から
> 申し出があった場合は、**切り抜きではなく写真の差し替え**で対応する。

### 14-4. 再検証

| 検証 | 結果 |
|---|---|
| リポジトリ全体 type-check | ✅ 6ワークスペース |
| `npm test` | ✅ 11テスト |
| 本番ビルド | ✅ 8ページ |
| デスクトップ / モバイル描画 | ✅ スクリーンショット確認 |
| 画像総量 | 3.4 MB（+1.0 MB） |

§13-5 の残課題から **#3「人物写真の同意」は解決**。残り6件。

---

## 15. 予約をフォーム埋め込みに変更（2026-10-29 追記）

ご指定のスニペットを `ReservationEmbed` コンポーネントとして実装。
外部リンクから**ページ内フォーム**に変更した。

```html
<script async src="https://pos.sciometa.com/widget/reserve.js"
        data-store="5bf3ed5" data-lang="auto"></script>
```

### 15-1. JSXに貼るだけでは動かない

**React は JSX で書いた `<script>` を実行しない**（DOMには入るが走らない）。
さらに loader は `document.currentScript` を読んで
①どの店舗か ②どこに iframe を挿すか を決めるため、別経路で注入すると
`currentScript` が null になり `if (!script) return` で**無言で終了**する
（iframe もエラーも出ない）。

→ `useEffect` 内で `document.createElement('script')` し、
**data-* を append の前に設定**。wagocoro で確立済みの作法に倣った。
StrictMode の二重実行対策と、**cleanup で script を外さない**理由
（loader が後から `parentNode.insertBefore` を呼ぶため null 参照で落ちる）も
コメントに記載。

### 15-2. ⚠️ 現状フォームは表示できない — allow-list が空

実ブラウザで検証した結果:

```
loader script tags: ["5bf3ed5|auto"]          ← 正しく注入
iframe: /embed/reserve/5bf3ed5?lang=fi&fit=1  ← lang も自動判定OK
console: Framing 'https://pos.sciometa.com/' violates
         ... "frame-ancestors 'self'". The request has been blocked.
```

埋め込みページは `frame-ancestors 'self' <allow-list>` で配信され、
リストは **`org_reservation_defaults.embed_allowed_domains`（組織単位）**。
**Klande Oy は `[]`（空）** なので、POS以外のホストでは
**何もログに残らないまま空の640px**になる。

#### 対応: フラグで分岐

`site.reservation.embedAllowlisted`（現在 `false`）で切替。
false の間は**予約ページへのリンク**を出す。空の箱より誠実で、必ず動く。

**有効化の手順**（本番データ変更のため未実行・ご判断ください）:

```sql
update org_reservation_defaults
   set embed_allowed_domains = array['klandestina.sciometa.com']
 where organization_id = 'badb316b-a6ec-4bbd-aec5-b27bfff43cf3';
```

→ その後フラグを `true` にして再デプロイ。
値は**スキームなしのホスト名**（既存例: `katana-ramen.com` /
`wagocoro.web.sciometa.com` / `tomo.web.sciometa.com`）。
**localhost は登録できない**ので、ローカルでは常にリンク表示になる。

### 15-3. レイアウト

フォームは約640pxで自動伸縮するため、左カラム（営業時間・住所）とは同居不可。
**2カラムの下に全幅ブロック**として独立させ、`#book` でアンカー可能にした。
iframe は明るい背景を自前で描画するため、`surface` の枠で囲んで
ダークな地に白い板が貼り付いて見えないようにしている。

### 15-4. 検証

| 項目 | 結果 |
|---|---|
| type-check / test / build | ✅ 6ワークスペース・11テスト・8ページ |
| loader 注入・lang自動判定 | ✅ 実ブラウザで確認 |
| allow-list 未登録時の挙動 | ✅ 空箱でなくリンクにフォールバック |

§13-5 の残課題に **#8「embed allow-list への登録」** を追加。

---

## 16. スペイン語を追加（2026-10-29 追記）

ロケールを **fi（既定）/ en / es** の3言語に拡張。

### 16-1. ⚠️ メニューはスペイン語にならない（仕様）

**POS 側に `es` の翻訳が1件も無い**ことを確認した:

```
store.supported_languages = ["fi","en"]
products(56件) の translations に 'es' … 0
products(56件) の description_translations に 'es' … 0
categories(11件) の translations に 'es' … 0
```

共有の `pickTranslated` は該当ロケールが無ければ**ベース文字列へフォールバック**するため、
`/es` では**サイト自身のコピーはスペイン語・料理名と説明は英語**になる。

これは不具合ではなく**この構成で取りうる唯一の正しい挙動**（代替は空行）。
ただし黙っていると読者が戸惑うので、**スペイン語版の `menu.posNote` に明記**した:

> 「Los nombres de los platos aparecen en inglés.（料理名は英語で表示されます）」

**POS に `es` 翻訳を入れれば、コード変更なしで自動的に反映される。**

> なお料理名の多く（birria / salsa verde / aguachile / queso fresco）は
> **元々スペイン語**なので、実用上の違和感は小さい。

### 16-2. 予約ウィジェットも es 非対応

`reserve.js` の `SUPPORTED = ['en','fi','sv','no','da']`。
`data-lang="auto"` は未対応言語を**黙って捨ててブラウザ言語で交渉**するため、
スペイン語話者には**ブラウザの言語**でフォームが出る（多くの場合スペイン語、
最悪でも英語）。壊れはしない。対応したい場合は POS 側リストへの追加が必要。

### 16-3. 法務ページも翻訳（重要）

`LocalizedDoc` は `Record<'fi'|'en'|'es', LegalDoc>` で、
**キー欠落は `/es/privacy` のクラッシュに直結**するため両ファイルとも追加済み。

翻訳にあたり**監督官庁は фин 側のまま**とした:

- 苦情申立先は **Tietosuojavaltuutetun toimisto（tietosuoja.fi）**。
  スペインの **AEPD に差し替えない** — 読者が何語で読もうと、
  この事業者はフィンランド法人でフィンランド法の下にある
- Cookie 法も **フィンランドの電子通信サービス法 917/2014 第205条**のまま
  （スペインの LSSI-CE にしない）

この取り違えは翻訳版プライバシーポリシーで最も起きやすい誤りなので、
両ファイルの docblock に理由を明記した。

### 16-4. 書式

`intlLocale` は **`es-ES`**（`es-MX` ではない）。
読者はヘルシンキにいるため、`9,50 €` と欧州式で揃う。
`es-MX` だと `$` とドット小数になり、隣の fi ページと不整合になる。

曜日も自動で `mar / mié–jue / vie–sáb` と出ることを確認。

### 16-5. 検証

| 項目 | 結果 |
|---|---|
| type-check / test | ✅ 6ワークスペース・11テスト |
| ビルド | ✅ **9ルート**（fi/en/es × 本体・privacy・cookies） |
| `/es` `/es/privacy` `/es/cookies` | ✅ すべて 200 |
| 監督官庁の取り違え | ✅ `tietosuoja.fi` 保持 / `AEPD` 混入なし |
| メッセージキー整合 | ✅ 3言語とも 36キーで一致 |
| 言語スイッチャー | ✅ FI/EN/ES の3つを表示 |
| sitemap | ✅ 3ロケール分を出力 |

> 新しいロケールを足す際の注意として **「4箇所」**（routing / messages /
> `Trilingual` 型 / **法務2ファイル**）を `AGENTS.md` に記載した。

---

## 17. 3言語の翻訳レビュー（2026-10-29 追記）

全36キー＋config のコピーを3言語横並びで確認し、不自然な箇所を修正した。

### 17-1. 【最重要】施設名を翻訳していた

**`Konepajan halli`（fi）と `el mercado Train Factory`（es）は当方の造語**だった。

施設の**公式サイト `trainfactory.com` のフィンランド語ページ**を確認したところ、
フィンランド語の文章中でも **英語のまま "Train Factory" / "Market Hall"** を使っている:

> 「Market Hall on **Train Factoryn** sydän」

→ 3言語とも**固有名詞は英語のまま**にし、周囲だけ各言語で格変化させる方式に統一:

| | 修正前 | 修正後 |
|---|---|---|
| fi | Konepajan hallissa | **Train Factoryn Market Hallissa, Konepajalla** |
| en | the Train Factory, Konepaja | **the Market Hall at Train Factory, Konepaja** |
| es | el mercado Train Factory | **el Market Hall de Train Factory, Konepaja** |

**施設名を訳すと検索できず現地でも辿り着けない。** 住所行で最もやってはいけない誤り。
なお `Konepaja` 単体は**地区名**（実在のフィンランド語）なので各言語で残している。

判断理由は `src/config/site.ts` の docblock に明記した（将来「訳し直される」のを防ぐため）。

### 17-2. フィンランド語の修正

| 箇所 | 修正前 → 修正後 | 理由 |
|---|---|---|
| hoursFallbackNote | ~~eivät ole **hetkeen** saatavilla~~ → `eivät ole **juuri nyt** saatavilla` | 否定文の `hetkeen` は「しばらく前から〜ない」。意味が変わる |
| 同 | ~~tavanomaiset **aikamme**~~ → `tavalliset **aukioloaikamme**` | 直訳調。語も不足 |
| tagline | ~~Rentoa ruokailua ja **baari**~~ → `Rento ruokapaikka ja baari` | 分格と主格の混在 |
| story body | ~~baarin, joka **jatkaa** vielä keittiön hiljennyttyä~~ → `Baari jatkaa vielä sen jälkeen, kun keittiö on mennyt kiinni.` | `jatkaa` が目的語を要求。文も長すぎたので分割 |
| 同 | ~~Rentoa menoa, sopivasti meluisaa~~ → `Meininki on rentoa ja sopivan äänekästä` | 断片の羅列 |
| notFound.body | ~~Sivua ei ole olemassa~~ → `Etsimääsi sivua ei ole — se on ehkä siirretty tai poistettu.` | 直訳調。タイトルと重複していた |
| menu.unavailable | ~~Katso **Instagramistamme**~~ → `Katso Instagramimme` | `katso` の格支配 |
| alt 3点 | ~~tarjoilijan **kädessä**~~ → `tarjoilijan **käsissä**` | 両手で持っている写真 |

> `Menu` は英語に見えるが**フィンランド語で通常使用**（姉妹サイト tokyo-street-helsinki
> でも `Koko Menu` 等で使用）。そのまま維持。

### 17-3. スペイン語の修正

| 箇所 | 修正前 → 修正後 | 理由 |
|---|---|---|
| bookBody | ~~Mesas **para hasta** 10~~ → `Mesas **de hasta** 10 personas` | `para hasta` は不自然 |
| heroAlt | ~~**agitando** un cóctel~~ → `**preparando** un cóctel en la coctelera` | `agitando` 単体は妙。スペイン語話者は `preparar` |
| menu.intro | ~~nunca **va por detrás de** la cocina~~ → `siempre está **al día con** la cocina` | 英語の直訳 |
| hoursFallbackNote | ~~El horario **en vivo**~~ → `El horario **actualizado**` | `en vivo` は生放送 |
| posNote | ~~¿Alergias?~~ → `¿Tienes alguna alergia?` | 唐突 |
| story body | ~~la cocina ya **se ha calmado**~~ → `la cocina ya **ha cerrado**` | 厨房には使わない表現 |
| tagline | ~~Comida informal y barra~~ → `Ambiente informal y buena barra` | メニュー分類のように読める |

### 17-4. 英語の修正

| 箇所 | 修正前 → 修正後 | 理由 |
|---|---|---|
| menu.unavailable | ~~or **call in**~~ → `or just **drop by**` | 英では「立ち寄る」だが「電話する」と紛らわしい |
| menu.intro | ~~never **out of date with** the kitchen~~ → `always **matches** the kitchen` | 回りくどい |
| story body | ~~after the kitchen **quietens down**~~ → `after the kitchen **closes**` | 曖昧 |

### 17-5. 法務ページの確認

スペイン語版の監督官庁・準拠法が**フィンランドのまま**であることを機械的に検査:

```
tietosuoja.fi（フィンランド）   → 保持 ✅
AEPD / Agencia Española       → 本文に混入なし ✅
LSSI-CE（スペインCookie法）    → 本文に混入なし ✅
IMY（スウェーデン）            → 本文に混入なし ✅
```

（`AEPD` `IMY` `LSSI` の文字列は**「差し替えるな」という当方のコメント内**にのみ存在）

privacy は3言語とも**同一の8セクション構成**で一致していることも確認。

### 17-6. 再検証

| 項目 | 結果 |
|---|---|
| type-check / test | ✅ 6ワークスペース・11テスト |
| ビルド | ✅ 9ルート |
| 3言語レンダリング | ✅ 修正後の文言を実画面で確認 |
| 旧施設名の残存 | ✅ 0件（コメント内の記録を除く） |
| メッセージキー | ✅ 3言語とも36キーで一致 |

> ⚠️ 残る確認: **fi / es ともネイティブ校正は未実施**。
> 上記は文法・語法・固有名詞の明確な誤りを潰したもので、
> 「店の声として自然か」は最終的に先方（および es ネイティブ）の確認が要る。

---

## 18. 予約専用ページと Hero ボタン（2026-10-29 追記）

### 18-1. `/reserve` を新設

埋め込みフォームを**独立したページ**に移した（3言語 = 計3ルート追加、全12ルート）。

理由: 予約は**再訪ゲストが最初に求めるもの**であり、Instagram・Google・卓上QRから
直接リンクできる必要がある。メニューをスクロールさせてから辿り着かせるのは遅い。

ページ構成:
- 見出し＋説明文
- **予約条件を3枚のカードで先出し**（最大10名 / 即時確定 / 24時間前まで無料キャンセル）
  — ウィジェットを開かなくても判断できるように
- フォーム本体
- メールでの問い合わせ導線（電話は非掲載のため、大人数・アレルギー等の受け皿）

### 18-2. 二重埋め込みを避けた

Visit セクションの予約ブロックは**フォームを再度埋め込まず `/reserve` へリンク**する。
同一ページに iframe が2つあると**両方がロードされ、両方が height を post し**、
ゲストから見て「同じ予約の入口が2つ」になる。
**ページがフォームを持ち、セクションは誘導を持つ**という分担にした。
`AGENTS.md` にも明記。

### 18-3. Hero にボタンを追加

Hero のボタンを**3つ**に:

| ボタン | 形 | 遷移先 |
|---|---|---|
| **Varaa pöytä / Book a table / Reservar mesa** | **塗り（amber）** | `/reserve` |
| Menu | 枠線 | `#menu` |
| Löydä meidät / Visit / Visítanos | 枠線 | `#visit` |

**塗りは1つだけ**にした。3つとも塗ると主アクションが消える。
予約だけがこのページで「決める」行為であり、見出し（jää juomien takia）が
そもそも誘っている内容なので、予約を主に据えるのが自然。

ヘッダーにも `/reserve` へのリンクを追加（**実ルートなので法務ページからも機能する** —
`#menu` 等のアンカーはそれらのページでは存在しないセクションを指してしまう）。

### 18-4. 作業中に見つけて直した表示不具合

実機スクリーンショットで2件発見:

1. **モバイルで「VARAA FI」が繋がって見えた** — ヘッダーの予約リンクと言語切替が
   同じ `gap-5` の行に並び、390px で約4px しか離れていなかった。
   **区切りのヘアライン**を挿入して解決
2. **320px でスペイン語だと ES が画面外にはみ出した** — `RESERVAR` が長く、
   3言語コードと合わせて溢れていた。**360px 未満では予約リンクを非表示**に
   （Hero の塗りボタンがすぐ下にあるので失われるものは無い）

### 18-5. sitemap

`/reserve` を3言語分追加（優先度 0.9 / 0.7）。
**法務ページは意図的に不掲載** — `noindex` なので、クロールを誘って
拒否するページを載せる意味がない。

### 18-6. 検証

| 項目 | 結果 |
|---|---|
| type-check / test | ✅ 6ワークスペース・11テスト |
| ビルド | ✅ **12ルート**（3言語 × 本体・reserve・privacy・cookies） |
| `/reserve` 3言語 | ✅ すべて 200・各言語で正しく描画 |
| ウィジェット注入 | ✅ iframe **1つだけ**・`lang=fi` 自動判定 |
| ヘッダー/Hero 表示 | ✅ 1440 / 390 / 320px で確認 |

> ⚠️ **フォーム自体は allow-list 未登録のため現状リンク表示**（§15-2 のまま）。
> `embedAllowlisted` を true にする前に、必ず対象ドメインを
> `org_reservation_defaults.embed_allowed_domains` へ登録すること。

---

## 19. メキシコ要素の追加（2026-10-29 追記）

### 19-1. 結論: フリー素材は使わなかった

ご要望は「フリー素材でメキシコ要素を」だったが、**調査の結果それは採らない方が良い**と判断した。

理由: **ブランド自身が既にメキシコの語彙を持っていた**。
POS の storefront 画像を拡大して確認した結果:

| 要素 | 正体 |
|---|---|
| ロゴのマスコット | **縞模様のロバ** = ティファナの `burro cebra`（観光用にシマウマ塗装されたロバ。1930年代から続く実在の風物） |
| 食器 | **青白のタラベラ焼き**（プエブラの陶器）とティール釉の皿 |
| 色 | ライム、赤紫の漬け玉ねぎ |

一方、ストックの「メキシコ」画像はソンブレロ・サボテン・パペルピカド・
ドクロがほとんど。**今のダークで抑制の効いたデザインに載せると
「テーマレストラン」になり、作ったものを安っぽくする。**
加えて同じ画像が他サイトにも出る。

→ **ブランド固有の素材を使う方が、無料素材より強く、かつ固有**。

### 19-2. 実装 1: ブランドのロバ（`Burro.tsx`）

storefront コラージュから**アルファ付きPNGとして抽出**（`mascot-from-collage.py`）。
Story セクションに小さく配置。

抽出の技術的な要点:
- ワードマークは紺一色の上だったので輝度だけで抜けたが、**ロバは料理写真の上**。
  ライムや白い器の縁も明るいため輝度だけでは混入する
- マークは**白＝無彩色**なので、**輝度 × 低彩度**の2条件で키ーイング
- ⚠️ **初版はグレーの縁取りが出た**。RGBA のまま拡大すると、
  アルファ0の領域に残っていた料理写真の暗い画素が LANCZOS で
  エッジに混ざるため。**アルファのみ拡大 → RGBは白で塗る**順に修正

### 19-3. 実装 2: タラベラ模様の帯（`TalaveraBand.tsx`）

Story と Menu の境目に、**SVGで描いた**八芒星のタイル模様を配置。

画像を探さず描いた理由:
1. 約1KBのマークアップで済み、どの幅でも破綻しない
2. **自前のトークンから色を取る**ので、写真のタイルのように紺地と喧嘩しない
3. **ライセンス管理も帰属表示も不要**（飲食店のフッターにクレジットは不要）

⚠️ **実装中に踏んだ罠**: 最初 `viewBox="0 0 40 40"` + `slice` で
「パターンが横に繰り返す」と想定したが、**viewBox は座標系そのもの**なので
1タイルが1440pxに引き伸ばされ**巨大な塊の列**になった。
→ **viewBox を外す**ことで user unit = CSS px となり、40px ごとに正しくタイリング。
`AGENTS.md` に明記。

### 19-4. 意図的に入れなかったもの

ソンブレロ / サボテン / パペルピカド / カラベラ（ドクロ）/
明るい原色のストライプ。いずれも**ステレオタイプで、このデザインを壊す**。

### 19-5. 検証

| 項目 | 結果 |
|---|---|
| type-check / test | ✅ 6ワークスペース・18テスト |
| ビルド | ✅ 全ルート生成 |
| ロバのアルファ | ✅ RGB完全な白（縁取りなし）を数値で確認 |
| 帯のタイリング | ✅ 1440pxで正しく反復することを実画面で確認 |
| 追加容量 | burro.png **132KB** + 帯は約4KBのコード |

> 素材が欲しくなった場合に備えて: 要件は
> **商用利用可・帰属表示不要（CC0/PD推奨）・再配布可**。
> Unsplash/Pexels は帰属不要だが「同じ写真が他所にも出る」問題は残る。

---

## 20. バグ修正: `/reserve` から戻れない（2026-10-29）

### 20-1. 原因

ヘッダーのセクションリンクが**素の `#anchor` のまま**だった。

```
/reserve のヘッダー:
  Klandestina  -> #top     ← ページ内に存在しない
  Menu         -> #menu    ← 存在しない
  Löydä meidät -> #visit   ← 存在しない
```

`#top` `#menu` `#visit` は**トップページのセクション**。`/reserve`・`/privacy`・
`/cookies` にはその要素が無いため、**クリックしても何も起きないリンク**になっていた。
エラーも出ないので「ヘッダーは揃っているのに出口が無い」状態。

**§18-3 で「実ルートなので法務ページからも機能する」と書いたのは予約リンクだけの話で、
その隣のアンカーは直していなかった。** コメントが実態より広く読めてしまっていた。

### 20-2. 修正

`Nav.tsx` に `SectionLink` を追加し、**現在地で出し分け**る:

| 現在地 | 出力 | 挙動 |
|---|---|---|
| トップ | `#menu` | ページ内スクロール（`scroll-padding-top` が効く） |
| それ以外 | `/#menu` | トップへ遷移し、当該セクションへ着地 |

`usePathname()`（next-intl）は**ロケール接頭辞を除いたパス**を返すので
`=== '/'` の比較が全ロケールで正しい。これに伴い Nav は client component 化。

### 20-3. 検証（実ブラウザでクリック）

```
from /reserve     click "Menu"         -> /#menu     scrollY=1665
from /reserve     click "Löydä meidät" -> /#visit    scrollY=5486
from /privacy     click "Menu"         -> /#menu     scrollY=1665
from /es/reserve  click "Carta"        -> /es#menu   scrollY=1665
from /es/reserve  click "Visítanos"    -> /es#visit  scrollY=5525
logo from /reserve                     -> /#top
```

**遷移するだけでなく、正しいセクションまでスクロールする**ことと、
**ロケールが保持される**ことを確認。

モバイル（390px）はセクションリンクが非表示の設計だが、
**ロゴが表示されており、これが `/#top` へ遷移する**ので出口はある。
実機タップでも確認済み。

### 20-4. 再発防止

`AGENTS.md` に「ヘッダーのセクションリンクは素のアンカーにしない。
新しいリンクも必ず `SectionLink` を通す」と明記した。

### 20-5. 検証結果

| 項目 | 結果 |
|---|---|
| type-check | ✅ 6ワークスペース |
| test | ✅ 18テスト |
| build | ✅ 成功 |
| クリック動作 | ✅ fi/es・デスクトップ/モバイルで確認 |
