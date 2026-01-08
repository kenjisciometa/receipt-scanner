// Google Cloud Vision API Test Route
import { NextResponse } from 'next/server';
import { GoogleVisionOCRService } from '@/services/ocr/google-vision';

export async function GET() {
  try {
    // Check if Google Cloud Vision credentials are configured
    const hasCredentials = process.env.GOOGLE_CLOUD_PROJECT_ID && 
                          process.env.GOOGLE_CLOUD_PRIVATE_KEY && 
                          process.env.GOOGLE_CLOUD_CLIENT_EMAIL;

    if (!hasCredentials) {
      return NextResponse.json({
        success: false,
        error: 'Google Cloud Vision credentials not configured',
        configured: false
      });
    }

    // Try to initialize the service
    try {
      const ocrService = new GoogleVisionOCRService();
      
      return NextResponse.json({
        success: true,
        message: 'Google Cloud Vision API is properly configured',
        configured: true,
        project_id: process.env.GOOGLE_CLOUD_PROJECT_ID,
        client_email: process.env.GOOGLE_CLOUD_CLIENT_EMAIL
      });

    } catch (initError) {
      return NextResponse.json({
        success: false,
        error: 'Failed to initialize Google Cloud Vision service',
        configured: true,
        details: initError instanceof Error ? initError.message : 'Unknown error'
      });
    }

  } catch (error) {
    console.error('Test API error:', error);
    
    return NextResponse.json({ 
      success: false, 
      error: 'Internal server error',
      details: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 });
  }
}