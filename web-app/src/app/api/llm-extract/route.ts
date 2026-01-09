/**
 * LLM Extraction API Endpoint
 *
 * POST /api/llm-extract
 * - Accepts image as base64 or file_id
 * - Returns extracted receipt data using llama.cpp (Qwen2.5-VL)
 */

import { NextRequest, NextResponse } from 'next/server';
import { getLlamaService, LLMExtractionResult } from '@/services/llm/llama-cpp-service';
import * as fs from 'fs';
import * as path from 'path';

interface ExtractRequest {
  image_base64?: string;
  file_id?: string;
  language_hint?: string;
}

interface ExtractResponse {
  success: boolean;
  data?: LLMExtractionResult;
  error?: string;
  llm_available: boolean;
  processing_time_ms: number;
}

/**
 * GET /api/llm-extract
 * Check if LLM service is available
 */
export async function GET(): Promise<NextResponse> {
  const llamaService = getLlamaService();
  const isAvailable = await llamaService.checkServer();

  return NextResponse.json({
    llm_available: isAvailable,
    server_url: process.env.LLAMA_SERVER_URL || 'http://localhost:8080',
    model: 'qwen2.5-vl',
  });
}

/**
 * POST /api/llm-extract
 * Extract receipt data from image using LLM
 */
export async function POST(request: NextRequest): Promise<NextResponse> {
  const startTime = Date.now();

  try {
    const body: ExtractRequest = await request.json();
    const llamaService = getLlamaService();

    // Check if LLM is available
    const isAvailable = await llamaService.checkServer();
    if (!isAvailable) {
      return NextResponse.json(
        {
          success: false,
          error: 'LLM server is not available. Please ensure llama-server is running.',
          llm_available: false,
          processing_time_ms: Date.now() - startTime,
        } as ExtractResponse,
        { status: 503 }
      );
    }

    // Get image data
    let imageBase64: string;

    if (body.image_base64) {
      // Direct base64 input
      imageBase64 = body.image_base64;
    } else if (body.file_id) {
      // Load from uploaded file
      const uploadsDir = path.join(process.cwd(), 'uploads');
      const files = fs.readdirSync(uploadsDir);
      const matchingFile = files.find((f) => f.startsWith(body.file_id!));

      if (!matchingFile) {
        return NextResponse.json(
          {
            success: false,
            error: `File not found: ${body.file_id}`,
            llm_available: true,
            processing_time_ms: Date.now() - startTime,
          } as ExtractResponse,
          { status: 404 }
        );
      }

      const filePath = path.join(uploadsDir, matchingFile);
      const fileBuffer = fs.readFileSync(filePath);
      imageBase64 = fileBuffer.toString('base64');
    } else {
      return NextResponse.json(
        {
          success: false,
          error: 'Either image_base64 or file_id is required',
          llm_available: true,
          processing_time_ms: Date.now() - startTime,
        } as ExtractResponse,
        { status: 400 }
      );
    }

    // Extract using LLM
    const result = await llamaService.extract(imageBase64);

    return NextResponse.json({
      success: true,
      data: result,
      llm_available: true,
      processing_time_ms: Date.now() - startTime,
    } as ExtractResponse);
  } catch (error) {
    console.error('LLM extraction error:', error);

    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
        llm_available: true,
        processing_time_ms: Date.now() - startTime,
      } as ExtractResponse,
      { status: 500 }
    );
  }
}
