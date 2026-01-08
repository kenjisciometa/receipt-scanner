// Document Type Classifier - Based on Flutter implementation
import { TextLine } from '@/types/ocr';

export interface DocumentTypeResult {
  documentType: 'receipt' | 'invoice' | 'unknown';
  confidence: number;        // 0.0-1.0
  reason: string;           // Human-readable reason for classification
  receiptScore: number;     // Score for receipt classification
  invoiceScore: number;     // Score for invoice classification
}

/**
 * Document Type Classifier
 * Classifies documents as receipt, invoice, or unknown based on text analysis
 * Uses the same multi-factor approach as Flutter implementation
 */
export class DocumentTypeClassifier {
  
  /**
   * Classify document type based on text lines
   * Returns DocumentTypeResult with classification and confidence
   */
  static classify(textLines: TextLine[], detectedLanguage?: string): DocumentTypeResult {
    let receiptScore = 0.0;
    let invoiceScore = 0.0;
    const reasons: string[] = [];

    if (!textLines || textLines.length === 0) {
      return {
        documentType: 'unknown',
        confidence: 0.0,
        reason: 'No text lines available',
        receiptScore: 0.0,
        invoiceScore: 0.0,
      };
    }

    const normalizedText = textLines.map((line) => line.text.toLowerCase()).join(' ');

    // 1. Keyword-based classification (weight: high = 2.0)
    const receiptKeywordScore = this.checkReceiptKeywords(normalizedText, detectedLanguage);
    const invoiceKeywordScore = this.checkInvoiceKeywords(normalizedText, detectedLanguage);
    
    receiptScore += receiptKeywordScore * 2.0;
    invoiceScore += invoiceKeywordScore * 2.0;
    
    if (receiptKeywordScore > 0) {
      reasons.push(`Found receipt keywords (score: ${receiptKeywordScore.toFixed(2)})`);
    }
    if (invoiceKeywordScore > 0) {
      reasons.push(`Found invoice keywords (score: ${invoiceKeywordScore.toFixed(2)})`);
    }

    // 2. Layout complexity (weight: medium = 1.0)
    const layoutScore = this.checkLayoutComplexity(textLines);
    receiptScore += layoutScore.receipt * 1.0;
    invoiceScore += layoutScore.invoice * 1.0;
    
    if (layoutScore.receipt > 0.5) {
      reasons.push('Simple layout suggests receipt');
    }
    if (layoutScore.invoice > 0.5) {
      reasons.push('Complex layout suggests invoice');
    }

    // 3. Information detail level (weight: medium = 1.0)
    const detailScore = this.checkInformationDetail(textLines, normalizedText);
    receiptScore += detailScore.receipt * 1.0;
    invoiceScore += detailScore.invoice * 1.0;
    
    if (detailScore.receipt > 0.5) {
      reasons.push('Simple information structure suggests receipt');
    }
    if (detailScore.invoice > 0.5) {
      reasons.push('Detailed information structure suggests invoice');
    }

    // 4. Date types (weight: low = 0.5)
    const dateScore = this.checkDateTypes(normalizedText);
    receiptScore += dateScore.receipt * 0.5;
    invoiceScore += dateScore.invoice * 0.5;
    
    if (dateScore.invoice > 0.5) {
      reasons.push('Multiple date types found (invoice indicator)');
    }

    // Determine document type
    const scoreDifference = Math.abs(receiptScore - invoiceScore);
    const totalScore = receiptScore + invoiceScore;
    const confidence = totalScore > 0 ? Math.min(scoreDifference / totalScore, 1.0) : 0.0;
    
    let documentType: 'receipt' | 'invoice' | 'unknown';
    if (receiptScore > invoiceScore + 1.0) {
      documentType = 'receipt';
    } else if (invoiceScore > receiptScore + 1.0) {
      documentType = 'invoice';
    } else {
      documentType = 'unknown';
    }

    const reason = reasons.length === 0 
        ? 'Insufficient evidence for classification'
        : reasons.join('; ');

    console.log(`📄 [DocumentClassifier] Document type: ${documentType} ` +
        `(receipt: ${receiptScore.toFixed(2)}, invoice: ${invoiceScore.toFixed(2)}, ` +
        `confidence: ${confidence.toFixed(2)})`);

    return {
      documentType,
      confidence,
      reason,
      receiptScore,
      invoiceScore,
    };
  }

