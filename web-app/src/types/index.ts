/**
 * Central types export file
 */

// Re-export from ocr types
export type { TextLine, OCRResult, OCRElement, TextElement, TextLineWithLabels, TextLineFeatures } from './ocr';

// Re-export from extraction types
export type { ExtractionResult, ReceiptItem, TaxBreakdown, DocumentType } from './extraction';

// Re-export from evidence types
export type { BoundingBox } from './evidence';

// Re-export from language keywords
export type { SupportedLanguage } from '../services/keywords/language-keywords';

/**
 * ProcessedTextLine - TextLine with additional processing metadata
 */
export interface ProcessedTextLine {
  text: string;
  confidence: number;
  boundingBox: [number, number, number, number]; // [x, y, w, h]
  merged?: boolean;
  lineIndex?: number;
  elements?: Array<{
    text: string;
    confidence: number;
    boundingBox: [number, number, number, number];
  }>;
}
