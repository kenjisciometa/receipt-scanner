/**
 * Enhanced Keyword Detector
 * 
 * Phase 1 implementation: Enhanced keyword detection using existing infrastructure
 * Implements Stage 1 of the 3-stage tax table detection strategy
 */

import { BoundingBox, ProcessedTextLine, SupportedLanguage } from '../../types';
import { CentralizedKeywordConfig, ExtendedFieldType } from '../keywords/centralized-keyword-config';
import { LanguageKeywords } from '../keywords/language-keywords';

/**
 * Tax keyword detection result with enhanced metadata
 */
export interface TaxKeywordDetectionResult {
  taxKeywords: Array<{
    keyword: string;
    language: SupportedLanguage;
    confidence: number;
    boundingBox: BoundingBox;
    type: 'primary_tax' | 'net_amount' | 'gross_amount' | 'tax_rate';
    lineIndex: number;
    fieldType: ExtendedFieldType;
  }>;
  numericPatterns: Array<{
    value: string;
    type: 'percentage' | 'currency' | 'decimal';
    confidence: number;
    boundingBox: BoundingBox;
    lineIndex: number;
    normalizedValue?: number;
  }>;
  structuralKeywords: Array<{
    keyword: string;
    type: 'header' | 'separator' | 'total';
    boundingBox: BoundingBox;
    lineIndex: number;
    confidence: number;
  }>;
  detectedLanguages: Array<{
    language: SupportedLanguage;
    confidence: number;
    evidenceCount: number;
  }>;
}

/**
 * Numeric pattern detection result
 */
interface NumericPattern {
  value: string;
  type: 'percentage' | 'currency' | 'decimal';
  confidence: number;
  normalizedValue: number;
  currency?: string;
}

/**
 * Enhanced tax keyword detector implementing Stage 1 of 3-stage detection
 */
export class EnhancedKeywordDetector {
  private patterns = {
    // Enhanced percentage patterns
    percentage: /(\d+(?:[.,]\d+)?)\s*%/g,
    
    // Multi-currency patterns
    currency: /((?:\$|€|£|¥|kr|SEK|EUR|USD)\s*)?(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?)\s*(€|kr|SEK|EUR|USD)?/g,
    
    // Decimal number patterns
    decimal: /\b(\d+(?:[.,]\d{2}))\b/g,
    
    // Tax rate patterns (language-specific)
    taxRate: /(ALV|VAT|MOMS|TVA|IVA|UST|MwSt)[.\s]*(\d+(?:[.,]?\d*)?)\s*%/gi,
    
    // Tax amount patterns
    taxAmount: /(TAX|VERO|IMPOSTA|STEUER|MOMS|TVA|IVA)[.\s]*((?:\$|€|£|¥|kr)?\s*\d+(?:[.,]\d{2})?)/gi,
    
    // Finnish ALV specific patterns
    alvTable: /(ALV)\s+(VEROTON|NET)\s+(VERO|TAX)\s+(VEROLLINEN|GROSS)/gi,
    
    // Swedish MOMS patterns  
    momsTable: /(MOMS)\s+(?:EXKL\.?|INKL\.?)/gi,
    
    // French TVA patterns
    tvaTable: /(HT|VEROTON)\s+(TVA)\s+(TTC|VEROLLINEN)/gi
  };

  constructor(
    private keywordConfig: typeof CentralizedKeywordConfig,
    private languageKeywords: LanguageKeywords
  ) {}

  /**
   * Main detection method implementing Stage 1 of 3-stage strategy
   */
  detectTaxKeywords(textLines: ProcessedTextLine[]): TaxKeywordDetectionResult {
    const result: TaxKeywordDetectionResult = {
      taxKeywords: [],
      numericPatterns: [],
      structuralKeywords: [],
      detectedLanguages: []
    };

    // Step 1: Detect languages present in the text
    const languageResults = this.detectLanguages(textLines);
    result.detectedLanguages = languageResults;

    // Step 2: Multi-language tax keyword detection
    for (const langResult of languageResults) {
      const taxKeywords = this.detectTaxKeywordsForLanguage(textLines, langResult.language);
      result.taxKeywords.push(...taxKeywords);
    }

    // Step 3: Numeric pattern detection with type classification
    result.numericPatterns = this.detectNumericPatterns(textLines);

    // Step 4: Structural keyword identification
    result.structuralKeywords = this.detectStructuralKeywords(textLines);

    // Step 5: Cross-reference and enhance confidence scores
    this.enhanceConfidenceScores(result);

    return result;
  }

