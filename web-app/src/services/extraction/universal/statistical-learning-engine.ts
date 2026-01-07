/**
 * Lightweight Statistical Learning Engine
 * 
 * Non-ML statistical learning system for pattern optimization.
 * Uses frequency analysis and success tracking without requiring
 * heavy machine learning models or training data.
 */

export interface PatternStatistics {
  patternId: string;
  successCount: number;
  totalAttempts: number;
  successRate: number;
  confidence: number;
  lastUsed: number;
  features: Record<string, number>;
}

export interface FeatureWeights {
  featureName: string;
  weight: number;
  sampleSize: number;
  lastUpdated: number;
}

export interface LearningHistory {
  timestamp: number;
  patternId: string;
  success: boolean;
  features: Record<string, number>;
  extractionQuality: number;
  processingTime: number;
}

export interface AdaptivePattern {
  id: string;
  basePatternIds: string[];
  adaptationType: 'combination' | 'mutation' | 'evolution';
  features: Record<string, number>;
  confidence: number;
  generatedAt: number;
}

export interface LearningConfiguration {
  enableLearning: boolean;
  maxHistorySize: number;
  minSampleSizeForWeight: number;
  confidenceDecayFactor: number;
  adaptationThreshold: number;
  stabilityMode: boolean;
}

const DEFAULT_LEARNING_CONFIG: LearningConfiguration = {
  enableLearning: true,
  maxHistorySize: 1000,
  minSampleSizeForWeight: 5,
  confidenceDecayFactor: 0.95,
  adaptationThreshold: 0.8,
  stabilityMode: true // Prioritize stability over aggressive learning
};

/**
 * Lightweight Statistical Pattern Learning Engine
 */
export class StatisticalLearningEngine {
  private patternStats: Map<string, PatternStatistics> = new Map();
  private featureWeights: Map<string, FeatureWeights> = new Map();
  private learningHistory: LearningHistory[] = [];
  private adaptivePatterns: Map<string, AdaptivePattern> = new Map();
  
  constructor(
    private config: LearningConfiguration = DEFAULT_LEARNING_CONFIG,
    private debugMode: boolean = false
  ) {
    this.loadPersistedData();
  }

  /**
   * Track pattern usage and success for learning
   */
  recordPatternUsage(
    patternId: string,
    features: Record<string, number>,
    success: boolean,
    extractionQuality: number = 0,
    processingTime: number = 0
  ): void {
    if (!this.config.enableLearning) return;

    // Update pattern statistics
    this.updatePatternStatistics(patternId, success, features);
    
    // Update feature weights
    this.updateFeatureWeights(features, success, extractionQuality);
    
    // Record in learning history
    this.recordLearningHistory(patternId, features, success, extractionQuality, processingTime);
    
    // Generate adaptive patterns if threshold met
    if (this.shouldGenerateAdaptivePatterns()) {
      this.generateAdaptivePatterns();
    }

    // Persist learning data periodically
    if (this.learningHistory.length % 10 === 0) {
      this.persistLearningData();
    }

    if (this.debugMode) {
      console.log(`📚 [Learning] Pattern ${patternId}: success=${success}, quality=${extractionQuality}`);
    }
  }

  /**
   * Get optimized pattern weights based on learning
   */
  getPatternWeights(): Map<string, number> {
    const weights = new Map<string, number>();
    
    for (const [patternId, stats] of this.patternStats) {
      const weight = this.calculatePatternWeight(stats);
      weights.set(patternId, weight);
    }
    
    return weights;
  }

  /**
   * Get feature importance weights
   */
  getFeatureImportance(): Map<string, number> {
    const importance = new Map<string, number>();
    
    for (const [featureName, weights] of this.featureWeights) {
      if (weights.sampleSize >= this.config.minSampleSizeForWeight) {
        importance.set(featureName, weights.weight);
      }
    }
    
    return importance;
  }

