// Google Cloud Vision OCR Service
import { ImageAnnotatorClient } from '@google-cloud/vision';
import { OCRResult, TextLine } from '@/types/ocr';

export class GoogleVisionOCRService {
  private client: ImageAnnotatorClient;

  constructor() {
    // Initialize Google Cloud Vision client
    this.client = new ImageAnnotatorClient({
      projectId: process.env.GOOGLE_CLOUD_PROJECT_ID,
      keyFilename: process.env.GOOGLE_CLOUD_KEY_FILE, // or use credentials object
      credentials: process.env.GOOGLE_CLOUD_PRIVATE_KEY ? {
        client_email: process.env.GOOGLE_CLOUD_CLIENT_EMAIL!,
        private_key: process.env.GOOGLE_CLOUD_PRIVATE_KEY.replace(/\\n/g, '\n'),
        project_id: process.env.GOOGLE_CLOUD_PROJECT_ID!,
      } : undefined,
    });
  }

  async processImage(imageBuffer: Buffer): Promise<OCRResult> {
    const startTime = Date.now();
    
    try {
      // Perform text detection
      const [result] = await this.client.textDetection({
        image: {
          content: imageBuffer.toString('base64'),
        },
        imageContext: {
          languageHints: ['en', 'fi', 'sv', 'fr', 'de', 'it', 'es'],
        },
      });

      const detections = result.textAnnotations || [];
      
      if (detections.length === 0) {
        return {
          text: '',
          textLines: [],
          confidence: 0,
          detected_language: 'unknown',
          processing_time: Date.now() - startTime,
          success: false,
        };
      }

      // First annotation contains full text
      const fullText = detections[0].description || '';
      
      // Extract individual text lines with bounding boxes
      const textLines: TextLine[] = this.extractTextLines(detections.slice(1));
      
      // Calculate overall confidence
      const confidence = this.calculateOverallConfidence(textLines);
      
      // Detect language (simple heuristic)
      const detectedLanguage = this.detectLanguage(fullText);

      return {
        text: fullText,
        textLines,
        confidence,
        detected_language: detectedLanguage,
        processing_time: Date.now() - startTime,
        success: true,
      };

    } catch (error) {
      console.error('Google Vision OCR Error:', error);
      
      return {
        text: '',
        textLines: [],
        confidence: 0,
        detected_language: 'unknown',
        processing_time: Date.now() - startTime,
        success: false,
      };
    }
  }

  private extractTextLines(detections: any[]): TextLine[] {
    return detections.map(detection => {
      const vertices = detection.boundingPoly?.vertices || [];
      let boundingBox: [number, number, number, number] = [0, 0, 0, 0];

      if (vertices.length >= 2) {
        const xs = vertices.map((v: any) => v.x || 0);
        const ys = vertices.map((v: any) => v.y || 0);
        
        const minX = Math.min(...xs);
        const minY = Math.min(...ys);
        const maxX = Math.max(...xs);
        const maxY = Math.max(...ys);
        
        boundingBox = [minX, minY, maxX - minX, maxY - minY];
      }

      return {
        text: detection.description || '',
        confidence: detection.confidence || 0.8, // Google Vision doesn't always provide confidence
        boundingBox,
      };
    });
  }

  private calculateOverallConfidence(textLines: TextLine[]): number {
    if (textLines.length === 0) return 0;
    
    const totalConfidence = textLines.reduce((sum, line) => sum + line.confidence, 0);
    return totalConfidence / textLines.length;
  }

  private detectLanguage(text: string): string {
    // Simple language detection based on common words
    const languagePatterns = {
      fi: ['kuitti', 'yhteensä', 'alv', 'päivämäärä', 'maksu'],
      sv: ['kvitto', 'summa', 'moms', 'datum', 'betalning'],
      fr: ['reçu', 'total', 'tva', 'date', 'paiement'],
      de: ['quittung', 'gesamt', 'mwst', 'datum', 'zahlung'],
      it: ['ricevuta', 'totale', 'iva', 'data', 'pagamento'],
      es: ['recibo', 'total', 'iva', 'fecha', 'pago'],
    };

    const textLower = text.toLowerCase();
    
    for (const [lang, patterns] of Object.entries(languagePatterns)) {
      const matchCount = patterns.filter(pattern => textLower.includes(pattern)).length;
      if (matchCount >= 2) {
        return lang;
      }
    }

    return 'en'; // Default to English
  }

  // Batch processing for multiple images
  async processImages(imageBuffers: Buffer[]): Promise<OCRResult[]> {
    const results = await Promise.all(
      imageBuffers.map(buffer => this.processImage(buffer))
    );
    return results;
  }

  // Process image from file path
  async processImageFile(imagePath: string): Promise<OCRResult> {
    const fs = await import('fs');
    const imageBuffer = fs.readFileSync(imagePath);
    return this.processImage(imageBuffer);
  }
}