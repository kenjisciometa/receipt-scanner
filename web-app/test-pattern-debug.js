const { MultilingualPatternGenerator } = require('./src/services/patterns/multilingual-pattern-generator.ts');
const { LanguageKeywords } = require('./src/services/keywords/language-keywords.ts');

console.log('=== TESTING PATTERN GENERATION ===');

// Test the subtotal pattern
try {
  const subtotalPattern = MultilingualPatternGenerator.generateFieldPattern('subtotal', 'en');
  console.log('SUBTOTAL Pattern:', subtotalPattern);
  
  const testText = "SUBTOTAL $ 208.98";
  const subtotalMatch = testText.match(subtotalPattern);
  console.log('SUBTOTAL Pattern match on "SUBTOTAL $ 208.98":', subtotalMatch ? subtotalMatch[0] : 'NO MATCH');
} catch (e) {
  console.error('Error with subtotal pattern:', e.message);
}

// Test the total pattern
try {
  const totalPattern = MultilingualPatternGenerator.generateFieldPattern('total', 'en');
  console.log('\nTOTAL Pattern:', totalPattern);
  
  console.log('\nTesting TOTAL pattern on different strings:');
  const tests = [
    "SUBTOTAL $ 208.98",
    "TOTAL $ 222.35", 
    "SUB-TOTAL $ 208.98",
    "GRAND TOTAL $ 222.35"
  ];
  
  for (const test of tests) {
    const match = test.match(totalPattern);
    console.log(`  "${test}" -> ${match ? match[0] : 'NO MATCH'}`);
  }
} catch (e) {
  console.error('Error with total pattern:', e.message);
}

// Test keywords
console.log('\n=== KEYWORDS ===');
console.log('Subtotal keywords:', LanguageKeywords.getKeywords('subtotal', 'en'));
console.log('Total keywords:', LanguageKeywords.getKeywords('total', 'en'));