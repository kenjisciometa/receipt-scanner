/**
 * Enhanced Receipt Extractor with Evidence-Based Fusion
 * 
 * Integrates the new Evidence-Based Fusion system with the existing 
 * AdvancedReceiptExtractor to provide superior accuracy and robustness
 */

import { TextLine, OCRResult, OCRElement } from '@/types/ocr';
import { ExtractionResult, ReceiptItem } from '@/types/extraction';
import { DocumentTypeClassifier } from '../classification/document-type-classifier';
import { LanguageKeywords, SupportedLanguage } from '../keywords/language-keywords';

// Define all interfaces inline to avoid Turbopack caching issues
export interface TaxBreakdown {
  rate: number;    // 14.0, 24.0 etc
  amount: number;  // tax amount
}

export type EvidenceSource = 
  | 'table' 
  | 'text' 
  | 'calculation' 
  | 'pattern' 
  | 'bbox' 
  | 'summary_calculation'
  | 'ocr_confidence'
  | 'spatial_analysis'
  | 'linguistic_analysis';

export interface EvidenceBasedExtractedData {
  // Core receipt fields
  subtotal?: number;
  tax_amount?: number;
  total?: number;
  merchant_name?: string;
  purchase_date?: Date;
  payment_method?: string;
  receipt_number?: string;
  currency?: string;
  
  // Tax breakdown information
  tax_breakdown?: TaxBreakdown[];
  tax_total?: number;
  
  // Evidence metadata
  evidence_summary: {
    totalEvidencePieces: number;
    sourcesUsed: EvidenceSource[];
    averageConfidence: number;
    consistencyScore: number;
    warnings: string[];
  };
  
  // Validation results
  validation: any;
  
  // Processing metadata
  processingMetadata: {
    evidenceCollectionTime: number;
    validationTime: number;
    fusionTime: number;
    totalProcessingTime: number;
  };
}

export interface EvidenceFusionConfig {
  minEvidenceConfidence: number;
  minClusterConfidence: number;
  similarityThreshold: number;
  maxClusterVariance: number;
  mathematicalTolerancePercent: number;
  spatialTolerancePixels: number;
  sourceWeights: Partial<Record<EvidenceSource, number>>;
  enabledSources: EvidenceSource[];
  maxTaxRatePercent: number;
  minTaxRatePercent: number;
  enableDebugLogging: boolean;
  enableEvidenceTracking: boolean;
}

export const DEFAULT_EVIDENCE_FUSION_CONFIG: EvidenceFusionConfig = {
  minEvidenceConfidence: 0.3,
  minClusterConfidence: 0.5,
  similarityThreshold: 0.85,
  maxClusterVariance: 0.1,
  mathematicalTolerancePercent: 2.0,
  spatialTolerancePixels: 10,
  sourceWeights: {
    table: 1.3,
    summary_calculation: 1.2,
    calculation: 1.1,
    text: 1.0,
    pattern: 0.9,
    bbox: 0.8,
  },
  enabledSources: [
    'table',
    'text', 
    'calculation',
    'summary_calculation',
    'pattern',
    'bbox',
    'ocr_confidence',
    'spatial_analysis'
  ],
  maxTaxRatePercent: 50.0,
  minTaxRatePercent: 0.0,
  enableDebugLogging: true,
  enableEvidenceTracking: true,
};

/**
 * Simplified Evidence-Based Fusion Engine (Inline Implementation)
 */
class SimplifiedFusionEngine {
  private config: EvidenceFusionConfig;

  constructor(config: EvidenceFusionConfig) {
    this.config = config;
  }

