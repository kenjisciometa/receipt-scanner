// Advanced Receipt Extraction Service (Based on Flutter Implementation)
import { TextLine, OCRResult, OCRElement } from '@/types/ocr';
import { ExtractionResult, ReceiptItem, TaxBreakdown } from '@/types/extraction';
import { DocumentTypeClassifier } from './document-classifier';

interface AmountCandidate {
  amount: number;
  label?: string;
  confidence?: number;
  boundingBox?: number[];
  fieldName: string; // 'total_amount', 'subtotal_amount', 'tax_amount'
}

interface ConsistencyResult {
  selectedCandidates: Record<string, AmountCandidate>;
  correctedValues?: Record<string, number>;
  itemsSum?: number;
  itemsCount?: number;
  itemsSumMatchesSubtotal?: boolean;
  itemsSumMatchesTotal?: boolean;
}

interface TableExtractionResult {
  amounts: Record<string, number>;
  taxBreakdowns?: Array<Record<string, number>>;
}

export class AdvancedReceiptExtractionService {
  private readonly languageKeywords = {
    total: {
      en: ['total', 'sum', 'amount', 'grand total', 'amount due'],
      fi: ['yhteensä', 'summa', 'loppusumma', 'maksettava', 'maksu'],
      sv: ['totalt', 'summa', 'att betala', 'slutsumma'],
      fr: ['total', 'montant total', 'somme', 'à payer', 'net à payer', 'total ttc'],
      de: ['summe', 'gesamt', 'betrag', 'gesamtbetrag', 'endsumme', 'zu zahlen'],
      it: ['totale', 'importo', 'somma', 'da pagare', 'totale generale', 'saldo'],
      es: ['total', 'importe', 'suma', 'a pagar', 'total general', 'precio total'],
    },
    subtotal: {
      en: ['subtotal', 'sub-total', 'net'],
      fi: ['välisumma', 'alasumma'],
      sv: ['delsumma', 'mellansumma'],
      fr: ['sous-total', 'montant ht'],
      de: ['zwischensumme', 'netto', 'nettosumme'],
      it: ['subtotale', 'imponibile'],
      es: ['subtotal', 'base imponible'],
    },
    tax: {
      en: ['vat', 'tax', 'sales tax'],
      fi: ['alv', 'arvonlisävero', 'vero', 'verot'], // Added plural form
      sv: ['moms', 'mervärdesskatt'],
      fr: ['tva', 'taxe'],
      de: ['mwst', 'umsatzsteuer', 'steuer'],
      it: ['iva', 'imposta'],
      es: ['iva', 'impuesto'],
    },
    payment: {
      en: ['payment'],
      fi: ['maksutapa'],
      sv: ['betalning'],
      fr: ['paiement'],
      de: ['zahlung'],
      it: ['pagamento'],
      es: ['pago'],
    },
    paymentMethodCash: {
      en: ['cash'],
      fi: ['käteinen'],
      sv: ['kontanter'],
      fr: ['espèces'],
      de: ['bar'],
      it: ['contanti'],
      es: ['efectivo'],
    },
    paymentMethodCard: {
      en: ['card'],
      fi: ['kortti'],
      sv: ['kort'],
      fr: ['carte'],
      de: ['karte'],
      it: ['carta'],
      es: ['tarjeta'],
    },
    receipt: {
      en: ['receipt'],
      fi: ['kuitti'],
      sv: ['kvitto'],
      fr: ['reçu'],
      de: ['rechnung', 'bon', 'quittung'],
      it: ['ricevuta'],
      es: ['recibo'],
    },
    invoice: {
      en: ['invoice', 'bill'],
      fi: ['lasku', 'faktuura'],
      sv: ['faktura', 'räkning'],
      fr: ['facture'],
      de: ['rechnung', 'faktura'],
      it: ['fattura'],
      es: ['factura'],
    },
    invoiceSpecific: {
      en: ['bill to', 'ship to', 'due date', 'payment terms', 'invoice number', 'invoice #', 'net 30', 'net 60', 'payment due', 'terms', 'billing address'],
      fi: ['laskutettava', 'toimitusosoite', 'eräpäivä', 'maksuehto', 'laskun numero', 'lasku nro', 'maksuaika', 'laskutusosoite'],
      sv: ['fakturera till', 'leveransadress', 'förfallodatum', 'betalningsvillkor', 'fakturanummer', 'faktura nr', 'betalningsvillkor'],
      fr: ['facturer à', 'livrer à', 'date d\'échéance', 'conditions de paiement', 'numéro de facture', 'facture n°', 'net 30', 'net 60'],
      de: ['rechnungsempfänger', 'lieferadresse', 'fälligkeitsdatum', 'zahlungsbedingungen', 'rechnungsnummer', 'rechnung nr', 'zahlungsziel'],
      it: ['fatturare a', 'spedire a', 'data di scadenza', 'termini di pagamento', 'numero fattura', 'fattura n°', 'netto 30'],
      es: ['facturar a', 'enviar a', 'fecha de vencimiento', 'términos de pago', 'número de factura', 'factura nº', 'neto 30'],
    },
    receiptSpecific: {
      en: ['thank you', 'thank you for your purchase', 'visitor copy', 'customer copy', 'paid', 'payment received'],
      fi: ['kiitos', 'kiitos ostoksestasi', 'asiakasnäyte', 'maksettu', 'maksu vastaanotettu'],
      sv: ['tack', 'tack för ditt köp', 'kundkopia', 'betalad', 'betalning mottagen'],
      fr: ['merci', 'merci pour votre achat', 'copie client', 'payé', 'paiement reçu'],
      de: ['danke', 'vielen dank für ihren einkauf', 'kundenbeleg', 'bezahlt', 'zahlung erhalten'],
      it: ['grazie', 'grazie per il tuo acquisto', 'copia cliente', 'pagato', 'pagamento ricevuto'],
      es: ['gracias', 'gracias por su compra', 'copia del cliente', 'pagado', 'pago recibido'],
    },
    itemTableHeader: {
      en: ['qty', 'quantity', 'description', 'item', 'product', 'unit price', 'unit', 'price', 'amount', 'vat', 'tax', 'sales tax'],
      fi: ['määrä', 'kappalemäärä', 'kuvaus', 'tuote', 'yksikköhinta', 'hinta', 'summa', 'alv', 'arvonlisävero'],
      sv: ['kvantitet', 'antal', 'beskrivning', 'produkt', 'enhetspris', 'pris', 'belopp', 'moms', 'mervärdesskatt'],
      fr: ['quantité', 'description', 'article', 'produit', 'prix unitaire', 'prix', 'montant', 'tva', 'taxe'],
      de: ['menge', 'anzahl', 'beschreibung', 'artikel', 'produkt', 'einzelpreis', 'preis', 'betrag', 'mwst', 'umsatzsteuer', 'steuer'],
      it: ['quantità', 'descrizione', 'articolo', 'prodotto', 'prezzo unitario', 'prezzo', 'importo', 'iva', 'imposta'],
      es: ['cantidad', 'descripción', 'artículo', 'producto', 'precio unitario', 'precio', 'importe', 'iva', 'impuesto'],
    }
  };

