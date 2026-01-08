import '../../data/models/receipt.dart';

/// Language keywords for receipt data extraction
/// Centralized management of all language-specific keywords
class LanguageKeywords {
  // Language codes
  static const String en = 'en';
  static const String fi = 'fi';
  static const String sv = 'sv';
  static const String fr = 'fr';
  static const String de = 'de';
  static const String it = 'it';
  static const String es = 'es';

  /// Category-based keyword map
  /// Structure: { category: { language: [keywords] } }
  static const Map<String, Map<String, List<String>>> keywords = {
    'total': {
      'en': ['total', 'sum', 'amount', 'grand total', 'amount due'],
      'fi': ['yhteensä', 'summa', 'loppusumma', 'maksettava', 'maksu'],
      'sv': ['totalt', 'summa', 'att betala', 'slutsumma'],
      'fr': ['total', 'montant total', 'somme', 'à payer', 'net à payer', 'total ttc'],
      'de': ['summe', 'gesamt', 'betrag', 'gesamtbetrag', 'endsumme', 'zu zahlen'],
      'it': ['totale', 'importo', 'somma', 'da pagare', 'totale generale', 'saldo'],
      'es': ['total', 'importe', 'suma', 'a pagar', 'total general', 'precio total'],
    },
    'subtotal': {
      'en': ['subtotal', 'sub-total', 'net'],
      'fi': ['välisumma', 'alasumma'],
      'sv': ['delsumma', 'mellansumma'],
      'fr': ['sous-total', 'montant ht'],
      'de': ['zwischensumme', 'netto', 'Zwischensumme', 'nettosumme'],
      'it': ['subtotale', 'imponibile'],
      'es': ['subtotal', 'base imponible'],
    },
    'tax': {
      'en': ['vat', 'tax', 'sales tax'],
      'fi': ['alv', 'arvonlisävero', 'vero'],
      'sv': ['moms', 'mervärdesskatt'],
      'fr': ['tva', 'taxe'],
      'de': ['mwst', 'umsatzsteuer', 'steuer'],
      'it': ['iva', 'imposta'],
      'es': ['iva', 'impuesto'],
    },
    'payment': {
      'en': ['payment'],
      'fi': ['maksutapa'],
      'sv': ['betalning'],
      'fr': ['paiement'],
      'de': ['zahlung'],
      'it': ['pagamento'],
      'es': ['pago'],
    },
    'payment_method_cash': {
      'en': ['cash'],
      'fi': ['käteinen'],
      'sv': ['kontanter'],
      'fr': ['espèces'],
      'de': ['bar'],
      'it': ['contanti'],
      'es': ['efectivo'],
    },
    'payment_method_card': {
      'en': ['card'],
      'fi': ['kortti'],
      'sv': ['kort'],
      'fr': ['carte'],
      'de': ['karte'],
      'it': ['carta'],
      'es': ['tarjeta'],
    },
    'receipt': {
      'en': ['receipt'],
      'fi': ['kuitti'],
      'sv': ['kvitto'],
      'fr': ['reçu'],
      'de': ['rechnung', 'bon', 'quittung'],
      'it': ['ricevuta'],
      'es': ['recibo'],
    },
    'invoice': {
      'en': ['invoice', 'bill'],
      'fi': ['lasku', 'faktuura'],
      'sv': ['faktura', 'räkning'],
      'fr': ['facture'],
      'de': ['rechnung', 'faktura'],
      'it': ['fattura'],
      'es': ['factura'],
    },
    'invoice_specific': {
      'en': ['bill to', 'ship to', 'due date', 'payment terms', 'invoice number', 'invoice #', 'net 30', 'net 60', 'payment due', 'terms', 'billing address'],
      'fi': ['laskutettava', 'toimitusosoite', 'eräpäivä', 'maksuehto', 'laskun numero', 'lasku nro', 'maksuaika', 'laskutusosoite'],
      'sv': ['fakturera till', 'leveransadress', 'förfallodatum', 'betalningsvillkor', 'fakturanummer', 'faktura nr', 'betalningsvillkor'],
      'fr': ['facturer à', 'livrer à', 'date d\'échéance', 'conditions de paiement', 'numéro de facture', 'facture n°', 'net 30', 'net 60'],
      'de': ['rechnungsempfänger', 'lieferadresse', 'fälligkeitsdatum', 'zahlungsbedingungen', 'rechnungsnummer', 'rechnung nr', 'zahlungsziel'],
      'it': ['fatturare a', 'spedire a', 'data di scadenza', 'termini di pagamento', 'numero fattura', 'fattura n°', 'netto 30'],
      'es': ['facturar a', 'enviar a', 'fecha de vencimiento', 'términos de pago', 'número de factura', 'factura nº', 'neto 30'],
    },
    'receipt_specific': {
      'en': ['thank you', 'thank you for your purchase', 'visitor copy', 'customer copy', 'paid', 'payment received'],
      'fi': ['kiitos', 'kiitos ostoksestasi', 'asiakasnäyte', 'maksettu', 'maksu vastaanotettu'],
      'sv': ['tack', 'tack för ditt köp', 'kundkopia', 'betalad', 'betalning mottagen'],
      'fr': ['merci', 'merci pour votre achat', 'copie client', 'payé', 'paiement reçu'],
      'de': ['danke', 'vielen dank für ihren einkauf', 'kundenbeleg', 'bezahlt', 'zahlung erhalten'],
      'it': ['grazie', 'grazie per il tuo acquisto', 'copia cliente', 'pagato', 'pagamento ricevuto'],
      'es': ['gracias', 'gracias por su compra', 'copia del cliente', 'pagado', 'pago recibido'],
    },
    'item_table_header': {
      'en': ['qty', 'quantity', 'description', 'item', 'product', 'unit price', 'unit', 'price', 'amount', 'vat', 'tax', 'sales tax'],
      'fi': ['määrä', 'kappalemäärä', 'kuvaus', 'tuote', 'yksikköhinta', 'hinta', 'summa', 'alv', 'arvonlisävero'],
      'sv': ['kvantitet', 'antal', 'beskrivning', 'produkt', 'enhetspris', 'pris', 'belopp', 'moms', 'mervärdesskatt'],
      'fr': ['quantité', 'description', 'article', 'produit', 'prix unitaire', 'prix', 'montant', 'tva', 'taxe'],
      'de': ['menge', 'anzahl', 'beschreibung', 'artikel', 'produkt', 'einzelpreis', 'preis', 'betrag', 'mwst', 'umsatzsteuer', 'steuer'],
      'it': ['quantità', 'descrizione', 'articolo', 'prodotto', 'prezzo unitario', 'prezzo', 'importo', 'iva', 'imposta'],
      'es': ['cantidad', 'descripción', 'artículo', 'producto', 'precio unitario', 'precio', 'importe', 'iva', 'impuesto'],
    },
  };

