/**
 * Language Keywords for Receipt Data Extraction
 * 
 * Ported from Flutter implementation with enhancements for Evidence-Based Fusion
 * Centralized management of all language-specific keywords for 7 languages:
 * EN, FI, SV, FR, DE, IT, ES
 */

export type SupportedLanguage = 'en' | 'fi' | 'sv' | 'fr' | 'de' | 'it' | 'es';

export type KeywordCategory = 
  | 'total'
  | 'subtotal'
  | 'tax'
  | 'payment'
  | 'payment_method_cash'
  | 'payment_method_card'
  | 'receipt'
  | 'invoice'
  | 'invoice_specific'
  | 'receipt_specific'
  | 'item_table_header'
  | 'change'
  | 'receipt_number';

export interface CurrencyInfo {
  code: string;
  symbol: string;
  name: string;
  position: 'prefix' | 'suffix';
}

/**
 * Enhanced LanguageKeywords class with multilingual support
 * Based on Flutter implementation but optimized for Evidence-Based Fusion
 */
export class LanguageKeywords {
  // Language codes
  static readonly LANGUAGES: Record<string, SupportedLanguage> = {
    EN: 'en',
    FI: 'fi',
    SV: 'sv',
    FR: 'fr',
    DE: 'de',
    IT: 'it',
    ES: 'es',
  };

