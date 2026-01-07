/**
 * Enhanced Receipt Extractor with Evidence-Based Fusion
 * 
 * Integrates the new Evidence-Based Fusion system with the existing 
 * AdvancedReceiptExtractor to provide superior accuracy and robustness
 */

import { TextLine, OCRResult } from '@/types/ocr';
import { ExtractionResult, ReceiptItem, DocumentType } from '@/types/extraction';
import { DocumentTypeClassifier } from '../classification/document-type-classifier';
import { LanguageKeywords, SupportedLanguage } from '../keywords/language-keywords';
import { TaxBreakdownFusionEngine } from './tax-breakdown-fusion-engine';
import { MultiCountryTaxExtractor, MultiCountryTaxResult } from './multi-country-tax-extractor';
import { 
  EvidenceBasedExtractedData, 
  EvidenceFusionConfig, 
  DEFAULT_EVIDENCE_FUSION_CONFIG, 
  TaxBreakdown, 
  EvidenceSource 
} from '../../types/evidence';

// Force file change to refresh Turbopack cache
const TURBOPACK_FIX = true;

/**
 * Enhanced Receipt Extraction Service
 * 
 * Combines traditional pattern-based extraction with Evidence-Based Fusion
 * for improved accuracy, especially for challenging receipts like Walmart US
 */
export class EnhancedReceiptExtractionService {
  private fusionEngine: TaxBreakdownFusionEngine;
  private multiCountryTaxExtractor: MultiCountryTaxExtractor;
  private config: EvidenceFusionConfig;

  constructor(config: Partial<EvidenceFusionConfig> = {}) {
    this.config = { ...DEFAULT_EVIDENCE_FUSION_CONFIG, ...config };
    this.fusionEngine = new TaxBreakdownFusionEngine(this.config);
    this.multiCountryTaxExtractor = new MultiCountryTaxExtractor(config.enableDebugLogging || false);
  }

  /**
   * Main extraction method with Evidence-Based Fusion
   */
  async extract(ocrResult: OCRResult, languageHint?: string): Promise<ExtractionResult> {
    const startTime = Date.now();
    const language = (languageHint || ocrResult.detected_language || 'en') as SupportedLanguage;
    const textLines = this.convertOCRToTextLines(ocrResult);
    const fullText = ocrResult.text;
    
    console.log(`🔍 [Enhanced] Starting extraction for language: ${language}`);
    console.log(`📊 [Enhanced] Processing ${textLines.length} text lines`);
    
    // Document type classification
    const documentTypeResult = DocumentTypeClassifier.classify(textLines, language);
    console.log(`📋 Document type: ${documentTypeResult.documentType} (confidence: ${documentTypeResult.confidence})`);
    
    // Phase 1: Evidence-Based Fusion Extraction (PRIMARY)
    console.log(`🧠 [Phase 1] Starting Evidence-Based Fusion extraction...`);
    let evidenceBasedResult: EvidenceBasedExtractedData;
    
    try {
      evidenceBasedResult = await this.fusionEngine.extractWithEvidence(textLines);
      console.log(`✅ [Phase 1] Evidence-Based extraction completed:`, {
        evidencePieces: evidenceBasedResult.evidence_summary.totalEvidencePieces,
        sources: evidenceBasedResult.evidence_summary.sourcesUsed,
        confidence: evidenceBasedResult.evidence_summary.averageConfidence,
        processingTime: evidenceBasedResult.processingMetadata.totalProcessingTime
      });
    } catch (error) {
      console.error(`❌ [Phase 1] Evidence-Based extraction failed:`, error);
      // Fall back to traditional extraction
      return this.fallbackToTraditionalExtraction(ocrResult, languageHint);
    }
    
    // Phase 2: Multi-Country Tax Extraction & Supplementary Fields
    console.log(`🌍 [Phase 2a] Starting multi-country tax breakdown extraction...`);
    let multiCountryTaxResult: MultiCountryTaxResult | null = null;
    
    try {
      const textLinesArray = textLines.map(tl => tl.text);
      multiCountryTaxResult = await this.multiCountryTaxExtractor.extractTaxBreakdown(
        textLinesArray, 
        fullText, 
        language
      );
      console.log(`✅ [Phase 2a] Multi-country tax extraction completed:`, {
        country: multiCountryTaxResult.detected_country,
        format: multiCountryTaxResult.detected_format,
        breakdownEntries: multiCountryTaxResult.tax_breakdown.length,
        totalTax: multiCountryTaxResult.tax_total,
        confidence: multiCountryTaxResult.extraction_confidence
      });
    } catch (error) {
      console.warn(`⚠️ [Phase 2a] Multi-country tax extraction failed:`, error);
    }
    
    console.log(`🔧 [Phase 2b] Extracting supplementary fields...`);
    const supplementaryData = await this.extractSupplementaryFields(textLines, fullText, language);
    
    // Phase 3: Result Fusion and Validation
    console.log(`🔄 [Phase 3] Fusing results and validating...`);
    const finalResult = this.fuseResults(evidenceBasedResult, supplementaryData, documentTypeResult, multiCountryTaxResult);
    
    // Phase 4: Confidence Assessment
    const overallConfidence = this.calculateOverallConfidence(evidenceBasedResult, finalResult);
    
    const totalProcessingTime = Date.now() - startTime;
    
    console.log(`🎯 [Enhanced] Extraction completed in ${totalProcessingTime}ms:`, {
      confidence: overallConfidence,
      subtotal: finalResult.subtotal,
      tax: finalResult.tax_total,
      total: finalResult.total,
      currency: finalResult.currency
    });
    
    return {
      ...finalResult,
      confidence: overallConfidence
    };
  }

