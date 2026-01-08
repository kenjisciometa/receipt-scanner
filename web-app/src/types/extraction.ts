// Extraction Types (Flutter-compatible)
export type ReceiptStatus = 'pending' | 'processing' | 'completed' | 'failed' | 'needs_verification';
export type DocumentType = 'receipt' | 'invoice' | 'unknown';

export interface TaxBreakdown {
  rate: number;           // 14.0, 24.0 etc (tax rate percentage)
  amount: number;         // tax amount (税額)
  net?: number;           // net amount (税抜き金額)
  gross?: number;         // gross amount (税込み金額)
  category?: string;      // tax category (A, B, Standard, Reduced)
  confidence?: number;    // detection confidence (0.0-1.0)
  description?: string;   // multilingual description
}

export interface ReceiptItem {
  name: string;
  quantity: number;
  total_price: number;
  unit_price: number;
  tax_rate: number;
}

export interface ExtractionResult {
  merchant_name: string | null;
  date: string | null;           // Date string in YYYY-MM-DD format (to avoid timezone issues)
  time?: string | null;          // Time string in HH:MM AM/PM format
  currency?: string;             // EUR, USD, etc. (made optional)
  subtotal: number | null;
  tax_breakdown: TaxBreakdown[];
  tax_total: number | null;
  total: number;                 // 必須
  receipt_number: string | null;
  payment_method: string | null;
  confidence: number;
  status: ReceiptStatus;
  needs_verification?: boolean;  // Made optional
  items?: ReceiptItem[];         // Renamed and made optional
  warnings?: string[];           // Added for evidence-based fusion
  
  // Document classification
  document_type?: DocumentType;
  document_type_confidence?: number;
  document_type_reason?: string;
  
  // Metadata for enhanced extraction
  metadata?: {
    extraction_method?: string;
    evidence_summary?: any;
    processing_times?: any;
    applied_patterns?: string[];
    language_detected?: string;
    fusion_config?: any;
    fallback_reason?: string;
  };

  // Processed text lines for training data collection
  processedTextLines?: any[];
}

// Document Type Classification
export interface DocumentTypeResult {
  documentType: DocumentType;
  confidence: number;        // 0.0-1.0
  reason: string;           // 分類理由
  receiptScore: number;     // レシートスコア
  invoiceScore: number;     // 請求書スコア
}

// Receipt specific data
export interface ReceiptData {
  document_type: 'receipt';
  payment_method: 'cash' | 'card' | 'mobile' | 'contactless';
  payment_status: 'paid' | 'completed';
  customer_copy: boolean;
  transaction_id?: string;
}

// Invoice specific data
export interface InvoiceData {
  document_type: 'invoice';
  due_date: string;           // ISO 8601
  payment_terms: string;      // 'Net 30', 'Net 60', etc.
  bill_to: {
    name: string;
    address: string;
  };
  invoice_number: string;
  payment_status: 'unpaid' | 'pending' | 'overdue';
  billing_address?: string;
}

// Editable fields for manual correction
export interface EditableFields {
  // 基本情報
  merchant_name: string;
  date: string;                    // YYYY-MM-DD format
  time?: string;                   // HH:MM AM/PM format
  currency: string;
  
  // 金額情報
  subtotal?: number;
  tax_total?: number;
  total: number;                   // 必須
  
  // 文書分類
  document_type: DocumentType;
  
  // Receipt特有
  payment_method?: string;
  transaction_id?: string;
  
  // Invoice特有
  due_date?: string;
  payment_terms?: string;
  bill_to_name?: string;
  bill_to_address?: string;
  
  // 商品情報
  items?: ReceiptItem[];
}