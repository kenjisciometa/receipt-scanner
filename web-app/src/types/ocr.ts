// OCR Types (Flutter-compatible)
export interface TextLine {
  text: string;
  confidence: number;
  boundingBox: [number, number, number, number]; // [x, y, w, h]
  merged?: boolean; // Flag to indicate if this line was merged from multiple OCR elements
}

export interface OCRResult {
  text: string;                    // 全認識テキスト
  textLines: TextLine[];          // 行ごとの結果
  confidence: number;             // 全体信頼度
  detected_language: string;      // 検出言語
  processing_time: number;        // 処理時間(ms)
  success: boolean;               // 処理成功フラグ
}

// Text Line with ML features
export interface TextLineWithLabels extends TextLine {
  line_index: number;
  elements: TextElement[];
  
  // ML学習用フィールド
  label: string;              // 'MERCHANT_NAME', 'TOTAL', 'TAX', 'OTHER' etc.
  label_confidence: number;   // 擬似ラベル信頼度
  features: TextLineFeatures; // 20次元特徴量
  feature_vector: number[];   // 数値ベクトル [位置, テキスト特徴量]
}

export interface TextElement {
  text: string;
  confidence: number;
  boundingBox: [number, number, number, number];
}

// Alias for backward compatibility
export type OCRElement = TextElement;

// Feature vector for ML (Flutter port)
export interface TextLineFeatures {
  // 位置特徴量 (4)
  x_center: number;
  y_center: number;  
  width: number;
  height: number;
  
  // 位置フラグ (4)
  is_right_side: boolean;
  is_bottom_area: boolean;
  is_middle_section: boolean;
  line_index_norm: number;
  
  // テキスト特徴量 (12)
  has_currency_symbol: boolean;
  has_percent: boolean;
  has_amount_like: boolean;
  has_total_keyword: boolean;
  has_tax_keyword: boolean;
  has_subtotal_keyword: boolean;
  has_date_like: boolean;
  has_quantity_marker: boolean;
  has_item_like: boolean;
  digit_count: number;
  alpha_count: number;
  contains_colon: boolean;
}