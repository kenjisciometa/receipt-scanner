/**
 * Evidence-Based Fusion System Test
 * 
 * Test the new Evidence-Based Fusion system with sample data,
 * including the problematic Walmart receipt case
 */

import { EnhancedReceiptExtractionService } from '../services/extraction/enhanced-receipt-extractor.js';
import { OCRResult, TextLine } from '../types/ocr.js';

/**
 * Test case: Walmart US Receipt (previously failed with traditional extraction)
 * 
 * Expected results:
 * - SUBTOTAL: $208.98 (should be detected via Tax Breakdown → Summary calculation)
 * - TAX: $13.37 (should be detected directly from "TAX   $13.37")  
 * - TOTAL: $222.35 (should be detected directly)
 * - Tax Breakdown: [{ rate: 6.4, amount: 13.37 }] (calculated from subtotal)
 */
const WALMART_RECEIPT_OCR: OCRResult = {
  text: `Walmart
Store #123
970-728-1838  MGR: JIM JONES
1166 GRAND AVE
STERLING, CO 80751

ITEM 5564-99900999 STO  TM 14322
HUNT 61 CHELE            $18.99
HARMONY LAV REMOTE       $189.99

SUBTOTAL    $208.98
TAX         $13.37
TOTAL       $222.35

ACCOUNT #  **** **** **** VISA
CHANGE                   $0.00
TRANS ID - 6647341726627UDE
VALIDATION - 8311
PAYMENT SERVICE - 8
RESPONSE # 463175239

05/30/2020    12:00 PM
ITEM SOLD: 2
Low prices you and trust   Every Day.

05/30/2020    12:00 PM`,
  
  textLines: [
    { text: 'Walmart', boundingBox: [150, 20, 100, 20], confidence: 0.95 },
    { text: 'Store #123', boundingBox: [130, 45, 120, 18], confidence: 0.90 },
    { text: '970-728-1838  MGR: JIM JONES', boundingBox: [50, 70, 300, 18], confidence: 0.85 },
    { text: '1166 GRAND AVE', boundingBox: [100, 95, 200, 18], confidence: 0.85 },
    { text: 'STERLING, CO 80751', boundingBox: [80, 120, 240, 18], confidence: 0.85 },
    { text: '', boundingBox: [0, 145, 400, 18], confidence: 0.0 },
    { text: 'ITEM 5564-99900999 STO  TM 14322', boundingBox: [20, 170, 360, 18], confidence: 0.80 },
    { text: 'HUNT 61 CHELE            $18.99', boundingBox: [20, 195, 360, 18], confidence: 0.85 },
    { text: 'HARMONY LAV REMOTE       $189.99', boundingBox: [20, 220, 360, 18], confidence: 0.85 },
    { text: '', boundingBox: [0, 245, 400, 18], confidence: 0.0 },
    { text: 'SUBTOTAL    $208.98', boundingBox: [20, 270, 360, 18], confidence: 0.90 },
    { text: 'TAX         $13.37', boundingBox: [20, 295, 360, 18], confidence: 0.90 },
    { text: 'TOTAL       $222.35', boundingBox: [20, 320, 360, 18], confidence: 0.95 },
    { text: '', boundingBox: [0, 345, 400, 18], confidence: 0.0 },
    { text: 'ACCOUNT #  **** **** **** VISA', boundingBox: [20, 370, 360, 18], confidence: 0.85 },
    { text: 'CHANGE                   $0.00', boundingBox: [20, 395, 360, 18], confidence: 0.85 },
  ],
  
  confidence: 0.85,
  detected_language: 'en',
  processing_time: 500,
  success: true
};

/**
 * Test case: Finnish Receipt with VAT breakdown (baseline test)
 */
