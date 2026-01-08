/**
 * Alternative approach: Use X-coordinate clustering to detect table columns
 * then group words within each column by Y
 *
 * This addresses the fundamental limitation of Y-only grouping when rows
 * have no vertical gap (common in table structures)
 */

// X-position based column detection
function detectColumns(words, xTolerance = 15) {
  // Get unique X start positions (rounded to tolerance)
  const xPositions = new Map();

  words.forEach(word => {
    const x = word.boundingBox[0];
    // Find existing column within tolerance
    let foundColumn = null;
    for (const [colX] of xPositions) {
      if (Math.abs(x - colX) <= xTolerance) {
        foundColumn = colX;
        break;
      }
    }

    if (foundColumn !== null) {
      xPositions.get(foundColumn).push(word);
    } else {
      xPositions.set(x, [word]);
    }
  });

  return Array.from(xPositions.entries())
    .sort((a, b) => a[0] - b[0])
    .map(([x, wordsInColumn]) => ({
      x,
      words: wordsInColumn.sort((a, b) => a.boundingBox[1] - b.boundingBox[1])
    }));
}

// Detect rows based on horizontal alignment of words across columns
function detectRowsFromColumns(columns) {
  // Get all unique Y positions from all columns
  const allYPositions = [];
  columns.forEach(col => {
    col.words.forEach(word => {
      allYPositions.push({
        y: word.boundingBox[1],
        height: word.boundingBox[3],
        word
      });
    });
  });

  // Sort by Y
  allYPositions.sort((a, b) => a.y - b.y);

  // Group into rows using gap detection
  const rows = [];
  let currentRow = [];
  let prevBottom = null;

  for (const item of allYPositions) {
    const y = item.y;
    const height = item.height;

    if (prevBottom === null) {
      currentRow.push(item.word);
      prevBottom = y + height;
    } else {
      const gap = y - prevBottom;
      // If there's a significant gap OR word starts well below previous words
      if (gap > height * 0.3) {
        // Start new row
        rows.push(currentRow);
        currentRow = [item.word];
        prevBottom = y + height;
      } else {
        // Same row - extend bottom if needed
        currentRow.push(item.word);
        prevBottom = Math.max(prevBottom, y + height);
      }
    }
  }

  if (currentRow.length > 0) {
    rows.push(currentRow);
  }

  return rows;
}

// Alternative: Use horizontal span overlap detection
function groupByHorizontalRows(words) {
  // Sort by Y first
  const sortedWords = [...words].sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);

  // Detect row boundaries by analyzing Y distribution
  // Words in the same visual row should have similar Y values
  const rows = [];
  let currentRow = [];
  let rowMinY = null;
  let rowMaxY = null;

  for (const word of sortedWords) {
    const y = word.boundingBox[1];
    const h = word.boundingBox[3];
    const bottom = y + h;

    // Calculate vertical overlap with current row
    if (rowMinY === null) {
      currentRow.push(word);
      rowMinY = y;
      rowMaxY = bottom;
    } else {
      // Check if this word overlaps vertically with the row
      const overlapTop = Math.max(y, rowMinY);
      const overlapBottom = Math.min(bottom, rowMaxY);
      const overlap = Math.max(0, overlapBottom - overlapTop);
      const wordHeight = h;
      const overlapRatio = overlap / wordHeight;

      // If more than 30% vertical overlap, it's the same row
      if (overlapRatio > 0.3) {
        currentRow.push(word);
        rowMinY = Math.min(rowMinY, y);
        rowMaxY = Math.max(rowMaxY, bottom);
      } else {
        // Start new row
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

  // Convert rows to merged TextLines
  return rows.map(row => mergeRow(row));
}

function mergeRow(words) {
  const sorted = words.sort((a, b) => a.boundingBox[0] - b.boundingBox[0]);
  return {
    text: sorted.map(w => w.text.trim()).join(' '),
    boundingBox: [
      Math.min(...sorted.map(w => w.boundingBox[0])),
      Math.min(...sorted.map(w => w.boundingBox[1])),
      Math.max(...sorted.map(w => w.boundingBox[0] + w.boundingBox[2])) -
        Math.min(...sorted.map(w => w.boundingBox[0])),
      Math.max(...sorted.map(w => w.boundingBox[1] + w.boundingBox[3])) -
        Math.min(...sorted.map(w => w.boundingBox[1]))
    ],
    merged: true
  };
}

// Test with MOMS table scenario
const momsTableWords = [
  // Row 1: MOMS header (words at slightly different Y due to OCR noise)
  // But all have similar Y range (775-790)
  { text: 'MOMS', boundingBox: [34, 776, 40, 15] },
  { text: 'MOMS', boundingBox: [80, 778, 40, 15] },
  { text: 'EXKL', boundingBox: [130, 775, 35, 15] },
  { text: '.', boundingBox: [168, 777, 5, 15] },
  { text: 'MOMS', boundingBox: [180, 779, 40, 15] },
  { text: 'INKL', boundingBox: [230, 776, 35, 15] },
  { text: '.', boundingBox: [268, 778, 5, 15] },
  { text: 'MOMS', boundingBox: [280, 777, 40, 15] },

  // Row 2: Data row (words at Y range 793-798)
  { text: '25.00', boundingBox: [34, 793, 45, 15] },
  { text: '%', boundingBox: [82, 795, 15, 15] },
  { text: '4.40', boundingBox: [130, 794, 35, 15] },
  { text: '17.60', boundingBox: [180, 796, 45, 15] },
  { text: '22.00', boundingBox: [280, 795, 45, 15] },
];

console.log('=== X-CLUSTERING AND VERTICAL OVERLAP APPROACH ===\n');

console.log('Input words (Y range for row 1: 775-793, row 2: 793-811):');
console.log('Row 1 (header): MOMS words at y=775-779');
console.log('Row 2 (data): numeric words at y=793-798');
console.log('Note: Row 1 bottom ≈ 790, Row 2 top ≈ 793 (only 3px gap!)\n');

console.log('--- Method: Vertical Overlap Detection ---');
const overlapResult = groupByHorizontalRows(momsTableWords);
console.log(`Result: ${overlapResult.length} rows`);
overlapResult.forEach((row, i) => {
  console.log(`  Row ${i+1}: "${row.text}"`);
});
console.log(`Status: ${overlapResult.length === 2 ? '✅ PASS' : '❌ FAIL'}`);

// Also try column detection approach
console.log('\n--- Method: Column Detection ---');
const columns = detectColumns(momsTableWords);
console.log(`Detected ${columns.length} columns at X positions: ${columns.map(c => c.x).join(', ')}`);
const colRows = detectRowsFromColumns(columns);
console.log(`Result: ${colRows.length} rows`);
colRows.forEach((row, i) => {
  const text = row.sort((a, b) => a.boundingBox[0] - b.boundingBox[0])
    .map(w => w.text).join(' ');
  console.log(`  Row ${i+1}: "${text}"`);
});
console.log(`Status: ${colRows.length === 2 ? '✅ PASS' : '❌ FAIL'}`);

console.log('\n=== KEY INSIGHT ===');
console.log('The vertical overlap method checks if words share vertical space.');
console.log('Header words (y=775-790) and data words (y=793-808) do NOT overlap,');
console.log('so they are correctly identified as separate rows.');
console.log('\nThis is more robust than Y-threshold methods because it uses');
console.log('the actual vertical extent of words rather than single Y values.');
