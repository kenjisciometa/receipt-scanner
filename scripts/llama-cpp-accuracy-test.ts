/**
 * llama.cpp (Qwen2.5-VL) GPU精度検証スクリプト
 *
 * 前提:
 * - llama-serverが http://localhost:8080 で起動していること
 */

import * as fs from 'fs';
import * as path from 'path';

// ============================================
// 設定
// ============================================

const LLAMA_SERVER_URL = 'http://localhost:8080';
const SAMPLE_DIR = path.join(__dirname, '..', 'ReceiptSample');
const OUTPUT_DIR = path.join(__dirname, '..', 'test-results');

// ============================================
// 型定義
// ============================================

interface ExtractedReceipt {
  merchant_name?: string;
  date?: string;
  time?: string;
  items?: Array<{
    name: string;
    quantity?: number;
    price: number;
  }>;
  subtotal?: number;
  tax_rate?: number;
  tax_amount?: number;
  total?: number;
  currency?: string;
  payment_method?: string;
}

interface TestResult {
  file: string;
  country: string;
  success: boolean;
  extracted: ExtractedReceipt | null;
  raw_response: string;
  processing_time_ms: number;
  error?: string;
  field_scores: {
    merchant_name: boolean;
    date: boolean;
    total: boolean;
    items: boolean;
    tax: boolean;
  };
}

// ============================================
// llama.cpp Server API クライアント
// ============================================

async function checkServerRunning(): Promise<boolean> {
  try {
    const response = await fetch(`${LLAMA_SERVER_URL}/health`);
    const data = await response.json() as { status: string };
    return data.status === 'ok';
  } catch {
    return false;
  }
}