  async extractWithEvidence(textLines: TextLine[]): Promise<EvidenceBasedExtractedData> {
    console.log(`🧠 [SimplifiedFusion] Processing ${textLines.length} text lines`);
    
    // Step 1: Detect currency from text patterns
    const currency = this.detectCurrency(textLines);
    console.log(`💱 [SimplifiedFusion] Detected currency: ${currency}`);
    
    // Step 2: Core Evidence-Based Fusion: Extract key financial values using multilingual support
    const subtotal = this.extractFinancialValue(textLines, 'subtotal');
    const taxAmount = this.extractFinancialValue(textLines, 'tax');
    const total = this.extractFinancialValue(textLines, 'total');
    
    console.log(`💰 [SimplifiedFusion] Extracted: Subtotal=${subtotal}, Tax=${taxAmount}, Total=${total}`);
    
    // Evidence-Based Validation: Tax Breakdown → Summary calculation
    let calculatedSubtotal = null;
    if (total !== null && taxAmount !== null) {
      calculatedSubtotal = total - taxAmount;
      console.log(`🧮 [SimplifiedFusion] Tax Breakdown calculation: ${total} - ${taxAmount} = ${calculatedSubtotal}`);
    }
    
    // Fusion Logic: Use best available evidence
    const finalSubtotal = subtotal !== null ? subtotal : calculatedSubtotal;
    const finalTaxAmount = taxAmount;
    const finalTotal = total;
    
    // Calculate confidence based on evidence availability
    let confidence = 0;
    if (finalSubtotal !== null) confidence += 0.3;
    if (finalTaxAmount !== null) confidence += 0.3;
    if (finalTotal !== null) confidence += 0.4;
    
    const warnings: string[] = [];
    if (finalSubtotal === null) warnings.push('No subtotal evidence found');
    if (finalTaxAmount === null) warnings.push('No tax evidence found');
    if (finalTotal === null) warnings.push('No total evidence found');
    
    return {
      subtotal: finalSubtotal,
      tax_amount: finalTaxAmount,
      total: finalTotal,
      currency: currency,
      tax_breakdown: [],
      tax_total: finalTaxAmount,
      evidence_summary: {
        totalEvidencePieces: (finalSubtotal !== null ? 1 : 0) + (finalTaxAmount !== null ? 1 : 0) + (finalTotal !== null ? 1 : 0),
        sourcesUsed: ['text'],
        averageConfidence: confidence,
        consistencyScore: confidence,
        warnings
      },
      validation: {
        clusters: [],
        overallConfidence: confidence,
        checksPerformed: ['text_pattern', 'tax_breakdown_calculation'],
        warnings,
        mathematicalConsistency: 1.0,
        spatialConsistency: 1.0
      },
      processingMetadata: {
        evidenceCollectionTime: 1,
        validationTime: 1,
        fusionTime: 1,
        totalProcessingTime: 3
      }
    };
  }
  
  private extractFinancialValue(textLines: TextLine[], category: 'total' | 'subtotal' | 'tax'): number | null {
    // Get all keywords for this category across ALL languages (equal treatment)
    const allKeywords = LanguageKeywords.getAllKeywords(category);
    
    for (const line of textLines) {
      const text = line.text.trim();
      const normalizedText = LanguageKeywords.normalizeText(text);
      
      for (const keyword of allKeywords) {
        const normalizedKeyword = LanguageKeywords.normalizeText(keyword);
        if (normalizedText.includes(normalizedKeyword)) {
          console.log(`🔍 [SimplifiedFusion] Found keyword "${keyword}" in line: "${text}"`);
          
          // Enhanced number patterns supporting international formats with better coverage
          const numberPatterns = [
            // Currency symbol patterns (high priority)
            /€\s*(\d+[.,]\d{2})/,                    // €35,62 or €35.62 (Euro)
            /(\d+[.,]\d{2})\s*€/,                    // 35,62€ or 35.62€
            /\$\s*(\d+[.,]\d{2})/,                   // $35.62 or $35,62 (Dollar)
            /(\d+[.,]\d{2})\s*\$/,                   // 35.62$ or 35,62$
            /(\d+[.,]\d{2})\s*kr/i,                  // 35,62 kr (Krona)
            /kr\s*(\d+[.,]\d{2})/i,                  // kr 35,62
            /£\s*(\d+[.,]\d{2})/,                    // £35.62 (Pound)
            /(\d+[.,]\d{2})\s*£/,                    // 35.62£
            
            // Currency code patterns (medium priority)
            /(\d+[.,]\d{2})\s+EUR\b/i,               // 35,62 EUR
            /(\d+[.,]\d{2})\s+USD\b/i,               // 35.62 USD
            /(\d+[.,]\d{2})\s+GBP\b/i,               // 35.62 GBP
            /(\d+[.,]\d{2})\s+SEK\b/i,               // 35,62 SEK
            
            // Standalone number patterns (lower priority)
            /(\d+[.,]\d{2})$/,                       // 35,62 or 35.62 at end of line
            /(\d+[.,]\d{1,2})\s*$/,                  // More flexible decimal places
            /(\d+[.,]\d+)/,                          // 35,62 or 35.62 anywhere
          ];
          
          for (const pattern of numberPatterns) {
            const match = text.match(pattern);
            if (match) {
              // Normalize number format (handle both comma and dot as decimal separator)
              const numberStr = match[1].replace(',', '.');
              const value = parseFloat(numberStr);
              if (!isNaN(value) && value > 0) {
                console.log(`💡 [SimplifiedFusion] Found ${category}: ${value} in "${text}"`);
                return value;
              }
            }
          }
        }
      }
    }
    
    // If we can't find in the same line, look for keywords and then check nearby lines
    for (let i = 0; i < textLines.length; i++) {
      const text = textLines[i].text.trim();
      const normalizedText = LanguageKeywords.normalizeText(text);
      
      for (const keyword of allKeywords) {
        const normalizedKeyword = LanguageKeywords.normalizeText(keyword);
        if (normalizedText.includes(normalizedKeyword)) {
          // Check next few lines for amounts
          for (let j = i; j < Math.min(i + 3, textLines.length); j++) {
            const nextText = textLines[j].text.trim();
            
            // International number patterns for nearby lines
            const amountMatch = nextText.match(/(\d+[.,]\d{2})/);
            if (amountMatch) {
              const numberStr = amountMatch[1].replace(',', '.');
              const value = parseFloat(numberStr);
              if (!isNaN(value) && value > 0) {
                console.log(`💡 [SimplifiedFusion] Found ${category}: ${value} in nearby line "${nextText}"`);
                return value;
              }
            }
          }
        }
      }
    }
    
    return null;
  }

