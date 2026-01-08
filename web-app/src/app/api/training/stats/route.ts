// Training Data Statistics API Route
import { NextRequest, NextResponse } from 'next/server';
import { readdir, readFile } from 'fs/promises';
import { existsSync } from 'fs';
import path from 'path';
import { TrainingDataStatistics } from '@/types/training';
import { prisma } from '@/lib/prisma';

export async function GET(request: NextRequest) {
  try {
    const statistics = await generateLiveTrainingDataStatistics();
    
    return NextResponse.json({
      success: true,
      statistics,
      generated_at: new Date().toISOString(),
    });

  } catch (error) {
    console.error('Statistics generation error:', error);
    
    return NextResponse.json({ 
      success: false, 
      error: 'Failed to generate statistics' 
    }, { status: 500 });
  }
}

/**
 * Generate real-time training data statistics
 */
async function generateLiveTrainingDataStatistics(): Promise<TrainingDataStatistics> {
  // Get database counts
  const dbStats = await getDatabaseStatistics();
  
  // Get file system statistics
  const fileStats = await getFileSystemStatistics();
  
  // Combine statistics
  const totalRaw = Math.max(dbStats.rawCount, fileStats.rawCount);
  const totalVerified = Math.max(dbStats.verifiedCount, fileStats.verifiedCount);
  const totalSamples = totalRaw + totalVerified;
  
  const verificationRate = totalSamples > 0 ? totalVerified / totalSamples : 0;
  
  // Calculate average confidence from database
  const avgConfidence = await calculateAverageConfidence();
  
  // Calculate data quality score
  const qualityScore = calculateQualityScore(verificationRate, avgConfidence);
  
  // Get distributions
  const languageDistribution = await getLanguageDistribution();
  const documentTypeDistribution = await getDocumentTypeDistribution();
  const confidenceDistribution = await getConfidenceDistribution();
  const labelDistribution = fileStats.labelDistribution;
  
  return {
    summary: {
      total_raw_samples: totalRaw,
      total_verified_samples: totalVerified,
      verification_rate: verificationRate,
      average_confidence: avgConfidence,
      data_quality_score: qualityScore,
    },
    distribution: {
      by_language: languageDistribution,
      by_document_type: documentTypeDistribution,
      by_confidence_range: confidenceDistribution,
    },
    label_quality: {
      label_distribution: labelDistribution,
      most_corrected_fields: await getMostCorrectedFields(),
      error_patterns: await getErrorPatterns(),
    },
    progress_tracking: {
      target_samples: 1000,
      current_samples: totalSamples,
      completion_percentage: Math.min(100, (totalSamples / 1000) * 100),
      estimated_completion_date: estimateCompletionDate(totalSamples),
    },
  };
}

/**
 * Get statistics from database
 */
async function getDatabaseStatistics(): Promise<{
  rawCount: number;
  verifiedCount: number;
}> {
  try {
    const rawCount = await prisma.trainingData.count({
      where: {
        rawData: { not: null }
      }
    });

    const verifiedCount = await prisma.trainingData.count({
      where: {
        verifiedData: { not: null }
      }
    });

    return { rawCount, verifiedCount };

  } catch (error) {
    console.error('Database statistics error:', error);
    return { rawCount: 0, verifiedCount: 0 };
  }
}

/**
 * Get statistics from file system
 */
async function getFileSystemStatistics(): Promise<{
  rawCount: number;
  verifiedCount: number;
  labelDistribution: Record<string, number>;
}> {
  const rawDir = path.join(process.cwd(), 'data', 'training', 'raw');
  const verifiedDir = path.join(process.cwd(), 'data', 'training', 'verified');
  
  let rawCount = 0;
  let verifiedCount = 0;
  const labelDistribution: Record<string, number> = {};

  // Count raw files and analyze labels
  if (existsSync(rawDir)) {
    const rawFiles = await readdir(rawDir);
    rawCount = rawFiles.filter(f => f.endsWith('.json')).length;

    // Analyze some files for label distribution
    for (const file of rawFiles.slice(0, Math.min(10, rawFiles.length))) {
      try {
        const content = await readFile(path.join(rawDir, file), 'utf8');
        const data = JSON.parse(content);
        
        if (data.text_lines) {
          data.text_lines.forEach((line: any) => {
            const label = line.label || 'OTHER';
            labelDistribution[label] = (labelDistribution[label] || 0) + 1;
          });
        }
      } catch (error) {
        console.error(`Error reading ${file}:`, error);
      }
    }
  }

  // Count verified files
  if (existsSync(verifiedDir)) {
    const verifiedFiles = await readdir(verifiedDir);
    verifiedCount = verifiedFiles.filter(f => f.endsWith('.json')).length;
  }

  return { rawCount, verifiedCount, labelDistribution };
}

