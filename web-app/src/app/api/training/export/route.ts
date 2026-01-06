// Training Data Export API Route
import { NextRequest, NextResponse } from 'next/server';
import { readdir, readFile, writeFile } from 'fs/promises';
import { existsSync } from 'fs';
import path from 'path';
import { TrainingDataExport, TrainingDataStatistics } from '@/types/training';
import { prisma } from '@/lib/prisma';

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const exportType = searchParams.get('type') || 'unified'; // unified, raw, verified, stats
  const format = searchParams.get('format') || 'json'; // json, csv

  try {
    switch (exportType) {
      case 'unified':
        return await exportUnifiedDataset(format);
      case 'raw':
        return await exportRawData(format);
      case 'verified':
        return await exportVerifiedData(format);
      case 'stats':
        return await exportStatistics();
      default:
        return NextResponse.json({ 
          success: false, 
          error: 'Invalid export type' 
        }, { status: 400 });
    }
  } catch (error) {
    console.error('Export error:', error);
    return NextResponse.json({ 
      success: false, 
      error: 'Export failed' 
    }, { status: 500 });
  }
}

/**
 * Export unified dataset combining raw and verified data
 */
async function exportUnifiedDataset(format: string): Promise<NextResponse> {
  const rawDir = path.join(process.cwd(), 'data', 'training', 'raw');
  const verifiedDir = path.join(process.cwd(), 'data', 'training', 'verified');
  const exportDir = path.join(process.cwd(), 'data', 'training', 'exports');

  const unifiedData: TrainingDataExport[] = [];

  // Read raw data
  if (existsSync(rawDir)) {
    const rawFiles = await readdir(rawDir);
    for (const file of rawFiles.filter(f => f.endsWith('.json'))) {
      try {
        const content = await readFile(path.join(rawDir, file), 'utf8');
        const data = JSON.parse(content);
        unifiedData.push(convertToExportFormat(data, false));
      } catch (error) {
        console.error(`Failed to process raw file ${file}:`, error);
      }
    }
  }

  // Read verified data
  if (existsSync(verifiedDir)) {
    const verifiedFiles = await readdir(verifiedDir);
    for (const file of verifiedFiles.filter(f => f.endsWith('.json'))) {
      try {
        const content = await readFile(path.join(verifiedDir, file), 'utf8');
        const data = JSON.parse(content);
        unifiedData.push(convertToExportFormat(data, true));
      } catch (error) {
        console.error(`Failed to process verified file ${file}:`, error);
      }
    }
  }

  // Sort by timestamp
  unifiedData.sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());

  const exportData = {
    export_info: {
      type: 'unified_training_dataset',
      generated_at: new Date().toISOString(),
      total_samples: unifiedData.length,
      raw_samples: unifiedData.filter(d => !d.is_verified).length,
      verified_samples: unifiedData.filter(d => d.is_verified).length,
    },
    data: unifiedData,
  };

  // Save export file
  const fileName = `training_dataset_${Date.now()}.json`;
  const filePath = path.join(exportDir, fileName);
  await writeFile(filePath, JSON.stringify(exportData, null, 2));

  if (format === 'csv') {
    return await convertToCSV(unifiedData);
  }

  return NextResponse.json({
    success: true,
    export_type: 'unified',
    file_path: filePath,
    total_samples: unifiedData.length,
    data: exportData,
  });
}

/**
 * Export only raw training data
 */
async function exportRawData(format: string): Promise<NextResponse> {
  const rawDir = path.join(process.cwd(), 'data', 'training', 'raw');
  
  if (!existsSync(rawDir)) {
    return NextResponse.json({
      success: false,
      error: 'No raw training data found'
    }, { status: 404 });
  }

  const rawFiles = await readdir(rawDir);
  const rawData = [];

  for (const file of rawFiles.filter(f => f.endsWith('.json'))) {
    try {
      const content = await readFile(path.join(rawDir, file), 'utf8');
      rawData.push(JSON.parse(content));
    } catch (error) {
      console.error(`Failed to process file ${file}:`, error);
    }
  }

  return NextResponse.json({
    success: true,
    export_type: 'raw',
    total_samples: rawData.length,
    data: rawData,
  });
}

