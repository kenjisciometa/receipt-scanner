/**
 * Debug script to investigate line grouping issue
 * Tests the groupTextLinesByY algorithm with the Swedish receipt
 */

// Simulate the groupTextLinesByY algorithm
function groupTextLinesByY(textLines) {
  // Sort by Y coordinate first
  const sortedLines = [...textLines].sort((a, b) => {
    const aY = a.boundingBox[1]; // Y coordinate
    const bY = b.boundingBox[1];
    return aY - bY;
  });

  const groupedLines = [];
  let currentGroup = [];
  let currentY = null;
  let groupDecisions = []; // Track decisions for debugging

  for (const line of sortedLines) {
    const lineY = line.boundingBox[1];

    // Calculate adaptive threshold based on text height
    const lineHeight = line.boundingBox[3]; // Text height
    const adaptiveThreshold = lineHeight * 0.4; // 40% of text height
    const minThreshold = 5; // Minimum 5px
    const maxThreshold = 20; // Maximum 20px

    const yTolerance = Math.max(minThreshold, Math.min(adaptiveThreshold, maxThreshold));

    // Start new group or add to current group
    const yDifference = currentY !== null ? Math.abs(lineY - currentY) : 0;
    const shouldGroup = currentY === null || yDifference <= yTolerance;

    groupDecisions.push({
      text: line.text,
      lineY,
      lineHeight,
      adaptiveThreshold: adaptiveThreshold.toFixed(1),
      yTolerance: yTolerance.toFixed(1),
      currentY: currentY !== null ? currentY.toFixed(1) : 'null',
      yDifference: yDifference.toFixed(1),
      shouldGroup,
      decision: shouldGroup ? 'GROUP' : 'NEW_LINE'
    });

    if (shouldGroup) {
      currentGroup.push(line);
      currentY = currentY === null ? lineY : (currentY + lineY) / 2; // Average Y
    } else {
      // Finish current group and start new one
      if (currentGroup.length > 0) {
        groupedLines.push(mergeTextLinesInGroup(currentGroup));
      }
      currentGroup = [line];
      currentY = lineY;
    }
  }

  // Don't forget the last group
  if (currentGroup.length > 0) {
    groupedLines.push(mergeTextLinesInGroup(currentGroup));
  }

  return { groupedLines, groupDecisions };
}

function mergeTextLinesInGroup(group) {
  if (group.length === 1) {
    return group[0];
  }

  // Sort by X coordinate within the group
  const sortedGroup = group.sort((a, b) => {
    const aX = a.boundingBox[0]; // X coordinate
    const bX = b.boundingBox[0];
    return aX - bX;
  });

  // Merge text with space separation
  const mergedText = sortedGroup.map(line => line.text.trim()).filter(text => text.length > 0).join(' ');

  // Calculate consolidated bounding box
  const minX = Math.min(...sortedGroup.map(line => line.boundingBox[0]));
  const minY = Math.min(...sortedGroup.map(line => line.boundingBox[1]));
  const maxX = Math.max(...sortedGroup.map(line => line.boundingBox[0] + line.boundingBox[2]));
  const maxY = Math.max(...sortedGroup.map(line => line.boundingBox[1] + line.boundingBox[3]));

  return {
    text: mergedText,
    confidence: sortedGroup.reduce((sum, line) => sum + line.confidence, 0) / sortedGroup.length,
    boundingBox: [minX, minY, maxX - minX, maxY - minY],
    merged: true,
    originalTexts: group.map(g => g.text)
  };
}

// Load and analyze the receipt data
const fs = require('fs');
const path = require('path');

const jsonPath = path.join(__dirname, 'data/training/raw/receipt_sv_3_1767868753366.json');
const receiptData = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));

console.log('=== LINE GROUPING DEBUG ===\n');

// Find the problematic MOMS line
const momsLine = receiptData.text_lines.find(l => l.text.includes('MOMS MOMS EXKL'));
if (momsLine) {
  console.log('🔍 Found problematic merged line:');
  console.log(`   Text: "${momsLine.text}"`);
  console.log(`   BoundingBox: [${momsLine.boundingBox.join(', ')}]`);
  console.log(`   Height: ${momsLine.boundingBox[3]}px (normal is ~15-20px)`);
  console.log(`   Y position: ${momsLine.boundingBox[1]}px`);
  console.log();
}

// Look at adjacent lines for context
console.log('📊 Lines around the tax table (y > 700):');
const taxAreaLines = receiptData.text_lines
  .filter(l => l.boundingBox[1] > 700)
  .sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);

taxAreaLines.forEach((line, i) => {
  console.log(`   ${i+1}. y=${line.boundingBox[1]}, h=${line.boundingBox[3]}, text="${line.text}"`);
});

console.log('\n=== SIMULATING RAW OCR WORDS ===\n');

