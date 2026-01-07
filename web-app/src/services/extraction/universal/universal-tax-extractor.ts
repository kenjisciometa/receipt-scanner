/**
 * Universal Tax Extraction System
 * 
 * Language, country, and store-agnostic tax extraction system.
 * Combines structural analysis with statistical learning for 
 * adaptive pattern recognition without hardcoded rules.
 */

import { LanguageKeywords, SupportedLanguage } from '@/services/keywords/language-keywords';
import { StructuralAnalysisEngine, SpatialStructure, TaxSection, TaxEntry } from './structural-analysis-engine';
import { StatisticalLearningEngine, LearningConfiguration } from './statistical-learning-engine';

export interface UniversalTaxEntry {
  rate?: number;              // Tax rate percentage (if detected)
  taxAmount: number;          // Tax amount
  taxableAmount?: number;     // Base amount before tax
  grossAmount?: number;       // Total amount including tax
  confidence: number;         // Extraction confidence (0-1)
  detectionMethod: string;    // How this entry was detected
  spatialLocation: {          // Where in document this was found
    lineIndex: number;
    sectionType: string;
  };
  features: Record<string, number>; // Features for learning
}

export interface UniversalTaxResult {
  taxEntries: UniversalTaxEntry[];
  taxTotal: number;
  extractionConfidence: number;
  detectionSummary: {
    primaryMethod: string;
    alternativeMethods: string[];
    structuralAnalysis: SpatialStructure;
    learningInsights?: any;
  };
  processingMetrics: {
    totalProcessingTime: number;
    structuralAnalysisTime: number;
    candidateGenerationTime: number;
    validationTime: number;
  };
}

export interface UniversalExtractionConfig {
  enableLearning: boolean;
  learningConfig?: Partial<LearningConfiguration>;
  minConfidenceThreshold: number;
  maxCandidatesPerSection: number;
  enableFallbackMethods: boolean;
  debugMode: boolean;
}

const DEFAULT_CONFIG: UniversalExtractionConfig = {
  enableLearning: true,
  minConfidenceThreshold: 0.3,
  maxCandidatesPerSection: 10,
  enableFallbackMethods: true,
  debugMode: false
};

/**
 * Universal Tax Extraction Engine
 * Core system that coordinates all extraction approaches
 */
export class UniversalTaxExtractor {
  private structuralEngine: StructuralAnalysisEngine;
  private learningEngine?: StatisticalLearningEngine;
  private languageKeywords: LanguageKeywords;

  constructor(
    private config: UniversalExtractionConfig = DEFAULT_CONFIG
  ) {
    this.languageKeywords = new LanguageKeywords();
    this.structuralEngine = new StructuralAnalysisEngine(
      this.languageKeywords, 
      config.debugMode
    );

    if (config.enableLearning) {
      this.learningEngine = new StatisticalLearningEngine(
        {
          enableLearning: true,
          maxHistorySize: 1000,
          minSampleSizeForWeight: 5,
          confidenceDecayFactor: 0.95,
          adaptationThreshold: 0.8,
          stabilityMode: true,
          ...config.learningConfig
        },
        config.debugMode
      );
    }
  }