  /// Get all keywords for a category across all languages
  static List<String> getAllKeywords(String category) {
    final allKeywords = <String>{};
    final categoryMap = keywords[category];
    if (categoryMap != null) {
      for (final langKeywords in categoryMap.values) {
        allKeywords.addAll(langKeywords);
      }
    }
    return allKeywords.toList();
  }

  /// Get keywords for a specific category and language
  static List<String> getKeywords(String category, String language) {
    return keywords[category]?[language] ?? [];
  }

  /// Get keywords for multiple languages
  static List<String> getKeywordsForLanguages(
    String category,
    List<String> languages,
  ) {
    final allKeywords = <String>{};
    for (final lang in languages) {
      allKeywords.addAll(getKeywords(category, lang));
    }
    return allKeywords.toList();
  }

  /// Check if a category exists
  static bool hasCategory(String category) {
    return keywords.containsKey(category);
  }

  /// Get all supported languages for a category
  static List<String> getSupportedLanguages(String category) {
    return keywords[category]?.keys.toList() ?? [];
  }

  // ========== CURRENCY MANAGEMENT ==========

  /// Currency symbol to Currency enum mapping
  /// Maps currency symbols to their corresponding Currency enum values
  static const Map<String, Currency> currencySymbolMap = {
    '€': Currency.eur,
    '£': Currency.gbp,
    '\$': Currency.usd,
    'kr': Currency.sek, // Swedish Krona (also used for NOK and DKK, but SEK is most common)
  };

