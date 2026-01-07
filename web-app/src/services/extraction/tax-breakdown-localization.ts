/**
 * Tax Breakdown Localization Service
 * 
 * Provides multilingual descriptions for tax breakdown categories
 * and rate types across different countries and languages
 */

export interface TaxCategoryLocalization {
  [language: string]: {
    [category: string]: string;
  };
}

export interface TaxRateDescription {
  [language: string]: {
    standard: string;
    reduced: string;
    zero: string;
    category: (code: string, rate: number) => string;
  };
}

/**
 * Tax category localizations
 */
export const TAX_CATEGORY_LOCALIZATIONS: TaxCategoryLocalization = {
  // English
  'en': {
    'A': 'Standard Rate',
    'B': 'Reduced Rate',
    'C': 'Zero Rate',
    'Standard': 'Standard Rate',
    'Reduced': 'Reduced Rate',
    'Zero': 'Zero Rate'
  },
  
  // Finnish
  'fi': {
    'A': 'Normaali arvonlisävero',
    'B': 'Alennettu arvonlisävero',
    'C': 'Nolla-arvonlisävero',
    'Standard': 'Normaali arvonlisävero',
    'Reduced': 'Alennettu arvonlisävero',
    'Zero': 'Nolla-arvonlisävero'
  },
  
  // Swedish
  'sv': {
    'A': 'Normal moms',
    'B': 'Reducerad moms',
    'C': 'Noll moms',
    'Standard': 'Normal moms',
    'Reduced': 'Reducerad moms',
    'Zero': 'Noll moms'
  },
  
  // German
  'de': {
    'A': 'Normaler Steuersatz',
    'B': 'Ermäßigter Steuersatz',
    'C': 'Steuerfreier Satz',
    'Standard': 'Normaler Steuersatz',
    'Reduced': 'Ermäßigter Steuersatz',
    'Zero': 'Steuerfreier Satz'
  },
  
  // French
  'fr': {
    'A': 'Taux normal',
    'B': 'Taux réduit',
    'C': 'Taux zéro',
    'Standard': 'Taux normal',
    'Reduced': 'Taux réduit',
    'Zero': 'Taux zéro'
  },
  
  // Spanish
  'es': {
    'A': 'Tipo general',
    'B': 'Tipo reducido',
    'C': 'Tipo cero',
    'Standard': 'Tipo general',
    'Reduced': 'Tipo reducido',
    'Zero': 'Tipo cero'
  },
  
  // Italian
  'it': {
    'A': 'Aliquota ordinaria',
    'B': 'Aliquota ridotta',
    'C': 'Aliquota zero',
    'Standard': 'Aliquota ordinaria',
    'Reduced': 'Aliquota ridotta',
    'Zero': 'Aliquota zero'
  }
};

/**
 * Tax rate descriptions with dynamic formatting
 */
export const TAX_RATE_DESCRIPTIONS: TaxRateDescription = {
  // English
  'en': {
    standard: 'Standard VAT',
    reduced: 'Reduced VAT',
    zero: 'Zero VAT',
    category: (code: string, rate: number) => `${code} - ${rate}% VAT`
  },
  
  // Finnish
  'fi': {
    standard: 'Normaali ALV',
    reduced: 'Alennettu ALV',
    zero: 'Nolla ALV',
    category: (code: string, rate: number) => `${code} - ${rate}% ALV`
  },
  
  // Swedish
  'sv': {
    standard: 'Normal moms',
    reduced: 'Reducerad moms',
    zero: 'Noll moms',
    category: (code: string, rate: number) => `${code} - ${rate}% moms`
  },
  
  // German
  'de': {
    standard: 'Normale MwSt.',
    reduced: 'Ermäßigte MwSt.',
    zero: 'Steuerfreie MwSt.',
    category: (code: string, rate: number) => `${code} - ${rate}% MwSt.`
  },
  
  // French
  'fr': {
    standard: 'TVA normale',
    reduced: 'TVA réduite',
    zero: 'TVA zéro',
    category: (code: string, rate: number) => `${code} - ${rate}% TVA`
  },
  
  // Spanish
  'es': {
    standard: 'IVA general',
    reduced: 'IVA reducido',
    zero: 'IVA cero',
    category: (code: string, rate: number) => `${code} - ${rate}% IVA`
  },
  
  // Italian
  'it': {
    standard: 'IVA ordinaria',
    reduced: 'IVA ridotta',
    zero: 'IVA zero',
    category: (code: string, rate: number) => `${code} - ${rate}% IVA`
  }
};

