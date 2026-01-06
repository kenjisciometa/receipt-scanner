/**
 * Tax Breakdown Fusion Engine
 * 
 * Implements the Evidence-Based Fusion System for extracting tax breakdown
 * information and calculating summary values (subtotal, tax, total) from
 * multiple evidence sources.
 */

import { 
  TaxEvidence, 
  EvidenceCluster, 
  ValidationResult, 
  EvidenceBasedExtractedData,
  EvidenceFusionConfig,
  DEFAULT_EVIDENCE_FUSION_CONFIG,
  TaxBreakdown,
  EvidenceSource,
  EvidenceField,
  EvidenceUtils
} from '../../types/evidence';
import { TextLine } from '../../types/receipt-extractor';

export interface SummaryCalculationResult {
  subtotal: number;
  tax_amount: number;
  total: number;
  confidence: number;
  method: string;
  supportingData: any;
}

/**
 * Main engine for evidence-based tax breakdown and summary extraction
 */
export class TaxBreakdownFusionEngine {
  private config: EvidenceFusionConfig;
  private logger: Console;

  constructor(config: Partial<EvidenceFusionConfig> = {}) {
    this.config = { ...DEFAULT_EVIDENCE_FUSION_CONFIG, ...config };
    this.logger = console;
  }

  /**
   * Main entry point for evidence-based extraction
   */
  async extractWithEvidence(textLines: TextLine[]): Promise<EvidenceBasedExtractedData> {
    const startTime = Date.now();
    
    try {
      // Phase 1: Evidence Collection
      const evidenceStartTime = Date.now();
      const allEvidence = await this.collectAllEvidence(textLines);
      const evidenceTime = Date.now() - evidenceStartTime;
      
      this.debugLog('Evidence Collection', {
        totalEvidence: allEvidence.length,
        sources: [...new Set(allEvidence.map(e => e.source))],
        fields: [...new Set(allEvidence.map(e => e.field))],
      });

      // Phase 2: Evidence Validation
      const validationStartTime = Date.now();
      const validationResult = await this.crossValidateEvidence(allEvidence);
      const validationTime = Date.now() - validationStartTime;

      // Phase 3: Evidence Fusion
      const fusionStartTime = Date.now();
      const extractedData = await this.fuseToOptimalValue(validationResult.clusters);
      const fusionTime = Date.now() - fusionStartTime;

      const totalProcessingTime = Date.now() - startTime;

      // Build final result
      const result: EvidenceBasedExtractedData = {
        ...extractedData,
        evidence_summary: {
          totalEvidencePieces: allEvidence.length,
          sourcesUsed: [...new Set(allEvidence.map(e => e.source))],
          averageConfidence: this.calculateAverageConfidence(allEvidence),
          consistencyScore: validationResult.overallConfidence,
          warnings: validationResult.warnings,
        },
        validation: validationResult,
        processingMetadata: {
          evidenceCollectionTime: evidenceTime,
          validationTime: validationTime,
          fusionTime: fusionTime,
          totalProcessingTime: totalProcessingTime,
        },
      };

      this.debugLog('Final Result', result);
      return result;

    } catch (error) {
      this.logger.error('Error in TaxBreakdownFusionEngine:', error);
      throw error;
    }
  }

  /**
   * Phase 1: Collect evidence from all available sources
   */
  private async collectAllEvidence(textLines: TextLine[]): Promise<TaxEvidence[]> {
    const evidence: TaxEvidence[] = [];
    const timestamp = new Date();

    // 1. Table structure evidence
    if (this.config.enabledSources.includes('table')) {
      evidence.push(...await this.extractTableEvidence(textLines, timestamp));
    }

    // 2. Text pattern evidence  
    if (this.config.enabledSources.includes('text')) {
      evidence.push(...await this.extractTextEvidence(textLines, timestamp));
    }

    // 3. Tax breakdown → summary calculation evidence
    if (this.config.enabledSources.includes('summary_calculation')) {
      evidence.push(...await this.extractSummaryCalculationEvidence(textLines, timestamp));
    }

    // 4. Spatial/positional evidence
    if (this.config.enabledSources.includes('spatial_analysis')) {
      evidence.push(...await this.extractPositionalEvidence(textLines, timestamp));
    }

    // 5. Mathematical calculation evidence
    if (this.config.enabledSources.includes('calculation')) {
      evidence.push(...await this.extractMathematicalEvidence(textLines, timestamp));
    }

    // Filter evidence by minimum confidence
    return evidence.filter(e => e.confidence >= this.config.minEvidenceConfidence);
  }

