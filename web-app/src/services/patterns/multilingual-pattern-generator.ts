/**
 * Multilingual Pattern Generator
 * 
 * Centralized system for generating language-specific regex patterns
 * for receipt field extraction. This replaces scattered hardcoded patterns
 * with a unified, maintainable approach.
 */

import { LanguageKeywords, SupportedLanguage, KeywordCategory } from '@/services/keywords/language-keywords';

/**
 * Pattern generation options for different field types and languages
 */
export interface PatternOptions {
  /** Allow optional currency symbols */
  includeCurrency?: boolean;
  /** Allow flexible separators (:, -, =, etc.) */
  flexibleSeparators?: boolean;
  /** Support both prefix and suffix currency positions */
  supportBothCurrencyPositions?: boolean;
  /** Allow optional whitespace variations */
  flexibleWhitespace?: boolean;
  /** Case insensitive matching */
  caseInsensitive?: boolean;
  /** Support decimal variations (. vs ,) */
  supportDecimalVariations?: boolean;
}

/**
 * Language-specific formatting rules
 */
export interface LanguageFormatConfig {
  /** Common separators between label and amount */
  separators: string[];
  /** Currency symbol positioning */
  currencyPosition: 'prefix' | 'suffix' | 'both';
  /** Decimal separator preference */
  decimalSeparator: '.' | ',';
  /** Thousands separator */
  thousandsSeparator?: ',' | '.' | ' ';
  /** Common amount formats */
  amountFormats: string[];
}

/**
 * Centralized multilingual pattern generator
 */
export class MultilingualPatternGenerator {
  
  /**
   * Language-specific formatting configurations
   */
  private static readonly LANGUAGE_FORMATS: Record<SupportedLanguage, LanguageFormatConfig> = {
    en: {
      separators: [':', '-', '=', '\\s+'],
      currencyPosition: 'prefix',
      decimalSeparator: '.',
      thousandsSeparator: ',',
      amountFormats: ['\\$?\\s*\\d+[.,]\\d{2}', '\\d+[.,]\\d{2}\\s*\\$?']
    },
    de: {
      separators: [':', '-', '=', '\\s+'],
      currencyPosition: 'suffix',
      decimalSeparator: ',',
      thousandsSeparator: '.',
      amountFormats: ['\\d+[.,]\\d{2}\\s*€?', '€?\\s*\\d+[.,]\\d{2}']
    },
    fi: {
      separators: [':', '-', '=', '\\s+'],
      currencyPosition: 'suffix',
      decimalSeparator: ',',
      thousandsSeparator: ' ',
      amountFormats: ['\\d+[.,]\\d{2}\\s*€?', '€?\\s*\\d+[.,]\\d{2}']
    },
    sv: {
      separators: [':', '-', '=', '\\s+'],
      currencyPosition: 'suffix',
      decimalSeparator: ',',
      thousandsSeparator: ' ',
      amountFormats: ['\\d+[.,]\\d{2}\\s*kr?', 'kr?\\s*\\d+[.,]\\d{2}']
    },
    fr: {
      separators: [':', '-', '=', '\\s+'],
      currencyPosition: 'suffix',
      decimalSeparator: ',',
      thousandsSeparator: ' ',
      amountFormats: ['\\d+[.,]\\d{2}\\s*€?', '€?\\s*\\d+[.,]\\d{2}']
    },
    it: {
      separators: [':', '-', '=', '\\s+'],
      currencyPosition: 'suffix',
      decimalSeparator: ',',
      thousandsSeparator: '.',
      amountFormats: ['\\d+[.,]\\d{2}\\s*€?', '€?\\s*\\d+[.,]\\d{2}']
    },
    es: {
      separators: [':', '-', '=', '\\s+'],
      currencyPosition: 'suffix',
      decimalSeparator: ',',
      thousandsSeparator: '.',
      amountFormats: ['\\d+[.,]\\d{2}\\s*€?', '€?\\s*\\d+[.,]\\d{2}']
    }
  };

  /**
   * Default pattern options
   */
  private static readonly DEFAULT_OPTIONS: PatternOptions = {
    includeCurrency: true,
    flexibleSeparators: true,
    supportBothCurrencyPositions: true,
    flexibleWhitespace: true,
    caseInsensitive: true,
    supportDecimalVariations: true
  };

