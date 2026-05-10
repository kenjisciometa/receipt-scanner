# 営業先の既存ベンダー — バトルカード

**作成日**: 2026年5月4日
**目的**: 営業先が使用中のPOS/テクノロジーとの比較。乗り換え/補完提案の根拠

---

## 総合マトリクス

| ベンダー | 使用先 | SciPOS最大の優位点 | 最も効果的なセールストーク |
|---------|-------|------------------|-------------------------|
| **SPARK EPoS** | YO! Sushi | コスト（無料 vs 有料）、BYOD | 「ロボットなしでも、POS機能はSciPOSのほうが安くて多機能」 |
| **NCR Aloha/NFS** | 丸亀うどん | コスト、決済自由、モダン設計 | 「旧式Alohaの決済ロックインから解放」 |
| **Yonoton** | Subway Finland | 圧倒的コスト差（年間€6-12万節約） | 「月額€500-1,000を無料に。会計連携も同等」 |
| **Restolution** | 市場リーダー | コスト、多言語、BYOD | 「40年の慣習より、コスト削減と多言語対応を」 |
| **Winpos** | Espresso House | セルフサービスの成熟度 | 「Winposのセルフサービスは"テスト中"。SciPOSは本番稼働中」 |
| **poscube** | MUJI Cafe&Meal | KDS/CDS/OSD統合、国際展開 | 「海外展開するなら日本限定のposcubeではなくSciPOS」 |
| **Slerp** | Tonkotsu | 補完関係（競合ではない） | 「店内はSciPOS、オンラインはSlerpの併用が最適」 |

---

## 1. SPARK EPoS（YO! Sushi）

| 項目 | SPARK | SciPOS | 優劣 |
|------|-------|--------|------|
| コアPOS | 有料（非公開） | **無料** | SciPOS |
| KDS | ○ | ○（無料） | SciPOS |
| キオスク | ○ | ○ | 同等 |
| ロボット連携 | **◎（15種類）** | × | SPARK |
| CRM/ロイヤリティ | ○ | △ | SPARK |
| 多言語 | △（英語中心） | **◎（12+）** | SciPOS |
| BYOD | × | **◎** | SciPOS |

**弱点**: 設立2019年・25名未満の小規模企業。ロボットのROI不透明。専用HW必須で高コスト。

---

## 2. NCR Aloha / NFS Hospitality（丸亀うどん）

| 項目 | Aloha | SciPOS | 優劣 |
|------|-------|--------|------|
| コアPOS | 高額（非公開） | **無料** | SciPOS |
| キオスク | △（GRUBBRR外部、2024年開始） | **◎（BOS自社開発）** | SciPOS |
| QRオーダー | △（サードパーティ依存） | **◎（TOS）** | SciPOS |
| オフライン | △（ネット依存高） | **◎** | SciPOS |
| 決済端末 | **×（NCRロックイン、2025年値上げ）** | ◎（Nets/SumUp自由選択） | SciPOS |
| 導入実績 | **◎（25年、大手多数）** | △ | Aloha |
| アレルゲン管理 | ○ | △ | Aloha |

**弱点**: サポート3-6日待ち。決済手数料ロックイン+一方的値上げ。旧式OS。ピーク時クラッシュ報告。不透明な請求。

---

## 3. Yonoton（Subway Finland）

| 項目 | Yonoton | SciPOS | 優劣 |
|------|---------|--------|------|
| コアPOS | **€500-1,000/月/店** | **無料** | SciPOS（圧倒的） |
| KDS | ○ | ○（無料） | SciPOS |
| キオスク | ○（NFC/RFID対応） | ○ | 同等 |
| テーブルオーダー | △ | **◎（TOS）** | SciPOS |
| ブランドアプリ | **◎** | × | Yonoton |
| ウェブショップ | **◎** | × | Yonoton |
| 多言語 | △（北欧中心） | **◎（12+）** | SciPOS |
| BYOD | △ | **◎** | SciPOS |

**弱点**: 高コスト（10店舗で年間€60,000-120,000）。北欧市場限定。国際展開実績なし。

**顧客**: Subway（北欧400店）、Night People Group（25店）、Juvenes（58店）

---