  /// Currency code to Currency enum mapping
  /// Maps currency codes (case-insensitive) to their corresponding Currency enum values
  static const Map<String, Currency> currencyCodeMap = {
    'eur': Currency.eur,
    'sek': Currency.sek,
    'nok': Currency.nok,
    'dkk': Currency.dkk,
    'usd': Currency.usd,
    'gbp': Currency.gbp,
    'chf': Currency.eur, // CHF not in enum, default to EUR
  };

  /// All supported currency symbols
  static List<String> get allCurrencySymbols => currencySymbolMap.keys.toList();

  /// All supported currency codes
  static List<String> get allCurrencyCodes => currencyCodeMap.keys.toList();

  /// Get currency pattern string for regex (escaped symbols)
  /// Returns a regex pattern string matching all currency symbols
  static String get currencyPattern {
    // Escape special regex characters in symbols
    final escapedSymbols = allCurrencySymbols.map((s) {
      if (s == '\$') return r'\$';
      if (s == '€') return '€';
      if (s == '£') return '£';
      return RegExp.escape(s);
    }).join('');
    return '[$escapedSymbols]?';
  }

  /// Get currency code pattern string for regex
  /// Returns a regex pattern string matching all currency codes
  static String get currencyCodePattern {
    // Include both lowercase and uppercase codes
    final codes = ['EUR', 'USD', 'GBP', 'SEK', 'NOK', 'DKK', 'CHF'].join('|');
    return '\\b($codes)\\b';
  }

  /// Get all currency regex patterns
  /// Returns a list of RegExp patterns for matching currency symbols and codes
  static List<RegExp> get currencyPatterns {
    return [
      // Currency symbols pattern
      RegExp(currencyPattern.replaceAll('?', ''), multiLine: true),
      // Currency codes pattern
      RegExp(currencyCodePattern, multiLine: true, caseSensitive: false),
    ];
  }

  /// Extract currency from text
  /// Returns the Currency enum value if found, null otherwise
  /// [text] - Text to search for currency
  /// [appliedPatterns] - Optional list to add applied pattern names
  static Currency? extractCurrency(String text, [List<String>? appliedPatterns]) {
    // Check for currency symbols first (strong indicators)
    for (final entry in currencySymbolMap.entries) {
      if (text.contains(entry.key)) {
        appliedPatterns?.add('currency_symbol_${entry.value.code.toLowerCase()}');
        return entry.value;
      }
    }

    // Check for currency codes using patterns
    for (final pattern in currencyPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final currencyText = match.group(0)!;
        appliedPatterns?.add('currency_pattern_${currencyPatterns.indexOf(pattern)}');

        // Try to match by symbol
        final symbolMatch = currencySymbolMap[currencyText];
        if (symbolMatch != null) {
          return symbolMatch;
        }

        // Try to match by code (case-insensitive)
        final codeMatch = currencyCodeMap[currencyText.toLowerCase()];
        if (codeMatch != null) {
          return codeMatch;
        }

        // Handle special cases
        switch (currencyText.toLowerCase()) {
          case '€':
          case 'eur':
            return Currency.eur;
          case 'kr':
            // Default to SEK for 'kr' (most common)
            return Currency.sek;
          case 'sek':
            return Currency.sek;
          case 'nok':
            return Currency.nok;
          case 'dkk':
            return Currency.dkk;
          case '\$':
          case 'usd':
            return Currency.usd;
          case '£':
          case 'gbp':
            return Currency.gbp;
        }
      }
    }

    return null;
  }

  /// Check if text contains currency symbol or code
  /// Returns true if any currency symbol or code is found in the text
  static bool hasCurrencySymbol(String text) {
    // Check for symbols
    for (final symbol in currencySymbolMap.keys) {
      if (text.contains(symbol)) {
        return true;
      }
    }

    // Check for codes using regex
    final codePattern = RegExp(currencyCodePattern, caseSensitive: false);
    return codePattern.hasMatch(text);
  }

  /// Convert currency code string to Currency enum
  /// Returns Currency enum value, defaults to EUR if not found
  static Currency fromCode(String code) {
    return currencyCodeMap[code.toLowerCase()] ?? Currency.eur;
  }

  /// Get currency symbol for a Currency enum
  /// Returns the symbol string for the given currency
  static String getSymbol(Currency currency) {
    return currency.symbol;
  }

  /// Get currency code for a Currency enum
  /// Returns the code string for the given currency
  static String getCode(Currency currency) {
    return currency.code;
  }
}