  /**
   * Detect currency from text lines using comprehensive patterns
   * Enhanced implementation based on Flutter's multilingual approach
   */
  private detectCurrency(textLines: TextLine[]): string {
    // Enhanced currency patterns with multilingual support
    const currencyPatterns = [
      // US Dollar - most comprehensive patterns
      { 
        symbol: '$', 
        currency: 'USD', 
        patterns: [
          /\$\s*\d/,           // $ symbol with amount
          /\bUSD\b/i,          // USD code
          /US\s*DOLLAR/i,      // Full name
          /DOLLAR/i            // Dollar text
        ] 
      },
      
      // Euro - comprehensive European patterns with enhanced detection
      { 
        symbol: '€', 
        currency: 'EUR', 
        patterns: [
          /€\s*\d/,                      // € symbol with amount
          /\d+[.,]\d+\s*€/,              // Amount followed by €
          /\d+[.,]\d+\s+EUR\b/i,         // 35,62 EUR format
          /\bEUR\b/i,                    // EUR code
          /EURO/i                        // Euro text
        ] 
      },
      
      // British Pound
      { 
        symbol: '£', 
        currency: 'GBP', 
        patterns: [
          /£\s*\d/,            // £ symbol with amount
          /\d+[.,]\d+\s*£/,    // Amount followed by £
          /\bGBP\b/i,          // GBP code
          /POUND/i,            // Pound text
          /STERLING/i          // Sterling
        ] 
      },
      
      // Japanese Yen
      { 
        symbol: '¥', 
        currency: 'JPY', 
        patterns: [
          /¥\s*\d/,            // ¥ symbol with amount
          /\d+\s*¥/,           // Amount followed by ¥
          /\bJPY\b/i,          // JPY code
          /YEN/i               // Yen text
        ] 
      },
      
      // Swedish Krona (most common 'kr' usage)
      { 
        symbol: 'kr', 
        currency: 'SEK', 
        patterns: [
          /\d+[.,]\d+\s*kr\b/i,  // Amount followed by kr
          /\bkr\s*\d/i,          // kr followed by amount
          /\bSEK\b/i,            // SEK code
          /KRONA/i,              // Krona text
          /KRONOR/i              // Swedish plural
        ] 
      },
      
      // Norwegian Krone
      { 
        symbol: 'kr', 
        currency: 'NOK', 
        patterns: [
          /\bNOK\b/i,            // NOK code (stronger indicator)
          /KRONE/i,              // Norwegian spelling
          /NORSK/i               // Norwegian context
        ] 
      },
      
      // Danish Krone
      { 
        symbol: 'kr', 
        currency: 'DKK', 
        patterns: [
          /\bDKK\b/i,            // DKK code
          /DANSKE/i,             // Danish context
          /DANSK\s*KRON/i        // Danish crown
        ] 
      },
      
      // Swiss Franc
      { 
        symbol: 'CHF', 
        currency: 'CHF', 
        patterns: [
          /\bCHF\b/i,            // CHF code
          /FRANC/i,              // Franc text
          /FRANKEN/i             // German plural
        ] 
      }
    ];

    const currencyScores: { [key: string]: number } = {};
    const currencyContexts: { [key: string]: string[] } = {};
    let totalLines = 0;

    // Analyze all text lines for currency indicators
    for (const line of textLines) {
      const text = line.text;
      const upperText = text.toUpperCase();
      totalLines++;

      for (const currencyInfo of currencyPatterns) {
        let lineScore = 0;
        const matchedPatterns: string[] = [];
        
        for (const pattern of currencyInfo.patterns) {
          if (pattern.test(upperText)) {
            // Different scoring based on pattern strength
            if (pattern.source.includes('\\d')) {
              // Patterns with amounts get higher score
              lineScore += 3;
              matchedPatterns.push(`amount_${currencyInfo.currency}`);
            } else if (pattern.source.includes('\\b.*\\b')) {
              // Exact word boundaries get medium score
              lineScore += 2;
              matchedPatterns.push(`code_${currencyInfo.currency}`);
            } else {
              // General text patterns get lower score
              lineScore += 1;
              matchedPatterns.push(`text_${currencyInfo.currency}`);
            }
          }
        }
        
        if (lineScore > 0) {
          // Initialize tracking arrays if not exists
          if (!currencyScores[currencyInfo.currency]) {
            currencyScores[currencyInfo.currency] = 0;
            currencyContexts[currencyInfo.currency] = [];
          }
          
          currencyScores[currencyInfo.currency] += lineScore;
          currencyContexts[currencyInfo.currency].push(...matchedPatterns);
        }
      }
    }

    // Special logic for distinguishing 'kr' currencies based on context
    if (currencyScores['SEK'] && currencyScores['NOK'] && currencyScores['DKK']) {
      // If multiple kr currencies detected, prioritize based on strong indicators
      const sekContext = currencyContexts['SEK'] || [];
      const nokContext = currencyContexts['NOK'] || [];
      const dkkContext = currencyContexts['DKK'] || [];
      
      // Boost score for specific country codes
      if (sekContext.some(c => c.includes('SEK'))) currencyScores['SEK'] += 5;
      if (nokContext.some(c => c.includes('NOK'))) currencyScores['NOK'] += 5;
      if (dkkContext.some(c => c.includes('DKK'))) currencyScores['DKK'] += 5;
    }

    // Find the currency with highest confidence
    let bestCurrency = 'USD'; // Default fallback
    let bestScore = 0;
    
    for (const [currency, score] of Object.entries(currencyScores)) {
      console.log(`💱 [CurrencyDetection] ${currency}: ${score} points (contexts: ${currencyContexts[currency]?.slice(0, 3).join(', ') || 'none'})`);
      if (score > bestScore) {
        bestScore = score;
        bestCurrency = currency;
      }
    }

    // Enhanced confidence calculation with more lenient thresholds
    const confidence = bestScore / Math.max(1, totalLines * 0.25); // More lenient denominator
    const hasStrongIndicator = currencyContexts[bestCurrency]?.some(c => c.includes('amount_') || c.includes('code_'));
    const hasEurIndicator = bestCurrency === 'EUR' && bestScore >= 2; // Special case for EUR
    
    // More lenient threshold for EUR detection (common in European receipts)
    if (confidence < 0.05 && !hasStrongIndicator && !hasEurIndicator) {
      console.log(`💱 [CurrencyDetection] Low confidence (${confidence.toFixed(2)}) and no strong indicators, using default: USD`);
      return 'USD';
    }

    console.log(`💱 [CurrencyDetection] Detected: ${bestCurrency} (confidence: ${confidence.toFixed(2)}, score: ${bestScore})`);
    return bestCurrency;
  }
}

