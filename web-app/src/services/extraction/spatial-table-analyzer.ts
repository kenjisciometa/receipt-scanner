/**
 * Spatial Table Analyzer
 * 
 * Phase 1 implementation: Spatial analysis and table structure recognition
 * Implements Stage 2 of the 3-stage tax table detection strategy
 */

import { BoundingBox, ProcessedTextLine } from '../../types';
import { TaxKeywordDetectionResult } from './enhanced-keyword-detector';

/**
 * Spatial element with enhanced positioning data
 */
export interface SpatialElement {
  text: string;
  boundingBox: BoundingBox;
  lineIndex: number;
  containsTaxKeyword: boolean;
  containsNumericValue: boolean;
  keywordTypes: string[];
  numericTypes: string[];
  confidence: number;
}

/**
 * Table structure detection result
 */
export interface TableStructure {
  type: 'horizontal_table' | 'vertical_list' | 'single_line' | 'mixed';
  boundingBox: BoundingBox;
  confidence: number;
  elements: SpatialElement[];
  gridInfo?: {
    rows: number;
    columns: number;
    cellBounds: BoundingBox[][];
    headerRow?: number;
    dataRows: number[];
  };
  metadata: {
    detectedLanguage?: string;
    primaryTaxKeyword?: string;
    structureScore: number;
    alignmentScore: number;
  };
}

/**
 * Alignment analysis result
 */
interface AlignmentAnalysis {
  horizontalGroups: SpatialElement[][];
  verticalGroups: SpatialElement[][];
  gridStructure?: {
    rows: SpatialElement[][];
    columns: SpatialElement[][];
  };
}

/**
 * Spatial table analyzer implementing Stage 2 of 3-stage detection
 */
export class SpatialTableAnalyzer {
  private readonly ALIGNMENT_TOLERANCE = 10; // pixels
  private readonly PROXIMITY_THRESHOLD = 50; // pixels for clustering
  private readonly MIN_TABLE_ELEMENTS = 3;

  /**
   * Main analysis method implementing Stage 2 of 3-stage strategy
   */
  analyzeStructure(
    keywordResults: TaxKeywordDetectionResult,
    textLines: ProcessedTextLine[]
  ): TableStructure[] {
    // Step 1: Convert to spatial elements
    const spatialElements = this.createSpatialElements(keywordResults, textLines);

    // Step 2: Spatial clustering based on proximity
    const clusters = this.performSpatialClustering(spatialElements);

    // Step 3: Analyze each cluster for table structures
    const structures: TableStructure[] = [];
    
    for (const cluster of clusters) {
      const structure = this.analyzeClusterStructure(cluster, keywordResults);
      if (structure) {
        structures.push(structure);
      }
    }

    // Step 4: Sort by confidence and filter weak candidates
    return structures
      .sort((a, b) => b.confidence - a.confidence)
      .filter(s => s.confidence > 0.5);
  }

  /**
   * Convert keyword detection results to spatial elements
   */
  private createSpatialElements(
    keywordResults: TaxKeywordDetectionResult,
    textLines: ProcessedTextLine[]
  ): SpatialElement[] {
    const elements: SpatialElement[] = [];

    for (let lineIndex = 0; lineIndex < textLines.length; lineIndex++) {
      const line = textLines[lineIndex];
      
      // Check for tax keywords in this line
      const lineKeywords = keywordResults.taxKeywords.filter(tk => tk.lineIndex === lineIndex);
      const lineNumbers = keywordResults.numericPatterns.filter(np => np.lineIndex === lineIndex);
      const lineStructural = keywordResults.structuralKeywords.filter(sk => sk.lineIndex === lineIndex);

      // Only include lines that have tax-relevant content
      const hasTaxContent = lineKeywords.length > 0 || 
                           lineNumbers.length > 0 || 
                           lineStructural.length > 0;

      if (hasTaxContent) {
        elements.push({
          text: line.text,
          boundingBox: line.boundingBox,
          lineIndex,
          containsTaxKeyword: lineKeywords.length > 0,
          containsNumericValue: lineNumbers.length > 0,
          keywordTypes: lineKeywords.map(lk => lk.type),
          numericTypes: lineNumbers.map(ln => ln.type),
          confidence: this.calculateElementConfidence(lineKeywords, lineNumbers, lineStructural)
        });
      }
    }

    return elements;
  }