  /**
   * Extract evidence from table structures
   */
  private async extractTableEvidence(textLines: TextLine[], timestamp: Date): Promise<TaxEvidence[]> {
    const evidence: TaxEvidence[] = [];
    
    // Find table-like structures
    const tableRows = this.detectTableRows(textLines);
    
    for (const row of tableRows) {
      // Extract tax rate and amount from table row
      const taxRateMatch = row.text.match(/(\d+(?:[.,]\d+)?)\s*%/);
      const amountMatch = row.text.match(/([€$£¥₹]?\s*\d+[.,]\d{2})/g);
      
      if (taxRateMatch && amountMatch && amountMatch.length > 0) {
        const rate = parseFloat(taxRateMatch[1].replace(',', '.'));
        const amounts = amountMatch.map(a => this.parseAmount(a)).filter(a => a > 0);
        
        if (amounts.length > 0) {
          const amount = amounts[amounts.length - 1]; // Use last amount as tax amount
          
          evidence.push({
            source: 'table',
            field: 'tax_breakdown',
            rate: rate,
            amount: amount,
            confidence: this.calculateTableConfidence(row, rate, amount),
            position: row.boundingBox,
            rawText: row.text,
            supportingData: {
              method: 'table_row_analysis',
              rowIndex: tableRows.indexOf(row),
              amountMatches: amountMatch,
              structuralConsistency: this.assessTableStructure(tableRows)
            },
            timestamp
          });
        }
      }
      
      // Extract summary values from table footer
      if (this.isSummaryRow(row)) {
        const summaryEvidence = this.extractSummaryFromRow(row, timestamp);
        evidence.push(...summaryEvidence);
      }
    }
    
    return evidence;
  }

  /**
   * Extract evidence from text patterns
   */
  private async extractTextEvidence(textLines: TextLine[], timestamp: Date): Promise<TaxEvidence[]> {
    const evidence: TaxEvidence[] = [];
    
    // Enhanced patterns for different languages and formats
    const patterns = [
      // Tax breakdown patterns
      {
        pattern: /(?:tax|vat|mwst|alv|moms|iva|tva)\s*(\d+(?:[.,]\d+)?)\s*%.*?([€$£¥₹]?\s*\d+[.,]\d{2})/gi,
        field: 'tax_breakdown' as EvidenceField
      },
      // Subtotal patterns (multilingual from requirements doc)
      {
        pattern: /(?:subtotal|sub-total|sub total|net|välisumma|alasumma|delsumma|mellansumma|sous-total|montant ht|zwischensumme|netto|subtotale|imponibile|base imponible)\s*:?\s*([€$£¥₹]?\s*\d+[.,]\d{2})/gi,
        field: 'subtotal' as EvidenceField
      },
      // Total patterns (multilingual)
      {
        pattern: /(?:total|sum|amount|grand total|amount due|yhteensä|summa|loppusumma|maksettava|maksu|totalt|att betala|slutsumma|montant total|somme|à payer|net à payer|total ttc|gesamt|betrag|gesamtbetrag|endsumme|zu zahlen|totale|importo|da pagare|totale generale|saldo|importe|a pagar|total general|precio total)\s*:?\s*([€$£¥₹]?\s*\d+[.,]\d{2})/gi,
        field: 'total' as EvidenceField
      },
      // Tax amount patterns
      {
        pattern: /(?:vat|tax|sales tax|alv|arvonlisävero|vero|moms|mervärdesskatt|tva|taxe|mwst|umsatzsteuer|steuer|iva|imposta|impuesto)\s*:?\s*([€$£¥₹]?\s*\d+[.,]\d{2})/gi,
        field: 'tax_amount' as EvidenceField
      }
    ];

    for (const line of textLines) {
      for (const { pattern, field } of patterns) {
        pattern.lastIndex = 0; // Reset regex
        const matches = Array.from(line.text.matchAll(pattern));
        
        for (const match of matches) {
          if (field === 'tax_breakdown' && match[1] && match[2]) {
            // Tax breakdown with rate and amount
            const rate = parseFloat(match[1].replace(',', '.'));
            const amount = this.parseAmount(match[2]);
            
            if (rate > 0 && amount > 0) {
              evidence.push({
                source: 'text',
                field: field,
                rate: rate,
                amount: amount,
                confidence: this.calculateTextPatternConfidence(match, line),
                position: line.boundingBox,
                rawText: match[0],
                supportingData: {
                  method: 'pattern_matching',
                  patternUsed: pattern.source,
                  lineIndex: textLines.indexOf(line)
                },
                timestamp
              });
            }
          } else if (match[1]) {
            // Summary value (subtotal, total, tax_amount)
            const amount = this.parseAmount(match[1]);
            
            if (amount > 0) {
              evidence.push({
                source: 'text',
                field: field,
                amount: amount,
                confidence: this.calculateTextPatternConfidence(match, line),
                position: line.boundingBox,
                rawText: match[0],
                supportingData: {
                  method: 'pattern_matching',
                  patternUsed: pattern.source,
                  lineIndex: textLines.indexOf(line)
                },
                timestamp
              });
            }
          }
        }
      }
    }
    
    return evidence;
  }