  /**
   * Convert OCR result to TextLine format for fusion engine
   * Enhanced with Y-coordinate based line grouping for better accuracy
   */
  private convertOCRToTextLines(ocrResult: OCRResult): TextLine[] {
    if (ocrResult.textLines && ocrResult.textLines.length > 0) {
      // Use existing TextLines and apply line grouping
      return this.groupTextLinesByY(ocrResult.textLines);
    } else {
      // Fall back to line-by-line parsing
      const lines = ocrResult.text.split('\n');
      return lines.map((text) => ({
        text: text.trim(),
        confidence: ocrResult.confidence || 1.0,
        boundingBox: [0, 0, 0, 0] as [number, number, number, number]
      }));
    }
  }

  /**
   * Group TextLines by Y-coordinate to reconstruct proper lines
   * This fixes the issue where "Yhteensä" and "35,62" are separated but should be on same line
   */
  private groupTextLinesByY(textLines: TextLine[]): TextLine[] {
    // Sort by Y coordinate first
    const sortedLines = [...textLines].sort((a, b) => {
      const aY = a.boundingBox[1]; // Y coordinate
      const bY = b.boundingBox[1];
      return aY - bY;
    });

    const groupedLines: TextLine[] = [];

    let currentGroup: TextLine[] = [];
    let currentY: number | null = null;

    for (const line of sortedLines) {
      const lineY = line.boundingBox[1];
      
      // Calculate adaptive threshold based on text height
      const lineHeight = line.boundingBox[3]; // Text height
      const adaptiveThreshold = lineHeight * 0.4; // 40% of text height
      const minThreshold = 5; // Minimum 5px
      const maxThreshold = 20; // Maximum 20px
      
      const yTolerance = Math.max(minThreshold, Math.min(adaptiveThreshold, maxThreshold));
      
      // Log adaptive threshold for debugging
      if (textLines.length < 50) { // Only log for smaller receipts to avoid spam
        console.log(`📏 [Adaptive Threshold] "${line.text}" -> height: ${lineHeight}px, threshold: ${yTolerance.toFixed(1)}px`);
      }
      
      // Start new group or add to current group
      const yDifference = currentY !== null ? Math.abs(lineY - currentY) : 0;
      const shouldGroup = currentY === null || yDifference <= yTolerance;
      
      if (shouldGroup) {
        currentGroup.push(line);
        currentY = currentY === null ? lineY : (currentY + lineY) / 2; // Average Y
      } else {
        // Finish current group and start new one
        if (currentGroup.length > 0) {
          groupedLines.push(this.mergeTextLinesInGroup(currentGroup));
        }
        currentGroup = [line];
        currentY = lineY;
      }
    }

    // Don't forget the last group
    if (currentGroup.length > 0) {
      groupedLines.push(this.mergeTextLinesInGroup(currentGroup));
    }

    console.log(`🔗 [Line Grouping] Merged ${textLines.length} text elements into ${groupedLines.length} lines`);
    
    return groupedLines;
  }