  /**
   * Extract tax information using universal approach
   */
  async extractTaxInformation(
    textLines: string[],
    language: SupportedLanguage = 'en'
  ): Promise<UniversalTaxResult> {
    const startTime = performance.now();

    if (this.config.debugMode) {
      console.log(`🌍 [Universal] Starting tax extraction for ${textLines.length} lines (${language})`);
    }

    // Step 1: Structural Analysis
    const structuralStartTime = performance.now();
    const structure = this.structuralEngine.analyzeTaxStructure(textLines, language);
    const structuralAnalysisTime = performance.now() - structuralStartTime;

    // Step 2: Generate Tax Candidates
    const candidateStartTime = performance.now();
    const candidates = this.generateTaxCandidates(structure, textLines, language);
    const candidateGenerationTime = performance.now() - candidateStartTime;

    // Step 3: Validate and Rank Candidates
    const validationStartTime = performance.now();
    const validatedEntries = this.validateAndRankCandidates(candidates, structure);
    const validationTime = performance.now() - validationStartTime;

    // Step 4: Apply Learning (if enabled)
    if (this.learningEngine) {
      this.applyLearningOptimization(validatedEntries, structure);
    }

    // Step 5: Generate Final Result
    const result = this.generateFinalResult(
      validatedEntries,
      structure,
      {
        totalProcessingTime: performance.now() - startTime,
        structuralAnalysisTime,
        candidateGenerationTime,
        validationTime
      }
    );

    // Step 6: Record Learning Data
    if (this.learningEngine && validatedEntries.length > 0) {
      this.recordExtractionForLearning(validatedEntries, result, structure);
    }

    if (this.config.debugMode) {
      console.log(`✅ [Universal] Extraction completed: ${result.taxEntries.length} entries, confidence: ${result.extractionConfidence}`);
    }

    return result;
  }

  /**
   * Generate tax candidates from structural analysis
   */
  private generateTaxCandidates(
    structure: SpatialStructure,
    textLines: string[],
    language: SupportedLanguage
  ): UniversalTaxEntry[] {
    const candidates: UniversalTaxEntry[] = [];

    // Method 1: Direct structural candidates from new TaxSection format
    structure.taxRelevantSections.forEach(section => {
      section.taxEntries.forEach(entry => {
        const features = this.extractEntryFeatures(entry, structure, textLines);
        
        candidates.push({
          rate: entry.rate,
          taxAmount: entry.amount,
          confidence: entry.confidence,
          detectionMethod: `structural-${section.type}`,
          spatialLocation: {
            lineIndex: entry.lineIndex,
            sectionType: section.type
          },
          features
        });
      });
    });

    // Method 2: Numerical relationship candidates
    const relationshipCandidates = this.generateRelationshipBasedCandidates(structure, textLines);
    candidates.push(...relationshipCandidates);

    // Method 3: Pattern-based candidates (using learned patterns if available)
    if (this.learningEngine) {
      const patternCandidates = this.generatePatternBasedCandidates(structure, textLines, language);
      candidates.push(...patternCandidates);
    }

    // Method 4: Fallback keyword-based candidates
    if (this.config.enableFallbackMethods) {
      const fallbackCandidates = this.generateFallbackCandidates(textLines, language);
      candidates.push(...fallbackCandidates);
    }

    return candidates;
  }

  /**
   * Generate candidates based on numerical relationships
   */
  private generateRelationshipBasedCandidates(
    structure: SpatialStructure,
    textLines: string[]
  ): UniversalTaxEntry[] {
    const candidates: UniversalTaxEntry[] = [];

    // Look for mathematical relationships in the numerical flow
    structure.numericalFlow.relationships.forEach(relationship => {
      if (relationship.relationship === 'tax_calculation' || 
          relationship.relationship === 'addition') {
        
        const features = this.extractRelationshipFeatures(relationship, structure);
        
        candidates.push({
          taxAmount: relationship.target.values[0] || 0,
          taxableAmount: relationship.relationship === 'tax_calculation' ? relationship.source.values[0] : undefined,
          confidence: relationship.confidence * 0.8, // Slightly lower confidence
          detectionMethod: `relationship-${relationship.relationship}`,
          spatialLocation: {
            lineIndex: relationship.target.lineIndex,
            sectionType: 'calculated'
          },
          features
        });
      }
    });

    return candidates;
  }

