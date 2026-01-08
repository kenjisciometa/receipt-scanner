/**
 * Test script for unified multilingual pattern generation system
 */
const { MultilingualPatternGenerator, PatternUtils } = require('./src/services/patterns/multilingual-pattern-generator.ts');
const { CentralizedKeywordConfig } = require('./src/services/keywords/centralized-keyword-config.ts');

async function testMultilingualPatterns() {
  console.log('🧪 Testing Unified Multilingual Pattern Generation System\n');

  // Test 1: Basic pattern generation for different languages
  console.log('📋 Test 1: Basic Pattern Generation');
  console.log('==========================================');

  const languages = ['en', 'de', 'fi', 'sv', 'fr', 'it', 'es'];
  const fieldTypes = ['total', 'subtotal', 'tax'];

  for (const language of languages) {
    console.log(`\n🌐 Language: ${language.toUpperCase()}`);
    
    try {
      for (const fieldType of fieldTypes) {
        const pattern = MultilingualPatternGenerator.generateFieldPattern(fieldType, language);
        console.log(`  ${fieldType}: ${pattern.source}`);
      }
    } catch (error) {
      console.error(`  ❌ Error for ${language}:`, error.message);
    }
  }

  // Test 2: Multi-language pattern generation
  console.log('\n📋 Test 2: Multi-Language Patterns');
  console.log('==========================================');

  try {
    const multiLangTotalPattern = MultilingualPatternGenerator.generateMultiLanguagePattern('total', languages);
    console.log('Multi-language TOTAL pattern:');
    console.log(multiLangTotalPattern.source);
    console.log();

    const multiLangTaxPattern = MultilingualPatternGenerator.generateMultiLanguagePattern('tax', languages);
    console.log('Multi-language TAX pattern:');
    console.log(multiLangTaxPattern.source);
    
  } catch (error) {
    console.error('❌ Multi-language pattern generation failed:', error.message);
  }

  // Test 3: Tax breakdown patterns
  console.log('\n📋 Test 3: Tax Breakdown Patterns');
  console.log('==========================================');

  for (const language of ['en', 'de', 'fi']) {
    console.log(`\n🌐 ${language.toUpperCase()} Tax Breakdown:`);
    
    try {
      const taxBreakdownPattern = MultilingualPatternGenerator.generateTaxBreakdownPattern(language);
      console.log(`  Pattern: ${taxBreakdownPattern.source}`);
    } catch (error) {
      console.error(`  ❌ Error: ${error.message}`);
    }
  }

  // Test 4: Table header patterns
  console.log('\n📋 Test 4: Table Header Patterns');
  console.log('==========================================');

  for (const language of ['en', 'de', 'fi']) {
    console.log(`\n🌐 ${language.toUpperCase()} Table Header:`);
    
    try {
      const headerPattern = MultilingualPatternGenerator.generateTableHeaderPattern(language);
      console.log(`  Pattern: ${headerPattern.source}`);
    } catch (error) {
      console.error(`  ❌ Error: ${error.message}`);
    }
  }

  // Test 5: Real text matching
  console.log('\n📋 Test 5: Real Text Matching');
  console.log('==========================================');

  const testTexts = {
    de: [
      'Summe : € 15,00',
      'Zwischensumme : € 12,50', 
      'UST % Netto € Steuer € Brutto €',
      '20 12,50 2,50 15,00'
    ],
    fi: [
      'Yhteensä 35,62',
      'Välisumma 31,11',
      'Alv 4,51'
    ],
    en: [
      'Total: $25.99',
      'Subtotal: $22.50',
      'Tax: $3.49',
      'VAT 10% $2.25'
    ]
  };

  for (const [language, texts] of Object.entries(testTexts)) {
    console.log(`\n🌐 Testing ${language.toUpperCase()} texts:`);
    
    try {
      const patterns = PatternUtils.generateAllExtractionPatterns(language);
      
      for (const text of texts) {
        console.log(`\n  Testing: "${text}"`);
        
        for (const [patternName, pattern] of Object.entries(patterns)) {
          const testResult = MultilingualPatternGenerator.testPattern(pattern, text);
          if (testResult.matches) {
            console.log(`    ✅ ${patternName}: ${JSON.stringify(testResult.results[0])}`);
          }
        }
      }
    } catch (error) {
      console.error(`  ❌ Pattern testing failed for ${language}:`, error.message);
    }
  }

  // Test 6: Centralized keyword configuration
  console.log('\n📋 Test 6: Centralized Keyword Configuration');
  console.log('==========================================');

  try {
    console.log('\nSupported field types:');
    const supportedTypes = CentralizedKeywordConfig.getSupportedFieldTypes();
    console.log(supportedTypes.join(', '));

    console.log('\nGerman tax keywords:');
    const germanTaxKeywords = CentralizedKeywordConfig.getKeywordTexts('tax', 'de');
    console.log(germanTaxKeywords.join(', '));

    console.log('\nGerman number format:');
    const germanNumberFormat = CentralizedKeywordConfig.getNumberFormat('de');
    console.log(JSON.stringify(germanNumberFormat, null, 2));

  } catch (error) {
    console.error('❌ Centralized config test failed:', error.message);
  }

  // Test 7: Pattern debugging
  console.log('\n📋 Test 7: Pattern Debugging');
  console.log('==========================================');

  try {
    const debugInfo = MultilingualPatternGenerator.debugPattern('total', 'de', {
      includeCurrency: true,
      flexibleSeparators: true
    });
    
    console.log('\nDebug info for German TOTAL pattern:');
    console.log(`Pattern: ${debugInfo.pattern.source}`);
    console.log(`Keywords: ${debugInfo.keywords.join(', ')}`);
    console.log(`Format config: ${JSON.stringify(debugInfo.formatConfig, null, 2)}`);
    
  } catch (error) {
    console.error('❌ Pattern debugging failed:', error.message);
  }

  console.log('\n🎉 Multilingual pattern generation tests completed!');
}

// Error handling wrapper
async function main() {
  try {
    await testMultilingualPatterns();
  } catch (error) {
    console.error('💥 Test suite failed:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run tests if this script is executed directly
if (require.main === module) {
  main();
}

module.exports = { testMultilingualPatterns };