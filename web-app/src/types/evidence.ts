/**
 * Evidence-Based Fusion System for Receipt Data Extraction
 * 
 * This module defines the core data structures for collecting, validating,
 * and fusing evidence from multiple sources to extract accurate receipt data.
 */

// Define BoundingBox inline since it's a simple type
export type BoundingBox = [number, number, number, number]; // [x, y, width, height]

export type EvidenceSource = 
  | 'table' 
  | 'text' 
  | 'calculation' 
  | 'pattern' 
  | 'bbox' 
  | 'summary_calculation'
  | 'ocr_confidence'
  | 'spatial_analysis'
  | 'linguistic_analysis';

export type EvidenceField = 
  | 'subtotal' 
  | 'tax_amount' 
  | 'total' 
  | 'tax_rate' 
  | 'tax_breakdown'
  | 'currency'
  | 'merchant_name'
  | 'purchase_date'
  | 'payment_method';

export interface TaxBreakdown {
  rate: number;                    // Tax rate as percentage (e.g., 14.0 for 14%)
  amount: number;                  // Tax amount for this rate
  net?: number;                    // Net amount (tax-free amount) for this rate
  gross?: number;                  // Gross amount (including tax) for this rate
  category?: string;               // Tax category code (A, B, C, Standard, Reduced)
  confidence: number;              // Confidence score for this breakdown
  description?: string;            // Multilingual description of the tax category
  supportingEvidence: number;      // Number of evidence sources supporting this
}

/**
 * Core evidence structure - represents a single piece of evidence
 * about a specific field from a specific source
 */
export interface TaxEvidence {
  /** Source of this evidence */
  source: EvidenceSource;
  
  /** Which field this evidence pertains to */
  field?: EvidenceField;
  
  /** Tax rate (for tax-related evidence) */
  rate?: number;
  
  /** Monetary amount */
  amount?: number;
  
  /** String value (for non-monetary fields) */
  value?: string;
  
  /** Confidence score (0.0 - 1.0) */
  confidence: number;
  
  /** Spatial position in the receipt */
  position?: BoundingBox;
  
  /** Raw text that generated this evidence */
  rawText: string;
  
  /** Additional supporting data */
  supportingData?: {
    method?: string;
    ocrConfidence?: number;
    spatialConsistency?: number;
    linguisticConsistency?: number;
    mathematicalConsistency?: number;
    [key: string]: any;
  };
  
  /** Timestamp when evidence was created */
  timestamp: Date;
}

/**
 * Cluster of similar evidence that should be considered together
 */
export interface EvidenceCluster {
  /** Type/field this cluster represents */
  type: EvidenceField;
  
  /** All evidence in this cluster */
  evidence: TaxEvidence[];
  
  /** Centroid/representative value */
  centroid: {
    rate?: number;
    amount?: number;
    value?: string;
  };
  
  /** Consolidated confidence after cross-validation */
  consolidatedConfidence: number;
  
  /** Variance/spread of values in the cluster */
  variance: number;
  
  /** Whether this cluster passed consistency checks */
  isConsistent: boolean;
}

/**
 * Result of cross-validation process
 */
export interface ValidationResult {
  /** Validated clusters */
  clusters: EvidenceCluster[];
  
  /** Overall confidence in the validation */
  overallConfidence: number;
  
  /** Consistency checks that were performed */
  checksPerformed: string[];
  
  /** Any warnings or issues found */
  warnings: string[];
  
  /** Mathematical consistency score */
  mathematicalConsistency: number;
  
  /** Spatial consistency score */
  spatialConsistency: number;
}

/**
 * Final extracted data with evidence tracking
 */
export interface EvidenceBasedExtractedData {
  // Core receipt fields
  subtotal?: number;
  tax_amount?: number;
  total?: number;
  currency?: string;
  merchant_name?: string;
  purchase_date?: Date;
  payment_method?: string;
  
  // Tax breakdown information
  tax_breakdown?: TaxBreakdown[];
  tax_total?: number;
  
  // Evidence metadata
  evidence_summary: {
    totalEvidencePieces: number;
    sourcesUsed: EvidenceSource[];
    averageConfidence: number;
    consistencyScore: number;
    warnings: string[];
  };
  
  // Validation results
  validation: ValidationResult;
  
  // Processing metadata
  processingMetadata: {
    evidenceCollectionTime: number;
    validationTime: number;
    fusionTime: number;
    totalProcessingTime: number;
  };
}

/**
 * Configuration for evidence collection and fusion
 */
export interface EvidenceFusionConfig {
  // Minimum confidence thresholds
  minEvidenceConfidence: number;
  minClusterConfidence: number;
  
  // Clustering parameters
  similarityThreshold: number;
  maxClusterVariance: number;
  
  // Validation parameters
  mathematicalTolerancePercent: number;
  spatialTolerancePixels: number;
  
  // Source weights
  sourceWeights: Partial<Record<EvidenceSource, number>>;
  
  // Enable/disable specific evidence sources
  enabledSources: EvidenceSource[];
  
  // Tax breakdown specific settings
  maxTaxRatePercent: number;
  minTaxRatePercent: number;
  
  // Debug and logging
  enableDebugLogging: boolean;
  enableEvidenceTracking: boolean;
}