  /**
   * Generate field extraction pattern for specific language and category
   */
  static generateFieldPattern(
    category: KeywordCategory,
    language: SupportedLanguage,
    options: Partial<PatternOptions> = {}
  ): RegExp {
    const mergedOptions = { ...this.DEFAULT_OPTIONS, ...options };
    const keywords = LanguageKeywords.getKeywords(category, language);
    const formatConfig = this.LANGUAGE_FORMATS[language];

    if (keywords.length === 0) {
      throw new Error(`No keywords found for category '${category}' in language '${language}'`);
    }

    // Build keyword pattern
    const escapedKeywords = keywords.map(keyword => 
      keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    );
    const keywordPattern = `(?:${escapedKeywords.join('|')})`;

    // Build separator pattern
    const separatorPattern = mergedOptions.flexibleSeparators 
      ? `\\s*(?:${formatConfig.separators.join('|')})\\s*`
      : '\\s*:\\s*';

    // Build amount pattern
    const amountPattern = this.buildAmountPattern(formatConfig, mergedOptions);

    // Combine patterns
    const fullPattern = `${keywordPattern}${separatorPattern}(${amountPattern})`;

    const flags = mergedOptions.caseInsensitive ? 'gi' : 'g';
    return new RegExp(fullPattern, flags);
  }

  /**
   * Generate patterns for multiple languages
   */
  static generateMultiLanguagePattern(
    category: KeywordCategory,
    languages: SupportedLanguage[],
    options: Partial<PatternOptions> = {}
  ): RegExp {
    const patterns = languages.map(lang => {
      const pattern = this.generateFieldPattern(category, lang, options);
      return pattern.source;
    });

    const combinedPattern = patterns.join('|');
    const flags = options.caseInsensitive !== false ? 'gi' : 'g';
    return new RegExp(combinedPattern, flags);
  }

  /**
   * Generate tax breakdown pattern for specific language
   */
  static generateTaxBreakdownPattern(
    language: SupportedLanguage,
    options: Partial<PatternOptions> = {}
  ): RegExp {
    const mergedOptions = { ...this.DEFAULT_OPTIONS, ...options };
    const taxKeywords = LanguageKeywords.getKeywords('tax', language);
    const formatConfig = this.LANGUAGE_FORMATS[language];

    // Tax breakdown pattern: "tax keyword rate% amount"
    const escapedTaxKeywords = taxKeywords.map(keyword => 
      keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    );
    const taxPattern = `(?:${escapedTaxKeywords.join('|')})`;
    
    const ratePattern = '(\\d+(?:[.,]\\d+)?)\\s*%';
    const amountPattern = this.buildAmountPattern(formatConfig, mergedOptions);

    const fullPattern = `${taxPattern}\\s*${ratePattern}.*?(${amountPattern})`;
    
    const flags = mergedOptions.caseInsensitive ? 'gi' : 'g';
    return new RegExp(fullPattern, flags);
  }

  /**
   * Generate table header detection pattern
   */
  static generateTableHeaderPattern(
    language: SupportedLanguage,
    options: Partial<PatternOptions> = {}
  ): RegExp {
    const mergedOptions = { ...this.DEFAULT_OPTIONS, ...options };
    
    // Get keywords for common table columns
    const taxKeywords = LanguageKeywords.getKeywords('tax', language);
    const itemHeaders = LanguageKeywords.getKeywords('item_table_header', language);
    
    // Common table header indicators
    const headerKeywords = [
      ...taxKeywords,
      ...itemHeaders.filter(header => 
        ['rate', '%', 'percent', 'gross', 'net', 'brutto', 'netto', 'steuer', 'mwst', 'ust'].some(key =>
          header.toLowerCase().includes(key)
        )
      )
    ];

    if (headerKeywords.length === 0) {
      // Fallback to common patterns
      const fallbackPatterns = {
        en: ['vat', 'tax', 'rate', 'gross', 'net'],
        de: ['ust', 'mwst', 'steuer', 'brutto', 'netto'],
        fi: ['alv', 'vero', 'brutto', 'netto'],
        sv: ['moms', 'brutto', 'netto'],
        fr: ['tva', 'taxe', 'brut', 'net'],
        it: ['iva', 'imposta', 'lordo', 'netto'],
        es: ['iva', 'impuesto', 'bruto', 'neto']
      };
      headerKeywords.push(...fallbackPatterns[language]);
    }

    const escapedKeywords = headerKeywords.map(keyword => 
      keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    );

    // Pattern for table headers (must contain tax + amount/rate indicators)
    const taxPattern = `(?:${escapedKeywords.filter(k => 
      ['tax', 'vat', 'mwst', 'alv', 'moms', 'ust', 'steuer', 'iva', 'tva'].some(tax => 
        k.toLowerCase().includes(tax)
      )
    ).join('|')})`;
    
    const amountPattern = `(?:${escapedKeywords.filter(k => 
      ['gross', 'net', 'rate', '%', 'brutto', 'netto', 'amount'].some(amount => 
        k.toLowerCase().includes(amount)
      )
    ).join('|')})`;

    const fullPattern = `${taxPattern}.*${amountPattern}|${amountPattern}.*${taxPattern}`;
    
    const flags = mergedOptions.caseInsensitive ? 'i' : '';
    return new RegExp(fullPattern, flags);
  }

