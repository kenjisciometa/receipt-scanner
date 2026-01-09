/**
 * llama.cpp (Qwen2.5-VL) LLM Service
 *
 * GPU-accelerated receipt extraction using local LLM
 */

export interface LLMExtractionResult {
  merchant_name: string | null;
  date: string | null;
  time: string | null;
  items: Array<{
    name: string;
    quantity: number;
    price: number;
    tax_rate?: number;
  }>;
  subtotal: number | null;
  tax_breakdown: Array<{
    rate: number;
    taxable_amount: number;
    tax_amount: number;
  }>;
  tax_total: number | null;
  total: number | null;
  currency: string | null;
  payment_method: string | null;
  receipt_number: string | null;
  raw_response: string;
  processing_time_ms: number;
  confidence: number;
}

export interface LLMServiceConfig {
  serverUrl: string;
  timeout: number;
  maxTokens: number;
  temperature: number;
}

const DEFAULT_CONFIG: LLMServiceConfig = {
  serverUrl: process.env.LLAMA_SERVER_URL || 'http://localhost:8080',
  timeout: parseInt(process.env.LLAMA_TIMEOUT || '30000'),
  maxTokens: 2048,
  temperature: 0.1,
};

const EXTRACTION_PROMPT = `You are a receipt OCR system. Extract all information from this receipt image and return ONLY valid JSON:

{
  "merchant_name": "Store/restaurant name",
  "date": "YYYY-MM-DD format",
  "time": "HH:MM format or null",
  "items": [
    {"name": "Item name", "quantity": 1, "price": 0.00, "tax_rate": 0}
  ],
  "subtotal": 0.00,
  "tax_breakdown": [
    {"rate": 10, "taxable_amount": 0.00, "tax_amount": 0.00}
  ],
  "tax_total": 0.00,
  "total": 0.00,
  "currency": "EUR/USD/SEK/etc",
  "payment_method": "cash/card/etc or null",
  "receipt_number": "receipt/transaction number or null"
}

Rules:
- Return ONLY the JSON object, no explanations or markdown
- Include ALL tax rates found on the receipt in tax_breakdown
- Each item should have its tax_rate if visible
- Use null for fields you cannot find
- Prices must be numbers, not strings
- Date must be YYYY-MM-DD format`;

export class LlamaCppService {
  private config: LLMServiceConfig;

  constructor(config: Partial<LLMServiceConfig> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
  }

  /**
   * Check if llama-server is running
   */
  async checkServer(): Promise<boolean> {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 5000);

      const response = await fetch(`${this.config.serverUrl}/health`, {
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      const data = await response.json();
      return data.status === 'ok';
    } catch {
      return false;
    }
  }

  /**
   * Extract receipt data using LLM
   */
  async extract(imageBase64: string): Promise<LLMExtractionResult> {
    const startTime = Date.now();

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.config.timeout);

      const response = await fetch(`${this.config.serverUrl}/v1/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'qwen2.5-vl',
          messages: [
            {
              role: 'user',
              content: [
                {
                  type: 'image_url',
                  image_url: { url: `data:image/png;base64,${imageBase64}` },
                },
                { type: 'text', text: EXTRACTION_PROMPT },
              ],
            },
          ],
          max_tokens: this.config.maxTokens,
          temperature: this.config.temperature,
        }),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        throw new Error(`LLM API error: ${response.status}`);
      }

      const data = await response.json();
      const rawResponse = data.choices[0].message.content;
      const processingTime = Date.now() - startTime;

      // Parse JSON from response
      const extracted = this.parseResponse(rawResponse);

      return {
        ...extracted,
        raw_response: rawResponse,
        processing_time_ms: processingTime,
        confidence: this.calculateConfidence(extracted),
      };
    } catch (error) {
      const processingTime = Date.now() - startTime;
      throw new Error(`LLM extraction failed after ${processingTime}ms: ${error}`);
    }
  }

  /**
   * Parse JSON from LLM response
   */
  private parseResponse(rawResponse: string): Omit<LLMExtractionResult, 'raw_response' | 'processing_time_ms' | 'confidence'> {
    try {
      // Try to find JSON in the response
      const jsonMatch = rawResponse.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        throw new Error('No JSON found in response');
      }

      const parsed = JSON.parse(jsonMatch[0]);

      return {
        merchant_name: parsed.merchant_name || null,
        date: parsed.date || null,
        time: parsed.time || null,
        items: Array.isArray(parsed.items) ? parsed.items : [],
        subtotal: typeof parsed.subtotal === 'number' ? parsed.subtotal : null,
        tax_breakdown: Array.isArray(parsed.tax_breakdown) ? parsed.tax_breakdown : [],
        tax_total: typeof parsed.tax_total === 'number' ? parsed.tax_total : null,
        total: typeof parsed.total === 'number' ? parsed.total : null,
        currency: parsed.currency || null,
        payment_method: parsed.payment_method || null,
        receipt_number: parsed.receipt_number || null,
      };
    } catch {
      // Return empty result on parse failure
      return {
        merchant_name: null,
        date: null,
        time: null,
        items: [],
        subtotal: null,
        tax_breakdown: [],
        tax_total: null,
        total: null,
        currency: null,
        payment_method: null,
        receipt_number: null,
      };
    }
  }

  /**
   * Calculate confidence score based on extracted fields
   */
  private calculateConfidence(extracted: Omit<LLMExtractionResult, 'raw_response' | 'processing_time_ms' | 'confidence'>): number {
    let score = 0;
    let maxScore = 0;

    // Critical fields (higher weight)
    if (extracted.total !== null && extracted.total > 0) {
      score += 3;
    }
    maxScore += 3;

    if (extracted.merchant_name) {
      score += 2;
    }
    maxScore += 2;

    if (extracted.date && /\d{4}-\d{2}-\d{2}/.test(extracted.date)) {
      score += 2;
    }
    maxScore += 2;

    // Important fields
    if (extracted.items.length > 0) {
      score += 2;
    }
    maxScore += 2;

    if (extracted.tax_breakdown.length > 0) {
      score += 2;
    }
    maxScore += 2;

    // Optional fields
    if (extracted.subtotal !== null) {
      score += 1;
    }
    maxScore += 1;

    if (extracted.currency) {
      score += 1;
    }
    maxScore += 1;

    if (extracted.payment_method) {
      score += 1;
    }
    maxScore += 1;

    return Math.round((score / maxScore) * 100) / 100;
  }
}

// Singleton instance
let llamaServiceInstance: LlamaCppService | null = null;

export function getLlamaService(): LlamaCppService {
  if (!llamaServiceInstance) {
    llamaServiceInstance = new LlamaCppService();
  }
  return llamaServiceInstance;
}