  /**
   * Generate candidates using learned patterns
   */
  private generatePatternBasedCandidates(
    structure: SpatialStructure,
    textLines: string[],
    language: SupportedLanguage
  ): UniversalTaxEntry[] {
    if (!this.learningEngine) return [];

    const candidates: UniversalTaxEntry[] = [];
    const adaptivePatterns = this.learningEngine.getAdaptivePatterns();
    const featureImportance = this.learningEngine.getFeatureImportance();

    // Apply learned patterns to identify potential tax entries
    adaptivePatterns.forEach(pattern => {
      // Score each numerical signature against the learned pattern
      structure.numericalFlow.sequence
        .filter(sig => sig.types.includes('amount'))
        .forEach(signature => {
          const features = this.extractSignatureFeatures(signature, structure, textLines);
          const patternScore = this.calculatePatternScore(features, pattern.features, featureImportance);
          
          if (patternScore > this.config.minConfidenceThreshold) {
            candidates.push({
              taxAmount: signature.values[0] || 0,
              confidence: patternScore * pattern.confidence,
              detectionMethod: `pattern-${pattern.adaptationType}`,
              spatialLocation: {
                lineIndex: signature.lineIndex,
                sectionType: 'pattern-detected'
              },
              features
            });
          }
        });
    });

    return candidates;
  }

  /**
   * Generate fallback candidates using basic keyword matching
   */
  private generateFallbackCandidates(
    textLines: string[],
    language: SupportedLanguage
  ): UniversalTaxEntry[] {
    const candidates: UniversalTaxEntry[] = [];
    const taxKeywords = LanguageKeywords.getKeywords('tax', language);

    // Simple keyword-based detection as last resort
    textLines.forEach((line, lineIndex) => {
      const lowerLine = line.toLowerCase();
      
      // Check if line contains tax keywords and numbers
      const hasTaxKeyword = taxKeywords.some((keyword: string) => lowerLine.includes(keyword.toLowerCase()));
      const amountMatch = line.match(/(\d+[.,]\d{2})/);
      
      if (hasTaxKeyword && amountMatch) {
        const amount = parseFloat(amountMatch[1].replace(',', '.'));
        
        candidates.push({
          taxAmount: amount,
          confidence: 0.4, // Low confidence for fallback method
          detectionMethod: 'fallback-keyword',
          spatialLocation: {
            lineIndex,
            sectionType: 'keyword-based'
          },
          features: {
            hasKeyword: 1,
            linePosition: lineIndex / textLines.length,
            amountValue: amount
          }
        });
      }
    });

    return candidates;
  }

  /**
   * Validate and rank all candidates
   */
  private validateAndRankCandidates(
    candidates: UniversalTaxEntry[],
    structure: SpatialStructure
  ): UniversalTaxEntry[] {
    // Remove duplicates (same amount + similar location)
    const uniqueCandidates = this.removeDuplicateCandidates(candidates);
    
    // Apply validation rules
    const validatedCandidates = uniqueCandidates.filter(candidate => 
      this.validateCandidate(candidate, structure)
    );

    // Enhance confidence based on cross-validation
    validatedCandidates.forEach(candidate => {
      candidate.confidence = this.enhanceConfidence(candidate, validatedCandidates, structure);
    });

    // Sort by confidence and limit results
    return validatedCandidates
      .sort((a, b) => b.confidence - a.confidence)
      .slice(0, this.config.maxCandidatesPerSection * structure.taxRelevantSections.length);
  }

  /**
   * Remove duplicate candidates with similar amounts and locations
   */
  private removeDuplicateCandidates(candidates: UniversalTaxEntry[]): UniversalTaxEntry[] {
    const unique: UniversalTaxEntry[] = [];
    const tolerance = 0.01; // 1 cent tolerance

    candidates.forEach(candidate => {
      const isDuplicate = unique.some(existing => 
        Math.abs(existing.taxAmount - candidate.taxAmount) < tolerance &&
        Math.abs(existing.spatialLocation.lineIndex - candidate.spatialLocation.lineIndex) <= 1
      );

      if (!isDuplicate) {
        unique.push(candidate);
      } else {
        // If duplicate found, keep the one with higher confidence
        const existingIndex = unique.findIndex(existing => 
          Math.abs(existing.taxAmount - candidate.taxAmount) < tolerance
        );
        if (existingIndex >= 0 && candidate.confidence > unique[existingIndex].confidence) {
          unique[existingIndex] = candidate;
        }
      }
    });

    return unique;
  }