  /**
   * Get language-specific amount parsing pattern
   */
  static getAmountParsingPattern(language: SupportedLanguage): RegExp {
    const formatConfig = this.LANGUAGE_FORMATS[language];
    const amountPattern = this.buildAmountPattern(formatConfig, this.DEFAULT_OPTIONS);
    return new RegExp(`(${amountPattern})`, 'g');
  }

  /**
   * Build amount pattern based on language formatting rules
   */
  private static buildAmountPattern(
    formatConfig: LanguageFormatConfig,
    options: PatternOptions
  ): string {
    if (!options.includeCurrency) {
      // Just numeric pattern with decimal variations
      return options.supportDecimalVariations 
        ? '\\d+[.,]\\d{2}'
        : `\\d+[${formatConfig.decimalSeparator}]\\d{2}`;
    }

    // Use pre-defined amount formats from language config
    if (options.supportBothCurrencyPositions) {
      return formatConfig.amountFormats.join('|');
    }

    // Use position-specific format
    const preferredFormat = formatConfig.currencyPosition === 'prefix' 
      ? formatConfig.amountFormats[0]
      : formatConfig.amountFormats[formatConfig.amountFormats.length - 1];
    
    return preferredFormat;
  }

  /**
   * Get all supported pattern categories
   */
  static getSupportedCategories(): KeywordCategory[] {
    return LanguageKeywords.getAllCategories();
  }

  /**
   * Get formatting configuration for language
   */
  static getLanguageFormat(language: SupportedLanguage): LanguageFormatConfig {
    return this.LANGUAGE_FORMATS[language];
  }

  /**
   * Validate if pattern works for given text
   */
  static testPattern(pattern: RegExp, testText: string): {
    matches: boolean;
    results: RegExpMatchArray[];
  } {
    const matches = Array.from(testText.matchAll(pattern));
    return {
      matches: matches.length > 0,
      results: matches
    };
  }

  /**
   * Generate debug information for pattern
   */
  static debugPattern(
    category: KeywordCategory,
    language: SupportedLanguage,
    options: Partial<PatternOptions> = {}
  ): {
    pattern: RegExp;
    keywords: string[];
    formatConfig: LanguageFormatConfig;
    options: PatternOptions;
  } {
    const pattern = this.generateFieldPattern(category, language, options);
    const keywords = LanguageKeywords.getKeywords(category, language);
    const formatConfig = this.LANGUAGE_FORMATS[language];
    const mergedOptions = { ...this.DEFAULT_OPTIONS, ...options };

    return {
      pattern,
      keywords,
      formatConfig,
      options: mergedOptions
    };
  }
}

/**
 * Convenience class for common pattern operations
 */
export class PatternUtils {
  
  /**
   * Generate all extraction patterns for a language
   */
  static generateAllExtractionPatterns(language: SupportedLanguage): {
    subtotal: RegExp;
    total: RegExp;
    tax: RegExp;
    taxBreakdown: RegExp;
    tableHeader: RegExp;
  } {
    return {
      subtotal: MultilingualPatternGenerator.generateFieldPattern('subtotal', language),
      total: MultilingualPatternGenerator.generateFieldPattern('total', language),
      tax: MultilingualPatternGenerator.generateFieldPattern('tax', language),
      taxBreakdown: MultilingualPatternGenerator.generateTaxBreakdownPattern(language),
      tableHeader: MultilingualPatternGenerator.generateTableHeaderPattern(language)
    };
  }

  /**
   * Generate patterns for multiple languages
   */
  static generateMultiLanguageExtractionPatterns(languages: SupportedLanguage[]): {
    subtotal: RegExp;
    total: RegExp;
    tax: RegExp;
  } {
    return {
      subtotal: MultilingualPatternGenerator.generateMultiLanguagePattern('subtotal', languages),
      total: MultilingualPatternGenerator.generateMultiLanguagePattern('total', languages),
      tax: MultilingualPatternGenerator.generateMultiLanguagePattern('tax', languages)
    };
  }
}