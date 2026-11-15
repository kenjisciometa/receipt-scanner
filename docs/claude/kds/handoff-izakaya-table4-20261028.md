# 引き継ぎ：Izakaya Taro Table 4 「KDSに1品しか通らなかった」調査

作成日：2026-10-28
前セッションの担当範囲：DB調査・KDSクライアント側コード調査
**このセッションでやること：WebSocket サーバー側ログの確認（13:30〜13:51 の切断有無）**

---

## 1. 事象（現場からの報告）

Izakaya Taro の Table 4 で、Hakata Ramen 2点・Onigiri 1点・ドリンク2点の注文が入ったが、
**キッチンディスプレイには Hakata Ramen 1点しか表示されなかった**。

報告者の見解（有力）：
- 「1つめのオーダーしか届かなかった」
- 画面右上の **Mark All Order Ready アイコンがグレー**だった

---

## 2. 確定している事実（DB実データ）

### 対象レコード

| 項目 | 値 |
|---|---|
| Supabase project | `mcldujatysqrzsdjxpof` (Sciometa POS Project) |
| organization_id | `792d7ebb-a398-4ba9-a7c6-b2063b0ec9ce` (Fukuoka style OÜ) |
| store_id | `bb3a76c7-51ac-4d3d-be8a-07df12d55e7b` (Izakaya Taro Vanalinn) |
| order_id | `720b5332-6088-49f0-a686-ff7731190216` |
| order_number | `TOS-ORD-0001` |
| table_number | 4 |
| source | `tos` |
| 注文時刻 | 2026-10-28 13:24:01 UTC |
| 現在の status | `cancelled`（14:09:06 に取消） |

### order_items の実データ（全7件・欠落なし）

| 品目 | seq | display_status | ready_at (UTC) | created_at (UTC) |
|---|---|---|---|---|
| Hakata Ramen ① | 1 | ready | **13:30:25.223139** | 13:24:01.207508 |
| Homemade Virgin Mojito | 1 | pending | null | 13:24:01.207508 |
| Hakata Ramen ② | 2 | ready | **13:51:28.618728** | 13:24:03.647261 |
| Homemade Yuzu Soda | 2 | pending | null | 13:24:03.647261 |
| Onigiri | 2 | ready | **13:51:28.618728** | 13:24:03.647261 |
| Matcha Ice Cream | 3 | pending | null | 13:51:10.685268 |
| Matcha Ice Cream | 4 | pending | null | 13:51:14.946855 |

**重要な点：**
- データ欠落は一切ない。全品サーバーに保存されている
- ラーメン2杯の**注文時刻差は2秒**（13:24:01 と 13:24:03）。追加注文ではなく、カート送信が2リクエストに分割され seq 1 / seq 2 に採番されたもの
- **21分の差は ready_at（完了ボタンを押した時刻）の差**であり、注文時刻の差ではない
- seq 2 のラーメンとおにぎりの ready_at が**マイクロ秒まで完全一致** → 1回の一括完了書き込み
- 抹茶アイス（seq 3/4, 13:51:10〜14）は本物の追加注文。その**18秒後**に seq 2 が完了されている

### ドリンク2点が表示されないのは正常（設計通り）

display_category_presets `f843e3c4-bd56-4d9b-8fd4-a88343886988`「Food Only (Izakaya Taro)」の
`excluded_category_ids` に `Soft Drinks`(`1cfd28d9-9ac3-46d7-b0ee-3fe0ae6419b0`) が含まれる。
除外カテゴリの品は「+N hidden」のバッジ件数としてしか返らない。
→ Virgin Mojito / Yuzu Soda は**意図通り非表示**。調査対象外。

なおこのプリセットは `table_grouping_enabled = true` / `window = 5分`。

---

## 3. 「Mark All Ready がグレー」の正しい意味（前セッションで判明）

報告者は「グレー = WebSocket 不通のサイン」と解釈していたが、**これは誤り**。