  /**
   * Check for receipt-specific keywords with language prioritization
   */
  private static checkReceiptKeywords(normalizedText: string, language?: string): number {
    let score = 0.0;
    
    // Language-specific receipt keywords (stronger match for detected language)
    const languageSpecificKeywords: { [key: string]: string[] } = {
      'en': ['receipt', 'thank you', 'visitor copy', 'customer copy', 'paid', 'payment received'],
      'fi': ['kuitti', 'kiitos', 'kiitos ostoksestasi', 'asiakasnäyte', 'maksettu', 'maksu vastaanotettu'],
      'sv': ['kvitto', 'tack', 'tack för ditt köp', 'kundkopia', 'betalad', 'betalning mottagen'],
      'fr': ['reçu', 'bon', 'merci', 'merci pour votre achat', 'copie client', 'payé', 'paiement reçu'],
      'de': ['rechnung', 'quittung', 'danke', 'vielen dank für ihren einkauf', 'kundenbeleg', 'bezahlt', 'zahlung erhalten'],
      'it': ['ricevuta', 'grazie', 'grazie per il tuo acquisto', 'copia cliente', 'pagato', 'pagamento ricevuto'],
      'es': ['recibo', 'gracias', 'gracias por su compra', 'copia del cliente', 'pagado', 'pago recibido'],
      'ja': ['レシート', 'ありがとう', 'お客様控え', '支払済み', 'お支払い完了'],
    };

    // Check language-specific keywords first (higher weight)
    if (language && languageSpecificKeywords[language]) {
      for (const keyword of languageSpecificKeywords[language]) {
        if (normalizedText.includes(keyword.toLowerCase())) {
          score += 3.0; // Higher score for language-specific matches
        }
      }
    }
    
    // Receipt keywords (basic) - all languages
    const receiptKeywords = [
      'receipt', 'kuitti', 'kvitto', 'reçu', 'rechnung', 'bon', 'quittung', 'ricevuta', 'recibo', 'レシート'
    ];
    for (const keyword of receiptKeywords) {
      if (normalizedText.includes(keyword.toLowerCase())) {
        // Lower score if already matched in language-specific
        const weightMultiplier = (language && languageSpecificKeywords[language]?.includes(keyword)) ? 0.5 : 1.0;
        score += 1.0 * weightMultiplier;
      }
    }
    
    // Receipt-specific keywords (stronger indicator) - all languages
    const receiptSpecificKeywords = [
      'thank you', 'thank you for your purchase', 'visitor copy', 'customer copy', 'paid', 'payment received',
      'kiitos', 'kiitos ostoksestasi', 'asiakasnäyte', 'maksettu', 'maksu vastaanotettu',
      'tack', 'tack för ditt köp', 'kundkopia', 'betalad', 'betalning mottagen',
      'merci', 'merci pour votre achat', 'copie client', 'payé', 'paiement reçu',
      'danke', 'vielen dank für ihren einkauf', 'kundenbeleg', 'bezahlt', 'zahlung erhalten',
      'grazie', 'grazie per il tuo acquisto', 'copia cliente', 'pagato', 'pagamento ricevuto',
      'gracias', 'gracias por su compra', 'copia del cliente', 'pagado', 'pago recibido',
      'ありがとう', 'お客様控え', '支払済み', 'お支払い完了'
    ];
    for (const keyword of receiptSpecificKeywords) {
      if (normalizedText.includes(keyword.toLowerCase())) {
        // Lower score if already matched in language-specific
        const weightMultiplier = (language && languageSpecificKeywords[language]?.includes(keyword)) ? 0.5 : 1.0;
        score += 2.0 * weightMultiplier;
      }
    }
    
    return score;
  }