  /**
   * Category-based keyword map
   * Structure: { category: { language: [keywords] } }
   * 
   * Enhanced with uppercase variants and additional patterns for better detection
   */
  private static readonly keywords: Record<KeywordCategory, Record<SupportedLanguage, string[]>> = {
    total: {
      en: [
        'total', 'sum', 'amount', 'grand total', 'amount due', 'total amount', 'final amount', 'balance due',
        'TOTAL', 'SUM', 'AMOUNT', 'GRAND TOTAL', 'AMOUNT DUE', 'TOTAL AMOUNT', 'FINAL AMOUNT', 'BALANCE DUE'
      ],
      fi: ['yhteensä', 'summa', 'loppusumma', 'maksettava', 'maksu', 'YHTEENSÄ', 'SUMMA', 'LOPPUSUMMA', 'MAKSETTAVA', 'MAKSU'],
      sv: ['totalt', 'summa', 'att betala', 'slutsumma', 'TOTALT', 'SUMMA', 'ATT BETALA', 'SLUTSUMMA'],
      fr: ['total', 'montant total', 'somme', 'à payer', 'net à payer', 'total ttc', 'TOTAL', 'MONTANT TOTAL', 'SOMME', 'À PAYER', 'NET À PAYER', 'TOTAL TTC'],
      de: ['summe', 'gesamt', 'betrag', 'gesamtbetrag', 'endsumme', 'zu zahlen', 'SUMME', 'GESAMT', 'BETRAG', 'GESAMTBETRAG', 'ENDSUMME', 'ZU ZAHLEN'],
      it: ['totale', 'importo', 'somma', 'da pagare', 'totale generale', 'saldo', 'TOTALE', 'IMPORTO', 'SOMMA', 'DA PAGARE', 'TOTALE GENERALE', 'SALDO'],
      es: ['total', 'importe', 'suma', 'a pagar', 'total general', 'precio total', 'TOTAL', 'IMPORTE', 'SUMA', 'A PAGAR', 'TOTAL GENERAL', 'PRECIO TOTAL'],
    },
    subtotal: {
      en: [
        'subtotal', 'sub-total', 'sub total', 'net', 'merchandise total', 'items total',
        'SUBTOTAL', 'SUB-TOTAL', 'SUB TOTAL', 'NET', 'MERCHANDISE TOTAL', 'ITEMS TOTAL'
      ],
      fi: ['välisumma', 'alasumma', 'VÄLISUMMA', 'ALASUMMA'],
      sv: ['delsumma', 'mellansumma', 'DELSUMMA', 'MELLANSUMMA'],
      fr: ['sous-total', 'montant ht', 'SOUS-TOTAL', 'MONTANT HT'],
      de: ['zwischensumme', 'netto', 'nettosumme', 'ZWISCHENSUMME', 'NETTO', 'NETTOSUMME'],
      it: ['subtotale', 'imponibile', 'SUBTOTALE', 'IMPONIBILE'],
      es: ['subtotal', 'base imponible', 'SUBTOTAL', 'BASE IMPONIBLE'],
    },
    tax: {
      en: [
        'vat', 'tax', 'sales tax', 'state tax', 'local tax', 'tax amount', 'total tax',
        'VAT', 'TAX', 'SALES TAX', 'STATE TAX', 'LOCAL TAX', 'TAX AMOUNT', 'TOTAL TAX'
      ],
      fi: ['alv', 'arvonlisävero', 'vero', 'ALV', 'ARVONLISÄVERO', 'VERO'],
      sv: ['moms', 'mervärdesskatt', 'MOMS', 'MERVÄRDESSKATT'],
      fr: ['tva', 'taxe', 'TVA', 'TAXE'],
      de: ['mwst', 'umsatzsteuer', 'steuer', 'MWST', 'UMSATZSTEUER', 'STEUER'],
      it: ['iva', 'imposta', 'IVA', 'IMPOSTA'],
      es: ['iva', 'impuesto', 'IVA', 'IMPUESTO'],
    },
    payment: {
      en: ['payment', 'PAYMENT'],
      fi: ['maksutapa', 'MAKSUTAPA'],
      sv: ['betalning', 'BETALNING'],
      fr: ['paiement', 'PAIEMENT'],
      de: ['zahlung', 'ZAHLUNG'],
      it: ['pagamento', 'PAGAMENTO'],
      es: ['pago', 'PAGO'],
    },
    payment_method_cash: {
      en: ['cash', 'CASH'],
      fi: ['käteinen', 'KÄTEINEN'],
      sv: ['kontanter', 'KONTANTER'],
      fr: ['espèces', 'ESPÈCES'],
      de: ['bar', 'BAR'],
      it: ['contanti', 'CONTANTI'],
      es: ['efectivo', 'EFECTIVO'],
    },
    payment_method_card: {
      en: ['card', 'CARD'],
      fi: ['kortti', 'KORTTI'],
      sv: ['kort', 'KORT'],
      fr: ['carte', 'CARTE'],
      de: ['karte', 'KARTE'],
      it: ['carta', 'CARTA'],
      es: ['tarjeta', 'TARJETA'],
    },
    receipt: {
      en: ['receipt', 'RECEIPT'],
      fi: ['kuitti', 'KUITTI'],
      sv: ['kvitto', 'KVITTO'],
      fr: ['reçu', 'REÇU'],
      de: ['rechnung', 'bon', 'quittung', 'RECHNUNG', 'BON', 'QUITTUNG'],
      it: ['ricevuta', 'RICEVUTA'],
      es: ['recibo', 'RECIBO'],
    },
    invoice: {
      en: ['invoice', 'bill', 'INVOICE', 'BILL'],
      fi: ['lasku', 'faktuura', 'LASKU', 'FAKTUURA'],
      sv: ['faktura', 'räkning', 'FAKTURA', 'RÄKNING'],
      fr: ['facture', 'FACTURE'],
      de: ['rechnung', 'faktura', 'RECHNUNG', 'FAKTURA'],
      it: ['fattura', 'FATTURA'],
      es: ['factura', 'FACTURA'],
    },
    invoice_specific: {
      en: [
        'bill to', 'ship to', 'due date', 'payment terms', 'invoice number', 'invoice #', 'net 30', 'net 60', 
        'payment due', 'terms', 'billing address', 'BILL TO', 'SHIP TO', 'DUE DATE', 'PAYMENT TERMS', 
        'INVOICE NUMBER', 'INVOICE #', 'NET 30', 'NET 60', 'PAYMENT DUE', 'TERMS', 'BILLING ADDRESS'
      ],
      fi: [
        'laskutettava', 'toimitusosoite', 'eräpäivä', 'maksuehto', 'laskun numero', 'lasku nro', 'maksuaika', 'laskutusosoite',
        'LASKUTETTAVA', 'TOIMITUSOSOITE', 'ERÄPÄIVÄ', 'MAKSUEHTO', 'LASKUN NUMERO', 'LASKU NRO', 'MAKSUAIKA', 'LASKUTUSOSOITE'
      ],
      sv: [
        'fakturera till', 'leveransadress', 'förfallodatum', 'betalningsvillkor', 'fakturanummer', 'faktura nr',
        'FAKTURERA TILL', 'LEVERANSADRESS', 'FÖRFALLODATUM', 'BETALNINGSVILLKOR', 'FAKTURANUMMER', 'FAKTURA NR'
      ],
      fr: [
        'facturer à', 'livrer à', "date d'échéance", 'conditions de paiement', 'numéro de facture', 'facture n°', 'net 30', 'net 60',
        'FACTURER À', 'LIVRER À', "DATE D'ÉCHÉANCE", 'CONDITIONS DE PAIEMENT', 'NUMÉRO DE FACTURE', 'FACTURE N°', 'NET 30', 'NET 60'
      ],
      de: [
        'rechnungsempfänger', 'lieferadresse', 'fälligkeitsdatum', 'zahlungsbedingungen', 'rechnungsnummer', 'rechnung nr', 'zahlungsziel',
        'RECHNUNGSEMPFÄNGER', 'LIEFERADRESSE', 'FÄLLIGKEITSDATUM', 'ZAHLUNGSBEDINGUNGEN', 'RECHNUNGSNUMMER', 'RECHNUNG NR', 'ZAHLUNGSZIEL'
      ],
      it: [
        'fatturare a', 'spedire a', 'data di scadenza', 'termini di pagamento', 'numero fattura', 'fattura n°', 'netto 30',
        'FATTURARE A', 'SPEDIRE A', 'DATA DI SCADENZA', 'TERMINI DI PAGAMENTO', 'NUMERO FATTURA', 'FATTURA N°', 'NETTO 30'
      ],
      es: [
        'facturar a', 'enviar a', 'fecha de vencimiento', 'términos de pago', 'número de factura', 'factura nº', 'neto 30',
        'FACTURAR A', 'ENVIAR A', 'FECHA DE VENCIMIENTO', 'TÉRMINOS DE PAGO', 'NÚMERO DE FACTURA', 'FACTURA Nº', 'NETO 30'
      ],
    },
    receipt_specific: {
      en: [
        'thank you', 'thank you for your purchase', 'visitor copy', 'customer copy', 'paid', 'payment received',
        'THANK YOU', 'THANK YOU FOR YOUR PURCHASE', 'VISITOR COPY', 'CUSTOMER COPY', 'PAID', 'PAYMENT RECEIVED'
      ],
      fi: [
        'kiitos', 'kiitos ostoksestasi', 'asiakasnäyte', 'maksettu', 'maksu vastaanotettu',
        'KIITOS', 'KIITOS OSTOKSESTASI', 'ASIAKASNÄYTE', 'MAKSETTU', 'MAKSU VASTAANOTETTU'
      ],
      sv: [
        'tack', 'tack för ditt köp', 'kundkopia', 'betalad', 'betalning mottagen',
        'TACK', 'TACK FÖR DITT KÖP', 'KUNDKOPIA', 'BETALAD', 'BETALNING MOTTAGEN'
      ],
      fr: [
        'merci', 'merci pour votre achat', 'copie client', 'payé', 'paiement reçu',
        'MERCI', 'MERCI POUR VOTRE ACHAT', 'COPIE CLIENT', 'PAYÉ', 'PAIEMENT REÇU'
      ],
      de: [
        'danke', 'vielen dank für ihren einkauf', 'kundenbeleg', 'bezahlt', 'zahlung erhalten',
        'DANKE', 'VIELEN DANK FÜR IHREN EINKAUF', 'KUNDENBELEG', 'BEZAHLT', 'ZAHLUNG ERHALTEN'
      ],
      it: [
        'grazie', 'grazie per il tuo acquisto', 'copia cliente', 'pagato', 'pagamento ricevuto',
        'GRAZIE', 'GRAZIE PER IL TUO ACQUISTO', 'COPIA CLIENTE', 'PAGATO', 'PAGAMENTO RICEVUTO'
      ],
      es: [
        'gracias', 'gracias por su compra', 'copia del cliente', 'pagado', 'pago recibido',
        'GRACIAS', 'GRACIAS POR SU COMPRA', 'COPIA DEL CLIENTE', 'PAGADO', 'PAGO RECIBIDO'
      ],
    },
    item_table_header: {
      en: [
        'qty', 'quantity', 'description', 'item', 'product', 'unit price', 'unit', 'price', 'amount', 'vat', 'tax', 'sales tax',
        'QTY', 'QUANTITY', 'DESCRIPTION', 'ITEM', 'PRODUCT', 'UNIT PRICE', 'UNIT', 'PRICE', 'AMOUNT', 'VAT', 'TAX', 'SALES TAX'
      ],
      fi: [
        'määrä', 'kappalemäärä', 'kuvaus', 'tuote', 'yksikköhinta', 'hinta', 'summa', 'alv', 'arvonlisävero',
        'MÄÄRÄ', 'KAPPALEMÄÄRÄ', 'KUVAUS', 'TUOTE', 'YKSIKKÖHINTA', 'HINTA', 'SUMMA', 'ALV', 'ARVONLISÄVERO'
      ],
      sv: [
        'kvantitet', 'antal', 'beskrivning', 'produkt', 'enhetspris', 'pris', 'belopp', 'moms', 'mervärdesskatt',
        'KVANTITET', 'ANTAL', 'BESKRIVNING', 'PRODUKT', 'ENHETSPRIS', 'PRIS', 'BELOPP', 'MOMS', 'MERVÄRDESSKATT'
      ],
      fr: [
        'quantité', 'description', 'article', 'produit', 'prix unitaire', 'prix', 'montant', 'tva', 'taxe',
        'QUANTITÉ', 'DESCRIPTION', 'ARTICLE', 'PRODUIT', 'PRIX UNITAIRE', 'PRIX', 'MONTANT', 'TVA', 'TAXE'
      ],
      de: [
        'menge', 'anzahl', 'beschreibung', 'artikel', 'produkt', 'einzelpreis', 'preis', 'betrag', 'mwst', 'umsatzsteuer', 'steuer',
        'MENGE', 'ANZAHL', 'BESCHREIBUNG', 'ARTIKEL', 'PRODUKT', 'EINZELPREIS', 'PREIS', 'BETRAG', 'MWST', 'UMSATZSTEUER', 'STEUER'
      ],
      it: [
        'quantità', 'descrizione', 'articolo', 'prodotto', 'prezzo unitario', 'prezzo', 'importo', 'iva', 'imposta',
        'QUANTITÀ', 'DESCRIZIONE', 'ARTICOLO', 'PRODOTTO', 'PREZZO UNITARIO', 'PREZZO', 'IMPORTO', 'IVA', 'IMPOSTA'
      ],
      es: [
        'cantidad', 'descripción', 'artículo', 'producto', 'precio unitario', 'precio', 'importe', 'iva', 'impuesto',
        'CANTIDAD', 'DESCRIPCIÓN', 'ARTÍCULO', 'PRODUCTO', 'PRECIO UNITARIO', 'PRECIO', 'IMPORTE', 'IVA', 'IMPUESTO'
      ],
    },
    change: {
      en: ['change', 'change due', 'your change', 'cash back', 'CHANGE', 'CHANGE DUE', 'YOUR CHANGE', 'CASH BACK'],
      fi: ['vaihtoraha', 'VAIHTORAHA'],
      sv: ['växel', 'VÄXEL'],
      fr: ['monnaie', 'rendu', 'MONNAIE', 'RENDU'],
      de: ['wechselgeld', 'rückgeld', 'WECHSELGELD', 'RÜCKGELD'],
      it: ['resto', 'RESTO'],
      es: ['cambio', 'vuelto', 'CAMBIO', 'VUELTO'],
    },
    receipt_number: {
      en: ['receipt #', 'receipt no', 'transaction #', 'trans id', 'ref #', 'RECEIPT #', 'RECEIPT NO', 'TRANSACTION #', 'TRANS ID', 'REF #'],
      fi: ['kuitti nro', 'kuitti #', 'KUITTI NRO', 'KUITTI #'],
      sv: ['kvitto nr', 'kvitto #', 'KVITTO NR', 'KVITTO #'],
      fr: ['reçu n°', 'reçu #', 'REÇU N°', 'REÇU #'],
      de: ['bon nr', 'bon #', 'beleg nr', 'BON NR', 'BON #', 'BELEG NR'],
      it: ['ricevuta n°', 'ricevuta #', 'RICEVUTA N°', 'RICEVUTA #'],
      es: ['recibo n°', 'recibo #', 'RECIBO N°', 'RECIBO #'],
    },
  };