  /**
   * Validate individual candidate
   */
  private validateCandidate(candidate: UniversalTaxEntry, structure: SpatialStructure): boolean {
    // Basic validation rules
    if (candidate.taxAmount <= 0 || candidate.taxAmount > 10000) return false;
    if (candidate.confidence < this.config.minConfidenceThreshold) return false;
    if (candidate.rate && (candidate.rate < 0 || candidate.rate > 50)) return false;

    // Contextual validation
    const isInTaxSection = structure.taxRelevantSections.some(section =>
      candidate.spatialLocation.lineIndex >= section.startLine &&
      candidate.spatialLocation.lineIndex <= section.endLine
    );

    return isInTaxSection || candidate.confidence > 0.7; // High confidence can override section requirement
  }

  /**
   * Enhance confidence based on cross-validation with other candidates
   */
  private enhanceConfidence(
    candidate: UniversalTaxEntry,
    allCandidates: UniversalTaxEntry[],
    structure: SpatialStructure
  ): number {
    let enhancedConfidence = candidate.confidence;

    // Bonus for mathematical consistency
    const hasRelatedSubtotal = this.findRelatedSubtotal(candidate, structure);
    if (hasRelatedSubtotal) {
      enhancedConfidence += 0.1;
    }

    // Bonus for multiple detection methods agreeing
    const agreementCount = allCandidates.filter(other => 
      other !== candidate &&
      Math.abs(other.taxAmount - candidate.taxAmount) < 0.02 &&
      other.detectionMethod !== candidate.detectionMethod
    ).length;
    
    enhancedConfidence += Math.min(agreementCount * 0.1, 0.3);

    // Bonus for having tax rate
    if (candidate.rate) {
      enhancedConfidence += 0.1;
    }

    return Math.min(enhancedConfidence, 1.0);
  }

  /**
   * Apply learning optimization to results
   */
  private applyLearningOptimization(
    entries: UniversalTaxEntry[],
    structure: SpatialStructure
  ): void {
    if (!this.learningEngine) return;

    const patternWeights = this.learningEngine.getPatternWeights();
    const featureImportance = this.learningEngine.getFeatureImportance();

    entries.forEach(entry => {
      // Adjust confidence based on learned patterns
      let adjustedConfidence = entry.confidence;
      
      // Apply feature importance weights
      for (const [featureName, importance] of featureImportance) {
        if (entry.features[featureName]) {
          adjustedConfidence *= (1 + (importance - 0.5) * 0.2); // Adjust based on importance
        }
      }

      entry.confidence = Math.max(0.1, Math.min(1.0, adjustedConfidence));
    });
  }

  /**
   * Generate final extraction result
   */
  private generateFinalResult(
    entries: UniversalTaxEntry[],
    structure: SpatialStructure,
    metrics: UniversalTaxResult['processingMetrics']
  ): UniversalTaxResult {
    
    const taxTotal = entries.reduce((sum, entry) => sum + entry.taxAmount, 0);
    const avgConfidence = entries.length > 0 
      ? entries.reduce((sum, entry) => sum + entry.confidence, 0) / entries.length 
      : 0;

    const detectionMethods = [...new Set(entries.map(e => e.detectionMethod))];
    const primaryMethod = detectionMethods[0] || 'none';

    return {
      taxEntries: entries,
      taxTotal,
      extractionConfidence: avgConfidence,
      detectionSummary: {
        primaryMethod,
        alternativeMethods: detectionMethods.slice(1),
        structuralAnalysis: structure,
        learningInsights: this.learningEngine?.getLearningAnalytics()
      },
      processingMetrics: metrics
    };
  }

