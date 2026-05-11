# PPI BOS Payment Terminal Reclassification Plan

## Organization
- **Name**: Prairie Plus International Oy
- **ID**: `87350b41-bac7-4d92-a0bc-415bc50777d1`
- **Supabase Project**: `mcldujatysqrzsdjxpof`

## Target Terminals
| Terminal | ID | Type |
|---|---|---|
| Sumup_SelfOrder | `c08d43a4-72e9-47c8-aa4e-656a8a0d85ba` | sumup |
| Backup terminal | `1fe3b53b-a531-47c5-8b6b-91fc7673c5f5` | sumup |

## Target Payment Types
| Payment Type | ID |
|---|---|
| Credit Card | `024eff86-40c2-4d2f-b451-f9c05ae3ed64` |
| Edenred | `ed1c0ab9-df94-4e8d-9279-f772ee28255d` |
| Sumup_SelfOrder (legacy) | `79158eaa-221b-4d20-b33f-29d043789767` |
| Backup terminal (legacy) | `8191aacc-21bd-4e34-a81e-320fc8a18d70` |

## Current State (BOS orders only)

| Current Terminal | Payment Type | Count | Amount |
|---|---|---|---|
| Backup terminal | Credit Card | 207 | EUR 5,291.70 |
| Sumup_SelfOrder | Edenred | 10 | EUR 140.00 |
| Sumup_SelfOrder | Sumup_SelfOrder | 8 | EUR 189.70 |
| Sumup_SelfOrder | Backup terminal | 7 | EUR 135.30 |

### Issues
1. **207 BOS Credit Card payments** are assigned to **Backup terminal** instead of **Sumup_SelfOrder**
2. **8 payments** use legacy payment type name **"Sumup_SelfOrder"** instead of **"Credit Card"**
3. **7 payments** use legacy payment type name **"Backup terminal"** instead of **"Credit Card"**

## Migration Plan (3 UPDATE queries)

### Step 1: Reassign BOS Credit Card to Sumup_SelfOrder (207 rows)

Move `payment_terminal_id` from Backup terminal to Sumup_SelfOrder for BOS orders with "Credit Card" payment type.

```sql
UPDATE order_payments op
SET payment_terminal_id = 'c08d43a4-72e9-47c8-aa4e-656a8a0d85ba'  -- Sumup_SelfOrder
FROM orders o
WHERE op.order_id = o.id
  AND o.organization_id = '87350b41-bac7-4d92-a0bc-415bc50777d1'
  AND o.order_number LIKE 'BOS-%'
  AND op.payment_type_id = '024eff86-40c2-4d2f-b451-f9c05ae3ed64'  -- Credit Card
  AND op.payment_terminal_id = '1fe3b53b-a531-47c5-8b6b-91fc7673c5f5';  -- Backup terminal
```

### Step 2: Rename "Sumup_SelfOrder" payment type to "Credit Card" (8 rows)

Change `payment_type_id` from legacy "Sumup_SelfOrder" to "Credit Card".

```sql
UPDATE order_payments op
SET payment_type_id = '024eff86-40c2-4d2f-b451-f9c05ae3ed64'  -- Credit Card
FROM orders o
WHERE op.order_id = o.id
  AND o.organization_id = '87350b41-bac7-4d92-a0bc-415bc50777d1'
  AND o.order_number LIKE 'BOS-%'
  AND op.payment_type_id = '79158eaa-221b-4d20-b33f-29d043789767';  -- Sumup_SelfOrder (legacy)
```

### Step 3: Rename "Backup terminal" payment type to "Credit Card" (7 rows)

Change `payment_type_id` from legacy "Backup terminal" to "Credit Card".

```sql
UPDATE order_payments op
SET payment_type_id = '024eff86-40c2-4d2f-b451-f9c05ae3ed64'  -- Credit Card
FROM orders o
WHERE op.order_id = o.id
  AND o.organization_id = '87350b41-bac7-4d92-a0bc-415bc50777d1'
  AND o.order_number LIKE 'BOS-%'
  AND op.payment_type_id = '8191aacc-21bd-4e34-a81e-320fc8a18d70';  -- Backup terminal (legacy)
```

## Expected Result After Migration

| Terminal | Payment Type | Count | Amount |
|---|---|---|---|
| **Sumup_SelfOrder** | **Credit Card** | **222** | **EUR 5,616.70** |
| **Sumup_SelfOrder** | **Edenred** | **10** | **EUR 140.00** |

## Notes
- Edenred (10 records) already correctly classified — no change needed
- POS orders are NOT affected by this migration (BOS-ORD- filter)
- `orders.payment_types` column is NOT updated (only `order_payments.payment_type_id`)