const FINNISH_RECEIPT_OCR: OCRResult = {
  text: `K-Market
Kauppakatu 123
00100 Helsinki

Maito 1,5%                 2.50€
ALV 14%                    0.31€
Leipä                      1.80€  
ALV 14%                    0.22€

Välisumma                  4.30€
ALV yhteensä               0.53€
Yhteensä                   4.83€

Maksu: Kortti
Kiitos!`,
  
  textLines: [
    { text: 'K-Market', boundingBox: [150, 20, 100, 20], confidence: 0.95 },
    { text: 'Kauppakatu 123', boundingBox: [120, 45, 160, 18], confidence: 0.90 },
    { text: '00100 Helsinki', boundingBox: [130, 70, 140, 18], confidence: 0.85 },
    { text: '', boundingBox: [0, 95, 400, 18], confidence: 0.0 },
    { text: 'Maito 1,5%                 2.50€', boundingBox: [20, 120, 360, 18], confidence: 0.85 },
    { text: 'ALV 14%                    0.31€', boundingBox: [20, 145, 360, 18], confidence: 0.85 },
    { text: 'Leipä                      1.80€', boundingBox: [20, 170, 360, 18], confidence: 0.85 },
    { text: 'ALV 14%                    0.22€', boundingBox: [20, 195, 360, 18], confidence: 0.85 },
    { text: '', boundingBox: [0, 220, 400, 18], confidence: 0.0 },
    { text: 'Välisumma                  4.30€', boundingBox: [20, 245, 360, 18], confidence: 0.90 },
    { text: 'ALV yhteensä               0.53€', boundingBox: [20, 270, 360, 18], confidence: 0.90 },
    { text: 'Yhteensä                   4.83€', boundingBox: [20, 295, 360, 18], confidence: 0.95 },
    { text: '', boundingBox: [0, 320, 400, 18], confidence: 0.0 },
    { text: 'Maksu: Kortti', boundingBox: [20, 345, 200, 18], confidence: 0.85 },
    { text: 'Kiitos!', boundingBox: [20, 370, 100, 18], confidence: 0.85 },
  ],
  
  confidence: 0.87,
  detected_language: 'fi',
  processing_time: 450,
  success: true
};

/**
 * Run Evidence-Based Fusion tests
 */
