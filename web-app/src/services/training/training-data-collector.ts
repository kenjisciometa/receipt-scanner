// Training Data Collection Service (Flutter port)
import { writeFile, mkdir } from 'fs/promises';
import { existsSync } from 'fs';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { 
  OCRResult, 
  TextLineWithLabels, 
  TextLineFeatures 
} from '@/types/ocr';
import { 
  ExtractionResult, 
  DocumentType 
} from '@/types/extraction';
import { 
  RawTrainingData, 
  VerifiedTrainingData, 
  TrainingDataMetadata 
} from '@/types/training';
import { prisma } from '@/lib/prisma';

export class TrainingDataCollector {
  
  private readonly RAW_DATA_DIR = path.join(process.cwd(), 'data', 'training', 'raw');
  private readonly VERIFIED_DATA_DIR = path.join(process.cwd(), 'data', 'training', 'verified');
  private readonly EXPORTS_DIR = path.join(process.cwd(), 'data', 'training', 'exports');

  constructor() {
    this.ensureDirectories();
  }

  private async ensureDirectories(): Promise<void> {
    const dirs = [this.RAW_DATA_DIR, this.VERIFIED_DATA_DIR, this.EXPORTS_DIR];
    
    for (const dir of dirs) {
      if (!existsSync(dir)) {
        await mkdir(dir, { recursive: true });
      }
    }
  }

  /**
   * Save raw training data (automatic extraction results with confidence >= 0.7)
   */
  async saveRawTrainingData(
    receiptId: string,
    ocrResult: OCRResult,
    extractionResult: ExtractionResult,
    imagePath: string
  ): Promise<string | null> {
    
    // Only save if confidence is acceptable
    if (extractionResult.confidence < 0.7) {
      console.log(`Skipping raw training data for ${receiptId} - confidence too low: ${extractionResult.confidence}`);
      return null;
    }

    try {
      const fileName = `receipt_${receiptId}_${Date.now()}.json`;
      const filePath = path.join(this.RAW_DATA_DIR, fileName);

      // Generate text lines with labels and features
      const textLinesWithLabels = this.generateTextLinesWithLabels(ocrResult, extractionResult);
      
      const trainingData: RawTrainingData = {
        receipt_id: receiptId,
        timestamp: new Date().toISOString(),
        is_verified: false,
        text_lines: textLinesWithLabels,
        extraction_result: extractionResult,
        metadata: {
          image_path: imagePath,
          language: ocrResult.detected_language,
          ocr_confidence: ocrResult.confidence,
          extraction_confidence: extractionResult.confidence,
          is_verified: false,
        }
      };

      await writeFile(filePath, JSON.stringify(trainingData, null, 2));

      // Save to database
      await this.saveToDatabase(receiptId, trainingData, null);

      console.log(`Raw training data saved: ${fileName}`);
      return fileName;

    } catch (error) {
      console.error('Failed to save raw training data:', error);
      return null;
    }
  }

  /**
   * Save verified training data (manually corrected ground truth)
   */
  async saveVerifiedTrainingData(
    receiptId: string,
    ocrResult: OCRResult,
    correctedData: Record<string, any>,
    originalImagePath: string
  ): Promise<string | null> {
    
    try {
      const fileName = `verified_receipt_${receiptId}_${Date.now()}.json`;
      const filePath = path.join(this.VERIFIED_DATA_DIR, fileName);

      // Generate verified labels based on corrected data
      const textLinesWithLabels = this.generateVerifiedLabels(ocrResult, correctedData);

      const trainingData: VerifiedTrainingData = {
        receipt_id: receiptId,
        timestamp: new Date().toISOString(),
        is_verified: true,
        text_lines: textLinesWithLabels,
        extraction_result: {
          success: true,
          confidence: 1.0,
          extracted_data: correctedData,
          metadata: {
            parsing_method: 'user_verified',
            is_ground_truth: true,
            document_type: correctedData.document_type,
            document_type_confidence: 1.0,
          }
        },
        metadata: {
          image_path: originalImagePath,
          language: ocrResult.detected_language,
          is_verified: true,
          verified_at: new Date().toISOString(),
        }
      };

      await writeFile(filePath, JSON.stringify(trainingData, null, 2));

      // Save to database
      await this.saveToDatabase(receiptId, null, trainingData);

      console.log(`Verified training data saved: ${fileName}`);
      return fileName;

    } catch (error) {
      console.error('Failed to save verified training data:', error);
      return null;
    }
  }

