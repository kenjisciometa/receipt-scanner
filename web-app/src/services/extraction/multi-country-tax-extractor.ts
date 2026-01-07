/**
 * Multi-Country Tax Breakdown Extraction System
 * 
 * Comprehensive system for extracting tax information from receipts
 * across different countries, languages, and formatting styles.
 */

import { LanguageKeywords, SupportedLanguage } from '@/services/keywords/language-keywords';
import { MultilingualPatternGenerator } from '@/services/patterns/multilingual-pattern-generator';

export interface TaxBreakdownEntry {
  rate: number;           // Tax rate as percentage (e.g., 19.0 for 19%)
  net_amount?: number;    // Net amount before tax
  tax_amount: number;     // Tax amount for this rate
  currency?: string;      // Currency symbol
  confidence: number;     // Extraction confidence 0-1
}

export interface CountryTaxProfile {
  country_code: string;          // ISO country code (US, DE, FI, etc.)
  tax_name: string;              // VAT, GST, Sales Tax, etc.
  common_rates: number[];        // Common tax rates for the country
  format_patterns: TaxFormatPattern[];
  currency_position: 'prefix' | 'suffix';
  decimal_separator: '.' | ',';
}

export interface TaxFormatPattern {
  pattern_type: 'table' | 'inline' | 'section' | 'summary';
  regex_pattern: RegExp;
  extraction_method: string;
  confidence_weight: number;
}

export interface MultiCountryTaxResult {
  detected_country?: string;
  detected_format: string;
  tax_breakdown: TaxBreakdownEntry[];
  tax_total: number;
  extraction_confidence: number;
  extraction_source: string;
  debug_info?: any;
}

/**
 * Country-specific tax extraction profiles
 */
export class CountryTaxProfiles {
  private static readonly PROFILES: Record<string, CountryTaxProfile> = {
    US: {
      country_code: 'US',
      tax_name: 'Sales Tax',
      common_rates: [7.25, 8.25, 9.25, 10.25], // Common US sales tax rates
      currency_position: 'prefix',
      decimal_separator: '.',
      format_patterns: [] // Will be populated by generator
    },
    DE: {
      country_code: 'DE',
      tax_name: 'MwSt',
      common_rates: [19.0, 7.0], // German VAT rates
      currency_position: 'suffix',
      decimal_separator: ',',
      format_patterns: []
    },
    FI: {
      country_code: 'FI',
      tax_name: 'ALV',
      common_rates: [24.0, 14.0, 10.0], // Finnish VAT rates
      currency_position: 'suffix',
      decimal_separator: ',',
      format_patterns: []
    },
    FR: {
      country_code: 'FR',
      tax_name: 'TVA',
      common_rates: [20.0, 10.0, 5.5, 2.1], // French VAT rates
      currency_position: 'suffix',
      decimal_separator: ',',
      format_patterns: []
    },
    GB: {
      country_code: 'GB',
      tax_name: 'VAT',
      common_rates: [20.0, 5.0, 0.0], // UK VAT rates
      currency_position: 'prefix',
      decimal_separator: '.',
      format_patterns: []
    },
    SE: {
      country_code: 'SE',
      tax_name: 'Moms',
      common_rates: [25.0, 12.0, 6.0], // Swedish VAT rates
      currency_position: 'suffix',
      decimal_separator: ',',
      format_patterns: []
    }
  };

  static getProfile(countryCode: string): CountryTaxProfile | null {
    return this.PROFILES[countryCode.toUpperCase()] || null;
  }

  static getAllProfiles(): CountryTaxProfile[] {
    return Object.values(this.PROFILES);
  }

  static detectCountryFromLanguage(language: SupportedLanguage): string | null {
    const languageToCountry: Record<SupportedLanguage, string> = {
      'en': 'US',
      'de': 'DE',
      'fi': 'FI',
      'fr': 'FR',
      'sv': 'SE',
      'it': 'IT',
      'es': 'ES'
    };
    return languageToCountry[language] || null;
  }
}

/**
 * Adaptive tax pattern detector for different receipt formats
 */
export class TaxPatternDetector {
  
