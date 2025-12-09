# Order Item論理削除機能 - 設計ドキュメント

## 概要
Pay-after-dining モードで既存のorder_itemを削除する場合、物理削除ではなくstatusを'cancelled'に変更して論理削除を行う。

## データベース設計

### order_items テーブル
- **status** カラム: `'active' | 'cancelled' | 'completed'`
  - `'active'`: 有効なアイテム（デフォルト）
  - `'cancelled'`: キャンセルされたアイテム（論理削除）
  - `'completed'`: 完了したアイテム（将来の拡張用）

**注意:** キャンセル関連のメタデータ（cancelled_at、cancelled_by、cancellation_reason）は実装せず、updated_atのみ更新する。

## フロントエンド実装

### 1. CartItemインターフェース
既存の構造をそのまま使用：
```typescript
interface CartItem {
  id: string
  product: Product
  quantity: number
  unitPrice: number
  taxRate: number
  discountAmount: number
  lineTotal: number
  comment?: string
  isExisting?: boolean        // 既存アイテムかどうか
  orderId?: string           // orders.id
  orderItemId?: string       // order_items.id
}
```

### 2. removeFromCart 関数の実装
既存アイテムの場合：
1. order_itemsのstatusを'cancelled'に更新
2. updated_atを更新
3. Order totalsを再計算・更新
4. Table Session totalsを再計算・更新
5. フロントエンドの状態から削除

新規アイテムの場合：
- 単純に状態から削除（データベース操作なし）

### 3. Order totals再計算
キャンセルされたアイテムの金額を減算：
- subtotal から line_total を減算
- tax_amount オブジェクトから該当税率の金額を減算
- total を再計算

### 4. Table Session totals再計算
キャンセルされたアイテムの金額（税込）を減算：
- total_amount から (line_total × (1 + tax_rate)) を減算

### 5. loadTableSessionOrders の修正
order_itemsを取得する際、`status='active'`のみ取得するようフィルタリング。

## データ整合性

### Order total計算
- キャンセルされたアイテムは計算から除外
- 既存のorder_itemsの合計 = status='active'のみ

### Table Session total計算
- 全てのunpaid ordersのtotalを合計
- キャンセルアイテムは自動的に除外される（order totalsに含まれないため）

### Payment完了時
- status='active'のorder_itemsのみをcompleted扱い
- status='cancelled'のアイテムはそのまま（履歴として残る）

## UI考慮事項

### 削除確認ダイアログ
既存アイテムを削除する際は確認ダイアログを表示：
- "This item has already been sent to the kitchen. Are you sure you want to cancel it?"

## マイグレーション

```sql
-- 既存データのstatus更新（必要に応じて）
UPDATE order_items
SET status = 'active'
WHERE status IS NULL;
```

## テスト観点

1. 既存アイテムの削除後、Order totalsが正しく更新されるか
2. 既存アイテムの削除後、Table Session totalsが正しく更新されるか
3. キャンセルされたアイテムがCart再読み込み時に表示されないか
4. 新規アイテムの削除は即座にUIから削除されるか（DB操作なし）
5. Payment完了時、キャンセルアイテムは除外されているか
6. 複数アイテムを連続削除した場合の整合性
7. オフライン時の削除操作（エラーハンドリング）