  private readonly amountCapturePattern = /([€\$£¥₹kr]?\s*[\d\s]+[.,]\d{1,2})/g;
  private readonly percentPattern = /(\d+(?:[.,]\d+)?)\s*%/;

  async extract(ocrResult: OCRResult, languageHint?: string): Promise<ExtractionResult> {
    const language = languageHint || ocrResult.detected_language || 'en';
    const textLines = ocrResult.textLines;
    const fullText = ocrResult.text;
    
    console.log(`🔍 Starting advanced extraction for language: ${language}`);
    
    // Document type classification
    const documentTypeResult = DocumentTypeClassifier.classify(textLines, language);
    
    // Extract basic fields
    const extractedData: Record<string, any> = {};
    const warnings: string[] = [];
    const appliedPatterns: string[] = [];
    
    // Merchant name
    const merchantName = this.extractMerchantName(textLines);
    if (merchantName) {
      extractedData.merchant_name = merchantName;
    } else {
      warnings.push('Merchant name not found');
    }
    
    // Date
    const date = this.extractDate(fullText);
    if (date) {
      extractedData.date = date;
    } else {
      warnings.push('Date not found');
    }
    
    // Currency
    const currency = this.extractCurrency(fullText);
    if (currency) {
      extractedData.currency = currency;
    }
    
    // Advanced Amount Extraction (Flutter-based logic)
    const amountResult = this.extractAmountsAdvanced(textLines, language, appliedPatterns);
    Object.assign(extractedData, amountResult);
    
    // Payment method
    const paymentMethod = this.extractPaymentMethod(fullText);
    if (paymentMethod) {
      extractedData.payment_method = paymentMethod;
    }
    
    // Receipt number
    const receiptNumber = this.extractReceiptNumber(fullText);
    if (receiptNumber) {
      extractedData.receipt_number = receiptNumber;
    }
    
    // Items (if detected)
    const items = this.extractItems(textLines);
    
    // Calculate confidence
    const confidence = this.calculateExtractionConfidence(extractedData, ocrResult.confidence, warnings.length);
    
    console.log(`✅ Advanced extraction completed. Confidence: ${confidence.toFixed(2)}`);
    console.log(`📋 Applied patterns: ${appliedPatterns.join(', ')}`);
    
    return {
      merchant_name: extractedData.merchant_name || null,
      date: extractedData.date || null,
      currency: extractedData.currency || null,
      subtotal: extractedData.subtotal_amount || null,
      tax_breakdown: extractedData.tax_breakdown || [],
      tax_total: extractedData.tax_amount || null,
      total: extractedData.total_amount || null,
      receipt_number: extractedData.receipt_number || null,
      payment_method: extractedData.payment_method || null,
      confidence,
      status: confidence >= 0.7 ? 'completed' : 'needs_verification',
      needs_verification: confidence < 0.7,
      extracted_items: items,
      document_type: documentTypeResult.documentType,
      document_type_confidence: documentTypeResult.confidence,
      document_type_reason: documentTypeResult.reason,
    };
  }

  // ========== ADVANCED AMOUNT EXTRACTION ==========
  
