/**
 * Test script for tax table parsing improvements
 */

// Test the problematic receipt data
const testReceiptData = {
  textLines: [
    {
      text: "Alv Brutto Netto Vero",
      line_index: 35,
      boundingBox: [77, 2288, 769, 39],
      features: { has_tax_keyword: true }
    },
    {
      text: "A 24 % 1,97 1,59 0,38",
      line_index: 36,
      boundingBox: [59, 2326, 786, 40],
      features: { has_percent: true, has_amount_like: true }
    },
    {
      text: "B 14 % 33,65 29.52 4.13",
      line_index: 37,
      boundingBox: [59, 2366, 784, 38],
      features: { has_percent: true, has_amount_like: true }
    }
  ]
};

// Test number parsing
function testNumberParsing() {
  console.log("🧪 Testing number parsing...");
  
  const testNumbers = [
    "1,97",    // German format - comma decimal
    "29.52",   // US format - period decimal  
    "33,65",   // German format - comma decimal
    "4.13",    // US format - period decimal
    "0,38",    // German format - comma decimal
    "1.234,56", // European format - period thousands, comma decimal
    "1,234.56"  // US format - comma thousands, period decimal
  ];
  
  testNumbers.forEach(num => {
    console.log(`Testing: "${num}"`);
    // This would call our parseGermanNumber function
    // For now, just show what each should parse to
    const expected = parseFloat(num.replace(',', '.'));
    console.log(`  Expected: ${expected}`);
  });
}

// Test pattern matching
function testPatternMatching() {
  console.log("🧪 Testing pattern matching...");
  
  const testLines = [
    "A 24 % 1,97 1,59 0,38",      // Standard format
    "B 14 % 33,65 29.52 4.13",   // Mixed number formats
    "A  24%  1,97  1,59  0,38",   // Extra spaces
    "Standard 24% 10,50 8,82 1,68", // Named rate
    "B Standard 14% 33,65 29.52 4.13" // Category with description
  ];
  
  const patterns = [
    /^([A-Z])\s+(\d+)\s*%\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/,
    /^([A-Z])\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/,
    /^(standard|reduced|normal|regular)\s+(\d+)\s*%\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/i,
    /^([A-Z])\s*(\d+)\s*%?\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/,
    /^([A-Z])\s+(?:standard|reduced|normal|regular)?\s*(\d+)\s*%\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/i
  ];
  
  testLines.forEach(line => {
    console.log(`Testing line: "${line}"`);
    let matched = false;
    patterns.forEach((pattern, index) => {
      if (pattern.test(line)) {
        console.log(`  ✅ Matched pattern ${index + 1}`);
        matched = true;
      }
    });
    if (!matched) {
      console.log(`  ❌ No pattern matched`);
    }
  });
}

// Run tests
console.log("🚀 Starting tax parsing tests...");
testNumberParsing();
testPatternMatching();

console.log("✅ Tests completed!");