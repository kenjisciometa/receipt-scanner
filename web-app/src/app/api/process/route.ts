// Processing Job API Route
import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { GoogleVisionOCRService } from '@/services/ocr/google-vision';
import { MockOCRService } from '@/services/ocr/mock-ocr-service';
import path from 'path';
import { readFile } from 'fs/promises';

// Use Google Vision if credentials are available, otherwise use mock
const useGoogleVision = process.env.GOOGLE_CLOUD_PROJECT_ID && 
                       (process.env.GOOGLE_CLOUD_PRIVATE_KEY || process.env.GOOGLE_APPLICATION_CREDENTIALS);

const ocrService = useGoogleVision ? new GoogleVisionOCRService() : new MockOCRService();

export async function POST(request: NextRequest) {
  try {
    const { file_id, language_hint, original_name } = await request.json();

    if (!file_id) {
      return NextResponse.json({ 
        success: false, 
        error: 'File ID required' 
      }, { status: 400 });
    }

    // Check if file exists
    const filePath = path.join(process.cwd(), 'uploads', file_id);
    const fs = await import('fs');
    
    if (!fs.existsSync(filePath)) {
      return NextResponse.json({ 
        success: false, 
        error: 'File not found' 
      }, { status: 404 });
    }

    // Create processing job with original filename
    const job = await prisma.processingJob.create({
      data: {
        imagePath: filePath,
        fileId: file_id,
        originalName: original_name,
        status: 'processing',
      }
    });

    // Start processing (could be moved to background queue in production)
    try {
      // Read image file
      const imageBuffer = await readFile(filePath);
      
      // Perform OCR using configured service
      const ocrResult = await ocrService.processImage(imageBuffer);

      if (!ocrResult.success) {
        await prisma.processingJob.update({
          where: { id: job.id },
          data: { 
            status: 'failed',
            completedAt: new Date(),
          }
        });

        return NextResponse.json({
          success: false,
          job_id: job.id,
          error: 'OCR processing failed'
        }, { status: 500 });
      }

      // Save OCR result
      await prisma.ocrResult.create({
        data: {
          jobId: job.id,
          fullText: ocrResult.text,
          textLines: JSON.stringify(ocrResult.textLines),
          confidence: ocrResult.confidence,
          detectedLanguage: ocrResult.detected_language,
          processingTime: ocrResult.processing_time,
        }
      });

      // Import enhanced extraction service with Evidence-Based Fusion
      const { EnhancedReceiptExtractionService } = await import('@/services/extraction/enhanced-receipt-extractor');
      const extractionService = new EnhancedReceiptExtractionService({
        enableDebugLogging: true,
        minEvidenceConfidence: 0.3,
        enabledSources: ['table', 'text', 'summary_calculation', 'spatial_analysis', 'calculation']
      });
      
      // Perform extraction
      const extractionResult = await extractionService.extract(ocrResult, ocrResult.detected_language);
      
      // Save extraction result
      await prisma.extractionResult.create({
        data: {
          jobId: job.id,
          extractedData: JSON.stringify(extractionResult),
          confidence: extractionResult.confidence,
          needsVerification: extractionResult.needs_verification || false,
          documentType: extractionResult.document_type || 'unknown',
          documentTypeConfidence: extractionResult.document_type_confidence,
          documentTypeReason: extractionResult.document_type_reason,
        }
      });

      // Save raw training data if confidence is sufficient
      const { TrainingDataCollector } = await import('@/services/training/training-data-collector');
      const trainingCollector = new TrainingDataCollector();
      
      // Use rescued TextLines if available, otherwise fall back to OCR result
      const modifiedOCRResult = (extractionResult as any).processedTextLines 
        ? { ...ocrResult, textLines: (extractionResult as any).processedTextLines }
        : ocrResult;

      await trainingCollector.saveRawTrainingData(
        job.id,
        modifiedOCRResult,
        extractionResult,
        job.imagePath,
        job.originalName || undefined
      );

      // Update job status
      await prisma.processingJob.update({
        where: { id: job.id },
        data: { 
          status: 'completed',
          completedAt: new Date(),
        }
      });

      return NextResponse.json({
        success: true,
        job_id: job.id,
        status: 'completed',
        ocr_result: ocrResult,
        extraction_result: extractionResult,
        processing_time: ocrResult.processing_time,
      });

    } catch (processingError) {
      console.error('Processing error:', processingError);

      await prisma.processingJob.update({
        where: { id: job.id },
        data: { 
          status: 'failed',
          completedAt: new Date(),
        }
      });

      return NextResponse.json({
        success: false,
        job_id: job.id,
        error: 'Processing failed'
      }, { status: 500 });
    }

  } catch (error) {
    console.error('API error:', error);
    
    return NextResponse.json({ 
      success: false, 
      error: 'Internal server error' 
    }, { status: 500 });
  }
}

// GET endpoint to retrieve job status and results
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
    const job = await prisma.processingJob.findUnique({
      where: { id: jobId },
      include: {
        ocrResult: true,
        extractionResult: true,
        trainingData: true,
      }
    });

    if (!job) {
      return NextResponse.json({ 
        success: false, 
        error: 'Job not found' 
      }, { status: 404 });
    }

    const response: any = {
      success: true,
      job_id: job.id,
      status: job.status,
      created_at: job.createdAt,
      completed_at: job.completedAt,
    };

    // Include OCR result if available
    if (job.ocrResult) {
      response.ocr_result = {
        text: job.ocrResult.fullText,
        textLines: JSON.parse(job.ocrResult.textLines || '[]'),
        confidence: job.ocrResult.confidence,
        detected_language: job.ocrResult.detectedLanguage,
        processing_time: job.ocrResult.processingTime,
        success: true,
      };
    }

    // Include extraction result if available
    if (job.extractionResult) {
      const extractedData = JSON.parse(job.extractionResult.extractedData || '{}');
      response.extraction_result = {
        ...extractedData,
        confidence: job.extractionResult.confidence,
        needs_verification: job.extractionResult.needsVerification,
        is_verified: job.extractionResult.isVerified,
        document_type: job.extractionResult.documentType,
        document_type_confidence: job.extractionResult.documentTypeConfidence,
        document_type_reason: job.extractionResult.documentTypeReason,
      };
    }

    return NextResponse.json(response);

  } catch (error) {
    console.error('Job retrieval error:', error);
    
    return NextResponse.json({ 
      success: false, 
      error: 'Failed to retrieve job' 
    }, { status: 500 });
  }
}