`order_sys/kds/flutter_app/lib/screens/order_display_screen.dart:989-996`

```dart
IconButton(
  onPressed: _activeOrders.isEmpty ? null : _showCompleteAllConfirmation,
  icon: const Icon(Icons.done_all),
  tooltip: 'Mark All Ready',
  color: _activeOrders.isEmpty ? Colors.grey : Colors.green,
)
```

色を決めるのは `_activeOrders.isEmpty` **のみ**。通信状態は参照していない。
- 緑 = 未完了の注文が1件以上ある
- グレー = **画面に表示されている未完了注文が0件**

### ただし、これは別の意味で不通の証拠になる

グレー = KDS 画面は「0件」と表示していた。
一方サーバー上では 13:30〜13:51 の間、**seq 2（ラーメン②＋おにぎり）は pending で存在していた**。

> サーバーに未完了注文があるのに、KDS 画面は0件だった
> = 受信できていなかった状態と整合する

**よって報告者の「不通だった」という仮説自体は有力。アイコンの読み方だけが誤り。**

### 付随して判明した設計上の欠陥

接続インジケータ `lib/widgets/connection_status_bar.dart` は実装済み
（緑=`Icons.wifi` / 橙=接続中 / 赤=`wifi_off`）だが、
使用箇所は `lib/screens/analytics_dashboard_screen.dart:81` の**アナリティクス画面だけ**。

**キッチンが見る注文表示画面（order_display_screen.dart）には接続表示が無い。**
→ 切断に気づく手段がない。今回の件の再発防止に直結する最優先の修正候補。

---

## 4. 前セッションで出した推論の訂正履歴（重要・再度踏まないため）

| 回 | 述べた内容 | 現在の評価 |
|---|---|---|
| 1回目 | 「seq 1→2→3/4 の4回に分かれた追加注文」 | **誤り**。seq 1/2 は2秒差で同一カートの分割。追加は seq 3/4 のみ |
| 2回目 | 「13:30 に seq 2 を見落とし、21分後に気づいて完了した運用ミス」 | **可能性は残るが根拠不足**。再接続でまとめて届いた説のほうが自然 |
| 2回目 | 「14:15 の Table 1 で seq 1+2 がまとまって完了 → 表示側は正常」 | **取り下げ済み**。14:15 は不通時間帯の後。13:30 時点の正常性の証明にならない |

---

## 5. このセッションでの調査タスク

### 目的
**2026-10-28 13:30〜13:51 UTC に、Izakaya Taro の KDS 端末が WebSocket から切断されていたかを確認する。**

切断が確認できれば原因確定。確認できなければ運用ミス説に戻る。

### 対象サーバー

`websocket-server/`（`unified-websocket-server`）
- 本番エントリポイント：`src/server.js`
- コンテナ名：`websocket-server-prod`（`docker-compose.prod.yml`）
- ログ出力：`./logs` をボリュームマウント（`LOG_MAX_SIZE=50`, `LOG_MAX_FILES=10`）
- Docker ログも `json-file` / `max-size: 50m` で保持

### grep すべきログ形式（src/server.js で確認済み）

```
[DISCONNECT] <socket.id> (<deviceType>) - Reason: <reason>
[STANDARD-PING-TIMEOUT] <socket.id> (<deviceType>) - Connection lost due to ping timeout
```

ping タイムアウトは `[STANDARD-PING-TIMEOUT]`、通常切断は `[DISCONNECT]` と**別の行**に出る。両方見ること。

認証時のログに store が出るので、端末特定に使える：
```
[SDS] Device authenticated: store=<storeId>, device=<deviceId>, room=store_<storeId>, ...
```

room 名は `store_bb3a76c7-51ac-4d3d-be8a-07df12d55e7b`。

### 確認手順（案）

