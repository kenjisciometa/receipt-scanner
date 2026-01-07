/**
 * Test for Finnish Line Grouping Functionality
 * 
 * This test simulates the "Yhteensä 35,62" detection issue and verifies
 * that our Y-coordinate based line grouping works correctly.
 */

import { TextLine } from '../types/ocr';

// Mock the line grouping function (copied from enhanced-receipt-extractor.ts)
function groupTextLinesByY(textLines: TextLine[]): TextLine[] {
  // Sort by Y coordinate first
  const sortedLines = [...textLines].sort((a, b) => {
    const aY = a.boundingBox[1]; // Y coordinate
    const bY = b.boundingBox[1];
    return aY - bY;
  });

  const groupedLines: TextLine[] = [];
  const yTolerance = 15; // Pixels tolerance for same line detection

  let currentGroup: TextLine[] = [];
  let currentY: number | null = null;

  for (const line of sortedLines) {
    const lineY = line.boundingBox[1];
    
    // Start new group or add to current group
    if (currentY === null || Math.abs(lineY - currentY) <= yTolerance) {
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

  console.log(`🔗 [Line Grouping Test] Merged ${textLines.length} text elements into ${groupedLines.length} lines`);
  
  return groupedLines;
}

function mergeTextLinesInGroup(group: TextLine[]): TextLine {
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
  
  const consolidatedBoundingBox: [number, number, number, number] = [
    minX,
    minY, 
    maxX - minX, // width
    maxY - minY  // height
  ];

  // Average confidence
  const avgConfidence = sortedGroup.reduce((sum, line) => sum + line.confidence, 0) / sortedGroup.length;

  const merged: TextLine = {
    text: mergedText,
    confidence: avgConfidence,
    boundingBox: consolidatedBoundingBox
  };

  // Log successful merges for debugging
  if (group.length > 1) {
    console.log(`🔗 [Line Merge Test] "${group.map(g => g.text).join('" + "')}" → "${mergedText}"`);
  }

  return merged;
}

// Test data based on the actual Finnish receipt
function runFinnishLineGroupingTest() {
  console.log('🧪 [Test] Running Finnish Line Grouping Test');
  
  // Simulate the "Yhteensä" and "35,62" scenario from the real receipt
  const testLines: TextLine[] = [
    {
      text: "Yhteensä",
      confidence: 0.8,
      boundingBox: [49, 1278, 304, 65] // x:49, y:1278, w:304, h:65
    },
    {
      text: "35,62",
      confidence: 0.8, 
      boundingBox: [661, 1286, 190, 61] // x:661, y:1286, w:190, h:61 (Y diff: 8px)
    },
    {
      text: "Some other line",
      confidence: 0.8,
      boundingBox: [100, 1400, 200, 50] // Different Y coordinate
    }
  ];

  const groupedLines = groupTextLinesByY(testLines);

  console.log('📋 [Test Results]:');
  groupedLines.forEach((line, index) => {
    console.log(`  Line ${index + 1}: "${line.text}" (confidence: ${line.confidence.toFixed(2)})`);
  });

  // Verify the test
  const expectedMergedLine = groupedLines.find(line => line.text.includes('Yhteensä') && line.text.includes('35,62'));
  
  if (expectedMergedLine) {
    console.log('✅ [Test] SUCCESS: "Yhteensä" and "35,62" were correctly merged into:', expectedMergedLine.text);
    
    // Test pattern matching
    const finnishTotalPattern = /(?:yhteensä|summa|loppusumma|maksettava|total|sum|amount)\s+(\d+[.,]\d{2})/gi;
    const match = expectedMergedLine.text.match(finnishTotalPattern);
    
    if (match) {
      console.log('✅ [Test] PATTERN MATCH SUCCESS: Found total pattern:', match[0]);
    } else {
      console.log('❌ [Test] PATTERN MATCH FAILED: No total pattern found in:', expectedMergedLine.text);
    }
  } else {
    console.log('❌ [Test] FAILED: "Yhteensä" and "35,62" were not merged correctly');
  }

  return groupedLines;
}

// Export for potential use in actual testing
export { runFinnishLineGroupingTest };

// Run the test if this file is executed directly
if (typeof window === 'undefined') {
  runFinnishLineGroupingTest();
}