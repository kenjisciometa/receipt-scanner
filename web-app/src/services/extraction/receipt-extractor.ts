// Receipt Extraction Service (Flutter port)
import { TextLine, OCRResult } from '@/types/ocr';
import { ExtractionResult, ReceiptItem, TaxBreakdown } from '@/types/extraction';
import { DocumentTypeClassifier } from './document-classifier';

export class ReceiptExtractionService {
  
  async extract(ocrResult: OCRResult, languageHint?: string): Promise<ExtractionResult> {
    const language = languageHint || ocrResult.detected_language || 'en';
    const textLines = ocrResult.textLines;
    const fullText = ocrResult.text;
    
    // Document type classification
    const documentTypeResult = DocumentTypeClassifier.classify(textLines, language);
    
    // Extract basic fields
    const extractedData: Record<string, any> = {};
    const warnings: string[] = [];
    
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
    
    // Time
    const time = this.extractTime(fullText);
    if (time) {
      extractedData.time = time;
    }
    
    // Currency
    const currency = this.extractCurrency(fullText);
    if (currency) {
      extractedData.currency = currency;
    }
    
    // Amounts (total, subtotal, tax)
    const amounts = this.extractAmounts(textLines, language);
    Object.assign(extractedData, amounts);
    
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
    
    return {
      merchant_name: extractedData.merchant_name || null,
      date: extractedData.date || null,
      time: extractedData.time || null,
      currency: extractedData.currency || null,
      subtotal: extractedData.subtotal || null,
      tax_breakdown: extractedData.tax_breakdown || [],
      tax_total: extractedData.tax_total || null,
      total: extractedData.total || null,
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
  
  private extractMerchantName(textLines: TextLine[]): string | null {
    // Usually the merchant name is in the first few lines
    const topLines = textLines.slice(0, 5);
    
    for (const line of topLines) {
      const text = line.text.trim();
      
      // Skip if line looks like an amount, date, or address
      if (this.looksLikeAmount(text) || this.looksLikeDate(text) || this.looksLikeAddress(text)) {
        continue;
      }
      
      // Skip very short lines or lines with only numbers
      if (text.length < 3 || /^\d+$/.test(text)) {
        continue;
      }
      
      // Skip common header words
      const skipWords = ['receipt', 'kuitti', 'kvitto', 'reçu', 'quittung', 'ricevuta', 'recibo'];
      if (skipWords.some(word => text.toLowerCase().includes(word))) {
        continue;
      }
      
      return text;
    }
    
    return null;
  }
  
  private extractDate(fullText: string): string | null {
    // Various date patterns
    const datePatterns = [
      /(\d{1,2})[\.\/\-](\d{1,2})[\.\/\-](\d{4})/,           // DD.MM.YYYY, DD/MM/YYYY, DD-MM-YYYY
      /(\d{4})[\.\/\-](\d{1,2})[\.\/\-](\d{1,2})/,          // YYYY.MM.DD, YYYY/MM/DD, YYYY-MM-DD
      /(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+(\d{4})/i, // DD MMM YYYY
    ];
    
    for (const pattern of datePatterns) {
      const match = fullText.match(pattern);
      if (match) {
        try {
          // Try to parse and convert to ISO format
          const dateStr = match[0];
          const parsedDate = new Date(dateStr);
          if (!isNaN(parsedDate.getTime())) {
            // Format as local date string (YYYY-MM-DD) without timezone conversion
            const year = parsedDate.getFullYear();
            const month = String(parsedDate.getMonth() + 1).padStart(2, '0');
            const day = String(parsedDate.getDate()).padStart(2, '0');
            return `${year}-${month}-${day}`;
          }
        } catch (error) {
          // Continue to next pattern
        }
      }
    }
    
    return null;
  }
  
  private extractTime(fullText: string): string | null {
    // Time patterns - look for HH:MM AM/PM format
    const timePatterns = [
      // 12-hour format with AM/PM (e.g., "12:20 AM", "3:45 PM")
      /\b(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)\b/i,
      // 24-hour format (e.g., "15:30", "09:45")
      /\b(\d{1,2}):(\d{2})(?!\s*(?:AM|PM|am|pm))\b/
    ];
    
    for (const pattern of timePatterns) {
      const match = fullText.match(pattern);
      if (match) {
        let hours = parseInt(match[1], 10);
        const minutes = parseInt(match[2], 10);
        const meridiem = match[3] ? match[3].toUpperCase() : null;
        
        // Validate time components
        if (minutes < 0 || minutes > 59) continue;
        
        // Format based on whether it has AM/PM
        if (meridiem) {
          // 12-hour format - validate hours and format
          if (hours < 1 || hours > 12) continue;
          return `${hours}:${String(minutes).padStart(2, '0')} ${meridiem}`;
        } else {
          // 24-hour format - validate hours and convert to 12-hour format for display
          if (hours < 0 || hours > 23) continue;
          
          // Convert 24-hour to 12-hour format for consistency
          if (hours === 0) {
            return `12:${String(minutes).padStart(2, '0')} AM`;
          } else if (hours < 12) {
            return `${hours}:${String(minutes).padStart(2, '0')} AM`;
          } else if (hours === 12) {
            return `12:${String(minutes).padStart(2, '0')} PM`;
          } else {
            return `${hours - 12}:${String(minutes).padStart(2, '0')} PM`;
          }
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
    
    return null; // No default currency
  }
  
  private extractAmounts(textLines: TextLine[], language: string): Record<string, any> {
    const amounts: Record<string, any> = {};
    const candidates: Array<{amount: number, type: string, lineIndex: number, score: number}> = [];
    
    // Keywords for different amount types by language
    const keywords = {
      total: this.getTotalKeywords(language),
      subtotal: this.getSubtotalKeywords(language),
      tax: this.getTaxKeywords(language),
    };
    
    // Find amount candidates
    textLines.forEach((line, index) => {
      const text = line.text.toLowerCase();
      const amounts_in_line = this.extractAmountsFromText(line.text);
      
      amounts_in_line.forEach(amount => {
        // Determine amount type based on keywords
        let type = 'other';
        let score = 0;
        
        // Check for total keywords
        if (keywords.total.some(keyword => text.includes(keyword))) {
          type = 'total';
          score = 10;
        }
        // Check for subtotal keywords  
        else if (keywords.subtotal.some(keyword => text.includes(keyword))) {
          type = 'subtotal';
          score = 8;
        }
        // Check for tax keywords
        else if (keywords.tax.some(keyword => text.includes(keyword))) {
          type = 'tax';
          score = 6;
        }
        // Position-based scoring for total (usually at bottom)
        else if (index > textLines.length * 0.7) {
          type = 'total';
          score = 5;
        }
        
        candidates.push({ amount, type, lineIndex: index, score });
      });
    });
    
    // Select best candidates for each type
    const bestTotal = this.selectBestCandidate(candidates, 'total');
    const bestSubtotal = this.selectBestCandidate(candidates, 'subtotal');
    const bestTax = this.selectBestCandidate(candidates, 'tax');
    
    if (bestTotal) amounts.total = bestTotal.amount;
    if (bestSubtotal) amounts.subtotal = bestSubtotal.amount;
    if (bestTax) amounts.tax_total = bestTax.amount;
    
    return amounts;
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
    
    // Simple item extraction - look for lines with name and price
    for (const line of textLines) {
      const text = line.text.trim();
      
      // Skip header/footer lines
      if (this.isHeaderOrFooterLine(text)) continue;
      
      // Look for pattern: NAME ... PRICE
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
            tax_rate: 0, // Would need more sophisticated logic
          });
        }
      }
    }
    
    return items;
  }
  
  // Helper methods
  
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
  
  private extractAmountsFromText(text: string): number[] {
    const amountPattern = /(\d+[.,]\d{2})/g;
    const matches = text.match(amountPattern) || [];
    
    return matches.map(match => {
      const normalized = match.replace(',', '.');
      return parseFloat(normalized);
    }).filter(num => !isNaN(num));
  }
  
  private selectBestCandidate(candidates: any[], type: string): any {
    const typeCandidates = candidates.filter(c => c.type === type);
    if (typeCandidates.length === 0) return null;
    
    // Sort by score descending
    typeCandidates.sort((a, b) => b.score - a.score);
    return typeCandidates[0];
  }
  
  private getTotalKeywords(language: string): string[] {
    const keywords = {
      en: ['total', 'grand total', 'sum'],
      fi: ['yhteensä', 'summa', 'loppusumma'],
      sv: ['summa', 'totalt', 'slutsumma'],
      fr: ['total', 'somme', 'montant total'],
      de: ['gesamt', 'summe', 'gesamtbetrag'],
      it: ['totale', 'somma', 'importo totale'],
      es: ['total', 'suma', 'importe total'],
    };
    
    return keywords[language as keyof typeof keywords] || keywords.en;
  }
  
  private getSubtotalKeywords(language: string): string[] {
    const keywords = {
      en: ['subtotal', 'sub total', 'sub-total'],
      fi: ['välisumma', 'alisumma'],
      sv: ['delsumma', 'mellansumma'],
      fr: ['sous-total', 'sous total'],
      de: ['zwischensumme', 'teilsumme'],
      it: ['subtotale', 'parziale'],
      es: ['subtotal', 'parcial'],
    };
    
    return keywords[language as keyof typeof keywords] || keywords.en;
  }
  
  private getTaxKeywords(language: string): string[] {
    const keywords = {
      en: ['tax', 'vat', 'sales tax'],
      fi: ['alv', 'arvonlisävero', 'vero'],
      sv: ['moms', 'skatt'],
      fr: ['tva', 'taxe'],
      de: ['mwst', 'steuer'],
      it: ['iva', 'tassa'],
      es: ['iva', 'impuesto'],
    };
    
    return keywords[language as keyof typeof keywords] || keywords.en;
  }
  
  private calculateExtractionConfidence(extractedData: Record<string, any>, ocrConfidence: number, warningCount: number): number {
    let confidence = ocrConfidence;
    
    // Required field penalties
    if (!extractedData.total) confidence *= 0.5;
    if (!extractedData.merchant_name) confidence *= 0.8;
    if (!extractedData.date) confidence *= 0.9;
    
    // Warning penalties
    confidence *= Math.max(0.3, 1.0 - (warningCount * 0.1));
    
    return Math.max(0.0, Math.min(1.0, confidence));
  }
}