/**
 * Default configuration for evidence fusion
 */
export const DEFAULT_EVIDENCE_FUSION_CONFIG: EvidenceFusionConfig = {
  minEvidenceConfidence: 0.3,
  minClusterConfidence: 0.5,
  
  similarityThreshold: 0.85,
  maxClusterVariance: 0.1,
  
  mathematicalTolerancePercent: 2.0,
  spatialTolerancePixels: 10,
  
  sourceWeights: {
    table: 1.3,
    summary_calculation: 1.2,
    calculation: 1.1,
    text: 1.0,
    pattern: 0.9,
    bbox: 0.8,
  },
  
  enabledSources: [
    'table',
    'text', 
    'calculation',
    'summary_calculation',
    'pattern',
    'bbox',
    'ocr_confidence',
    'spatial_analysis'
  ],
  
  maxTaxRatePercent: 50.0,
  minTaxRatePercent: 0.0,
  
  enableDebugLogging: true,
  enableEvidenceTracking: true,
};

/**
 * Utility functions for working with evidence
 */
export class EvidenceUtils {
  /**
   * Calculate similarity between two evidence pieces
   */
  static calculateSimilarity(evidence1: TaxEvidence, evidence2: TaxEvidence): number {
    if (evidence1.field !== evidence2.field) return 0;
    
    let similarity = 0;
    let factors = 0;
    
    // Amount similarity
    if (evidence1.amount != null && evidence2.amount != null) {
      const deviation = Math.abs(evidence1.amount - evidence2.amount) / Math.max(evidence1.amount, evidence2.amount);
      similarity += Math.max(0, 1 - deviation);
      factors++;
    }
    
    // Rate similarity  
    if (evidence1.rate != null && evidence2.rate != null) {
      const deviation = Math.abs(evidence1.rate - evidence2.rate) / Math.max(evidence1.rate, evidence2.rate);
      similarity += Math.max(0, 1 - deviation);
      factors++;
    }
    
    // String similarity (for non-numeric fields)
    if (evidence1.value != null && evidence2.value != null) {
      const stringSimilarity = this.calculateStringSimilarity(evidence1.value, evidence2.value);
      similarity += stringSimilarity;
      factors++;
    }
    
    return factors > 0 ? similarity / factors : 0;
  }
  
  /**
   * Calculate string similarity using simple overlap metric
   */
  static calculateStringSimilarity(str1: string, str2: string): number {
    const s1 = str1.toLowerCase().trim();
    const s2 = str2.toLowerCase().trim();
    
    if (s1 === s2) return 1.0;
    
    const longer = s1.length > s2.length ? s1 : s2;
    const shorter = s1.length > s2.length ? s2 : s1;
    
    if (longer.length === 0) return 1.0;
    
    const editDistance = this.calculateEditDistance(longer, shorter);
    return (longer.length - editDistance) / longer.length;
  }
  
  /**
   * Calculate edit distance between two strings
   */
  static calculateEditDistance(str1: string, str2: string): number {
    const matrix = Array(str2.length + 1).fill(null).map(() => Array(str1.length + 1).fill(null));
    
    for (let i = 0; i <= str1.length; i++) matrix[0][i] = i;
    for (let j = 0; j <= str2.length; j++) matrix[j][0] = j;
    
    for (let j = 1; j <= str2.length; j++) {
      for (let i = 1; i <= str1.length; i++) {
        const substitutionCost = str1[i - 1] === str2[j - 1] ? 0 : 1;
        matrix[j][i] = Math.min(
          matrix[j][i - 1] + 1,     // insertion
          matrix[j - 1][i] + 1,     // deletion
          matrix[j - 1][i - 1] + substitutionCost  // substitution
        );
      }
    }
    
    return matrix[str2.length][str1.length];
  }
  
  /**
   * Calculate weighted average of evidence values
   */
  static calculateWeightedAverage(evidence: TaxEvidence[], field: 'amount' | 'rate'): number | null {
    const validEvidence = evidence.filter(e => e[field] != null);
    if (validEvidence.length === 0) return null;
    
    let weightedSum = 0;
    let totalWeight = 0;
    
    for (const e of validEvidence) {
      const value = e[field]!;
      const weight = e.confidence;
      weightedSum += value * weight;
      totalWeight += weight;
    }
    
    return totalWeight > 0 ? weightedSum / totalWeight : null;
  }
  
  /**
   * Remove outliers from evidence based on statistical analysis
   */
  static removeOutliers(evidence: TaxEvidence[], field: 'amount' | 'rate'): TaxEvidence[] {
    const values = evidence.filter(e => e[field] != null).map(e => e[field]!);
    if (values.length < 3) return evidence; // Not enough data for outlier detection
    
    values.sort((a, b) => a - b);
    const q1Index = Math.floor(values.length * 0.25);
    const q3Index = Math.floor(values.length * 0.75);
    const q1 = values[q1Index];
    const q3 = values[q3Index];
    const iqr = q3 - q1;
    const lowerBound = q1 - 1.5 * iqr;
    const upperBound = q3 + 1.5 * iqr;
    
    return evidence.filter(e => {
      const value = e[field];
      return value == null || (value >= lowerBound && value <= upperBound);
    });
  }
}