1. 本番サーバーにアクセスし `websocket-server/logs/` を確認
2. 2026-10-28 13:20〜14:00 UTC の範囲を抽出
   - **タイムゾーン注意**：DB の値は全て UTC。ログ側が現地時間（EET/EEST, UTC+2/+3）の可能性があるため確認必須
3. `store_bb3a76c7-...` の room に属する端末の
   `[DISCONNECT]` / `[STANDARD-PING-TIMEOUT]` / 再接続（authenticated）を時系列で並べる
4. 13:30:25（ラーメン①完了）の直後〜13:51:10（抹茶アイス投入）の間に切断があるかを判定

### 判定基準

| ログの内容 | 結論 |
|---|---|
| 13:30 直後に切断、13:51 前後に再接続 | **原因確定**。不通により seq 2 が届かず、復帰時にまとめて表示・完了された |
| 当該時間帯に切断なし | 不通説は否定。表示側の不具合か運用ミスの再調査へ |
| ログが残っていない／ローテート済み | 断定不可。接続インジケータ追加＋ログ保全を先に実施 |

### 補助的な確認先

- `/health` および `/health/ready` エンドポイント（監視側がスクレイプしている場合は履歴があるかも）
- `monitoring-integrated/` ディレクトリ（メトリクス保存の有無を確認する価値あり）
- 端末側 Flutter ログ：`_isConnected` の遷移が debugPrint に出る
  （`lib/services/kds_websocket_service.dart:315`）。端末が手元にあれば有力

---

## 5.5 【解決済】真因と実施した修正（2026-10-28 追記）

### 真因

WebSocket の切断ではなかった。**サーバーの重複排除が orderId のみをキーにしており、
TOS の分割送信の2回目を「重複」と誤判定して破棄していた。**

```
13:24:01.650Z ✅ Order create broadcasted successfully   ← seq 1 は配信
13:24:04.103Z ⏭️ Duplicate pos_order_create for 720b5332…
              (2452ms since last) - skipping broadcast   ← seq 2 は破棄
```

当該KDSは 12:48:15Z 接続〜14:27 まで同一ソケットで、`[DISCONNECT]` も
`[STANDARD-PING-TIMEOUT]` も出ていない。13:2x〜13:5x に切断を繰り返していたのは
TOS 端末（客側タブレット）であって KDS ではない。

**節4の「不通説」および節3の「不通の証拠になる」という記述は誤りだったため取り下げる。**
「サーバーに未完了注文があるのに KDS は0件」の状態は、通知が届かなかったことで説明がつく。

### 実施した修正（websocket-server）

重複排除のキーを `orderId` から **(store, order, batch)** に変更。
`batch` は item 集合のダイジェストで、分割バッチと再送を区別する。

- `src/server.js` — `_orderCreateDedupKey()` / `_orderBatchFingerprint()` を追加し、
  **POS と BOS の両呼び出し箇所**に適用（BOS 側も同じ Map を共用しており同一欠陥があった）
- `src/test/order-create-dedup-test.js` — 回帰テスト15件（`npm run test:order-dedup`）

**source（送信元デバイス）では区別できない。** 今回の分割2件は同一ソース
（`reactpos_api_<store>`）から 2452ms 間隔で届いており、これは再送と見分けがつかない。
実際に異なるのは payload の item 集合であり、そこをキーにした。

store をキーに含めたのは、BOS 経路が `orderNumber` にフォールバックし、
注文番号が店舗ごと日次でリセットされるため（別店舗の `ORD-0004` が相互にマスクし得る）。

### 残っている制約（重要）

**item を持たない payload は `noitems` という単一バケットを共有する。**
REST 経路（`serverNotifier.ts`）は item 配列を送らないため、
**itemless な分割送信が3秒以内に2回来た場合、2回目は依然として破棄される。**

このバケットを device 別にしない理由は、そうすると全ソースが別キーになり
本来の cross-source 重複排除が全く効かなくなるため。トレードオフとして受容した。
テストに `LIMITATION:` として明示的にアサートしてある。