  /**
   * Calculate confidence score for a spatial element
   */
  private calculateElementConfidence(
    keywords: TaxKeywordDetectionResult['taxKeywords'],
    numbers: TaxKeywordDetectionResult['numericPatterns'],
    structural: TaxKeywordDetectionResult['structuralKeywords']
  ): number {
    let confidence = 0.5; // base confidence

    // Boost for tax keywords
    if (keywords.length > 0) {
      const avgKeywordConf = keywords.reduce((sum, k) => sum + k.confidence, 0) / keywords.length;
      confidence += avgKeywordConf * 0.3;
    }

    // Boost for numeric patterns
    if (numbers.length > 0) {
      const avgNumericConf = numbers.reduce((sum, n) => sum + n.confidence, 0) / numbers.length;
      confidence += avgNumericConf * 0.2;
    }

    // Boost for structural elements
    if (structural.length > 0) {
      const avgStructuralConf = structural.reduce((sum, s) => sum + s.confidence, 0) / structural.length;
      confidence += avgStructuralConf * 0.2;
    }

    // Boost for combination of keywords and numbers
    if (keywords.length > 0 && numbers.length > 0) {
      confidence += 0.2;
    }

    return Math.min(0.98, confidence);
  }

  /**
   * Perform spatial clustering based on bounding box proximity
   */
  private performSpatialClustering(elements: SpatialElement[]): SpatialElement[][] {
    if (elements.length === 0) return [];

    const clusters: SpatialElement[][] = [];
    const visited = new Set<number>();

    for (let i = 0; i < elements.length; i++) {
      if (visited.has(i)) continue;

      const cluster = [elements[i]];
      visited.add(i);

      // Find nearby elements
      for (let j = i + 1; j < elements.length; j++) {
        if (visited.has(j)) continue;

        if (this.areElementsNearby(elements[i], elements[j])) {
          cluster.push(elements[j]);
          visited.add(j);
        }
      }

      // Expand cluster by checking transitivity
      let expanded = true;
      while (expanded) {
        expanded = false;
        for (let k = 0; k < elements.length; k++) {
          if (visited.has(k)) continue;

          const isNearCluster = cluster.some(clusterElement => 
            this.areElementsNearby(clusterElement, elements[k])
          );

          if (isNearCluster) {
            cluster.push(elements[k]);
            visited.add(k);
            expanded = true;
          }
        }
      }

      if (cluster.length >= this.MIN_TABLE_ELEMENTS) {
        clusters.push(cluster);
      }
    }

    return clusters;
  }

  /**
   * Check if two elements are spatially nearby
   */
  private areElementsNearby(element1: SpatialElement, element2: SpatialElement): boolean {
    const box1 = element1.boundingBox;
    const box2 = element2.boundingBox;

    // Calculate vertical and horizontal distances
    const verticalDistance = Math.abs(box1[1] - box2[1]); // Y-axis distance
    const horizontalOverlap = this.calculateHorizontalOverlap(box1, box2);

    // Elements are nearby if they're vertically close or horizontally aligned
    return verticalDistance <= this.PROXIMITY_THRESHOLD || 
           horizontalOverlap > 0.3; // 30% overlap
  }

  /**
   * Calculate horizontal overlap between two bounding boxes
   */
  private calculateHorizontalOverlap(box1: BoundingBox, box2: BoundingBox): number {
    const [x1, , w1] = box1;
    const [x2, , w2] = box2;
    
    const left1 = x1;
    const right1 = x1 + w1;
    const left2 = x2;
    const right2 = x2 + w2;

    const overlap = Math.max(0, Math.min(right1, right2) - Math.max(left1, left2));
    const minWidth = Math.min(w1, w2);
    
    return minWidth > 0 ? overlap / minWidth : 0;
  }