  /**
   * Get recommended adaptive patterns
   */
  getAdaptivePatterns(): AdaptivePattern[] {
    const now = Date.now();
    const validPatterns = Array.from(this.adaptivePatterns.values())
      .filter(pattern => {
        // Only return patterns that have been validated or are recent
        const ageHours = (now - pattern.generatedAt) / (1000 * 60 * 60);
        return pattern.confidence > this.config.adaptationThreshold || ageHours < 1;
      })
      .sort((a, b) => b.confidence - a.confidence);

    if (this.debugMode && validPatterns.length > 0) {
      console.log(`🧬 [Learning] Generated ${validPatterns.length} adaptive patterns`);
    }

    return validPatterns;
  }

  /**
   * Update pattern statistics with new usage data
   */
  private updatePatternStatistics(
    patternId: string,
    success: boolean,
    features: Record<string, number>
  ): void {
    const existing = this.patternStats.get(patternId) || {
      patternId,
      successCount: 0,
      totalAttempts: 0,
      successRate: 0,
      confidence: 0.5,
      lastUsed: Date.now(),
      features: {}
    };

    existing.totalAttempts++;
    if (success) existing.successCount++;
    existing.successRate = existing.successCount / existing.totalAttempts;
    existing.lastUsed = Date.now();
    
    // Update feature averages
    for (const [featureName, value] of Object.entries(features)) {
      const currentAvg = existing.features[featureName] || 0;
      existing.features[featureName] = (currentAvg * (existing.totalAttempts - 1) + value) / existing.totalAttempts;
    }
    
    // Calculate confidence using Bayesian approach
    existing.confidence = this.calculateBayesianConfidence(existing.successCount, existing.totalAttempts);
    
    this.patternStats.set(patternId, existing);
  }

  /**
   * Update feature weights based on success correlation
   */
  private updateFeatureWeights(
    features: Record<string, number>,
    success: boolean,
    quality: number
  ): void {
    for (const [featureName, value] of Object.entries(features)) {
      const existing = this.featureWeights.get(featureName) || {
        featureName,
        weight: 0.5,
        sampleSize: 0,
        lastUpdated: Date.now()
      };

      existing.sampleSize++;
      
      // Weight adjustment based on success and quality
      const adjustment = success ? (quality > 0.7 ? 0.1 : 0.05) : -0.05;
      const learningRate = 1 / Math.sqrt(existing.sampleSize); // Decreasing learning rate
      
      existing.weight = Math.max(0, Math.min(1, existing.weight + adjustment * learningRate));
      existing.lastUpdated = Date.now();
      
      this.featureWeights.set(featureName, existing);
    }
  }

  /**
   * Record learning event in history
   */
  private recordLearningHistory(
    patternId: string,
    features: Record<string, number>,
    success: boolean,
    quality: number,
    processingTime: number
  ): void {
    this.learningHistory.push({
      timestamp: Date.now(),
      patternId,
      success,
      features,
      extractionQuality: quality,
      processingTime
    });

    // Maintain history size limit
    if (this.learningHistory.length > this.config.maxHistorySize) {
      this.learningHistory = this.learningHistory.slice(-this.config.maxHistorySize);
    }
  }

  /**
   * Calculate Bayesian confidence for pattern success
   */
  private calculateBayesianConfidence(successes: number, attempts: number): number {
    // Beta distribution with uniform prior (alpha=1, beta=1)
    const alpha = 1 + successes;
    const beta = 1 + (attempts - successes);
    
    // Expected value of Beta distribution
    return alpha / (alpha + beta);
  }

  /**
   * Calculate pattern weight considering success rate, recency, and stability
   */
  private calculatePatternWeight(stats: PatternStatistics): number {
    let weight = stats.successRate;
    
    // Recency factor (decay old patterns)
    const ageHours = (Date.now() - stats.lastUsed) / (1000 * 60 * 60);
    const recencyFactor = Math.pow(this.config.confidenceDecayFactor, ageHours / 24);
    weight *= recencyFactor;
    
    // Sample size factor (prefer patterns with more data)
    const sampleSizeFactor = Math.min(1, stats.totalAttempts / 10);
    weight *= (0.5 + 0.5 * sampleSizeFactor);
    
    // Stability mode: Conservative weighting
    if (this.config.stabilityMode) {
      weight *= 0.8; // Reduce all weights to prefer stability
    }
    
    return Math.max(0.1, Math.min(1.0, weight));
  }