export async function runEvidenceFusionTests(): Promise<void> {
  console.log('🧪 Starting Evidence-Based Fusion Tests...\n');
  
  const extractor = new EnhancedReceiptExtractionService({
    enableDebugLogging: true,
    minEvidenceConfidence: 0.3,
    enabledSources: ['table', 'text', 'summary_calculation', 'spatial_analysis', 'calculation']
  });

  // Test 1: Walmart Receipt (the challenging case)
  console.log('📋 Test 1: Walmart US Receipt (Challenging Case)');
  console.log('=' .repeat(50));
  
  try {
    const walmartResult = await extractor.extract(WALMART_RECEIPT_OCR, 'en');
    
    console.log('Results:');
    console.log(`  Merchant: ${walmartResult.merchant_name}`);
    console.log(`  Subtotal: $${walmartResult.subtotal}`);
    console.log(`  Tax: $${walmartResult.tax_total}`);
    console.log(`  Total: $${walmartResult.total}`);
    console.log(`  Tax Breakdowns: ${walmartResult.tax_breakdown.length}`);
    console.log(`  Confidence: ${(walmartResult.confidence * 100).toFixed(1)}%`);
    console.log(`  Status: ${walmartResult.status}`);
    
    if (walmartResult.tax_breakdown.length > 0) {
      console.log('  Tax Breakdown Details:');
      walmartResult.tax_breakdown.forEach((breakdown, index) => {
        console.log(`    ${index + 1}. ${breakdown.rate}% = $${breakdown.amount}`);
      });
    }
    
    if (walmartResult.metadata?.evidence_summary) {
      console.log(`  Evidence Sources: ${walmartResult.metadata.evidence_summary.sourcesUsed?.join(', ')}`);
      console.log(`  Evidence Pieces: ${walmartResult.metadata.evidence_summary.totalEvidencePieces}`);
    }
    
    // Validation
    console.log('\nValidation:');
    const expectedSubtotal = 208.98;
    const expectedTax = 13.37;
    const expectedTotal = 222.35;
    
    const subtotalMatch = Math.abs((walmartResult.subtotal || 0) - expectedSubtotal) < 0.01;
    const taxMatch = Math.abs((walmartResult.tax_total || 0) - expectedTax) < 0.01;
    const totalMatch = Math.abs((walmartResult.total || 0) - expectedTotal) < 0.01;
    
    console.log(`  ✅ Subtotal: ${subtotalMatch ? 'PASS' : 'FAIL'} (expected: $${expectedSubtotal}, got: $${walmartResult.subtotal})`);
    console.log(`  ✅ Tax: ${taxMatch ? 'PASS' : 'FAIL'} (expected: $${expectedTax}, got: $${walmartResult.tax_total})`);
    console.log(`  ✅ Total: ${totalMatch ? 'PASS' : 'FAIL'} (expected: $${expectedTotal}, got: $${walmartResult.total})`);
    
    const overallSuccess = subtotalMatch && taxMatch && totalMatch;
    console.log(`  🎯 Overall: ${overallSuccess ? '✅ SUCCESS' : '❌ FAILED'}`);
    
  } catch (error) {
    console.error('❌ Test 1 failed with error:', error);
  }
  
  console.log('\n' + '=' .repeat(50) + '\n');

  // Test 2: Finnish Receipt (baseline test)
  console.log('📋 Test 2: Finnish Receipt with VAT (Baseline Test)');
  console.log('=' .repeat(50));
  
  try {
    const finnishResult = await extractor.extract(FINNISH_RECEIPT_OCR, 'fi');
    
    console.log('Results:');
    console.log(`  Merchant: ${finnishResult.merchant_name}`);
    console.log(`  Subtotal: €${finnishResult.subtotal}`);
    console.log(`  Tax: €${finnishResult.tax_total}`);
    console.log(`  Total: €${finnishResult.total}`);
    console.log(`  Tax Breakdowns: ${finnishResult.tax_breakdown.length}`);
    console.log(`  Confidence: ${(finnishResult.confidence * 100).toFixed(1)}%`);
    console.log(`  Status: ${finnishResult.status}`);
    
    if (finnishResult.tax_breakdown.length > 0) {
      console.log('  Tax Breakdown Details:');
      finnishResult.tax_breakdown.forEach((breakdown, index) => {
        console.log(`    ${index + 1}. ${breakdown.rate}% = €${breakdown.amount}`);
      });
    }
    
    // Validation
    console.log('\nValidation:');
    const expectedSubtotalFi = 4.30;
    const expectedTaxFi = 0.53;
    const expectedTotalFi = 4.83;
    
    const subtotalMatchFi = Math.abs((finnishResult.subtotal || 0) - expectedSubtotalFi) < 0.01;
    const taxMatchFi = Math.abs((finnishResult.tax_total || 0) - expectedTaxFi) < 0.01;
    const totalMatchFi = Math.abs((finnishResult.total || 0) - expectedTotalFi) < 0.01;
    
    console.log(`  ✅ Subtotal: ${subtotalMatchFi ? 'PASS' : 'FAIL'} (expected: €${expectedSubtotalFi}, got: €${finnishResult.subtotal})`);
    console.log(`  ✅ Tax: ${taxMatchFi ? 'PASS' : 'FAIL'} (expected: €${expectedTaxFi}, got: €${finnishResult.tax_total})`);
    console.log(`  ✅ Total: ${totalMatchFi ? 'PASS' : 'FAIL'} (expected: €${expectedTotalFi}, got: €${finnishResult.total})`);
    
    const overallSuccessFi = subtotalMatchFi && taxMatchFi && totalMatchFi;
    console.log(`  🎯 Overall: ${overallSuccessFi ? '✅ SUCCESS' : '❌ FAILED'}`);
    
  } catch (error) {
    console.error('❌ Test 2 failed with error:', error);
  }
  
  console.log('\n' + '🧪 Evidence-Based Fusion Tests Complete!' + '\n');
}

// Export for external testing
export { WALMART_RECEIPT_OCR, FINNISH_RECEIPT_OCR };

// Run tests if called directly
if (require.main === module) {
  runEvidenceFusionTests().catch(console.error);
}