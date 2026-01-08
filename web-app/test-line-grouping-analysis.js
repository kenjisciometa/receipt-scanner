/**
 * Detailed analysis of line grouping algorithm problem
 *
 * Problem: "MOMS MOMS EXKL . MOMS INKL . MOMS" and "25.00 % 4.40 17.60 22.00"
 * are being merged into a single line when they should be separate rows.
 *
 * The merged line has height=33px, which is about 2x the normal single line height (15-20px).
 */

// Current algorithm (from enhanced-receipt-extractor.ts)
function currentGroupTextLinesByY(textLines) {
  const sortedLines = [...textLines].sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);
  const groupedLines = [];
  let currentGroup = [];
  let currentY = null;

  for (const line of sortedLines) {
    const lineY = line.boundingBox[1];
    const lineHeight = line.boundingBox[3];
    const adaptiveThreshold = lineHeight * 0.4;
    const yTolerance = Math.max(5, Math.min(adaptiveThreshold, 20)); // min 5px, max 20px

    const yDifference = currentY !== null ? Math.abs(lineY - currentY) : 0;
    const shouldGroup = currentY === null || yDifference <= yTolerance;

    if (shouldGroup) {
      currentGroup.push(line);
      currentY = currentY === null ? lineY : (currentY + lineY) / 2; // BUG: Y averaging causes drift
    } else {
      if (currentGroup.length > 0) {
        groupedLines.push(mergeGroup(currentGroup));
      }
      currentGroup = [line];
      currentY = lineY;
    }
  }

  if (currentGroup.length > 0) {
    groupedLines.push(mergeGroup(currentGroup));
  }

  return groupedLines;
}

// Proposed fix: Use first word's Y as anchor, no averaging
function fixedGroupTextLinesByY(textLines) {
  const sortedLines = [...textLines].sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);
  const groupedLines = [];
  let currentGroup = [];
  let anchorY = null; // Use anchor Y instead of average

  for (const line of sortedLines) {
    const lineY = line.boundingBox[1];
    const lineHeight = line.boundingBox[3];

    // Use half the line height as tolerance (more strict)
    const yTolerance = Math.max(5, Math.min(lineHeight * 0.5, 15)); // max 15px instead of 20px

    const yDifference = anchorY !== null ? Math.abs(lineY - anchorY) : 0;
    const shouldGroup = anchorY === null || yDifference <= yTolerance;

    if (shouldGroup) {
      currentGroup.push(line);
      // Keep the anchor Y fixed (no averaging)
    } else {
      if (currentGroup.length > 0) {
        groupedLines.push(mergeGroup(currentGroup));
      }
      currentGroup = [line];
      anchorY = lineY; // Set new anchor
    }
  }

  if (currentGroup.length > 0) {
    groupedLines.push(mergeGroup(currentGroup));
  }

  return groupedLines;
}

// Alternative fix: Use Y range overlap detection
function rangeBasedGroupTextLinesByY(textLines) {
  const sortedLines = [...textLines].sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);
  const groupedLines = [];
  let currentGroup = [];
  let groupMinY = null;
  let groupMaxY = null;

  for (const line of sortedLines) {
    const lineY = line.boundingBox[1];
    const lineHeight = line.boundingBox[3];
    const lineBottomY = lineY + lineHeight;

    // Check if this line's Y range overlaps with current group's Y range
    // Allow some tolerance (5px) for slight variations
    const tolerance = 5;
    const overlaps = groupMinY === null || (
      lineY < groupMaxY + tolerance && lineBottomY > groupMinY - tolerance
    );

    if (overlaps) {
      currentGroup.push(line);
      groupMinY = groupMinY === null ? lineY : Math.min(groupMinY, lineY);
      groupMaxY = groupMaxY === null ? lineBottomY : Math.max(groupMaxY, lineBottomY);
    } else {
      if (currentGroup.length > 0) {
        groupedLines.push(mergeGroup(currentGroup));
      }
      currentGroup = [line];
      groupMinY = lineY;
      groupMaxY = lineBottomY;
    }
  }

  if (currentGroup.length > 0) {
    groupedLines.push(mergeGroup(currentGroup));
  }

  return groupedLines;
}

function mergeGroup(group) {
  if (group.length === 1) return group[0];

  const sorted = group.sort((a, b) => a.boundingBox[0] - b.boundingBox[0]);
  const text = sorted.map(l => l.text.trim()).join(' ');
  const minX = Math.min(...sorted.map(l => l.boundingBox[0]));
  const minY = Math.min(...sorted.map(l => l.boundingBox[1]));
  const maxX = Math.max(...sorted.map(l => l.boundingBox[0] + l.boundingBox[2]));
  const maxY = Math.max(...sorted.map(l => l.boundingBox[1] + l.boundingBox[3]));

  return {
    text,
    boundingBox: [minX, minY, maxX - minX, maxY - minY],
    merged: true,
    wordCount: group.length
  };
}

