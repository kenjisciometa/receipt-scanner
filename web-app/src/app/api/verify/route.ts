// Manual Verification API Route
import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { TrainingDataCollector } from '@/services/training/training-data-collector';

export async function POST(request: NextRequest) {
  try {
    const { job_id, verified_data } = await request.json();

    if (!job_id || !verified_data) {
      return NextResponse.json({ 
        success: false, 
        error: 'Job ID and verified data required' 
      }, { status: 400 });
    }

    // Get the job and its OCR result
    const job = await prisma.processingJob.findUnique({
      where: { id: job_id },
      include: {
        ocrResult: true,
        extractionResult: true,
      }
    });

    if (!job) {
      return NextResponse.json({ 
        success: false, 
        error: 'Job not found' 
      }, { status: 404 });
    }

    if (!job.ocrResult) {
      return NextResponse.json({ 
        success: false, 
        error: 'No OCR result found for this job' 
      }, { status: 400 });
    }

    // Validate verified data
    const validationResult = validateVerifiedData(verified_data);
    if (!validationResult.isValid) {
      return NextResponse.json({ 
        success: false, 
        error: 'Validation failed',
        validation_errors: validationResult.errors 
      }, { status: 400 });
    }

    // Perform consistency checks
    const consistencyResult = checkDataConsistency(verified_data);
    const warnings = consistencyResult.warnings || [];

    // Initialize training data collector
    const trainingCollector = new TrainingDataCollector();

    // Reconstruct OCR result
    const ocrResult = {
      text: job.ocrResult.fullText || '',
      textLines: JSON.parse(job.ocrResult.textLines || '[]'),
      confidence: job.ocrResult.confidence || 0,
      detected_language: job.ocrResult.detectedLanguage || 'en',
      processing_time: job.ocrResult.processingTime || 0,
      success: true,
    };

    // Save verified training data
    const verifiedFileName = await trainingCollector.saveVerifiedTrainingData(
      job_id,
      ocrResult,
      verified_data,
      job.imagePath
    );

    // Update extraction result in database
    await prisma.extractionResult.update({
      where: { jobId: job_id },
      data: {
        verifiedData: JSON.stringify(verified_data),
        isVerified: true,
        verifiedAt: new Date(),
        // Update document type information if corrected
        documentType: verified_data.document_type || job.extractionResult?.documentType,
        documentTypeConfidence: verified_data.document_type ? 1.0 : job.extractionResult?.documentTypeConfidence,
        documentTypeReason: verified_data.document_type ? 'user_verified' : job.extractionResult?.documentTypeReason,
      }
    });

    // Update training data statistics
    await updateTrainingDataStatistics();

    return NextResponse.json({
      success: true,
      verified_file: verifiedFileName,
      job_id,
      warnings,
      consistency_check: consistencyResult,
    });

  } catch (error) {
    console.error('Verification error:', error);
    
    return NextResponse.json({ 
      success: false, 
      error: 'Failed to save verification data' 
    }, { status: 500 });
  }
}

// GET endpoint to retrieve verification status
export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const jobId = searchParams.get('job_id');

  if (!jobId) {
    return NextResponse.json({ 
      success: false, 
      error: 'Job ID required' 
    }, { status: 400 });
  }

  try {
    const extractionResult = await prisma.extractionResult.findUnique({
      where: { jobId },
      include: {
        job: true,
      }
    });

    if (!extractionResult) {
      return NextResponse.json({ 
        success: false, 
        error: 'Extraction result not found' 
      }, { status: 404 });
    }

    const response = {
      success: true,
      job_id: jobId,
      is_verified: extractionResult.isVerified,
      verified_at: extractionResult.verifiedAt,
      verified_data: extractionResult.verifiedData 
        ? JSON.parse(extractionResult.verifiedData) 
        : null,
      original_data: JSON.parse(extractionResult.extractedData || '{}'),
    };

    return NextResponse.json(response);

  } catch (error) {
    console.error('Verification retrieval error:', error);
    
    return NextResponse.json({ 
      success: false, 
      error: 'Failed to retrieve verification data' 
    }, { status: 500 });
  }
}

/**
 * Validate verified data structure and required fields
 */
function validateVerifiedData(data: Record<string, any>): {
  isValid: boolean;
  errors: string[];
} {
  const errors: string[] = [];

  // Required fields
  if (!data.merchant_name || typeof data.merchant_name !== 'string') {
    errors.push('Merchant name is required');
  }
  
  if (!data.date) {
    errors.push('Date is required');
  }
  
  if (typeof data.total !== 'number' || data.total <= 0) {
    errors.push('Valid total amount is required');
  }
  
  if (!data.currency || typeof data.currency !== 'string') {
    errors.push('Currency is required');
  }
  
  if (!data.document_type || !['receipt', 'invoice', 'unknown'].includes(data.document_type)) {
    errors.push('Valid document type is required');
  }

  // Document type specific validation
  if (data.document_type === 'invoice') {
    if (!data.due_date) {
      errors.push('Due date required for invoices');
    }
    if (!data.payment_terms) {
      errors.push('Payment terms required for invoices');
    }
  }

  // Amount validation
  if (data.subtotal && typeof data.subtotal !== 'number') {
    errors.push('Subtotal must be a number');
  }
  
  if (data.tax_total && typeof data.tax_total !== 'number') {
    errors.push('Tax total must be a number');
  }

  return { isValid: errors.length === 0, errors };
}

/**
 * Check data consistency and calculate warnings
 */
function checkDataConsistency(data: Record<string, any>): {
  isConsistent: boolean;
  warnings: string[];
  consistencyScore: number;
} {
  const warnings: string[] = [];
  let consistencyScore = 1.0;

  // Check amount consistency: subtotal + tax ≈ total
  if (data.subtotal && data.tax_total && data.total) {
    const calculatedTotal = data.subtotal + data.tax_total;
    const difference = Math.abs(calculatedTotal - data.total);
    
    if (difference > 0.02) {
      warnings.push(`Amount inconsistency: subtotal (${data.subtotal}) + tax (${data.tax_total}) ≠ total (${data.total})`);
      consistencyScore *= 0.8;
    }
  }

  // Check if total is reasonable
  if (data.total && (data.total < 0.01 || data.total > 10000)) {
    warnings.push(`Unusual total amount: ${data.total}`);
    consistencyScore *= 0.9;
  }

  // Check date format
  if (data.date) {
    const dateRegex = /^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}(\.\d{3})?Z?)?$/;
    if (!dateRegex.test(data.date)) {
      warnings.push('Date format should be ISO 8601 (YYYY-MM-DD)');
      consistencyScore *= 0.9;
    }
  }

  return {
    isConsistent: warnings.length === 0,
    warnings,
    consistencyScore: Math.max(0.0, consistencyScore),
  };
}

/**
 * Update training data statistics (simple implementation)
 */
async function updateTrainingDataStatistics(): Promise<void> {
  try {
    // Count total training data records
    const totalRaw = await prisma.trainingData.count({
      where: {
        rawData: { not: null }
      }
    });

    const totalVerified = await prisma.trainingData.count({
      where: {
        verifiedData: { not: null }
      }
    });

    console.log(`Training data stats updated: ${totalRaw} raw, ${totalVerified} verified`);
    
    // Could save to a statistics table here
    
  } catch (error) {
    console.error('Failed to update training data statistics:', error);
  }
}