  private extractAmountsAdvanced(textLines: TextLine[], language: string, appliedPatterns: string[]): Record<string, any> {
    console.log(`💰 Starting advanced amount extraction for ${textLines.length} lines`);
    
    // Try table extraction first (more accurate)
    const tableResult = this.extractAmountsFromTable(textLines, appliedPatterns);
    if (tableResult && Object.keys(tableResult.amounts).length > 0) {
      console.log(`📊 Table extraction successful: ${JSON.stringify(tableResult.amounts)}`);
      const result = { ...tableResult.amounts };
      if (tableResult.taxBreakdowns) {
        result.tax_breakdown = tableResult.taxBreakdowns;
      }
      return result;
    }
    
    // Try individual tax line extraction (for receipts like Finnish ALV lines)
    console.log(`📄 Trying individual tax line extraction`);
    const individualTaxResult = this.extractIndividualTaxLines(textLines, language, appliedPatterns);
    if (individualTaxResult && Object.keys(individualTaxResult).length > 0) {
      console.log(`💰 Individual tax extraction successful: ${JSON.stringify(individualTaxResult)}`);
      return individualTaxResult;
    }

    // Fallback to line-by-line extraction
    console.log(`📄 Falling back to line-by-line extraction`);
    return this.extractAmountsLineByLine(textLines, language, appliedPatterns);
  }

  private extractAmountsFromTable(textLines: TextLine[], appliedPatterns: string[]): TableExtractionResult | null {
    console.log(`📊 Attempting table extraction from ${textLines.length} lines`);
    
    // Find potential table header and data rows
    let headerLine: TextLine | null = null;
    const dataRows: TextLine[] = [];
    
    for (const line of textLines) {
      if (this.isSummaryTableHeader(line.text)) {
        headerLine = line;
        console.log(`📋 Found table header: "${line.text}"`);
      } else if (this.isSummaryTableDataRow(line.text)) {
        dataRows.push(line);
        console.log(`📊 Found table data row: "${line.text}"`);
      }
    }
    
    if (headerLine && dataRows.length > 0) {
      return this.processTableData(headerLine, dataRows, appliedPatterns);
    }
    
    console.log(`📊 No table structure found`);
    return null;
  }

  private isSummaryTableHeader(headerText: string): boolean {
    const lower = headerText.toLowerCase();
    const totalKeywords = this.getAllKeywords('total');
    const subtotalKeywords = this.getAllKeywords('subtotal');
    const taxKeywords = this.getAllKeywords('tax');
    
    let hasTotal = false;
    let hasSubtotal = false;
    let hasTax = false;
    
    console.log(`🔍 Checking header: "${headerText}"`);
    
    // Use word boundary matching
    for (const keyword of totalKeywords) {
      const pattern = new RegExp(`\\b${this.escapeRegex(keyword.toLowerCase())}\\b`);
      if (pattern.test(lower)) {
        hasTotal = true;
        console.log(`✅ Found total keyword: ${keyword}`);
        break;
      }
    }
    for (const keyword of subtotalKeywords) {
      const pattern = new RegExp(`\\b${this.escapeRegex(keyword.toLowerCase())}\\b`);
      if (pattern.test(lower)) {
        hasSubtotal = true;
        console.log(`✅ Found subtotal keyword: ${keyword}`);
        break;
      }
    }
    for (const keyword of taxKeywords) {
      const pattern = new RegExp(`\\b${this.escapeRegex(keyword.toLowerCase())}\\b`);
      if (pattern.test(lower)) {
        hasTax = true;
        console.log(`✅ Found tax keyword: ${keyword}`);
        break;
      }
    }
    
    const keywordCount = [hasTotal, hasSubtotal, hasTax].filter(Boolean).length;
    const hasRateKeyword = /\brate\b/.test(lower); // Fixed regex escaping
    
    console.log(`📊 Header analysis: total=${hasTotal}, subtotal=${hasSubtotal}, tax=${hasTax}, rate=${hasRateKeyword}, count=${keywordCount}`);
    
    const isValid = keywordCount >= 2 || (keywordCount >= 1 && hasRateKeyword);
    console.log(`📊 Is valid header: ${isValid}`);
    
    return isValid;
  }

  private isSummaryTableDataRow(rowText: string): boolean {
    const amountMatches = rowText.match(this.amountCapturePattern);
    const amountCount = amountMatches ? amountMatches.length : 0;
    
    console.log(`🔍 Checking data row: "${rowText}"`);
    console.log(`💰 Found ${amountCount} amounts: ${amountMatches?.join(', ') || 'none'}`);
    
    // Data row criteria: 3+ amounts (Tax rate, Tax, Subtotal, Total)
    if (amountCount >= 3) {
      // Additional validation for summary table content
      const totalKeywords = this.getAllKeywords('total');
      const subtotalKeywords = this.getAllKeywords('subtotal');
      const taxKeywords = this.getAllKeywords('tax');
      const itemTableKeywords = this.getAllKeywords('itemTableHeader');
      
      const summaryKeywords = [...totalKeywords, ...subtotalKeywords, ...taxKeywords];
      const lower = rowText.toLowerCase();
      
      // Check if contains summary keywords (not item table keywords)
      const hasSummaryKeyword = summaryKeywords.some(keyword => 
        new RegExp(`\\b${this.escapeRegex(keyword.toLowerCase())}\\b`).test(lower)
      );
      const hasItemKeyword = itemTableKeywords.some(keyword => 
        new RegExp(`\\b${this.escapeRegex(keyword.toLowerCase())}\\b`).test(lower)
      );
      
      // Special case: if row has percentage and multiple amounts, it's likely a summary
      const hasPercentage = this.percentPattern.test(rowText);
      
      console.log(`📊 Data row validation: summaryKeyword=${hasSummaryKeyword}, itemKeyword=${hasItemKeyword}, hasPercentage=${hasPercentage}`);
      
      const isValid = (hasSummaryKeyword && !hasItemKeyword) || hasPercentage;
      console.log(`📊 Is valid data row: ${isValid}`);
      
      return isValid;
    }
    
    console.log(`📊 Insufficient amounts for data row`);
    return false;
  }

