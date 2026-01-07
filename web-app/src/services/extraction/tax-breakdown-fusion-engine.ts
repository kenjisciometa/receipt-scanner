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
import { TextLine } from '../../types/ocr';
import { TaxBreakdownLocalizationService } from './tax-breakdown-localization';
import { MultilingualPatternGenerator } from '@/services/patterns/multilingual-pattern-generator';
import { CentralizedKeywordConfig, ExtendedFieldType } from '@/services/keywords/centralized-keyword-config';
import { SupportedLanguage } from '@/services/keywords/language-keywords';
import { CurrencyExtractor, CurrencyInfo } from './currency-extractor';

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

    // 6. Currency detection evidence
    const currencyEvidence = this.extractCurrencyEvidence(textLines, timestamp);
    if (currencyEvidence) {
      evidence.push(currencyEvidence);
    }

    // Filter evidence by minimum confidence
    return evidence.filter(e => e.confidence >= this.config.minEvidenceConfidence);
  }

  /**
   * Extract evidence from table structures using enhanced tax table detector
   */
  private async extractTableEvidence(textLines: TextLine[], timestamp: Date): Promise<TaxEvidence[]> {
    const evidence: TaxEvidence[] = [];
    
    try {
      // Use Enhanced Tax Table Detector for comprehensive analysis
      const { EnhancedTaxTableDetector } = await import('./enhanced-tax-table-detector');
      const tableDetector = new EnhancedTaxTableDetector();
      const detectedTables = await tableDetector.detectTaxTables(textLines);
      
      console.log(`🔍 [TableEvidence] Detected ${detectedTables.length} tax tables`);
      
      // Convert detected tables to evidence
      for (const table of detectedTables) {
        console.log(`📊 [TableEvidence] Processing table with ${table.rows.length} rows`);
        
        // Extract tax breakdown evidence from table rows
        for (const row of table.rows) {
          const taxEvidence = {
            source: 'table' as EvidenceSource,
            field: 'tax_breakdown' as EvidenceField,
            rate: row.rate,
            amount: row.tax,
            confidence: row.confidence * table.confidence, // Combined confidence
            position: [0, 0, 0, 0] as [number, number, number, number], // Simplified for now
            rawText: `${row.code} ${row.rate}% ${row.gross} ${row.net} ${row.tax}`,
            supportingData: {
              method: 'enhanced_table_detection',
              tableId: table.id,
              rowCode: row.code,
              grossAmount: row.gross,
              netAmount: row.net,
              taxAmount: row.tax,
              mathematicalValidation: row.validationResults,
              tableConfidence: table.confidence
            },
            timestamp
          };
          
          console.log(`✅ [TableEvidence] Adding tax evidence: ${row.rate}% = ${row.tax}`);
          evidence.push(taxEvidence);
        }
        
        // Extract subtotal evidence from table totals
        if (table.totals.totalNet > 0) {
          evidence.push({
            source: 'table',
            field: 'subtotal',
            amount: table.totals.totalNet,
            confidence: table.totals.confidence * table.confidence,
            position: [0, 0, 0, 0] as [number, number, number, number],
            rawText: `Table calculated subtotal: ${table.totals.totalNet}`,
            supportingData: {
              method: 'table_totals_calculation',
              tableId: table.id,
              calculatedFromRows: table.totals.calculatedFromRows,
              rowCount: table.rows.length,
              totalGross: table.totals.totalGross,
              totalTax: table.totals.totalTax
            },
            timestamp
          });
        }
        
        // Extract tax total evidence from table totals
        if (table.totals.totalTax > 0) {
          evidence.push({
            source: 'table',
            field: 'tax_amount',
            amount: table.totals.totalTax,
            confidence: table.totals.confidence * table.confidence,
            position: [0, 0, 0, 0] as [number, number, number, number],
            rawText: `Table calculated tax total: ${table.totals.totalTax}`,
            supportingData: {
              method: 'table_totals_calculation',
              tableId: table.id,
              calculatedFromRows: table.totals.calculatedFromRows,
              rowCount: table.rows.length,
              breakdown: table.rows.map(row => ({
                rate: row.rate,
                tax: row.tax,
                net: row.net
              }))
            },
            timestamp
          });
        }
        
        // Extract total evidence if available (gross total)
        if (table.totals.totalGross > 0) {
          evidence.push({
            source: 'table',
            field: 'total',
            amount: table.totals.totalGross,
            confidence: table.totals.confidence * table.confidence * 0.8, // Slightly lower confidence for derived total
            position: [0, 0, 0, 0] as [number, number, number, number],
            rawText: `Table calculated total: ${table.totals.totalGross}`,
            supportingData: {
              method: 'table_totals_calculation',
              tableId: table.id,
              calculatedFromRows: table.totals.calculatedFromRows,
              derivedFromSubtotalAndTax: true
            },
            timestamp
          });
        }
      }
      
    } catch (error) {
      console.warn(`⚠️ [TableEvidence] Enhanced detector failed, falling back to basic detection:`, error);
      
      // Fallback to basic table detection
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
                method: 'fallback_table_row_analysis',
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
    }
    
    console.log(`📊 [TableEvidence] Generated ${evidence.length} evidence pieces from tables`);
    return evidence;
  }

  /**
   * Extract evidence from text patterns using unified pattern generation
   */
  private async extractTextEvidence(textLines: TextLine[], timestamp: Date): Promise<TaxEvidence[]> {
    const evidence: TaxEvidence[] = [];
    
    // Get unified patterns using the new multilingual system
    const patterns = this.getUnifiedTextPatterns();

    // Direct tax breakdown extraction for US-style receipts like Walmart
    this.extractDirectTaxBreakdown(textLines, evidence, timestamp);

    for (const line of textLines) {
      for (const { pattern, field } of patterns) {
        pattern.lastIndex = 0; // Reset regex
        const matches = Array.from(line.text.matchAll(pattern));
        
        // Debug tax breakdown pattern matching
        if (field === 'tax_breakdown' && line.text.toLowerCase().includes('tax')) {
          console.log(`🎯 [TaxBreakdown] Pattern: ${pattern.source.substring(0, 100)}... testing line: "${line.text}" → matches: ${matches.length}`);
          if (matches.length > 0) {
            matches.forEach((match, i) => {
              console.log(`   Match ${i}: full="${match[0]}" rate="${match[1]}" amount="${match[2]}"`);
            });
          }
        }
        
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
   * Enhanced for US-style receipt layout recognition
   */
  private async extractPositionalEvidence(textLines: TextLine[], timestamp: Date): Promise<TaxEvidence[]> {
    const evidence: TaxEvidence[] = [];
    
    // Enhanced right-aligned detection for US receipts
    const rightAlignedLines = textLines.filter(line => {
      if (!line.boundingBox) return false;
      
      // US receipts typically have amounts aligned at 0.65+ (more lenient threshold)
      const rightAlignment = (line.boundingBox[0] + line.boundingBox[2]) > 0.65;
      
      // Also check for consistent right margin alignment across multiple lines
      return rightAlignment && this.containsAmountPattern(line.text);
    });
    
    // Group lines by vertical sections for better field identification
    const upperSection = rightAlignedLines.filter(line => line.boundingBox && line.boundingBox[1] <= 0.4);
    const middleSection = rightAlignedLines.filter(line => line.boundingBox && line.boundingBox[1] > 0.4 && line.boundingBox[1] <= 0.7);
    const lowerSection = rightAlignedLines.filter(line => line.boundingBox && line.boundingBox[1] > 0.7);
    
    // Process each section with different field prioritization
    this.processRightAlignedSection(upperSection, 'upper', evidence, timestamp);
    this.processRightAlignedSection(middleSection, 'middle', evidence, timestamp);
    this.processRightAlignedSection(lowerSection, 'lower', evidence, timestamp);
    
    // Enhanced US-style keyword-based spatial analysis
    this.analyzeUSStyleKeywordPositions(textLines, evidence, timestamp);
    
    return evidence;
  }

  /**
   * Process right-aligned section with enhanced field detection
   */
  private processRightAlignedSection(lines: TextLine[], section: 'upper' | 'middle' | 'lower', evidence: TaxEvidence[], timestamp: Date): void {
    for (const line of lines) {
      const amounts = this.extractAmountsFromText(line.text);
      if (amounts.length === 0) continue;
      
      const amount = amounts[amounts.length - 1];
      let field: EvidenceField;
      let confidence = 0.6; // Base confidence
      
      // Enhanced field determination based on section and keywords
      if (section === 'upper') {
        // Upper section likely contains item prices or subtotal
        field = this.containsKeywords(line.text, ['subtotal', 'sub-total', 'sub total', 'net', 'merchandise total']) ? 'subtotal' : 'subtotal';
        confidence = this.containsKeywords(line.text, ['subtotal', 'sub-total', 'sub total']) ? 0.85 : 0.65;
      } else if (section === 'middle') {
        // Middle section likely contains tax information
        if (this.containsKeywords(line.text, ['tax', 'vat', 'sales tax', 'state tax', 'local tax'])) {
          field = 'tax_amount';
          confidence = 0.8;
        } else {
          field = 'subtotal';
          confidence = 0.7;
        }
      } else { // lower section
        // Lower section likely contains total, but check for subtotal/tax keywords first
        if (this.containsKeywords(line.text, ['subtotal', 'sub-total', 'sub total', 'net', 'merchandise total'])) {
          field = 'subtotal';
          confidence = 0.85;
        } else if (this.containsKeywords(line.text, ['tax', 'vat', 'sales tax', 'state tax', 'local tax'])) {
          field = 'tax_amount';
          confidence = 0.8;
        } else if (this.containsKeywords(line.text, ['total', 'grand total', 'amount due', 'balance due'])) {
          field = 'total';
          confidence = 0.9;
        } else if (this.containsKeywords(line.text, ['change', 'change due', 'cash back'])) {
          field = 'total'; // Might be change, but we treat as total for now
          confidence = 0.75;
        } else {
          // Don't default to total unless we're confident it's actually a total
          // Skip lines that don't match known patterns
          continue;
        }
      }
      
      evidence.push({
        source: 'spatial_analysis',
        field: field,
        amount: amount,
        confidence: this.calculateEnhancedSpatialConfidence(line, section, confidence),
        position: line.boundingBox,
        rawText: line.text,
        supportingData: {
          method: 'enhanced_right_aligned_analysis',
          section: section,
          alignmentScore: line.boundingBox ? (line.boundingBox[0] + line.boundingBox[2]) : 0,
          keywordMatches: this.findMatchingKeywords(line.text),
          usStyleLayout: true
        },
        timestamp
      });
    }
  }

  /**
   * Analyze US-style keyword positions for better field detection
   */
  private analyzeUSStyleKeywordPositions(textLines: TextLine[], evidence: TaxEvidence[], timestamp: Date): void {
    // US receipts often have keywords on left, amounts on right
    const keywordAmountPairs = this.findUSStyleKeywordAmountPairs(textLines);
    
    for (const pair of keywordAmountPairs) {
      const { keywordLine, amountLine, field, confidence } = pair;
      const amounts = this.extractAmountsFromText(amountLine.text);
      
      if (amounts.length > 0) {
        const amount = amounts[amounts.length - 1];
        
        evidence.push({
          source: 'spatial_analysis',
          field: field,
          amount: amount,
          confidence: confidence,
          position: amountLine.boundingBox,
          rawText: `${keywordLine.text} → ${amountLine.text}`,
          supportingData: {
            method: 'us_style_keyword_amount_pairing',
            keywordText: keywordLine.text,
            amountText: amountLine.text,
            verticalDistance: amountLine.boundingBox && keywordLine.boundingBox ? 
              Math.abs(amountLine.boundingBox[1] - keywordLine.boundingBox[1]) : 0
          },
          timestamp
        });
      }
    }
  }

  /**
   * Find US-style keyword-amount pairs (keyword left, amount right)
   */
  private findUSStyleKeywordAmountPairs(textLines: TextLine[]): Array<{
    keywordLine: TextLine;
    amountLine: TextLine;
    field: EvidenceField;
    confidence: number;
  }> {
    const pairs: Array<{keywordLine: TextLine; amountLine: TextLine; field: EvidenceField; confidence: number}> = [];
    
    // Define keyword patterns for US receipts
    const fieldKeywords: Array<{keywords: string[]; field: EvidenceField; confidence: number}> = [
      { keywords: ['subtotal', 'sub-total', 'sub total', 'merchandise total', 'items total'], field: 'subtotal', confidence: 0.85 },
      { keywords: ['sales tax', 'state tax', 'local tax', 'tax', 'total tax'], field: 'tax_amount', confidence: 0.8 },
      { keywords: ['total', 'grand total', 'amount due', 'balance due', 'final amount'], field: 'total', confidence: 0.9 }
    ];
    
    for (let i = 0; i < textLines.length; i++) {
      const line = textLines[i];
      
      for (const { keywords, field, confidence } of fieldKeywords) {
        if (this.containsKeywords(line.text, keywords)) {
          // Look for amount on same line or nearby lines
          const candidates = [line]; // Same line
          if (i + 1 < textLines.length) candidates.push(textLines[i + 1]); // Next line
          if (i - 1 >= 0) candidates.push(textLines[i - 1]); // Previous line
          
          for (const candidate of candidates) {
            if (this.containsAmountPattern(candidate.text) && 
                candidate.boundingBox && (candidate.boundingBox[0] + candidate.boundingBox[2]) > 0.6) {
              pairs.push({
                keywordLine: line,
                amountLine: candidate,
                field: field,
                confidence: candidate === line ? confidence : confidence * 0.9 // Slight penalty for different lines
              });
              break; // Found pair, move to next keyword
            }
          }
        }
      }
    }
    
    return pairs;
  }

  /**
   * Check if text contains amount pattern
   * Enhanced to support USD prefix and other currency formats
   */
  private containsAmountPattern(text: string): boolean {
    const patterns = [
      /\$\s*\d+[.,]\d{2}/,                    // USD prefix: $123.45
      /\d+[.,]\d{2}\s*[€£¥₹]/,              // Suffix currencies: 123.45€
      /\b\d+[.,]\d{2}\b/                      // Standalone amounts: 123.45
    ];
    
    return patterns.some(pattern => pattern.test(text));
  }

  /**
   * Check if text contains specific keywords
   */
  private containsKeywords(text: string, keywords: string[]): boolean {
    const normalizedText = text.toLowerCase();
    return keywords.some(keyword => normalizedText.includes(keyword.toLowerCase()));
  }

  /**
   * Find matching keywords in text
   */
  private findMatchingKeywords(text: string): string[] {
    const allKeywords = [
      'subtotal', 'sub-total', 'sub total', 'merchandise total', 'items total',
      'sales tax', 'state tax', 'local tax', 'tax', 'total tax',
      'total', 'grand total', 'amount due', 'balance due', 'final amount',
      'change', 'change due', 'cash back'
    ];
    
    const normalizedText = text.toLowerCase();
    return allKeywords.filter(keyword => normalizedText.includes(keyword.toLowerCase()));
  }

  /**
   * Calculate enhanced spatial confidence with section awareness
   */
  private calculateEnhancedSpatialConfidence(line: TextLine, section: 'upper' | 'middle' | 'lower', baseConfidence: number): number {
    let confidence = baseConfidence;
    
    // Bonus for strong right alignment (more confidence in US-style receipts)
    if (line.boundingBox) {
      const alignmentScore = line.boundingBox[0] + line.boundingBox[2];
      if (alignmentScore > 0.8) confidence += 0.1;
      if (alignmentScore > 0.9) confidence += 0.05;
    }
    
    // Section-based adjustments
    if (section === 'lower') confidence += 0.05; // Lower section more likely to have important totals
    if (section === 'upper') confidence -= 0.05; // Upper section might have item prices
    
    return Math.min(confidence, 0.95);
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
    
    // Fuse tax breakdowns first
    const taxBreakdownCluster = clusters.find(c => c.type === 'tax_breakdown');
    if (taxBreakdownCluster) {
      result.tax_breakdown = this.fuseTaxBreakdowns(taxBreakdownCluster);
      result.tax_total = result.tax_breakdown.reduce((sum: number, tb: TaxBreakdown) => sum + tb.amount, 0);
      console.log(`💰 [FuseToOptimalValue] Tax breakdown total: ${result.tax_total} from ${result.tax_breakdown.length} breakdowns`);
    }
    
    // Fuse summary values
    result.subtotal = this.fuseNumericValue(clusters, 'subtotal');
    result.tax_amount = this.fuseNumericValue(clusters, 'tax_amount');
    result.total = this.fuseNumericValue(clusters, 'total');
    
    // If we have tax breakdown total but no tax_amount, use the breakdown total
    if (result.tax_total !== undefined && result.tax_amount === undefined) {
      console.log(`🔄 [FuseToOptimalValue] Using tax breakdown total as tax_amount: ${result.tax_total}`);
      result.tax_amount = result.tax_total;
    }
    
    // If we have both, verify they're consistent and prefer the breakdown total if available
    if (result.tax_total !== undefined && result.tax_amount !== undefined) {
      const deviation = Math.abs(result.tax_total - result.tax_amount);
      if (deviation > 0.02) { // More than 2 cents difference
        console.log(`⚠️ [FuseToOptimalValue] Tax amount mismatch: breakdown=${result.tax_total}, text=${result.tax_amount}, using breakdown`);
        result.tax_amount = result.tax_total;
      }
    }
    
    // Extract currency information from clusters
    result.currency = this.fuseCurrencyValue(clusters);
    
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
    
    console.log(`🎯 [Cluster] Clustering ${evidence.length} evidence items`);
    
    for (const item of evidence) {
      if (!item.field) continue;
      
      console.log(`📊 [Cluster] Processing: ${item.field} = ${item.rate}% / ${item.amount}`);
      
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
        
        console.log(`✅ [Cluster] Created new cluster for: ${item.field}`);
        clusters.push(cluster);
      } else {
        // Special handling for tax_breakdown: always combine different rates
        if (item.field === 'tax_breakdown') {
          console.log(`📊 [Cluster] Tax breakdown: Always adding to existing cluster: ${item.rate}% / ${item.amount}`);
          cluster.evidence.push(item);
          this.updateClusterCentroid(cluster);
        } else {
          // Check if evidence is similar enough to add to cluster
          const similarity = this.calculateEvidenceSimilarity(item, cluster);
          console.log(`🔍 [Cluster] Similarity check: ${similarity} >= ${this.config.similarityThreshold}?`);
          
          if (similarity >= this.config.similarityThreshold) {
            console.log(`✅ [Cluster] Adding to existing cluster: ${item.rate}% / ${item.amount}`);
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
          Math.pow(pos1[0] - pos2[0], 2) + Math.pow(pos1[1] - pos2[1], 2)
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
    
    console.log(`🔄 [FuseTax] Processing cluster with ${cluster.evidence.length} evidence items`);
    
    // Group by rate (rounded to nearest 0.1%)
    for (const evidence of cluster.evidence) {
      console.log(`📊 [FuseTax] Evidence: ${evidence.rate}% = ${evidence.amount}`);
      
      if (evidence.rate != null && evidence.amount != null) {
        const roundedRate = Math.round(evidence.rate * 10) / 10;
        const key = roundedRate.toString();
        
        if (!breakdownMap.has(key)) {
          breakdownMap.set(key, []);
        }
        breakdownMap.get(key)!.push(evidence);
        console.log(`✅ [FuseTax] Added ${evidence.rate}% to group '${key}'`);
      }
    }
    
    console.log(`🔑 [FuseTax] Rate groups: ${Array.from(breakdownMap.keys()).join(', ')}`);
    console.log(`📊 [FuseTax] Total groups: ${breakdownMap.size}`);
    
    
    // Fuse each rate group
    const result: TaxBreakdown[] = [];
    for (const [rateStr, evidenceList] of breakdownMap) {
      const rate = parseFloat(rateStr);
      const amount = EvidenceUtils.calculateWeightedAverage(evidenceList, 'amount') || 0;
      const confidence = evidenceList.reduce((sum, e) => sum + e.confidence, 0) / evidenceList.length;
      
      // Extract additional fields from supporting evidence
      const sampleEvidence = evidenceList[0]; // Use first evidence as reference
      const net = sampleEvidence.supportingData?.netAmount;
      const gross = sampleEvidence.supportingData?.grossAmount;
      const category = sampleEvidence.supportingData?.taxCategory;
      const detectedLanguage = sampleEvidence.supportingData?.detectedLanguage || 'en';
      
      // Generate description using localization service
      let description = '';
      if (category) {
        description = TaxBreakdownLocalizationService.getFormattedCategoryDescription(category, rate, detectedLanguage);
      } else {
        description = TaxBreakdownLocalizationService.getRateTypeDescription(rate, detectedLanguage);
      }
      
      const taxBreakdown = {
        rate,
        amount: Math.round(amount * 100) / 100,
        net: net ? Math.round(net * 100) / 100 : undefined,
        gross: gross ? Math.round(gross * 100) / 100 : undefined,
        category,
        confidence,
        description,
        supportingEvidence: evidenceList.length
      };
      
      console.log(`✅ [FuseTax] Created breakdown: ${rate}% = ${taxBreakdown.amount}`);
      result.push(taxBreakdown);
    }
    
    const finalResult = result.sort((a, b) => a.rate - b.rate);
    console.log(`🎯 [FuseTax] Final result: ${finalResult.length} breakdowns`);
    finalResult.forEach((breakdown, i) => {
      console.log(`  ${i+1}. ${breakdown.rate}% = ${breakdown.amount}`);
    });
    
    return finalResult;
  }

  private fuseNumericValue(clusters: EvidenceCluster[], field: EvidenceField): number | undefined {
    const cluster = clusters.find(c => c.type === field);
    if (!cluster || cluster.evidence.length === 0) return undefined;
    
    console.log(`🔍 [FuseNumericValue] Processing ${field} with ${cluster.evidence.length} evidence pieces`);
    cluster.evidence.forEach(e => {
      console.log(`  - ${e.source}: ${e.amount} (conf: ${e.confidence.toFixed(2)}) "${e.rawText}"`);
    });
    
    // PRIORITY 1: High-confidence text evidence from OCR (trust what we can clearly see)
    const textEvidence = cluster.evidence.filter(e => 
      (e.source === 'text' || e.source === 'pattern') && 
      e.confidence > 0.7 && 
      e.amount !== undefined
    );
    
    if (textEvidence.length > 0) {
      // For financial fields, trust the highest confidence text evidence
      const sortedTextEvidence = textEvidence.sort((a, b) => b.confidence - a.confidence);
      const bestTextValue = sortedTextEvidence[0].amount!;
      
      console.log(`✅ [FuseNumericValue] Using high-confidence text evidence for ${field}: ${bestTextValue} (conf: ${sortedTextEvidence[0].confidence.toFixed(2)})`);
      return Math.round(bestTextValue * 100) / 100;
    }
    
    // PRIORITY 2: Mathematical consistency check between calculation and text evidence
    const calculationEvidence = cluster.evidence.filter(e => e.source === 'calculation' || e.source === 'summary_calculation');
    const allTextEvidence = cluster.evidence.filter(e => e.source === 'text' || e.source === 'pattern');
    
    if (calculationEvidence.length > 0 && allTextEvidence.length > 0) {
      const calcValue = calculationEvidence[0].amount;
      const textValue = allTextEvidence.find(e => e.amount !== undefined)?.amount;
      
      if (calcValue !== undefined && textValue !== undefined) {
        const deviation = Math.abs(calcValue - textValue);
        const tolerance = Math.max(calcValue, textValue) * 0.01; // 1% tolerance for financial data
        
        if (deviation <= tolerance) {
          console.log(`🧮 [FuseNumericValue] Mathematical consistency detected for ${field}: calc=${calcValue}, text=${textValue}, using text value`);
          return Math.round(textValue * 100) / 100; // Trust text over calculation when they agree
        } else {
          console.log(`⚠️ [FuseNumericValue] Mathematical inconsistency for ${field}: calc=${calcValue}, text=${textValue}, deviation=${deviation.toFixed(2)} > tolerance=${tolerance.toFixed(2)}`);
        }
      }
    }
    
    // PRIORITY 3: For total field, verify with subtotal + tax calculation
    if (field === 'total') {
      const subtotalCluster = clusters.find(c => c.type === 'subtotal');
      const taxCluster = clusters.find(c => c.type === 'tax_amount');
      
      if (subtotalCluster && taxCluster) {
        // Get text evidence values for subtotal and tax
        const subtotalTextEvidence = subtotalCluster.evidence.filter(e => 
          (e.source === 'text' || e.source === 'pattern') && e.confidence > 0.7
        );
        const taxTextEvidence = taxCluster.evidence.filter(e => 
          (e.source === 'text' || e.source === 'pattern') && e.confidence > 0.7
        );
        
        if (subtotalTextEvidence.length > 0 && taxTextEvidence.length > 0) {
          const subtotalValue = subtotalTextEvidence.sort((a, b) => b.confidence - a.confidence)[0].amount;
          const taxValue = taxTextEvidence.sort((a, b) => b.confidence - a.confidence)[0].amount;
          
          if (subtotalValue !== undefined && taxValue !== undefined) {
            const calculatedTotal = subtotalValue + taxValue;
            
            // Check if this calculated total matches any text evidence within tolerance
            const totalTextEvidence = cluster.evidence.filter(e => e.source === 'text' || e.source === 'pattern');
            const matchingTextEvidence = totalTextEvidence.find(e => {
              if (e.amount === undefined) return false;
              const deviation = Math.abs(calculatedTotal - e.amount);
              return deviation <= 0.05; // 5 cent tolerance for rounding differences
            });
            
            if (matchingTextEvidence) {
              console.log(`🧮 [FuseNumericValue] Total calculation matches text evidence: using text value ${matchingTextEvidence.amount} (calculated: ${calculatedTotal})`);
              return Math.round(matchingTextEvidence.amount * 100) / 100;
            } else {
              console.log(`⚠️ [FuseNumericValue] Total calculation mismatch: calculated=${calculatedTotal}, text=${totalTextEvidence[0]?.amount}`);
            }
          }
        }
      }
    }
    
    // PRIORITY 4: Fallback to highest confidence evidence of any source
    const highestConfidenceValue = this.getHighestConfidenceValue(cluster);
    if (highestConfidenceValue !== undefined) {
      console.log(`📊 [FuseNumericValue] Using highest confidence value for ${field}: ${highestConfidenceValue}`);
      return Math.round(highestConfidenceValue * 100) / 100;
    }
    
    // Final fallback: use weighted average only if no high-confidence evidence exists
    const cleanedEvidence = EvidenceUtils.removeOutliers(cluster.evidence, 'amount');
    const weightedAverage = EvidenceUtils.calculateWeightedAverage(cleanedEvidence, 'amount');
    
    console.log(`⚠️ [FuseNumericValue] Falling back to weighted average for ${field}: ${weightedAverage}`);
    return weightedAverage ? Math.round(weightedAverage * 100) / 100 : undefined;
  }

  /**
   * Get the value from the evidence with the highest confidence in a cluster
   */
  private getHighestConfidenceValue(cluster: EvidenceCluster): number | undefined {
    if (!cluster || cluster.evidence.length === 0) return undefined;
    
    const validEvidence = cluster.evidence.filter(e => e.amount !== undefined);
    if (validEvidence.length === 0) return undefined;
    
    // Sort by confidence descending
    validEvidence.sort((a, b) => b.confidence - a.confidence);
    return validEvidence[0].amount;
  }

  /**
   * Fuse currency value from evidence clusters
   */
  private fuseCurrencyValue(clusters: EvidenceCluster[]): string | undefined {
    // Look for currency cluster first
    const currencyCluster = clusters.find(c => c.type === 'currency');
    if (currencyCluster && currencyCluster.evidence.length > 0) {
      const evidence = currencyCluster.evidence[0]; // Take the first currency evidence
      console.log(`💱 [FuseCurrency] Found currency from cluster: ${evidence.value}`);
      return evidence.value || undefined;
    }
    
    // Fallback: Look for currency evidence from all clusters
    for (const cluster of clusters) {
      for (const evidence of cluster.evidence) {
        if (evidence.field === 'currency' && evidence.value && evidence.supportingData?.method === 'currency_pattern_detection') {
          console.log(`💱 [FuseCurrency] Found currency evidence: ${evidence.value}`);
          return evidence.value;
        }
      }
    }
    
    console.log(`💱 [FuseCurrency] No currency evidence found in clusters`);
    return undefined;
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
    const result = CurrencyExtractor.extractCurrencyAndAmount(text);
    return result.amount || 0;
  }

  /**
   * Extract currency information from text lines
   */
  private extractCurrencyEvidence(textLines: TextLine[], timestamp: Date): TaxEvidence | null {
    // Combine all text to search for currency information
    const fullText = textLines.map(line => line.text).join(' ');
    
    console.log(`💱 [Currency] Analyzing text for currency: ${fullText.substring(0, 200)}...`);
    
    const appliedPatterns: string[] = [];
    const detectedCurrency = CurrencyExtractor.extractCurrency(fullText, appliedPatterns);
    
    if (detectedCurrency) {
      console.log(`✅ [Currency] Detected currency: ${detectedCurrency.code} (${detectedCurrency.symbol})`);
      
      return {
        source: 'text' as EvidenceSource,
        field: 'currency' as EvidenceField,
        value: detectedCurrency.code,
        confidence: 0.9,
        position: [0, 0, 0, 0] as [number, number, number, number],
        rawText: `Currency detected: ${detectedCurrency.code} (${detectedCurrency.symbol})`,
        supportingData: {
          method: 'currency_pattern_detection',
          detectedSymbol: detectedCurrency.symbol,
          appliedPatterns: appliedPatterns,
          searchText: fullText.substring(0, 100)
        },
        timestamp
      };
    }
    
    console.log(`❌ [Currency] No currency detected in text`);
    return null;
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
    
    // Enhanced pattern to support both USD prefix ($123.45) and EUR suffix (123.45€) formats
    const amountPatterns = [
      /\$\s*\d+[.,]\d{2}/g,                    // USD prefix: $123.45, $ 123.45
      /\d+[.,]\d{2}\s*[€£¥₹]/g,              // Suffix currencies: 123.45€, 123.45£
      /(?<![€$£¥₹])\b\d+[.,]\d{2}\b(?!\s*[€£¥₹])/g  // Standalone amounts: 123.45 (not preceded/followed by currency)
    ];
    
    for (const pattern of amountPatterns) {
      const matches = text.match(pattern);
      if (matches) {
        for (const match of matches) {
          const amount = this.parseAmount(match);
          if (amount > 0) amounts.push(amount);
        }
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

  /**
   * Get unified text patterns using the new multilingual pattern generation system
   */
  private getUnifiedTextPatterns(): Array<{ pattern: RegExp; field: EvidenceField }> {
    // Detect language from text lines (simplified - could be enhanced)
    const detectedLanguages: SupportedLanguage[] = ['en', 'de', 'fi', 'sv', 'fr', 'it', 'es'];
    
    const patterns = [];

    try {
      // Generate tax breakdown patterns (rate + amount)
      for (const language of detectedLanguages) {
        try {
          const taxBreakdownPattern = MultilingualPatternGenerator.generateTaxBreakdownPattern(language, {
            includeCurrency: true,
            flexibleSeparators: true,
            supportDecimalVariations: true
          });
          patterns.push({ pattern: taxBreakdownPattern, field: 'tax_breakdown' as EvidenceField });
          console.log(`✅ [TaxBreakdownPattern] Generated successfully for ${language}: ${taxBreakdownPattern.source.substring(0, 80)}...`);
        } catch (error) {
          console.warn(`⚠️ [TaxBreakdownPattern] Failed to generate for language ${language}:`, error);
          // Fallback: Simple tax breakdown pattern for US-style receipts
          if (language === 'en') {
            const fallbackPattern = /\b(?:tax|vat)\s*\d*\s*(\d+(?:[.,]\d+)?)\s*%.*?(\d+[.,]\d{2})/gi;
            patterns.push({ pattern: fallbackPattern, field: 'tax_breakdown' as EvidenceField });
            console.log(`✅ [TaxBreakdownPattern] Added fallback pattern for English`);
          }
        }
      }

      // Generate field-specific patterns for multiple languages
      const fieldTypes: Array<{ field: EvidenceField; configField: ExtendedFieldType }> = [
        { field: 'subtotal', configField: 'subtotal' },
        { field: 'total', configField: 'total' },
        { field: 'tax_amount', configField: 'tax' }
      ];

      for (const { field, configField } of fieldTypes) {
        const multiLangPattern = MultilingualPatternGenerator.generateMultiLanguagePattern(configField, detectedLanguages, {
          includeCurrency: true,
          flexibleSeparators: true,
          supportDecimalVariations: true
        });
        patterns.push({ pattern: multiLangPattern, field });
      }

      // Add specialized patterns for enhanced detection
      patterns.push(
        // Enhanced tax amount detection
        {
          pattern: MultilingualPatternGenerator.generateMultiLanguagePattern('tax_amount', detectedLanguages),
          field: 'tax_amount' as EvidenceField
        },
        // Net amount detection
        {
          pattern: MultilingualPatternGenerator.generateMultiLanguagePattern('net_amount', detectedLanguages),
          field: 'subtotal' as EvidenceField
        },
        // Gross amount detection
        {
          pattern: MultilingualPatternGenerator.generateMultiLanguagePattern('gross_amount', detectedLanguages),
          field: 'total' as EvidenceField
        }
      );

    } catch (error) {
      console.warn('⚠️ [UnifiedPatterns] Error generating patterns, falling back to basic patterns:', error);
      
      // Fallback to basic patterns with word boundaries to avoid false matches
      patterns.push(
        {
          pattern: /\b(?:total|sum|yhteensä|summa|gesamt|totalt|montant total|totale|importe)\s*:?\s*([€$£¥₹]?\s*\d+[.,]\d{2}|\d+[.,]\d{2}\s*[€$£¥₹])/gi,
          field: 'total' as EvidenceField
        },
        {
          pattern: /\b(?:subtotal|välisumma|zwischensumme|delsumma|sous-total|subtotale|base imponible)\s*:?\s*([€$£¥₹]?\s*\d+[.,]\d{2}|\d+[.,]\d{2}\s*[€$£¥₹])/gi,
          field: 'subtotal' as EvidenceField
        },
        {
          pattern: /\b(?:tax|vat|alv|mwst|ust|moms|tva|iva|steuer)\s*:?\s*([€$£¥₹]?\s*\d+[.,]\d{2}|\d+[.,]\d{2}\s*[€$£¥₹])/gi,
          field: 'tax_amount' as EvidenceField
        }
      );
    }

    console.log(`🎨 [UnifiedPatterns] Generated ${patterns.length} unified patterns`);
    return patterns;
  }

  /**
   * Detect primary language from text lines
   */
  private detectPrimaryLanguage(textLines: TextLine[]): SupportedLanguage {
    const fullText = textLines.map(line => line.text).join(' ').toLowerCase();
    
    // Simple language detection based on characteristic keywords
    const languageScores = {
      de: (fullText.match(/\b(ust|mwst|steuer|zwischensumme|summe|betrag|rechnung|quittung)\b/g) || []).length,
      fi: (fullText.match(/\b(alv|yhteensä|summa|kuitti|maksettava|arvonlisävero)\b/g) || []).length,
      sv: (fullText.match(/\b(moms|totalt|summa|kvitto|att betala)\b/g) || []).length,
      fr: (fullText.match(/\b(tva|total|reçu|facture|montant)\b/g) || []).length,
      it: (fullText.match(/\b(iva|totale|ricevuta|fattura|importo)\b/g) || []).length,
      es: (fullText.match(/\b(iva|total|recibo|factura|importe)\b/g) || []).length,
      en: (fullText.match(/\b(vat|tax|total|receipt|invoice|amount)\b/g) || []).length,
    };

    const detectedLanguage = Object.entries(languageScores)
      .reduce((max, [lang, score]) => score > max.score ? { language: lang, score } : max, 
              { language: 'en', score: 0 }).language as SupportedLanguage;

    console.log(`🌐 [Language] Detected: ${detectedLanguage} (scores: ${JSON.stringify(languageScores)})`);
    return detectedLanguage;
  }
}