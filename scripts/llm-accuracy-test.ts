/**
 * Qwen2-VL 7B 精度検証スクリプト
 *
 * 使用方法:
 * 1. Ollamaをインストール: curl -fsSL https://ollama.com/install.sh | sh
 * 2. モデルをダウンロード: ollama pull qwen2-vl:7b
 * 3. 実行: npx ts-node scripts/llm-accuracy-test.ts
 */

import * as fs from 'fs';
import * as path from 'path';

// ============================================
// 設定
// ============================================

const OLLAMA_URL = 'http://localhost:11434';
const MODEL_NAME = 'qwen2.5vl:7b';
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
// Ollama API クライアント
// ============================================

async function checkOllamaRunning(): Promise<boolean> {
  try {
    const response = await fetch(`${OLLAMA_URL}/api/tags`);
    return response.ok;
  } catch {
    return false;
  }
}

async function checkModelAvailable(): Promise<boolean> {
  try {
    const response = await fetch(`${OLLAMA_URL}/api/tags`);
    const data = await response.json() as { models: Array<{ name: string }> };
    return data.models?.some(m => m.name.includes('qwen2.5vl') || m.name.includes('qwen2-vl')) ?? false;
  } catch {
    return false;
  }
}

async function extractWithQwen(imageBase64: string): Promise<{ response: string; time: number }> {
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

  const response = await fetch(`${OLLAMA_URL}/api/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: MODEL_NAME,
      messages: [{
        role: 'user',
        content: prompt,
        images: [imageBase64]
      }],
      stream: false,
      options: {
        temperature: 0.1,  // 低めで一貫性重視
        num_predict: 1024
      }
    })
  });

  if (!response.ok) {
    throw new Error(`Ollama API error: ${response.status}`);
  }

  const data = await response.json() as { message: { content: string } };
  const endTime = Date.now();

  return {
    response: data.message.content,
    time: endTime - startTime
  };
}

// ============================================
// JSON パース（LLM出力は不安定なので頑健に）
// ============================================

function parseExtractedJson(rawResponse: string): ExtractedReceipt | null {
  try {
    // JSONブロックを探す
    const jsonMatch = rawResponse.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return null;

    const parsed = JSON.parse(jsonMatch[0]);
    return parsed as ExtractedReceipt;
  } catch {
    // markdownコードブロック内のJSONを試す
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

    const { response, time } = await extractWithQwen(imageBase64);
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
  console.log('Qwen2-VL 7B 精度検証');
  console.log('='.repeat(60));

  // 前提条件チェック
  console.log('\n[1/4] Ollama接続確認...');
  if (!await checkOllamaRunning()) {
    console.error('❌ Ollamaが起動していません。以下を実行してください:');
    console.error('   ollama serve');
    process.exit(1);
  }
  console.log('✅ Ollama接続OK');

  console.log('\n[2/4] モデル確認...');
  if (!await checkModelAvailable()) {
    console.error('❌ qwen2-vlモデルがありません。以下を実行してください:');
    console.error('   ollama pull qwen2-vl:7b');
    process.exit(1);
  }
  console.log('✅ モデルOK');

  // サンプル画像を収集
  console.log('\n[3/4] サンプル画像を収集...');
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

  // テスト実行
  console.log('\n[4/4] テスト実行中...');
  const results: TestResult[] = [];

  for (const imagePath of imageFiles) {
    const result = await testSingleImage(imagePath);
    results.push(result);

    const status = result.success ? '✅' : '❌';
    const time = `${result.processing_time_ms}ms`;
    console.log(`    ${status} ${result.country}/${result.file} (${time})`);
  }

  // 結果を保存
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const outputPath = path.join(OUTPUT_DIR, `qwen2vl-test-${timestamp}.json`);
  fs.writeFileSync(outputPath, JSON.stringify(results, null, 2));

  // サマリー出力
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

  // 国別成功率
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

  // フィールド別成功率
  console.log('\n【フィールド別検出率】');
  const fieldNames: (keyof TestResult['field_scores'])[] = ['merchant_name', 'date', 'total', 'items', 'tax'];
  for (const field of fieldNames) {
    const detected = results.filter(r => r.field_scores[field]).length;
    const rate = ((detected / total) * 100).toFixed(0);
    console.log(`  ${field}: ${detected}/${total} (${rate}%)`);
  }

  // 処理時間
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

  // エラーがあれば表示
  const errors = results.filter(r => r.error);
  if (errors.length > 0) {
    console.log(`\n【エラー】`);
    for (const e of errors) {
      console.log(`  ${e.country}/${e.file}: ${e.error}`);
    }
  }
}

// 実行
runAllTests().catch(console.error);