  /**
   * Analyze cluster structure and determine table type
   */
  private analyzeClusterStructure(
    cluster: SpatialElement[],
    keywordResults: TaxKeywordDetectionResult
  ): TableStructure | null {
    if (cluster.length < this.MIN_TABLE_ELEMENTS) return null;

    // Step 1: Alignment analysis
    const alignment = this.analyzeAlignment(cluster);

    // Step 2: Try different structure types
    const candidates = [
      this.tryHorizontalTable(cluster, alignment),
      this.tryVerticalList(cluster, alignment),
      this.trySingleLine(cluster),
      this.tryMixedStructure(cluster, alignment)
    ].filter(Boolean) as TableStructure[];

    // Step 3: Select best candidate
    if (candidates.length === 0) return null;

    const bestCandidate = candidates.reduce((best, current) => 
      current.confidence > best.confidence ? current : best
    );

    // Step 4: Add metadata
    bestCandidate.metadata = {
      detectedLanguage: this.inferLanguage(cluster, keywordResults),
      primaryTaxKeyword: this.findPrimaryTaxKeyword(cluster, keywordResults),
      structureScore: this.calculateStructureScore(bestCandidate),
      alignmentScore: this.calculateAlignmentScore(alignment)
    };

    return bestCandidate;
  }

  /**
   * Analyze spatial alignment patterns
   */
  private analyzeAlignment(cluster: SpatialElement[]): AlignmentAnalysis {
    const result: AlignmentAnalysis = {
      horizontalGroups: [],
      verticalGroups: []
    };

    // Group elements by horizontal alignment (similar Y coordinates)
    const yGroups = new Map<number, SpatialElement[]>();
    for (const element of cluster) {
      const yPos = element.boundingBox[1];
      let foundGroup = false;

      for (const [groupY, group] of yGroups) {
        if (Math.abs(groupY - yPos) <= this.ALIGNMENT_TOLERANCE) {
          group.push(element);
          foundGroup = true;
          break;
        }
      }

      if (!foundGroup) {
        yGroups.set(yPos, [element]);
      }
    }

    result.horizontalGroups = Array.from(yGroups.values())
      .filter(group => group.length > 1)
      .map(group => group.sort((a, b) => a.boundingBox[0] - b.boundingBox[0]));

    // Group elements by vertical alignment (similar X coordinates)
    const xGroups = new Map<number, SpatialElement[]>();
    for (const element of cluster) {
      const xPos = element.boundingBox[0];
      let foundGroup = false;

      for (const [groupX, group] of xGroups) {
        if (Math.abs(groupX - xPos) <= this.ALIGNMENT_TOLERANCE) {
          group.push(element);
          foundGroup = true;
          break;
        }
      }

      if (!foundGroup) {
        xGroups.set(xPos, [element]);
      }
    }

    result.verticalGroups = Array.from(xGroups.values())
      .filter(group => group.length > 1)
      .map(group => group.sort((a, b) => a.boundingBox[1] - b.boundingBox[1]));

    // Try to detect grid structure
    if (result.horizontalGroups.length >= 2 && result.verticalGroups.length >= 2) {
      result.gridStructure = {
        rows: result.horizontalGroups,
        columns: result.verticalGroups
      };
    }

    return result;
  }

  /**
   * Try to detect horizontal table structure (header row + data rows)
   */
  private tryHorizontalTable(cluster: SpatialElement[], alignment: AlignmentAnalysis): TableStructure | null {
    if (!alignment.gridStructure || alignment.horizontalGroups.length < 2) {
      return null;
    }

    const rows = alignment.horizontalGroups;
    const columns = alignment.verticalGroups;

    // Find header row (likely to contain structural keywords)
    let headerRowIndex = -1;
    let maxStructuralElements = 0;

    for (let i = 0; i < rows.length; i++) {
      const structuralCount = rows[i].filter(el => 
        el.containsTaxKeyword && !el.containsNumericValue
      ).length;
      
      if (structuralCount > maxStructuralElements) {
        maxStructuralElements = structuralCount;
        headerRowIndex = i;
      }
    }

    if (headerRowIndex === -1) return null;

    const dataRows = rows.filter((_, index) => index !== headerRowIndex);
    
    // Calculate confidence based on structure quality
    let confidence = 0.6;
    
    // Boost for consistent column count
    const avgColumnsPerRow = rows.reduce((sum, row) => sum + row.length, 0) / rows.length;
    const columnConsistency = rows.filter(row => 
      Math.abs(row.length - avgColumnsPerRow) <= 1
    ).length / rows.length;
    confidence += columnConsistency * 0.2;

    // Boost for header containing keywords
    if (maxStructuralElements >= 2) {
      confidence += 0.15;
    }

    // Calculate overall bounding box
    const allElements = cluster;
    const boundingBox = this.calculateOverallBoundingBox(allElements);

    return {
      type: 'horizontal_table',
      boundingBox,
      confidence,
      elements: allElements,
      gridInfo: {
        rows: rows.length,
        columns: columns.length,
        cellBounds: this.calculateCellBounds(rows, columns),
        headerRow: headerRowIndex,
        dataRows: dataRows.map((_, index) => index !== headerRowIndex ? index : -1).filter(i => i !== -1)
      },
      metadata: {
        structureScore: 0,
        alignmentScore: 0
      }
    };
  }

