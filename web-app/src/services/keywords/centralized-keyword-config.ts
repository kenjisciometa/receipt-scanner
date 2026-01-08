/**
 * Centralized Keyword Configuration
 * 
 * This file consolidates all multilingual keywords and patterns
 * that were previously scattered across multiple files.
 * Provides a single source of truth for multilingual receipt processing.
 */

import { SupportedLanguage, KeywordCategory } from './language-keywords';

/**
 * Enhanced keyword configuration with additional metadata
 */
export interface KeywordEntry {
  /** The keyword text */
  text: string;
  /** Confidence boost for this specific keyword */
  confidence?: number;
  /** Alternative spellings or variations */
  variations?: string[];
  /** Context where this keyword is most effective */
  context?: 'formal' | 'informal' | 'abbreviated' | 'full';
  /** Common patterns this keyword appears in */
  commonPatterns?: string[];
}

/**
 * Extended field types beyond basic categories
 */
export type ExtendedFieldType = KeywordCategory | 
  'tax_breakdown' | 'tax_rate' | 'tax_amount' | 'net_amount' | 'gross_amount' |
  'merchant_info' | 'date_time' | 'payment_info' | 'line_item' | 'discount' | 
  'service_charge' | 'tip' | 'cash_back' | 'change_given';

/**
 * Table-specific column headers
 */
export interface TableColumnConfig {
  type: 'rate' | 'net' | 'tax' | 'gross' | 'description' | 'quantity' | 'price';
  keywords: Record<SupportedLanguage, KeywordEntry[]>;
  patterns: Record<SupportedLanguage, string[]>;
}

/**
 * Number format configuration per language
 */
export interface NumberFormatConfig {
  /** Decimal separator preference */
  decimal: ',' | '.';
  /** Thousands separator */
  thousands?: ',' | '.' | ' ' | '';
  /** Currency symbol position */
  currencyPosition: 'prefix' | 'suffix';
  /** Common currency symbols for this language/region */
  currencies: string[];
  /** Number patterns specific to this language */
  patterns: {
    /** Pattern for whole numbers */
    integer: string;
    /** Pattern for decimal numbers */
    decimal: string;
    /** Pattern for currency amounts */
    currency: string;
    /** Pattern for percentages */
    percentage: string;
  };
}

/**
 * Comprehensive multilingual configuration
 */
export interface MultilingualConfig {
  /** Basic field keywords */
  keywords: Record<ExtendedFieldType, Record<SupportedLanguage, KeywordEntry[]>>;
  /** Table-specific configurations */
  tableColumns: Record<string, TableColumnConfig>;
  /** Number formatting rules */
  numberFormats: Record<SupportedLanguage, NumberFormatConfig>;
  /** Common separator patterns */
  separators: Record<SupportedLanguage, string[]>;
  /** Language-specific regex flags */
  regexFlags: Record<SupportedLanguage, string>;
}

/**
 * Centralized keyword and pattern configuration
 */
