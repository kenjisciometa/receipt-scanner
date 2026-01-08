// Document Type Classification Service (Flutter port)
import { TextLine } from '@/types/ocr';
import { DocumentType, DocumentTypeResult } from '@/types/extraction';

// Comprehensive multilingual keywords (matching Flutter implementation)
const LANGUAGE_KEYWORDS = {
  receipt: {
    en: ['receipt', 'ticket', 'bill', 'transaction receipt', 'purchase receipt'],
    fi: ['kuitti', 'ostokuitti', 'maksukuitti'],
    sv: ['kvitto', 'köpkvitto', 'betalningskvitto'],
    fr: ['reçu', 'ticket', 'reçu d\'achat'],
    de: ['quittung', 'kassenbon', 'beleg', 'kaufbeleg'],
    it: ['ricevuta', 'scontrino', 'ricevuta di pagamento'],
    es: ['recibo', 'ticket', 'comprobante de pago']
  },
  invoice: {
    en: ['invoice', 'bill', 'billing statement', 'statement of account'],
    fi: ['lasku', 'laskutusote', 'tilinote'],
    sv: ['faktura', 'räkning', 'faktureringsunderlag'],
    fr: ['facture', 'note', 'relevé de facturation'],
    de: ['rechnung', 'rechnungsstellung', 'abrechnungsbeleg'],
    it: ['fattura', 'nota', 'estratto conto'],
    es: ['factura', 'cuenta', 'estado de cuenta']
  },
  receiptSpecific: {
    en: ['thank you', 'customer copy', 'paid', 'payment received', 'cash', 'card', 'change', 'contactless'],
    fi: ['kiitos', 'asiakasnäyte', 'maksettu', 'maksu vastaanotettu', 'käteinen', 'kortti', 'vaihtorahat', 'kosketukseton'],
    sv: ['tack', 'kundkopia', 'betalad', 'betalning mottagen', 'kontant', 'kort', 'växel', 'kontaktlös'],
    fr: ['merci', 'copie client', 'payé', 'paiement reçu', 'espèces', 'carte', 'monnaie', 'sans contact'],
    de: ['danke', 'kundenbeleg', 'bezahlt', 'zahlung erhalten', 'bargeld', 'karte', 'wechselgeld', 'kontaktlos'],
    it: ['grazie', 'copia cliente', 'pagato', 'pagamento ricevuto', 'contanti', 'carta', 'resto', 'contactless'],
    es: ['gracias', 'copia del cliente', 'pagado', 'pago recibido', 'efectivo', 'tarjeta', 'cambio', 'sin contacto']
  },
  invoiceSpecific: {
    en: ['bill to', 'due date', 'payment terms', 'net 30', 'billing address', 'invoice number', 'remit to', 'unpaid', 'pending', 'overdue'],
    fi: ['laskutettava', 'eräpäivä', 'maksuehto', 'maksuaika', 'laskutusosoite', 'laskunumero', 'lähetä osoitteeseen', 'maksamaton', 'odottaa', 'erääntynyt'],
    sv: ['fakturera till', 'förfallodatum', 'betalningsvillkor', 'fakturanummer', 'skicka till', 'obetald', 'väntande', 'förfallen'],
    fr: ['facturer à', 'date d\'échéance', 'conditions de paiement', 'numéro de facture', 'envoyer à', 'impayé', 'en attente', 'en retard'],
    de: ['rechnungsempfänger', 'fälligkeitsdatum', 'zahlungsbedingungen', 'rechnungsnummer', 'senden an', 'unbezahlt', 'ausstehend', 'überfällig'],
    it: ['fatturare a', 'data di scadenza', 'termini di pagamento', 'numero fattura', 'inviare a', 'non pagato', 'in sospeso', 'scaduto'],
    es: ['facturar a', 'fecha de vencimiento', 'términos de pago', 'número de factura', 'enviar a', 'impago', 'pendiente', 'vencido']
  }
};

export class DocumentTypeClassifier {
  
