/**
 * Currency Detection Service
 * Based on Flutter app's LanguageKeywords currency detection logic
 */

export enum Currency {
  EUR = 'EUR',
  SEK = 'SEK', 
  NOK = 'NOK',
  DKK = 'DKK',
  USD = 'USD',
  GBP = 'GBP',
}

export interface CurrencyInfo {
  code: Currency;
  symbol: string;
}

export class CurrencyExtractor {
  
  // Currency symbol to Currency enum mapping
  private static readonly currencySymbolMap: Map<string, Currency> = new Map([
    ['€', Currency.EUR],
    ['£', Currency.GBP],
    ['$', Currency.USD],
    ['kr', Currency.SEK], // Swedish Krona (also used for NOK and DKK, but SEK is most common)
  ]);

  // Currency code to Currency enum mapping (case-insensitive)
  private static readonly currencyCodeMap: Map<string, Currency> = new Map([
    ['eur', Currency.EUR],
    ['sek', Currency.SEK],
    ['nok', Currency.NOK],
    ['dkk', Currency.DKK],
    ['usd', Currency.USD],
    ['gbp', Currency.GBP],
    ['chf', Currency.EUR], // CHF not in enum, default to EUR
  ]);

  // Get all supported currency symbols
  private static get allCurrencySymbols(): string[] {
    return Array.from(this.currencySymbolMap.keys());
  }

  // Get all supported currency codes
  private static get allCurrencyCodes(): string[] {
    return Array.from(this.currencyCodeMap.keys());
  }

  // Get currency pattern string for regex (escaped symbols)
  static get currencySymbolPattern(): string {
    // Escape special regex characters in symbols
    const escapedSymbols = this.allCurrencySymbols.map((s) => {
      if (s === '$') return '\\$';
      if (s === '€') return '€';
      if (s === '£') return '£';
      return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); // Escape special regex chars
    }).join('');
    return `[${escapedSymbols}]`;
  }

  // Get currency code pattern string for regex
  static get currencyCodePattern(): string {
    // Include both lowercase and uppercase codes
    const codes = ['EUR', 'USD', 'GBP', 'SEK', 'NOK', 'DKK', 'CHF'].join('|');
    return `\\b(${codes})\\b`;
  }

  // Get all currency regex patterns
  static get currencyPatterns(): RegExp[] {
    return [
      // Currency symbols pattern
      new RegExp(this.currencySymbolPattern, 'gi'),
      // Currency codes pattern  
      new RegExp(this.currencyCodePattern, 'gi'),
    ];
  }

  /**
   * Extract currency from text
   * Returns the Currency enum value if found, null otherwise
   * @param text Text to search for currency
   * @param appliedPatterns Optional list to add applied pattern names
   */
  static extractCurrency(text: string, appliedPatterns?: string[]): CurrencyInfo | null {
    // Check for currency symbols first (strong indicators)
    for (const [symbol, currency] of this.currencySymbolMap.entries()) {
      if (text.includes(symbol)) {
        appliedPatterns?.push(`currency_symbol_${currency.toLowerCase()}`);
        return {
          code: currency,
          symbol: this.getSymbol(currency)
        };
      }
    }

    // Check for currency codes using patterns
    for (let i = 0; i < this.currencyPatterns.length; i++) {
      const pattern = this.currencyPatterns[i];
      const match = pattern.exec(text);
      if (match) {
        const currencyText = match[0];
        appliedPatterns?.push(`currency_pattern_${i}`);

        // Try to match by symbol
        const symbolMatch = this.currencySymbolMap.get(currencyText);
        if (symbolMatch) {
          return {
            code: symbolMatch,
            symbol: this.getSymbol(symbolMatch)
          };
        }

        // Try to match by code (case-insensitive)
        const codeMatch = this.currencyCodeMap.get(currencyText.toLowerCase());
        if (codeMatch) {
          return {
            code: codeMatch,
            symbol: this.getSymbol(codeMatch)
          };
        }

        // Handle special cases
        const lowerText = currencyText.toLowerCase();
        switch (lowerText) {
          case '€':
          case 'eur':
            return { code: Currency.EUR, symbol: '€' };
          case 'kr':
          case 'sek':
            return { code: Currency.SEK, symbol: 'kr' };
          case 'nok':
            return { code: Currency.NOK, symbol: 'kr' };
          case 'dkk':
            return { code: Currency.DKK, symbol: 'kr' };
          case '$':
          case 'usd':
            return { code: Currency.USD, symbol: '$' };
          case '£':
          case 'gbp':
            return { code: Currency.GBP, symbol: '£' };
        }
      }
    }

    return null;
  }

  /**
   * Check if text contains currency symbol or code
   */
  static hasCurrencySymbol(text: string): boolean {
    // Check for symbols
    for (const symbol of this.currencySymbolMap.keys()) {
      if (text.includes(symbol)) {
        return true;
      }
    }

    // Check for codes using regex
    const codePattern = new RegExp(this.currencyCodePattern, 'i');
    return codePattern.test(text);
  }

  /**
   * Convert currency code string to Currency enum
   */
  static fromCode(code: string): Currency {
    return this.currencyCodeMap.get(code.toLowerCase()) ?? Currency.EUR;
  }

  /**
   * Get currency symbol for a Currency enum
   */
  static getSymbol(currency: Currency): string {
    switch (currency) {
      case Currency.EUR: return '€';
      case Currency.GBP: return '£';
      case Currency.USD: return '$';
      case Currency.SEK:
      case Currency.NOK: 
      case Currency.DKK: return 'kr';
      default: return '€';
    }
  }

  /**
   * Get currency code for a Currency enum
   */
  static getCode(currency: Currency): string {
    return currency;
  }

  /**
   * Extract currency from amount text and return both the cleaned amount and currency
   */
  static extractCurrencyAndAmount(text: string): { 
    amount: number | null, 
    currency: CurrencyInfo | null,
    cleanedText: string 
  } {
    const currency = this.extractCurrency(text);
    
    // Remove currency symbols and clean the text
    let cleanedText = text;
    if (currency) {
      // Remove the specific currency symbol/code found
      cleanedText = cleanedText.replace(new RegExp(`\\${currency.symbol}|${currency.code}`, 'gi'), '');
    }
    
    // Remove any remaining currency symbols
    cleanedText = cleanedText.replace(/[€$£¥₹kr]/gi, '');
    
    // Clean spaces and convert comma to decimal
    cleanedText = cleanedText.trim().replace(',', '.');
    
    // Parse amount
    const amount = cleanedText ? parseFloat(cleanedText) : null;
    
    return {
      amount: isNaN(amount!) ? null : amount,
      currency,
      cleanedText
    };
  }
}