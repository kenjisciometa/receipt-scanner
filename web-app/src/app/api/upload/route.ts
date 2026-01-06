// Image Upload API Route
import { NextRequest, NextResponse } from 'next/server';
import { writeFile, mkdir } from 'fs/promises';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';

export async function POST(request: NextRequest) {
  try {
    const data = await request.formData();
    const file: File | null = data.get('file') as unknown as File;

    if (!file) {
      return NextResponse.json({ 
        success: false, 
        error: 'No file uploaded' 
      }, { status: 400 });
    }

    // Validate file type
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'application/pdf'];
    if (!allowedTypes.includes(file.type)) {
      return NextResponse.json({ 
        success: false, 
        error: 'Invalid file type. Only JPEG, PNG, and PDF are allowed.' 
      }, { status: 400 });
    }

    // Validate file size (10MB limit)
    const maxSize = 10 * 1024 * 1024; // 10MB
    if (file.size > maxSize) {
      return NextResponse.json({ 
        success: false, 
        error: 'File too large. Maximum size is 10MB.' 
      }, { status: 400 });
    }

    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);

    // Generate unique filename
    const fileExtension = path.extname(file.name);
    const fileName = `${uuidv4()}${fileExtension}`;
    const uploadsDir = path.join(process.cwd(), 'uploads');
    const filePath = path.join(uploadsDir, fileName);

    // Ensure uploads directory exists
    try {
      await mkdir(uploadsDir, { recursive: true });
    } catch (error) {
      // Directory already exists or other error - continue
    }

    // Save file
    await writeFile(filePath, buffer);

    return NextResponse.json({
      success: true,
      file_id: fileName,
      file_path: filePath,
      file_size: file.size,
      file_type: file.type,
      original_name: file.name,
    });

  } catch (error) {
    console.error('Upload error:', error);
    
    return NextResponse.json({ 
      success: false, 
      error: 'Failed to upload file' 
    }, { status: 500 });
  }
}

// GET endpoint to retrieve upload info
export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const fileId = searchParams.get('file_id');

  if (!fileId) {
    return NextResponse.json({ 
      success: false, 
      error: 'File ID required' 
    }, { status: 400 });
  }

  try {
    const filePath = path.join(process.cwd(), 'uploads', fileId);
    const fs = await import('fs');
    
    if (!fs.existsSync(filePath)) {
      return NextResponse.json({ 
        success: false, 
        error: 'File not found' 
      }, { status: 404 });
    }

    const stats = fs.statSync(filePath);
    
    return NextResponse.json({
      success: true,
      file_id: fileId,
      file_path: filePath,
      file_size: stats.size,
      uploaded_at: stats.birthtime,
      exists: true,
    });

  } catch (error) {
    console.error('File info error:', error);
    
    return NextResponse.json({ 
      success: false, 
      error: 'Failed to get file info' 
    }, { status: 500 });
  }
}