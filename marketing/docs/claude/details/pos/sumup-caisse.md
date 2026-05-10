# SumUp Caisse（旧Tiller）

> **調査日**: 2026-04-23
> **カテゴリ**: pos
> **調査ステータス**: ✅詳細調査済

---

## 基本情報

| 項目 | 内容 |
|------|------|
| 会社名 | SumUp Payments Ltd（英国法人）／旧：Tiller Systems SA（仏） |
| プロダクト名 | SumUp Caisse（旧Tiller）、SumUp POS Pro（欧州向け旧ブランド）、SumUp Caisse Lite / Caisse Pro |
| 本社所在地 | ロンドン、英国（欧州本部）；Tiller本体: パリ、フランス |
| Tiller設立年 | 2014年3月（創業者: Josef Bovet、Scott Gordon、Dimitri Farber、Vincent Oliveira） |
| SumUp買収 | 2021年2月3日 |
| 従業員規模 | 旧Tiller: 167名（買収時）；SumUp全体: 3,000名以上 |
| 資金調達 | Tiller単体: 累計$18.6M（Series A: €4.5M / 2016年、Series B: $13.9M / 2018年）；SumUp全体: 累計€1.5B以上 |
| 主な展開地域 | フランス（主力）、欧州30カ国以上（SumUpグループとして） |
| 顧客数 | 不明（SumUp全体では400万件以上の加盟店） |

### 買収経緯
SumUpは2021年2月にパリのTiller Systemsを買収（価格非公開）。翌月には英国のGoodtillも買収し、欧州POS市場への本格参入を完了。TillerはSumUpのPOS部門として「SumUp POS Pro」として統合。フランス市場ではブランド認知のため一時期「Tiller by SumUp」として展開、現在は「SumUp Caisse」に統一されつつある。

---

## 料金体系

| 項目 | 内容 |
|------|------|
| Caisse Lite | 月額€0（ハードウェアコストのみ）。基本機能のみ |
| Caisse Pro | カスタム見積もり。参考値: €79/月以上（1年・3年・5年契約） |
| 決済手数料（通常） | 1.75%/取引 |
| SumUp One（オプション） | €19/月＋0.79%/取引（低ボリューム向け） or 0.99%（別プランあり） |
| ハードウェア | Solo Lite: €34、Solo: €79、Terminal（一体型プリンタ内蔵）: €169 |
| 契約期間 | 1年・3年・5年の選択制 |
| 無料プラン | SumUp Caisse Lite（機能制限あり） |
| トライアル | 不明 |

---

## ターゲット市場

| 項目 | 内容 |
|------|------|
| 対応業態 | フルサービスレストラン、ファストフード、ピッツェリア、フードトラック、カフェ、バー、小売店 |
| 対象規模 | 個人店〜マルチロケーション |
| 主要地域 | フランス（Tiller遺産）＋SumUpグループとして欧州30カ国以上 |

---

## 機能比較

| 機能 | 対応状況 | 備考 |
|------|---------|------|
| POS レジ機能 | ✅ | iPad型NF525認証済み。全決済方式対応（カード・現金・小切手・非接触・Apple Pay・Google Pay） |
| セルフオーダー（キオスク） | ✅（連携） | AppMarket経由のパートナー連携 |
| セルフオーダー（テーブル/QR） | 部分対応 | Click & CollectはPulpとの連携 |
| KDS（キッチンディスプレイ） | ✅ | キッチンディスプレイシステム統合 |
| 在庫管理 | ✅ | 在庫追跡、閾値アラート |
| シフト・勤怠管理 | ✅（連携） | AppMarket経由でシフト・HR管理ツール連携 |
| 予約管理 | ✅ | 予約管理機能対応 |
| CRM / ロイヤルティ | ✅ | ロイヤルティプログラム、顧客データベース |
| デリバリー連携 | ✅ | Deliverect経由（Uber Eats・Deliveroo・Just Eat等を一元管理） |
| Click & Collect | ✅ | Pulp連携でClick & Collect管理 |
| 会計ソフト連携 | ✅ | AppMarket経由で会計ソフト連携 |
| レポート・分析 | ✅ | 売上・取引・顧客・バスケット分析、商品TOP/FLOPレポート、スタッフ分析。iPad/PC/モバイルでアクセス |
| テーブル管理 | ✅ | 2D/3D テーブルレイアウト管理 |
| 多言語対応 | ✅ | 複数言語対応（SumUpグループ内） |
| オフライン対応 | 不明 | 基本はクラウドベース |
| AI / 自動化機能 | 部分対応 | AppMarket拡張による自動化対応 |
| AppMarket | ✅ | サードパーティ連携マーケットプレイス（独自エコシステム） |