  private processTableData(headerLine: TextLine, dataRows: TextLine[], appliedPatterns: string[]): TableExtractionResult {
    console.log(`📊 Processing ${dataRows.length} data row(s) from table`);
    
    const amounts: Record<string, number> = {};
    let totalTax = 0.0;
    let totalSubtotal = 0.0;
    let finalTotal: number | null = null;
    const taxBreakdowns: Array<Record<string, number>> = [];
    
    for (let rowIndex = 0; rowIndex < dataRows.length; rowIndex++) {
      const dataRow = dataRows[rowIndex];
      
      // Extract using bounding box if available
      const extracted = headerLine.elements && dataRow.elements ? 
        this.extractTableValuesFromBoundingBox(headerLine, dataRow, appliedPatterns) :
        this.extractTableValuesFromText(headerLine.text, dataRow.text, appliedPatterns);
      
      if (extracted.amounts) {
        const rowAmounts = extracted.amounts;
        
        // Accumulate values
        if (rowAmounts.tax_amount) {
          totalTax += rowAmounts.tax_amount;
        }
        if (rowAmounts.subtotal_amount) {
          totalSubtotal += rowAmounts.subtotal_amount;
        }
        if (rowAmounts.total_amount && finalTotal === null && dataRows.length === 1) {
          finalTotal = rowAmounts.total_amount;
        }
        
        console.log(`📊 Row ${rowIndex + 1}: tax=${rowAmounts.tax_amount || 0}, subtotal=${rowAmounts.subtotal_amount || 0}, total=${rowAmounts.total_amount || 0}`);
      }
      
      // Extract tax breakdown
      if (extracted.tax_breakdown) {
        taxBreakdowns.push(extracted.tax_breakdown);
        console.log(`📊 Row ${rowIndex + 1} tax breakdown: ${extracted.tax_breakdown.rate}% = ${extracted.tax_breakdown.amount}`);
      }
    }
    
    // Set accumulated values
    if (totalTax > 0) {
      amounts.tax_amount = Math.round(totalTax * 100) / 100;
    }
    if (totalSubtotal > 0) {
      amounts.subtotal_amount = Math.round(totalSubtotal * 100) / 100;
    }
    
    // Calculate final total
    if (totalSubtotal > 0 && totalTax > 0) {
      amounts.total_amount = Math.round((totalSubtotal + totalTax) * 100) / 100;
      console.log(`📊 Calculated final total: ${amounts.subtotal_amount} + ${amounts.tax_amount} = ${amounts.total_amount}`);
    } else if (finalTotal !== null && dataRows.length === 1) {
      amounts.total_amount = finalTotal;
    }
    
    if (Object.keys(amounts).length > 0) {
      appliedPatterns.push('table_extraction_success');
    }
    
    return {
      amounts,
      taxBreakdowns: taxBreakdowns.length > 0 ? taxBreakdowns : undefined
    };
  }