  /**
   * Generate text lines with labels and features for ML training
   */
  private generateTextLinesWithLabels(
    ocrResult: OCRResult, 
    extractionResult: ExtractionResult
  ): TextLineWithLabels[] {
    
    return ocrResult.textLines.map((line, index) => {
      // Generate label based on extraction result
      const label = this.generateLabelForTextLine(line.text, extractionResult);
      
      // Extract features
      const features = this.extractTextLineFeatures(line, index, ocrResult.textLines);
      
      return {
        ...line,
        line_index: index,
        elements: [], // Could be expanded later
        label,
        label_confidence: this.calculateLabelConfidence(label, extractionResult.confidence),
        features,
        feature_vector: this.featuresToVector(features),
      };
    });
  }

  /**
   * Generate verified labels based on manually corrected data
   */
  private generateVerifiedLabels(
    ocrResult: OCRResult,
    correctedData: Record<string, any>
  ): TextLineWithLabels[] {
    
    return ocrResult.textLines.map((line, index) => {
      // More accurate labeling since we have ground truth
      const label = this.generateGroundTruthLabel(line.text, correctedData);
      const features = this.extractTextLineFeatures(line, index, ocrResult.textLines);
      
      return {
        ...line,
        line_index: index,
        elements: [],
        label,
        label_confidence: 1.0, // Ground truth
        features,
        feature_vector: this.featuresToVector(features),
      };
    });
  }

  /**
   * Generate label for text line based on extraction results (pseudo-labels)
   */
  private generateLabelForTextLine(lineText: string, extractionResult: ExtractionResult): string {
    const text = lineText.toLowerCase().trim();
    
    // Check if line contains merchant name
    if (extractionResult.merchant_name && 
        text.includes(extractionResult.merchant_name.toLowerCase())) {
      return 'MERCHANT_NAME';
    }
    
    // Check if line contains total amount
    if (extractionResult.total && 
        text.includes(extractionResult.total.toString())) {
      return 'TOTAL';
    }
    
    // Check if line contains subtotal
    if (extractionResult.subtotal && 
        text.includes(extractionResult.subtotal.toString())) {
      return 'SUBTOTAL';
    }
    
    // Check if line contains tax
    if (extractionResult.tax_total && 
        text.includes(extractionResult.tax_total.toString())) {
      return 'TAX';
    }
    
    // Check if line contains date
    if (extractionResult.date && text.includes(extractionResult.date.split('T')[0])) {
      return 'DATE';
    }
    
    // Check if line contains receipt number
    if (extractionResult.receipt_number && 
        text.includes(extractionResult.receipt_number.toLowerCase())) {
      return 'RECEIPT_NUMBER';
    }
    
    // Check if line contains payment method
    if (extractionResult.payment_method && 
        text.includes(extractionResult.payment_method.toLowerCase())) {
      return 'PAYMENT_METHOD';
    }
    
    // Check for item-like patterns
    if (this.looksLikeItem(text)) {
      return 'ITEM_NAME';
    }
    
    return 'OTHER';
  }

  /**
   * Generate ground truth labels based on manually corrected data
   */
  private generateGroundTruthLabel(lineText: string, correctedData: Record<string, any>): string {
    // More sophisticated labeling with corrected data
    // This would use exact matching with verified field values
    return this.generateLabelForTextLine(lineText, correctedData as ExtractionResult);
  }

