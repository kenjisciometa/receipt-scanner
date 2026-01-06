// Test Advanced Extraction API Route
import { NextRequest, NextResponse } from 'next/server';
import { AdvancedReceiptExtractionService } from '@/services/extraction/advanced-receipt-extractor';
import { readFile } from 'fs/promises';
import path from 'path';

export async function POST(request: NextRequest) {
  try {
    const { testData } = await request.json();
    
    if (!testData) {
      return NextResponse.json({ 
        success: false, 
        error: 'Test data required' 
      }, { status: 400 });
    }

    console.log('🧪 Testing advanced extraction with sample data');
    
    // Create extraction service
    const extractionService = new AdvancedReceiptExtractionService();
    
    // Test extraction
    const startTime = Date.now();
    const extractionResult = await extractionService.extract(testData, 'en');
    const processingTime = Date.now() - startTime;
    
    console.log('✅ Advanced extraction test completed');
    console.log(`📊 Results: total=${extractionResult.total}, subtotal=${extractionResult.subtotal}, tax=${extractionResult.tax_total}`);
    
    return NextResponse.json({
      success: true,
      extraction_result: extractionResult,
      processing_time: processingTime,
      test_info: {
        input_lines: testData.textLines?.length || 0,
        detected_language: testData.detected_language,
        ocr_confidence: testData.confidence
      }
    });

  } catch (error) {
    console.error('Test extraction error:', error);
    
    return NextResponse.json({ 
      success: false, 
      error: 'Test extraction failed',
      details: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 });
  }
}

export async function GET() {
  try {
    // Load test sample and run extraction
    const samplePath = path.join(process.cwd(), 'test-sample.json');
    const sampleData = JSON.parse(await readFile(samplePath, 'utf-8'));
    
    console.log('🧪 Running automated extraction test with sample data');
    
    const extractionService = new AdvancedReceiptExtractionService();
    const extractionResult = await extractionService.extract(sampleData, sampleData.detected_language);
    
    return NextResponse.json({
      success: true,
      test_type: 'automated_sample',
      sample_data: {
        lines: sampleData.textLines.length,
        full_text: sampleData.text,
        confidence: sampleData.confidence
      },
      extraction_result: extractionResult,
      expected_values: {
        total: 22.00,
        subtotal: 19.27,
        tax: 2.73,
        tax_rate: 14
      }
    });

  } catch (error) {
    console.error('Automated test error:', error);
    
    return NextResponse.json({ 
      success: false, 
      error: 'Automated test failed',
      details: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 });
  }
}