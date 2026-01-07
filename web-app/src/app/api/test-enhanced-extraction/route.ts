// Test Enhanced Receipt Extraction API Route
import { NextRequest, NextResponse } from 'next/server';
import { EnhancedReceiptExtractionService } from '@/services/extraction/enhanced-receipt-extractor';

export async function POST(request: NextRequest) {
  try {
    const { textLines, text, detected_language, confidence } = await request.json();
    
    if (!textLines || !text) {
      return NextResponse.json({ 
        success: false, 
        error: 'Text lines and text required' 
      }, { status: 400 });
    }

    console.log('🧪 Testing enhanced extraction service with tax table data');
    
    // Create OCR result format
    const ocrResult = {
      text,
      textLines,
      confidence: confidence || 0.8,
      detected_language: detected_language || 'en',
      processing_time: 0,
      success: true
    };
    
    // Create enhanced extraction service with debug logging
    const extractionService = new EnhancedReceiptExtractionService({
      enableDebugLogging: true,
      minEvidenceConfidence: 0.3,
      enabledSources: ['table', 'text', 'summary_calculation', 'spatial_analysis', 'calculation']
    });
    
    // Test extraction
    const startTime = Date.now();
    const extractionResult = await extractionService.extract(ocrResult, detected_language);
    const processingTime = Date.now() - startTime;
    
    console.log('✅ Enhanced extraction test completed');
    console.log(`📊 Results: total=${extractionResult.total}, subtotal=${extractionResult.subtotal}, tax=${extractionResult.tax_total}`);
    console.log(`📊 Tax breakdown: ${JSON.stringify(extractionResult.tax_breakdown)}`);
    
    return NextResponse.json({
      success: true,
      extraction_result: extractionResult,
      processing_time: processingTime,
      test_info: {
        input_lines: textLines.length,
        detected_language,
        ocr_confidence: confidence
      }
    });

  } catch (error) {
    console.error('Enhanced extraction test error:', error);
    
    return NextResponse.json({ 
      success: false, 
      error: 'Enhanced extraction test failed',
      details: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 });
  }
}