  private extractTableValuesFromBoundingBox(
    headerLine: TextLine, 
    dataLine: TextLine, 
    appliedPatterns: string[]
  ): { amounts?: Record<string, number>; tax_breakdown?: Record<string, number> } {
    const result: { amounts?: Record<string, number>; tax_breakdown?: Record<string, number> } = {};
    
    if (!headerLine.elements || !dataLine.elements) {
      return result;
    }
    
    // Sort elements by x position
    const headerElements = [...headerLine.elements].sort((a, b) => (a.boundingBox?.[0] || 0) - (b.boundingBox?.[0] || 0));
    const dataElements = [...dataLine.elements].sort((a, b) => (a.boundingBox?.[0] || 0) - (b.boundingBox?.[0] || 0));
    
    // Map column types based on header
    const columnTypes: Record<number, string> = {};
    const totalKeywords = this.getAllKeywords('total');
    const subtotalKeywords = this.getAllKeywords('subtotal');
    const taxKeywords = this.getAllKeywords('tax');
    
    for (let i = 0; i < headerElements.length; i++) {
      const headerText = headerElements[i].text.toLowerCase();
      if (headerText.includes('rate') || headerText.includes('%')) {
        columnTypes[i] = 'tax_rate';
      } else if (taxKeywords.some(k => headerText.includes(k.toLowerCase()))) {
        columnTypes[i] = 'tax';
      } else if (subtotalKeywords.some(k => headerText.includes(k.toLowerCase()))) {
        columnTypes[i] = 'subtotal';
      } else if (totalKeywords.some(k => headerText.includes(k.toLowerCase()))) {
        columnTypes[i] = 'total';
      }
    }
    
    // Match data elements to columns
    const matchedValues: Record<number, OCRElement> = {};
    for (const dataElement of dataElements) {
      const dataX = dataElement.boundingBox?.[0] || 0;
      let bestMatch = -1;
      let minDistance = Infinity;
      
      for (let i = 0; i < headerElements.length; i++) {
        const headerX = headerElements[i].boundingBox?.[0] || 0;
        const distance = Math.abs(dataX - headerX);
        if (distance < minDistance) {
          minDistance = distance;
          bestMatch = i;
        }
      }
      
      if (bestMatch !== -1 && minDistance < 100) { // tolerance
        matchedValues[bestMatch] = dataElement;
      }
    }
    
    // Extract values
    const amounts: Record<string, number> = {};
    let taxRate: number | null = null;
    
    for (const [columnIndex, value] of Object.entries(matchedValues)) {
      const colIndex = parseInt(columnIndex);
      const columnType = columnTypes[colIndex];
      
      if (columnType === 'tax_rate' || value.text.includes('%')) {
        const percentMatch = this.percentPattern.exec(value.text);
        if (percentMatch) {
          const percentStr = percentMatch[1].replace(',', '.');
          taxRate = parseFloat(percentStr);
          appliedPatterns.push(`table_tax_rate_${taxRate.toFixed(0)}%`);
        }
        continue;
      }
      
      const amount = this.parseAmount(value.text);
      if (!amount || amount <= 0) continue;
      
      if (columnType === 'tax') {
        amounts.tax_amount = amount;
        console.log(`📊 Assigned tax amount: ${amount} (from column ${colIndex})`);
      } else if (columnType === 'subtotal') {
        amounts.subtotal_amount = amount;
        console.log(`📊 Assigned subtotal amount: ${amount} (from column ${colIndex})`);
      } else if (columnType === 'total') {
        amounts.total_amount = amount;
        console.log(`📊 Assigned total amount: ${amount} (from column ${colIndex})`);
      }
    }
    
    result.amounts = amounts;
    
    // Create tax breakdown if we have both rate and amount
    if (taxRate !== null && amounts.tax_amount) {
      result.tax_breakdown = {
        rate: taxRate,
        amount: amounts.tax_amount
      };
      console.log(`📊 Tax breakdown: ${taxRate}% = ${amounts.tax_amount}`);
    }
    
    return result;
  }

  private extractTableValuesFromText(
    headerText: string, 
    dataText: string, 
    appliedPatterns: string[]
  ): { amounts?: Record<string, number>; tax_breakdown?: Record<string, number> } {
    const result: { amounts?: Record<string, number>; tax_breakdown?: Record<string, number> } = {};
    
    // Extract amounts from data row
    const amountMatches = Array.from(dataText.matchAll(this.amountCapturePattern));
    const amounts: Record<string, number> = {};
    
    if (amountMatches.length >= 3) {
      // Typical order: [Tax Rate %] [Tax Amount] [Subtotal] [Total]
      const values = amountMatches.map(match => this.parseAmount(match[0])).filter(Boolean);
      
      if (values.length >= 3) {
        // Extract tax rate
        const percentMatch = this.percentPattern.exec(dataText);
        let taxRate: number | null = null;
        if (percentMatch) {
          taxRate = parseFloat(percentMatch[1].replace(',', '.'));
          appliedPatterns.push(`table_tax_rate_${taxRate.toFixed(0)}%`);
        }
        
        // Assign amounts (skip first if it's tax rate percentage)
        let valueIndex = 0;
        
        // If first value matches tax rate, skip it
        if (taxRate && values[0] && Math.abs(values[0] - taxRate) < 0.1) {
          valueIndex = 1;
        }
        
        if (values[valueIndex]) amounts.tax_amount = values[valueIndex];
        if (values[valueIndex + 1]) amounts.subtotal_amount = values[valueIndex + 1];
        if (values[valueIndex + 2]) amounts.total_amount = values[valueIndex + 2];
        
        // Create tax breakdown
        if (taxRate !== null && amounts.tax_amount) {
          result.tax_breakdown = {
            rate: taxRate,
            amount: amounts.tax_amount
          };
        }
        
        console.log(`📊 Text-based extraction: tax=${amounts.tax_amount}, subtotal=${amounts.subtotal_amount}, total=${amounts.total_amount}`);
      }
    }
    
    result.amounts = amounts;
    return result;
  }

  // ========== INDIVIDUAL TAX LINE EXTRACTION ==========
  
