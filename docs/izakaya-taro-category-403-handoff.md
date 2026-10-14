# 引き継ぎ：Izakaya Taro Manager のカテゴリ 403 調査

## 問い合わせ内容（原文）

> 居酒屋のカテゴリーですがホットドリンクが表示されなくなっています。
> カテゴリのところでアクティブにしようとしても変更する権限がないと言うエラーが出ます。
> You do not have permission to perform this operation と表示されています。

## 対象

| 項目 | 値 |
|---|---|
| 対象ユーザー | `motokiohata13@gmail.com` / user_id `cfd52cd9-7292-40b8-9f7e-2868b7053567` |
| 組織 | Taro Group / `792d7ebb-a398-4ba9-a7c6-b2063b0ec9ce` |
| 店舗 | Izakaya Taro Vanalinn / `bb3a76c7-51ac-4d3d-be8a-07df12d55e7b` |
| カテゴリ | Hot Drinks / `6632a478-52cd-4930-8062-5f1a144cc8b4` |
| クライアント | FlutterPOS **1.1.8** (Windows, 日曜ビルド) |
| 本番サーバー | **`stage` ブランチ**（`main` ではない）/ HEAD `f8dd178d` |
| Supabase | `mcldujatysqrzsdjxpof` |

## 確認済みの事実（コード・DB で検証済み）

1. **権限データは正しい。** `users.role = manager`、`user_store_roles.role = manager` @ Izakaya Taro Vanalinn、担当・店舗ともに `is_active = true`。Manager は `settings.write` を保持（`ReactRestaurantPOS/src/app/api/shared/rbac-capabilities.ts:245`）。

2. **表示が消えた直接原因（判明済み・権限とは別問題）。** Hot Drinks の `category_availability.active_in_pos = false`（Izakaya Taro Vanalinn の行 `6b12d529-f15f-4104-9114-737f9e49d752`）。組織側の `categories.is_active` は `true`。

3. **画面の店舗ドロップダウンは「Izakaya Taro Vanalinn」を表示していた**（利用者確認済み）。→ スコープは店舗で正しい。

4. **本番(stage)の列単位ゲート。** `categories` の `is_active` / `active_in_bos` / `active_in_web` / `deleted_at` は `settings.write.organization`（**Owner 限定**）を要求（`rbac-capabilities.ts:613-622`）。`active_in_pos` は `settings.write` で足りる（Manager 可）。

5. **サーバーは無変更の列を見逃す設計。** `missingCapabilitiesForSettingsUpdate` が `sameSettingValue(value, existing[column])` で既存値と比較し、一致する列は無視する。

6. **Hot Drinks の現在値**: `is_active: true` / `active_in_bos: null` / `active_in_web: true` / `deleted_at: null`。

7. **1.1.8 のクライアント実装は正しい。** 店舗スコープなら `active_in_pos` のみ送信（`bos_category_availability_provider.dart:156`）。スコープ確定の修正3件（`68aff4158` / `3b83aefa5` / `2186db906`, 10/2）はすべて 1.1.8 に含まれる。

8. **編集ダイアログに権限ガードが無い（未修正・1.1.9 でも残存）。** `categories_section.dart:1198-1215` の `active_in_web` スイッチ（地球アイコン、`SwitchListTile`）は Manager にもそのまま表示・操作可能。該当ダイアログ範囲（900-1300行）に `canEditOrgDefault` は **0 箇所**。`Category.toJson()`（`lib/domain/entities/category.dart`）は `is_active` / `active_in_web` / `deleted_at` を**常に送る**。

## 未確定：403 の発生経路

この画面には「アクティブ」に見える操作が2つある。

| | 場所 | 書込先 | Manager |
|---|---|---|---|
| **A** | カテゴリ一覧の行のトグルスイッチ | `active_in_pos`（当該店舗のみ） | ✅ 通る |
| **B** | 鉛筆アイコン → 編集ダイアログ内のスイッチ | `active_in_web`（組織全体） | ❌ 403 |

