/**
 * Test script to verify proposed fixes for line grouping algorithm
 */

// Current algorithm (buggy)
function currentAlgorithm(textLines) {
  const sortedLines = [...textLines].sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);
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
      if (currentGroup.length > 0) groupedLines.push(mergeGroup(currentGroup));
      currentGroup = [line];
      currentY = lineY;
    }
  }
  if (currentGroup.length > 0) groupedLines.push(mergeGroup(currentGroup));
  return groupedLines;
}

// Option 1: Y Range-based grouping
function option1YRange(textLines) {
  const sortedLines = [...textLines].sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);
  const groupedLines = [];
  let currentGroup = [];
  let groupMinY = null;
  let groupMaxY = null;

  for (const line of sortedLines) {
    const lineY = line.boundingBox[1];
    const lineHeight = line.boundingBox[3];
    const lineBottomY = lineY + lineHeight;
    const tolerance = Math.max(5, Math.min(lineHeight * 0.5, 10));

    const belongsToGroup = groupMinY === null || (
      lineY <= groupMaxY + tolerance &&
      lineBottomY >= groupMinY - tolerance
    );

    if (belongsToGroup) {
      currentGroup.push(line);
      groupMinY = groupMinY === null ? lineY : Math.min(groupMinY, lineY);
      groupMaxY = groupMaxY === null ? lineBottomY : Math.max(groupMaxY, lineBottomY);
    } else {
      if (currentGroup.length > 0) groupedLines.push(mergeGroup(currentGroup));
      currentGroup = [line];
      groupMinY = lineY;
      groupMaxY = lineBottomY;
    }
  }
  if (currentGroup.length > 0) groupedLines.push(mergeGroup(currentGroup));
  return groupedLines;
}

// Option 2: Strict anchor with tighter threshold
function option2StrictAnchor(textLines) {
  const sortedLines = [...textLines].sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);
  const groupedLines = [];
  let currentGroup = [];
  let anchorY = null;

  for (const line of sortedLines) {
    const lineY = line.boundingBox[1];
    const lineHeight = line.boundingBox[3];
    const yTolerance = Math.max(5, Math.min(lineHeight * 0.4, 12));
    const yDifference = anchorY !== null ? Math.abs(lineY - anchorY) : 0;
    const shouldGroup = anchorY === null || yDifference <= yTolerance;

    if (shouldGroup) {
      currentGroup.push(line);
      // Don't average - keep anchor fixed
    } else {
      if (currentGroup.length > 0) groupedLines.push(mergeGroup(currentGroup));
      currentGroup = [line];
      anchorY = lineY;
    }
  }
  if (currentGroup.length > 0) groupedLines.push(mergeGroup(currentGroup));
  return groupedLines;
}

// Option 3: Gap-based detection
function option3GapBased(textLines) {
  const sortedLines = [...textLines].sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);
  if (sortedLines.length === 0) return [];

  const groupedLines = [];
  let currentGroup = [sortedLines[0]];

  for (let i = 1; i < sortedLines.length; i++) {
    const prevLine = sortedLines[i - 1];
    const currLine = sortedLines[i];
    const prevBottom = prevLine.boundingBox[1] + prevLine.boundingBox[3];
    const currY = currLine.boundingBox[1];
    const gap = currY - prevBottom;
    const avgHeight = (prevLine.boundingBox[3] + currLine.boundingBox[3]) / 2;

    if (gap > avgHeight * 0.2) {
      groupedLines.push(mergeGroup(currentGroup));
      currentGroup = [currLine];
    } else {
      currentGroup.push(currLine);
    }
  }
  if (currentGroup.length > 0) groupedLines.push(mergeGroup(currentGroup));
  return groupedLines;
}

function mergeGroup(group) {
  if (group.length === 1) return group[0];
  const sorted = group.sort((a, b) => a.boundingBox[0] - b.boundingBox[0]);
  return {
    text: sorted.map(l => l.text.trim()).join(' '),
    boundingBox: [
      Math.min(...sorted.map(l => l.boundingBox[0])),
      Math.min(...sorted.map(l => l.boundingBox[1])),
      Math.max(...sorted.map(l => l.boundingBox[0] + l.boundingBox[2])) - Math.min(...sorted.map(l => l.boundingBox[0])),
      Math.max(...sorted.map(l => l.boundingBox[1] + l.boundingBox[3])) - Math.min(...sorted.map(l => l.boundingBox[1]))
    ],
    merged: true
  };
}