---

## ハードウェアモデル

| 項目 | 内容 |
|------|------|
| デバイス | iPad（Tiller遺産の主力） |
| SumUp決済端末 | Solo Lite（€34）、Solo（€79）、Terminal（€169・プリンタ一体型） |
| プリンタ | Terminal内蔵またはBluetooth接続レシートプリンタ |
| BYOD | iPad対応 |
| 統合モデル | SumUp決済端末＋Tillerソフトウェアの完全統合が最大の強み |

---

## 認証・コンプライアンス

| 項目 | 内容 |
|------|------|
| NF525認証 | 取得済み（Tiller 3 - v11で更新）。フランス財務省要件準拠 |

---

## 強み / 弱み（SciometaPOS との比較視点）

### 強み
- **決済端末＋POSの完全統合**: SumUpハードウェアとTillerソフトウェアが1プロバイダーに統合。他社比でシンプルな調達・管理
- SumUpグループの強力な財務基盤（累計€1.5B調達）と30カ国展開
- AppMarketによる柔軟な拡張性（シフト・会計・デリバリー等を任意追加）
- 透明なハードウェア価格（€34〜€169）
- Trustpilot 4.0/5（35,000件以上レビュー）の高いブランド信頼度
- Caisse Liteによる低コスト入門
- Deliverect統合によるデリバリープラットフォーム一元管理

### 弱み
- ソフトウェア価格の不透明さ（要見積もり、長期契約必須）
- サポートが平日9〜18時のみ（電話なし、チャット・メールのみ）
- 頻繁なアップデートによる偶発的バグ報告
- 請求明細への不満の声あり
- キオスク・セルフオーダーはネイティブ非対応（パートナー経由）
- SumUpとTillerのブランド統合が混乱を招くケースあり

### SciometaPOSとの差分
- SciometaPOSはアジア・日本市場向け統合プラットフォーム（POS＋セルフオーダー＋シフト管理ネイティブ統合）。SumUp CaisseはフランスCHR市場に強みを持つが、アジア市場・日本語対応・ネイティブシフト管理・セルフオーダー統合においてSciometaPOSが優位。SumUpは「決済端末＋POS」の統合モデルという独自のバリュープロポジションを持つ。

---

## 最近の動向（直近1年）

- **2025年2月〜**: フランス財務法2025年施行に対応し、NF525認証を更新（Tiller 3 v11）。2026年3月以降の義務化に先行対応
- **Deliverect統合強化**: デリバリープラットフォーム連携をDeliverect経由で一元化
- **SumUp Caisse統一**: 「SumUp POS Pro」「Tiller by SumUp」の複数ブランドを「SumUp Caisse」に統一中
- **AppMarket拡充**: パートナーアプリを継続的に追加、エコシステム拡充
- **SumUp全社**: 2025年通年売上$423.3M（Tiller by SumUp含む）。欧州フィンテック大手としての地位を維持

---

## 参考リンク

- 公式サイト（Tiller）: https://www.tillersystems.com/en/
- SumUp買収プレスリリース: https://www.sumup.com/fr-fr/press/sumup-acquiert-le-francais-tiller/
- Tiller Wikipedia: https://en.wikipedia.org/wiki/Tiller_Systems_(software)
- Crunchbase（Tiller）: https://www.crunchbase.com/organization/tiller-systems
- 料金ページ: https://www.sumup.com/en-us/pos/sumup-pos/pricing/