  /**
   * Try to detect vertical list structure (multiple tax lines)
   */
  private tryVerticalList(cluster: SpatialElement[], alignment: AlignmentAnalysis): TableStructure | null {
    // Check for multiple elements with tax keywords arranged vertically
    const taxElements = cluster.filter(el => el.containsTaxKeyword);
    
    if (taxElements.length < 2) return null;

    // Check vertical alignment
    const verticallyAligned = this.checkVerticalAlignment(taxElements);
    if (!verticallyAligned) return null;

    // Calculate confidence
    let confidence = 0.7;
    
    // Boost for consistent tax + numeric pattern
    const elementsWithNumbers = taxElements.filter(el => el.containsNumericValue);
    const numberRatio = elementsWithNumbers.length / taxElements.length;
    confidence += numberRatio * 0.2;

    // Boost for similar text patterns (e.g., "TAX 1", "TAX 2")
    const similarPatterns = this.detectSimilarPatterns(taxElements);
    if (similarPatterns) {
      confidence += 0.15;
    }

    const boundingBox = this.calculateOverallBoundingBox(cluster);

    return {
      type: 'vertical_list',
      boundingBox,
      confidence,
      elements: cluster,
      metadata: {
        structureScore: 0,
        alignmentScore: 0
      }
    };
  }

  /**
   * Try to detect single line tax structure
   */
  private trySingleLine(cluster: SpatialElement[]): TableStructure | null {
    if (cluster.length !== 1) return null;

    const element = cluster[0];
    
    // Must contain both tax keyword and numeric value
    if (!element.containsTaxKeyword || !element.containsNumericValue) return null;

    const confidence = Math.min(0.9, element.confidence);

    return {
      type: 'single_line',
      boundingBox: element.boundingBox,
      confidence,
      elements: cluster,
      metadata: {
        structureScore: 0,
        alignmentScore: 0
      }
    };
  }

  /**
   * Try to detect mixed structure (headers + multiple data patterns)
   */
  private tryMixedStructure(cluster: SpatialElement[], alignment: AlignmentAnalysis): TableStructure | null {
    // Mixed structure: some horizontal alignment + some vertical patterns
    if (alignment.horizontalGroups.length === 0 && alignment.verticalGroups.length === 0) {
      return null;
    }

    let confidence = 0.5;
    
    // Boost for having both horizontal and vertical alignments
    if (alignment.horizontalGroups.length > 0 && alignment.verticalGroups.length > 0) {
      confidence += 0.2;
    }

    // Boost for variety in element types
    const hasKeywords = cluster.some(el => el.containsTaxKeyword);
    const hasNumbers = cluster.some(el => el.containsNumericValue);
    if (hasKeywords && hasNumbers) {
      confidence += 0.15;
    }

    const boundingBox = this.calculateOverallBoundingBox(cluster);

    return {
      type: 'mixed',
      boundingBox,
      confidence,
      elements: cluster,
      metadata: {
        structureScore: 0,
        alignmentScore: 0
      }
    };
  }

  /**
   * Check if elements are vertically aligned
   */
  private checkVerticalAlignment(elements: SpatialElement[]): boolean {
    if (elements.length < 2) return true;

    const xPositions = elements.map(el => el.boundingBox[0]);
    const avgX = xPositions.reduce((sum, x) => sum + x, 0) / xPositions.length;
    
    return xPositions.every(x => Math.abs(x - avgX) <= this.ALIGNMENT_TOLERANCE);
  }

