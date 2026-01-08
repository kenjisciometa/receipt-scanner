# Line Grouping Algorithm Fix Proposal

## Problem Summary

The current `groupTextLinesByY` algorithm incorrectly merges separate rows in tax tables because:

1. **Y Coordinate Averaging**: `currentY = (currentY + lineY) / 2` causes the reference Y to drift
2. **Loose Threshold**: Max threshold of 20px is too permissive for closely-spaced table rows
3. **No Gap Detection**: The algorithm doesn't consider vertical gaps between rows

### Example of the Bug

Original receipt (two separate rows):
```
MOMS  MOMS  EXKL.MOMS  INKL.MOMS    <- Header row (y ≈ 775-790)
25.00%   4.40    17.60    22.00     <- Data row (y ≈ 790-808)
```

Incorrectly merged into one line:
```
"MOMS MOMS EXKL . MOMS INKL . MOMS 25.00 % 4.40 17.60 22.00"
```

## Root Cause Analysis

When OCR returns words with slight Y variations:
- Word 1: y=775
- Word 2: y=778 → currentY = 776.5
- Word 3: y=780 → currentY = 778.25
- ... (drift continues)
- Word 8: y=790 → currentY ≈ 783
- Data word at y=795 → yDiff = 12px, within 20px threshold → INCORRECTLY GROUPED

## Proposed Fix

### Option 1: Anchor-Based Grouping (Recommended)

Instead of averaging Y, use the **group's Y range** to determine membership:

```typescript
private groupTextLinesByY(textLines: TextLine[]): TextLine[] {
  const sortedLines = [...textLines].sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);
  const groupedLines: TextLine[] = [];
  let currentGroup: TextLine[] = [];
  let groupMinY: number | null = null;
  let groupMaxY: number | null = null;

  for (const line of sortedLines) {
    const lineY = line.boundingBox[1];
    const lineHeight = line.boundingBox[3];
    const lineBottomY = lineY + lineHeight;

    // Use tighter tolerance (50% of line height, max 10px)
    const tolerance = Math.max(5, Math.min(lineHeight * 0.5, 10));

    // Check if this word belongs to current group based on Y range overlap
    const belongsToGroup = groupMinY === null || (
      lineY <= groupMaxY! + tolerance &&
      lineBottomY >= groupMinY! - tolerance
    );

    if (belongsToGroup) {
      currentGroup.push(line);
      groupMinY = groupMinY === null ? lineY : Math.min(groupMinY, lineY);
      groupMaxY = groupMaxY === null ? lineBottomY : Math.max(groupMaxY, lineBottomY);
    } else {
      // Start new group
      if (currentGroup.length > 0) {
        groupedLines.push(this.mergeTextLinesInGroup(currentGroup));
      }
      currentGroup = [line];
      groupMinY = lineY;
      groupMaxY = lineBottomY;
    }
  }

  if (currentGroup.length > 0) {
    groupedLines.push(this.mergeTextLinesInGroup(currentGroup));
  }

  return groupedLines;
}
```

### Option 2: Strict Threshold with No Averaging

Keep anchor Y fixed (no averaging) with a stricter threshold:

```typescript
private groupTextLinesByY(textLines: TextLine[]): TextLine[] {
  const sortedLines = [...textLines].sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);
  const groupedLines: TextLine[] = [];
  let currentGroup: TextLine[] = [];
  let anchorY: number | null = null;

  for (const line of sortedLines) {
    const lineY = line.boundingBox[1];
    const lineHeight = line.boundingBox[3];

    // Stricter threshold: 40% of line height, max 12px (reduced from 20px)
    const yTolerance = Math.max(5, Math.min(lineHeight * 0.4, 12));

    const yDifference = anchorY !== null ? Math.abs(lineY - anchorY) : 0;
    const shouldGroup = anchorY === null || yDifference <= yTolerance;

    if (shouldGroup) {
      currentGroup.push(line);
      // Don't average - keep first word's Y as anchor
    } else {
      if (currentGroup.length > 0) {
        groupedLines.push(this.mergeTextLinesInGroup(currentGroup));
      }
      currentGroup = [line];
      anchorY = lineY; // New anchor
    }
  }

  if (currentGroup.length > 0) {
    groupedLines.push(this.mergeTextLinesInGroup(currentGroup));
  }

  return groupedLines;
}
```

### Option 3: Gap-Based Detection

Detect vertical gaps between words to determine line breaks:

```typescript
private groupTextLinesByY(textLines: TextLine[]): TextLine[] {
  const sortedLines = [...textLines].sort((a, b) => a.boundingBox[1] - b.boundingBox[1]);

  if (sortedLines.length === 0) return [];

  const groupedLines: TextLine[] = [];
  let currentGroup: TextLine[] = [sortedLines[0]];

  for (let i = 1; i < sortedLines.length; i++) {
    const prevLine = sortedLines[i - 1];
    const currLine = sortedLines[i];

    const prevY = prevLine.boundingBox[1];
    const prevHeight = prevLine.boundingBox[3];
    const currY = currLine.boundingBox[1];

    // Calculate gap between bottom of previous word and top of current word
    const gap = currY - (prevY + prevHeight);
    const avgHeight = (prevHeight + currLine.boundingBox[3]) / 2;

    // If gap is more than 20% of average height, it's a new line
    const isNewLine = gap > avgHeight * 0.2;

    if (isNewLine) {
      groupedLines.push(this.mergeTextLinesInGroup(currentGroup));
      currentGroup = [currLine];
    } else {
      currentGroup.push(currLine);
    }
  }

  if (currentGroup.length > 0) {
    groupedLines.push(this.mergeTextLinesInGroup(currentGroup));
  }

  return groupedLines;
}
```

## Recommendation

**Use Option 1 (Anchor-Based Grouping with Y Range)** because:

1. It's more robust to Y coordinate variations
2. It properly handles multi-word lines with slight Y drift
3. The tighter tolerance (10px max) prevents merging adjacent rows
4. Y range overlap is a more natural criterion for "same line" detection

## Files to Update

1. `src/services/extraction/enhanced-receipt-extractor.ts` - Main extraction service
2. `src/services/training/training-data-collector.ts` - Training data collection (same algorithm)

## Testing

After implementing the fix, verify with:

1. The Swedish receipt with MOMS table (should produce 4 separate tax rows)
2. Finnish receipts with ALV tax tables
3. Walmart receipts with multi-column financial summaries