  static classify(textLines: TextLine[], language: string = 'en'): DocumentTypeResult {
    let receiptScore = 0.0;
    let invoiceScore = 0.0;
    const reasons: string[] = [];
    
    // 全文結合
    const fullText = textLines.map(line => line.text).join(' ').toLowerCase();
    
    // 1. キーワードベース分類（高重要度: 2.0倍）
    const keywordScores = this.checkKeywords(fullText, language);
    receiptScore += keywordScores.receiptScore * 2.0;
    invoiceScore += keywordScores.invoiceScore * 2.0;
    
    if (keywordScores.receiptKeywords.length > 0) {
      reasons.push(`Receipt keywords found: ${keywordScores.receiptKeywords.join(', ')}`);
    }
    if (keywordScores.invoiceKeywords.length > 0) {
      reasons.push(`Invoice keywords found: ${keywordScores.invoiceKeywords.join(', ')}`);
    }
    
    // 2. 構造的特徴分析（中重要度: 1.5倍）
    const structureScores = this.checkStructuralFeatures(textLines);
    receiptScore += structureScores.receiptScore * 1.5;
    invoiceScore += structureScores.invoiceScore * 1.5;
    
    if (structureScores.reasons.length > 0) {
      reasons.push(...structureScores.reasons);
    }
    
    // 3. 金額・支払いパターン（標準重要度: 1.0倍）
    const paymentScores = this.checkPaymentPatterns(fullText);
    receiptScore += paymentScores.receiptScore;
    invoiceScore += paymentScores.invoiceScore;
    
    if (paymentScores.reasons.length > 0) {
      reasons.push(...paymentScores.reasons);
    }
    
    // 判定ロジック
    const scoreDiff = Math.abs(receiptScore - invoiceScore);
    const totalScore = receiptScore + invoiceScore;
    const confidence = totalScore > 0 ? (scoreDiff / totalScore) : 0.0;
    
    let documentType: DocumentType;
    if (receiptScore > invoiceScore + 1.0) {
      documentType = 'receipt';
    } else if (invoiceScore > receiptScore + 1.0) {
      documentType = 'invoice';
    } else {
      documentType = 'unknown';
    }
    
    return {
      documentType,
      confidence: Math.min(confidence, 1.0),
      reason: reasons.join('; '),
      receiptScore,
      invoiceScore,
    };
  }
  
  private static checkKeywords(fullText: string, language: string): {
    receiptScore: number;
    invoiceScore: number;
    receiptKeywords: string[];
    invoiceKeywords: string[];
  } {
    const lang = language as keyof (typeof LANGUAGE_KEYWORDS.receipt);
    
    // Get keywords for the specified language, fallback to English
    const receiptKeywords = [
      ...(LANGUAGE_KEYWORDS.receipt[lang] || LANGUAGE_KEYWORDS.receipt.en),
      ...(LANGUAGE_KEYWORDS.receiptSpecific[lang] || LANGUAGE_KEYWORDS.receiptSpecific.en)
    ];
    
    const invoiceKeywords = [
      ...(LANGUAGE_KEYWORDS.invoice[lang] || LANGUAGE_KEYWORDS.invoice.en),
      ...(LANGUAGE_KEYWORDS.invoiceSpecific[lang] || LANGUAGE_KEYWORDS.invoiceSpecific.en)
    ];
    
    const foundReceiptKeywords: string[] = [];
    const foundInvoiceKeywords: string[] = [];
    
    let receiptScore = 0;
    let invoiceScore = 0;
    
    // Receipt keywords check with weighted scoring
    receiptKeywords.forEach(keyword => {
      if (fullText.includes(keyword.toLowerCase())) {
        foundReceiptKeywords.push(keyword);
        // Higher weight for specific receipt indicators
        const weight = LANGUAGE_KEYWORDS.receiptSpecific[lang]?.includes(keyword) ? 1.5 : 1.0;
        receiptScore += weight;
      }
    });
    
    // Invoice keywords check with weighted scoring
    invoiceKeywords.forEach(keyword => {
      if (fullText.includes(keyword.toLowerCase())) {
        foundInvoiceKeywords.push(keyword);
        // Higher weight for specific invoice indicators
        const weight = LANGUAGE_KEYWORDS.invoiceSpecific[lang]?.includes(keyword) ? 1.5 : 1.0;
        invoiceScore += weight;
      }
    });
    
    return {
      receiptScore,
      invoiceScore,
      receiptKeywords: foundReceiptKeywords,
      invoiceKeywords: foundInvoiceKeywords,
    };
  }
  
