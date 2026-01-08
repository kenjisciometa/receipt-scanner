// Mock OCR Service for development/testing without Google Cloud credentials
import { OCRResult, TextLine } from '@/types/ocr';

export class MockOCRService {
  
  async processImage(imageBuffer: Buffer): Promise<OCRResult> {
    const startTime = Date.now();
    
    // Simulate processing time
    await new Promise(resolve => setTimeout(resolve, 800 + Math.random() * 400));
    
    // Generate realistic mock receipt data
    const receipts = this.getVariedReceiptData();
    const selectedReceipt = receipts[Math.floor(Math.random() * receipts.length)];
    
    const fullText = selectedReceipt.textLines.map(line => line.text).join('\n');
    const confidence = selectedReceipt.textLines.reduce((acc, line) => acc + line.confidence, 0) / selectedReceipt.textLines.length;
    
    return {
      text: fullText,
      textLines: selectedReceipt.textLines,
      confidence,
      detected_language: selectedReceipt.language,
      processing_time: Date.now() - startTime,
      success: true,
    };
  }

  async processImages(imageBuffers: Buffer[]): Promise<OCRResult[]> {
    return Promise.all(imageBuffers.map(buffer => this.processImage(buffer)));
  }

  async processImageFile(imagePath: string): Promise<OCRResult> {
    // For mock service, we don't actually read the file
    // Just generate mock data
    return this.processImage(Buffer.alloc(0));
  }