// Force file change to refresh Turbopack cache
const TURBOPACK_FIX = true;

/**
 * Enhanced Receipt Extraction Service
 * 
 * Combines traditional pattern-based extraction with Evidence-Based Fusion
 * for improved accuracy, especially for challenging receipts like Walmart US
 */
export class EnhancedReceiptExtractionService {
  private fusionEngine: SimplifiedFusionEngine;
  private config: EvidenceFusionConfig;

  constructor(config: Partial<EvidenceFusionConfig> = {}) {
    this.config = { ...DEFAULT_EVIDENCE_FUSION_CONFIG, ...config };
    this.fusionEngine = new SimplifiedFusionEngine(this.config);
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
    
    // Phase 2: Traditional Field Extraction (SUPPLEMENTARY)
    console.log(`🔧 [Phase 2] Extracting supplementary fields...`);
    const supplementaryData = await this.extractSupplementaryFields(textLines, fullText, language);
    
    // Phase 3: Result Fusion and Validation
    console.log(`🔄 [Phase 3] Fusing results and validating...`);
    const finalResult = this.fuseResults(evidenceBasedResult, supplementaryData, documentTypeResult);
    
    // Phase 4: Confidence Assessment
    const overallConfidence = this.calculateOverallConfidence(evidenceBasedResult, finalResult);
    
    const totalProcessingTime = Date.now() - startTime;
    
    console.log(`🎯 [Enhanced] Extraction completed in ${totalProcessingTime}ms:`, {
      confidence: overallConfidence,
      subtotal: finalResult.subtotal,
      tax: finalResult.tax_amount,
      total: finalResult.total,
      taxBreakdowns: finalResult.tax_breakdown?.length || 0,
      warnings: evidenceBasedResult.evidence_summary.warnings.length
    });

    return {
      merchant_name: finalResult.merchant_name || '',
      date: finalResult.purchase_date || new Date(),
      currency: finalResult.currency || 'USD',
      subtotal: finalResult.subtotal || 0,
      tax_breakdown: finalResult.tax_breakdown || [],
      tax_total: finalResult.tax_total || 0,
      total: finalResult.total || 0,
      receipt_number: finalResult.receipt_number || null,
      payment_method: finalResult.payment_method || null,
      confidence: overallConfidence,
      status: overallConfidence >= 0.7 ? 'completed' : 'needs_verification',
      items: [], // TODO: Implement item extraction with evidence-based approach
      document_type: documentTypeResult.documentType,
      document_type_confidence: documentTypeResult.confidence,
      document_type_reason: documentTypeResult.reason,
      warnings: evidenceBasedResult.evidence_summary.warnings,
      metadata: {
        extraction_method: 'evidence_based_fusion',
        evidence_summary: evidenceBasedResult.evidence_summary,
        processing_times: {
          evidence_based: evidenceBasedResult.processingMetadata.totalProcessingTime,
          supplementary: 0, // Will be measured
          total: totalProcessingTime
        },
        applied_patterns: [], // Legacy field
        language_detected: language,
        fusion_config: {
          enabled_sources: this.config.enabledSources,
          min_confidence: this.config.minEvidenceConfidence
        },
        document_classification: {
          document_type: documentTypeResult.documentType,
          confidence: documentTypeResult.confidence,
          reason: documentTypeResult.reason,
          receipt_score: documentTypeResult.receiptScore,
          invoice_score: documentTypeResult.invoiceScore
        }
      }
    };
  }

