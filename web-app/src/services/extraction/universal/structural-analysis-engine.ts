/**
 * Universal Structural Analysis Engine
 * 
 * Language and store-agnostic structural analysis for tax extraction.
 * Uses numerical patterns and spatial relationships instead of hardcoded rules.
 */

import { LanguageKeywords, SupportedLanguage } from '@/services/keywords/language-keywords';

export interface NumericalSignature {
  values: number[];
  types: ('percentage' | 'amount' | 'unknown')[];
  position: number;
  lineIndex: number;
  confidence: number;
  text: string;
  containsCurrency: boolean;
  containsPercentage: boolean;
}

export interface SpatialStructure {
  segments: DocumentSegment[];
  taxRelevantSections: TaxSection[];
  numericalFlow: NumericalFlow;
}

export interface DocumentSegment {
  startLine: number;
  endLine: number;
  type: 'header' | 'items' | 'summary' | 'footer';
  confidence: number;
  features: SegmentFeatures;
}

export interface TaxSection {
  startLine: number;
  endLine: number;
  type: 'structured' | 'scattered';
  taxEntries: TaxEntry[];
  subtotal?: number;
  total?: number;
  confidence: number;
  splitTotalInfo?: { amount: number; amountLineIndex: number; labelLineIndex: number };
}

export interface TaxEntry {
  rate?: number;
  amount: number;
  confidence: number;
  source: string;
  lineIndex: number;
}

export interface TaxCandidate {
  rate?: number;
  amount: number;
  relatedAmounts: number[];
  lineIndex: number;
  confidence: number;
  spatialContext: SpatialContext;
}

export interface NumericalFlow {
  sequence: NumericalSignature[];
  relationships: NumericalRelationship[];
  mathematicalConsistency: number;
}

export interface NumericalRelationship {
  source: NumericalSignature;
  target: NumericalSignature;
  relationship: 'addition' | 'multiplication' | 'subtotal' | 'tax_calculation';
  confidence: number;
}

export interface SegmentFeatures {
  averageLineLength: number;
  numericalDensity: number;
  percentageCount: number;
  currencySymbolCount: number;
  emptyLinesBefore: number;
  emptyLinesAfter: number;
}

export interface SpatialContext {
  precedingNumbers: number[];
  followingNumbers: number[];
  sameLineNumbers: number[];
  proximityScore: number;
}

/**
 * Universal Structural Analysis Engine
 * Analyzes receipt structure without language or store-specific hardcoding
 */
export class StructuralAnalysisEngine {
  
  constructor(
    private languageKeywords: LanguageKeywords,
    private debugMode: boolean = false
  ) {}

  /**
   * Analyze document structure and identify tax-relevant patterns
   */
  analyzeTaxStructure(textLines: string[], language: SupportedLanguage): SpatialStructure {
    if (this.debugMode) {
      console.log(`🔍 [Structural] Analyzing ${textLines.length} lines for language: ${language}`);
    }

    // Step 1: Extract numerical signatures
    const numericalSignatures = this.extractNumericalSignatures(textLines);
    
    // Step 2: Segment document structure
    const segments = this.segmentDocument(textLines, numericalSignatures);
    
    // Step 3: Identify tax-relevant sections
    const taxSections = this.identifyTaxSections(segments, numericalSignatures, language);
    
    // Step 4: Analyze numerical relationships
    const numericalFlow = this.analyzeNumericalFlow(numericalSignatures);

    const structure: SpatialStructure = {
      segments,
      taxRelevantSections: taxSections,
      numericalFlow
    };

    if (this.debugMode) {
      console.log(`✅ [Structural] Found ${taxSections.length} tax-relevant sections`);
      console.log(`📊 [Structural] Numerical relationships: ${numericalFlow.relationships.length}`);
    }

    return structure;
  }

