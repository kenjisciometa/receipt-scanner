/**
 * Debug script to get raw OCR data before grouping
 * Run with: npx ts-node test-raw-ocr-debug.ts
 */

import { GoogleVisionOCRService } from './src/services/ocr/google-vision';
import * as fs from 'fs';
import * as path from 'path';

async function debugRawOCR() {
  const imagePath = path.join(__dirname, 'uploads/52f85f8e-2d23-4f60-954d-ab6e33aece79.png');

  if (!fs.existsSync(imagePath)) {
    console.error('Image file not found:', imagePath);
    return;
  }

  console.log('=== RAW OCR DEBUG ===\n');
  console.log('Processing image:', imagePath);

  const ocrService = new GoogleVisionOCRService();
  const imageBuffer = fs.readFileSync(imagePath);

  try {
    const result = await ocrService.processImage(imageBuffer);

    console.log('\n=== RAW OCR RESULT (BEFORE GROUPING) ===\n');
    console.log('Total textLines:', result.textLines.length);
    console.log('Confidence:', result.confidence);
    console.log('Detected language:', result.detected_language);

    // Filter for the tax table area (y > 750)
    const taxAreaLines = result.textLines
      .filter(line => line.boundingBox[1] > 750 && line.boundingBox[1] < 850)
      .sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);

    console.log('\n=== TAX TABLE AREA (y > 750, y < 850) ===\n');
    console.log(`Found ${taxAreaLines.length} text elements in this area:`);

    taxAreaLines.forEach((line, i) => {
      const [x, y, w, h] = line.boundingBox;
      console.log(`   ${String(i+1).padStart(2)}. y=${y}, h=${h}, x=${x}, w=${w}, text="${line.text}"`);
    });

    // Analyze Y coordinate distribution
    console.log('\n=== Y COORDINATE ANALYSIS ===\n');

    const yGroups: Map<number, string[]> = new Map();
    taxAreaLines.forEach(line => {
      const y = line.boundingBox[1];
      // Round to nearest 5px to see natural groupings
      const roundedY = Math.round(y / 5) * 5;
      if (!yGroups.has(roundedY)) {
        yGroups.set(roundedY, []);
      }
      yGroups.get(roundedY)!.push(line.text);
    });

    const sortedYGroups = Array.from(yGroups.entries()).sort((a, b) => a[0] - b[0]);
    sortedYGroups.forEach(([y, texts]) => {
      console.log(`   y~${y}: ${texts.join(', ')}`);
    });

    // Save raw data to file for further analysis
    const outputPath = path.join(__dirname, 'debug-raw-ocr-output.json');
    fs.writeFileSync(outputPath, JSON.stringify({
      totalLines: result.textLines.length,
      taxAreaLines: taxAreaLines,
      fullText: result.text,
      yGroups: Object.fromEntries(sortedYGroups)
    }, null, 2));

    console.log(`\nFull raw data saved to: ${outputPath}`);

  } catch (error) {
    console.error('OCR Error:', error);
  }
}

debugRawOCR().catch(console.error);
