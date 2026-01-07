/**
 * Test the actual receipt processing API with EnhancedReceiptExtractionService
 */
const fs = require('fs');

async function testActualProcessingAPI() {
  try {
    // Create a test image file (or copy existing receipt image)
    const imagePath = 'uploads/88fbdcdc-7d78-4465-ae9b-84687dae62b2.png';
    
    if (!fs.existsSync(imagePath)) {
      console.log('❌ Test image not found, testing with mock data instead...');
      
      // Test directly with enhanced extraction service
      const receiptData = JSON.parse(fs.readFileSync('data/training/raw/receipt_de_4_1767786821495.json', 'utf8'));
      
      const response = await fetch('http://localhost:3000/api/test-enhanced-extraction', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          textLines: receiptData.text_lines,
          text: receiptData.text_lines.map(line => line.text).join('\n'),
          detected_language: 'de',
          confidence: 0.8
        })
      });
      
      const result = await response.json();
      console.log('📊 Enhanced Extraction Result:', JSON.stringify(result, null, 2));
      
      return;
    }
    
    console.log('📋 Testing actual processing API...');
    
    // Step 1: Upload the image (simulate file upload)
    const fileId = 'test-tax-fix-' + Date.now();
    const testImagePath = `uploads/${fileId}`;
    
    // Copy existing image for testing
    fs.copyFileSync(imagePath, testImagePath);
    
    // Step 2: Process the image
    const processResponse = await fetch('http://localhost:3000/api/process', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        file_id: fileId,
        language_hint: 'de',
        original_name: 'test-receipt.png'
      })
    });
    
    const processResult = await processResponse.json();
    console.log('📊 Process Result:', JSON.stringify(processResult.extraction_result, null, 2));
    
    // Check for tax breakdown
    if (processResult.success && processResult.extraction_result) {
      const taxBreakdown = processResult.extraction_result.tax_breakdown;
      console.log('\n🔍 Tax Analysis:');
      console.log(`Tax Total: ${processResult.extraction_result.tax_total}`);
      console.log(`Tax Breakdown: ${JSON.stringify(taxBreakdown, null, 2)}`);
      
      if (taxBreakdown && taxBreakdown.length > 1) {
        console.log('✅ Multiple tax rates detected!');
        taxBreakdown.forEach((tax, index) => {
          console.log(`  ${index + 1}. ${tax.rate}% = ${tax.amount}`);
        });
      } else if (taxBreakdown && taxBreakdown.length === 1) {
        console.log(`⚠️ Only one tax rate detected: ${taxBreakdown[0].rate}% = ${taxBreakdown[0].amount}`);
      } else {
        console.log('❌ No tax breakdown detected');
      }
    }
    
    // Cleanup
    if (fs.existsSync(testImagePath)) {
      fs.unlinkSync(testImagePath);
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

testActualProcessingAPI();