  /**
   * Extract all numerical signatures from text without language-specific patterns
   */
  private extractNumericalSignatures(textLines: string[]): NumericalSignature[] {
    const signatures: NumericalSignature[] = [];
    
    textLines.forEach((line, lineIndex) => {
      const values: number[] = [];
      const types: ('percentage' | 'amount' | 'unknown')[] = [];
      
      // Extract percentages
      const percentagePattern = /(\d+(?:[.,]\d+)?)\s*%/g;
      let match;
      while ((match = percentagePattern.exec(line)) !== null) {
        const value = parseFloat(match[1].replace(',', '.'));
        if (value >= 0 && value <= 50) {
          values.push(value);
          types.push('percentage');
        }
      }

      // Extract currency amounts - broader pattern
      const amountPatterns = [
        /\$\s*(\d+(?:[.,]\d{1,3})*(?:[.,]\d{2})?)/, // $ 5.47
        /(\d+(?:[.,]\d{1,3})*(?:[.,]\d{2}))\s*\$/, // 5.47$
        /€\s*(\d+(?:[.,]\d{1,3})*(?:[.,]\d{2})?)/, // € 5.47
        /(\d+(?:[.,]\d{1,3})*(?:[.,]\d{2}))\s*€/, // 5.47€
        /\b(\d+[.,]\d{2})\b/ // Standalone decimals like 5.47
      ];

      for (const pattern of amountPatterns) {
        let match;
        let iterations = 0;
        const maxIterations = 20; // Prevent infinite loops
        
        while ((match = pattern.exec(line)) !== null && iterations < maxIterations) {
          iterations++;
          const rawValue = match[1];
          let value = this.parseAmount(rawValue);
          
          if (value > 0 && value < 100000) {
            values.push(value);
            types.push('amount');
          }
          
          // Break if pattern isn't global to avoid infinite loop
          if (!pattern.global) {
            break;
          }
        }
        
        // Reset pattern for next iteration
        pattern.lastIndex = 0;
      }

      if (values.length > 0) {
        signatures.push({
          values,
          types,
          position: 0,
          lineIndex,
          confidence: 0.8,
          text: line.trim(),
          containsCurrency: /[$€£¥]/.test(line),
          containsPercentage: /%/.test(line)
        });
      }
    });

    return signatures;
  }

  private parseAmount(rawValue: string): number {
    // Handle decimal separators properly
    if (rawValue.includes(',') && rawValue.includes('.')) {
      // Format like 1,234.56 - use last separator as decimal
      return parseFloat(rawValue.replace(/,/g, ''));
    } else if (rawValue.includes(',')) {
      // Could be thousands separator or decimal separator
      const parts = rawValue.split(',');
      if (parts.length === 2 && parts[1].length <= 3 && parts[1].length >= 1) {
        // Likely decimal separator: 12,34 or 12,3
        return parseFloat(rawValue.replace(',', '.'));
      } else {
        // Likely thousands separator: 1,234
        return parseFloat(rawValue.replace(',', ''));
      }
    } else {
      return parseFloat(rawValue);
    }
  }

  /**
   * Segment document into logical sections based on structural patterns
   */
  private segmentDocument(textLines: string[], signatures: NumericalSignature[]): DocumentSegment[] {
    const segments: DocumentSegment[] = [];
    let currentSegmentStart = 0;

    // Find segment boundaries based on content patterns
    const segmentBoundaries = this.findSegmentBoundaries(textLines, signatures);
    
    segmentBoundaries.forEach((boundary, index) => {
      const segmentLines = textLines.slice(currentSegmentStart, boundary);
      const features = this.calculateSegmentFeatures(segmentLines);
      const segmentType = this.classifySegmentType(segmentLines, features, index, segmentBoundaries.length);

      segments.push({
        startLine: currentSegmentStart,
        endLine: boundary - 1,
        type: segmentType,
        confidence: this.calculateSegmentConfidence(features, segmentType),
        features
      });

      currentSegmentStart = boundary;
    });

    return segments;
  }

  /**
   * Find segment boundaries using numerical density and empty line patterns
   */
  private findSegmentBoundaries(textLines: string[], signatures: NumericalSignature[]): number[] {
    const boundaries: number[] = [0];
    
    // Calculate numerical density per line
    const lineDensity = new Array(textLines.length).fill(0);
    signatures.forEach(sig => {
      lineDensity[sig.lineIndex]++;
    });

    // Find boundaries based on density changes and empty lines
    for (let i = 1; i < textLines.length; i++) {
      const isEmptyLine = textLines[i].trim().length === 0;
      const densityChange = Math.abs(lineDensity[i] - lineDensity[i - 1]) > 1;
      const contextChange = this.detectContextChange(textLines, i);

      if ((isEmptyLine && lineDensity[i + 1] > 0) || densityChange || contextChange) {
        boundaries.push(i);
      }
    }

    boundaries.push(textLines.length);
    return boundaries.filter((boundary, index) => 
      index === 0 || boundary > boundaries[index - 1] + 1 // Minimum segment size
    );
  }

