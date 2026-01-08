'use client';

import { useState } from 'react';
import { UploadComponent } from '@/components/upload/upload-component';
import { ResultsComponent } from '@/components/results/results-component';

interface ProcessingJob {
  job_id: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  ocr_result?: any;
  extraction_result?: any;
  processing_time?: number;
}

export default function Home() {
  const [currentJob, setCurrentJob] = useState<ProcessingJob | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  const handleUploadComplete = (job: ProcessingJob) => {
    setCurrentJob(job);
    setIsProcessing(false);
  };

  const handleProcessingStart = () => {
    setIsProcessing(true);
  };

  const handleReset = () => {
    setCurrentJob(null);
    setIsProcessing(false);
  };

  return (
    <main className="min-h-screen bg-gray-50">
      <div className="container mx-auto py-8 px-4">
        <div className="max-w-4xl mx-auto">
          {/* Header */}
          <div className="text-center mb-8">
            <h1 className="text-3xl font-bold text-gray-900 mb-2">
              Receipt OCR & ML System
            </h1>
            <p className="text-gray-600">
              Upload receipt images for OCR processing and field extraction
            </p>
            <div className="mt-4">
              <a
                href="/training"
                className="text-blue-600 hover:text-blue-700 text-sm font-medium"
              >
                View Training Data Dashboard →
              </a>
            </div>
          </div>

          {/* Main Content */}
          <div className="bg-white rounded-lg shadow-lg p-6">
            {!currentJob ? (
              /* Upload Section */
              <UploadComponent
                onUploadComplete={handleUploadComplete}
                onProcessingStart={handleProcessingStart}
                isProcessing={isProcessing}
              />
            ) : (
              /* Results Section */
              <div>
                <ResultsComponent
                  job={currentJob}
                  onReset={handleReset}
                />
              </div>
            )}
          </div>

          {/* Status Footer */}
          <div className="mt-6 text-center">
            <div className="flex justify-center items-center space-x-6 text-sm text-gray-500">
              <div className="flex items-center">
                <div className="w-3 h-3 bg-green-400 rounded-full mr-2"></div>
                Completed
              </div>
              <div className="flex items-center">
                <div className="w-3 h-3 bg-yellow-400 rounded-full mr-2"></div>
                Processing
              </div>
              <div className="flex items-center">
                <div className="w-3 h-3 bg-red-400 rounded-full mr-2"></div>
                Needs Verification
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  );
}