**恒久対応は TOS 側**で、分割の2回目を `order_created` ではなく
「注文の更新」として送ること。サーバー修正は実害の大半を止めるが完全ではない。

### 未実施（要判断）

- **過去8件の照合**：10/21〜10/28 に重複破棄されたTOS注文のうち、
  1.3〜2.6秒間隔の8件（10/21 14:09、10/22 13:50、10/23 17:11、10/25 16:46、
  10/27 15:44、10/27 16:50、10/28 13:24）。実際に取りこぼしが起きたかDB照合が必要
- **KDS 側のポーリング保険**：現状 `PURE WEBSOCKET MODE` で再取得が一切無く
  （`order_display_screen.dart:450`、5秒タイマーは時刻再描画のみ）、
  取りこぼしの自己回復手段がゼロ。設計判断のため要相談
- **デプロイ**：本修正は未デプロイ

---

## 6. 本調査とは独立した既知バグ（今回の原因ではないが要修正）

### (A) POS 経由注文の display_status が null → キッチンに永久に出ない【実害大】

同じ Table 4 で 14:09 に作られた `ORD-0004-1/2` / `ORD-0004-2/2`
（order_id `b18ef27b-95b4-4931-937b-1bd00af04afb` / `f9cfafc5-eced-44d4-82d7-95a5e43f6720`）は、
**全7品の `display_status` が `null`**。

KDS API は `display_status->>status = 'pending'` の**完全一致**で絞り込む
（`ReactRestaurantPOS/src/app/api/kds/orders/route.ts:192-198`）ため、
`null` は `'pending'` に合致せず**1品も返らない**。

> 会計時に POS で注文を切り直すと、その品目は KDS に二度と出てこない

今回は取消前に調理完了していたため実害なし。**調理前に同じ操作をすると注文が無言で消える。**
修正方針は未決（null を pending 扱いにする／POS 作成経路で初期化する）。
前者は既存データも救済できるが、`served` 済みの古い注文を蘇らせない確認が必要。

### (B) グルーピング設定が端末再選択まで反映されない

`table_grouping_enabled` はサーバープリセットを端末の SharedPreferences にコピーして使う。
同期は `lib/services/auth_service.dart:339-341` の `selectDisplay()`、
つまり**ディスプレイを選択した時だけ**。
`lib/services/order_processing_service.dart:213` は常にローカル値を読む。

> 管理画面で設定を変更しても、KDS 端末でディスプレイを選び直すまで反映されない

### (C) 注文表示画面に接続インジケータが無い【最優先】

上記 3 節の通り。既存 `ConnectionStatusBar` を `order_display_screen.dart` に
マウントするだけで済む。今回の件の再発防止に直結。

---

## 7. 関連ファイル索引

| 役割 | パス |
|---|---|
| KDS アプリ（Flutter） | `order_sys/kds/flutter_app/` |
| Mark All Ready ボタン | `order_sys/kds/flutter_app/lib/screens/order_display_screen.dart:989` |
| 接続インジケータ（未使用） | `order_sys/kds/flutter_app/lib/widgets/connection_status_bar.dart` |
| WebSocket クライアント | `order_sys/kds/flutter_app/lib/services/kds_websocket_service.dart` |
| グルーピング処理 | `order_sys/kds/flutter_app/lib/services/order_processing_service.dart:212` |
| プリセット同期 | `order_sys/kds/flutter_app/lib/services/auth_service.dart:339` |
| KDS API（絞り込み） | `ReactRestaurantPOS/src/app/api/kds/orders/route.ts` |
| WebSocket サーバー | `websocket-server/src/server.js` |
| 本番構成 | `websocket-server/docker-compose.prod.yml` |

注：`ReactRestaurantPOS` に稼働中の KDS 画面は存在しない（`DemoKDS.tsx` はデモ用）。
キッチンが見ているのは Flutter アプリ。