  /**
   * Detect similar text patterns in elements
   */
  private detectSimilarPatterns(elements: SpatialElement[]): boolean {
    if (elements.length < 2) return false;

    // Look for patterns like "TAX 1", "TAX 2" or "ALV 24%", "ALV 14%"
    const patterns = elements.map(el => {
      const text = el.text.toLowerCase();
      const words = text.split(/\s+/);
      return words.slice(0, 2).join(' '); // Take first two words
    });

    // Check if patterns share common prefixes
    const firstPattern = patterns[0];
    const commonPrefix = patterns.every(pattern => 
      pattern.startsWith(firstPattern.split(' ')[0]) // Same first word
    );

    return commonPrefix;
  }

  /**
   * Calculate overall bounding box for a group of elements
   */
  private calculateOverallBoundingBox(elements: SpatialElement[]): BoundingBox {
    if (elements.length === 0) return [0, 0, 0, 0];

    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

    for (const element of elements) {
      const [x, y, w, h] = element.boundingBox;
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x + w);
      maxY = Math.max(maxY, y + h);
    }

    return [minX, minY, maxX - minX, maxY - minY];
  }

  /**
   * Calculate cell bounds for grid structure
   */
  private calculateCellBounds(rows: SpatialElement[][], columns: SpatialElement[][]): BoundingBox[][] {
    const cellBounds: BoundingBox[][] = [];

    for (let r = 0; r < rows.length; r++) {
      cellBounds[r] = [];
      for (let c = 0; c < columns.length; c++) {
        // Find element at this row/column intersection
        const rowElements = rows[r];
        const colElements = columns[c];
        
        const intersection = rowElements.find(rowEl =>
          colElements.some(colEl => colEl.lineIndex === rowEl.lineIndex)
        );

        if (intersection) {
          cellBounds[r][c] = intersection.boundingBox;
        } else {
          // Estimate cell bounds based on row and column positions
          const rowY = rows[r][0]?.boundingBox[1] || 0;
          const colX = columns[c][0]?.boundingBox[0] || 0;
          cellBounds[r][c] = [colX, rowY, 50, 20]; // Default cell size
        }
      }
    }

    return cellBounds;
  }

  /**
   * Infer primary language from cluster elements
   */
  private inferLanguage(cluster: SpatialElement[], keywordResults: TaxKeywordDetectionResult): string {
    const languages = keywordResults.detectedLanguages;
    return languages.length > 0 ? languages[0].language : 'unknown';
  }

  /**
   * Find primary tax keyword in cluster
   */
  private findPrimaryTaxKeyword(cluster: SpatialElement[], keywordResults: TaxKeywordDetectionResult): string {
    const clusterLines = new Set(cluster.map(el => el.lineIndex));
    const relevantKeywords = keywordResults.taxKeywords.filter(tk => clusterLines.has(tk.lineIndex));
    
    if (relevantKeywords.length === 0) return 'unknown';
    
    // Return the highest confidence keyword
    const bestKeyword = relevantKeywords.reduce((best, current) =>
      current.confidence > best.confidence ? current : best
    );
    
    return bestKeyword.keyword;
  }

  /**
   * Calculate structure quality score
   */
  private calculateStructureScore(structure: TableStructure): number {
    let score = structure.confidence;
    
    if (structure.gridInfo) {
      // Boost for well-formed grids
      const { rows, columns } = structure.gridInfo;
      if (rows >= 2 && columns >= 2) {
        score += 0.1;
      }
    }

    return Math.min(0.98, score);
  }

  /**
   * Calculate alignment quality score
   */
  private calculateAlignmentScore(alignment: AlignmentAnalysis): number {
    let score = 0.5;

    // Boost for horizontal alignment
    if (alignment.horizontalGroups.length > 0) {
      score += 0.2;
    }

    // Boost for vertical alignment  
    if (alignment.verticalGroups.length > 0) {
      score += 0.2;
    }

    // Boost for grid structure
    if (alignment.gridStructure) {
      score += 0.1;
    }

    return Math.min(0.98, score);
  }
}