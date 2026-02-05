# Receipt Scanner 課金実装 進捗状況

**最終更新**: 2026-01-30

## 概要

Receipt Scanner アプリの Google Play 課金機能を sciometa-auth と連携して実装中。

---

## 完了した作業

### 1. Supabase クライアント初期化エラーの修正 (sciometa-auth)

**問題**: Docker 環境で `Error: Your project's URL and Key are required to create a Supabase client!`

**原因**:
- Proxy パターンによる環境変数読み込みタイミングの問題
- ビルド時にフォールバック値がなかった

**修正ファイル**:
| ファイル | 変更内容 |
|---------|---------|
| `src/lib/supabase/admin.ts` | Proxy → getter ベースに変更、`getSupabaseAdmin()` をエクスポート |
| `src/lib/supabase/client.ts` | フォールバック値追加、キャッシュ追加 |
| `src/lib/supabase/server.ts` | フォールバック値追加 |
| `src/app/global-error.tsx` | React 19 の prerender 問題を解決（新規作成） |
| `Dockerfile` | ビルド時 `NODE_ENV=production` に修正 |

**ステータス**: ✅ 完了・プッシュ済み

---

### 2. Flutter Google Play Billing 型エラーの修正 (receipt-scanner)

**問題**: `type '() => ProductDetails' is not a subtype of type '(() => GooglePlayProductDetails)?' of 'orElse'`

**原因**: `firstWhere` の `orElse` パラメータで `ProductDetails` と `GooglePlayProductDetails` の型共変性問題

**修正ファイル**:
- `flutter_app/lib/services/google_play_billing_service.dart`

**修正内容**:
```dart
// Before (問題のあるコード)
final subscriptionProduct = response.productDetails.firstWhere(
  (p) => p.id == kSubscriptionId,
  orElse: () => response.productDetails.first,
);

// After (ループベースの実装)
ProductDetails? subscriptionProduct;
for (final p in response.productDetails) {
  if (p.id == kSubscriptionId) {
    subscriptionProduct = p;
    break;
  }
}
subscriptionProduct ??= response.productDetails.isNotEmpty
    ? response.productDetails.first
    : null;
```

**ステータス**: ✅ 完了（ローカル修正済み、未プッシュ）

---

### 3. Receipt アプリ APP_NOT_FOUND エラーの修正

**問題**: `App not found. Please check the app_id parameter.`

**原因**: restaurant-pos の Docker コンテナで `RECEIPT_AUTH_APP_KEY` 環境変数が読み込まれていなかった

**確認事項**:
- DB に `receipt` アプリ登録済み: ✅
- API キーハッシュ一致: ✅ (`9b3842b5720eed1a71b0d167c10d65b34fe8bcb733474acfb56ad08baa02b8dc`)
- 環境変数設定: ✅ `RECEIPT_AUTH_APP_KEY=sk_receipt_8313f08541dd0766821cdadb9c8bc05e`

**ステータス**: ✅ 完了（環境変数設定で解決）

---

## 未完了の作業

### 4. Google Play Service Account Key の設定 (sciometa-auth)

**問題**: `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY environment variable is not set`

**必要な作業**:

1. **Google Cloud Console**
   - サービスアカウント作成
   - JSON キーファイルをダウンロード

2. **Google Play Console**
   - サービスアカウントをリンク
   - 「財務データを表示」「注文を管理」権限を付与

3. **sciometa-auth 環境変数設定**
   ```bash
   GOOGLE_PLAY_SERVICE_ACCOUNT_KEY='{"type":"service_account","project_id":"...","private_key":"...",...}'
   ```

4. **Docker コンテナ再起動**

**ステータス**: ❌ 未着手

---

### 5. Google Play Console で商品登録

**必要な作業**:

1. Google Play Console → 収益化 → 定期購入
2. 商品 ID: `receipt_pro_monthly`
3. 価格: €4.99/月
4. 有効化

**ステータス**: ❓ 未確認

---

## 環境変数一覧

### sciometa-auth (.env.development)

```bash
# 必須（未設定）
GOOGLE_PLAY_SERVICE_ACCOUNT_KEY='{"type":"service_account",...}'

# 設定済み
NEXT_PUBLIC_SUPABASE_URL=https://uxxiiexrquiqdnmltkhq.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...
```

### restaurant-pos (.env.development)

```bash
# 設定済み
RECEIPT_AUTH_APP_KEY=sk_receipt_8313f08541dd0766821cdadb9c8bc05e
AUTH_APP_KEY=sk_pos_94aa80c6bd4409aa7551a7470f6a7001
AUTH_MODE=sso
NEXT_PUBLIC_AUTH_URL=https://auth.sciometa.com
```

---

## DB 登録状況

### apps テーブル
| slug | name | is_active | api_key_hash |
|------|------|-----------|--------------|
| receipt | Receipt Scanner | ✅ true | 9b3842b5...05e |
| pos | Restaurant POS | ✅ true | (別のハッシュ) |

### subscription_plans テーブル
| app_slug | name | price_cents | billing_unit |
|----------|------|-------------|--------------|
| receipt | Receipt Pro | 499 | user |

---

## 次のステップ

1. [ ] Google Cloud でサービスアカウント作成
2. [ ] Google Play Console でサービスアカウントをリンク
3. [ ] `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY` を sciometa-auth に設定
4. [ ] Google Play Console で `receipt_pro_monthly` 商品を登録
5. [ ] Docker コンテナ再ビルド・再起動
6. [ ] 購入フローのE2Eテスト
7. [ ] Flutter アプリの変更をコミット・プッシュ

---

## 関連ファイル

- `sciometa-auth/src/lib/google-play/client.ts` - Google Play API クライアント
- `sciometa-auth/src/app/api/billing/verify-google-play/route.ts` - 購入検証 API
- `flutter_app/lib/services/google_play_billing_service.dart` - Flutter 側課金サービス
- `flutter_app/lib/services/billing_service.dart` - 課金状態管理