async function extractWithLlamaCpp(imageBase64: string): Promise<{ response: string; time: number }> {
  const startTime = Date.now();

  const prompt = `You are a receipt OCR system. Extract the following information from this receipt image and return ONLY valid JSON, no other text:

{
  "merchant_name": "Store/restaurant name",
  "date": "YYYY-MM-DD format",
  "time": "HH:MM format if visible",
  "items": [
    {"name": "Item name", "quantity": 1, "price": 0.00}
  ],
  "subtotal": 0.00,
  "tax_rate": 0,
  "tax_amount": 0.00,
  "total": 0.00,
  "currency": "EUR/USD/SEK/etc",
  "payment_method": "cash/card/etc"
}

Important:
- Return ONLY the JSON object, no explanations
- Use null for fields you cannot find
- Prices should be numbers, not strings
- Date must be YYYY-MM-DD format`;

  // OpenAI互換API形式を使用
  const response = await fetch(`${LLAMA_SERVER_URL}/v1/chat/completions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: 'qwen2.5-vl',
      messages: [
        {
          role: 'user',
          content: [
            { type: 'image_url', image_url: { url: `data:image/png;base64,${imageBase64}` } },
            { type: 'text', text: prompt }
          ]
        }
      ],
      max_tokens: 1024,
      temperature: 0.1
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`llama-server API error: ${response.status} - ${errorText}`);
  }

  const data = await response.json() as { choices: Array<{ message: { content: string } }> };
  const endTime = Date.now();

  return {
    response: data.choices[0].message.content,
    time: endTime - startTime
  };
}

// ============================================
// JSON パース
// ============================================

function parseExtractedJson(rawResponse: string): ExtractedReceipt | null {
  try {
    const jsonMatch = rawResponse.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return null;
    return JSON.parse(jsonMatch[0]) as ExtractedReceipt;
  } catch {
    try {
      const codeBlockMatch = rawResponse.match(/```(?:json)?\s*([\s\S]*?)```/);
      if (codeBlockMatch) {
        return JSON.parse(codeBlockMatch[1]) as ExtractedReceipt;
      }
    } catch {
      // ignore
    }
    return null;
  }
}

// ============================================
// フィールド評価
// ============================================

function evaluateFields(extracted: ExtractedReceipt | null): TestResult['field_scores'] {
  if (!extracted) {
    return {
      merchant_name: false,
      date: false,
      total: false,
      items: false,
      tax: false
    };
  }

  return {
    merchant_name: !!(extracted.merchant_name && extracted.merchant_name.length > 0),
    date: !!(extracted.date && /\d{4}-\d{2}-\d{2}/.test(extracted.date)),
    total: !!(extracted.total && typeof extracted.total === 'number' && extracted.total > 0),
    items: !!(extracted.items && Array.isArray(extracted.items) && extracted.items.length > 0),
    tax: !!(extracted.tax_amount !== undefined || extracted.tax_rate !== undefined)
  };
}

// ============================================
// テスト実行
// ============================================

async function testSingleImage(imagePath: string): Promise<TestResult> {
  const fileName = path.basename(imagePath);
  const country = path.basename(path.dirname(imagePath));

  console.log(`  Processing: ${country}/${fileName}`);

  try {
    const imageBuffer = fs.readFileSync(imagePath);
    const imageBase64 = imageBuffer.toString('base64');

    const { response, time } = await extractWithLlamaCpp(imageBase64);
    const extracted = parseExtractedJson(response);
    const fieldScores = evaluateFields(extracted);

    const success = extracted !== null && fieldScores.total;

    return {
      file: fileName,
      country,
      success,
      extracted,
      raw_response: response,
      processing_time_ms: time,
      field_scores: fieldScores
    };
  } catch (error) {
    return {
      file: fileName,
      country,
      success: false,
      extracted: null,
      raw_response: '',
      processing_time_ms: 0,
      error: error instanceof Error ? error.message : String(error),
      field_scores: {
        merchant_name: false,
        date: false,
        total: false,
        items: false,
        tax: false
      }
    };
  }
}

async function runAllTests(): Promise<void> {
  console.log('='.repeat(60));
  console.log('llama.cpp (Qwen2.5-VL) GPU精度検証');
  console.log('='.repeat(60));

  console.log('\n[1/3] llama-server接続確認...');
  if (!await checkServerRunning()) {
    console.error('❌ llama-serverが起動していません。以下を実行してください:');
    console.error('   /path/to/llama-server -m model.gguf --mmproj mmproj.gguf -ngl 99 --port 8080');
    process.exit(1);
  }
  console.log('✅ llama-server接続OK');

  console.log('\n[2/3] サンプル画像を収集...');
  const countries = fs.readdirSync(SAMPLE_DIR).filter(f =>
    fs.statSync(path.join(SAMPLE_DIR, f)).isDirectory()
  );

  const imageFiles: string[] = [];
  for (const country of countries) {
    const countryDir = path.join(SAMPLE_DIR, country);
    const files = fs.readdirSync(countryDir)
      .filter(f => /\.(png|jpg|jpeg)$/i.test(f))
      .map(f => path.join(countryDir, f));
    imageFiles.push(...files);
  }

  console.log(`✅ ${imageFiles.length}枚の画像を発見`);
  console.log(`   国別: ${countries.join(', ')}`);

  console.log('\n[3/3] テスト実行中...');
  const results: TestResult[] = [];

  for (const imagePath of imageFiles) {
    const result = await testSingleImage(imagePath);
    results.push(result);

    const status = result.success ? '✅' : '❌';
    const time = `${(result.processing_time_ms / 1000).toFixed(1)}s`;
    console.log(`    ${status} ${result.country}/${result.file} (${time})`);
  }

  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const outputPath = path.join(OUTPUT_DIR, `llama-cpp-gpu-test-${timestamp}.json`);
  fs.writeFileSync(outputPath, JSON.stringify(results, null, 2));

  printSummary(results);

  console.log(`\n詳細結果: ${outputPath}`);
}

function printSummary(results: TestResult[]): void {
  console.log('\n' + '='.repeat(60));
  console.log('検証結果サマリー');
  console.log('='.repeat(60));

  const total = results.length;
  const successful = results.filter(r => r.success).length;
  const successRate = ((successful / total) * 100).toFixed(1);

  console.log(`\n全体成功率: ${successful}/${total} (${successRate}%)`);

  console.log('\n【国別成功率】');
  const byCountry = new Map<string, TestResult[]>();
  for (const r of results) {
    if (!byCountry.has(r.country)) byCountry.set(r.country, []);
    byCountry.get(r.country)!.push(r);
  }

  for (const [country, countryResults] of byCountry) {
    const countrySuccess = countryResults.filter(r => r.success).length;
    const rate = ((countrySuccess / countryResults.length) * 100).toFixed(0);
    console.log(`  ${country}: ${countrySuccess}/${countryResults.length} (${rate}%)`);
  }

  console.log('\n【フィールド別検出率】');
  const fieldNames: (keyof TestResult['field_scores'])[] = ['merchant_name', 'date', 'total', 'items', 'tax'];
  for (const field of fieldNames) {
    const detected = results.filter(r => r.field_scores[field]).length;
    const rate = ((detected / total) * 100).toFixed(0);
    console.log(`  ${field}: ${detected}/${total} (${rate}%)`);
  }

  const times = results.map(r => r.processing_time_ms).filter(t => t > 0);
  if (times.length > 0) {
    const avgTime = (times.reduce((a, b) => a + b, 0) / times.length / 1000).toFixed(1);
    const minTime = (Math.min(...times) / 1000).toFixed(1);
    const maxTime = (Math.max(...times) / 1000).toFixed(1);
    console.log(`\n【処理時間】`);
    console.log(`  平均: ${avgTime}秒`);
    console.log(`  最短: ${minTime}秒`);
    console.log(`  最長: ${maxTime}秒`);
  }

  const errors = results.filter(r => r.error);
  if (errors.length > 0) {
    console.log(`\n【エラー】`);
    for (const e of errors) {
      console.log(`  ${e.country}/${e.file}: ${e.error}`);
    }
  }
}

runAllTests().catch(console.error);