  /**
   * Currency information with enhanced support for multiple formats
   */
  private static readonly currencyInfo: Record<string, CurrencyInfo> = {
    EUR: { code: 'EUR', symbol: '€', name: 'Euro', position: 'suffix' },
    USD: { code: 'USD', symbol: '$', name: 'US Dollar', position: 'prefix' },
    GBP: { code: 'GBP', symbol: '£', name: 'British Pound', position: 'prefix' },
    SEK: { code: 'SEK', symbol: 'kr', name: 'Swedish Krona', position: 'suffix' },
    NOK: { code: 'NOK', symbol: 'kr', name: 'Norwegian Krone', position: 'suffix' },
    DKK: { code: 'DKK', symbol: 'kr', name: 'Danish Krone', position: 'suffix' },
    CHF: { code: 'CHF', symbol: 'CHF', name: 'Swiss Franc', position: 'suffix' },
  };

  // === PUBLIC API METHODS ===

  /**
   * Get all keywords for a category across all languages
   */
  static getAllKeywords(category: KeywordCategory): string[] {
    const allKeywords = new Set<string>();
    const categoryMap = this.keywords[category];
    
    if (categoryMap) {
      Object.values(categoryMap).forEach(langKeywords => {
        langKeywords.forEach(keyword => allKeywords.add(keyword));
      });
    }
    
    return Array.from(allKeywords);
  }

