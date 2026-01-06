// Training Data Types (Flutter-compatible)
import { TextLineWithLabels, OCRResult } from './ocr';
import { ExtractionResult } from './extraction';

export interface TrainingDataMetadata {
  image_path: string;
  language: string;
  ocr_confidence: number;
  extraction_confidence: number;
  is_verified: boolean;
  verified_at?: string;
}

// Raw Training Data (自動抽出結果)
export interface RawTrainingData {
  receipt_id: string;
  timestamp: string;
  is_verified: false;           // Raw データは未検証
  text_lines: TextLineWithLabels[];
  extraction_result: ExtractionResult;
  metadata: TrainingDataMetadata;
}

// Verified Training Data (手動修正後)
export interface VerifiedTrainingData {
  receipt_id: string;
  timestamp: string;
  is_verified: true;            // Ground truth
  text_lines: TextLineWithLabels[];
  extraction_result: {
    success: true;
    confidence: 1.0;            // 検証済みは常に1.0
    extracted_data: Record<string, any>; // 修正済みデータ
    metadata: {
      parsing_method: 'user_verified';
      is_ground_truth: true;
      document_type?: string;
      document_type_confidence?: number;
    };
  };
  metadata: {
    image_path: string;
    language: string;
    is_verified: true;
    verified_at: string;
  };
}

// Training Data Export format
export interface TrainingDataExport {
  receipt_id: string;
  timestamp: string;
  is_verified: boolean;
  text_lines: Array<{
    text: string;
    bounding_box: number[];
    confidence: number;
    label: string;           // MERCHANT_NAME, DATE, TOTAL, etc.
    label_confidence: number;
    features: any; // FeatureVector
    feature_vector: number[];
  }>;
  extraction_result: ExtractionResult;
  metadata: {
    image_path: string;
    language: string;
    ocr_confidence: number;
    extraction_confidence: number;
    is_ground_truth: boolean;
  };
}

// Training data statistics
export interface TrainingDataStatistics {
  summary: {
    total_raw_samples: number;
    total_verified_samples: number;
    verification_rate: number;        // verified / (raw + verified)
    average_confidence: number;
    data_quality_score: number;       // 0.0-1.0
  };
  
  distribution: {
    by_language: Record<string, number>;
    by_document_type: Record<string, number>;
    by_confidence_range: {
      high: number;    // 0.8+
      medium: number;  // 0.5-0.8
      low: number;     // <0.5
    };
  };
  
  label_quality: {
    label_distribution: Record<string, number>;
    most_corrected_fields: string[];  // 最も修正が多いフィールド
    error_patterns: string[];          // よくある間違いパターン
  };
  
  progress_tracking: {
    target_samples: number;            // 目標サンプル数
    current_samples: number;
    completion_percentage: number;
    estimated_completion_date: string;
  };
}

// Validation result
export interface ValidationResult {
  isValid: boolean;
  errors: string[];
}

// Verification result
export interface VerificationResult {
  success: boolean;
  verifiedJsonPath?: string;
  updatedRecord?: string;
  errors?: string[];
}