  private getVariedReceiptData() {
    return [
      // Finnish K-Market Receipt
      {
        language: 'fi',
        textLines: [
          { text: "K-Market Keskus", confidence: 0.95, boundingBox: [100, 50, 200, 30] },
          { text: "Kauppakatu 15", confidence: 0.92, boundingBox: [100, 90, 180, 25] },
          { text: "00100 Helsinki", confidence: 0.90, boundingBox: [100, 120, 160, 25] },
          { text: "15.01.2024 14:30", confidence: 0.88, boundingBox: [100, 160, 140, 25] },
          { text: "Maito 1L                 €1,90", confidence: 0.93, boundingBox: [100, 200, 250, 25] },
          { text: "Leipä                    €2,50", confidence: 0.91, boundingBox: [100, 230, 250, 25] },
          { text: "Juusto 200g              €4,20", confidence: 0.89, boundingBox: [100, 260, 250, 25] },
          { text: "ALV 14%                  €1,22", confidence: 0.87, boundingBox: [100, 300, 200, 25] },
          { text: "ALV 24%                  €1,01", confidence: 0.86, boundingBox: [100, 330, 200, 25] },
          { text: "YHTEENSÄ                 €10,83", confidence: 0.94, boundingBox: [100, 370, 220, 30] },
          { text: "KORTTIMAKSU              €10,83", confidence: 0.92, boundingBox: [100, 410, 220, 25] },
          { text: "Kuitti #K2024-001234", confidence: 0.85, boundingBox: [100, 440, 180, 20] },
          { text: "Kiitos käynnistä!", confidence: 0.83, boundingBox: [100, 460, 180, 25] }
        ]
      },
      // English Starbucks Receipt
      {
        language: 'en',
        textLines: [
          { text: "Starbucks Coffee", confidence: 0.96, boundingBox: [120, 45, 180, 35] },
          { text: "Downtown Location", confidence: 0.91, boundingBox: [125, 85, 160, 25] },
          { text: "123 Main St, NYC", confidence: 0.89, boundingBox: [115, 115, 170, 25] },
          { text: "Jan 15, 2024 15:42", confidence: 0.92, boundingBox: [110, 155, 160, 25] },
          { text: "Grande Latte             $5.25", confidence: 0.94, boundingBox: [100, 195, 260, 25] },
          { text: "Blueberry Muffin         $3.75", confidence: 0.90, boundingBox: [100, 225, 260, 25] },
          { text: "Subtotal                 $9.00", confidence: 0.88, boundingBox: [100, 265, 220, 25] },
          { text: "Tax (8.75%)              $0.79", confidence: 0.85, boundingBox: [100, 295, 220, 25] },
          { text: "Total                    $9.79", confidence: 0.95, boundingBox: [100, 335, 220, 30] },
          { text: "Card Payment             $9.79", confidence: 0.93, boundingBox: [100, 375, 220, 25] },
          { text: "Receipt #SB-78901", confidence: 0.87, boundingBox: [100, 405, 170, 20] },
          { text: "Thank you for visiting!", confidence: 0.82, boundingBox: [100, 435, 200, 25] }
        ]
      },
      // German Supermarket Receipt
      {
        language: 'de',
        textLines: [
          { text: "REWE Markt", confidence: 0.94, boundingBox: [130, 50, 140, 30] },
          { text: "Berliner Straße 45", confidence: 0.88, boundingBox: [110, 85, 180, 25] },
          { text: "10115 Berlin", confidence: 0.90, boundingBox: [125, 115, 140, 25] },
          { text: "15.01.2024 16:20", confidence: 0.91, boundingBox: [115, 155, 145, 25] },
          { text: "Brot 500g                €2.49", confidence: 0.92, boundingBox: [100, 195, 250, 25] },
          { text: "Butter                   €1.89", confidence: 0.89, boundingBox: [100, 225, 250, 25] },
          { text: "Milch 1L                 €0.99", confidence: 0.93, boundingBox: [100, 255, 250, 25] },
          { text: "MwSt. 7%                 €0.38", confidence: 0.86, boundingBox: [100, 295, 200, 25] },
          { text: "Gesamt                   €5.75", confidence: 0.96, boundingBox: [100, 335, 200, 30] },
          { text: "EC-Karte                 €5.75", confidence: 0.91, boundingBox: [100, 375, 200, 25] },
          { text: "Beleg-Nr: RW-4567890", confidence: 0.84, boundingBox: [100, 405, 190, 20] },
          { text: "Vielen Dank!", confidence: 0.80, boundingBox: [130, 435, 120, 25] }
        ]
      },
      // Walmart Receipt with problematic line merging (test case for adaptive threshold)
      {
        language: 'en',
        textLines: [
          { text: "WALL-MART", confidence: 0.8, boundingBox: [59, 35, 100, 14] },
          { text: "SUPERSTORE", confidence: 0.8, boundingBox: [160, 35, 120, 14] },
          { text: "GATORADE #2323", confidence: 0.9, boundingBox: [16, 124, 150, 20] },
          { text: "2.97", confidence: 0.9, boundingBox: [200, 124, 40, 20] },
          { text: "TOWEL OP #23432435", confidence: 0.8, boundingBox: [16, 148, 180, 20] },
          { text: "2.00", confidence: 0.9, boundingBox: [200, 148, 40, 20] },
          { text: "PUSH-SHIRT PINS", confidence: 0.8, boundingBox: [16, 172, 160, 20] },
          { text: "16.88", confidence: 0.9, boundingBox: [190, 172, 50, 20] },
          // Problematic financial summary section (closely spaced)
          { text: "TAX", confidence: 0.8, boundingBox: [87, 205, 30, 12] },
          { text: "TAX", confidence: 0.8, boundingBox: [120, 205, 30, 12] }, 
          { text: "2", confidence: 0.8, boundingBox: [155, 205, 15, 12] },
          { text: "1", confidence: 0.8, boundingBox: [175, 205, 15, 12] },
          { text: "SUBTOTAL", confidence: 0.9, boundingBox: [87, 218, 60, 12] },
          { text: "7.89", confidence: 0.9, boundingBox: [150, 218, 35, 12] },
          { text: "4.90", confidence: 0.9, boundingBox: [190, 218, 35, 12] },
          { text: "TOTAL", confidence: 0.9, boundingBox: [87, 231, 40, 12] },
          { text: "%", confidence: 0.8, boundingBox: [130, 231, 15, 12] },
          { text: "%", confidence: 0.8, boundingBox: [150, 231, 15, 12] },
          { text: "23.09", confidence: 0.9, boundingBox: [170, 231, 40, 12] },
          { text: "27.27", confidence: 0.9, boundingBox: [215, 231, 40, 12] },
          { text: "2.90", confidence: 0.9, boundingBox: [260, 231, 35, 12] },
          { text: "1.28", confidence: 0.9, boundingBox: [300, 231, 35, 12] },
          { text: "CREDIT", confidence: 0.8, boundingBox: [149, 259, 60, 24] },
          { text: "27.27", confidence: 0.9, boundingBox: [220, 259, 40, 24] },
          { text: "CUSTOMER COPY", confidence: 0.8, boundingBox: [97, 541, 151, 11] }
        ]
      },
      // French Café Receipt
      {
        language: 'fr',
        textLines: [
          { text: "Café de Paris", confidence: 0.93, boundingBox: [125, 50, 150, 30] },
          { text: "15 Rue de la Paix", confidence: 0.87, boundingBox: [110, 85, 170, 25] },
          { text: "75001 Paris", confidence: 0.91, boundingBox: [130, 115, 130, 25] },
          { text: "15/01/2024 14:35", confidence: 0.89, boundingBox: [115, 155, 150, 25] },
          { text: "Espresso                 €2.80", confidence: 0.94, boundingBox: [100, 195, 250, 25] },
          { text: "Croissant                €3.20", confidence: 0.92, boundingBox: [100, 225, 250, 25] },
          { text: "Sous-total               €6.00", confidence: 0.88, boundingBox: [100, 265, 220, 25] },
          { text: "TVA 10%                  €0.60", confidence: 0.85, boundingBox: [100, 295, 200, 25] },
          { text: "Total                    €6.60", confidence: 0.95, boundingBox: [100, 335, 200, 30] },
          { text: "Carte bancaire           €6.60", confidence: 0.90, boundingBox: [100, 375, 220, 25] },
          { text: "Ticket N°: CP-123456", confidence: 0.83, boundingBox: [100, 405, 180, 20] },
          { text: "Merci de votre visite!", confidence: 0.79, boundingBox: [100, 435, 200, 25] }
        ]
      }
    ];
  }

