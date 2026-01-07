const testData = {
  textLines: [
    "Subtotal $ 5.47", 
    "Tax $ 0.24", 
    "$ 5.71", 
    "Total"
  ],
  text: "Subtotal $ 5.47 Tax $ 0.24 $ 5.71 Total",
  detected_language: "en",
  test_mode: "integrated"
};

async function testUniversalTax() {
  try {
    console.log('Testing universal tax extraction...');
    console.log('Input:', testData);
    
    const response = await fetch('http://localhost:3000/api/test-universal-tax', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(testData)
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    console.log('Success!');
    console.log('Response:', JSON.stringify(data, null, 2));
  } catch (error) {
    console.error('Error:', error.message);
  }
}

testUniversalTax();