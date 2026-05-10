# 企業組織調査ガイド

フィンランド企業の組織構造を公開情報から調査する方法をまとめたガイドです。
MUJI Finland Oyの調査を実例として使用しています。

---

## 1. フィンランド商業登記

### YTJ (ytj.fi)
- **検索内容**: 会社名またはBusiness ID（Y-tunnus）
- **検索クエリ**: `"MUJI Finland Oy"` または `2971569-1`
- **取得できる情報**: 会社形態、登記住所、業種コード、設立日
- **URL**: https://www.ytj.fi/

### Asiakastieto (asiakastieto.fi)
- **検索内容**: 会社名
- **検索クエリ**: `MUJI Finland Oy`
- **取得できる情報**:
  - **取締役会**（hallitus） — 会長、取締役メンバーのフルネーム
  - **代表取締役**（toimitusjohtaja） — 登記上のMD
  - **財務データ** — 売上、従業員数、損益（年次決算報告書から）
  - **実質的支配者** — 最終的な所有構造
- **主要ページ**:
  - `/paattajat` — 意思決定者・取締役会メンバー
  - `/taloustiedot` — 財務情報
- **注意**: 一部データは有料サブスクリプションが必要

### Kauppalehti (kauppalehti.fi/yritykset)
- **検索内容**: 会社名またはY-tunnus
- **取得できる情報**: Asiakastietoと類似 — 財務概要、従業員数、売上推移
- **利点**: 基本的な財務データは無料でアクセス可能

### Finder.fi
- **検索内容**: 会社名
- **取得できる情報**: 連絡先、従業員数、売上、登記住所
- **利点**: シンプルなUIでクイック検索に最適

---

## 2. LinkedIn

### 会社ページ検索
- **検索内容**: LinkedIn検索で会社名 → 「企業」でフィルタ
- **検索クエリ**: `MUJI Finland Oy`
- **取得できる情報**: 公式会社ページ、LinkedIn上の従業員数、最近の投稿
- **URLパターン**: `linkedin.com/company/muji-finland-oy`

### 従業員検索
- **検索内容**: 「メンバー」でフィルタ → 「現在の勤務先」= 対象企業
- **検索クエリ**: `People who work at MUJI Finland Oy`
- **取得できる情報**:
  - 個人名、役職、在籍期間
  - 役職名から組織構造を推定可能
- **コツ**:
  - 関連度順にソートすると上級職が先に表示される
  - 「全X名の従業員を表示」で全リストを確認
  - 小売・飲食スタッフの多くはLinkedInプロフィールを持っていないため、カバー率は部分的（例: MUJI Finlandの場合、57名中約10名）

### 個人プロフィール検索
- **検索内容**: 人名 + 会社名
- **検索クエリ**: `"Miho Takagi" MUJI Finland`
- **取得できる情報**: 職歴、学歴、スキル、つながり

---

## 3. アグリゲーターサイト

### RocketReach (rocketreach.co)
- **検索内容**: 会社名 → "Management & Staff"
- **検索クエリ**: `MUJI Finland Oy management`
- **取得できる情報**: 従業員名、役職、メールアドレスのパターン
- **注意**: 無料アクセスは限定的。フルデータは有料

### The Org (theorg.com)
- **検索内容**: 会社名または親会社名
- **検索クエリ**: `MUJI Europe Holdings Limited`
- **取得できる情報**: 大規模組織（親会社・グループレベル）のビジュアル組織図
- **注意**: カバー率は企業や従業員がデータを提供しているかに依存

### Crunchbase (crunchbase.com)
- **検索内容**: 会社名
- **取得できる情報**: 資金調達情報、主要人物、親子会社関係
- **最適な用途**: テック企業やスタートアップ向け。小売子会社の情報は限定的

---

## 4. ニュース・プレス記事

### Google検索
- **検索クエリ例**:
  - `"MUJI Finland" managing director`
  - `"MUJI Finland" OR "MUJI Kamppi" interview`
  - `"MUJI Finland" site:linkedin.com`
  - `"高木美帆" MUJI Finland`（日本語名での検索）
- **取得できる情報**: インタビュー、プレスリリース、イベント記事から役職・担当業務が判明

### Googleニュース
- **検索クエリ**: `"MUJI Finland"` → ニュースでフィルタ
- **取得できる情報**: 企業活動、経営陣の異動、新店舗オープンに関する最近の記事

### 業界特化型メディア
- **例**: Enter Espoo (enterespoo.fi)、Varjo事例研究
- **検索内容**: 会社名 + 製品・サービスのキーワード
- **取得できる情報**: ケーススタディや特集記事にはキーパーソンの名前と役職が掲載されることが多い

---

## 5. ソーシャルメディア

### Instagram / Facebook
- **検索内容**: 企業公式アカウント（例: `@mujifinland`）
- **取得できる情報**: 投稿にタグ付けされたスタッフ、イベント報告、チーム写真
- **コツ**: 「舞台裏」や周年記念の投稿では、チームメンバーが名前と役職付きで紹介されることがある

### X (Twitter)
- **検索内容**: 会社名またはキーパーソンの名前
- **取得できる情報**: 公式発言、イベント参加情報、人脈関係

---

## 6. 政府・法的情報源

### PRH - フィンランド特許登録庁 (prh.fi)
- **検索内容**: Virreサービス（virre.prh.fi）で会社名を検索
- **取得できる情報**: 公式商業登記抄本 — 取締役会メンバー、MD、定款
- **注意**: 詳細な抄本は有料（通常、書類1件あたり数ユーロ）

### フィンランド金融監督庁
- **検索内容**: 上場企業または規制対象企業のみ該当
- **取得できる情報**: 年次報告書、株主開示情報

---

## まとめ: 調査フロー

| ステップ | 情報源 | 取得する情報 |
|---------|--------|-----------|
| 1 | YTJ / Asiakastieto | 基本会社情報、取締役会、MD、財務データ |
| 2 | LinkedIn（会社ページ） | 従業員数、会社概要 |
| 3 | LinkedIn（メンバー検索） | 個人の役職、部門構成 |
| 4 | RocketReach / The Org | 追加の人名、メールパターン、組織図 |
| 5 | Google検索 | インタビュー、プレス記事から役職を特定 |
| 6 | ソーシャルメディア | 非公式なチーム情報、イベント参加 |
| 7 | PRH / Virre | 登記官の公式確認 |

---

## 実例: MUJI Finland Oy

| 取得した情報 | 情報源 | 検索クエリ |
|------------|--------|-----------|
| 取締役会: 荒井正人, Karsenti, 高木美帆 | Asiakastieto `/paattajat` | `MUJI Finland Oy` |
| 従業員数: 57名 | Asiakastieto `/taloustiedot` | `MUJI Finland Oy` |
| MD: 高木美帆 | Enter Espoo記事、Varjo事例研究 | `"Miho Takagi" MUJI Finland` |
| 事業開発: 田熊聡子 | LinkedInプロフィール | `"Satoko Taguma" MUJI` |
| HR: Kirsi-Maria Kononow | LinkedInプロフィール | MUJI Finland Oyのメンバー検索 |
| VMD: Eiko Jarviluoma | LinkedInプロフィール | MUJI Finland Oyのメンバー検索 |
| マーケティング: Wilma Viertola | RocketReach | MUJI Finland management |

---

*最終更新: 2026-05-08*