  /**
   * Extract Tax Breakdown → Summary calculation evidence (CORE INNOVATION)
   */
  private async extractSummaryCalculationEvidence(textLines: TextLine[], timestamp: Date): Promise<TaxEvidence[]> {
    const evidence: TaxEvidence[] = [];
    
    // First extract raw tax breakdowns from all sources
    const taxBreakdowns = this.extractRawTaxBreakdowns(textLines);
    
    if (taxBreakdowns.length === 0) {
      return evidence;
    }
    
    // Calculate tax total from breakdowns
    const calculatedTaxTotal = taxBreakdowns.reduce((sum, tb) => sum + tb.amount, 0);
    
    // Find total candidates to work backwards from
    const totalCandidates = this.findTotalCandidates(textLines);
    
    for (const total of totalCandidates) {
      // Calculate subtotal = total - tax_total
      const calculatedSubtotal = total - calculatedTaxTotal;
      
      // Validate reasonableness of calculated subtotal
      if (calculatedSubtotal > 0 && calculatedSubtotal > calculatedTaxTotal) {
        // Generate subtotal evidence
        evidence.push({
          source: 'summary_calculation',
          field: 'subtotal',
          amount: calculatedSubtotal,
          confidence: this.calculateSubtotalConfidence(taxBreakdowns, total, calculatedSubtotal),
          rawText: `Calculated from Total(${total}) - TaxTotal(${calculatedTaxTotal}) = ${calculatedSubtotal}`,
          supportingData: {
            method: 'total_minus_tax_breakdown',
            totalUsed: total,
            taxBreakdowns: taxBreakdowns,
            calculatedTaxTotal: calculatedTaxTotal,
            taxRateConsistency: this.checkTaxRateConsistency(taxBreakdowns, calculatedSubtotal)
          },
          timestamp
        });

        // Generate tax evidence (sum of breakdowns)
        evidence.push({
          source: 'summary_calculation',
          field: 'tax_amount',
          amount: calculatedTaxTotal,
          confidence: 0.92, // High confidence as it's direct calculation from breakdowns
          rawText: `Tax total from breakdown: ${taxBreakdowns.map(tb => `${tb.rate}%=${tb.amount}`).join(' + ')} = ${calculatedTaxTotal}`,
          supportingData: {
            method: 'tax_breakdown_sum',
            breakdowns: taxBreakdowns,
            breakdownCount: taxBreakdowns.length
          },
          timestamp
        });

        // Generate total verification evidence
        const recalculatedTotal = calculatedSubtotal + calculatedTaxTotal;
        evidence.push({
          source: 'summary_calculation',
          field: 'total',
          amount: total,
          confidence: this.calculateTotalVerificationConfidence(total, recalculatedTotal),
          rawText: `Total verification: ${calculatedSubtotal} + ${calculatedTaxTotal} = ${recalculatedTotal} (vs original: ${total})`,
          supportingData: {
            method: 'subtotal_plus_tax_verification',
            subtotal: calculatedSubtotal,
            tax: calculatedTaxTotal,
            recalculated: recalculatedTotal,
            deviation: Math.abs(total - recalculatedTotal),
            deviationPercent: Math.abs(total - recalculatedTotal) / total * 100
          },
          timestamp
        });
      }
    }
    
    return evidence;
  }