  /**
   * Record extraction results for learning
   */
  private recordExtractionForLearning(
    entries: UniversalTaxEntry[],
    result: UniversalTaxResult,
    structure: SpatialStructure
  ): void {
    if (!this.learningEngine) return;

    // Record success for each detection method used
    const methodSuccess = new Map<string, boolean>();
    
    entries.forEach(entry => {
      const success = entry.confidence > 0.6; // Define success threshold
      methodSuccess.set(entry.detectionMethod, success);
      
      this.learningEngine!.recordPatternUsage(
        entry.detectionMethod,
        entry.features,
        success,
        entry.confidence,
        result.processingMetrics.totalProcessingTime
      );
    });
  }

  /**
   * Helper method to extract features from tax entry
   */
  private extractEntryFeatures(
    entry: TaxEntry,
    structure: SpatialStructure,
    textLines: string[]
  ): Record<string, number> {
    const line = textLines[entry.lineIndex] || '';
    
    return {
      hasRate: entry.rate ? 1 : 0,
      rateValue: entry.rate || 0,
      amountValue: entry.amount,
      linePosition: entry.lineIndex / textLines.length,
      lineLength: line.length,
      numericalDensity: (line.match(/\d/g) || []).length / Math.max(line.length, 1),
      hasPercentage: line.includes('%') ? 1 : 0,
      hasCurrency: /[$€£¥]/.test(line) ? 1 : 0
    };
  }

  /**
   * Extract features from numerical relationship
   */
  private extractRelationshipFeatures(relationship: any, structure: SpatialStructure): Record<string, number> {
    return {
      relationshipType: relationship.relationship === 'addition' ? 1 : 0.5,
      confidence: relationship.confidence,
      sourceValue: relationship.source.values[0] || 0,
      targetValue: relationship.target.values[0] || 0,
      lineDistance: Math.abs(relationship.target.lineIndex - relationship.source.lineIndex),
      mathematicalConsistency: structure.numericalFlow.mathematicalConsistency
    };
  }

  /**
   * Extract features from numerical signature
   */
  private extractSignatureFeatures(signature: any, structure: SpatialStructure, textLines: string[]): Record<string, number> {
    const line = textLines[signature.lineIndex] || '';
    
    return {
      signatureType: signature.types.includes('percentage') ? 1 : 0,
      value: signature.values[0] || 0,
      linePosition: signature.lineIndex / textLines.length,
      confidence: signature.confidence,
      lineLength: line.length,
      position: signature.position / Math.max(line.length, 1)
    };
  }

  /**
   * Calculate pattern score based on feature similarity
   */
  private calculatePatternScore(
    features: Record<string, number>,
    patternFeatures: Record<string, number>,
    importance: Map<string, number>
  ): number {
    let score = 0;
    let totalWeight = 0;

    for (const [featureName, patternValue] of Object.entries(patternFeatures)) {
      const featureValue = features[featureName] || 0;
      const weight = importance.get(featureName) || 0.5;
      
      // Calculate similarity (1 - normalized difference)
      const similarity = 1 - Math.abs(patternValue - featureValue);
      score += similarity * weight;
      totalWeight += weight;
    }

    return totalWeight > 0 ? score / totalWeight : 0;
  }

  /**
   * Find related subtotal for mathematical consistency
   */
  private findRelatedSubtotal(candidate: UniversalTaxEntry, structure: SpatialStructure): boolean {
    // Look for subtotal + tax = total pattern
    return structure.numericalFlow.relationships.some(rel => 
      rel.relationship === 'addition' &&
      (rel.source.values.some(v => Math.abs(v - candidate.taxAmount) < 0.01) || 
       rel.target.values.some(v => Math.abs(v - candidate.taxAmount) < 0.01))
    );
  }

  /**
   * Get learning statistics for monitoring
   */
  getLearningStatistics(): any {
    return this.learningEngine?.getLearningAnalytics() || null;
  }

  /**
   * Clear learning data (for testing/reset)
   */
  clearLearningData(): void {
    this.learningEngine?.clearLearningData();
  }
}