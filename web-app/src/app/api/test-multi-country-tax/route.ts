// Multi-Country Tax Extraction Test API Route
import { NextRequest, NextResponse } from 'next/server';
import { MultiCountryTaxExtractor } from '@/services/extraction/multi-country-tax-extractor';

export async function POST(request: NextRequest) {
  try {
    const { textLines, text, detected_language, test_scenarios } = await request.json();
    
    if (!textLines || !text) {
      return NextResponse.json({ 
        success: false, 
        error: 'Text lines and text required' 
      }, { status: 400 });
    }

    console.log('🌍 Testing multi-country tax extraction system');
    
    const multiCountryExtractor = new MultiCountryTaxExtractor(true); // Enable debug mode
    
    // Test extraction for current receipt
    const startTime = Date.now();
    const extractionResult = await multiCountryExtractor.extractTaxBreakdown(
      textLines,
      text,
      detected_language || 'en'
    );
    const processingTime = Date.now() - startTime;
    
    // Additional test scenarios if provided
    let scenarioResults = [];
    if (test_scenarios && Array.isArray(test_scenarios)) {
      console.log(`🧪 Testing ${test_scenarios.length} additional scenarios`);
      
      for (const scenario of test_scenarios) {
        const scenarioStartTime = Date.now();
        const scenarioResult = await multiCountryExtractor.extractTaxBreakdown(
          scenario.textLines || [],
          scenario.text || '',
          scenario.language || 'en'
        );
        const scenarioProcessingTime = Date.now() - scenarioStartTime;
        
        scenarioResults.push({
          scenario_name: scenario.name || 'unnamed',
          language: scenario.language,
          result: scenarioResult,
          processing_time: scenarioProcessingTime
        });
      }
    }
    
    console.log('✅ Multi-country tax extraction test completed');
    console.log(`📊 Main Result: country=${extractionResult.detected_country}, format=${extractionResult.detected_format}`);
    console.log(`📊 Tax breakdown entries: ${extractionResult.tax_breakdown.length}`);
    console.log(`📊 Total tax: ${extractionResult.tax_total}, confidence: ${extractionResult.extraction_confidence}`);
    
    return NextResponse.json({
      success: true,
      main_result: {
        extraction_result: extractionResult,
        processing_time: processingTime,
        input_info: {
          input_lines: textLines.length,
          detected_language,
          text_length: text.length
        }
      },
      scenario_results: scenarioResults,
      system_info: {
        total_scenarios_tested: scenarioResults.length + 1,
        total_processing_time: processingTime + scenarioResults.reduce((sum, s) => sum + s.processing_time, 0)
      }
    });

  } catch (error) {
    console.error('Multi-country tax extraction test error:', error);
    
    return NextResponse.json({ 
      success: false, 
      error: 'Multi-country tax extraction test failed',
      details: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 });
  }
}

// Helper function to create test scenarios
export async function GET() {
  const testScenarios = [
    {
      name: 'German Receipt - VAT Table',
      language: 'de',
      text: `
        Zwischensumme          €15.13
        MwSt 19%              €2.87
        MwSt 7%               €0.59
        Gesamt                €18.59
      `,
      textLines: [
        'Zwischensumme          €15.13',
        'MwSt 19%              €2.87', 
        'MwSt 7%               €0.59',
        'Gesamt                €18.59'
      ]
    },
    {
      name: 'Finnish Receipt - ALV Breakdown',
      language: 'fi', 
      text: `
        Yhteensä ilman ALV     €35.62
        ALV 24%               €8.55
        ALV 14%               €2.10
        Yhteensä              €46.27
      `,
      textLines: [
        'Yhteensä ilman ALV     €35.62',
        'ALV 24%               €8.55',
        'ALV 14%               €2.10', 
        'Yhteensä              €46.27'
      ]
    },
    {
      name: 'Swedish Receipt - MOMS',
      language: 'sv',
      text: `
        Delsumma              kr 100.00
        Moms 25%              kr  25.00
        Moms 12%              kr   6.00
        Totalt                kr 131.00
      `,
      textLines: [
        'Delsumma              kr 100.00',
        'Moms 25%              kr  25.00',
        'Moms 12%              kr   6.00',
        'Totalt                kr 131.00'
      ]
    },
    {
      name: 'French Receipt - TVA',
      language: 'fr',
      text: `
        Sous-total            €45.50
        TVA 20%               €9.10
        TVA 10%               €2.15
        Total                 €56.75
      `,
      textLines: [
        'Sous-total            €45.50',
        'TVA 20%               €9.10',
        'TVA 10%               €2.15',
        'Total                 €56.75'
      ]
    },
    {
      name: 'US Receipt - Sales Tax (Walmart Style)',
      language: 'en',
      text: `
        SUBTOTAL              $23.09
        TAX 1  7.89%           $2.90
        TAX 2  4.50%           $1.28
        TOTAL                 $27.27
      `,
      textLines: [
        'SUBTOTAL              $23.09',
        'TAX 1  7.89%           $2.90',
        'TAX 2  4.50%           $1.28',
        'TOTAL                 $27.27'
      ]
    }
  ];

  return NextResponse.json({
    success: true,
    test_scenarios: testScenarios,
    info: {
      total_scenarios: testScenarios.length,
      supported_languages: ['en', 'de', 'fi', 'sv', 'fr', 'it', 'es'],
      supported_countries: ['US', 'DE', 'FI', 'SE', 'FR', 'IT', 'ES', 'GB']
    }
  });
}