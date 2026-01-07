// Universal Tax Extraction System Test API Route
import { NextRequest, NextResponse } from 'next/server';
import { EnhancedReceiptExtractionService } from '@/services/extraction/enhanced-receipt-extractor';
import { UniversalTaxExtractor } from '@/services/extraction/universal/universal-tax-extractor';

export async function POST(request: NextRequest) {
  try {
    const { textLines, text, detected_language, test_mode } = await request.json();
    
    if (!textLines || !text) {
      return NextResponse.json({ 
        success: false, 
        error: 'Text lines and text required' 
      }, { status: 400 });
    }

    console.log('🌍 Testing Universal Tax Extraction System');
    
    let results: any = {};

    if (test_mode === 'standalone') {
      // Test universal system in isolation
      const universalExtractor = new UniversalTaxExtractor({
        enableLearning: true,
        minConfidenceThreshold: 0.2,
        maxCandidatesPerSection: 10,
        enableFallbackMethods: true,
        debugMode: true
      });

      const startTime = Date.now();
      const universalResult = await universalExtractor.extractTaxInformation(
        textLines,
        detected_language || 'en'
      );
      const processingTime = Date.now() - startTime;

      results.universal_standalone = {
        result: universalResult,
        processing_time: processingTime
      };

      // Get learning statistics
      const learningStats = universalExtractor.getLearningStatistics();
      if (learningStats) {
        results.learning_statistics = learningStats;
      }

    } else {
      // Test integrated system (default)
      const enhancedExtractor = new EnhancedReceiptExtractionService({
        enableDebugLogging: true,
        minEvidenceConfidence: 0.2,
        enabledSources: ['table', 'text', 'summary_calculation', 'spatial_analysis', 'calculation']
      });

      // Create OCR result format
      const ocrResult = {
        text,
        textLines: textLines.map((line: string, index: number) => ({
          text: line.trim(),
          confidence: 0.8,
          boundingBox: [0, index * 20, 300, (index + 1) * 20] as [number, number, number, number]
        })),
        confidence: 0.8,
        detected_language: detected_language || 'en',
        processing_time: 0,
        success: true
      };

      const startTime = Date.now();
      const extractionResult = await enhancedExtractor.extract(ocrResult, detected_language);
      const processingTime = Date.now() - startTime;

      results.enhanced_integrated = {
        result: extractionResult,
        processing_time: processingTime
      };
    }

    // Test with various scenarios
    if (test_mode === 'comprehensive') {
      const testScenarios = [
        {
          name: 'US Walmart Style',
          textLines: ['SUBTOTAL 23.09', 'TAX 1 7.89% 2.90', 'TAX 2 4.50% 1.28', 'TOTAL 27.27'],
          language: 'en'
        },
        {
          name: 'German VAT Style',
          textLines: ['Zwischensumme €15.13', 'MwSt 19% €2.87', 'MwSt 7% €0.59', 'Gesamt €18.59'],
          language: 'de'
        },
        {
          name: 'Finnish ALV Style', 
          textLines: ['Yhteensä ilman ALV €35.62', 'ALV 24% €8.55', 'ALV 14% €2.10', 'Yhteensä €46.27'],
          language: 'fi'
        }
      ];

      const universalExtractor = new UniversalTaxExtractor({
        enableLearning: false, // Disable for consistent testing
        minConfidenceThreshold: 0.2,
        maxCandidatesPerSection: 10,
        enableFallbackMethods: true,
        debugMode: true
      });

      results.comprehensive_tests = [];

      for (const scenario of testScenarios) {
        const startTime = Date.now();
        const result = await universalExtractor.extractTaxInformation(
          scenario.textLines,
          scenario.language as any
        );
        const processingTime = Date.now() - startTime;

        results.comprehensive_tests.push({
          scenario_name: scenario.name,
          language: scenario.language,
          input_lines: scenario.textLines.length,
          result,
          processing_time: processingTime,
          success: result.taxEntries.length > 0
        });
      }
    }

    console.log('✅ Universal tax extraction testing completed');

    return NextResponse.json({
      success: true,
      test_mode: test_mode || 'integrated',
      results,
      system_info: {
        timestamp: new Date().toISOString(),
        input_info: {
          lines: textLines.length,
          language: detected_language || 'en',
          text_length: text.length
        }
      }
    });

  } catch (error) {
    console.error('Universal tax extraction test error:', error);
    
    return NextResponse.json({ 
      success: false, 
      error: 'Universal tax extraction test failed',
      details: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 });
  }
}