  /**
   * Detect languages present in the receipt text
   */
  private detectLanguages(textLines: ProcessedTextLine[]): Array<{
    language: SupportedLanguage;
    confidence: number;
    evidenceCount: number;
  }> {
    const languages: SupportedLanguage[] = ['en', 'fi', 'de', 'sv', 'fr', 'it', 'es'];
    const languageScores = new Map<SupportedLanguage, { score: number; evidence: number }>();

    // Initialize scores
    languages.forEach(lang => {
      languageScores.set(lang, { score: 0, evidence: 0 });
    });

    // Score based on tax keyword presence
    const taxFieldTypes: ExtendedFieldType[] = ['tax', 'tax_rate', 'tax_amount', 'subtotal', 'total'];
    
    for (const line of textLines) {
      const text = line.text.toLowerCase();
      
      for (const lang of languages) {
        let langScore = 0;
        let evidence = 0;

        for (const fieldType of taxFieldTypes) {
          const keywords = this.keywordConfig.getKeywordTexts(fieldType, lang);
          
          for (const keyword of keywords) {
            if (text.includes(keyword.toLowerCase())) {
              const confidence = this.keywordConfig.getKeywordConfidence(fieldType, lang, keyword);
              langScore += confidence;
              evidence++;
            }
          }
        }

        const current = languageScores.get(lang)!;
        current.score += langScore;
        current.evidence += evidence;
      }
    }

    // Convert to result format and sort by confidence
    return Array.from(languageScores.entries())
      .map(([language, data]) => ({
        language,
        confidence: data.evidence > 0 ? data.score / data.evidence : 0,
        evidenceCount: data.evidence
      }))
      .filter(result => result.evidenceCount > 0)
      .sort((a, b) => b.confidence - a.confidence);
  }

  /**
   * Detect tax keywords for a specific language
   */
  private detectTaxKeywordsForLanguage(
    textLines: ProcessedTextLine[], 
    language: SupportedLanguage
  ): TaxKeywordDetectionResult['taxKeywords'] {
    const taxKeywords: TaxKeywordDetectionResult['taxKeywords'] = [];
    
    // Define tax-related field types to search for
    const taxFieldTypes: Array<{ fieldType: ExtendedFieldType; type: 'primary_tax' | 'net_amount' | 'gross_amount' | 'tax_rate' }> = [
      { fieldType: 'tax', type: 'primary_tax' },
      { fieldType: 'tax_rate', type: 'tax_rate' },
      { fieldType: 'tax_amount', type: 'primary_tax' },
      { fieldType: 'net_amount', type: 'net_amount' },
      { fieldType: 'gross_amount', type: 'gross_amount' },
      { fieldType: 'subtotal', type: 'net_amount' },
      { fieldType: 'total', type: 'gross_amount' }
    ];

    for (let lineIndex = 0; lineIndex < textLines.length; lineIndex++) {
      const line = textLines[lineIndex];
      const text = line.text.toLowerCase();

      for (const { fieldType, type } of taxFieldTypes) {
        const keywords = this.keywordConfig.getKeywords(fieldType, language);
        
        for (const keywordEntry of keywords) {
          const keyword = keywordEntry.text.toLowerCase();
          const regex = new RegExp(`\\b${this.escapeRegex(keyword)}\\b`, 'gi');
          const matches = text.matchAll(regex);

          for (const match of matches) {
            taxKeywords.push({
              keyword: keywordEntry.text,
              language,
              confidence: keywordEntry.confidence || 0.8,
              boundingBox: line.boundingBox,
              type,
              lineIndex,
              fieldType
            });
          }
        }
      }
    }

    return taxKeywords;
  }

  /**
   * Detect and classify numeric patterns
   */
  private detectNumericPatterns(textLines: ProcessedTextLine[]): TaxKeywordDetectionResult['numericPatterns'] {
    const numericPatterns: TaxKeywordDetectionResult['numericPatterns'] = [];

    for (let lineIndex = 0; lineIndex < textLines.length; lineIndex++) {
      const line = textLines[lineIndex];
      const text = line.text;

      // Detect percentages
      const percentageMatches = text.matchAll(this.patterns.percentage);
      for (const match of percentageMatches) {
        const value = match[1].replace(',', '.');
        const normalizedValue = parseFloat(value);
        
        if (!isNaN(normalizedValue) && normalizedValue >= 0 && normalizedValue <= 100) {
          numericPatterns.push({
            value: match[0],
            type: 'percentage',
            confidence: 0.95,
            boundingBox: line.boundingBox,
            lineIndex,
            normalizedValue
          });
        }
      }

      // Detect currency amounts
      const currencyMatches = text.matchAll(this.patterns.currency);
      for (const match of currencyMatches) {
        const prefix = match[1];
        const amount = match[2];
        const suffix = match[3];
        const currency = prefix || suffix;
        
        if (amount) {
          const normalizedAmount = this.normalizeCurrencyAmount(amount);
          if (!isNaN(normalizedAmount)) {
            numericPatterns.push({
              value: match[0],
              type: 'currency',
              confidence: currency ? 0.9 : 0.7,
              boundingBox: line.boundingBox,
              lineIndex,
              normalizedValue: normalizedAmount
            });
          }
        }
      }

      // Detect decimal numbers (not already captured as currency)
      const decimalMatches = text.matchAll(this.patterns.decimal);
      for (const match of decimalMatches) {
        // Skip if already captured as currency or percentage
        const alreadyCaptured = numericPatterns.some(pattern => 
          pattern.lineIndex === lineIndex && 
          pattern.value.includes(match[1])
        );
        
        if (!alreadyCaptured) {
          const normalizedValue = this.normalizeCurrencyAmount(match[1]);
          if (!isNaN(normalizedValue)) {
            numericPatterns.push({
              value: match[0],
              type: 'decimal',
              confidence: 0.8,
              boundingBox: line.boundingBox,
              lineIndex,
              normalizedValue
            });
          }
        }
      }
    }

    return numericPatterns;
  }