  /**
   * Detect context changes using keyword patterns and structure
   */
  private detectContextChange(textLines: string[], lineIndex: number): boolean {
    if (lineIndex === 0 || lineIndex >= textLines.length - 1) return false;

    const currentLine = textLines[lineIndex].toLowerCase();
    const prevLine = textLines[lineIndex - 1].toLowerCase();

    // Common context change indicators (language-agnostic)
    const contextMarkers = [
      /total|sum|gesamt|yhteensä|totalt|somme/, // Total indicators
      /tax|vat|mwst|alv|moms|tva|imposto/,     // Tax indicators  
      /subtotal|netto|net|delsumma/,           // Subtotal indicators
      /^\s*[-=_]{3,}\s*$/,                     // Separator lines
      /item|artikel|tuote|vara|produit/        // Item section indicators
    ];

    return contextMarkers.some(pattern => 
      (pattern.test(currentLine) && !pattern.test(prevLine)) ||
      (!pattern.test(currentLine) && pattern.test(prevLine))
    );
  }

  /**
   * Calculate features for document segment classification
   */
  private calculateSegmentFeatures(segmentLines: string[]): SegmentFeatures {
    const totalChars = segmentLines.reduce((sum, line) => sum + line.length, 0);
    const averageLineLength = segmentLines.length > 0 ? totalChars / segmentLines.length : 0;
    
    const allText = segmentLines.join(' ');
    const percentageCount = (allText.match(/%/g) || []).length;
    const currencySymbolCount = (allText.match(/[$€£¥]/g) || []).length;
    const numberCount = (allText.match(/\d+[.,]\d{2}/g) || []).length;
    
    const numericalDensity = segmentLines.length > 0 ? numberCount / segmentLines.length : 0;

    return {
      averageLineLength,
      numericalDensity,
      percentageCount,
      currencySymbolCount,
      emptyLinesBefore: 0, // Will be set by caller if needed
      emptyLinesAfter: 0   // Will be set by caller if needed
    };
  }

  /**
   * Classify segment type based on features and position
   */
  private classifySegmentType(
    segmentLines: string[], 
    features: SegmentFeatures, 
    segmentIndex: number, 
    totalSegments: number
  ): DocumentSegment['type'] {
    
    // Header: First segment with low numerical density
    if (segmentIndex === 0 && features.numericalDensity < 0.5) {
      return 'header';
    }
    
    // Footer: Last segment with low numerical density
    if (segmentIndex === totalSegments - 1 && features.numericalDensity < 0.5) {
      return 'footer';
    }
    
    // Summary: High percentage + currency density
    if (features.percentageCount > 0 && features.currencySymbolCount > 0) {
      return 'summary';
    }
    
    // Items: Medium numerical density, longer lines
    if (features.numericalDensity > 0.3 && features.averageLineLength > 20) {
      return 'items';
    }
    
    return 'summary'; // Default for tax-relevant sections
  }

  /**
   * Identify tax-relevant sections within document segments
   */
  private identifyTaxSections(
    segments: DocumentSegment[],
    signatures: NumericalSignature[],
    language: SupportedLanguage
  ): TaxSection[] {
    const taxSections: TaxSection[] = [];

    // Analyze each segment for tax content
    for (const segment of segments) {
      if (segment.type === 'summary') {
        const taxSection = this.analyzeTaxSectionContent(segment, signatures, language);
        if (taxSection) {
          taxSections.push(taxSection);
        }
      }
    }

    // Also look for scattered tax information across document
    const scatteredTaxSection = this.identifyScatteredTaxInformation(signatures, language);
    if (scatteredTaxSection) {
      taxSections.push(scatteredTaxSection);
    }

    return taxSections;
  }

  private analyzeTaxSectionContent(
    segment: DocumentSegment,
    signatures: NumericalSignature[],
    language: SupportedLanguage
  ): TaxSection | null {
    // Implementation for structured tax sections
    return null; // Simplified for now
  }