  /**
   * Check for invoice-specific keywords with language prioritization
   */
  private static checkInvoiceKeywords(normalizedText: string, language?: string): number {
    let score = 0.0;
    
    // Language-specific invoice keywords (stronger match for detected language)
    const languageSpecificKeywords: { [key: string]: string[] } = {
      'en': ['invoice', 'bill', 'bill to', 'ship to', 'due date', 'payment terms', 'invoice number', 'net 30', 'payment due'],
      'fi': ['lasku', 'faktuura', 'laskutettava', 'toimitusosoite', 'eräpäivä', 'maksuehto', 'laskun numero', 'maksuaika'],
      'sv': ['faktura', 'räkning', 'fakturera till', 'leveransadress', 'förfallodatum', 'betalningsvillkor', 'fakturanummer'],
      'fr': ['facture', 'facturer à', 'livrer à', 'date d\'échéance', 'conditions de paiement', 'numéro de facture'],
      'de': ['rechnung', 'rechnungsempfänger', 'lieferadresse', 'fälligkeitsdatum', 'zahlungsbedingungen', 'rechnungsnummer'],
      'it': ['fattura', 'fatturare a', 'spedire a', 'data di scadenza', 'termini di pagamento', 'numero fattura'],
      'es': ['factura', 'facturar a', 'enviar a', 'fecha de vencimiento', 'términos de pago', 'número de factura'],
      'ja': ['請求書', '請求先', '支払期限', '支払条件', '請求書番号', '納期'],
    };

    // Check language-specific keywords first (higher weight)
    if (language && languageSpecificKeywords[language]) {
      for (const keyword of languageSpecificKeywords[language]) {
        if (normalizedText.includes(keyword.toLowerCase())) {
          score += 3.0; // Higher score for language-specific matches
        }
      }
    }
    
    // Invoice keywords (basic) - all languages
    const invoiceKeywords = [
      'invoice', 'bill', 'lasku', 'faktuura', 'faktura', 'räkning', 'facture', 'rechnung', 'fattura', '請求書'
    ];
    for (const keyword of invoiceKeywords) {
      if (normalizedText.includes(keyword.toLowerCase())) {
        // Lower score if already matched in language-specific
        const weightMultiplier = (language && languageSpecificKeywords[language]?.includes(keyword)) ? 0.5 : 1.0;
        score += 1.0 * weightMultiplier;
      }
    }
    
    // Invoice-specific keywords (stronger indicator) - all languages
    const invoiceSpecificKeywords = [
      'bill to', 'ship to', 'due date', 'payment terms', 'invoice number', 'invoice #', 'net 30', 'net 60', 
      'payment due', 'terms', 'billing address',
      'laskutettava', 'toimitusosoite', 'eräpäivä', 'maksuehto', 'laskun numero', 'lasku nro', 
      'maksuaika', 'laskutusosoite',
      'fakturera till', 'leveransadress', 'förfallodatum', 'betalningsvillkor', 'fakturanummer', 'faktura nr',
      'facturer à', 'livrer à', 'date d\'échéance', 'conditions de paiement', 'numéro de facture', 'facture n°',
      'rechnungsempfänger', 'lieferadresse', 'fälligkeitsdatum', 'zahlungsbedingungen', 'rechnungsnummer', 
      'rechnung nr', 'zahlungsziel',
      'fatturare a', 'spedire a', 'data di scadenza', 'termini di pagamento', 'numero fattura', 'fattura n°',
      'facturar a', 'enviar a', 'fecha de vencimiento', 'términos de pago', 'número de factura', 'factura nº',
      '請求先', '支払期限', '支払条件', '請求書番号', '納期'
    ];
    for (const keyword of invoiceSpecificKeywords) {
      if (normalizedText.includes(keyword.toLowerCase())) {
        // Lower score if already matched in language-specific
        const weightMultiplier = (language && languageSpecificKeywords[language]?.includes(keyword)) ? 0.5 : 1.0;
        score += 2.0 * weightMultiplier;
      }
    }
    
    return score;
  }

  /**
   * Check layout complexity (simple = receipt, complex = invoice)
   */
  private static checkLayoutComplexity(textLines: TextLine[]): { receipt: number; invoice: number } {
    const lineCount = textLines.length;
    
    // Count table-like structures (multiple columns, aligned text)
    let tableLikeLines = 0;
    for (const line of textLines) {
      const text = line.text.trim();
      // Check for multiple spaces/tabs (potential table structure)
      if (/\s{3,}/.test(text) || text.includes('\t')) {
        tableLikeLines++;
      }
    }
    
    const tableRatio = lineCount > 0 ? tableLikeLines / lineCount : 0.0;
    
    // Simple layout (receipt): fewer lines, less table structure
    const receiptScore = lineCount < 30 && tableRatio < 0.3 ? 1.0 : 
                        lineCount < 40 && tableRatio < 0.4 ? 0.5 : 0.0;
    
    // Complex layout (invoice): more lines, more table structure
    const invoiceScore = lineCount > 40 && tableRatio > 0.4 ? 1.0 :
                        lineCount > 30 && tableRatio > 0.3 ? 0.5 : 0.0;
    
    return { receipt: receiptScore, invoice: invoiceScore };
  }