**A なら成功するはずなのに 403 が出ている。** 事実3でスコープは正しいと確認済みのため、A では 403 を説明できない。そこで「利用者は B を操作したのではないか」という**仮説**を立てたが、**裏付けは取れていない**。利用者がどのボタンを押したかはコードからは判別不能。

A 経路でも 403 になる未知の経路が存在しない、とも言い切れていない。

## サーバーログで確認したいこと

本番(stage)は拒否した列名を返している（`src/app/api/categories/route.ts:407-411`）：

```js
{ success: false, error: 'Forbidden', missing: [{ capability, columns }] }
```

Flutter 側が `api_client_service.dart:788` で全 403 を定型文に潰しているため画面からは判別不能。**サーバーログの `missing` を見れば確定する。**

### 判定表

| ログの内容 | 結論 | 次の対応 |
|---|---|---|
| `missing` に **`active_in_web`** | B が原因（仮説が当たり） | 修正案1へ |
| `missing` に **`is_active`** | A 経路が組織スコープに書いている。スコープ確定にまだ穴がある | `categories_section.dart:186-215` の再調査 |
| `PUT /api/categories` の 403 が**無い** / `category-availabilities` 側で 403 | 原因は別経路。RLS も含めて再調査 | 下記「RLS の注意点」参照 |

### 検索条件

- 期間: 問い合わせ受領前後（今日 2026-10-06 およびその前日）
- エンドポイント: `PUT /api/categories` および `PUT /api/category-availabilities`
- ステータス: 403
- user_id: `cfd52cd9-7292-40b8-9f7e-2868b7053567`
- 併せて `🚫 Permission denied` / `Forbidden` の文字列

### RLS の注意点

`categories` の RLS は**組織一致のみで role を見ない**:

```sql
organization_id IN (SELECT organization_id FROM users WHERE id = auth.uid())
```

この Manager の組織とカテゴリの組織は一致するため、**RLS は 403 の原因になり得ない**。403 は必ず API 層（capability ゲート）から来る。

## 修正案（ログ確認後に着手）

1. **編集ダイアログの `active_in_web` を Manager に出さない** — `categories_section.dart:1198` を `if (canEditOrgDefault)` で囲む。一覧のドロップダウンが Organization Default を隠しているのと同じ扱い。小さく、すぐ出せる。
2. **`toJson` が無変更の Owner 専用列を送らないようにする** — 根本側。現状は「送ってみて拒否される」設計で、サーバーの値比較に救われているだけ。
3. **403 のメッセージにサーバーの `missing` を表示する** — `api_client_service.dart:788`。今回の切り分けに何往復も要した直接の原因。

## 即時復旧（原因特定と独立に実施可能）

Hot Drinks の表示を戻すには、Izakaya Taro Vanalinn の `active_in_pos` を `true` にする。

- 推奨: Owner アカウント（`s.takakura555@gmail.com` 等）で POS の店舗スコープから ON にする
- DB 直接更新も可能だが、対象行を確認してから実行すること:
  ```sql
  -- 対象確認
  select id, active_in_pos from category_availability
  where id = '6b12d529-f15f-4104-9114-737f9e49d752';
  ```

## 注意：調査中に4回見立てを変えている

以下はすべて**誤りとして撤回済み**。再び同じ道に入らないよう記録する。

1. ❌「店舗ドロップダウンが他店舗を指していた」→ 事実3で否定。Settings 画面ではなく BOS Kiosk タブのコードを読んでいた
2. ❌「権限読み込みのレース条件」→ 条件は `stores.length > 1` であってレースではない（1.1.7 の話）
3. ❌「サーバー側が本番に未デプロイ」→ **本番は `stage`** であり、サーバーは対応済み。`main` を本番と誤認していた
4. ❌「1.1.7 だから未修正」→ 実際は 1.1.8 で、修正3件は含まれている

**教訓**: 本番は `main` ではなく `stage`。`main` を見て判断しないこと。
