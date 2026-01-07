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
import { UniversalTaxExtractor, UniversalTaxResult } from './universal/universal-tax-extractor';
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
  private universalTaxExtractor: UniversalTaxExtractor;
  private config: EvidenceFusionConfig;

  constructor(config: Partial<EvidenceFusionConfig> = {}) {
    this.config = { ...DEFAULT_EVIDENCE_FUSION_CONFIG, ...config };
    this.fusionEngine = new TaxBreakdownFusionEngine(this.config);
    this.multiCountryTaxExtractor = new MultiCountryTaxExtractor(config.enableDebugLogging || false);
    this.universalTaxExtractor = new UniversalTaxExtractor({
      enableLearning: !config.enableDebugLogging, // Disable learning in debug mode for consistency
      minConfidenceThreshold: 0.3,
      maxCandidatesPerSection: 10,
      enableFallbackMethods: true,
      debugMode: config.enableDebugLogging || false
    });
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
    
    let evidenceBasedFailed = false;
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
      evidenceBasedFailed = true;
      // Create empty result to continue processing
      evidenceBasedResult = {
        tax_breakdown: [],
        tax_total: 0,
        subtotal: 0,
        tax_amount: 0,
        total: 0,
        evidence_summary: {
          totalEvidencePieces: 0,
          sourcesUsed: [],
          averageConfidence: 0,
          consistencyScore: 0,
          warnings: ['Evidence-Based Fusion failed']
        },
        validation: {
          clusters: [],
          overallConfidence: 0,
          checksPerformed: [],
          warnings: [],
          mathematicalConsistency: 0,
          spatialConsistency: 0
        },
        processingMetadata: {
          evidenceCollectionTime: 0,
          validationTime: 0,
          fusionTime: 0,
          totalProcessingTime: 0
        }
      };
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

    // Phase 2b: Universal Tax Extraction
    console.log(`🌍 [Phase 2b] Starting universal tax extraction...`);
    let universalTaxResult: UniversalTaxResult | null = null;
    
    try {
      const textLinesArray = textLines.map(tl => tl.text);
      universalTaxResult = await this.universalTaxExtractor.extractTaxInformation(
        textLinesArray, 
        language
      );
      console.log(`✅ [Phase 2b] Universal tax extraction completed:`, {
        entries: universalTaxResult.taxEntries.length,
        totalTax: universalTaxResult.taxTotal,
        confidence: universalTaxResult.extractionConfidence,
        primaryMethod: universalTaxResult.detectionSummary.primaryMethod
      });
    } catch (error) {
      console.warn(`⚠️ [Phase 2b] Universal tax extraction failed:`, error);
    }
    
    console.log(`🔧 [Phase 2c] Extracting supplementary fields...`);
    const supplementaryData = await this.extractSupplementaryFields(textLines, fullText, language);
    
    // Phase 3: Result Fusion and Validation
    console.log(`🔄 [Phase 3] Fusing results and validating...`);
    const finalResult = this.fuseResults(evidenceBasedResult, supplementaryData, documentTypeResult, multiCountryTaxResult, universalTaxResult);
    
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
    multiCountryTaxResult?: MultiCountryTaxResult | null,
    universalTaxResult?: UniversalTaxResult | null
  ): ExtractionResult {
    // Select best financial values from all sources
    const bestFinancialData = this.selectBestFinancialData(evidenceResult, multiCountryTaxResult, universalTaxResult);
    
    return {
      // Core financial data from best available source
      subtotal: bestFinancialData.subtotal,
      tax_total: bestFinancialData.tax_total,
      total: bestFinancialData.total,
      currency: bestFinancialData.currency,
      
      // Tax breakdown - prioritize best extraction method
      tax_breakdown: this.selectBestTaxBreakdown(evidenceResult.tax_breakdown, multiCountryTaxResult, universalTaxResult),
      
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
   * Select the best financial data from all extraction methods
   */
  private selectBestFinancialData(
    evidenceResult: EvidenceBasedExtractedData,
    multiCountryResult?: MultiCountryTaxResult | null,
    universalResult?: UniversalTaxResult | null
  ) {
    // Check Universal Tax Extractor first for scattered tax patterns
    if (universalResult && universalResult.taxEntries.length > 0) {
      // Find subtotal and total from Universal result structure
      const subtotal = universalResult.detectionSummary.structuralAnalysis?.taxRelevantSections?.[0]?.subtotal;
      const total = universalResult.detectionSummary.structuralAnalysis?.taxRelevantSections?.[0]?.total;
      
      if (subtotal && total && universalResult.taxTotal > 0) {
        console.log(`🌍 [FuseResults] Using Universal Tax Extractor financial data`);
        return {
          subtotal,
          tax_total: universalResult.taxTotal,
          total,
          currency: 'USD' // Default, could be enhanced
        };
      }
    }
    
    // Check Multi-Country Tax Extractor
    if (multiCountryResult && multiCountryResult.tax_breakdown.length > 0) {
      console.log(`🌍 [FuseResults] Using Multi-Country Tax Extractor financial data`);
      return {
        subtotal: evidenceResult.subtotal || null, // Use Evidence-Based Fusion for subtotal
        tax_total: multiCountryResult.tax_total,
        total: evidenceResult.total || null, // Use Evidence-Based Fusion for total
        currency: evidenceResult.currency || null // Use Evidence-Based Fusion for currency
      };
    }
    
    // Fall back to Evidence-Based result
    console.log(`🧠 [FuseResults] Using Evidence-Based Fusion financial data`);
    return {
      subtotal: evidenceResult.subtotal || null,
      tax_total: evidenceResult.tax_amount || null,
      total: evidenceResult.total || 0,
      currency: evidenceResult.currency || undefined
    };
  }

  /**
   * Select the best tax breakdown among all extraction methods
   */
  private selectBestTaxBreakdown(
    evidenceBreakdown: TaxBreakdown[] = [],
    multiCountryResult?: MultiCountryTaxResult | null,
    universalResult?: UniversalTaxResult | null
  ): TaxBreakdown[] {
    const candidates: Array<{
      breakdown: TaxBreakdown[];
      confidence: number;
      source: string;
    }> = [];

    // Add evidence-based breakdown
    if (evidenceBreakdown.length > 0) {
      const avgConfidence = evidenceBreakdown.reduce((sum, t) => sum + (t.confidence || 0), 0) / evidenceBreakdown.length;
      candidates.push({
        breakdown: evidenceBreakdown,
        confidence: avgConfidence,
        source: 'evidence-based'
      });
    }

    // Add multi-country breakdown
    if (multiCountryResult && multiCountryResult.tax_breakdown.length > 0) {
      const multiCountryBreakdown: TaxBreakdown[] = multiCountryResult.tax_breakdown.map(entry => ({
        rate: entry.rate,
        amount: entry.tax_amount,
        net: entry.net_amount || 0,
        description: `${entry.rate}% ${multiCountryResult.detected_country || 'Tax'}`,
        confidence: entry.confidence,
        supportingEvidence: 1
      }));

      candidates.push({
        breakdown: multiCountryBreakdown,
        confidence: multiCountryResult.extraction_confidence,
        source: 'multi-country'
      });
    }

    // Add universal breakdown
    if (universalResult && universalResult.taxEntries.length > 0) {
      const universalBreakdown: TaxBreakdown[] = universalResult.taxEntries.map(entry => ({
        rate: entry.rate || 0,
        amount: entry.taxAmount,
        net: entry.taxableAmount || 0,
        gross: entry.grossAmount,
        description: entry.detectionMethod,
        confidence: entry.confidence,
        supportingEvidence: 1
      }));

      candidates.push({
        breakdown: universalBreakdown,
        confidence: universalResult.extractionConfidence,
        source: 'universal'
      });
    }

    // If no candidates, return empty
    if (candidates.length === 0) {
      return [];
    }

    // Select best candidate based on confidence and completeness
    const bestCandidate = candidates.reduce((best, current) => {
      // Factor in both confidence and number of entries
      const currentScore = current.confidence * (1 + current.breakdown.length * 0.1);
      const bestScore = best.confidence * (1 + best.breakdown.length * 0.1);
      
      return currentScore > bestScore ? current : best;
    });

    console.log(`🔄 Selected ${bestCandidate.source} tax breakdown (${bestCandidate.breakdown.length} entries, confidence: ${bestCandidate.confidence})`);
    
    return bestCandidate.breakdown;
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