  /**
   * Get keywords for a specific category and language
   */
  static getKeywords(category: KeywordCategory, language: SupportedLanguage): string[] {
    return this.keywords[category]?.[language] ?? [];
  }

  /**
   * Get keywords for multiple languages
   */
  static getKeywordsForLanguages(
    category: KeywordCategory,
    languages: SupportedLanguage[]
  ): string[] {
    const allKeywords = new Set<string>();
    
    languages.forEach(lang => {
      const keywords = this.getKeywords(category, lang);
      keywords.forEach(keyword => allKeywords.add(keyword));
    });
    
    return Array.from(allKeywords);
  }

  /**
   * Check if a category exists
   */
  static hasCategory(category: string): category is KeywordCategory {
    return category in this.keywords;
  }

  /**
   * Get all supported languages for a category
   */
  static getSupportedLanguages(category: KeywordCategory): SupportedLanguage[] {
    return Object.keys(this.keywords[category] || {}) as SupportedLanguage[];
  }

  /**
   * Get all supported categories
   */
  static getAllCategories(): KeywordCategory[] {
    return Object.keys(this.keywords) as KeywordCategory[];
  }

  // === CURRENCY MANAGEMENT ===

  /**
   * Get all supported currency symbols
   */
  static getAllCurrencySymbols(): string[] {
    return Object.values(this.currencyInfo).map(info => info.symbol);
  }