/**
 * Export only verified training data
 */
async function exportVerifiedData(format: string): Promise<NextResponse> {
  const verifiedDir = path.join(process.cwd(), 'data', 'training', 'verified');
  
  if (!existsSync(verifiedDir)) {
    return NextResponse.json({
      success: false,
      error: 'No verified training data found'
    }, { status: 404 });
  }

  const verifiedFiles = await readdir(verifiedDir);
  const verifiedData = [];

  for (const file of verifiedFiles.filter(f => f.endsWith('.json'))) {
    try {
      const content = await readFile(path.join(verifiedDir, file), 'utf8');
      verifiedData.push(JSON.parse(content));
    } catch (error) {
      console.error(`Failed to process file ${file}:`, error);
    }
  }

  return NextResponse.json({
    success: true,
    export_type: 'verified',
    total_samples: verifiedData.length,
    data: verifiedData,
  });
}

/**
 * Export training data statistics
 */
async function exportStatistics(): Promise<NextResponse> {
  try {
    const statistics = await generateTrainingDataStatistics();
    
    const exportDir = path.join(process.cwd(), 'data', 'training', 'exports');
    const fileName = `training_statistics_${Date.now()}.json`;
    const filePath = path.join(exportDir, fileName);
    
    await writeFile(filePath, JSON.stringify(statistics, null, 2));

    return NextResponse.json({
      success: true,
      export_type: 'statistics',
      file_path: filePath,
      statistics,
    });

  } catch (error) {
    console.error('Statistics export error:', error);
    throw error;
  }
}

/**
 * Convert training data to unified export format
 */
function convertToExportFormat(data: any, isVerified: boolean): TrainingDataExport {
  return {
    receipt_id: data.receipt_id,
    timestamp: data.timestamp,
    is_verified: isVerified,
    text_lines: data.text_lines.map((line: any) => ({
      text: line.text,
      bounding_box: line.boundingBox || line.bounding_box,
      confidence: line.confidence,
      label: line.label,
      label_confidence: line.label_confidence,
      features: line.features,
      feature_vector: line.feature_vector,
    })),
    extraction_result: isVerified ? data.extraction_result.extracted_data : data.extraction_result,
    metadata: {
      image_path: data.metadata.image_path,
      language: data.metadata.language,
      ocr_confidence: data.metadata.ocr_confidence,
      extraction_confidence: data.metadata.extraction_confidence,
      is_ground_truth: isVerified,
    },
  };
}

/**
 * Generate comprehensive training data statistics
 */