  /**
   * Determine if adaptive pattern generation should be triggered
   */
  private shouldGenerateAdaptivePatterns(): boolean {
    if (!this.config.enableLearning || this.config.stabilityMode) return false;
    
    const recentHistory = this.learningHistory.filter(h => 
      Date.now() - h.timestamp < 24 * 60 * 60 * 1000 // Last 24 hours
    );
    
    // Generate patterns if we have enough recent data
    return recentHistory.length > 20 && this.adaptivePatterns.size < 5;
  }

  /**
   * Generate new adaptive patterns from successful patterns
   */
  private generateAdaptivePatterns(): void {
    const successfulPatterns = Array.from(this.patternStats.values())
      .filter(stats => stats.successRate > 0.7 && stats.totalAttempts > 5)
      .sort((a, b) => b.confidence - a.confidence);

    if (successfulPatterns.length < 2) return;

    // Pattern combination (crossover)
    for (let i = 0; i < Math.min(2, successfulPatterns.length); i++) {
      for (let j = i + 1; j < Math.min(3, successfulPatterns.length); j++) {
        const combinedPattern = this.combinePatterns(successfulPatterns[i], successfulPatterns[j]);
        if (combinedPattern) {
          this.adaptivePatterns.set(combinedPattern.id, combinedPattern);
        }
      }
    }

    // Pattern mutation
    successfulPatterns.slice(0, 2).forEach(pattern => {
      const mutatedPattern = this.mutatePattern(pattern);
      if (mutatedPattern) {
        this.adaptivePatterns.set(mutatedPattern.id, mutatedPattern);
      }
    });
  }

  /**
   * Combine two successful patterns into a new adaptive pattern
   */
  private combinePatterns(pattern1: PatternStatistics, pattern2: PatternStatistics): AdaptivePattern | null {
    const combinedFeatures: Record<string, number> = {};
    
    // Combine features with weighted average
    const allFeatureNames = new Set([
      ...Object.keys(pattern1.features),
      ...Object.keys(pattern2.features)
    ]);
    
    for (const featureName of allFeatureNames) {
      const val1 = pattern1.features[featureName] || 0;
      const val2 = pattern2.features[featureName] || 0;
      const weight1 = pattern1.confidence;
      const weight2 = pattern2.confidence;
      
      combinedFeatures[featureName] = (val1 * weight1 + val2 * weight2) / (weight1 + weight2);
    }
    
    const confidence = Math.min(pattern1.confidence, pattern2.confidence) * 0.8; // Conservative
    
    return {
      id: `adaptive-combo-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
      basePatternIds: [pattern1.patternId, pattern2.patternId],
      adaptationType: 'combination',
      features: combinedFeatures,
      confidence,
      generatedAt: Date.now()
    };
  }

  /**
   * Create a mutated version of a successful pattern
   */
  private mutatePattern(pattern: PatternStatistics): AdaptivePattern | null {
    const mutatedFeatures = { ...pattern.features };
    
    // Apply small random mutations to feature values
    const featureNames = Object.keys(mutatedFeatures);
    const numMutations = Math.min(2, featureNames.length);
    
    for (let i = 0; i < numMutations; i++) {
      const featureName = featureNames[Math.floor(Math.random() * featureNames.length)];
      const currentValue = mutatedFeatures[featureName];
      const mutation = (Math.random() - 0.5) * 0.2; // ±10% mutation
      mutatedFeatures[featureName] = Math.max(0, Math.min(1, currentValue + mutation));
    }
    
    const confidence = pattern.confidence * 0.7; // Lower confidence for mutations
    
    return {
      id: `adaptive-mut-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
      basePatternIds: [pattern.patternId],
      adaptationType: 'mutation',
      features: mutatedFeatures,
      confidence,
      generatedAt: Date.now()
    };
  }