  /**
   * Extract positional/spatial evidence
   */
  private async extractPositionalEvidence(textLines: TextLine[], timestamp: Date): Promise<TaxEvidence[]> {
    const evidence: TaxEvidence[] = [];
    
    // Find right-aligned amounts (common in receipts)
    const rightAlignedLines = textLines.filter(line => 
      line.boundingBox && (line.boundingBox.x + line.boundingBox.width) > 0.7
    );
    
    for (const line of rightAlignedLines) {
      const amounts = this.extractAmountsFromText(line.text);
      if (amounts.length > 0) {
        // Right-aligned amounts are likely to be totals or subtotals
        const amount = amounts[amounts.length - 1];
        const isLowerSection = line.boundingBox && line.boundingBox.y > 0.6;
        
        evidence.push({
          source: 'spatial_analysis',
          field: isLowerSection ? 'total' : 'subtotal',
          amount: amount,
          confidence: this.calculateSpatialConfidence(line, isLowerSection),
          position: line.boundingBox,
          rawText: line.text,
          supportingData: {
            method: 'right_aligned_analysis',
            alignmentScore: line.boundingBox ? (line.boundingBox.x + line.boundingBox.width) : 0,
            isLowerSection: isLowerSection
          },
          timestamp
        });
      }
    }
    
    return evidence;
  }

  /**
   * Extract mathematical calculation evidence
   */
  private async extractMathematicalEvidence(textLines: TextLine[], timestamp: Date): Promise<TaxEvidence[]> {
    const evidence: TaxEvidence[] = [];
    
    // Find potential subtotal and total pairs for calculation
    const subtotalCandidates = this.findAmountCandidates(textLines, ['subtotal', 'sub-total', 'net']);
    const totalCandidates = this.findAmountCandidates(textLines, ['total', 'sum', 'amount']);
    
    for (const subtotal of subtotalCandidates) {
      for (const total of totalCandidates) {
        if (total.amount > subtotal.amount) {
          const calculatedTax = total.amount - subtotal.amount;
          const calculatedRate = (calculatedTax / subtotal.amount) * 100;
          
          // Check if calculated rate is reasonable
          if (calculatedRate >= this.config.minTaxRatePercent && 
              calculatedRate <= this.config.maxTaxRatePercent) {
            
            evidence.push({
              source: 'calculation',
              field: 'tax_amount',
              amount: calculatedTax,
              rate: calculatedRate,
              confidence: this.calculateMathematicalConfidence(subtotal, total, calculatedTax),
              rawText: `Calculated from Total(${total.amount}) - Subtotal(${subtotal.amount}) = ${calculatedTax}`,
              supportingData: {
                method: 'total_minus_subtotal',
                subtotalUsed: subtotal,
                totalUsed: total,
                calculatedRate: calculatedRate
              },
              timestamp
            });
          }
        }
      }
    }
    
    return evidence;
  }

  /**
   * Phase 2: Cross-validate evidence and create clusters
   */
  private async crossValidateEvidence(evidence: TaxEvidence[]): Promise<ValidationResult> {
    const clusters = this.clusterSimilarEvidence(evidence);
    const warnings: string[] = [];
    let mathematicalConsistency = 0;
    let spatialConsistency = 0;
    
    for (const cluster of clusters) {
      // Mathematical consistency check
      const mathScore = this.checkMathematicalConsistency(cluster);
      mathematicalConsistency += mathScore;
      
      // Spatial consistency check  
      const spatialScore = this.checkSpatialConsistency(cluster);
      spatialConsistency += spatialScore;
      
      // Tax breakdown consistency check
      const taxBreakdownScore = this.checkTaxBreakdownConsistency(cluster);
      
      // Calculate consolidated confidence
      cluster.consolidatedConfidence = this.calculateConsolidatedConfidence(
        mathScore, spatialScore, taxBreakdownScore, cluster.evidence
      );
      
      // Check if cluster passes consistency thresholds
      cluster.isConsistent = cluster.consolidatedConfidence >= this.config.minClusterConfidence;
      
      if (!cluster.isConsistent) {
        warnings.push(`Low confidence cluster for ${cluster.type}: ${cluster.consolidatedConfidence.toFixed(2)}`);
      }
    }
    
    const validClusters = clusters.filter(c => c.isConsistent);
    const overallConfidence = validClusters.length > 0 
      ? validClusters.reduce((sum, c) => sum + c.consolidatedConfidence, 0) / validClusters.length
      : 0;
    
    return {
      clusters: validClusters,
      overallConfidence,
      checksPerformed: ['mathematical', 'spatial', 'tax_breakdown'],
      warnings,
      mathematicalConsistency: mathematicalConsistency / clusters.length,
      spatialConsistency: spatialConsistency / clusters.length,
    };
  }