  /**
   * Generate country-specific tax extraction patterns
   */
  static generateTaxPatterns(countryCode: string, language: SupportedLanguage): TaxFormatPattern[] {
    const profile = CountryTaxProfiles.getProfile(countryCode);
    if (!profile) return [];

    const patterns: TaxFormatPattern[] = [];
    
    // Pattern 1: Table format detection
    patterns.push({
      pattern_type: 'table',
      regex_pattern: this.generateTablePattern(language, profile),
      extraction_method: 'extractFromTable',
      confidence_weight: 0.9
    });

    // Pattern 2: Inline format (US style)
    patterns.push({
      pattern_type: 'inline',
      regex_pattern: this.generateInlinePattern(language, profile),
      extraction_method: 'extractFromInline',
      confidence_weight: 0.8
    });

    // Pattern 3: Section format (German/Nordic style)
    patterns.push({
      pattern_type: 'section',
      regex_pattern: this.generateSectionPattern(language, profile),
      extraction_method: 'extractFromSection',
      confidence_weight: 0.85
    });

    // Pattern 4: Summary format (tax total only)
    patterns.push({
      pattern_type: 'summary',
      regex_pattern: this.generateSummaryPattern(language, profile),
      extraction_method: 'extractFromSummary',
      confidence_weight: 0.6
    });

    return patterns;
  }

  private static generateTablePattern(language: SupportedLanguage, profile: CountryTaxProfile): RegExp {
    const taxKeywords = LanguageKeywords.getKeywords('tax', language);
    const rateKeywords = ['rate', 'satz', '%', 'procent', 'taux', 'aliquota'];
    
    // Table header detection
    const headerPattern = `(?:${taxKeywords.join('|')}).*(?:${rateKeywords.join('|')})`;
    
    // Table row pattern: Rate + Amount
    const decSep = profile.decimal_separator === ',' ? '[,.]' : '\\.';
    const rowPattern = `(\\d+${decSep}?\\d*)\\s*%.*?(\\d+${decSep}\\d{2})`;
    
    return new RegExp(`${headerPattern}[\\s\\S]*?${rowPattern}`, 'gi');
  }

  private static generateInlinePattern(language: SupportedLanguage, profile: CountryTaxProfile): RegExp {
    const taxKeywords = LanguageKeywords.getKeywords('tax', language);
    const decSep = profile.decimal_separator === ',' ? '[,.]' : '\\.';
    
    // US style: "TAX 1 7.89% 2.90"
    const pattern = `(?:${taxKeywords.join('|')})\\s*\\d*\\s*(\\d+${decSep}?\\d*)\\s*%\\s*(\\d+${decSep}\\d{2})`;
    
    return new RegExp(pattern, 'gi');
  }

  private static generateSectionPattern(language: SupportedLanguage, profile: CountryTaxProfile): RegExp {
    const taxKeywords = LanguageKeywords.getKeywords('tax', language);
    const decSep = profile.decimal_separator === ',' ? '[,.]' : '\\.';
    
    // German style: "MwSt 19% €2.87"
    const pattern = `(?:${taxKeywords.join('|')})\\s*(\\d+${decSep}?\\d*)\\s*%.*?(\\d+${decSep}\\d{2})`;
    
    return new RegExp(pattern, 'gi');
  }

  private static generateSummaryPattern(language: SupportedLanguage, profile: CountryTaxProfile): RegExp {
    const taxKeywords = LanguageKeywords.getKeywords('tax', language);
    const totalKeywords = LanguageKeywords.getKeywords('total', language);
    const decSep = profile.decimal_separator === ',' ? '[,.]' : '\\.';
    
    // Tax total only: "Total VAT €3.46"
    const pattern = `(?:${totalKeywords.join('|')})?\\s*(?:${taxKeywords.join('|')}).*?(\\d+${decSep}\\d{2})`;
    
    return new RegExp(pattern, 'gi');
  }
}

/**
 * Main multi-country tax extraction service
 */
export class MultiCountryTaxExtractor {
  
  constructor(
    private debugMode: boolean = false
  ) {}