  /**
   * Get learning analytics for monitoring and debugging
   */
  getLearningAnalytics(): {
    totalPatterns: number;
    averageSuccessRate: number;
    totalAttempts: number;
    recentActivity: number;
    topFeatures: Array<{ name: string; weight: number }>;
    adaptivePatterns: number;
  } {
    const patterns = Array.from(this.patternStats.values());
    const totalAttempts = patterns.reduce((sum, p) => sum + p.totalAttempts, 0);
    const weightedSuccessRate = patterns.reduce((sum, p) => 
      sum + p.successRate * p.totalAttempts, 0) / Math.max(1, totalAttempts);
    
    const recentActivity = this.learningHistory.filter(h => 
      Date.now() - h.timestamp < 60 * 60 * 1000 // Last hour
    ).length;

    const topFeatures = Array.from(this.featureWeights.values())
      .filter(f => f.sampleSize >= this.config.minSampleSizeForWeight)
      .sort((a, b) => b.weight - a.weight)
      .slice(0, 10)
      .map(f => ({ name: f.featureName, weight: f.weight }));

    return {
      totalPatterns: patterns.length,
      averageSuccessRate: weightedSuccessRate,
      totalAttempts,
      recentActivity,
      topFeatures,
      adaptivePatterns: this.adaptivePatterns.size
    };
  }

  /**
   * Load persisted learning data from storage
   */
  private loadPersistedData(): void {
    try {
      // Skip persistence in server environment (localStorage not available)
      if (typeof window === 'undefined' || typeof localStorage === 'undefined') {
        return;
      }
      const stored = localStorage.getItem('universal-tax-learning-data');
      if (stored) {
        const data = JSON.parse(stored);
        
        // Load pattern statistics
        if (data.patternStats) {
          this.patternStats = new Map(Object.entries(data.patternStats));
        }
        
        // Load feature weights
        if (data.featureWeights) {
          this.featureWeights = new Map(Object.entries(data.featureWeights));
        }
        
        // Load recent history (limited)
        if (data.learningHistory && Array.isArray(data.learningHistory)) {
          this.learningHistory = data.learningHistory.slice(-100); // Keep only recent
        }

        if (this.debugMode) {
          console.log(`📚 [Learning] Loaded ${this.patternStats.size} patterns, ${this.featureWeights.size} features`);
        }
      }
    } catch (error) {
      if (this.debugMode) {
        console.warn('📚 [Learning] Failed to load persisted data:', error);
      }
    }
  }

  /**
   * Persist learning data to storage
   */
  private persistLearningData(): void {
    try {
      const data = {
        patternStats: Object.fromEntries(this.patternStats),
        featureWeights: Object.fromEntries(this.featureWeights),
        learningHistory: this.learningHistory.slice(-100), // Keep only recent
        lastUpdated: Date.now()
      };
      
      // Skip persistence in server environment (localStorage not available)
      if (typeof window !== 'undefined' && typeof localStorage !== 'undefined') {
        localStorage.setItem('universal-tax-learning-data', JSON.stringify(data));
      }
      
      if (this.debugMode) {
        console.log('📚 [Learning] Persisted learning data');
      }
    } catch (error) {
      if (this.debugMode) {
        console.warn('📚 [Learning] Failed to persist data:', error);
      }
    }
  }

  /**
   * Clear all learning data (for testing or reset)
   */
  clearLearningData(): void {
    this.patternStats.clear();
    this.featureWeights.clear();
    this.learningHistory = [];
    this.adaptivePatterns.clear();
    localStorage.removeItem('universal-tax-learning-data');
    
    if (this.debugMode) {
      console.log('📚 [Learning] Cleared all learning data');
    }
  }
}