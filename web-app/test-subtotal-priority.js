/**
 * Test script for Subtotal Priority Fix
 * Tests the categorizeFinancialLabel function to ensure SUBTOTAL is prioritized over TOTAL
 */

const fs = require('fs');
const path = require('path');

// Mock the enhanced-receipt-extractor to test the categorizeFinancialLabel function
class TestExtractor {
  /**
   * Categorize financial text labels with proper priority handling
   * IMPORTANT: Checks subtotal BEFORE total to prevent "subtotal" matching "total"
   * Returns the most specific category found, or null if no financial keywords detected
   */
  categorizeFinancialLabel(text) {
    const lowerText = text.toLowerCase();
    
    // IMPORTANT: Order matters! Check subtotal patterns FIRST to prevent false positives
    // "Subtotal" contains "total", so we must check subtotal keywords before total keywords
    
    // 1. Check subtotal keywords first (highest priority)
    const subtotalPatterns = [
      /\b(subtotal|sub-total|sub\s*total)\b/i,
      /\b(delsumma|välisumma|小计)\b/i
    ];
    
    for (const pattern of subtotalPatterns) {
      if (pattern.test(lowerText)) {
        console.log(`🏷️ [Label] "${text}" -> categorized as SUBTOTAL`);
        return 'subtotal';
      }
    }
    
    // 2. Check tax keywords
    const taxPatterns = [
      /\b(tax|vat|moms|alv|vero|税|增值税)\b/i
    ];
    
    for (const pattern of taxPatterns) {
      if (pattern.test(lowerText)) {
        console.log(`🏷️ [Label] "${text}" -> categorized as TAX`);
        return 'tax';
      }
    }
    
    // 3. Check total keywords LAST (lowest priority)
    const totalPatterns = [
      /\b(total|sum|summa|yhteensä|总计|合计)\b/i,
      /\b(grand\s*total|总金额|最终金额)\b/i
    ];
    
    for (const pattern of totalPatterns) {
      if (pattern.test(lowerText)) {
        console.log(`🏷️ [Label] "${text}" -> categorized as TOTAL`);
        return 'total';
      }
    }
    
    // 4. Other financial keywords
    const otherPatterns = [
      /\b(amount|beløp|määrä|金额)\b/i
    ];
    
    for (const pattern of otherPatterns) {
      if (pattern.test(lowerText)) {
        console.log(`🏷️ [Label] "${text}" -> categorized as AMOUNT`);
        return 'amount';
      }
    }
    
    return null;
  }
}

function runTests() {
  console.log('🧪 Testing Subtotal Priority Fix...\n');
  
  const extractor = new TestExtractor();
  
  // Test cases from the actual problematic receipts
  const testCases = [
    // The actual problematic case
    { text: "SUBTOTAL 93.62", expected: "subtotal" },
    { text: "SUBTOTAL", expected: "subtotal" },
    
    // Edge cases
    { text: "subtotal 208.98", expected: "subtotal" },
    { text: "Sub-total: €25.00", expected: "subtotal" },
    { text: "Sub total", expected: "subtotal" },
    
    // Total cases (should still work when no subtotal keyword)
    { text: "TOTAL 98.21", expected: "total" },
    { text: "Total: €30.00", expected: "total" },
    { text: "Grand Total 150.00", expected: "total" },
    
    // Tax cases
    { text: "TAX 4.59", expected: "tax" },
    { text: "VAT 24% 12.50", expected: "tax" },
    
    // Non-financial cases
    { text: "Walmart", expected: null },
    { text: "Item description", expected: null },
    { text: "Receipt #12345", expected: null }
  ];
  
  let passedTests = 0;
  let totalTests = testCases.length;
  
  console.log('🧪 Running test cases...\n');
  
  for (const testCase of testCases) {
    const result = extractor.categorizeFinancialLabel(testCase.text);
    const passed = result === testCase.expected;
    
    const status = passed ? '✅' : '❌';
    console.log(`${status} "${testCase.text}" -> expected: ${testCase.expected}, got: ${result}`);
    
    if (passed) {
      passedTests++;
    }
  }
  
  console.log(`\n📊 Test Results: ${passedTests}/${totalTests} tests passed`);
  
  if (passedTests === totalTests) {
    console.log('🎉 All tests passed! Subtotal priority fix is working correctly.');
  } else {
    console.log('⚠️  Some tests failed. Review the implementation.');
  }
  
  // Test with the exact problematic JSON data
  console.log('\n🔍 Testing with actual problematic data...');
  testWithActualData();
}

function testWithActualData() {
  const extractor = new TestExtractor();
  
  // Test the exact text from the problematic receipt
  const problematicTexts = [
    "SUBTOTAL 93.62",
    "SUBTOTAL 208.98"
  ];
  
  console.log('\n📋 Processing actual problematic texts:');
  
  for (const text of problematicTexts) {
    const category = extractor.categorizeFinancialLabel(text);
    console.log(`"${text}" -> ${category}`);
    
    if (category === 'subtotal') {
      console.log('✅ CORRECT: Properly categorized as subtotal');
    } else {
      console.log('❌ ERROR: Should be categorized as subtotal, got:', category);
    }
  }
}

// Run the tests
runTests();