// GET endpoint for system information and test scenarios
export async function GET(request: NextRequest) {
  const url = new URL(request.url);
  const action = url.searchParams.get('action');

  if (action === 'learning-stats') {
    // Get current learning statistics
    try {
      const universalExtractor = new UniversalTaxExtractor({
        enableLearning: true,
        minConfidenceThreshold: 0.3,
        maxCandidatesPerSection: 10,
        enableFallbackMethods: true,
        debugMode: false
      });

      const stats = universalExtractor.getLearningStatistics();
      
      return NextResponse.json({
        success: true,
        learning_statistics: stats,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      return NextResponse.json({
        success: false,
        error: 'Failed to get learning statistics',
        details: error instanceof Error ? error.message : 'Unknown error'
      }, { status: 500 });
    }
  }

  if (action === 'clear-learning') {
    // Clear learning data for testing
    try {
      const universalExtractor = new UniversalTaxExtractor({
        enableLearning: true,
        minConfidenceThreshold: 0.3,
        maxCandidatesPerSection: 10,
        enableFallbackMethods: true,
        debugMode: false
      });

      universalExtractor.clearLearningData();
      
      return NextResponse.json({
        success: true,
        message: 'Learning data cleared',
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      return NextResponse.json({
        success: false,
        error: 'Failed to clear learning data',
        details: error instanceof Error ? error.message : 'Unknown error'
      }, { status: 500 });
    }
  }

  // Default: Return system information and test scenarios
  return NextResponse.json({
    success: true,
    system_info: {
      name: 'Universal Tax Extraction System',
      version: '1.0.0',
      capabilities: [
        'Language-agnostic tax detection',
        'Structural pattern analysis',
        'Statistical learning and adaptation',
        'Multi-method fusion',
        'Real-time confidence scoring'
      ],
      test_modes: [
        'standalone - Test universal system only',
        'integrated - Test within enhanced extraction service', 
        'comprehensive - Test multiple scenarios'
      ]
    },
    test_scenarios: {
      basic: {
        name: 'Basic Receipt Test',
        textLines: ['SUBTOTAL 10.00', 'TAX 8.5% 0.85', 'TOTAL 10.85'],
        language: 'en'
      },
      walmart_style: {
        name: 'US Walmart Receipt',
        textLines: ['SUBTOTAL 23.09', 'TAX 1 7.89% 2.90', 'TAX 2 4.50% 1.28', 'TOTAL 27.27'],
        language: 'en'
      },
      german_vat: {
        name: 'German VAT Receipt',
        textLines: ['Zwischensumme €15.13', 'MwSt 19% €2.87', 'MwSt 7% €0.59', 'Gesamt €18.59'],
        language: 'de'
      },
      finnish_alv: {
        name: 'Finnish ALV Receipt',
        textLines: ['Yhteensä ilman ALV €35.62', 'ALV 24% €8.55', 'ALV 14% €2.10', 'Yhteensä €46.27'],
        language: 'fi'
      }
    },
    usage_examples: {
      standalone_test: 'POST with test_mode: "standalone"',
      integrated_test: 'POST with test_mode: "integrated" (default)',
      comprehensive_test: 'POST with test_mode: "comprehensive"',
      learning_stats: 'GET ?action=learning-stats',
      clear_learning: 'GET ?action=clear-learning'
    }
  });
}