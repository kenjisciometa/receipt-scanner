// Test API processing with debug information

const fs = require('fs');
const path = require('path');

// Create a simple test to understand what's happening in the API
async function testDateProcessing() {
  console.log('🔍 Testing Date Processing in API');
  console.log('================================');
  
  // Test the exact same text that's causing the issue
  const mockOcrResult = {
    text: `Walmart > <
Save money. Live better.
970-728-1838 Mgr JIM JAMES
1155 S CAMINO DEL RIO
DURANGO, CO 81303
ST# 5944 OP# 39934962 TE# 17 TR# 14322
HDMI 6FT CABLE $18.99
HARMONY UNV REMOTE $189.99
SUBTOTAL $208.98
TAX $13.37
TOTAL $222.35
TEND $222.35
ACCOUNT # **** **** **** VISA
APPROVAL # 716071
REF # 3332300535EC
TRANS ID - 6547341725EC7D3E
VALIDATION - 8311
PAYMENT SERVICE - E
TERMINAL # AE91DF99
05/30/2020 12:20 AM
# ITEMS SOLD 2`,
    detected_language: 'en',
    textLines: [
      { text: '05/30/2020 12:20 AM', confidence: 0.8 }
    ]
  };

  console.log('Input OCR text contains: "05/30/2020 12:20 AM"');
  console.log('Expected output: "2020-05-30"');
  console.log('');

  try {
    // Import the actual enhanced extractor
    console.log('📦 Loading EnhancedReceiptExtractionService...');
    
    // Test with require (TypeScript compilation)
    const extractorPath = path.join(__dirname, 'src/services/extraction/enhanced-receipt-extractor.js');
    
    // Since TypeScript files need to be compiled, let's check if the build exists
    if (!fs.existsSync(extractorPath)) {
      console.log('❌ TypeScript files not compiled to JavaScript');
      console.log('   This is likely why we are seeing outdated behavior');
      console.log('   The modified TypeScript code needs to be compiled/rebuilt');
      console.log('');
      console.log('🔧 Suggested fix:');
      console.log('   1. Run: npm run build');
      console.log('   2. Or restart the development server: npm run dev');
      return;
    }
    
    console.log('✅ Build files found, proceeding with test...');
    
    // Test the actual extraction
    const { EnhancedReceiptExtractionService } = require(extractorPath);
    const extractor = new EnhancedReceiptExtractionService({
      enableDebugLogging: true
    });
    
    const result = await extractor.extract(mockOcrResult, 'en');
    
    console.log('📊 Extraction Result:');
    console.log('  Date value:', result.date);
    console.log('  Date type:', typeof result.date);
    console.log('  Is correct (2020-05-30)?:', result.date === '2020-05-30' ? '✅' : '❌');
    
    if (result.date !== '2020-05-30') {
      console.log('  ❌ Issue still exists - investigating further...');
      
      // Test JSON serialization
      console.log('  Testing JSON serialization:');
      const stringified = JSON.stringify(result);
      const parsed = JSON.parse(stringified);
      console.log('    After JSON.stringify/parse:', parsed.date);
      console.log('    Still incorrect?:', parsed.date !== '2020-05-30' ? '❌' : '✅');
    }
    
  } catch (error) {
    console.error('❌ Error during test:', error.message);
    console.log('');
    console.log('🔧 This suggests the TypeScript changes haven\'t been compiled yet.');
    console.log('   Please run: npm run build or restart: npm run dev');
  }
}

testDateProcessing().catch(console.error);