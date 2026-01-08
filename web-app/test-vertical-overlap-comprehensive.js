/**
 * Comprehensive test for Vertical Overlap Detection algorithm
 */

function groupByVerticalOverlap(words) {
  const sortedWords = [...words].sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);
  const rows = [];
  let currentRow = [];
  let rowMinY = null;
  let rowMaxY = null;

  for (const word of sortedWords) {
    const y = word.boundingBox[1];
    const h = word.boundingBox[3];
    const bottom = y + h;

    if (rowMinY === null) {
      currentRow.push(word);
      rowMinY = y;
      rowMaxY = bottom;
    } else {
      // Calculate vertical overlap ratio
      const overlapTop = Math.max(y, rowMinY);
      const overlapBottom = Math.min(bottom, rowMaxY);
      const overlap = Math.max(0, overlapBottom - overlapTop);
      const overlapRatio = overlap / h;

      // If more than 30% vertical overlap, same row
      if (overlapRatio > 0.3) {
        currentRow.push(word);
        rowMinY = Math.min(rowMinY, y);
        rowMaxY = Math.max(rowMaxY, bottom);
      } else {
        rows.push(currentRow);
        currentRow = [word];
        rowMinY = y;
        rowMaxY = bottom;
      }
    }
  }

  if (currentRow.length > 0) {
    rows.push(currentRow);
  }

  return rows.map(row => {
    const sorted = row.sort((a, b) => a.boundingBox[0] - b.boundingBox[0]);
    return {
      text: sorted.map(w => w.text.trim()).join(' '),
      wordCount: sorted.length
    };
  });
}

// Current buggy algorithm for comparison
function currentAlgorithm(words) {
  const sortedLines = [...words].sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);
  const groupedLines = [];
  let currentGroup = [];
  let currentY = null;

  for (const line of sortedLines) {
    const lineY = line.boundingBox[1];
    const lineHeight = line.boundingBox[3];
    const yTolerance = Math.max(5, Math.min(lineHeight * 0.4, 20));
    const yDifference = currentY !== null ? Math.abs(lineY - currentY) : 0;
    const shouldGroup = currentY === null || yDifference <= yTolerance;

    if (shouldGroup) {
      currentGroup.push(line);
      currentY = currentY === null ? lineY : (currentY + lineY) / 2;
    } else {
      if (currentGroup.length > 0) {
        const sorted = currentGroup.sort((a, b) => a.boundingBox[0] - b.boundingBox[0]);
        groupedLines.push({ text: sorted.map(w => w.text).join(' '), wordCount: sorted.length });
      }
      currentGroup = [line];
      currentY = lineY;
    }
  }
  if (currentGroup.length > 0) {
    const sorted = currentGroup.sort((a, b) => a.boundingBox[0] - b.boundingBox[0]);
    groupedLines.push({ text: sorted.map(w => w.text).join(' '), wordCount: sorted.length });
  }
  return groupedLines;
}