  /**
   * Check information detail level
   */
  private static checkInformationDetail(textLines: TextLine[], normalizedText: string): { receipt: number; invoice: number } {
    // Check for detailed item information (quantity, unit price, tax breakdown)
    const itemTableHeaders = [
      'qty', 'quantity', 'description', 'item', 'product', 'unit price', 'unit', 'price', 'amount', 'vat', 'tax',
      'määrä', 'kappalemäärä', 'kuvaus', 'tuote', 'yksikköhinta', 'hinta', 'summa', 'alv', 'arvonlisävero',
      'kvantitet', 'antal', 'beskrivning', 'produkt', 'enhetspris', 'pris', 'belopp', 'moms', 'mervärdesskatt',
      'quantité', 'description', 'article', 'produit', 'prix unitaire', 'prix', 'montant', 'tva', 'taxe',
      'menge', 'anzahl', 'beschreibung', 'artikel', 'produkt', 'einzelpreis', 'preis', 'betrag', 'mwst', 
      'umsatzsteuer', 'steuer'
    ];
    
    let detailedItemIndicators = 0;
    for (const line of textLines) {
      const lineText = line.text.toLowerCase();
      for (const header of itemTableHeaders) {
        if (lineText.includes(header)) {
          detailedItemIndicators++;
          break;
        }
      }
    }
    
    const detailRatio = textLines.length > 0 ? detailedItemIndicators / textLines.length : 0.0;
    
    // Check for customer/billing information patterns
    const customerInfoPatterns = [
      'customer', 'client', 'bill to', 'ship to', 'address', 'phone', 'email',
      'asiakas', 'laskutettava', 'toimitusosoite', 'osoite', 'puhelin', 'sähköposti',
      'kund', 'fakturera', 'leverans', 'adress', 'telefon', 'e-post',
      'client', 'facturer', 'livrer', 'adresse', 'téléphone', 'email',
      'kunde', 'rechnung', 'lieferung', 'adresse', 'telefon', 'e-mail'
    ];
    
    let customerInfoCount = 0;
    for (const pattern of customerInfoPatterns) {
      if (normalizedText.includes(pattern)) {
        customerInfoCount++;
      }
    }
    
    // Simple information (receipt): few detailed headers, no customer info
    const receiptScore = detailRatio < 0.1 && customerInfoCount < 2 ? 1.0 :
                        detailRatio < 0.15 && customerInfoCount < 3 ? 0.5 : 0.0;
    
    // Complex information (invoice): many detailed headers, customer info present
    const invoiceScore = detailRatio > 0.15 && customerInfoCount > 3 ? 1.0 :
                        detailRatio > 0.1 && customerInfoCount > 2 ? 0.5 : 0.0;
    
    return { receipt: receiptScore, invoice: invoiceScore };
  }

  /**
   * Check date types (invoices often have multiple dates)
   */
  private static checkDateTypes(normalizedText: string): { receipt: number; invoice: number } {
    const dateKeywords = [
      'due date', 'invoice date', 'ship date', 'delivery date', 'payment due',
      'eräpäivä', 'laskupäivä', 'toimituspäivä',
      'förfallodatum', 'fakturadatum', 'leveransdatum',
      'date échéance', 'date facture', 'date livraison',
      'fälligkeitsdatum', 'rechnungsdatum', 'lieferdatum',
      'data scadenza', 'data fattura', 'data consegna'
    ];
    
    let dateTypeCount = 0;
    for (const keyword of dateKeywords) {
      if (normalizedText.includes(keyword)) {
        dateTypeCount++;
      }
    }
    
    // Receipts typically have just one date
    const receiptScore = dateTypeCount <= 1 ? 0.5 : 0.0;
    
    // Invoices often have multiple date types
    const invoiceScore = dateTypeCount >= 2 ? 1.0 : dateTypeCount === 1 ? 0.3 : 0.0;
    
    return { receipt: receiptScore, invoice: invoiceScore };
  }
}