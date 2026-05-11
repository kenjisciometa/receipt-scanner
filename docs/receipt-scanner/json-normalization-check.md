# JSON出力の正規化チェック

## 目次
1. [現状の分析](#1-現状の分析)
2. [問題点](#2-問題点)
3. [改善案](#3-改善案)
4. [正規化されたスキーマ](#4-正規化されたスキーマ)

---

## 1. 現状の分析

### 1.1 現在のJSON構造

**Raw Data (`saveTrainingData`):**
```json
{
  "receipt_id": "string",
  "timestamp": "ISO8601 string",
  "text_lines": [
    {
      "text": "string",
      "bounding_box": [x, y, w, h] | null,
      "confidence": 0.0-1.0,
      "line_index": 0,
      "elements": [...],  // 常に存在（textLinesの場合）
      "label": "string",
      "label_confidence": 0.0-1.0,
      "features": {...},  // 条件付き（boundingBoxがある場合）
      "feature_vector": [...]  // 条件付き（featuresがある場合）
    }
  ],
  "extraction_result": {
    "success": boolean,
    "confidence": 0.0-1.0,
    "extracted_data": {...},
    "warnings": [...],
    "applied_patterns": [...],
    "metadata": {...}
  },
  "metadata": {
    "image_path": "string",
    "language": "string",
    "ocr_confidence": 0.0-1.0,
    "extraction_confidence": 0.0-1.0,
    "extraction_method": "string",
    "consistency_score": number | null,
    "text_lines_count": number,
    "text_blocks_count": number,
    ...
  }
}
```

**Verified Data (`saveVerifiedTrainingData`):**
```json
{
  "receipt_id": "string",
  "timestamp": "ISO8601 string",
  "is_verified": true,  // 追加フィールド
  "text_lines": [...],
  "extraction_result": {
    "success": true,
    "confidence": 1.0,
    "extracted_data": {...},
    "warnings": [],
    "applied_patterns": [],
    "metadata": {
      "parsing_method": "user_verified",
      "is_ground_truth": true
    }
  },
  "metadata": {
    "image_path": "string",
    "language": "string",
    "ocr_confidence": 0.0-1.0,
    "extraction_confidence": 1.0,
    "extraction_method": "user_verified",
    "text_lines_count": number,
    "text_blocks_count": number,
    "verified_at": "ISO8601 string",  // 追加フィールド
    ...
  }
}
```

---

## 2. 問題点

### 2.1 条件付きフィールドの不一致

**問題：**
1. **`features`と`feature_vector`が条件付き**
   - `boundingBox`がない場合、これらのフィールドが存在しない
   - Python側でnullチェックが必要

2. **`elements`の扱いが一貫していない**
   - `textLines`の場合は常に存在
   - `textBlocks`の場合は存在しない可能性

3. **`is_verified`フィールドの不一致**
   - Verified dataにのみ存在
   - Raw dataには存在しない（デフォルトで`false`と推測）

### 2.2 データ型の不一致

**問題：**
1. **`bounding_box`がnullの可能性**
   - 配列またはnull
   - Python側で型チェックが必要

2. **`consistency_score`がnullの可能性**
   - 数値またはnull
   - デフォルト値が不明

3. **`extracted_data`の構造が不明確**
   - 必須フィールドが不明
   - オプショナルフィールドが不明

### 2.3 メタデータの不一致

**問題：**
1. **`metadata`の構造が異なる**
   - Raw dataとVerified dataで異なるフィールド
   - `verified_at`がVerified dataにのみ存在

2. **`extraction_result.metadata`の構造が異なる**
   - Raw data: `parsing_method`など
   - Verified data: `parsing_method: "user_verified"`, `is_ground_truth: true`

---

## 3. 改善案

### 3.1 必須フィールドの統一

**すべてのJSONに必須フィールドを追加：**

```dart
// 改善前
if (features != null) 'features': _featuresToMap(features),
if (featureVector != null) 'feature_vector': featureVector,

// 改善後
'features': features != null ? _featuresToMap(features) : _getDefaultFeatures(),
'feature_vector': featureVector ?? _getDefaultFeatureVector(),
```

### 3.2 デフォルト値の提供

**nullの代わりにデフォルト値を提供：**

```dart
// 改善前
'bounding_box': line.boundingBox,

// 改善後
'bounding_box': line.boundingBox ?? [0.0, 0.0, 0.0, 0.0],
```

### 3.3 `is_verified`フィールドの統一

**すべてのJSONに`is_verified`フィールドを追加：**

```dart
// 改善前（Raw data）
final trainingData = <String, dynamic>{
  'receipt_id': receiptId,
  'timestamp': DateTime.now().toIso8601String(),
  'text_lines': ...,
  ...
};

// 改善後
final trainingData = <String, dynamic>{
  'receipt_id': receiptId,
  'timestamp': DateTime.now().toIso8601String(),
  'is_verified': false,  // 明示的に追加
  'text_lines': ...,
  ...
};
```

### 3.4 メタデータの統一

**メタデータの構造を統一：**

```dart
// 改善前
'metadata': {
  'image_path': imagePath,
  'language': ocrResult.detectedLanguage ?? 'unknown',
  ...
  if (additionalMetadata != null) ...additionalMetadata,
},

// 改善後
'metadata': {
  'image_path': imagePath,
  'language': ocrResult.detectedLanguage ?? 'unknown',
  'ocr_confidence': ocrResult.confidence,
  'extraction_confidence': extractionResult.confidence,
  'extraction_method': extractionResult.metadata['parsing_method'] ?? 'rule_based',
  'consistency_score': extractionResult.metadata['consistency_score'] ?? null,
  'text_lines_count': ocrResult.textLines.length,
  'text_blocks_count': ocrResult.textBlocks.length,
  'is_verified': false,  // 統一
  'verified_at': null,   // 統一（Raw dataではnull）
  if (additionalMetadata != null) ...additionalMetadata,
},
```

---

## 4. 正規化されたスキーマ

### 4.1 統一されたJSONスキーマ

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": [
    "receipt_id",
    "timestamp",
    "is_verified",
    "text_lines",
    "extraction_result",
    "metadata"
  ],
  "properties": {
    "receipt_id": {
      "type": "string",
      "description": "Unique receipt identifier"
    },
    "timestamp": {
      "type": "string",
      "format": "date-time",
      "description": "ISO8601 timestamp"
    },
    "is_verified": {
      "type": "boolean",
      "description": "Whether this is verified ground truth data"
    },
    "text_lines": {
      "type": "array",
      "items": {
        "type": "object",
        "required": [
          "text",
          "bounding_box",
          "confidence",
          "line_index",
          "elements",
          "label",
          "label_confidence",
          "features",
          "feature_vector"
        ],
        "properties": {
          "text": {
            "type": "string"
          },
          "bounding_box": {
            "type": "array",
            "items": {
              "type": "number"
            },
            "minItems": 4,
            "maxItems": 4,
            "description": "[x, y, width, height] or [0, 0, 0, 0] if not available"
          },
          "confidence": {
            "type": "number",
            "minimum": 0.0,
            "maximum": 1.0
          },
          "line_index": {
            "type": "integer",
            "minimum": 0
          },
          "elements": {
            "type": "array",
            "items": {
              "type": "object",
              "required": ["text", "confidence", "bounding_box"],
              "properties": {
                "text": {"type": "string"},
                "confidence": {"type": "number"},
                "bounding_box": {
                  "type": "array",
                  "items": {"type": "number"},
                  "minItems": 4,
                  "maxItems": 4
                }
              }
            },
            "default": []
          },
          "label": {
            "type": "string",
            "enum": [
              "OTHER",
              "MERCHANT_NAME",
              "DATE",
              "TIME",
              "TOTAL",
              "SUBTOTAL",
              "TAX",
              "ITEM_NAME",
              "ITEM_PRICE",
              "PAYMENT_METHOD",
              "RECEIPT_NUMBER",
              "SECTION_HEADER"
            ]
          },
          "label_confidence": {
            "type": "number",
            "minimum": 0.0,
            "maximum": 1.0
          },
          "features": {
            "type": "object",
            "required": [
              "x_center",
              "y_center",
              "width",
              "height",
              "is_right_side",
              "is_bottom_area",
              "is_middle_section",
              "line_index_norm",
              "has_currency_symbol",
              "has_percent",
              "has_amount_like",
              "has_total_keyword",
              "has_tax_keyword",
              "has_subtotal_keyword",
              "has_date_like",
              "has_quantity_marker",
              "has_item_like",
              "digit_count",
              "alpha_count",
              "contains_colon"
            ],
            "properties": {
              "x_center": {"type": "number"},
              "y_center": {"type": "number"},
              "width": {"type": "number"},
              "height": {"type": "number"},
              "is_right_side": {"type": "boolean"},
              "is_bottom_area": {"type": "boolean"},
              "is_middle_section": {"type": "boolean"},
              "line_index_norm": {"type": "number"},
              "has_currency_symbol": {"type": "boolean"},
              "has_percent": {"type": "boolean"},
              "has_amount_like": {"type": "boolean"},
              "has_total_keyword": {"type": "boolean"},
              "has_tax_keyword": {"type": "boolean"},
              "has_subtotal_keyword": {"type": "boolean"},
              "has_date_like": {"type": "boolean"},
              "has_quantity_marker": {"type": "boolean"},
              "has_item_like": {"type": "boolean"},
              "digit_count": {"type": "integer"},
              "alpha_count": {"type": "integer"},
              "contains_colon": {"type": "boolean"}
            }
          },
          "feature_vector": {
            "type": "array",
            "items": {"type": "number"},
            "minItems": 20,
            "maxItems": 20,
            "description": "20-dimensional feature vector"
          }
        }
      }
    },
    "extraction_result": {
      "type": "object",
      "required": [
        "success",
        "confidence",
        "extracted_data",
        "warnings",
        "applied_patterns",
        "metadata"
      ],
      "properties": {
        "success": {"type": "boolean"},
        "confidence": {
          "type": "number",
          "minimum": 0.0,
          "maximum": 1.0
        },
        "extracted_data": {
          "type": "object",
          "properties": {
            "merchant_name": {"type": ["string", "null"]},
            "date": {"type": ["string", "null"]},
            "time": {"type": ["string", "null"]},
            "total_amount": {"type": ["number", "null"]},
            "subtotal_amount": {"type": ["number", "null"]},
            "tax_amount": {"type": ["number", "null"]},
            "payment_method": {"type": ["string", "null"]},
            "currency": {"type": ["string", "null"]},
            "receipt_number": {"type": ["string", "null"]}
          }
        },
        "warnings": {
          "type": "array",
          "items": {"type": "string"},
          "default": []
        },
        "applied_patterns": {
          "type": "array",
          "items": {"type": "string"},
          "default": []
        },
        "metadata": {
          "type": "object",
          "properties": {
            "parsing_method": {
              "type": "string",
              "enum": ["rule_based", "user_verified", "ml_enhanced"]
            },
            "is_ground_truth": {"type": "boolean"},
            "consistency_score": {"type": ["number", "null"]},
            "items_sum": {"type": ["number", "null"]},
            "items_count": {"type": ["integer", "null"]}
          }
        }
      }
    },
    "metadata": {
      "type": "object",
      "required": [
        "image_path",
        "language",
        "ocr_confidence",
        "extraction_confidence",
        "extraction_method",
        "text_lines_count",
        "text_blocks_count",
        "is_verified",
        "verified_at"
      ],
      "properties": {
        "image_path": {"type": "string"},
        "language": {"type": "string"},
        "ocr_confidence": {
          "type": "number",
          "minimum": 0.0,
          "maximum": 1.0
        },
        "extraction_confidence": {
          "type": "number",
          "minimum": 0.0,
          "maximum": 1.0
        },
        "extraction_method": {
          "type": "string",
          "enum": ["rule_based", "user_verified", "ml_enhanced"]
        },
        "consistency_score": {"type": ["number", "null"]},
        "text_lines_count": {"type": "integer"},
        "text_blocks_count": {"type": "integer"},
        "is_verified": {"type": "boolean"},
        "verified_at": {"type": ["string", "null"], "format": "date-time"},
        "is_test_image": {"type": ["boolean", "null"]},
        "original_confidence": {"type": ["number", "null"]}
      }
    }
  }
}
```

---

## 5. 実装の改善

### 5.1 デフォルト値の提供

```dart
/// Get default features when bounding box is not available
Map<String, dynamic> _getDefaultFeatures() {
  return {
    'x_center': 0.0,
    'y_center': 0.0,
    'width': 0.0,
    'height': 0.0,
    'is_right_side': false,
    'is_bottom_area': false,
    'is_middle_section': false,
    'line_index_norm': 0.0,
    'has_currency_symbol': false,
    'has_percent': false,
    'has_amount_like': false,
    'has_total_keyword': false,
    'has_tax_keyword': false,
    'has_subtotal_keyword': false,
    'has_date_like': false,
    'has_quantity_marker': false,
    'has_item_like': false,
    'digit_count': 0,
    'alpha_count': 0,
    'contains_colon': false,
  };
}

/// Get default feature vector
List<double> _getDefaultFeatureVector() {
  return List.filled(20, 0.0);
}
```

### 5.2 統一されたtext_linesの生成

```dart
List<Map<String, dynamic>> _prepareTextLines(
  OCRResult ocrResult,
  ExtractionResult? extractionResult,
) {
  final textLines = <Map<String, dynamic>>[];
  final imageSize = _estimateImageSize(ocrResult);

  if (ocrResult.textLines.isNotEmpty) {
    for (int i = 0; i < ocrResult.textLines.length; i++) {
      final line = ocrResult.textLines[i];
      
      // Extract features (always provide, even if bounding box is missing)
      TextLineFeatures features;
      List<double> featureVector;
      if (line.boundingBox != null && line.boundingBox!.length >= 4) {
        try {
          features = TextLineFeatureExtractor.extractFeatures(...);
          featureVector = _buildFeatureVector(features);
        } catch (e) {
          logger.w('Failed to extract features for line $i: $e');
          features = _getDefaultFeatures();
          featureVector = _getDefaultFeatureVector();
        }
      } else {
        features = _getDefaultFeatures();
        featureVector = _getDefaultFeatureVector();
      }
      
      // Generate pseudo-label
      final labelInfo = _generatePseudoLabel(line, extractionResult, i);
      
      textLines.add({
        'text': line.text,
        'bounding_box': line.boundingBox ?? [0.0, 0.0, 0.0, 0.0],  // デフォルト値
        'confidence': line.confidence,
        'line_index': i,
        'elements': line.elements.map((e) => {
          'text': e.text,
          'confidence': e.confidence,
          'bounding_box': e.boundingBox ?? [0.0, 0.0, 0.0, 0.0],  // デフォルト値
        }).toList(),
        // ML training fields (常に存在)
        'label': labelInfo['label'],
        'label_confidence': labelInfo['confidence'],
        'features': _featuresToMap(features),  // 常に存在
        'feature_vector': featureVector,  // 常に存在
      });
    }
  } else {
    // Fallback to textBlocks (elementsを空配列に)
    for (int i = 0; i < ocrResult.textBlocks.length; i++) {
      final block = ocrResult.textBlocks[i];
      final labelInfo = _generatePseudoLabelFromBlock(block, extractionResult, i);
      
      textLines.add({
        'text': block.text,
        'bounding_box': block.boundingBox ?? [0.0, 0.0, 0.0, 0.0],
        'confidence': block.confidence,
        'line_index': i,
        'elements': [],  // 空配列
        'label': labelInfo['label'],
        'label_confidence': labelInfo['confidence'],
        'features': _getDefaultFeatures(),  // デフォルト値
        'feature_vector': _getDefaultFeatureVector(),  // デフォルト値
      });
    }
  }

  return textLines;
}
```

### 5.3 統一されたメタデータの生成

```dart
Map<String, dynamic> _buildMetadata({
  required String imagePath,
  required OCRResult ocrResult,
  required ExtractionResult extractionResult,
  required bool isVerified,
  Map<String, dynamic>? additionalMetadata,
}) {
  return {
    'image_path': imagePath,
    'language': ocrResult.detectedLanguage ?? 'unknown',
    'ocr_confidence': ocrResult.confidence,
    'extraction_confidence': extractionResult.confidence,
    'extraction_method': extractionResult.metadata['parsing_method'] ?? 'rule_based',
    'consistency_score': extractionResult.metadata['consistency_score'],
    'text_lines_count': ocrResult.textLines.length,
    'text_blocks_count': ocrResult.textBlocks.length,
    'is_verified': isVerified,  // 統一
    'verified_at': isVerified ? DateTime.now().toIso8601String() : null,  // 統一
    if (additionalMetadata != null) ...additionalMetadata,
  };
}
```

---

## 6. まとめ

### 6.1 改善が必要な点

1. ✅ **必須フィールドの統一**: `is_verified`, `features`, `feature_vector`を常に含める
2. ✅ **デフォルト値の提供**: nullの代わりにデフォルト値を提供
3. ✅ **メタデータの統一**: Raw dataとVerified dataで同じ構造
4. ✅ **型の一貫性**: すべてのフィールドで型を統一

### 6.2 実装の優先順位

1. **高優先度**: デフォルト値の提供（Python側のnullチェックを不要に）
2. **中優先度**: `is_verified`フィールドの統一
3. **低優先度**: メタデータの完全な統一（後方互換性を保つ）

### 6.3 次のステップ

1. `_getDefaultFeatures()`と`_getDefaultFeatureVector()`を実装
2. `_prepareTextLines()`を改善して、常にすべてのフィールドを含める
3. `_buildMetadata()`を追加して、メタデータの生成を統一
4. 既存のJSONファイルとの互換性を確認

---

## 参考資料

- [ml-training-guide.md](./ml-training-guide.md)
- [pseudo-label-collection-strategy.md](./pseudo-label-collection-strategy.md)

