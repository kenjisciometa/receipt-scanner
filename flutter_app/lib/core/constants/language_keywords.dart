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
      'de': ['zwischensumme', 'netto'],
      'it': ['subtotale', 'imponibile'],
      'es': ['subtotal', 'base imponible'],
    },
    'tax': {
      'en': ['vat', 'tax', 'sales tax'],
      'fi': ['alv', 'arvonlisävero'],
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
}

