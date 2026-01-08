// Test date extraction to identify UTC conversion issue

// Mock OCR result based on the image content
const mockOcrResult = {
  text: `Walmart 
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
  textLines: []
};

console.log('🧪 Testing Date Extraction Services');
console.log('Input date string: "05/30/2020 12:20 AM"');
console.log('Expected result: "2020-05-30"');
console.log('');

// Test basic JavaScript Date parsing
console.log('📅 Basic JavaScript Date Parsing:');
const testDate = new Date('05/30/2020 12:20 AM');
console.log('new Date("05/30/2020 12:20 AM"):', testDate);
console.log('toISOString():', testDate.toISOString());
console.log('toISOString().split("T")[0]:', testDate.toISOString().split('T')[0]);

// Local date formatting
const year = testDate.getFullYear();
const month = String(testDate.getMonth() + 1).padStart(2, '0');
const day = String(testDate.getDate()).padStart(2, '0');
const localDateStr = `${year}-${month}-${day}`;
console.log('Local date formatting:', localDateStr);
console.log('');

// Test different extractors
async function testExtractors() {
  console.log('🔍 Testing Different Extraction Services:');
  
  try {
    const { AdvancedReceiptExtractionService } = await import('./src/services/extraction/advanced-receipt-extractor.js');
    const advancedExtractor = new AdvancedReceiptExtractionService();
    const advancedResult = await advancedExtractor.extract(mockOcrResult, 'en');
    console.log('✓ Advanced Extractor:', {
      date: advancedResult.date,
      dateType: typeof advancedResult.date
    });
  } catch (error) {
    console.log('✗ Advanced Extractor Error:', error.message);
  }
  
  try {
    const { EnhancedReceiptExtractor } = await import('./src/services/extraction/enhanced-receipt-extractor.js');
    const enhancedExtractor = new EnhancedReceiptExtractor();
    const enhancedResult = await enhancedExtractor.extract(mockOcrResult, 'en');
    console.log('✓ Enhanced Extractor:', {
      date: enhancedResult.date,
      dateType: typeof enhancedResult.date,
      dateISO: enhancedResult.date instanceof Date ? enhancedResult.date.toISOString() : 'N/A'
    });
  } catch (error) {
    console.log('✗ Enhanced Extractor Error:', error.message);
  }
  
  try {
    const { ReceiptExtractionService } = await import('./src/services/extraction/receipt-extractor.js');
    const basicExtractor = new ReceiptExtractionService();
    const basicResult = await basicExtractor.extract(mockOcrResult, 'en');
    console.log('✓ Basic Extractor:', {
      date: basicResult.date,
      dateType: typeof basicResult.date
    });
  } catch (error) {
    console.log('✗ Basic Extractor Error:', error.message);
  }
}

testExtractors().catch(console.error);