# React POS Discount適用クリア機能 - 実装修正案

## 概要
ReactRestaurantPOSにFlutterPOS準拠のDiscount適用クリア機能を実装し、一貫したDiscount管理動作を実現する。

## FlutterPOS参考実装の調査結果

### Discount Clear のタイミング
1. **テーブルセッション変更時**: `clearCart()` - 完全状態リセット
2. **NEW→SAVED変換時**: `mergeNewItemsToSaved()` - **Discount情報保持**  
3. **CHECKOUT後**: `clearCartAfterCheckout()` - 完全状態リセット

### FlutterPOSの `clearCartAfterCheckout()` 実装
```dart
void clearCartAfterCheckout() {
  // 完全にクリアな状態に戻す
  _actualDiningOptionName = null;
  _existingOrderId = null;
  _tableSessionId = null;
  
  // 完全に新しいCartインスタンス（全ての状態をリセット）
  state = Cart();  // ← Discount含む全状態クリア
  
  _saveCart();
  _clearCartCache();
}
```

## ReactPOS現在の実装状況

### ✅ 実装済み（修正不要）
1. **CHECKOUT後のDiscount完全クリア**: `startNewOrder()` → `clearCart()` で実装済み
2. **NEW→SAVED変換時のDiscount保持**: `mergeNewItemsToSaved()` で正しく実装済み

### ❌ 修正が必要
**テーブルセッション変更時のItem-level Discountクリア強化**

## 修正実装案

### 修正箇所1: loadTableSessionOrders()関数の強化

**ファイル:** `src/app/pos/page.tsx`  
**行数:** 340-345行目（エラー時処理）、358-362行目（セッション未発見時処理）

#### 現在のコード
```typescript
// エラー時
setCartItems([])
setExistingOrderId(null)
setTableSessionId(null)
setOriginalOrderItemIds([])
setAppliedCoupon(null)  // Order-level couponのみクリア

// セッション未発見時  
setCartItems(prevItems => prevItems.filter(item => !item.isExisting))
setExistingOrderId(null)
setTableSessionId(null) 
setOriginalOrderItemIds([])
// ❌ Order-level couponクリアが抜けている
```

#### 修正後のコード
```typescript
// エラー時
setCartItems([])
setExistingOrderId(null)
setTableSessionId(null)
setOriginalOrderItemIds([])
setAppliedCoupon(null)  // Order-level coupon クリア

// セッション未発見時
setCartItems(prevItems => {
  // Item-level discountもクリアしてからフィルタ
  const clearedItems = prevItems.map(item => ({
    ...item,
    discountAmount: 0,
    discountType: undefined,
    discountPercentage: undefined,
    manualDiscountAmount: 0,
    itemCouponDiscount: 0,
    orderCouponDiscount: 0,
    lineTotal: item.unitPrice * item.quantity,
    couponId: undefined
  }))
  return clearedItems.filter(item => !item.isExisting)
})
setExistingOrderId(null)
setTableSessionId(null)
setOriginalOrderItemIds([])
setAppliedCoupon(null)  // Order-level coupon クリア
```

### 修正箇所2: clearCartの強化（念のため）

**ファイル:** `src/app/pos/page.tsx`  
**行数:** 1461-1480行目

#### 現在のコード（正常動作中）
```typescript
const clearCart = async () => {
  setCartItems([])
  setAppliedCoupon(null) // Clear coupon when clearing cart
  // ... 他の処理
}
```

#### 強化版（FlutterPOS完全準拠）
```typescript
const clearCart = async () => {
  setCartItems([])                    // カートアイテム完全クリア
  setAppliedCoupon(null)             // Order-level couponクリア
  setSelectedDiningOption(null)       // Dining optionクリア（必要に応じて）
  // 🔧 FIX: Clear lastLoadedOrderItems to prevent stale data
  if (typeof window !== 'undefined') {
    (window as any).lastLoadedOrderItems = []
  }
  // ... 既存のWebSocket処理
}
```

## 実装の動作フロー

### 1. テーブルセッション変更時
```
テーブル番号入力 
→ loadTableSessionOrders() 
→ セッション検索
→ 【修正】既存アイテムのDiscountクリア + Order-level couponクリア
→ 新しいセッションの既存アイテム読み込み
```

### 2. Create/Update Order時  
```
Create/Update Order API call
→ mergeNewItemsToSaved()
→ 【現状維持】Discount情報を保持してNEW→SAVED変換
```

### 3. CHECKOUT → Start New Order時
```
CHECKOUT完了
→ startNewOrder()
→ clearCart()
→ 【現状維持】全ての状態（Discount含む）を完全クリア
```

## FlutterPOSとの動作一致確認

| 動作タイミング | ReactPOS（修正後） | FlutterPOS | 一致 |
|---------------|-------------------|-----------|------|
| テーブルセッション変更 | Discount完全クリア | `clearCart()` | ✅ |
| NEW→SAVED変換 | Discount保持 | `mergeNewItemsToSaved()` | ✅ |
| CHECKOUT後 | 完全状態リセット | `clearCartAfterCheckout()` | ✅ |

## 期待される効果

### システム動作の一貫性
- ✅ **ReactPOSとFlutterPOSで同一のDiscount管理動作**
- ✅ **テーブル切り替え時の確実なDiscount状態リセット**
- ✅ **Order作成/更新時の適切なDiscount保持**

### ユーザー体験の向上
- ✅ **予期しないDiscount適用の防止**
- ✅ **テーブル間でのDiscount混在防止**  
- ✅ **一貫した金額計算**

## 実装優先度

### 🔴 高優先度（必須修正）
**テーブルセッション変更時のItem-level Discountクリア強化**
- 修正箇所1: `loadTableSessionOrders()` 関数の強化

### 🟡 中優先度（推奨）
**clearCart()の強化**
- 修正箇所2: より堅牢なクリア処理

---

**この修正により、ReactPOSがFlutterPOSと完全に一致したDiscount管理動作を実現し、両POSシステム間での一貫したユーザー体験を提供できます。**