export const MULTILINGUAL_CONFIG: MultilingualConfig = {
  
  // ========== KEYWORDS ==========
  keywords: {
    
    // TOTAL FIELD
    total: {
      en: [
        { text: 'total', confidence: 0.9 },
        { text: 'sum', confidence: 0.8 },
        { text: 'amount', confidence: 0.7 },
        { text: 'grand total', confidence: 0.95 },
        { text: 'amount due', confidence: 0.9 },
        { text: 'balance due', confidence: 0.9 },
        { text: 'final amount', confidence: 0.85 }
      ],
      fi: [
        { text: 'yhteensä', confidence: 0.95 },
        { text: 'summa', confidence: 0.9 },
        { text: 'loppusumma', confidence: 0.9 },
        { text: 'maksettava', confidence: 0.85 },
        { text: 'maksu', confidence: 0.8 }
      ],
      de: [
        { text: 'summe', confidence: 0.95 },
        { text: 'gesamt', confidence: 0.9 },
        { text: 'betrag', confidence: 0.85 },
        { text: 'gesamtbetrag', confidence: 0.95 },
        { text: 'endsumme', confidence: 0.9 },
        { text: 'zu zahlen', confidence: 0.9 }
      ],
      sv: [
        { text: 'totalt', confidence: 0.9 },
        { text: 'summa', confidence: 0.85 },
        { text: 'att betala', confidence: 0.9 },
        { text: 'slutsumma', confidence: 0.9 }
      ],
      fr: [
        { text: 'total', confidence: 0.9 },
        { text: 'montant total', confidence: 0.95 },
        { text: 'somme', confidence: 0.8 },
        { text: 'à payer', confidence: 0.9 },
        { text: 'net à payer', confidence: 0.9 },
        { text: 'total ttc', confidence: 0.95 }
      ],
      it: [
        { text: 'totale', confidence: 0.9 },
        { text: 'importo', confidence: 0.85 },
        { text: 'somma', confidence: 0.8 },
        { text: 'da pagare', confidence: 0.9 },
        { text: 'totale generale', confidence: 0.95 },
        { text: 'saldo', confidence: 0.8 }
      ],
      es: [
        { text: 'total', confidence: 0.9 },
        { text: 'importe', confidence: 0.85 },
        { text: 'suma', confidence: 0.8 },
        { text: 'a pagar', confidence: 0.9 },
        { text: 'total general', confidence: 0.95 },
        { text: 'precio total', confidence: 0.9 }
      ]
    },

    // SUBTOTAL FIELD
    subtotal: {
      en: [
        { text: 'subtotal', confidence: 0.95 },
        { text: 'sub-total', confidence: 0.95 },
        { text: 'sub total', confidence: 0.95 },
        { text: 'net', confidence: 0.8, context: 'abbreviated' },
        { text: 'merchandise total', confidence: 0.9 },
        { text: 'items total', confidence: 0.85 }
      ],
      fi: [
        { text: 'välisumma', confidence: 0.95 },
        { text: 'alasumma', confidence: 0.9 }
      ],
      de: [
        { text: 'zwischensumme', confidence: 0.95 },
        { text: 'netto', confidence: 0.9 },
        { text: 'nettosumme', confidence: 0.95 }
      ],
      sv: [
        { text: 'delsumma', confidence: 0.9 },
        { text: 'mellansumma', confidence: 0.9 }
      ],
      fr: [
        { text: 'sous-total', confidence: 0.95 },
        { text: 'montant ht', confidence: 0.9 }
      ],
      it: [
        { text: 'subtotale', confidence: 0.95 },
        { text: 'imponibile', confidence: 0.9 }
      ],
      es: [
        { text: 'subtotal', confidence: 0.95 },
        { text: 'base imponible', confidence: 0.9 }
      ]
    },

    // TAX FIELD
    tax: {
      en: [
        { text: 'vat', confidence: 0.95, context: 'abbreviated' },
        { text: 'tax', confidence: 0.9 },
        { text: 'sales tax', confidence: 0.95 },
        { text: 'state tax', confidence: 0.9 },
        { text: 'local tax', confidence: 0.9 },
        { text: 'tax amount', confidence: 0.9 },
        { text: 'total tax', confidence: 0.95 }
      ],
      fi: [
        { text: 'alv', confidence: 0.95, context: 'abbreviated' },
        { text: 'arvonlisävero', confidence: 0.95, context: 'full' },
        { text: 'vero', confidence: 0.85 }
      ],
      de: [
        { text: 'mwst', confidence: 0.95, context: 'abbreviated' },
        { text: 'ust', confidence: 0.95, context: 'abbreviated' },
        { text: 'umsatzsteuer', confidence: 0.95, context: 'full' },
        { text: 'steuer', confidence: 0.9 }
      ],
      sv: [
        { text: 'moms', confidence: 0.95, context: 'abbreviated' },
        { text: 'mervärdesskatt', confidence: 0.95, context: 'full' }
      ],
      fr: [
        { text: 'tva', confidence: 0.95, context: 'abbreviated' },
        { text: 'taxe', confidence: 0.9 }
      ],
      it: [
        { text: 'iva', confidence: 0.95, context: 'abbreviated' },
        { text: 'imposta', confidence: 0.9 }
      ],
      es: [
        { text: 'iva', confidence: 0.95, context: 'abbreviated' },
        { text: 'impuesto', confidence: 0.9 }
      ]
    },

    // TAX BREAKDOWN (NEW)
    tax_breakdown: {
      en: [
        { text: 'tax breakdown', confidence: 0.95 },
        { text: 'vat breakdown', confidence: 0.95 },
        { text: 'tax details', confidence: 0.9 }
      ],
      fi: [
        { text: 'alv erittelyä', confidence: 0.95 },
        { text: 'vero erittelyä', confidence: 0.9 }
      ],
      de: [
        { text: 'steuer aufschlüsselung', confidence: 0.95 },
        { text: 'mwst aufgliederung', confidence: 0.95 },
        { text: 'ust aufschlüsselung', confidence: 0.95 }
      ],
      sv: [
        { text: 'moms uppdelning', confidence: 0.95 },
        { text: 'skatt uppdelning', confidence: 0.9 }
      ],
      fr: [
        { text: 'détail tva', confidence: 0.95 },
        { text: 'répartition taxe', confidence: 0.9 }
      ],
      it: [
        { text: 'dettaglio iva', confidence: 0.95 },
        { text: 'ripartizione imposta', confidence: 0.9 }
      ],
      es: [
        { text: 'detalle iva', confidence: 0.95 },
        { text: 'desglose impuesto', confidence: 0.9 }
      ]
    },

    // Continue with other field types...
    payment: {
      en: [{ text: 'payment', confidence: 0.9 }],
      fi: [{ text: 'maksutapa', confidence: 0.9 }],
      de: [{ text: 'zahlung', confidence: 0.9 }],
      sv: [{ text: 'betalning', confidence: 0.9 }],
      fr: [{ text: 'paiement', confidence: 0.9 }],
      it: [{ text: 'pagamento', confidence: 0.9 }],
      es: [{ text: 'pago', confidence: 0.9 }]
    },

    payment_method_cash: {
      en: [{ text: 'cash', confidence: 0.95 }],
      fi: [{ text: 'käteinen', confidence: 0.95 }],
      de: [{ text: 'bar', confidence: 0.95 }],
      sv: [{ text: 'kontanter', confidence: 0.95 }],
      fr: [{ text: 'espèces', confidence: 0.95 }],
      it: [{ text: 'contanti', confidence: 0.95 }],
      es: [{ text: 'efectivo', confidence: 0.95 }]
    },

    payment_method_card: {
      en: [{ text: 'card', confidence: 0.95 }],
      fi: [{ text: 'kortti', confidence: 0.95 }],
      de: [{ text: 'karte', confidence: 0.95 }],
      sv: [{ text: 'kort', confidence: 0.95 }],
      fr: [{ text: 'carte', confidence: 0.95 }],
      it: [{ text: 'carta', confidence: 0.95 }],
      es: [{ text: 'tarjeta', confidence: 0.95 }]
    },

    receipt: {
      en: [{ text: 'receipt', confidence: 0.95 }],
      fi: [{ text: 'kuitti', confidence: 0.95 }],
      de: [{ text: 'rechnung', confidence: 0.9 }, { text: 'bon', confidence: 0.9 }, { text: 'quittung', confidence: 0.95 }],
      sv: [{ text: 'kvitto', confidence: 0.95 }],
      fr: [{ text: 'reçu', confidence: 0.95 }],
      it: [{ text: 'ricevuta', confidence: 0.95 }],
      es: [{ text: 'recibo', confidence: 0.95 }]
    },

    invoice: {
      en: [{ text: 'invoice', confidence: 0.95 }, { text: 'bill', confidence: 0.9 }],
      fi: [{ text: 'lasku', confidence: 0.95 }, { text: 'faktuura', confidence: 0.9 }],
      de: [{ text: 'rechnung', confidence: 0.95 }, { text: 'faktura', confidence: 0.9 }],
      sv: [{ text: 'faktura', confidence: 0.95 }, { text: 'räkning', confidence: 0.9 }],
      fr: [{ text: 'facture', confidence: 0.95 }],
      it: [{ text: 'fattura', confidence: 0.95 }],
      es: [{ text: 'factura', confidence: 0.95 }]
    },

    invoice_specific: {
      en: [
        { text: 'bill to', confidence: 0.9 },
        { text: 'ship to', confidence: 0.9 },
        { text: 'due date', confidence: 0.95 },
        { text: 'payment terms', confidence: 0.9 },
        { text: 'invoice number', confidence: 0.95 },
        { text: 'invoice #', confidence: 0.95 }
      ],
      fi: [
        { text: 'laskutettava', confidence: 0.9 },
        { text: 'toimitusosoite', confidence: 0.9 },
        { text: 'eräpäivä', confidence: 0.95 },
        { text: 'maksuehto', confidence: 0.9 },
        { text: 'laskun numero', confidence: 0.95 }
      ],
      de: [
        { text: 'rechnungsempfänger', confidence: 0.9 },
        { text: 'lieferadresse', confidence: 0.9 },
        { text: 'fälligkeitsdatum', confidence: 0.95 },
        { text: 'zahlungsbedingungen', confidence: 0.9 },
        { text: 'rechnungsnummer', confidence: 0.95 }
      ],
      sv: [
        { text: 'fakturera till', confidence: 0.9 },
        { text: 'leveransadress', confidence: 0.9 },
        { text: 'förfallodatum', confidence: 0.95 },
        { text: 'betalningsvillkor', confidence: 0.9 },
        { text: 'fakturanummer', confidence: 0.95 }
      ],
      fr: [
        { text: 'facturer à', confidence: 0.9 },
        { text: 'livrer à', confidence: 0.9 },
        { text: 'date d\'échéance', confidence: 0.95 },
        { text: 'conditions de paiement', confidence: 0.9 },
        { text: 'numéro de facture', confidence: 0.95 }
      ],
      it: [
        { text: 'fatturare a', confidence: 0.9 },
        { text: 'spedire a', confidence: 0.9 },
        { text: 'data di scadenza', confidence: 0.95 },
        { text: 'termini di pagamento', confidence: 0.9 },
        { text: 'numero fattura', confidence: 0.95 }
      ],
      es: [
        { text: 'facturar a', confidence: 0.9 },
        { text: 'enviar a', confidence: 0.9 },
        { text: 'fecha de vencimiento', confidence: 0.95 },
        { text: 'términos de pago', confidence: 0.9 },
        { text: 'número de factura', confidence: 0.95 }
      ]
    },

    receipt_specific: {
      en: [
        { text: 'thank you', confidence: 0.8 },
        { text: 'thank you for your purchase', confidence: 0.9 },
        { text: 'visitor copy', confidence: 0.9 },
        { text: 'customer copy', confidence: 0.9 },
        { text: 'paid', confidence: 0.85 },
        { text: 'payment received', confidence: 0.9 }
      ],
      fi: [
        { text: 'kiitos', confidence: 0.8 },
        { text: 'kiitos ostoksestasi', confidence: 0.9 },
        { text: 'asiakasnäyte', confidence: 0.9 },
        { text: 'maksettu', confidence: 0.85 },
        { text: 'maksu vastaanotettu', confidence: 0.9 }
      ],
      de: [
        { text: 'danke', confidence: 0.8 },
        { text: 'vielen dank für ihren einkauf', confidence: 0.9 },
        { text: 'kundenbeleg', confidence: 0.9 },
        { text: 'bezahlt', confidence: 0.85 },
        { text: 'zahlung erhalten', confidence: 0.9 }
      ],
      sv: [
        { text: 'tack', confidence: 0.8 },
        { text: 'tack för ditt köp', confidence: 0.9 },
        { text: 'kundkopia', confidence: 0.9 },
        { text: 'betalad', confidence: 0.85 },
        { text: 'betalning mottagen', confidence: 0.9 }
      ],
      fr: [
        { text: 'merci', confidence: 0.8 },
        { text: 'merci pour votre achat', confidence: 0.9 },
        { text: 'copie client', confidence: 0.9 },
        { text: 'payé', confidence: 0.85 },
        { text: 'paiement reçu', confidence: 0.9 }
      ],
      it: [
        { text: 'grazie', confidence: 0.8 },
        { text: 'grazie per il tuo acquisto', confidence: 0.9 },
        { text: 'copia cliente', confidence: 0.9 },
        { text: 'pagato', confidence: 0.85 },
        { text: 'pagamento ricevuto', confidence: 0.9 }
      ],
      es: [
        { text: 'gracias', confidence: 0.8 },
        { text: 'gracias por su compra', confidence: 0.9 },
        { text: 'copia del cliente', confidence: 0.9 },
        { text: 'pagado', confidence: 0.85 },
        { text: 'pago recibido', confidence: 0.9 }
      ]
    },

    item_table_header: {
      en: [
        { text: 'qty', confidence: 0.9 },
        { text: 'quantity', confidence: 0.95 },
        { text: 'description', confidence: 0.9 },
        { text: 'item', confidence: 0.85 },
        { text: 'product', confidence: 0.85 },
        { text: 'unit price', confidence: 0.9 },
        { text: 'unit', confidence: 0.8 },
        { text: 'price', confidence: 0.85 },
        { text: 'amount', confidence: 0.8 },
        { text: 'vat', confidence: 0.9 },
        { text: 'tax', confidence: 0.9 },
        { text: 'sales tax', confidence: 0.9 }
      ],
      fi: [
        { text: 'määrä', confidence: 0.9 },
        { text: 'kappalemäärä', confidence: 0.95 },
        { text: 'kuvaus', confidence: 0.9 },
        { text: 'tuote', confidence: 0.85 },
        { text: 'yksikköhinta', confidence: 0.9 },
        { text: 'hinta', confidence: 0.85 },
        { text: 'summa', confidence: 0.8 },
        { text: 'alv', confidence: 0.9 },
        { text: 'arvonlisävero', confidence: 0.9 }
      ],
      de: [
        { text: 'menge', confidence: 0.9 },
        { text: 'anzahl', confidence: 0.95 },
        { text: 'beschreibung', confidence: 0.9 },
        { text: 'artikel', confidence: 0.85 },
        { text: 'produkt', confidence: 0.85 },
        { text: 'einzelpreis', confidence: 0.9 },
        { text: 'preis', confidence: 0.85 },
        { text: 'betrag', confidence: 0.8 },
        { text: 'mwst', confidence: 0.9 },
        { text: 'ust', confidence: 0.9 },
        { text: 'umsatzsteuer', confidence: 0.9 },
        { text: 'steuer', confidence: 0.85 },
        { text: 'netto', confidence: 0.85 },
        { text: 'brutto', confidence: 0.85 }
      ],
      sv: [
        { text: 'kvantitet', confidence: 0.9 },
        { text: 'antal', confidence: 0.95 },
        { text: 'beskrivning', confidence: 0.9 },
        { text: 'produkt', confidence: 0.85 },
        { text: 'enhetspris', confidence: 0.9 },
        { text: 'pris', confidence: 0.85 },
        { text: 'belopp', confidence: 0.8 },
        { text: 'moms', confidence: 0.9 },
        { text: 'mervärdesskatt', confidence: 0.9 }
      ],
      fr: [
        { text: 'quantité', confidence: 0.9 },
        { text: 'description', confidence: 0.9 },
        { text: 'article', confidence: 0.85 },
        { text: 'produit', confidence: 0.85 },
        { text: 'prix unitaire', confidence: 0.9 },
        { text: 'prix', confidence: 0.85 },
        { text: 'montant', confidence: 0.8 },
        { text: 'tva', confidence: 0.9 },
        { text: 'taxe', confidence: 0.85 }
      ],
      it: [
        { text: 'quantità', confidence: 0.9 },
        { text: 'descrizione', confidence: 0.9 },
        { text: 'articolo', confidence: 0.85 },
        { text: 'prodotto', confidence: 0.85 },
        { text: 'prezzo unitario', confidence: 0.9 },
        { text: 'prezzo', confidence: 0.85 },
        { text: 'importo', confidence: 0.8 },
        { text: 'iva', confidence: 0.9 },
        { text: 'imposta', confidence: 0.85 }
      ],
      es: [
        { text: 'cantidad', confidence: 0.9 },
        { text: 'descripción', confidence: 0.9 },
        { text: 'artículo', confidence: 0.85 },
        { text: 'producto', confidence: 0.85 },
        { text: 'precio unitario', confidence: 0.9 },
        { text: 'precio', confidence: 0.85 },
        { text: 'importe', confidence: 0.8 },
        { text: 'iva', confidence: 0.9 },
        { text: 'impuesto', confidence: 0.85 }
      ]
    },

    change: {
      en: [
        { text: 'change', confidence: 0.9 },
        { text: 'change due', confidence: 0.95 },
        { text: 'your change', confidence: 0.95 },
        { text: 'cash back', confidence: 0.9 }
      ],
      fi: [{ text: 'vaihtoraha', confidence: 0.95 }],
      de: [
        { text: 'wechselgeld', confidence: 0.95 },
        { text: 'rückgeld', confidence: 0.9 }
      ],
      sv: [{ text: 'växel', confidence: 0.95 }],
      fr: [
        { text: 'monnaie', confidence: 0.9 },
        { text: 'rendu', confidence: 0.85 }
      ],
      it: [{ text: 'resto', confidence: 0.95 }],
      es: [
        { text: 'cambio', confidence: 0.9 },
        { text: 'vuelto', confidence: 0.9 }
      ]
    },

    receipt_number: {
      en: [
        { text: 'receipt #', confidence: 0.95 },
        { text: 'receipt no', confidence: 0.95 },
        { text: 'transaction #', confidence: 0.9 },
        { text: 'trans id', confidence: 0.85 },
        { text: 'ref #', confidence: 0.8 }
      ],
      fi: [
        { text: 'kuitti nro', confidence: 0.95 },
        { text: 'kuitti #', confidence: 0.95 }
      ],
      de: [
        { text: 'bon nr', confidence: 0.95 },
        { text: 'bon #', confidence: 0.95 },
        { text: 'beleg nr', confidence: 0.9 }
      ],
      sv: [
        { text: 'kvitto nr', confidence: 0.95 },
        { text: 'kvitto #', confidence: 0.95 }
      ],
      fr: [
        { text: 'reçu n°', confidence: 0.95 },
        { text: 'reçu #', confidence: 0.95 }
      ],
      it: [
        { text: 'ricevuta n°', confidence: 0.95 },
        { text: 'ricevuta #', confidence: 0.95 }
      ],
      es: [
        { text: 'recibo n°', confidence: 0.95 },
        { text: 'recibo #', confidence: 0.95 }
      ]
    },

    // Extended fields
    tax_rate: {
      en: [{ text: 'tax rate', confidence: 0.9 }, { text: 'vat rate', confidence: 0.9 }],
      fi: [{ text: 'alv kanta', confidence: 0.9 }, { text: 'vero prosentti', confidence: 0.85 }],
      de: [{ text: 'steuersatz', confidence: 0.95 }, { text: 'mwst satz', confidence: 0.95 }, { text: 'ust satz', confidence: 0.95 }],
      sv: [{ text: 'momssats', confidence: 0.95 }, { text: 'skattesats', confidence: 0.9 }],
      fr: [{ text: 'taux tva', confidence: 0.95 }, { text: 'taux de taxe', confidence: 0.9 }],
      it: [{ text: 'aliquota iva', confidence: 0.95 }, { text: 'tasso imposta', confidence: 0.9 }],
      es: [{ text: 'tipo iva', confidence: 0.95 }, { text: 'tasa impuesto', confidence: 0.9 }]
    },

    tax_amount: {
      en: [{ text: 'tax amount', confidence: 0.95 }, { text: 'vat amount', confidence: 0.95 }],
      fi: [{ text: 'alv määrä', confidence: 0.95 }, { text: 'vero määrä', confidence: 0.9 }],
      de: [{ text: 'steuerbetrag', confidence: 0.95 }, { text: 'mwst betrag', confidence: 0.95 }, { text: 'ust betrag', confidence: 0.95 }],
      sv: [{ text: 'moms belopp', confidence: 0.95 }, { text: 'skatte belopp', confidence: 0.9 }],
      fr: [{ text: 'montant tva', confidence: 0.95 }, { text: 'montant taxe', confidence: 0.9 }],
      it: [{ text: 'importo iva', confidence: 0.95 }, { text: 'importo imposta', confidence: 0.9 }],
      es: [{ text: 'importe iva', confidence: 0.95 }, { text: 'importe impuesto', confidence: 0.9 }]
    },

    net_amount: {
      en: [{ text: 'net amount', confidence: 0.9 }, { text: 'net', confidence: 0.8 }],
      fi: [{ text: 'netto määrä', confidence: 0.9 }, { text: 'netto', confidence: 0.8 }],
      de: [{ text: 'netto betrag', confidence: 0.95 }, { text: 'netto', confidence: 0.9 }],
      sv: [{ text: 'netto belopp', confidence: 0.9 }, { text: 'netto', confidence: 0.8 }],
      fr: [{ text: 'montant net', confidence: 0.9 }, { text: 'net', confidence: 0.8 }],
      it: [{ text: 'importo netto', confidence: 0.9 }, { text: 'netto', confidence: 0.8 }],
      es: [{ text: 'importe neto', confidence: 0.9 }, { text: 'neto', confidence: 0.8 }]
    },

    gross_amount: {
      en: [{ text: 'gross amount', confidence: 0.9 }, { text: 'gross', confidence: 0.8 }],
      fi: [{ text: 'brutto määrä', confidence: 0.9 }, { text: 'brutto', confidence: 0.8 }],
      de: [{ text: 'brutto betrag', confidence: 0.95 }, { text: 'brutto', confidence: 0.9 }],
      sv: [{ text: 'brutto belopp', confidence: 0.9 }, { text: 'brutto', confidence: 0.8 }],
      fr: [{ text: 'montant brut', confidence: 0.9 }, { text: 'brut', confidence: 0.8 }],
      it: [{ text: 'importo lordo', confidence: 0.9 }, { text: 'lordo', confidence: 0.8 }],
      es: [{ text: 'importe bruto', confidence: 0.9 }, { text: 'bruto', confidence: 0.8 }]
    },

    // Additional extended fields can be added here
    merchant_info: {
      en: [{ text: 'merchant', confidence: 0.8 }, { text: 'store', confidence: 0.7 }],
      fi: [{ text: 'kauppias', confidence: 0.8 }, { text: 'myymälä', confidence: 0.7 }],
      de: [{ text: 'händler', confidence: 0.8 }, { text: 'geschäft', confidence: 0.7 }],
      sv: [{ text: 'handlare', confidence: 0.8 }, { text: 'butik', confidence: 0.7 }],
      fr: [{ text: 'marchand', confidence: 0.8 }, { text: 'magasin', confidence: 0.7 }],
      it: [{ text: 'commerciante', confidence: 0.8 }, { text: 'negozio', confidence: 0.7 }],
      es: [{ text: 'comerciante', confidence: 0.8 }, { text: 'tienda', confidence: 0.7 }]
    },

    date_time: {
      en: [{ text: 'date', confidence: 0.8 }, { text: 'time', confidence: 0.7 }],
      fi: [{ text: 'päivämäärä', confidence: 0.8 }, { text: 'aika', confidence: 0.7 }],
      de: [{ text: 'datum', confidence: 0.8 }, { text: 'zeit', confidence: 0.7 }],
      sv: [{ text: 'datum', confidence: 0.8 }, { text: 'tid', confidence: 0.7 }],
      fr: [{ text: 'date', confidence: 0.8 }, { text: 'heure', confidence: 0.7 }],
      it: [{ text: 'data', confidence: 0.8 }, { text: 'ora', confidence: 0.7 }],
      es: [{ text: 'fecha', confidence: 0.8 }, { text: 'hora', confidence: 0.7 }]
    },

    payment_info: {
      en: [{ text: 'payment method', confidence: 0.9 }, { text: 'paid by', confidence: 0.8 }],
      fi: [{ text: 'maksutapa', confidence: 0.9 }, { text: 'maksettu', confidence: 0.8 }],
      de: [{ text: 'zahlungsart', confidence: 0.9 }, { text: 'bezahlt mit', confidence: 0.8 }],
      sv: [{ text: 'betalningsmetod', confidence: 0.9 }, { text: 'betald med', confidence: 0.8 }],
      fr: [{ text: 'mode de paiement', confidence: 0.9 }, { text: 'payé par', confidence: 0.8 }],
      it: [{ text: 'metodo di pagamento', confidence: 0.9 }, { text: 'pagato con', confidence: 0.8 }],
      es: [{ text: 'método de pago', confidence: 0.9 }, { text: 'pagado con', confidence: 0.8 }]
    },

    line_item: {
      en: [{ text: 'item', confidence: 0.8 }, { text: 'product', confidence: 0.8 }],
      fi: [{ text: 'tuote', confidence: 0.8 }, { text: 'artikkeli', confidence: 0.8 }],
      de: [{ text: 'artikel', confidence: 0.8 }, { text: 'produkt', confidence: 0.8 }],
      sv: [{ text: 'artikel', confidence: 0.8 }, { text: 'produkt', confidence: 0.8 }],
      fr: [{ text: 'article', confidence: 0.8 }, { text: 'produit', confidence: 0.8 }],
      it: [{ text: 'articolo', confidence: 0.8 }, { text: 'prodotto', confidence: 0.8 }],
      es: [{ text: 'artículo', confidence: 0.8 }, { text: 'producto', confidence: 0.8 }]
    },

    discount: {
      en: [{ text: 'discount', confidence: 0.9 }, { text: 'off', confidence: 0.7 }],
      fi: [{ text: 'alennus', confidence: 0.9 }, { text: 'ale', confidence: 0.8 }],
      de: [{ text: 'rabatt', confidence: 0.9 }, { text: 'nachlass', confidence: 0.8 }],
      sv: [{ text: 'rabatt', confidence: 0.9 }, { text: 'avdrag', confidence: 0.8 }],
      fr: [{ text: 'remise', confidence: 0.9 }, { text: 'réduction', confidence: 0.8 }],
      it: [{ text: 'sconto', confidence: 0.9 }, { text: 'riduzione', confidence: 0.8 }],
      es: [{ text: 'descuento', confidence: 0.9 }, { text: 'rebaja', confidence: 0.8 }]
    },

    service_charge: {
      en: [{ text: 'service charge', confidence: 0.9 }, { text: 'service fee', confidence: 0.9 }],
      fi: [{ text: 'palvelumaksu', confidence: 0.9 }, { text: 'palveluveloitus', confidence: 0.8 }],
      de: [{ text: 'servicegebühr', confidence: 0.9 }, { text: 'bedienungsgebühr', confidence: 0.9 }],
      sv: [{ text: 'serviceavgift', confidence: 0.9 }, { text: 'betjäningsavgift', confidence: 0.9 }],
      fr: [{ text: 'frais de service', confidence: 0.9 }, { text: 'charge de service', confidence: 0.8 }],
      it: [{ text: 'costo del servizio', confidence: 0.9 }, { text: 'tassa di servizio', confidence: 0.9 }],
      es: [{ text: 'cargo por servicio', confidence: 0.9 }, { text: 'tarifa de servicio', confidence: 0.9 }]
    },

    tip: {
      en: [{ text: 'tip', confidence: 0.9 }, { text: 'gratuity', confidence: 0.9 }],
      fi: [{ text: 'juomaraha', confidence: 0.9 }, { text: 'tippi', confidence: 0.8 }],
      de: [{ text: 'trinkgeld', confidence: 0.9 }, { text: 'bedienung', confidence: 0.7 }],
      sv: [{ text: 'dricks', confidence: 0.9 }, { text: 'service', confidence: 0.7 }],
      fr: [{ text: 'pourboire', confidence: 0.9 }, { text: 'service', confidence: 0.7 }],
      it: [{ text: 'mancia', confidence: 0.9 }, { text: 'servizio', confidence: 0.7 }],
      es: [{ text: 'propina', confidence: 0.9 }, { text: 'servicio', confidence: 0.7 }]
    },

    cash_back: {
      en: [{ text: 'cash back', confidence: 0.9 }, { text: 'cashback', confidence: 0.9 }],
      fi: [{ text: 'käteispalautus', confidence: 0.9 }, { text: 'takaisin käteistä', confidence: 0.8 }],
      de: [{ text: 'bargeld zurück', confidence: 0.9 }, { text: 'cashback', confidence: 0.8 }],
      sv: [{ text: 'kontanter tillbaka', confidence: 0.9 }, { text: 'cashback', confidence: 0.8 }],
      fr: [{ text: 'retrait espèces', confidence: 0.9 }, { text: 'cashback', confidence: 0.8 }],
      it: [{ text: 'prelievo contanti', confidence: 0.9 }, { text: 'cashback', confidence: 0.8 }],
      es: [{ text: 'retiro de efectivo', confidence: 0.9 }, { text: 'cashback', confidence: 0.8 }]
    },

    change_given: {
      en: [{ text: 'change given', confidence: 0.9 }, { text: 'change back', confidence: 0.8 }],
      fi: [{ text: 'annettu vaihtoraha', confidence: 0.9 }, { text: 'vaihtoraha takaisin', confidence: 0.8 }],
      de: [{ text: 'wechselgeld gegeben', confidence: 0.9 }, { text: 'rückgeld erhalten', confidence: 0.8 }],
      sv: [{ text: 'växel given', confidence: 0.9 }, { text: 'växel tillbaka', confidence: 0.8 }],
      fr: [{ text: 'monnaie rendue', confidence: 0.9 }, { text: 'rendu monnaie', confidence: 0.8 }],
      it: [{ text: 'resto dato', confidence: 0.9 }, { text: 'resto restituito', confidence: 0.8 }],
      es: [{ text: 'cambio dado', confidence: 0.9 }, { text: 'vuelto entregado', confidence: 0.8 }]
    }
  },

  // ========== TABLE COLUMNS ==========
  tableColumns: {
    taxTable: {
      type: 'rate',
      keywords: {
        en: [{ text: 'rate' }, { text: '%' }, { text: 'vat' }, { text: 'tax' }],
        fi: [{ text: 'kanta' }, { text: '%' }, { text: 'alv' }],
        de: [{ text: 'satz' }, { text: '%' }, { text: 'ust' }, { text: 'mwst' }, { text: 'steuer' }],
        sv: [{ text: 'sats' }, { text: '%' }, { text: 'moms' }],
        fr: [{ text: 'taux' }, { text: '%' }, { text: 'tva' }],
        it: [{ text: 'aliquota' }, { text: '%' }, { text: 'iva' }],
        es: [{ text: 'tipo' }, { text: '%' }, { text: 'iva' }]
      },
      patterns: {
        en: ['\\d+(?:[.,]\\d+)?\\s*%'],
        fi: ['\\d+(?:[.,]\\d+)?\\s*%'],
        de: ['\\d+(?:[.,]\\d+)?\\s*%'],
        sv: ['\\d+(?:[.,]\\d+)?\\s*%'],
        fr: ['\\d+(?:[.,]\\d+)?\\s*%'],
        it: ['\\d+(?:[.,]\\d+)?\\s*%'],
        es: ['\\d+(?:[.,]\\d+)?\\s*%']
      }
    }
  },

  // ========== NUMBER FORMATS ==========
  numberFormats: {
    en: {
      decimal: '.',
      thousands: ',',
      currencyPosition: 'prefix',
      currencies: ['$', 'USD'],
      patterns: {
        integer: '\\d{1,3}(?:,\\d{3})*',
        decimal: '\\d{1,3}(?:,\\d{3})*\\.\\d{2}',
        currency: '\\$\\s*\\d{1,3}(?:,\\d{3})*(?:\\.\\d{2})?',
        percentage: '\\d+(?:\\.\\d+)?\\s*%'
      }
    },
    de: {
      decimal: ',',
      thousands: '.',
      currencyPosition: 'suffix',
      currencies: ['€', 'EUR'],
      patterns: {
        integer: '\\d{1,3}(?:\\.\\d{3})*',
        decimal: '\\d{1,3}(?:\\.\\d{3})*,\\d{2}',
        currency: '\\d{1,3}(?:\\.\\d{3})*(?:,\\d{2})?\\s*€',
        percentage: '\\d+(?:,\\d+)?\\s*%'
      }
    },
    fi: {
      decimal: ',',
      thousands: ' ',
      currencyPosition: 'suffix',
      currencies: ['€', 'EUR'],
      patterns: {
        integer: '\\d{1,3}(?:\\s\\d{3})*',
        decimal: '\\d{1,3}(?:\\s\\d{3})*,\\d{2}',
        currency: '\\d{1,3}(?:\\s\\d{3})*(?:,\\d{2})?\\s*€',
        percentage: '\\d+(?:,\\d+)?\\s*%'
      }
    },
    sv: {
      decimal: ',',
      thousands: ' ',
      currencyPosition: 'suffix',
      currencies: ['kr', 'SEK'],
      patterns: {
        integer: '\\d{1,3}(?:\\s\\d{3})*',
        decimal: '\\d{1,3}(?:\\s\\d{3})*,\\d{2}',
        currency: '\\d{1,3}(?:\\s\\d{3})*(?:,\\d{2})?\\s*kr',
        percentage: '\\d+(?:,\\d+)?\\s*%'
      }
    },
    fr: {
      decimal: ',',
      thousands: ' ',
      currencyPosition: 'suffix',
      currencies: ['€', 'EUR'],
      patterns: {
        integer: '\\d{1,3}(?:\\s\\d{3})*',
        decimal: '\\d{1,3}(?:\\s\\d{3})*,\\d{2}',
        currency: '\\d{1,3}(?:\\s\\d{3})*(?:,\\d{2})?\\s*€',
        percentage: '\\d+(?:,\\d+)?\\s*%'
      }
    },
    it: {
      decimal: ',',
      thousands: '.',
      currencyPosition: 'suffix',
      currencies: ['€', 'EUR'],
      patterns: {
        integer: '\\d{1,3}(?:\\.\\d{3})*',
        decimal: '\\d{1,3}(?:\\.\\d{3})*,\\d{2}',
        currency: '\\d{1,3}(?:\\.\\d{3})*(?:,\\d{2})?\\s*€',
        percentage: '\\d+(?:,\\d+)?\\s*%'
      }
    },
    es: {
      decimal: ',',
      thousands: '.',
      currencyPosition: 'suffix',
      currencies: ['€', 'EUR'],
      patterns: {
        integer: '\\d{1,3}(?:\\.\\d{3})*',
        decimal: '\\d{1,3}(?:\\.\\d{3})*,\\d{2}',
        currency: '\\d{1,3}(?:\\.\\d{3})*(?:,\\d{2})?\\s*€',
        percentage: '\\d+(?:,\\d+)?\\s*%'
      }
    }
  },

  // ========== SEPARATORS ==========
  separators: {
    en: [':', '-', '=', '\\s+', '\\.', ','],
    fi: [':', '-', '=', '\\s+', '\\.', ','],
    de: [':', '-', '=', '\\s+', '\\.', ','],
    sv: [':', '-', '=', '\\s+', '\\.', ','],
    fr: [':', '-', '=', '\\s+', '\\.', ','],
    it: [':', '-', '=', '\\s+', '\\.', ','],
    es: [':', '-', '=', '\\s+', '\\.', ',']
  },

  // ========== REGEX FLAGS ==========
  regexFlags: {
    en: 'gi',
    fi: 'gi',
    de: 'gi',
    sv: 'gi', 
    fr: 'gi',
    it: 'gi',
    es: 'gi'
  }
};