  private identifyScatteredTaxInformation(
    signatures: NumericalSignature[],
    language: SupportedLanguage
  ): TaxSection | null {
    const totalKeywords = LanguageKeywords.getKeywords('total', language);
    const subtotalKeywords = LanguageKeywords.getKeywords('subtotal', language);
    const taxKeywords = LanguageKeywords.getKeywords('tax', language);
    const taxEntries: TaxEntry[] = [];
    let subtotal: number | undefined = undefined;
    let total: number | undefined = undefined;
    let totalSplitInfo: { amount: number; amountLineIndex: number; labelLineIndex: number } | undefined = undefined;

    // Find split total (amount and label on separate lines)
    const amountOnlySignatures = signatures.filter(sig => 
      sig.containsCurrency && 
      sig.values.length === 1 && 
      !this.hasRelevantKeywords(sig.text, language)
    );

    const labelOnlyLines = signatures.filter(sig => 
      !sig.containsCurrency && 
      totalKeywords.some(keyword => sig.text.toLowerCase().includes(keyword.toLowerCase()))
    );

    for (const amountSig of amountOnlySignatures) {
      for (const labelSig of labelOnlyLines) {
        const verticalDistance = Math.abs(labelSig.lineIndex - amountSig.lineIndex);
        if (verticalDistance <= 2) { // Allow up to 2 lines apart
          totalSplitInfo = {
            amount: amountSig.values[0],
            amountLineIndex: amountSig.lineIndex,
            labelLineIndex: labelSig.lineIndex
          };
          total = amountSig.values[0];
          break;
        }
      }
      if (total !== undefined) break;
    }

    // Find subtotal
    for (const sig of signatures) {
      if (subtotalKeywords.some(keyword => sig.text.toLowerCase().includes(keyword.toLowerCase()))) {
        if (sig.values.length > 0) {
          subtotal = sig.values[sig.values.length - 1]; // Take last value
        }
      }
    }

    // Find tax entries
    for (const sig of signatures) {
      if (taxKeywords.some(keyword => sig.text.toLowerCase().includes(keyword.toLowerCase()))) {
        if (sig.values.length > 0) {
          const taxAmount = sig.values[sig.values.length - 1]; // Take last value
          taxEntries.push({
            rate: undefined, // No rate specified
            amount: taxAmount,
            confidence: 0.8,
            source: 'simple_tax_line',
            lineIndex: sig.lineIndex
          });
        }
      }
    }

    // Validate mathematical consistency if we have all components
    if (subtotal !== undefined && total !== undefined && taxEntries.length > 0) {
      const calculatedTotal = subtotal + taxEntries.reduce((sum, entry) => sum + entry.amount, 0);
      const tolerance = 0.02;
      if (Math.abs(calculatedTotal - total) <= tolerance) {
        return {
          startLine: 0,
          endLine: signatures.length - 1,
          type: 'scattered',
          taxEntries,
          subtotal,
          total,
          confidence: 0.85,
          splitTotalInfo: totalSplitInfo
        };
      }
    }

    // Return tax section even without perfect math if we found tax
    if (taxEntries.length > 0) {
      return {
        startLine: 0,
        endLine: signatures.length - 1,
        type: 'scattered',
        taxEntries,
        subtotal,
        total,
        confidence: 0.7,
        splitTotalInfo: totalSplitInfo
      };
    }

    return null;
  }

  private hasRelevantKeywords(text: string, language: SupportedLanguage): boolean {
    const totalKeywords = LanguageKeywords.getKeywords('total', language);
    const subtotalKeywords = LanguageKeywords.getKeywords('subtotal', language);
    const taxKeywords = LanguageKeywords.getKeywords('tax', language);
    const lowerText = text.toLowerCase();
    
    const allKeywords = [
      ...totalKeywords,
      ...subtotalKeywords,
      ...taxKeywords
    ];

    return allKeywords.some((keyword: string) => lowerText.includes(keyword.toLowerCase()));
  }