  /**
   * Detect structural keywords that indicate table organization
   */
  private detectStructuralKeywords(textLines: ProcessedTextLine[]): TaxKeywordDetectionResult['structuralKeywords'] {
    const structuralKeywords: TaxKeywordDetectionResult['structuralKeywords'] = [];

    // Header patterns for different table types
    const headerPatterns = [
      // Finnish ALV table headers
      { pattern: /(ALV)\s+(VEROTON|NET)\s+(VERO|TAX)\s+(VEROLLINEN|GROSS)/gi, type: 'header' as const },
      // Swedish MOMS table headers  
      { pattern: /(MOMS)\s+(EXKL\.?)\s+(MOMS)\s+(INKL\.?)/gi, type: 'header' as const },
      // French TVA table headers
      { pattern: /(HT)\s+(TVA)\s+(TTC)/gi, type: 'header' as const },
      // General table headers
      { pattern: /(TAX\s+RATE|TAX\s+AMOUNT|NET\s+AMOUNT|GROSS\s+AMOUNT)/gi, type: 'header' as const }
    ];

    // Separator patterns
    const separatorPatterns = [
      { pattern: /[-=]{3,}/g, type: 'separator' as const },
      { pattern: /[.]{3,}/g, type: 'separator' as const }
    ];

    // Total indicators
    const totalPatterns = [
      { pattern: /(TOTAL|SUMMA|YHTEENSÄ|GESAMT|TOTALT|SOMME|TOTALE|SUMA)/gi, type: 'total' as const }
    ];

    for (let lineIndex = 0; lineIndex < textLines.length; lineIndex++) {
      const line = textLines[lineIndex];
      const text = line.text;

      // Check all pattern types
      const allPatterns = [...headerPatterns, ...separatorPatterns, ...totalPatterns];
      
      for (const { pattern, type } of allPatterns) {
        const matches = text.matchAll(pattern);
        for (const match of matches) {
          structuralKeywords.push({
            keyword: match[0],
            type,
            boundingBox: line.boundingBox,
            lineIndex,
            confidence: type === 'header' ? 0.9 : type === 'total' ? 0.85 : 0.7
          });
        }
      }
    }

    return structuralKeywords;
  }

  /**
   * Enhance confidence scores based on cross-references
   */
  private enhanceConfidenceScores(result: TaxKeywordDetectionResult): void {
    // Boost confidence for tax keywords that have nearby numeric patterns
    for (const taxKeyword of result.taxKeywords) {
      const nearbyNumbers = result.numericPatterns.filter(pattern => 
        Math.abs(pattern.lineIndex - taxKeyword.lineIndex) <= 1
      );

      if (nearbyNumbers.length > 0) {
        // Boost confidence based on relevant numeric patterns
        for (const number of nearbyNumbers) {
          if (taxKeyword.type === 'tax_rate' && number.type === 'percentage') {
            taxKeyword.confidence = Math.min(0.98, taxKeyword.confidence * 1.2);
          } else if (taxKeyword.type === 'primary_tax' && number.type === 'currency') {
            taxKeyword.confidence = Math.min(0.95, taxKeyword.confidence * 1.1);
          }
        }
      }
    }

    // Boost confidence for consistent language detection
    if (result.detectedLanguages.length === 1) {
      const dominantLanguage = result.detectedLanguages[0].language;
      
      for (const taxKeyword of result.taxKeywords) {
        if (taxKeyword.language === dominantLanguage) {
          taxKeyword.confidence = Math.min(0.98, taxKeyword.confidence * 1.1);
        }
      }
    }

    // Boost confidence for structured table patterns
    const hasTableStructure = result.structuralKeywords.some(sk => sk.type === 'header');
    if (hasTableStructure) {
      for (const taxKeyword of result.taxKeywords) {
        taxKeyword.confidence = Math.min(0.95, taxKeyword.confidence * 1.05);
      }
    }
  }

  /**
   * Normalize currency amount to decimal number
   */
  private normalizeCurrencyAmount(amount: string): number {
    // Remove thousands separators and normalize decimal separator
    let normalized = amount;
    
    // Check if European format (comma as decimal separator)
    if (amount.includes(',') && amount.includes('.')) {
      // Format like "1.234,56" -> remove dots, keep comma as decimal
      normalized = amount.replace(/\./g, '').replace(',', '.');
    } else if (amount.includes(',') && !amount.includes('.')) {
      // Format like "12,34" -> treat comma as decimal separator
      normalized = amount.replace(',', '.');
    } else {
      // US format or simple number
      normalized = amount.replace(/,/g, '');
    }

    return parseFloat(normalized);
  }

  /**
   * Escape regex special characters
   */
  private escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
}