  /**
   * Merge multiple TextLines in the same group into one consolidated line
   */
  private mergeTextLinesInGroup(group: TextLine[]): TextLine {
    if (group.length === 1) {
      return group[0];
    }

    // Sort by X coordinate within the group
    const sortedGroup = group.sort((a, b) => {
      const aX = a.boundingBox[0]; // X coordinate
      const bX = b.boundingBox[0];
      return aX - bX;
    });

    // Merge text with space separation
    const mergedText = sortedGroup.map(line => line.text.trim()).filter(text => text.length > 0).join(' ');
    
    // Calculate consolidated bounding box
    const minX = Math.min(...sortedGroup.map(line => line.boundingBox[0]));
    const minY = Math.min(...sortedGroup.map(line => line.boundingBox[1]));
    const maxX = Math.max(...sortedGroup.map(line => line.boundingBox[0] + line.boundingBox[2]));
    const maxY = Math.max(...sortedGroup.map(line => line.boundingBox[1] + line.boundingBox[3]));
    
    const consolidatedBoundingBox: [number, number, number, number] = [
      minX,
      minY, 
      maxX - minX, // width
      maxY - minY  // height
    ];

    // Average confidence
    const avgConfidence = sortedGroup.reduce((sum, line) => sum + line.confidence, 0) / sortedGroup.length;

    const merged: TextLine = {
      text: mergedText,
      confidence: avgConfidence,
      boundingBox: consolidatedBoundingBox,
      merged: group.length > 1 // Set merged flag
    };

    // Log successful merges for debugging
    if (group.length > 1) {
      console.log(`🔗 [Line Merge] "${group.map(g => g.text).join('" + "')}" → "${mergedText}"`);
    }

    return merged;
  }

  /**
   * Extract supplementary fields not handled by fusion engine
   */
  private async extractSupplementaryFields(textLines: TextLine[], fullText: string, language: SupportedLanguage) {
    const result: any = {};
    
    // Extract merchant name
    result.merchant_name = this.extractMerchantName(textLines);
    
    // Extract purchase date
    result.purchase_date = this.extractPurchaseDate(textLines);
    
    // Extract payment method
    result.payment_method = this.extractPaymentMethod(textLines);
    
    // Extract receipt number
    result.receipt_number = this.extractReceiptNumber(textLines);
    
    return result;
  }