  /**
   * Phase 3: Fuse evidence to optimal values
   */
  private async fuseToOptimalValue(clusters: EvidenceCluster[]): Promise<Partial<EvidenceBasedExtractedData>> {
    const result: any = {};
    
    // Fuse tax breakdowns
    const taxBreakdownCluster = clusters.find(c => c.type === 'tax_breakdown');
    if (taxBreakdownCluster) {
      result.tax_breakdown = this.fuseTaxBreakdowns(taxBreakdownCluster);
      result.tax_total = result.tax_breakdown.reduce((sum: number, tb: TaxBreakdown) => sum + tb.amount, 0);
    }
    
    // Fuse summary values
    result.subtotal = this.fuseNumericValue(clusters, 'subtotal');
    result.tax_amount = this.fuseNumericValue(clusters, 'tax_amount');
    result.total = this.fuseNumericValue(clusters, 'total');
    
    // Perform final consistency check
    if (result.subtotal && result.tax_amount && result.total) {
      const calculatedTotal = result.subtotal + result.tax_amount;
      const deviation = Math.abs(calculatedTotal - result.total);
      const deviationPercent = (deviation / result.total) * 100;
      
      if (deviationPercent > this.config.mathematicalTolerancePercent) {
        // If inconsistent, trust the tax breakdown calculation
        if (result.tax_breakdown && result.tax_breakdown.length > 0) {
          result.tax_amount = result.tax_total;
          result.subtotal = result.total - result.tax_amount;
        }
      }
    }
    
    return result;
  }

  // === UTILITY METHODS ===

  private clusterSimilarEvidence(evidence: TaxEvidence[]): EvidenceCluster[] {
    const clusters: EvidenceCluster[] = [];
    
    for (const item of evidence) {
      if (!item.field) continue;
      
      // Find existing cluster for this field
      let cluster = clusters.find(c => c.type === item.field);
      
      if (!cluster) {
        // Create new cluster
        cluster = {
          type: item.field,
          evidence: [item],
          centroid: {
            rate: item.rate,
            amount: item.amount,
            value: item.value
          },
          consolidatedConfidence: item.confidence,
          variance: 0,
          isConsistent: true
        };
        clusters.push(cluster);
      } else {
        // Check if evidence is similar enough to add to cluster
        const similarity = this.calculateEvidenceSimilarity(item, cluster);
        if (similarity >= this.config.similarityThreshold) {
          cluster.evidence.push(item);
          this.updateClusterCentroid(cluster);
        } else {
          // Create a new cluster for dissimilar evidence
          clusters.push({
            type: item.field,
            evidence: [item],
            centroid: { rate: item.rate, amount: item.amount, value: item.value },
            consolidatedConfidence: item.confidence,
            variance: 0,
            isConsistent: true
          });
        }
      }
    }
    
    // Calculate variance for each cluster
    clusters.forEach(cluster => {
      cluster.variance = this.calculateClusterVariance(cluster);
    });
    
    return clusters;
  }

  private checkMathematicalConsistency(cluster: EvidenceCluster): number {
    if (cluster.evidence.length === 0) return 0;
    
    let consistencyScore = 0;
    let validChecks = 0;
    
    // For tax breakdown evidence, check rate-amount consistency
    if (cluster.type === 'tax_breakdown') {
      for (const evidence of cluster.evidence) {
        if (evidence.rate && evidence.amount && evidence.supportingData?.subtotal) {
          const expectedAmount = evidence.supportingData.subtotal * evidence.rate / 100;
          const deviation = Math.abs(expectedAmount - evidence.amount) / evidence.amount;
          consistencyScore += Math.max(0, 1 - deviation);
          validChecks++;
        }
      }
    }
    
    // Check variance within cluster
    const values = cluster.evidence
      .map(e => e.amount || 0)
      .filter(v => v > 0);
    
    if (values.length > 1) {
      const variance = this.calculateVariance(values);
      const mean = values.reduce((sum, v) => sum + v, 0) / values.length;
      const coefficientOfVariation = Math.sqrt(variance) / mean;
      consistencyScore += Math.max(0, 1 - coefficientOfVariation);
      validChecks++;
    }
    
    return validChecks > 0 ? consistencyScore / validChecks : 0.5;
  }