const testCases = [
  {
    name: "Swedish MOMS Table",
    expected: 2,
    words: [
      { text: 'MOMS', boundingBox: [34, 776, 40, 15] },
      { text: 'MOMS', boundingBox: [80, 778, 40, 15] },
      { text: 'EXKL', boundingBox: [130, 775, 35, 15] },
      { text: '.', boundingBox: [168, 777, 5, 15] },
      { text: 'MOMS', boundingBox: [180, 779, 40, 15] },
      { text: 'INKL', boundingBox: [230, 776, 35, 15] },
      { text: '.', boundingBox: [268, 778, 5, 15] },
      { text: 'MOMS', boundingBox: [280, 777, 40, 15] },
      { text: '25.00', boundingBox: [34, 793, 45, 15] },
      { text: '%', boundingBox: [82, 795, 15, 15] },
      { text: '4.40', boundingBox: [130, 794, 35, 15] },
      { text: '17.60', boundingBox: [180, 796, 45, 15] },
      { text: '22.00', boundingBox: [280, 795, 45, 15] },
    ]
  },
  {
    name: "Extreme Y drift (header 775-793, data 795)",
    expected: 2,
    words: [
      { text: 'MOMS', boundingBox: [34, 775, 40, 15] },
      { text: 'MOMS', boundingBox: [80, 780, 40, 15] },
      { text: 'EXKL', boundingBox: [130, 785, 35, 15] },
      { text: 'MOMS', boundingBox: [180, 790, 40, 15] },
      { text: 'MOMS', boundingBox: [280, 793, 40, 15] },
      { text: '25.00', boundingBox: [34, 808, 45, 15] },
      { text: '4.40', boundingBox: [130, 809, 35, 15] },
      { text: '22.00', boundingBox: [280, 810, 45, 15] },
    ]
  },
  {
    name: "Normal separated lines (20px gap)",
    expected: 3,
    words: [
      { text: 'Item', boundingBox: [10, 100, 40, 15] },
      { text: 'name', boundingBox: [55, 101, 35, 15] },
      { text: '10.00', boundingBox: [200, 102, 45, 15] },
      { text: 'Tax', boundingBox: [10, 130, 30, 15] },
      { text: '1.00', boundingBox: [200, 131, 35, 15] },
      { text: 'Total', boundingBox: [10, 160, 45, 15] },
      { text: '11.00', boundingBox: [200, 161, 50, 15] },
    ]
  },
  {
    name: "Finnish ALV table (tight spacing)",
    expected: 3,
    words: [
      { text: 'ALV', boundingBox: [20, 300, 30, 14] },
      { text: '14%', boundingBox: [55, 301, 30, 14] },
      { text: '1.22', boundingBox: [150, 302, 35, 14] },
      { text: 'ALV', boundingBox: [20, 318, 30, 14] },
      { text: '24%', boundingBox: [55, 319, 30, 14] },
      { text: '1.01', boundingBox: [150, 320, 35, 14] },
      { text: 'Yhteensä', boundingBox: [20, 338, 70, 16] },
      { text: '10.83', boundingBox: [150, 339, 45, 16] },
    ]
  },
  {
    name: "Zero gap between rows (header ends at data start)",
    expected: 2,
    words: [
      { text: 'Header', boundingBox: [10, 100, 60, 15] }, // ends at 115
      { text: 'text', boundingBox: [80, 102, 40, 15] },
      { text: 'Data', boundingBox: [10, 115, 40, 15] }, // starts at 115 (no gap!)
      { text: 'value', boundingBox: [80, 116, 50, 15] },
    ]
  },
  {
    name: "Overlapping words in same line",
    expected: 1,
    words: [
      { text: 'One', boundingBox: [10, 100, 30, 20] },
      { text: 'Two', boundingBox: [50, 105, 30, 20] }, // Overlaps with first word
      { text: 'Three', boundingBox: [90, 102, 45, 20] },
    ]
  }
];

console.log('=== VERTICAL OVERLAP VS CURRENT ALGORITHM ===\n');

let currentPass = 0, overlapPass = 0;

testCases.forEach(tc => {
  console.log(`\n${'─'.repeat(60)}`);
  console.log(`TEST: ${tc.name}`);
  console.log(`Expected: ${tc.expected} lines`);
  console.log('─'.repeat(60));

  const currentResult = currentAlgorithm(tc.words);
  const overlapResult = groupByVerticalOverlap(tc.words);

  const currentOk = currentResult.length === tc.expected;
  const overlapOk = overlapResult.length === tc.expected;

  if (currentOk) currentPass++;
  if (overlapOk) overlapPass++;

  console.log(`\n${currentOk ? '✅' : '❌'} Current algorithm: ${currentResult.length} lines`);
  if (!currentOk) {
    currentResult.forEach((r, i) => console.log(`   ${i+1}. "${r.text.substring(0, 50)}..."`));
  }

  console.log(`${overlapOk ? '✅' : '❌'} Vertical Overlap: ${overlapResult.length} lines`);
  if (!overlapOk) {
    overlapResult.forEach((r, i) => console.log(`   ${i+1}. "${r.text.substring(0, 50)}..."`));
  }
});

console.log('\n\n' + '═'.repeat(60));
console.log('FINAL RESULTS');
console.log('═'.repeat(60));
console.log(`\nCurrent algorithm: ${currentPass}/${testCases.length} passed (${Math.round(currentPass/testCases.length*100)}%)`);
console.log(`Vertical Overlap:  ${overlapPass}/${testCases.length} passed (${Math.round(overlapPass/testCases.length*100)}%)`);

console.log('\n' + '═'.repeat(60));
console.log('CONCLUSION');
console.log('═'.repeat(60));
if (overlapPass > currentPass) {
  console.log('\n✅ Vertical Overlap algorithm is recommended.');
  console.log('   It correctly handles tight row spacing and Y drift.');
} else if (overlapPass === currentPass) {
  console.log('\n⚠️ Both algorithms have same pass rate.');
  console.log('   Consider edge cases specific to your receipts.');
} else {
  console.log('\n⚠️ Current algorithm still performs better.');
  console.log('   The issue may require different approach.');
}