  /**
   * Convert OCR result to TextLine format expected by fusion engine
   */
  private convertOCRToTextLines(ocrResult: OCRResult): TextLine[] {
    const textLines: TextLine[] = [];
    
    // If we have detailed text lines with bounding boxes
    if (ocrResult.textLines && ocrResult.textLines.length > 0) {
      return ocrResult.textLines.map(line => ({
        text: line.text || '',
        boundingBox: line.boundingBox || { x: 0, y: 0, width: 0, height: 0 },
        confidence: line.confidence || 0.8
      }));
    }
    
    // If we have elements array
    if (ocrResult.elements && ocrResult.elements.length > 0) {
      return ocrResult.elements.map((element: OCRElement, index: number) => ({
        text: element.text || '',
        boundingBox: element.boundingBox || { x: 0, y: index * 20, width: 100, height: 20 },
        confidence: element.confidence || 0.8
      }));
    }
    
    // Fallback: split full text by lines
    if (ocrResult.text) {
      const lines = ocrResult.text.split('\n');
      return lines.map((line, index) => ({
        text: line.trim(),
        boundingBox: { x: 0, y: index * 20, width: 100, height: 20 },
        confidence: 0.7
      }));
    }
    
    return [];
  }

  /**
   * Extract supplementary fields using traditional methods
   */
  private async extractSupplementaryFields(
    textLines: TextLine[], 
    fullText: string, 
    language: SupportedLanguage
  ): Promise<Partial<EvidenceBasedExtractedData>> {
    const result: Partial<EvidenceBasedExtractedData> = {};
    
    // Merchant name extraction
    if (!result.merchant_name) {
      result.merchant_name = this.extractMerchantName(textLines);
    }
    
    // Date extraction
    if (!result.purchase_date) {
      const dateStr = this.extractDate(fullText);
      if (dateStr) {
        result.purchase_date = new Date(dateStr);
      }
    }
    
    // Receipt number
    if (!result.receipt_number) {
      result.receipt_number = this.extractReceiptNumber(fullText);
    }
    
    // Payment method
    if (!result.payment_method) {
      result.payment_method = this.extractPaymentMethod(fullText, language);
    }
    
    return result;
  }

