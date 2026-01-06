'use client';

import { useState, useCallback } from 'react';
import { useDropzone } from 'react-dropzone';

interface UploadComponentProps {
  onUploadComplete: (job: any) => void;
  onProcessingStart: () => void;
  isProcessing: boolean;
}

export function UploadComponent({ 
  onUploadComplete, 
  onProcessingStart, 
  isProcessing 
}: UploadComponentProps) {
  const [uploadedFile, setUploadedFile] = useState<File | null>(null);
  const [uploadStatus, setUploadStatus] = useState<'idle' | 'uploading' | 'uploaded' | 'error'>('idle');
  const [error, setError] = useState<string>('');
  const [uploadResult, setUploadResult] = useState<any>(null);

  const onDrop = useCallback((acceptedFiles: File[]) => {
    const file = acceptedFiles[0];
    if (file) {
      setUploadedFile(file);
      uploadFile(file);
    }
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'image/*': ['.png', '.jpg', '.jpeg'],
      'application/pdf': ['.pdf']
    },
    maxSize: 10 * 1024 * 1024, // 10MB
    multiple: false,
  });

  const uploadFile = async (file: File) => {
    setUploadStatus('uploading');
    setError('');

    try {
      const formData = new FormData();
      formData.append('file', file);

      const response = await fetch('/api/upload', {
        method: 'POST',
        body: formData,
      });

      const result = await response.json();

      if (!result.success) {
        throw new Error(result.error || 'Upload failed');
      }

      setUploadStatus('uploaded');
      setUploadResult(result);
      
      // Automatically start processing
      await processFile(result.file_id, result.original_name);

    } catch (err) {
      setUploadStatus('error');
      setError(err instanceof Error ? err.message : 'Upload failed');
    }
  };

  const processFile = async (fileId: string, originalName?: string) => {
    onProcessingStart();
    
    try {
      const response = await fetch('/api/process', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          file_id: fileId,
          language_hint: 'auto',
          original_name: originalName,
        }),
      });

      const result = await response.json();

      if (!result.success) {
        throw new Error(result.error || 'Processing failed');
      }

      onUploadComplete(result);

    } catch (err) {
      setError(err instanceof Error ? err.message : 'Processing failed');
    }
  };

  const resetUpload = () => {
    setUploadedFile(null);
    setUploadStatus('idle');
    setUploadResult(null);
    setError('');
  };

  return (
    <div className="space-y-6">
      {/* Upload Area */}
      <div
        {...getRootProps()}
        className={`
          border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors
          ${isDragActive 
            ? 'border-blue-400 bg-blue-50' 
            : uploadStatus === 'uploaded'
            ? 'border-green-400 bg-green-50'
            : uploadStatus === 'error'
            ? 'border-red-400 bg-red-50'
            : 'border-gray-300 hover:border-gray-400'
          }
        `}
      >
        <input {...getInputProps()} />
        
        {uploadStatus === 'idle' && (
          <div>
            <svg
              className="mx-auto h-12 w-12 text-gray-400"
              stroke="currentColor"
              fill="none"
              viewBox="0 0 48 48"
            >
              <path
                d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02"
                strokeWidth={2}
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            <p className="mt-4 text-sm text-gray-600">
              {isDragActive
                ? 'Drop the file here...'
                : 'Drag & drop a receipt image, or click to select'}
            </p>
            <p className="text-xs text-gray-400 mt-2">
              PNG, JPG, PDF up to 10MB
            </p>
          </div>
        )}

        {uploadStatus === 'uploading' && (
          <div>
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
            <p className="mt-4 text-sm text-blue-600">Uploading...</p>
          </div>
        )}

        {uploadStatus === 'uploaded' && !isProcessing && (
          <div>
            <svg
              className="mx-auto h-12 w-12 text-green-500"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M5 13l4 4L19 7"
              />
            </svg>
            <p className="mt-4 text-sm text-green-600">Upload successful!</p>
            <p className="text-xs text-gray-600 mt-1">{uploadedFile?.name}</p>
          </div>
        )}

        {isProcessing && (
          <div>
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-yellow-600 mx-auto"></div>
            <p className="mt-4 text-sm text-yellow-600">Processing OCR & Extraction...</p>
          </div>
        )}

        {uploadStatus === 'error' && (
          <div>
            <svg
              className="mx-auto h-12 w-12 text-red-500"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
            <p className="mt-4 text-sm text-red-600">Upload failed</p>
            <p className="text-xs text-red-500 mt-1">{error}</p>
            <button
              onClick={resetUpload}
              className="mt-3 text-sm text-blue-600 hover:text-blue-700"
            >
              Try again
            </button>
          </div>
        )}
      </div>

      {/* File Info */}
      {uploadedFile && uploadStatus === 'uploaded' && (
        <div className="bg-gray-50 rounded-lg p-4">
          <h3 className="text-sm font-medium text-gray-900 mb-2">File Details</h3>
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <span className="text-gray-500">Name:</span>
              <span className="ml-2 text-gray-900">{uploadedFile.name}</span>
            </div>
            <div>
              <span className="text-gray-500">Size:</span>
              <span className="ml-2 text-gray-900">
                {(uploadedFile.size / 1024 / 1024).toFixed(2)} MB
              </span>
            </div>
            <div>
              <span className="text-gray-500">Type:</span>
              <span className="ml-2 text-gray-900">{uploadedFile.type}</span>
            </div>
          </div>
        </div>
      )}

      {/* OCR Service Status */}
      <div className="bg-blue-50 rounded-lg p-4">
        <h3 className="text-sm font-medium text-blue-900 mb-2">OCR Service Status</h3>
        {process.env.NEXT_PUBLIC_GOOGLE_CLOUD_CONFIGURED === 'true' ? (
          <div className="text-sm text-blue-800">
            <p className="flex items-center">
              <span className="w-2 h-2 bg-green-500 rounded-full mr-2"></span>
              Google Cloud Vision API configured - High accuracy OCR enabled
            </p>
          </div>
        ) : (
          <div className="text-sm text-blue-800">
            <p className="flex items-center">
              <span className="w-2 h-2 bg-yellow-500 rounded-full mr-2"></span>
              Development mode - Using mock OCR data for testing
            </p>
          </div>
        )}
      </div>

      {/* Instructions */}
      <div className="bg-gray-50 rounded-lg p-4">
        <h3 className="text-sm font-medium text-gray-900 mb-2">Instructions</h3>
        <ul className="text-sm text-gray-700 space-y-1">
          <li>• Upload a clear image of your receipt</li>
          <li>• Ensure good lighting and minimal blur</li>
          <li>• The system supports English, Finnish, Swedish, French, German, Italian, and Spanish</li>
          <li>• Both receipts and invoices are supported</li>
        </ul>
      </div>
    </div>
  );
}