// Simulate what raw OCR words might look like for the MOMS area
// Based on Google Vision returning individual words
const simulatedRawOCRWords = [
  // Header row
  { text: 'MOMS', boundingBox: [34, 775, 40, 15], confidence: 0.8 },
  { text: 'MOMS', boundingBox: [80, 775, 40, 15], confidence: 0.8 },
  { text: 'EXKL', boundingBox: [130, 775, 35, 15], confidence: 0.8 },
  { text: '.', boundingBox: [168, 775, 5, 15], confidence: 0.8 },
  { text: 'MOMS', boundingBox: [180, 775, 40, 15], confidence: 0.8 },
  { text: 'INKL', boundingBox: [230, 775, 35, 15], confidence: 0.8 },
  { text: '.', boundingBox: [268, 775, 5, 15], confidence: 0.8 },
  { text: 'MOMS', boundingBox: [280, 775, 40, 15], confidence: 0.8 },

  // Data row - Y is ~795 (20px below header)
  { text: '25.00', boundingBox: [34, 795, 45, 15], confidence: 0.8 },
  { text: '%', boundingBox: [82, 795, 15, 15], confidence: 0.8 },
  { text: '4.40', boundingBox: [130, 795, 35, 15], confidence: 0.8 },
  { text: '17.60', boundingBox: [180, 795, 45, 15], confidence: 0.8 },
  { text: '22.00', boundingBox: [280, 795, 45, 15], confidence: 0.8 },
];

console.log('Simulated raw OCR words (header at y=775, data at y=795):');
simulatedRawOCRWords.forEach((w, i) => {
  console.log(`   ${i+1}. y=${w.boundingBox[1]}, h=${w.boundingBox[3]}, text="${w.text}"`);
});

console.log('\n=== RUNNING GROUPING ALGORITHM ===\n');

const { groupedLines, groupDecisions } = groupTextLinesByY(simulatedRawOCRWords);

console.log('Grouping decisions (in Y-sorted order):');
groupDecisions.forEach((d, i) => {
  const icon = d.shouldGroup ? '✅' : '🆕';
  console.log(`   ${icon} "${d.text}": y=${d.lineY}, currentY=${d.currentY}, diff=${d.yDifference}, threshold=${d.yTolerance} -> ${d.decision}`);
});

console.log('\n=== RESULT ===\n');

console.log('Grouped lines:');
groupedLines.forEach((line, i) => {
  console.log(`   ${i+1}. "${line.text}"`);
  if (line.originalTexts) {
    console.log(`      (merged from: ${line.originalTexts.map(t => `"${t}"`).join(', ')})`);
  }
});

console.log('\n=== PROBLEM ANALYSIS ===\n');

// The issue: Y coordinate averaging causes drift
console.log('The problem is Y coordinate averaging:');
console.log('- Header words are at y=775');
console.log('- After grouping first header word: currentY = 775');
console.log('- After each header word: currentY stays around 775');
console.log('- Data words are at y=795');
console.log('- Y difference = |795 - 775| = 20px');
console.log('- With lineHeight=15, threshold = min(15*0.4, 20) = 6px');
console.log('- BUT the maxThreshold is 20px!');
console.log('- So threshold becomes max(5, min(6, 20)) = 6px');
console.log('- 20px > 6px threshold -> should NOT group');
console.log();
console.log('However, if the original OCR has Y coordinates that are closer...');
console.log('Or if the averaging causes currentY to drift closer to the data row...');

// Test with closer Y coordinates (realistic scenario)
console.log('\n=== TEST WITH CLOSER Y COORDINATES ===\n');

const closerRawOCRWords = [
  // Header row at varying Y positions
  { text: 'MOMS', boundingBox: [34, 775, 40, 15], confidence: 0.8 },
  { text: 'MOMS', boundingBox: [80, 778, 40, 15], confidence: 0.8 },
  { text: 'EXKL', boundingBox: [130, 780, 35, 15], confidence: 0.8 },
  { text: '.', boundingBox: [168, 782, 5, 15], confidence: 0.8 },
  { text: 'MOMS', boundingBox: [180, 784, 40, 15], confidence: 0.8 },
  { text: 'INKL', boundingBox: [230, 786, 35, 15], confidence: 0.8 },
  { text: '.', boundingBox: [268, 788, 5, 15], confidence: 0.8 },
  { text: 'MOMS', boundingBox: [280, 790, 40, 15], confidence: 0.8 },

  // Data row
  { text: '25.00', boundingBox: [34, 795, 45, 15], confidence: 0.8 },
  { text: '%', boundingBox: [82, 795, 15, 15], confidence: 0.8 },
  { text: '4.40', boundingBox: [130, 795, 35, 15], confidence: 0.8 },
  { text: '17.60', boundingBox: [180, 795, 45, 15], confidence: 0.8 },
  { text: '22.00', boundingBox: [280, 795, 45, 15], confidence: 0.8 },
];

const result2 = groupTextLinesByY(closerRawOCRWords);

console.log('With header words at varying Y (775-790), data at 795:');
result2.groupDecisions.forEach((d, i) => {
  const icon = d.shouldGroup ? '✅' : '🆕';
  console.log(`   ${icon} "${d.text}": y=${d.lineY}, currentY=${d.currentY}, diff=${d.yDifference}, threshold=${d.yTolerance} -> ${d.decision}`);
});

console.log('\nGrouped lines:');
result2.groupedLines.forEach((line, i) => {
  console.log(`   ${i+1}. "${line.text}"`);
});

console.log('\n=== CONCLUSION ===\n');
console.log('The Y averaging algorithm causes currentY to drift towards the data row.');
console.log('When the last header word is at y=790 and currentY has drifted to ~782,');
console.log('the data row at y=795 has a yDiff of only ~13px, which is within maxThreshold (20px).');
console.log();
console.log('SOLUTION: Instead of averaging Y, use the median Y of the current group');
console.log('or implement separate handling for table-like structures.');