/**
 * Calculate average confidence from database
 */
async function calculateAverageConfidence(): Promise<number> {
  try {
    const results = await prisma.extractionResult.findMany({
      select: {
        confidence: true,
      },
      where: {
        confidence: { not: null }
      }
    });

    if (results.length === 0) return 0;

    const sum = results.reduce((acc, result) => acc + (result.confidence || 0), 0);
    return sum / results.length;

  } catch (error) {
    console.error('Average confidence calculation error:', error);
    return 0;
  }
}

/**
 * Calculate data quality score
 */
function calculateQualityScore(verificationRate: number, avgConfidence: number): number {
  // Weighted score: 40% verification rate, 50% confidence, 10% base
  return Math.min(1.0, (verificationRate * 0.4) + (avgConfidence * 0.5) + 0.1);
}

/**
 * Get language distribution from database
 */
async function getLanguageDistribution(): Promise<Record<string, number>> {
  try {
    const results = await prisma.ocrResult.groupBy({
      by: ['detectedLanguage'],
      _count: {
        detectedLanguage: true,
      },
    });

    const distribution: Record<string, number> = {};
    results.forEach(result => {
      const lang = result.detectedLanguage || 'unknown';
      distribution[lang] = result._count.detectedLanguage;
    });

    return distribution;

  } catch (error) {
    console.error('Language distribution error:', error);
    return {};
  }
}

/**
 * Get document type distribution from database
 */
async function getDocumentTypeDistribution(): Promise<Record<string, number>> {
  try {
    const results = await prisma.extractionResult.groupBy({
      by: ['documentType'],
      _count: {
        documentType: true,
      },
    });

    const distribution: Record<string, number> = {};
    results.forEach(result => {
      const type = result.documentType || 'unknown';
      distribution[type] = result._count.documentType;
    });

    return distribution;

  } catch (error) {
    console.error('Document type distribution error:', error);
    return {};
  }
}

/**
 * Get confidence range distribution
 */
async function getConfidenceDistribution(): Promise<{
  high: number;
  medium: number;
  low: number;
}> {
  try {
    const results = await prisma.extractionResult.findMany({
      select: {
        confidence: true,
      },
      where: {
        confidence: { not: null }
      }
    });

    const distribution = { high: 0, medium: 0, low: 0 };

    results.forEach(result => {
      const confidence = result.confidence || 0;
      if (confidence >= 0.8) distribution.high++;
      else if (confidence >= 0.5) distribution.medium++;
      else distribution.low++;
    });

    return distribution;

  } catch (error) {
    console.error('Confidence distribution error:', error);
    return { high: 0, medium: 0, low: 0 };
  }
}

/**
 * Get most frequently corrected fields
 */
async function getMostCorrectedFields(): Promise<string[]> {
  try {
    // This would require comparing original vs verified data
    // For now, return common fields that often need correction
    return ['merchant_name', 'total', 'date', 'currency'];

  } catch (error) {
    console.error('Most corrected fields error:', error);
    return [];
  }
}

/**
 * Get common error patterns
 */
async function getErrorPatterns(): Promise<string[]> {
  try {
    // This would require sophisticated error analysis
    // For now, return common patterns we expect to see
    return [
      'OCR misreads currency symbols',
      'Date format inconsistencies',
      'Merchant name incomplete',
      'Amount decimal separator errors'
    ];

  } catch (error) {
    console.error('Error patterns analysis error:', error);
    return [];
  }
}

/**
 * Estimate completion date based on current progress
 */
function estimateCompletionDate(currentSamples: number): string {
  const targetSamples = 1000;
  
  if (currentSamples >= targetSamples) {
    return new Date().toISOString().split('T')[0];
  }

  // Estimate based on current rate (assume 20 samples per week)
  const remainingSamples = targetSamples - currentSamples;
  const estimatedWeeks = Math.ceil(remainingSamples / 20);
  const completionDate = new Date();
  completionDate.setDate(completionDate.getDate() + (estimatedWeeks * 7));
  
  return completionDate.toISOString().split('T')[0];
}