// Test data - simulate raw OCR words for the tax table
// Based on analysis: words in rows can have slight Y variations
const testCases = [
  {
    name: "Ideal case (all words aligned)",
    words: [
      // Header row at y=775
      { text: 'MOMS', boundingBox: [34, 775, 40, 15] },
      { text: 'MOMS', boundingBox: [80, 775, 40, 15] },
      { text: 'EXKL', boundingBox: [130, 775, 35, 15] },
      { text: '.', boundingBox: [168, 775, 5, 15] },
      { text: 'MOMS', boundingBox: [180, 775, 40, 15] },
      { text: 'INKL', boundingBox: [230, 775, 35, 15] },
      { text: '.', boundingBox: [268, 775, 5, 15] },
      { text: 'MOMS', boundingBox: [280, 775, 40, 15] },
      // Data row at y=795
      { text: '25.00', boundingBox: [34, 795, 45, 15] },
      { text: '%', boundingBox: [82, 795, 15, 15] },
      { text: '4.40', boundingBox: [130, 795, 35, 15] },
      { text: '17.60', boundingBox: [180, 795, 45, 15] },
      { text: '22.00', boundingBox: [280, 795, 45, 15] },
    ]
  },
  {
    name: "Realistic case (slight Y drift in header row)",
    words: [
      // Header row with Y drift (775 -> 790)
      { text: 'MOMS', boundingBox: [34, 775, 40, 15] },
      { text: 'MOMS', boundingBox: [80, 778, 40, 15] },
      { text: 'EXKL', boundingBox: [130, 780, 35, 15] },
      { text: '.', boundingBox: [168, 782, 5, 15] },
      { text: 'MOMS', boundingBox: [180, 784, 40, 15] },
      { text: 'INKL', boundingBox: [230, 786, 35, 15] },
      { text: '.', boundingBox: [268, 788, 5, 15] },
      { text: 'MOMS', boundingBox: [280, 790, 40, 15] },
      // Data row at y=795 (only 5px below last header word)
      { text: '25.00', boundingBox: [34, 795, 45, 15] },
      { text: '%', boundingBox: [82, 795, 15, 15] },
      { text: '4.40', boundingBox: [130, 795, 35, 15] },
      { text: '17.60', boundingBox: [180, 795, 45, 15] },
      { text: '22.00', boundingBox: [280, 795, 45, 15] },
    ]
  },
  {
    name: "Worst case (Y values interleaved)",
    words: [
      // Header and data rows with interleaved Y values
      { text: 'MOMS', boundingBox: [34, 775, 40, 15] },
      { text: '25.00', boundingBox: [34, 778, 45, 15] }, // Data word with close Y
      { text: 'MOMS', boundingBox: [80, 780, 40, 15] },
      { text: '%', boundingBox: [82, 782, 15, 15] },
      { text: 'EXKL', boundingBox: [130, 784, 35, 15] },
      { text: '4.40', boundingBox: [130, 786, 35, 15] },
      { text: '.', boundingBox: [168, 788, 5, 15] },
      { text: 'MOMS', boundingBox: [180, 790, 40, 15] },
      { text: '17.60', boundingBox: [180, 792, 45, 15] },
      { text: 'INKL', boundingBox: [230, 794, 35, 15] },
      { text: '.', boundingBox: [268, 796, 5, 15] },
      { text: 'MOMS', boundingBox: [280, 798, 40, 15] },
      { text: '22.00', boundingBox: [280, 800, 45, 15] },
    ]
  }
];

console.log('=== LINE GROUPING ALGORITHM ANALYSIS ===\n');

testCases.forEach(testCase => {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`TEST: ${testCase.name}`);
  console.log('='.repeat(60));

  console.log('\n--- Current Algorithm (with Y averaging) ---');
  const currentResult = currentGroupTextLinesByY(testCase.words);
  currentResult.forEach((line, i) => {
    console.log(`  ${i+1}. "${line.text}"`);
  });
  console.log(`  Result: ${currentResult.length} lines (expected: 2)`);
  console.log(`  Status: ${currentResult.length === 2 ? '✅ PASS' : '❌ FAIL'}`);

  console.log('\n--- Fixed Algorithm (anchor Y, no averaging) ---');
  const fixedResult = fixedGroupTextLinesByY(testCase.words);
  fixedResult.forEach((line, i) => {
    console.log(`  ${i+1}. "${line.text}"`);
  });
  console.log(`  Result: ${fixedResult.length} lines (expected: 2)`);
  console.log(`  Status: ${fixedResult.length === 2 ? '✅ PASS' : '❌ FAIL'}`);

  console.log('\n--- Range-based Algorithm (Y overlap detection) ---');
  const rangeResult = rangeBasedGroupTextLinesByY(testCase.words);
  rangeResult.forEach((line, i) => {
    console.log(`  ${i+1}. "${line.text}"`);
  });
  console.log(`  Result: ${rangeResult.length} lines (expected: 2)`);
  console.log(`  Status: ${rangeResult.length === 2 ? '✅ PASS' : '❌ FAIL'}`);
});

console.log('\n\n=== ROOT CAUSE ANALYSIS ===\n');
console.log('The problem is in the current algorithm\'s Y averaging:');
console.log('');
console.log('  currentY = (currentY + lineY) / 2');
console.log('');
console.log('This causes the reference Y to drift towards each new word.');
console.log('When header row words have slight Y variations (common in OCR),');
console.log('the currentY drifts towards the data row, eventually making');
console.log('the data row words appear within the grouping threshold.');
console.log('');
console.log('RECOMMENDED FIX: Use anchor Y (first word\'s Y) without averaging,');
console.log('or use Y range overlap detection for more robust grouping.');