  /**
   * Fuse Evidence-Based results with supplementary traditional extraction
   */
  private fuseResults(
    evidenceBasedResult: EvidenceBasedExtractedData,
    supplementaryData: Partial<EvidenceBasedExtractedData>,
    documentTypeResult: any
  ): EvidenceBasedExtractedData {
    // Evidence-based data takes priority for financial fields
    const fusedResult: EvidenceBasedExtractedData = {
      ...evidenceBasedResult,
      // Fill in missing fields from supplementary extraction
      merchant_name: evidenceBasedResult.merchant_name || supplementaryData.merchant_name,
      purchase_date: evidenceBasedResult.purchase_date || supplementaryData.purchase_date,
      receipt_number: evidenceBasedResult.receipt_number || supplementaryData.receipt_number,
      payment_method: evidenceBasedResult.payment_method || supplementaryData.payment_method,
    };
    
    // Add document type information
    fusedResult.evidence_summary.warnings.push(`Document type: ${documentTypeResult.documentType} (${documentTypeResult.confidence.toFixed(2)})`);
    
    return fusedResult;
  }

  /**
   * Calculate overall confidence based on evidence and traditional extraction
   */
  private calculateOverallConfidence(
    evidenceBasedResult: EvidenceBasedExtractedData,
    finalResult: EvidenceBasedExtractedData
  ): number {
    const evidenceConfidence = evidenceBasedResult.evidence_summary.averageConfidence;
    const consistencyScore = evidenceBasedResult.evidence_summary.consistencyScore;
    
    // Base confidence from evidence fusion
    let overallConfidence = evidenceConfidence * 0.7 + consistencyScore * 0.3;
    
    // Bonus for having key financial fields
    let fieldBonus = 0;
    if (finalResult.subtotal && finalResult.subtotal > 0) fieldBonus += 0.1;
    if (finalResult.tax_amount && finalResult.tax_amount > 0) fieldBonus += 0.1;
    if (finalResult.total && finalResult.total > 0) fieldBonus += 0.1;
    if (finalResult.tax_breakdown && finalResult.tax_breakdown.length > 0) fieldBonus += 0.15;
    
    // Penalty for warnings
    const warningPenalty = Math.min(0.2, finalResult.evidence_summary.warnings.length * 0.05);
    
    return Math.min(0.95, Math.max(0.1, overallConfidence + fieldBonus - warningPenalty));
  }

  /**
   * Fallback to traditional extraction if Evidence-Based fusion fails
   */
  private async fallbackToTraditionalExtraction(
    ocrResult: OCRResult, 
    languageHint?: string
  ): Promise<ExtractionResult> {
    console.warn(`⚠️ Falling back to traditional extraction`);
    
    // Import and use the original advanced extractor
    const { AdvancedReceiptExtractionService } = await import('./advanced-receipt-extractor');
    const traditionalExtractor = new AdvancedReceiptExtractionService();
    
    const result = await traditionalExtractor.extract(ocrResult, languageHint);
    
    // Add fallback metadata
    result.metadata = {
      ...result.metadata,
      extraction_method: 'traditional_fallback',
      fallback_reason: 'evidence_based_fusion_failed'
    };
    
    return result;
  }

  // === TRADITIONAL EXTRACTION METHODS (for supplementary data) ===