  /**
   * Analyze numerical flow and relationships
   */
  private analyzeNumericalFlow(signatures: NumericalSignature[]): NumericalFlow {
    const relationships: NumericalRelationship[] = [];
    
    // Extract all amount values from signatures
    const allAmounts: { value: number; lineIndex: number; sig: NumericalSignature }[] = [];
    signatures.forEach(sig => {
      sig.values.forEach((value, idx) => {
        if (sig.types[idx] === 'amount') {
          allAmounts.push({ value, lineIndex: sig.lineIndex, sig });
        }
      });
    });

    // Find mathematical relationships
    for (let i = 0; i < allAmounts.length; i++) {
      for (let j = i + 1; j < allAmounts.length; j++) {
        const relationship = this.detectNumericalRelationship(
          allAmounts[i].sig, allAmounts[j].sig, allAmounts.map(a => a.sig)
        );
        if (relationship) {
          relationships.push(relationship);
        }
      }
    }

    // Calculate mathematical consistency
    const consistency = this.calculateMathematicalConsistency(allAmounts.map(a => a.sig), relationships);

    return {
      sequence: signatures,
      relationships,
      mathematicalConsistency: consistency
    };
  }

  /**
   * Detect relationship between two numerical values
   */
  private detectNumericalRelationship(
    sig1: NumericalSignature, 
    sig2: NumericalSignature, 
    allAmounts: NumericalSignature[]
  ): NumericalRelationship | null {
    
    // Get primary values for comparison
    const val1 = sig1.values[0] || 0;
    const val2 = sig2.values[0] || 0;
    
    const diff = Math.abs(val1 - val2);
    const ratio = val2 / val1;
    const tolerance = 0.02; // 2 cents tolerance

    // Check for addition relationship (subtotal + tax = total)
    const sum = val1 + val2;
    const sumCandidate = allAmounts.find(s => 
      s.values.some(v => Math.abs(v - sum) < tolerance)
    );
    
    if (sumCandidate) {
      return {
        source: sig1,
        target: sig2,
        relationship: 'addition',
        confidence: 0.9
      };
    }

    // Check for tax calculation relationship (base * rate = tax)
    if (ratio >= 0.05 && ratio <= 0.30) { // 5-30% range
      return {
        source: sig1,
        target: sig2,
        relationship: 'tax_calculation',
        confidence: 0.7
      };
    }

    return null;
  }

  /**
   * Helper methods for confidence calculations
   */
  private calculatePercentageConfidence(value: number): number {
    // Higher confidence for common tax rates
    const commonRates = [5, 6, 7, 8, 9, 10, 12, 14, 19, 20, 21, 22, 24, 25];
    const isCommon = commonRates.some(rate => Math.abs(value - rate) < 0.5);
    return isCommon ? 0.9 : 0.6;
  }

  private calculateAmountConfidence(value: number, line: string): number {
    let confidence = 0.5;
    
    // Higher confidence if currency symbols present
    if (/[$€£¥]/.test(line)) confidence += 0.2;
    
    // Higher confidence for reasonable amounts
    if (value >= 0.01 && value <= 1000) confidence += 0.2;
    
    return Math.min(confidence, 1.0);
  }

  private calculateSegmentConfidence(features: SegmentFeatures, type: DocumentSegment['type']): number {
    let confidence = 0.5;
    
    switch (type) {
      case 'summary':
        if (features.percentageCount > 0) confidence += 0.3;
        if (features.numericalDensity > 0.5) confidence += 0.2;
        break;
      case 'header':
        if (features.numericalDensity < 0.3) confidence += 0.3;
        break;
      case 'footer':
        if (features.averageLineLength < 30) confidence += 0.2;
        break;
    }
    
    return Math.min(confidence, 1.0);
  }





  private calculateMathematicalConsistency(amounts: NumericalSignature[], relationships: NumericalRelationship[]): number {
    if (relationships.length === 0) return 0;
    
    let consistentCount = 0;
    const tolerance = 0.02;
    
    relationships.forEach(rel => {
      if (rel.relationship === 'addition') {
        // Check if subtotal + tax = total pattern exists
        const val1 = rel.source.values[0] || 0;
        const val2 = rel.target.values[0] || 0;
        const sum = val1 + val2;
        const hasMatchingTotal = amounts.some(a => 
          a.values.some(v => Math.abs(v - sum) < tolerance)
        );
        if (hasMatchingTotal) consistentCount++;
      }
    });
    
    return consistentCount / relationships.length;
  }
}