async function generateTrainingDataStatistics(): Promise<TrainingDataStatistics> {
  const rawDir = path.join(process.cwd(), 'data', 'training', 'raw');
  const verifiedDir = path.join(process.cwd(), 'data', 'training', 'verified');

  let rawData: any[] = [];
  let verifiedData: any[] = [];

  // Read raw data
  if (existsSync(rawDir)) {
    const rawFiles = await readdir(rawDir);
    rawData = await Promise.all(
      rawFiles.filter(f => f.endsWith('.json')).map(async file => {
        const content = await readFile(path.join(rawDir, file), 'utf8');
        return JSON.parse(content);
      })
    );
  }

  // Read verified data
  if (existsSync(verifiedDir)) {
    const verifiedFiles = await readdir(verifiedDir);
    verifiedData = await Promise.all(
      verifiedFiles.filter(f => f.endsWith('.json')).map(async file => {
        const content = await readFile(path.join(verifiedDir, file), 'utf8');
        return JSON.parse(content);
      })
    );
  }

  const allData = [...rawData, ...verifiedData];

  // Calculate statistics
  const totalSamples = allData.length;
  const verificationRate = totalSamples > 0 ? verifiedData.length / totalSamples : 0;
  
  // Language distribution
  const languageCount: Record<string, number> = {};
  allData.forEach(sample => {
    const lang = sample.metadata.language || 'unknown';
    languageCount[lang] = (languageCount[lang] || 0) + 1;
  });

  // Document type distribution
  const documentTypeCount: Record<string, number> = {};
  allData.forEach(sample => {
    const type = sample.extraction_result?.document_type || 'unknown';
    documentTypeCount[type] = (documentTypeCount[type] || 0) + 1;
  });

  // Confidence distribution
  const confidenceRanges = { high: 0, medium: 0, low: 0 };
  rawData.forEach(sample => {
    const confidence = sample.metadata.extraction_confidence || 0;
    if (confidence >= 0.8) confidenceRanges.high++;
    else if (confidence >= 0.5) confidenceRanges.medium++;
    else confidenceRanges.low++;
  });

  // Label distribution
  const labelCount: Record<string, number> = {};
  allData.forEach(sample => {
    sample.text_lines.forEach((line: any) => {
      const label = line.label || 'OTHER';
      labelCount[label] = (labelCount[label] || 0) + 1;
    });
  });

  // Average confidence
  const avgConfidence = rawData.length > 0 
    ? rawData.reduce((sum, sample) => sum + (sample.metadata.extraction_confidence || 0), 0) / rawData.length
    : 0;

  // Data quality score (simple heuristic)
  const qualityScore = Math.min(1.0, (avgConfidence * 0.5) + (verificationRate * 0.3) + 0.2);

  return {
    summary: {
      total_raw_samples: rawData.length,
      total_verified_samples: verifiedData.length,
      verification_rate: verificationRate,
      average_confidence: avgConfidence,
      data_quality_score: qualityScore,
    },
    distribution: {
      by_language: languageCount,
      by_document_type: documentTypeCount,
      by_confidence_range: confidenceRanges,
    },
    label_quality: {
      label_distribution: labelCount,
      most_corrected_fields: [], // Would need more sophisticated analysis
      error_patterns: [], // Would need error tracking
    },
    progress_tracking: {
      target_samples: 1000,
      current_samples: totalSamples,
      completion_percentage: (totalSamples / 1000) * 100,
      estimated_completion_date: estimateCompletionDate(totalSamples),
    },
  };
}

/**
 * Estimate completion date based on current progress
 */
function estimateCompletionDate(currentSamples: number): string {
  const targetSamples = 1000;
  if (currentSamples >= targetSamples) {
    return new Date().toISOString().split('T')[0]; // Today
  }

  // Assume 10 samples per day (very rough estimate)
  const remainingSamples = targetSamples - currentSamples;
  const estimatedDays = Math.ceil(remainingSamples / 10);
  const completionDate = new Date();
  completionDate.setDate(completionDate.getDate() + estimatedDays);
  
  return completionDate.toISOString().split('T')[0];
}

/**
 * Convert training data to CSV format
 */
async function convertToCSV(data: TrainingDataExport[]): Promise<NextResponse> {
  const headers = [
    'receipt_id', 'timestamp', 'is_verified', 'language', 'document_type',
    'merchant_name', 'date', 'total', 'currency', 'ocr_confidence', 'extraction_confidence'
  ].join(',');

  const rows = data.map(item => [
    item.receipt_id,
    item.timestamp,
    item.is_verified,
    item.metadata.language,
    item.extraction_result.document_type || '',
    item.extraction_result.merchant_name || '',
    item.extraction_result.date || '',
    item.extraction_result.total || '',
    item.extraction_result.currency || '',
    item.metadata.ocr_confidence,
    item.metadata.extraction_confidence,
  ].join(','));

  const csvContent = [headers, ...rows].join('\n');

  return new NextResponse(csvContent, {
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': `attachment; filename="training_data_${Date.now()}.csv"`
    }
  });
}