  private checkSpatialConsistency(cluster: EvidenceCluster): number {
    const evidenceWithPosition = cluster.evidence.filter(e => e.position);
    if (evidenceWithPosition.length < 2) return 0.8; // Default score if insufficient spatial data
    
    // Calculate spatial clustering
    let totalDistance = 0;
    let comparisons = 0;
    
    for (let i = 0; i < evidenceWithPosition.length - 1; i++) {
      for (let j = i + 1; j < evidenceWithPosition.length; j++) {
        const pos1 = evidenceWithPosition[i].position!;
        const pos2 = evidenceWithPosition[j].position!;
        
        const distance = Math.sqrt(
          Math.pow(pos1.x - pos2.x, 2) + Math.pow(pos1.y - pos2.y, 2)
        );
        
        totalDistance += distance;
        comparisons++;
      }
    }
    
    if (comparisons === 0) return 0.8;
    
    const avgDistance = totalDistance / comparisons;
    const tolerance = this.config.spatialTolerancePixels / 100; // Normalize to 0-1 range
    
    return Math.max(0, 1 - (avgDistance / tolerance));
  }

  private checkTaxBreakdownConsistency(cluster: EvidenceCluster): number {
    if (cluster.type !== 'tax_breakdown') return 1.0;
    
    // Check if tax rates are within reasonable bounds
    const rates = cluster.evidence
      .map(e => e.rate)
      .filter(r => r != null) as number[];
    
    let reasonableRates = 0;
    for (const rate of rates) {
      if (rate >= this.config.minTaxRatePercent && rate <= this.config.maxTaxRatePercent) {
        reasonableRates++;
      }
    }
    
    return rates.length > 0 ? reasonableRates / rates.length : 1.0;
  }

  private calculateConsolidatedConfidence(
    mathScore: number, 
    spatialScore: number, 
    taxBreakdownScore: number,
    evidence: TaxEvidence[]
  ): number {
    // Base confidence is weighted average of evidence confidences
    const baseConfidence = evidence.reduce((sum, e) => sum + e.confidence, 0) / evidence.length;
    
    // Apply source weights
    const weightedConfidence = evidence.reduce((sum, e) => {
      const weight = this.config.sourceWeights[e.source] || 1.0;
      return sum + (e.confidence * weight);
    }, 0) / evidence.reduce((sum, e) => sum + (this.config.sourceWeights[e.source] || 1.0), 0);
    
    // Combine with consistency scores
    const consistencyBonus = (mathScore + spatialScore + taxBreakdownScore) / 3 * 0.1;
    
    return Math.min(0.95, weightedConfidence + consistencyBonus);
  }

  private fuseTaxBreakdowns(cluster: EvidenceCluster): TaxBreakdown[] {
    const breakdownMap = new Map<string, TaxEvidence[]>();
    
    // Group by rate (rounded to nearest 0.1%)
    for (const evidence of cluster.evidence) {
      if (evidence.rate != null && evidence.amount != null) {
        const roundedRate = Math.round(evidence.rate * 10) / 10;
        const key = roundedRate.toString();
        
        if (!breakdownMap.has(key)) {
          breakdownMap.set(key, []);
        }
        breakdownMap.get(key)!.push(evidence);
      }
    }
    
    // Fuse each rate group
    const result: TaxBreakdown[] = [];
    for (const [rateStr, evidenceList] of breakdownMap) {
      const rate = parseFloat(rateStr);
      const amount = EvidenceUtils.calculateWeightedAverage(evidenceList, 'amount') || 0;
      const confidence = evidenceList.reduce((sum, e) => sum + e.confidence, 0) / evidenceList.length;
      
      result.push({
        rate,
        amount: Math.round(amount * 100) / 100,
        confidence,
        supportingEvidence: evidenceList.length
      });
    }
    
    return result.sort((a, b) => a.rate - b.rate);
  }