  /**
   * Fuse Evidence-Based results with supplementary data and multi-country tax extraction
   */
  private fuseResults(
    evidenceResult: EvidenceBasedExtractedData, 
    supplementary: any, 
    documentType: any, 
    multiCountryTaxResult?: MultiCountryTaxResult | null
  ): ExtractionResult {
    return {
      // Core financial data from Evidence-Based Fusion
      subtotal: evidenceResult.subtotal || null,
      tax_total: evidenceResult.tax_amount || null,
      total: evidenceResult.total || 0,
      currency: evidenceResult.currency || undefined,
      
      // Tax breakdown - prioritize multi-country extraction if available
      tax_breakdown: this.selectBestTaxBreakdown(evidenceResult.tax_breakdown, multiCountryTaxResult),
      
      // Supplementary fields
      merchant_name: evidenceResult.merchant_name || supplementary.merchant_name || null,
      date: evidenceResult.purchase_date || supplementary.purchase_date || null,
      payment_method: evidenceResult.payment_method || supplementary.payment_method || null,
      receipt_number: supplementary.receipt_number || null,
      
      // Document classification
      document_type: documentType.documentType as DocumentType || 'unknown',
      document_type_confidence: documentType.confidence || 0,
      document_type_reason: documentType.factors?.join(', ') || '',
      
      // Required fields
      confidence: 0.5, // Will be overridden by calculateOverallConfidence
      status: 'completed' as const,
      
      // Optional fields
      items: [],
      warnings: evidenceResult.evidence_summary.warnings,
      
      // Evidence metadata
      metadata: {
        extraction_method: 'evidence_based_fusion',
        evidence_summary: evidenceResult.evidence_summary,
        processing_times: evidenceResult.processingMetadata,
        applied_patterns: [],
        language_detected: 'auto',
        fusion_config: null
      }
    };
  }

  /**
   * Select the best tax breakdown between evidence-based and multi-country extraction
   */
  private selectBestTaxBreakdown(
    evidenceBreakdown: TaxBreakdown[] = [],
    multiCountryResult?: MultiCountryTaxResult | null
  ): TaxBreakdown[] {
    if (!multiCountryResult || multiCountryResult.tax_breakdown.length === 0) {
      return evidenceBreakdown;
    }

    // Convert multi-country breakdown to our TaxBreakdown format
    const multiCountryBreakdown: TaxBreakdown[] = multiCountryResult.tax_breakdown.map(entry => ({
      rate: entry.rate,
      amount: entry.tax_amount,  // Map tax_amount to amount field
      net: entry.net_amount || 0,
      description: `${entry.rate}% ${multiCountryResult.detected_country || 'Tax'}`,
      confidence: entry.confidence,
      supportingEvidence: 1 // Multi-country extraction counts as 1 source
    }));

    // If evidence-based has no breakdown, use multi-country
    if (evidenceBreakdown.length === 0) {
      console.log(`🔄 Using multi-country tax breakdown (${multiCountryBreakdown.length} entries)`);
      return multiCountryBreakdown;
    }

    // If multi-country has higher confidence, use it
    const evidenceAvgConfidence = evidenceBreakdown.reduce((sum, t) => sum + (t.confidence || 0), 0) / evidenceBreakdown.length;
    const multiCountryConfidence = multiCountryResult.extraction_confidence;

    if (multiCountryConfidence > evidenceAvgConfidence + 0.1) { // Slight bias toward multi-country
      console.log(`🔄 Switching to multi-country tax breakdown (confidence: ${multiCountryConfidence} > ${evidenceAvgConfidence})`);
      return multiCountryBreakdown;
    }

    // Use evidence-based as fallback
    console.log(`🔄 Using evidence-based tax breakdown (confidence: ${evidenceAvgConfidence} >= ${multiCountryConfidence})`);
    return evidenceBreakdown;
  }

  /**
   * Calculate overall confidence score
   */
  private calculateOverallConfidence(evidenceResult: EvidenceBasedExtractedData, finalResult: ExtractionResult): number {
    const evidenceConfidence = evidenceResult.evidence_summary.averageConfidence;
    const consistencyScore = evidenceResult.evidence_summary.consistencyScore;
    const mathConsistency = evidenceResult.validation.mathematicalConsistency;
    
    // Weighted average of different confidence factors
    return (evidenceConfidence * 0.4 + consistencyScore * 0.3 + mathConsistency * 0.3);
  }