  /**
   * Extract tax breakdown for any country/format
   */
  async extractTaxBreakdown(
    textLines: string[],
    fullText: string,
    detectedLanguage: SupportedLanguage = 'en'
  ): Promise<MultiCountryTaxResult> {
    
    if (this.debugMode) {
      console.log(`🌍 Starting multi-country tax extraction for language: ${detectedLanguage}`);
    }

    // Step 1: Detect country from language/text content
    const detectedCountry = this.detectCountry(fullText, detectedLanguage);
    
    // Step 2: Get country profile and patterns
    const profile = CountryTaxProfiles.getProfile(detectedCountry);
    if (!profile) {
      return this.createFallbackResult('Unknown country profile');
    }

    const patterns = TaxPatternDetector.generateTaxPatterns(detectedCountry, detectedLanguage);
    
    // Step 3: Try each pattern type in order of confidence
    const extractionAttempts: Array<{ result: TaxBreakdownEntry[], confidence: number, source: string }> = [];
    
    for (const pattern of patterns.sort((a, b) => b.confidence_weight - a.confidence_weight)) {
      try {
        const result = await this.applyPattern(pattern, textLines, fullText, profile);
        if (result.length > 0) {
          extractionAttempts.push({
            result,
            confidence: pattern.confidence_weight * this.calculateExtractionQuality(result),
            source: pattern.pattern_type
          });
        }
      } catch (error) {
        if (this.debugMode) {
          console.log(`❌ Pattern ${pattern.pattern_type} failed:`, error);
        }
      }
    }

    // Step 4: Select best result
    if (extractionAttempts.length === 0) {
      return this.createFallbackResult('No patterns matched');
    }

    const bestAttempt = extractionAttempts.reduce((best, current) => 
      current.confidence > best.confidence ? current : best
    );

    const taxTotal = bestAttempt.result.reduce((sum, entry) => sum + entry.tax_amount, 0);

    return {
      detected_country: detectedCountry,
      detected_format: bestAttempt.source,
      tax_breakdown: bestAttempt.result,
      tax_total: taxTotal,
      extraction_confidence: bestAttempt.confidence,
      extraction_source: `multi-country-${bestAttempt.source}`,
      debug_info: this.debugMode ? {
        attempted_patterns: patterns.length,
        successful_extractions: extractionAttempts.length,
        country_profile: profile
      } : undefined
    };
  }

  private detectCountry(text: string, language: SupportedLanguage): string {
    // Method 1: Strong currency pattern detection
    const strongCurrencyPatterns = {
      '\\$\\s*\\d+[.,]\\d{2}': 'US', // $23.09 format
      '€\\s*\\d+[.,]\\d{2}': 'DE',   // €23.09 format  
      '\\d+[.,]\\d{2}\\s*€': 'DE',   // 23.09€ format
      '£\\s*\\d+[.,]\\d{2}': 'GB',   // £23.09 format
      '\\d+[.,]\\d{2}\\s*kr': 'SE'   // 23.09kr format
    };

    for (const [pattern, country] of Object.entries(strongCurrencyPatterns)) {
      if (new RegExp(pattern, 'i').test(text)) {
        if (this.debugMode) {
          console.log(`🏛️ Country detected by currency pattern: ${country}`);
        }
        return country;
      }
    }

    // Method 2: Currency symbol detection (fallback)
    const currencyHints = {
      '€': ['DE', 'FI', 'FR'],
      '$': ['US'],
      '£': ['GB'],
      'kr': ['SE', 'FI'],
      'SEK': ['SE'],
      'NOK': ['NO']
    };

    for (const [currency, countries] of Object.entries(currencyHints)) {
      if (text.includes(currency)) {
        // If multiple countries use same currency, use language to disambiguate
        if (countries.length === 1) return countries[0];
        
        const languageCountry = CountryTaxProfiles.detectCountryFromLanguage(language);
        if (languageCountry && countries.includes(languageCountry)) {
          return languageCountry;
        }
        return countries[0];
      }
    }

    // Method 3: Tax terminology detection
    const taxTermHints = {
      'mwst': 'DE',
      'ust': 'DE',
      'alv': 'FI',
      'moms': 'SE',
      'tva': 'FR',
      'vat': 'GB',
      'sales tax': 'US'
    };

    const lowerText = text.toLowerCase();
    for (const [term, country] of Object.entries(taxTermHints)) {
      if (lowerText.includes(term)) {
        if (this.debugMode) {
          console.log(`🏛️ Country detected by tax term: ${country} (${term})`);
        }
        return country;
      }
    }

    // Method 4: Receipt format patterns
    const receiptFormatHints = {
      'wall-mart': 'US',
      'walmart': 'US', 
      'target': 'US',
      'subtotal.*tax.*total': 'US', // Common US retail format
      'zwischensumme.*mwst': 'DE',
      'yhteensä.*alv': 'FI',
      'delsumma.*moms': 'SE'
    };

    for (const [pattern, country] of Object.entries(receiptFormatHints)) {
      if (new RegExp(pattern, 'i').test(text)) {
        if (this.debugMode) {
          console.log(`🏛️ Country detected by receipt format: ${country} (${pattern})`);
        }
        return country;
      }
    }

    // Fallback to language-based detection
    return CountryTaxProfiles.detectCountryFromLanguage(language) || 'US';
  }