/**
 * Tax Breakdown Localization Service
 */
export class TaxBreakdownLocalizationService {
  
  /**
   * Get localized description for tax category
   */
  static getCategoryDescription(
    category: string, 
    language: string = 'en'
  ): string {
    const localizations = TAX_CATEGORY_LOCALIZATIONS[language] || TAX_CATEGORY_LOCALIZATIONS['en'];
    return localizations[category] || category;
  }
  
  /**
   * Get localized description for tax rate type
   */
  static getRateTypeDescription(
    rate: number,
    language: string = 'en'
  ): string {
    const descriptions = TAX_RATE_DESCRIPTIONS[language] || TAX_RATE_DESCRIPTIONS['en'];
    
    // Classify rate type based on common EU rates
    if (rate === 0) return descriptions.zero;
    if (rate <= 10) return descriptions.reduced;
    return descriptions.standard;
  }
  
  /**
   * Get formatted category with rate
   */
  static getFormattedCategoryDescription(
    category: string,
    rate: number,
    language: string = 'en'
  ): string {
    const descriptions = TAX_RATE_DESCRIPTIONS[language] || TAX_RATE_DESCRIPTIONS['en'];
    return descriptions.category(category, rate);
  }
  
  /**
   * Get comprehensive tax breakdown description
   */
  static getComprehensiveDescription(
    category: string,
    rate: number,
    amount: number,
    currency: string = 'EUR',
    language: string = 'en'
  ): string {
    const categoryDesc = this.getFormattedCategoryDescription(category, rate, language);
    const formattedAmount = new Intl.NumberFormat(this.getLocaleFromLanguage(language), {
      style: 'currency',
      currency: currency
    }).format(amount);
    
    return `${categoryDesc}: ${formattedAmount}`;
  }
  
  /**
   * Generate summary description for all tax breakdowns
   */
  static generateSummaryDescription(
    breakdowns: Array<{category: string, rate: number, amount: number}>,
    currency: string = 'EUR',
    language: string = 'en'
  ): string {
    const descriptions = breakdowns.map(breakdown =>
      this.getComprehensiveDescription(
        breakdown.category, 
        breakdown.rate, 
        breakdown.amount, 
        currency, 
        language
      )
    );
    
    const separator = this.getSeparatorForLanguage(language);
    return descriptions.join(separator);
  }
  
  /**
   * Get locale string from language code
   */
  private static getLocaleFromLanguage(language: string): string {
    const localeMap: { [key: string]: string } = {
      'en': 'en-US',
      'fi': 'fi-FI',
      'sv': 'sv-SE',
      'de': 'de-DE',
      'fr': 'fr-FR',
      'es': 'es-ES',
      'it': 'it-IT'
    };
    
    return localeMap[language] || 'en-US';
  }
  
  /**
   * Get separator character for language
   */
  private static getSeparatorForLanguage(language: string): string {
    // Some languages prefer semicolons, others commas
    const semicolonLanguages = ['de', 'fr'];
    return semicolonLanguages.includes(language) ? '; ' : ', ';
  }
  
  /**
   * Detect language from tax keywords
   */
  static detectLanguageFromTaxKeywords(text: string): string {
    const keywordMap = [
      { keywords: ['alv', 'arvonlisävero', 'vero'], language: 'fi' },
      { keywords: ['moms', 'mervärdesskatt'], language: 'sv' },
      { keywords: ['mwst', 'mehrwertsteuer', 'steuer'], language: 'de' },
      { keywords: ['tva', 'taxe'], language: 'fr' },
      { keywords: ['iva', 'impuesto'], language: 'es' },
      { keywords: ['iva', 'imposta'], language: 'it' },
      { keywords: ['vat', 'tax'], language: 'en' }
    ];
    
    const lowerText = text.toLowerCase();
    
    for (const { keywords, language } of keywordMap) {
      if (keywords.some(keyword => lowerText.includes(keyword))) {
        return language;
      }
    }
    
    return 'en'; // Default to English
  }
}