  private extractIndividualTaxLines(textLines: TextLine[], language: string, appliedPatterns: string[]): Record<string, any> {
    console.log(`🏷️ Extracting individual tax lines for language: ${language}`);
    
    const amounts: Record<string, any> = {};
    const taxBreakdowns: Array<Record<string, number>> = [];
    let totalTax = 0;
    let totalAmount = 0;
    let itemsTotal = 0;
    
    const taxKeywords = this.getKeywords('tax', language);
    const totalKeywords = this.getKeywords('total', language);
    
    // Process each line
    for (const line of textLines) {
      const text = line.text.toLowerCase();
      const lineAmounts = this.extractAmountsFromText(line.text);
      
      // Check for tax lines (ALV 14%, VAT 20%, etc.)
      const hasAnyTaxKeyword = taxKeywords.some(keyword => text.includes(keyword.toLowerCase()));
      const hasPercentage = this.percentPattern.test(line.text);
      
      if (hasAnyTaxKeyword && hasPercentage && lineAmounts.length > 0) {
        const percentMatch = this.percentPattern.exec(line.text);
        if (percentMatch) {
          const rate = parseFloat(percentMatch[1].replace(',', '.'));
          const taxAmount = lineAmounts[lineAmounts.length - 1]; // Last amount is usually tax
          
          console.log(`🏷️ Found tax line: ${line.text} -> ${rate}% = €${taxAmount}`);
          
          taxBreakdowns.push({
            rate: rate,
            amount: taxAmount
          });
          
          totalTax += taxAmount;
          appliedPatterns.push(`individual_tax_${rate}%`);
        }
      }
      
      // Check for total lines
      const hasAnyTotalKeyword = totalKeywords.some(keyword => text.includes(keyword.toLowerCase()));
      if (hasAnyTotalKeyword && lineAmounts.length > 0) {
        totalAmount = lineAmounts[lineAmounts.length - 1]; // Last amount is total
        console.log(`💰 Found total line: ${line.text} -> €${totalAmount}`);
        appliedPatterns.push(`individual_total_${language}`);
      }
      
      // Check for item lines (no tax/total keywords, has amount)
      const isItemLine = !hasAnyTaxKeyword && !hasAnyTotalKeyword && lineAmounts.length > 0;
      if (isItemLine) {
        // Skip lines that look like addresses, dates, or merchant info
        const looksLikeItem = !this.looksLikeDate(line.text) && 
                             !this.looksLikeAddress(line.text) &&
                             line.text.length > 5;
        
        if (looksLikeItem) {
          const itemPrice = lineAmounts[lineAmounts.length - 1];
          itemsTotal += itemPrice;
          console.log(`🛒 Found item line: ${line.text} -> €${itemPrice} (running total: €${itemsTotal})`);
        }
      }
    }
    
    // Set the extracted amounts
    if (totalTax > 0) {
      amounts.tax_amount = Math.round(totalTax * 100) / 100;
      console.log(`🏷️ Total tax: €${amounts.tax_amount}`);
    }
    
    if (totalAmount > 0) {
      amounts.total_amount = totalAmount;
      console.log(`💰 Total amount: €${amounts.total_amount}`);
    }
    
    // Calculate subtotal from items or derive from total - tax
    if (itemsTotal > 0) {
      amounts.subtotal_amount = Math.round(itemsTotal * 100) / 100;
      console.log(`🛒 Subtotal from items: €${amounts.subtotal_amount}`);
    } else if (totalAmount > 0 && totalTax > 0) {
      amounts.subtotal_amount = Math.round((totalAmount - totalTax) * 100) / 100;
      console.log(`🧮 Calculated subtotal: €${amounts.total_amount} - €${amounts.tax_amount} = €${amounts.subtotal_amount}`);
    }
    
    // Add tax breakdown if we found individual tax lines
    if (taxBreakdowns.length > 0) {
      amounts.tax_breakdown = taxBreakdowns;
      console.log(`🏷️ Tax breakdown: ${JSON.stringify(taxBreakdowns)}`);
    }
    
    // Validate consistency
    if (amounts.subtotal_amount && amounts.tax_amount && amounts.total_amount) {
      const expectedTotal = amounts.subtotal_amount + amounts.tax_amount;
      const difference = Math.abs(expectedTotal - amounts.total_amount);
      
      if (difference > 0.02) {
        console.log(`⚠️ Inconsistency detected: subtotal(${amounts.subtotal_amount}) + tax(${amounts.tax_amount}) = ${expectedTotal.toFixed(2)}, but total is ${amounts.total_amount}`);
        // Keep the values but add warning
        appliedPatterns.push('inconsistent_amounts');
      } else {
        console.log(`✅ Amounts are consistent: ${amounts.subtotal_amount} + ${amounts.tax_amount} = ${amounts.total_amount}`);
        appliedPatterns.push('consistent_amounts');
      }
    }
    
    return amounts;
  }