  /**
   * Extract feature vector for text line (Flutter port)
   */
  private extractTextLineFeatures(
    line: { text: string, boundingBox: [number, number, number, number] },
    lineIndex: number,
    allLines: any[]
  ): TextLineFeatures {
    
    const [x, y, width, height] = line.boundingBox;
    const text = line.text.toLowerCase();
    
    // Normalize position features (assuming 1000x1000 reference)
    const x_center = (x + width / 2) / 1000;
    const y_center = (y + height / 2) / 1000;
    const norm_width = width / 1000;
    const norm_height = height / 1000;
    
    return {
      // Position features (4)
      x_center,
      y_center,
      width: norm_width,
      height: norm_height,
      
      // Position flags (4)
      is_right_side: x_center > 0.6,
      is_bottom_area: y_center > 0.7,
      is_middle_section: y_center > 0.3 && y_center < 0.7,
      line_index_norm: lineIndex / Math.max(1, allLines.length - 1),
      
      // Text features (12)
      has_currency_symbol: /€|\$|£|kr|sek|usd|eur/i.test(text),
      has_percent: /%/.test(text),
      has_amount_like: /\d+[.,]\d{2}/.test(text),
      has_total_keyword: /(total|yhteensä|summa|gesamt|totale|som)/i.test(text),
      has_tax_keyword: /(tax|alv|moms|vat|steuer|iva)/i.test(text),
      has_subtotal_keyword: /(subtotal|välisumma|delsumma|zwischensumme)/i.test(text),
      has_date_like: /\d{1,2}[\.\/\-]\d{1,2}[\.\/\-]\d{2,4}/.test(text),
      has_quantity_marker: /(x\d+|\d+\s*pc|\d+\s*st)/i.test(text),
      has_item_like: this.looksLikeItem(text),
      digit_count: (text.match(/\d/g) || []).length,
      alpha_count: (text.match(/[a-zA-ZäöåÄÖÅ]/g) || []).length,
      contains_colon: /:/.test(text),
    };
  }

  /**
   * Convert features to numerical vector
   */
  private featuresToVector(features: TextLineFeatures): number[] {
    return [
      features.x_center, 
      features.y_center, 
      features.width, 
      features.height,
      Number(features.is_right_side), 
      Number(features.is_bottom_area),
      Number(features.is_middle_section), 
      features.line_index_norm,
      Number(features.has_currency_symbol), 
      Number(features.has_percent),
      Number(features.has_amount_like), 
      Number(features.has_total_keyword),
      Number(features.has_tax_keyword), 
      Number(features.has_subtotal_keyword),
      Number(features.has_date_like), 
      Number(features.has_quantity_marker),
      Number(features.has_item_like), 
      features.digit_count / 100.0,
      features.alpha_count / 100.0, 
      Number(features.contains_colon)
    ];
  }

  /**
   * Calculate label confidence based on extraction confidence
   */
  private calculateLabelConfidence(label: string, extractionConfidence: number): number {
    // Higher confidence for structural labels
    const confidenceMultiplier = ['TOTAL', 'MERCHANT_NAME', 'DATE'].includes(label) ? 1.0 : 0.8;
    return Math.min(1.0, extractionConfidence * confidenceMultiplier);
  }

  /**
   * Check if text looks like an item name
   */
  private looksLikeItem(text: string): boolean {
    // Simple heuristic for item detection
    return text.length > 3 && 
           text.length < 50 && 
           !/^(total|summa|tax|date|time)/i.test(text) &&
           /[a-zA-ZäöåÄÖÅ]/.test(text);
  }

  /**
   * Save training data to database
   */
  private async saveToDatabase(
    receiptId: string,
    rawData: RawTrainingData | null,
    verifiedData: VerifiedTrainingData | null
  ): Promise<void> {
    
    try {
      await prisma.trainingData.upsert({
        where: { jobId: receiptId },
        update: {
          rawData: rawData ? JSON.stringify(rawData) : undefined,
          verifiedData: verifiedData ? JSON.stringify(verifiedData) : undefined,
          isGroundTruth: verifiedData !== null,
        },
        create: {
          jobId: receiptId,
          rawData: rawData ? JSON.stringify(rawData) : null,
          verifiedData: verifiedData ? JSON.stringify(verifiedData) : null,
          features: rawData ? JSON.stringify(rawData.text_lines.map(l => l.features)) : null,
          labels: rawData ? JSON.stringify(rawData.text_lines.map(l => l.label)) : null,
          isGroundTruth: verifiedData !== null,
        }
      });
    } catch (error) {
      console.error('Failed to save training data to database:', error);
    }
  }
}