  /**
   * Fallback to traditional extraction when Evidence-Based fails
   */
  private async fallbackToTraditionalExtraction(ocrResult: OCRResult, languageHint?: string): Promise<ExtractionResult> {
    console.log(`🔄 [Fallback] Using traditional extraction...`);
    
    const { AdvancedReceiptExtractionService } = await import('./advanced-receipt-extractor');
    const fallbackService = new AdvancedReceiptExtractionService();
    
    const result = await fallbackService.extract(ocrResult, languageHint);
    
    // Add evidence metadata for consistency
    if (!result.metadata) {
      result.metadata = {};
    }
    result.metadata.evidence_summary = {
      totalEvidencePieces: 0,
      sourcesUsed: ['text'],
      averageConfidence: result.confidence || 0.5,
      consistencyScore: 0.5,
      warnings: ['Fallback to traditional extraction']
    };
    result.metadata.fallback_reason = 'Evidence-Based Fusion failed';
    
    return result;
  }

  // Helper extraction methods for supplementary fields
  private extractMerchantName(textLines: TextLine[]): string | undefined {
    // Simple heuristic: look for merchant name in first few lines
    for (let i = 0; i < Math.min(5, textLines.length); i++) {
      const text = textLines[i].text.trim();
      
      // Skip very short lines or lines that look like addresses/numbers
      if (text.length < 3 || /^\d+$/.test(text) || /^[\d\s\-\.]+$/.test(text)) {
        continue;
      }
      
      // Skip common receipt headers
      if (/^(receipt|transaction|order|invoice|bill)/i.test(text)) {
        continue;
      }
      
      // Return first reasonable line
      if (text.length >= 3 && text.length <= 50) {
        return text;
      }
    }
    
    return undefined;
  }

  private extractPurchaseDate(textLines: TextLine[]): Date | undefined {
    for (const line of textLines) {
      const text = line.text.trim();
      
      // Various date patterns
      const datePatterns = [
        /(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})/,     // MM/DD/YYYY or DD.MM.YY
        /(\d{2,4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2})/,     // YYYY/MM/DD
        /(\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+\d{2,4})/i // DD MMM YYYY
      ];
      
      for (const pattern of datePatterns) {
        const match = text.match(pattern);
        if (match) {
          const dateStr = match[1];
          const parsedDate = new Date(dateStr);
          
          // Validate the date
          if (!isNaN(parsedDate.getTime())) {
            return parsedDate;
          }
        }
      }
    }
    
    return undefined;
  }

  private extractPaymentMethod(textLines: TextLine[]): string | undefined {
    const paymentPatterns = [
      /\b(cash|credit|debit|visa|mastercard|amex|american express|discover|paypal|apple pay|google pay)\b/i
    ];
    
    for (const line of textLines) {
      const text = line.text.trim();
      
      for (const pattern of paymentPatterns) {
        const match = text.match(pattern);
        if (match) {
          return match[1].toLowerCase();
        }
      }
    }
    
    return undefined;
  }

  private extractReceiptNumber(textLines: TextLine[]): string | undefined {
    for (const line of textLines) {
      const text = line.text.trim();
      
      // Look for receipt/transaction/order numbers
      const patterns = [
        /(?:receipt|trans|order|ref)\s*#?\s*:?\s*([a-zA-Z0-9\-]+)/i,
        /(?:invoice|bill)\s*#?\s*:?\s*([a-zA-Z0-9\-]+)/i,
        /#\s*([a-zA-Z0-9\-]{4,})/i
      ];
      
      for (const pattern of patterns) {
        const match = text.match(pattern);
        if (match) {
          return match[1];
        }
      }
    }
    
    return undefined;
  }

  /**
   * Update config
   */
  setConfig(config: Partial<EvidenceFusionConfig>): void {
    this.config = { ...this.config, ...config };
    this.fusionEngine = new TaxBreakdownFusionEngine(this.config);
  }

  /**
   * Get current config
   */
  getConfig(): EvidenceFusionConfig {
    return { ...this.config };
  }
}