  private extractAmountsLineByLine(textLines: TextLine[], language: string, appliedPatterns: string[]): Record<string, any> {
    const amounts: Record<string, any> = {};
    const candidates: AmountCandidate[] = [];
    
    // Collect all amount candidates with their types and scores
    textLines.forEach((line, index) => {
      const text = line.text.toLowerCase();
      const amountsInLine = this.extractAmountsFromText(line.text);
      
      amountsInLine.forEach(amount => {
        let fieldName = 'other';
        let score = 0;
        let label = '';
        
        // Check for total keywords
        const totalKeywords = this.getKeywords('total', language);
        if (totalKeywords.some(keyword => text.includes(keyword.toLowerCase()))) {
          fieldName = 'total_amount';
          score = 10;
          label = 'total';
          appliedPatterns.push(`total_keyword_${language}`);
        }
        // Check for subtotal keywords
        else {
          const subtotalKeywords = this.getKeywords('subtotal', language);
          if (subtotalKeywords.some(keyword => text.includes(keyword.toLowerCase()))) {
            fieldName = 'subtotal_amount';
            score = 8;
            label = 'subtotal';
            appliedPatterns.push(`subtotal_keyword_${language}`);
          }
          // Check for tax keywords
          else {
            const taxKeywords = this.getKeywords('tax', language);
            if (taxKeywords.some(keyword => text.includes(keyword.toLowerCase()))) {
              fieldName = 'tax_amount';
              score = 6;
              label = 'tax';
              appliedPatterns.push(`tax_keyword_${language}`);
            }
            // Position-based scoring for total (usually at bottom)
            else if (index > textLines.length * 0.7) {
              fieldName = 'total_amount';
              score = 5;
              label = 'position_total';
              appliedPatterns.push('position_based_total');
            }
          }
        }
        
        candidates.push({
          amount,
          label,
          fieldName,
          confidence: score / 10.0,
          boundingBox: line.elements?.[0]?.boundingBox
        });
      });
    });
    
    // Select best candidates
    const consistencyResult = this.selectConsistentAmounts(candidates);
    
    for (const [fieldName, candidate] of Object.entries(consistencyResult.selectedCandidates)) {
      amounts[fieldName] = candidate.amount;
      console.log(`💰 Selected ${fieldName}: ${candidate.amount} (${candidate.label}, confidence: ${candidate.confidence?.toFixed(2)})`);
    }
    
    // Apply corrections if available
    if (consistencyResult.correctedValues) {
      Object.assign(amounts, consistencyResult.correctedValues);
      appliedPatterns.push('consistency_correction');
    }
    
    return amounts;
  }

  private selectConsistentAmounts(candidates: AmountCandidate[]): ConsistencyResult {
    const selectedCandidates: Record<string, AmountCandidate> = {};
    
    // Group candidates by field type
    const groupedCandidates = candidates.reduce((acc, candidate) => {
      if (!acc[candidate.fieldName]) acc[candidate.fieldName] = [];
      acc[candidate.fieldName].push(candidate);
      return acc;
    }, {} as Record<string, AmountCandidate[]>);
    
    // Select best candidate for each type
    for (const [fieldName, fieldCandidates] of Object.entries(groupedCandidates)) {
      // Sort by confidence descending
      fieldCandidates.sort((a, b) => (b.confidence || 0) - (a.confidence || 0));
      selectedCandidates[fieldName] = fieldCandidates[0];
    }
    
    // Basic consistency check: total should be >= subtotal + tax
    const total = selectedCandidates.total_amount?.amount;
    const subtotal = selectedCandidates.subtotal_amount?.amount;
    const tax = selectedCandidates.tax_amount?.amount;
    
    let correctedValues: Record<string, number> | undefined;
    
    if (total && subtotal && tax) {
      const expectedTotal = subtotal + tax;
      const difference = Math.abs(total - expectedTotal);
      
      if (difference > 0.02) { // More than 2 cents difference
        console.log(`⚠️ Consistency check failed: total=${total}, expected=${expectedTotal.toFixed(2)} (subtotal=${subtotal} + tax=${tax})`);
        
        // If the calculated total is more reasonable, use it
        correctedValues = {
          total_amount: Math.round(expectedTotal * 100) / 100
        };
      }
    }
    
    return {
      selectedCandidates,
      correctedValues
    };
  }

  // ========== HELPER METHODS ==========
  
  private getAllKeywords(category: string): string[] {
    const allKeywords: string[] = [];
    const categoryMap = this.languageKeywords[category as keyof typeof this.languageKeywords];
    if (categoryMap) {
      for (const langKeywords of Object.values(categoryMap)) {
        allKeywords.push(...langKeywords);
      }
    }
    return allKeywords;
  }

  private getKeywords(category: string, language: string): string[] {
    const categoryMap = this.languageKeywords[category as keyof typeof this.languageKeywords];
    return categoryMap?.[language as keyof typeof categoryMap] || [];
  }

  private extractAmountsFromText(text: string): number[] {
    const matches = text.match(this.amountCapturePattern) || [];
    return matches.map(match => {
      const normalized = match.replace(/[^\d.,]/g, '').replace(',', '.');
      const parsed = parseFloat(normalized);
      return isNaN(parsed) ? 0 : parsed;
    }).filter(num => num > 0);
  }

  private parseAmount(text: string): number | null {
    const normalized = text.replace(/[^\d.,]/g, '').replace(',', '.');
    const parsed = parseFloat(normalized);
    return isNaN(parsed) ? null : parsed;
  }