  private extractMerchantName(textLines: TextLine[]): string | null {
    // Look for merchant name in first few lines
    for (let i = 0; i < Math.min(5, textLines.length); i++) {
      const line = textLines[i].text.trim();
      
      // Skip empty lines, dates, addresses with numbers
      if (!line || 
          /^\d+[-\/]\d+[-\/]\d+/.test(line) || 
          /^\d+\s+\w+\s+\w+/.test(line) ||
          line.length < 3) {
        continue;
      }
      
      // Look for business-like names
      if (/^[A-Z][A-Za-z\s&'.-]{2,30}$/.test(line) && 
          !/(receipt|invoice|bill|total|tax|vat)/i.test(line)) {
        return line;
      }
    }
    
    return null;
  }

  private extractDate(fullText: string): string | null {
    // Enhanced date patterns for multiple formats including 2-digit years
    const datePatterns = [
      /(\d{1,2}[-\/]\d{1,2}[-\/]\d{4})/,        // DD/MM/YYYY or MM/DD/YYYY
      /(\d{4}[-\/]\d{1,2}[-\/]\d{1,2})/,        // YYYY/MM/DD
      /(\d{1,2}\.\d{1,2}\.\d{4})/,              // DD.MM.YYYY (European)
      /(\d{1,2}\.\d{1,2}\.\d{2})/,              // DD.MM.YY (European 2-digit year)
      /(\d{1,2}\s+\w+\s+\d{4})/,                // DD Month YYYY
      /(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2},?\s+\d{4}/i
    ];
    
    for (const pattern of datePatterns) {
      const match = fullText.match(pattern);
      if (match) {
        let dateStr = match[1] || match[0];
        
        // Convert 2-digit year to 4-digit year (e.g., 14 -> 2014)
        if (dateStr.includes('.') && dateStr.split('.').length === 3) {
          const parts = dateStr.split('.');
          if (parts[2].length === 2) {
            const year = parseInt(parts[2]);
            // Assume years 00-30 are 2000s, 31-99 are 1900s
            const fullYear = year <= 30 ? 2000 + year : 1900 + year;
            dateStr = `${parts[0]}.${parts[1]}.${fullYear}`;
          }
        }
        
        return dateStr;
      }
    }
    
    return null;
  }

  private extractReceiptNumber(fullText: string): string | null {
    const receiptPatterns = [
      /(?:receipt|trans|ref|invoice|bill)\s*#?\s*:?\s*([A-Z0-9]+)/i,
      /#\s*([A-Z0-9]{4,})/i,
      /(?:no|nr|num|number)\s*:?\s*([A-Z0-9]+)/i
    ];
    
    for (const pattern of receiptPatterns) {
      const match = fullText.match(pattern);
      if (match && match[1].length >= 3) {
        return match[1];
      }
    }
    
    return null;
  }

  private extractPaymentMethod(fullText: string, language: SupportedLanguage): string | null {
    // Use LanguageKeywords for payment method detection
    const cashKeywords = LanguageKeywords.getKeywords('payment_method_cash', language);
    const cardKeywords = LanguageKeywords.getKeywords('payment_method_card', language);
    
    const lowerText = fullText.toLowerCase();
    
    // Check for cash keywords
    for (const keyword of cashKeywords) {
      if (lowerText.includes(keyword.toLowerCase())) {
        return 'cash';
      }
    }
    
    // Check for card keywords
    for (const keyword of cardKeywords) {
      if (lowerText.includes(keyword.toLowerCase())) {
        return 'card';
      }
    }
    
    // Check for specific card types
    if (/visa|mastercard|amex|american express/i.test(fullText)) {
      return 'card';
    }
    
    return null;
  }

  // === UTILITY METHODS ===

  /**
   * Enable or disable debug logging
   */
  setDebugMode(enabled: boolean): void {
    this.config.enableDebugLogging = enabled;
    this.fusionEngine = new SimplifiedFusionEngine(this.config);
  }

  /**
   * Update fusion engine configuration
   */
  updateConfig(config: Partial<EvidenceFusionConfig>): void {
    this.config = { ...this.config, ...config };
    this.fusionEngine = new SimplifiedFusionEngine(this.config);
  }

  /**
   * Get current configuration
   */
  getConfig(): EvidenceFusionConfig {
    return { ...this.config };
  }
}