## 4. Restolution（フィンランド市場リーダー）

| 項目 | Restolution | SciPOS | 優劣 |
|------|-----------|--------|------|
| コアPOS | 有料（非公開） | **無料** | SciPOS |
| セルフキオスク | ○（RestoSelfi） | ○（BOS/Self Station） | 同等 |
| テーブルオーダー | ○（RestoHost） | ○（TOS） | 同等 |
| Procountor連携 | **◎（深い統合）** | ○ | Restolution |
| BYOD | △（RestoHostのみ） | **◎** | SciPOS |
| 多言語 | 5言語 | **◎（12+）** | SciPOS |
| 市場シェア | **◎（4,000+店舗）** | △ | Restolution |

**弱点**: 40年のレガシーUI。専用HW依存（RestoSmart）。料金不透明。国際展開5言語のみ。

**選ばれる理由**: 40年の信頼、フィンランド語ネイティブ、Kespro連携、周囲の使用実績。

---

## 5. Winpos（Espresso House）

| 項目 | Winpos | SciPOS | 優劣 |
|------|--------|--------|------|
| コアPOS | 有料（非公開） | **無料** | SciPOS |
| セルフサービス | **△（テスト中）** | **◎（本番稼働）** | SciPOS |
| 多国籍一元管理 | **◎（5カ国統一DB）** | ○ | Winpos |
| ロイヤリティ | **◎** | △ | Winpos |
| BYOD | △ | **◎** | SciPOS |

**弱点**: セルフサービスが未成熟（テスト段階）。料金非公開。カフェ・QSR特化。

---

## 6. poscube（MUJI Cafe&Meal）

| 項目 | poscube | SciPOS | 優劣 |
|------|---------|--------|------|
| コアPOS | 月額¥5,980〜 | **無料** | SciPOS |
| KDS | △（プリンター中心） | **◎（ディスプレイ）** | SciPOS |
| セルフキオスク | × | **◎（BOS/Self Station）** | SciPOS |
| CDS/OSD | × | **◎（無料）** | SciPOS |
| 多言語 | △（日本語中心） | **◎（12+）** | SciPOS |
| 国際展開 | **×（日本限定）** | **◎** | SciPOS |
| 複雑なメニュー | **◎** | ○ | poscube |

**弱点**: KDS未成熟。キオスクなし。日本限定で海外展開不可。iPad限定。CDS/OSDなし。

---

## 7. Slerp（Tonkotsu — オンライン注文）

| 観点 | Slerp | SciPOS |
|------|-------|--------|
| 店内POS | × | **◎** |
| KDS | × | **◎** |
| オンライン注文 | **◎** | × |
| デリバリー管理 | **◎** | × |
| テーブルQR注文 | ○ | **◎（TOS）** |
| キオスク | × | **◎（BOS）** |

**関係**: 競合ではなく**補完**。店内はSciPOS、オンラインはSlerpの併用が最適。

---

## 営業時に質問されるリスク（全ベンダー共通）

| 質問 | 回答案 |
|------|--------|
| 「オンライン注文/デリバリーは？」 | 「現在開発中。当面はSlerp/Deliverect等との併用を推奨」 |
| 「ブランドアプリは作れる？」 | 「現時点では非対応。QRオーダーで同等の体験を提供」 |
| 「ロイヤリティプログラムは？」 | 「基本機能あり。高度なCRMは将来的に拡充予定」 |
| 「400店舗級の実績は？」 | 「大規模チェーンでの実績は構築中。まずPoCで効果を実証」 |
| 「予約管理は？」 | 「基本的な予約機能あり。OpenTable等との連携も検討中」 |

---

## 出典

- [SPARK EPoS](https://sparkepos.com/) / [SPARK Robotics Blog](https://blog.sparkepos.com/)
- [NFS Hospitality - Marugame Case Study](https://www.nfs-hospitality.com/case-studies/marugame-udon/)
- [Yonoton](https://yonoton.com/)
- [Restolution](https://restolution.eu/en/)
- [Winpos](https://winpos.com/en/)
- [poscube](https://pos-cube.com/) / [poscube 良品計画事例](https://pos-cube.com/results/ryouhinkeikaku/)
- [Slerp](https://www.slerp.com/)