  private fuseNumericValue(clusters: EvidenceCluster[], field: EvidenceField): number | undefined {
    const cluster = clusters.find(c => c.type === field);
    if (!cluster || cluster.evidence.length === 0) return undefined;
    
    // Use weighted average, removing outliers
    const cleanedEvidence = EvidenceUtils.removeOutliers(cluster.evidence, 'amount');
    const weightedAverage = EvidenceUtils.calculateWeightedAverage(cleanedEvidence, 'amount');
    
    return weightedAverage ? Math.round(weightedAverage * 100) / 100 : undefined;
  }

  // === TAX BREAKDOWN → SUMMARY CALCULATION HELPERS ===

  private extractRawTaxBreakdowns(textLines: TextLine[]): Array<{rate: number, amount: number}> {
    const breakdowns: Array<{rate: number, amount: number}> = [];
    
    // Look for patterns like "14% VAT $12.50"
    const taxPattern = /(\d+(?:[.,]\d+)?)\s*%.*?([€$£¥₹]?\s*\d+[.,]\d{2})/g;
    
    for (const line of textLines) {
      const matches = Array.from(line.text.matchAll(taxPattern));
      for (const match of matches) {
        const rate = parseFloat(match[1].replace(',', '.'));
        const amount = this.parseAmount(match[2]);
        
        if (rate > 0 && amount > 0 && rate <= this.config.maxTaxRatePercent) {
          breakdowns.push({ rate, amount });
        }
      }
    }
    
    return breakdowns;
  }

  private findTotalCandidates(textLines: TextLine[]): number[] {
    const candidates: number[] = [];
    const totalPattern = /(?:total|sum|amount)\s*:?\s*([€$£¥₹]?\s*\d+[.,]\d{2})/gi;
    
    for (const line of textLines) {
      const matches = Array.from(line.text.matchAll(totalPattern));
      for (const match of matches) {
        const amount = this.parseAmount(match[1]);
        if (amount > 0) {
          candidates.push(amount);
        }
      }
    }
    
    // Return unique values, sorted by value
    return [...new Set(candidates)].sort((a, b) => b - a);
  }

  private checkTaxRateConsistency(taxBreakdowns: Array<{rate: number, amount: number}>, subtotal: number): number {
    if (subtotal <= 0) return 0;
    
    let consistencyScore = 0;
    for (const breakdown of taxBreakdowns) {
      const expectedAmount = subtotal * breakdown.rate / 100;
      const deviation = Math.abs(expectedAmount - breakdown.amount) / breakdown.amount;
      consistencyScore += Math.max(0, 1 - deviation);
    }
    
    return taxBreakdowns.length > 0 ? consistencyScore / taxBreakdowns.length : 0;
  }

  private calculateSubtotalConfidence(
    taxBreakdowns: Array<{rate: number, amount: number}>, 
    total: number, 
    calculatedSubtotal: number
  ): number {
    let confidence = 0.8; // Base confidence
    
    // Tax breakdown count bonus
    if (taxBreakdowns.length >= 2) confidence += 0.05;
    
    // Rate reasonableness check
    const reasonableRates = taxBreakdowns.filter(tb => 
      tb.rate >= 0 && tb.rate <= this.config.maxTaxRatePercent
    ).length;
    confidence += (reasonableRates / taxBreakdowns.length) * 0.05;
    
    // Subtotal ratio check
    const subtotalRatio = calculatedSubtotal / total;
    if (subtotalRatio >= 0.7 && subtotalRatio <= 0.95) {
      confidence += 0.05;
    }
    
    return Math.min(0.95, confidence);
  }

  private calculateTotalVerificationConfidence(original: number, recalculated: number): number {
    const deviation = Math.abs(original - recalculated) / original;
    return Math.max(0.5, 0.95 - (deviation * 2));
  }

  // === BASIC UTILITY METHODS ===

  private parseAmount(text: string): number {
    const cleanText = text.replace(/[€$£¥₹\s]/g, '').replace(',', '.');
    const amount = parseFloat(cleanText);
    return isNaN(amount) ? 0 : Math.abs(amount);
  }