  // Alternative mock data for different receipt types
  async processImageWithType(type: 'receipt' | 'invoice'): Promise<OCRResult> {
    const startTime = Date.now();
    await new Promise(resolve => setTimeout(resolve, 800));

    if (type === 'invoice') {
      const mockInvoiceLines: TextLine[] = [
        {
          text: "INVOICE",
          confidence: 0.96,
          boundingBox: [100, 50, 120, 35]
        },
        {
          text: "ABC Company Ltd",
          confidence: 0.94,
          boundingBox: [100, 100, 180, 30]
        },
        {
          text: "Invoice Number: INV-2024-001",
          confidence: 0.92,
          boundingBox: [100, 150, 220, 25]
        },
        {
          text: "Date: 15.01.2024",
          confidence: 0.90,
          boundingBox: [100, 180, 140, 25]
        },
        {
          text: "Due Date: 15.02.2024",
          confidence: 0.89,
          boundingBox: [100, 210, 160, 25]
        },
        {
          text: "Bill To:",
          confidence: 0.87,
          boundingBox: [100, 250, 80, 25]
        },
        {
          text: "Customer Company",
          confidence: 0.88,
          boundingBox: [100, 280, 160, 25]
        },
        {
          text: "Consulting Services      €500.00",
          confidence: 0.91,
          boundingBox: [100, 330, 280, 25]
        },
        {
          text: "VAT 24%                  €120.00",
          confidence: 0.86,
          boundingBox: [100, 370, 200, 25]
        },
        {
          text: "Total Amount             €620.00",
          confidence: 0.93,
          boundingBox: [100, 410, 220, 30]
        },
        {
          text: "Payment Terms: Net 30",
          confidence: 0.85,
          boundingBox: [100, 450, 180, 25]
        }
      ];

      const fullText = mockInvoiceLines.map(line => line.text).join('\n');
      const confidence = mockInvoiceLines.reduce((acc, line) => acc + line.confidence, 0) / mockInvoiceLines.length;

      return {
        text: fullText,
        textLines: mockInvoiceLines,
        confidence,
        detected_language: 'en',
        processing_time: Date.now() - startTime,
        success: true,
      };
    }

    // Default to receipt type
    return this.processImage(Buffer.alloc(0));
  }
}