  private async applyPattern(
    pattern: TaxFormatPattern,
    textLines: string[],
    fullText: string,
    profile: CountryTaxProfile
  ): Promise<TaxBreakdownEntry[]> {
    
    switch (pattern.extraction_method) {
      case 'extractFromTable':
        return this.extractFromTable(pattern.regex_pattern, textLines, profile);
      case 'extractFromInline':
        return this.extractFromInline(pattern.regex_pattern, fullText, profile);
      case 'extractFromSection':
        return this.extractFromSection(pattern.regex_pattern, textLines, profile);
      case 'extractFromSummary':
        return this.extractFromSummary(pattern.regex_pattern, fullText, profile);
      default:
        return [];
    }
  }

  private extractFromTable(pattern: RegExp, textLines: string[], profile: CountryTaxProfile): TaxBreakdownEntry[] {
    const entries: TaxBreakdownEntry[] = [];
    
    // Find table region
    let inTable = false;
    let tableLines: string[] = [];
    
    for (const line of textLines) {
      if (pattern.test(line)) {
        inTable = true;
        tableLines = [];
        continue;
      }
      
      if (inTable) {
        if (line.trim().length === 0 || /^[=\-_\s]+$/.test(line)) {
          break; // End of table
        }
        tableLines.push(line);
      }
    }

    // Extract from table rows
    const decSep = profile.decimal_separator === ',' ? ',' : '.';
    const rowPattern = new RegExp(`(\\d+[${decSep}]?\\d*)\\s*%.*?(\\d+[${decSep}]\\d{2})`, 'gi');
    
    for (const line of tableLines) {
      const match = rowPattern.exec(line);
      if (match) {
        const rate = parseFloat(match[1].replace(',', '.'));
        const amount = parseFloat(match[2].replace(',', '.'));
        
        entries.push({
          rate,
          tax_amount: amount,
          confidence: 0.9
        });
      }
    }

    return entries;
  }

  private extractFromInline(pattern: RegExp, text: string, profile: CountryTaxProfile): TaxBreakdownEntry[] {
    const entries: TaxBreakdownEntry[] = [];
    let match;
    
    while ((match = pattern.exec(text)) !== null) {
      const rate = parseFloat(match[1].replace(',', '.'));
      const amount = parseFloat(match[2].replace(',', '.'));
      
      entries.push({
        rate,
        tax_amount: amount,
        confidence: 0.8
      });
    }

    return entries;
  }

  private extractFromSection(pattern: RegExp, textLines: string[], profile: CountryTaxProfile): TaxBreakdownEntry[] {
    const entries: TaxBreakdownEntry[] = [];
    
    for (const line of textLines) {
      const match = pattern.exec(line);
      if (match) {
        const rate = parseFloat(match[1].replace(',', '.'));
        const amount = parseFloat(match[2].replace(',', '.'));
        
        entries.push({
          rate,
          tax_amount: amount,
          confidence: 0.85
        });
      }
    }

    return entries;
  }

  private extractFromSummary(pattern: RegExp, text: string, profile: CountryTaxProfile): TaxBreakdownEntry[] {
    const match = pattern.exec(text);
    if (!match) return [];

    const amount = parseFloat(match[1].replace(',', '.'));
    
    // For summary only, we don't know the rate, so use most common rate for country
    const assumedRate = profile.common_rates[0] || 0;
    
    return [{
      rate: assumedRate,
      tax_amount: amount,
      confidence: 0.6 // Lower confidence for summary-only extraction
    }];
  }

  private calculateExtractionQuality(entries: TaxBreakdownEntry[]): number {
    if (entries.length === 0) return 0;
    
    // Quality factors:
    // 1. Number of entries (more detailed is better)
    // 2. Confidence scores
    // 3. Reasonable tax rates (0-30% range)
    
    const avgConfidence = entries.reduce((sum, e) => sum + e.confidence, 0) / entries.length;
    const reasonableRates = entries.filter(e => e.rate >= 0 && e.rate <= 30).length / entries.length;
    const completenessBonus = Math.min(entries.length / 3, 1); // Up to 3 tax rates is excellent
    
    return avgConfidence * reasonableRates * (0.7 + 0.3 * completenessBonus);
  }

  private createFallbackResult(reason: string): MultiCountryTaxResult {
    return {
      detected_format: 'fallback',
      tax_breakdown: [],
      tax_total: 0,
      extraction_confidence: 0,
      extraction_source: `fallback: ${reason}`
    };
  }
}