// Test cases that simulate realistic OCR output
const testCases = [
  {
    name: "Swedish MOMS Table - Header + Data Row (realistic OCR drift)",
    description: "Header words drift from y=775 to y=790, data row at y=795",
    expectedLines: 2,
    words: [
      // Header row - words with Y drift (simulating real OCR behavior)
      { text: 'MOMS', boundingBox: [34, 775, 40, 15] },
      { text: 'MOMS', boundingBox: [80, 777, 40, 15] },
      { text: 'EXKL', boundingBox: [130, 779, 35, 15] },
      { text: '.', boundingBox: [168, 780, 5, 15] },
      { text: 'MOMS', boundingBox: [180, 782, 40, 15] },
      { text: 'INKL', boundingBox: [230, 784, 35, 15] },
      { text: '.', boundingBox: [268, 786, 5, 15] },
      { text: 'MOMS', boundingBox: [280, 788, 40, 15] },
      // Data row - starts just below header
      { text: '25.00', boundingBox: [34, 795, 45, 15] },
      { text: '%', boundingBox: [82, 796, 15, 15] },
      { text: '4.40', boundingBox: [130, 797, 35, 15] },
      { text: '17.60', boundingBox: [180, 798, 45, 15] },
      { text: '22.00', boundingBox: [280, 799, 45, 15] },
    ]
  },
  {
    name: "Swedish MOMS Table - Extreme drift scenario",
    description: "Header words drift from y=775 to y=793, data row at y=795 (only 2px gap)",
    expectedLines: 2,
    words: [
      // Header row - extreme Y drift
      { text: 'MOMS', boundingBox: [34, 775, 40, 15] },
      { text: 'MOMS', boundingBox: [80, 778, 40, 15] },
      { text: 'EXKL', boundingBox: [130, 781, 35, 15] },
      { text: '.', boundingBox: [168, 784, 5, 15] },
      { text: 'MOMS', boundingBox: [180, 787, 40, 15] },
      { text: 'INKL', boundingBox: [230, 790, 35, 15] },
      { text: '.', boundingBox: [268, 793, 5, 15] },
      { text: 'MOMS', boundingBox: [280, 793, 40, 15] },
      // Data row - very close to last header word
      { text: '25.00', boundingBox: [34, 795, 45, 15] },
      { text: '%', boundingBox: [82, 795, 15, 15] },
      { text: '4.40', boundingBox: [130, 795, 35, 15] },
      { text: '17.60', boundingBox: [180, 795, 45, 15] },
      { text: '22.00', boundingBox: [280, 795, 45, 15] },
    ]
  },
  {
    name: "Normal receipt - well separated lines",
    description: "Lines with clear Y separation (20+px)",
    expectedLines: 3,
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
    name: "Finnish ALV table - tight spacing",
    description: "Finnish tax table with tight row spacing",
    expectedLines: 3,
    words: [
      // Row 1: ALV header
      { text: 'ALV', boundingBox: [20, 300, 30, 14] },
      { text: '14%', boundingBox: [55, 301, 30, 14] },
      { text: '1.22', boundingBox: [150, 302, 35, 14] },
      // Row 2: ALV 24%
      { text: 'ALV', boundingBox: [20, 318, 30, 14] },
      { text: '24%', boundingBox: [55, 319, 30, 14] },
      { text: '1.01', boundingBox: [150, 320, 35, 14] },
      // Row 3: Yhteensä
      { text: 'Yhteensä', boundingBox: [20, 338, 70, 16] },
      { text: '10.83', boundingBox: [150, 339, 45, 16] },
    ]
  }
];

console.log('=== LINE GROUPING FIX COMPARISON ===\n');

const algorithms = [
  { name: 'Current (buggy)', fn: currentAlgorithm },
  { name: 'Option 1: Y Range', fn: option1YRange },
  { name: 'Option 2: Strict Anchor', fn: option2StrictAnchor },
  { name: 'Option 3: Gap Based', fn: option3GapBased }
];

let results = {};
algorithms.forEach(alg => results[alg.name] = { pass: 0, fail: 0 });

testCases.forEach(tc => {
  console.log(`\n${'─'.repeat(70)}`);
  console.log(`TEST: ${tc.name}`);
  console.log(`Description: ${tc.description}`);
  console.log(`Expected: ${tc.expectedLines} lines`);
  console.log('─'.repeat(70));

  algorithms.forEach(alg => {
    const result = alg.fn(tc.words);
    const passed = result.length === tc.expectedLines;

    if (passed) {
      results[alg.name].pass++;
    } else {
      results[alg.name].fail++;
    }

    const icon = passed ? '✅' : '❌';
    console.log(`\n${icon} ${alg.name}: ${result.length} lines`);

    if (!passed) {
      result.forEach((line, i) => {
        console.log(`   ${i+1}. "${line.text.substring(0, 60)}${line.text.length > 60 ? '...' : ''}"`);
      });
    }
  });
});

console.log('\n\n' + '═'.repeat(70));
console.log('SUMMARY');
console.log('═'.repeat(70));

console.log('\n' + 'Algorithm'.padEnd(25) + 'Pass'.padEnd(8) + 'Fail'.padEnd(8) + 'Rate');
console.log('─'.repeat(50));

algorithms.forEach(alg => {
  const total = results[alg.name].pass + results[alg.name].fail;
  const rate = ((results[alg.name].pass / total) * 100).toFixed(0) + '%';
  console.log(
    alg.name.padEnd(25) +
    String(results[alg.name].pass).padEnd(8) +
    String(results[alg.name].fail).padEnd(8) +
    rate
  );
});

console.log('\n' + '═'.repeat(70));
console.log('RECOMMENDATION');
console.log('═'.repeat(70));

const bestAlg = algorithms.reduce((best, curr) =>
  results[curr.name].pass > results[best.name].pass ? curr : best
);

console.log(`\nBest performing algorithm: ${bestAlg.name}`);
console.log(`Pass rate: ${results[bestAlg.name].pass}/${testCases.length}`);