  private static checkStructuralFeatures(textLines: TextLine[]): {
    receiptScore: number;
    invoiceScore: number;
    reasons: string[];
  } {
    let receiptScore = 0;
    let invoiceScore = 0;
    const reasons: string[] = [];
    
    const fullText = textLines.map(line => line.text).join(' ').toLowerCase();
    
    // Receipt構造特徴
    if (this.hasReceiptStructure(textLines)) {
      receiptScore += 2.0;
      reasons.push('Receipt-like structure detected');
    }
    
    // Invoice構造特徴
    if (this.hasInvoiceStructure(textLines)) {
      invoiceScore += 2.0;
      reasons.push('Invoice-like structure detected');
    }
    
    // 文書の長さによる判定（レシートは通常短い）
    if (textLines.length < 20) {
      receiptScore += 0.5;
      reasons.push('Short document (receipt-like)');
    } else if (textLines.length > 30) {
      invoiceScore += 0.5;
      reasons.push('Long document (invoice-like)');
    }
    
    return { receiptScore, invoiceScore, reasons };
  }
  
  private static hasReceiptStructure(textLines: TextLine[]): boolean {
    const fullText = textLines.map(line => line.text).join(' ').toLowerCase();
    
    // レシートらしい構造の特徴
    const receiptPatterns = [
      /total.*[\d.,]+/i,           // "TOTAL 15.60"
      /thanks?.*visit/i,           // "Thank you for visiting"
      /change.*[\d.,]+/i,          // "CHANGE 2.40"
      /cash.*[\d.,]+/i,           // "CASH 18.00"
      /card.*[\d.,]+/i,           // "CARD ****1234"
    ];
    
    return receiptPatterns.some(pattern => pattern.test(fullText));
  }
  
  private static hasInvoiceStructure(textLines: TextLine[]): boolean {
    const fullText = textLines.map(line => line.text).join(' ').toLowerCase();
    
    // 請求書らしい構造の特徴
    const invoicePatterns = [
      /due.*date/i,                // "Due Date"
      /bill.*to/i,                 // "Bill To"
      /net.*\d+/i,                 // "Net 30"
      /remit.*to/i,                // "Remit To"
      /payment.*terms/i,           // "Payment Terms"
      /invoice.*number/i,          // "Invoice Number"
    ];
    
    return invoicePatterns.some(pattern => pattern.test(fullText));
  }
  
  private static checkPaymentPatterns(fullText: string): {
    receiptScore: number;
    invoiceScore: number;
    reasons: string[];
  } {
    let receiptScore = 0;
    let invoiceScore = 0;
    const reasons: string[] = [];
    
    // Receipt支払いパターン
    const receiptPaymentPatterns = [
      /cash/i,
      /card/i,
      /contactless/i,
      /paid/i,
      /change/i,
    ];
    
    // Invoice支払いパターン
    const invoicePaymentPatterns = [
      /unpaid/i,
      /pending/i,
      /overdue/i,
      /net \d+/i,
      /payment due/i,
    ];
    
    receiptPaymentPatterns.forEach(pattern => {
      if (pattern.test(fullText)) {
        receiptScore += 0.5;
        reasons.push(`Receipt payment pattern: ${pattern.source}`);
      }
    });
    
    invoicePaymentPatterns.forEach(pattern => {
      if (pattern.test(fullText)) {
        invoiceScore += 0.5;
        reasons.push(`Invoice payment pattern: ${pattern.source}`);
      }
    });
    
    return { receiptScore, invoiceScore, reasons };
  }
}