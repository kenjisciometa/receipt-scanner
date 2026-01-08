/**
 * Test to debug tax extraction pipeline
 */
const fs = require('fs');

async function testExtractionPipeline() {
  try {
    const receiptData = JSON.parse(fs.readFileSync('data/training/raw/receipt_fi_2_1767784951246.json', 'utf8'));
    
    console.log('📋 Testing extraction pipeline...');
    
    // Test the extraction endpoint
    const response = await fetch('http://localhost:3000/api/test-extraction', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        testData: {
          textLines: receiptData.text_lines.slice(35, 40), // Tax table area
          text: receiptData.text_lines.slice(35, 40).map(line => line.text).join('\n'),
          detected_language: 'fi',
          confidence: 0.8
        }
      })
    });
    
    const result = await response.json();
    console.log('📊 Result:', JSON.stringify(result, null, 2));
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

// Wait a bit for server to be ready, then test
setTimeout(testExtractionPipeline, 2000);