  private calculateAverageConfidence(evidence: TaxEvidence[]): number {
    if (evidence.length === 0) return 0;
    return evidence.reduce((sum, e) => sum + e.confidence, 0) / evidence.length;
  }

  private calculateVariance(values: number[]): number {
    if (values.length === 0) return 0;
    const mean = values.reduce((sum, v) => sum + v, 0) / values.length;
    return values.reduce((sum, v) => sum + Math.pow(v - mean, 2), 0) / values.length;
  }

  private debugLog(phase: string, data: any): void {
    if (this.config.enableDebugLogging) {
      this.logger.log(`[TaxBreakdownFusionEngine] ${phase}:`, data);
    }
  }

  // === PLACEHOLDER METHODS (TO BE IMPLEMENTED) ===

  private detectTableRows(textLines: TextLine[]): TextLine[] {
    // TODO: Implement sophisticated table detection
    return textLines.filter(line => line.text.includes('%') || line.text.match(/\d+[.,]\d{2}/));
  }

  private calculateTableConfidence(row: TextLine, rate: number, amount: number): number {
    // TODO: Implement table structure confidence calculation
    return 0.85;
  }

  private assessTableStructure(tableRows: TextLine[]): number {
    // TODO: Implement table structure assessment
    return 0.8;
  }

  private isSummaryRow(row: TextLine): boolean {
    return /(?:subtotal|total|tax|sum)/i.test(row.text);
  }

  private extractSummaryFromRow(row: TextLine, timestamp: Date): TaxEvidence[] {
    // TODO: Implement summary extraction from table rows
    return [];
  }

  private calculateTextPatternConfidence(match: RegExpMatchArray, line: TextLine): number {
    // TODO: Implement pattern match confidence calculation
    return 0.75;
  }

  private extractAmountsFromText(text: string): number[] {
    const amounts: number[] = [];
    const amountPattern = /([€$£¥₹]?\s*\d+[.,]\d{2})/g;
    const matches = text.match(amountPattern);
    
    if (matches) {
      for (const match of matches) {
        const amount = this.parseAmount(match);
        if (amount > 0) amounts.push(amount);
      }
    }
    
    return amounts;
  }

  private calculateSpatialConfidence(line: TextLine, isLowerSection: boolean): number {
    // TODO: Implement spatial confidence calculation
    return isLowerSection ? 0.8 : 0.6;
  }

  private findAmountCandidates(textLines: TextLine[], keywords: string[]): Array<{amount: number, line: TextLine}> {
    const candidates: Array<{amount: number, line: TextLine}> = [];
    
    for (const line of textLines) {
      if (keywords.some(keyword => line.text.toLowerCase().includes(keyword))) {
        const amounts = this.extractAmountsFromText(line.text);
        for (const amount of amounts) {
          candidates.push({ amount, line });
        }
      }
    }
    
    return candidates;
  }

  private calculateMathematicalConfidence(
    subtotal: {amount: number, line: TextLine}, 
    total: {amount: number, line: TextLine}, 
    calculatedTax: number
  ): number {
    // TODO: Implement mathematical confidence calculation
    return 0.8;
  }

  private calculateEvidenceSimilarity(evidence: TaxEvidence, cluster: EvidenceCluster): number {
    // Use the utility function
    if (cluster.evidence.length === 0) return 0;
    
    const similarities = cluster.evidence.map(e => 
      EvidenceUtils.calculateSimilarity(evidence, e)
    );
    
    return Math.max(...similarities);
  }

  private updateClusterCentroid(cluster: EvidenceCluster): void {
    if (cluster.evidence.length === 0) return;
    
    const amounts = cluster.evidence.map(e => e.amount).filter(a => a != null) as number[];
    const rates = cluster.evidence.map(e => e.rate).filter(r => r != null) as number[];
    
    if (amounts.length > 0) {
      cluster.centroid.amount = amounts.reduce((sum, a) => sum + a, 0) / amounts.length;
    }
    
    if (rates.length > 0) {
      cluster.centroid.rate = rates.reduce((sum, r) => sum + r, 0) / rates.length;
    }
  }

  private calculateClusterVariance(cluster: EvidenceCluster): number {
    if (cluster.evidence.length <= 1) return 0;
    
    const amounts = cluster.evidence.map(e => e.amount).filter(a => a != null) as number[];
    return amounts.length > 1 ? this.calculateVariance(amounts) : 0;
  }
}