/**
 * Test the tax parsing fixes with the problematic receipt data
 */
const fs = require('fs');
const path = require('path');

async function testTaxFix() {
  try {
    // Read the problematic receipt data
    const receiptPath = path.join(__dirname, 'data/training/raw/receipt_fi_2_1767784016158.json');
    const receiptData = JSON.parse(fs.readFileSync(receiptPath, 'utf8'));
    
    console.log('📋 Testing tax parsing fix...');
    console.log(`Receipt has ${receiptData.text_lines.length} text lines`);
    
    // Find the tax table header and data lines
    const headerLine = receiptData.text_lines.find(line => 
      line.text.toLowerCase().includes('alv') && line.text.toLowerCase().includes('brutto')
    );
    
    if (headerLine) {
      console.log(`✅ Found header at line ${headerLine.line_index}: "${headerLine.text}"`);
      
      // Find the tax data lines after the header
      const taxLines = receiptData.text_lines.filter(line => 
        line.line_index > headerLine.line_index && 
        line.line_index <= headerLine.line_index + 5 &&
        /^([A-Z])\s+(\d+)\s*%/.test(line.text.trim())
      );
      
      console.log(`🔍 Found ${taxLines.length} potential tax data lines:`);
      taxLines.forEach(line => {
        console.log(`  Line ${line.line_index}: "${line.text}"`);
        
        // Test our enhanced pattern matching
        const text = line.text.trim();
        const match = text.match(/^([A-Z])\s+(\d+)\s*%\s+([\d,\.]+)\s+([\d,\.]+)\s+([\d,\.]+)$/);
        if (match) {
          const [_, code, rate, gross, net, tax] = match;
          console.log(`    ✅ Pattern matched: ${code} ${rate}% | Gross: ${gross} | Net: ${net} | Tax: ${tax}`);
          
          // Test number parsing
          const parseGermanNumber = (str) => {
            let normalized = str.trim();
            const hasComma = normalized.includes(',');
            const hasPeriod = normalized.includes('.');
            
            if (hasComma && hasPeriod) {
              const lastCommaIndex = normalized.lastIndexOf(',');
              const lastPeriodIndex = normalized.lastIndexOf('.');
              
              if (lastCommaIndex > lastPeriodIndex) {
                normalized = normalized.replace(/\./g, '').replace(',', '.');
              } else {
                normalized = normalized.replace(/,/g, '');
              }
            } else if (hasComma && !hasPeriod) {
              normalized = normalized.replace(',', '.');
            }
            
            return parseFloat(normalized);
          };
          
          const grossNum = parseGermanNumber(gross);
          const netNum = parseGermanNumber(net);
          const taxNum = parseGermanNumber(tax);
          
          console.log(`    📊 Parsed numbers: Gross: ${grossNum} | Net: ${netNum} | Tax: ${taxNum}`);
          
          // Validate math
          const expectedTax = (netNum * parseInt(rate)) / 100;
          const expectedGross = netNum + taxNum;
          const taxError = Math.abs(taxNum - expectedTax);
          const grossError = Math.abs(grossNum - expectedGross);
          
          console.log(`    🧮 Validation: Tax error: ${taxError.toFixed(4)} | Gross error: ${grossError.toFixed(4)}`);
        } else {
          console.log(`    ❌ Pattern did not match`);
        }
      });
      
      // Check current extraction result
      if (receiptData.extraction_result) {
        console.log('\n📊 Current extraction result:');
        console.log(`Tax Total: ${receiptData.extraction_result.tax_total}`);
        console.log(`Tax Breakdown: ${JSON.stringify(receiptData.extraction_result.tax_breakdown, null, 2)}`);
      }
      
    } else {
      console.log('❌ Tax table header not found');
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

testTaxFix();