/**
 * Utility functions for working with centralized configuration
 */
export class CentralizedKeywordConfig {
  
  /**
   * Get keywords for a field type and language
   */
  static getKeywords(fieldType: ExtendedFieldType, language: SupportedLanguage): KeywordEntry[] {
    return MULTILINGUAL_CONFIG.keywords[fieldType]?.[language] || [];
  }

  /**
   * Get all keyword texts for a field type and language
   */
  static getKeywordTexts(fieldType: ExtendedFieldType, language: SupportedLanguage): string[] {
    return this.getKeywords(fieldType, language).map(entry => entry.text);
  }

  /**
   * Get number format configuration for a language
   */
  static getNumberFormat(language: SupportedLanguage): NumberFormatConfig {
    return MULTILINGUAL_CONFIG.numberFormats[language];
  }

  /**
   * Get separator patterns for a language
   */
  static getSeparators(language: SupportedLanguage): string[] {
    return MULTILINGUAL_CONFIG.separators[language];
  }

  /**
   * Get regex flags for a language
   */
  static getRegexFlags(language: SupportedLanguage): string {
    return MULTILINGUAL_CONFIG.regexFlags[language];
  }

  /**
   * Check if a field type is supported
   */
  static isFieldSupported(fieldType: string): fieldType is ExtendedFieldType {
    return fieldType in MULTILINGUAL_CONFIG.keywords;
  }

  /**
   * Get all supported field types
   */
  static getSupportedFieldTypes(): ExtendedFieldType[] {
    return Object.keys(MULTILINGUAL_CONFIG.keywords) as ExtendedFieldType[];
  }

  /**
   * Get confidence boost for a specific keyword
   */
  static getKeywordConfidence(fieldType: ExtendedFieldType, language: SupportedLanguage, keyword: string): number {
    const entry = this.getKeywords(fieldType, language).find(k => k.text === keyword);
    return entry?.confidence || 0.8; // Default confidence
  }
}