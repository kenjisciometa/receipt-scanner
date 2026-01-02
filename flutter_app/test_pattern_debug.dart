// Quick debug script to test pattern generation
// Run with: dart test_pattern_debug.dart

import 'lib/core/constants/language_keywords.dart';
import 'lib/core/constants/pattern_generator.dart';

void main() {
  print('Testing Subtotal pattern generation...\n');
  
  // Get keywords
  final subtotalKeywords = LanguageKeywords.getAllKeywords('subtotal');
  print('Subtotal keywords: $subtotalKeywords');
  print('Contains "subtotal": ${subtotalKeywords.contains('subtotal')}');
  print('Contains "sub-total": ${subtotalKeywords.contains('sub-total')}\n');
  
  // Generate patterns
  final patterns = PatternGenerator.generateAmountPatterns(
    category: 'subtotal',
  );
  
  print('Generated ${patterns.length} patterns:\n');
  for (int i = 0; i < patterns.length; i++) {
    print('Pattern ${i + 1}: ${patterns[i].pattern}');
  }
  
  // Test matching
  final testStrings = [
    'Subtotal: €12.58',
    'Subtotal €12.58',
    'subtotal: €12.58',
    'Sub-total: €12.58',
  ];
  
  print('\nTesting matches:');
  for (final testString in testStrings) {
    print('\nTesting: "$testString"');
    bool matched = false;
    for (int i = 0; i < patterns.length; i++) {
      final match = patterns[i].firstMatch(testString);
      if (match != null) {
        matched = true;
        print('  ✅ Pattern ${i + 1} matched!');
        print('    Group 1 (keyword): "${match.group(1)}"');
        print('    Group 2 (amount): "${match.group(2)}"');
        print('    Group count: ${match.groupCount}');
      }
    }
    if (!matched) {
      print('  ❌ No pattern matched');
    }
  }
}