  /**
   * Get all supported currency codes
   */
  static getAllCurrencyCodes(): string[] {
    return Object.keys(this.currencyInfo);
  }

  /**
   * Get currency pattern for regex (escaped symbols)
   */
  static getCurrencyPattern(): string {
    const symbols = this.getAllCurrencySymbols();
    const escapedSymbols = symbols.map(s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|');
    return `(${escapedSymbols})`;
  }

  /**
   * Get currency code pattern for regex
   */
  static getCurrencyCodePattern(): string {
    const codes = this.getAllCurrencyCodes();
    return `\\b(${codes.join('|')})\\b`;
  }

  /**
   * Extract currency from text with enhanced detection
   */
  static extractCurrency(text: string): CurrencyInfo | null {
    // Check for symbols first
    for (const [code, info] of Object.entries(this.currencyInfo)) {
      if (text.includes(info.symbol)) {
        return info;
      }
    }

    // Check for currency codes
    const codePattern = new RegExp(this.getCurrencyCodePattern(), 'i');
    const match = text.match(codePattern);
    
    if (match) {
      const foundCode = match[1].toUpperCase();
      return this.currencyInfo[foundCode] || null;
    }

    return null;
  }

  /**
   * Check if text contains currency symbol or code
   */
  static hasCurrencySymbol(text: string): boolean {
    return this.extractCurrency(text) !== null;
  }

  /**
   * Generate regex patterns for currency amounts
   */
  static generateCurrencyAmountPatterns(): {
    prefixed: RegExp;
    suffixed: RegExp;
    codes: RegExp;
  } {
    const prefixSymbols = Object.values(this.currencyInfo)
      .filter(info => info.position === 'prefix')
      .map(info => info.symbol.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
      .join('|');

    const suffixSymbols = Object.values(this.currencyInfo)
      .filter(info => info.position === 'suffix')
      .map(info => info.symbol.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
      .join('|');

    return {
      prefixed: new RegExp(`(${prefixSymbols})\\s*\\d+[.,]\\d{2}`, 'g'),
      suffixed: new RegExp(`\\d+[.,]\\d{2}\\s*(${suffixSymbols})`, 'g'),
      codes: new RegExp(`\\d+[.,]\\d{2}\\s*${this.getCurrencyCodePattern()}`, 'gi'),
    };
  }

  // === PATTERN GENERATION FOR EVIDENCE-BASED FUSION ===

  /**
   * Generate comprehensive regex pattern for a category across all languages
   */
  static generateCategoryPattern(category: KeywordCategory): RegExp {
    const allKeywords = this.getAllKeywords(category);
    const escapedKeywords = allKeywords.map(keyword => 
      keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    );
    
    const pattern = `\\b(${escapedKeywords.join('|')})\\b`;
    return new RegExp(pattern, 'gi');
  }

  /**
   * Generate language-specific pattern for a category
   */
  static generateLanguagePattern(category: KeywordCategory, language: SupportedLanguage): RegExp {
    const keywords = this.getKeywords(category, language);
    const escapedKeywords = keywords.map(keyword => 
      keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    );
    
    const pattern = `\\b(${escapedKeywords.join('|')})\\b`;
    return new RegExp(pattern, 'gi');
  }

  /**
   * Generate amount extraction pattern with currency support
   */
  static generateAmountPattern(includesCurrency = true): RegExp {
    if (includesCurrency) {
      const currencySymbols = this.getAllCurrencySymbols()
        .map(s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
        .join('|');
      
      // Matches both prefix ($123.45) and suffix (123.45€) patterns
      return new RegExp(
        `(?:(${currencySymbols})\\s*)?\\d{1,3}(?:[.,]\\d{3})*(?:[.,]\\d{2})?(?:\\s*(${currencySymbols}))?`,
        'g'
      );
    } else {
      // Just numbers with decimal places
      return new RegExp(`\\d{1,3}(?:[.,]\\d{3})*(?:[.,]\\d{2})?`, 'g');
    }
  }

  /**
   * Generate tax rate pattern (percentage)
   */
  static generateTaxRatePattern(): RegExp {
    return new RegExp(`(\\d+(?:[.,]\\d+)?)\\s*%`, 'g');
  }

  // === UTILITY METHODS ===

  /**
   * Normalize text for better matching (handle case, accents, etc.)
   */
  static normalizeText(text: string): string {
    return text
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '') // Remove diacritics
      .toLowerCase()
      .trim();
  }

  /**
   * Check if text contains any keyword from a category
   */
  static containsKeyword(text: string, category: KeywordCategory, language?: SupportedLanguage): boolean {
    const normalizedText = this.normalizeText(text);
    
    if (language) {
      const keywords = this.getKeywords(category, language);
      return keywords.some(keyword => 
        normalizedText.includes(this.normalizeText(keyword))
      );
    } else {
      const allKeywords = this.getAllKeywords(category);
      return allKeywords.some(keyword => 
        normalizedText.includes(this.normalizeText(keyword))
      );
    }
  }

  /**
   * Find best matching language for text based on keyword frequency
   */
  static detectLanguage(text: string): SupportedLanguage | null {
    const normalizedText = this.normalizeText(text);
    const languageScores: Record<SupportedLanguage, number> = {
      en: 0, fi: 0, sv: 0, fr: 0, de: 0, it: 0, es: 0
    };

    // Score each language based on keyword matches
    (Object.keys(this.keywords) as KeywordCategory[]).forEach(category => {
      Object.entries(this.keywords[category]).forEach(([lang, keywords]) => {
        const language = lang as SupportedLanguage;
        keywords.forEach(keyword => {
          if (normalizedText.includes(this.normalizeText(keyword))) {
            languageScores[language]++;
          }
        });
      });
    });

    // Find language with highest score
    let maxScore = 0;
    let detectedLanguage: SupportedLanguage | null = null;

    Object.entries(languageScores).forEach(([lang, score]) => {
      if (score > maxScore) {
        maxScore = score;
        detectedLanguage = lang as SupportedLanguage;
      }
    });

    // Require minimum score to be confident in detection
    return maxScore >= 2 ? detectedLanguage : null;
  }

  /**
   * Get keyword confidence score based on context and language
   */
  static calculateKeywordConfidence(
    keyword: string, 
    category: KeywordCategory,
    language: SupportedLanguage | null,
    context: string
  ): number {
    let confidence = 0.7; // Base confidence

    // Language match bonus
    if (language && this.getKeywords(category, language).includes(keyword)) {
      confidence += 0.2;
    }

    // Case consistency bonus (if keyword is uppercase in context)
    if (keyword === keyword.toUpperCase() && /[A-Z]/.test(context)) {
      confidence += 0.1;
    }

    // Word boundary bonus (keyword is isolated, not part of another word)
    const wordBoundaryPattern = new RegExp(`\\b${keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i');
    if (wordBoundaryPattern.test(context)) {
      confidence += 0.1;
    }

    return Math.min(confidence, 0.95);
  }
}