  private escapeRegex(string: string): string {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  // ========== EXISTING METHODS (PRESERVED) ==========
  
  private extractMerchantName(textLines: TextLine[]): string | null {
    const topLines = textLines.slice(0, 5);
    
    for (const line of topLines) {
      const text = line.text.trim();
      
      if (this.looksLikeAmount(text) || this.looksLikeDate(text) || this.looksLikeAddress(text)) {
        continue;
      }
      
      if (text.length < 3 || /^\d+$/.test(text)) {
        continue;
      }
      
      const skipWords = ['receipt', 'kuitti', 'kvitto', 'reçu', 'quittung', 'ricevuta', 'recibo'];
      if (skipWords.some(word => text.toLowerCase().includes(word))) {
        continue;
      }
      
      return text;
    }
    
    return null;
  }
  
  private extractDate(fullText: string): string | null {
    const datePatterns = [
      /(\d{1,2})[\.\/\-](\d{1,2})[\.\/\-](\d{4})/,
      /(\d{4})[\.\/\-](\d{1,2})[\.\/\-](\d{1,2})/,
      /(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+(\d{4})/i,
    ];
    
    for (const pattern of datePatterns) {
      const match = fullText.match(pattern);
      if (match) {
        try {
          const dateStr = match[0];
          const parsedDate = new Date(dateStr);
          if (!isNaN(parsedDate.getTime())) {
            return parsedDate.toISOString().split('T')[0];
          }
        } catch (error) {
          continue;
        }
      }
    }
    
    return null;
  }
  
  private extractCurrency(fullText: string): string | null {
    const currencyPatterns = [
      { pattern: /€|EUR|euro/i, code: 'EUR' },
      { pattern: /\$|USD|dollar/i, code: 'USD' },
      { pattern: /£|GBP|pound/i, code: 'GBP' },
      { pattern: /kr|SEK|krona/i, code: 'SEK' },
      { pattern: /NOK|krone/i, code: 'NOK' },
    ];
    
    for (const { pattern, code } of currencyPatterns) {
      if (pattern.test(fullText)) {
        return code;
      }
    }
    
    return null;
  }
  
  private extractPaymentMethod(fullText: string): string | null {
    const paymentPatterns = [
      { pattern: /cash|käteinen|kontant|espèces|bargeld|contanti|efectivo/i, method: 'cash' },
      { pattern: /card|kortti|kort|carte|karte|carta|tarjeta/i, method: 'card' },
      { pattern: /contactless|lähetin/i, method: 'contactless' },
      { pattern: /mobile|mobil/i, method: 'mobile' },
    ];
    
    for (const { pattern, method } of paymentPatterns) {
      if (pattern.test(fullText)) {
        return method;
      }
    }
    
    return null;
  }
  
  private extractReceiptNumber(fullText: string): string | null {
    const patterns = [
      /receipt\s*#?\s*:?\s*(\w+\d+)/i,
      /kuitti\s*#?\s*:?\s*(\w+\d+)/i,
      /ref\s*#?\s*:?\s*(\w+\d+)/i,
      /no\s*#?\s*:?\s*(\w+\d+)/i,
      /#(\w*\d+\w*)/,
    ];
    
    for (const pattern of patterns) {
      const match = fullText.match(pattern);
      if (match) {
        return match[1];
      }
    }
    
    return null;
  }
  
  private extractItems(textLines: TextLine[]): ReceiptItem[] {
    const items: ReceiptItem[] = [];
    
    for (const line of textLines) {
      const text = line.text.trim();
      
      if (this.isHeaderOrFooterLine(text)) continue;
      
      const itemPattern = /^(.+?)\s+(\d+[.,]\d{2})$/;
      const match = text.match(itemPattern);
      
      if (match) {
        const name = match[1].trim();
        const priceStr = match[2].replace(',', '.');
        const price = parseFloat(priceStr);
        
        if (!isNaN(price) && name.length > 2) {
          items.push({
            name,
            quantity: 1,
            total_price: price,
            unit_price: price,
            tax_rate: 0,
          });
        }
      }
    }
    
    return items;
  }
  
  private looksLikeAmount(text: string): boolean {
    return /\d+[.,]\d{2}/.test(text) && text.length < 20;
  }
  
  private looksLikeDate(text: string): boolean {
    return /\d{1,2}[\.\/\-]\d{1,2}[\.\/\-]\d{2,4}/.test(text);
  }
  
  private looksLikeAddress(text: string): boolean {
    return /\d+.*street|str\.|tie|gatan|rue|straße|via|calle/i.test(text);
  }
  
  private isHeaderOrFooterLine(text: string): boolean {
    const skipPatterns = [
      /thank you|kiitos|tack|merci|danke|grazie|gracias/i,
      /welcome|tervetuloa|välkommen|bienvenue|willkommen|benvenuti/i,
      /receipt|kuitti|kvitto|reçu|quittung|ricevuta|recibo/i,
    ];
    
    return skipPatterns.some(pattern => pattern.test(text));
  }
  
  private calculateExtractionConfidence(
    extractedData: Record<string, any>, 
    ocrConfidence: number, 
    warningCount: number
  ): number {
    let confidence = ocrConfidence;
    
    // Required field penalties
    if (!extractedData.total_amount) confidence *= 0.5;
    if (!extractedData.merchant_name) confidence *= 0.8;
    if (!extractedData.date) confidence *= 0.9;
    
    // Bonus for having consistent amounts
    if (extractedData.total_amount && extractedData.subtotal_amount && extractedData.tax_amount) {
      const expected = extractedData.subtotal_amount + extractedData.tax_amount;
      const actual = extractedData.total_amount;
      if (Math.abs(expected - actual) < 0.02) {
        confidence *= 1.1; // 10% bonus for consistency
      }
    }
    
    // Warning penalties
    confidence *= Math.max(0.3, 1.0 - (warningCount * 0.1));
    
    return Math.max(0.0, Math.min(1.0, confidence));
  }
}