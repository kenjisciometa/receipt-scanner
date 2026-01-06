'use client';

import { useState } from 'react';

interface ProcessingJob {
  job_id: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  ocr_result?: any;
  extraction_result?: any;
  processing_time?: number;
}

interface ResultsComponentProps {
  job: ProcessingJob;
  onReset: () => void;
}

export function ResultsComponent({ job, onReset }: ResultsComponentProps) {
  const [activeTab, setActiveTab] = useState<'extraction' | 'ocr' | 'verification'>('extraction');
  const [isEditing, setIsEditing] = useState(false);
  const [editedData, setEditedData] = useState(job.extraction_result || {});

  const getStatusColor = (status: string, confidence?: number) => {
    if (status === 'failed') return 'text-red-600 bg-red-50';
    if (status === 'completed' && confidence && confidence >= 0.7) return 'text-green-600 bg-green-50';
    if (status === 'completed') return 'text-yellow-600 bg-yellow-50';
    return 'text-blue-600 bg-blue-50';
  };

  const getDocumentTypeColor = (type: string) => {
    switch (type) {
      case 'receipt': return 'text-green-600 bg-green-50';
      case 'invoice': return 'text-blue-600 bg-blue-50';
      default: return 'text-gray-600 bg-gray-50';
    }
  };

  const handleSaveVerification = async () => {
    try {
      const response = await fetch('/api/verify', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          job_id: job.job_id,
          verified_data: editedData,
        }),
      });

      const result = await response.json();

      if (result.success) {
        setIsEditing(false);
        // Could update the job state here
      }

    } catch (error) {
      console.error('Verification save failed:', error);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Processing Results</h2>
          <p className="text-sm text-gray-500">Job ID: {job.job_id}</p>
        </div>
        <div className="flex items-center space-x-3">
          <span
            className={`px-3 py-1 rounded-full text-xs font-medium ${getStatusColor(
              job.status,
              job.extraction_result?.confidence
            )}`}
          >
            {job.status === 'completed' 
              ? job.extraction_result?.needs_verification 
                ? 'Needs Verification' 
                : 'Completed'
              : job.status.charAt(0).toUpperCase() + job.status.slice(1)
            }
          </span>
          <button
            onClick={onReset}
            className="text-sm text-blue-600 hover:text-blue-700"
          >
            Process Another
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="border-b border-gray-200">
        <nav className="-mb-px flex">
          <button
            onClick={() => setActiveTab('extraction')}
            className={`py-2 px-4 border-b-2 font-medium text-sm ${
              activeTab === 'extraction'
                ? 'border-blue-500 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Extracted Fields
          </button>
          <button
            onClick={() => setActiveTab('ocr')}
            className={`py-2 px-4 border-b-2 font-medium text-sm ${
              activeTab === 'ocr'
                ? 'border-blue-500 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            OCR Results
          </button>
          <button
            onClick={() => setActiveTab('verification')}
            className={`py-2 px-4 border-b-2 font-medium text-sm ${
              activeTab === 'verification'
                ? 'border-blue-500 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Manual Verification
          </button>
        </nav>
      </div>

      {/* Tab Content */}
      <div className="mt-6">
        {/* Extraction Results Tab */}
        {activeTab === 'extraction' && (
          <div className="space-y-4">
            {/* Document Classification */}
            {job.extraction_result?.document_type && (
              <div className="bg-gray-50 rounded-lg p-4">
                <h3 className="text-sm font-medium text-gray-900 mb-3">Document Classification</h3>
                <div className="grid grid-cols-2 gap-4 mb-3">
                  <div>
                    <span className="text-sm text-gray-500">Type:</span>
                    <span
                      className={`ml-2 px-2 py-1 rounded text-xs font-medium ${getDocumentTypeColor(
                        job.extraction_result.document_type
                      )}`}
                    >
                      {job.extraction_result.document_type?.charAt(0).toUpperCase() + 
                       job.extraction_result.document_type?.slice(1)}
                    </span>
                  </div>
                  <div>
                    <span className="text-sm text-gray-500">Confidence:</span>
                    <span className="ml-2 text-sm text-gray-900">
                      {((job.extraction_result.document_type_confidence || 0) * 100).toFixed(1)}%
                    </span>
                  </div>
                </div>
                {job.extraction_result.document_type_reason && (
                  <div>
                    <span className="text-sm text-gray-500">Reason:</span>
                    <div className="mt-1 text-xs text-gray-700 bg-white rounded px-2 py-1">
                      {job.extraction_result.document_type_reason}
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* Extracted Fields */}
            <div className="bg-white border border-gray-200 rounded-lg">
              <div className="px-4 py-3 border-b border-gray-200">
                <h3 className="text-sm font-medium text-gray-900">Extracted Information</h3>
              </div>
              <div className="p-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-medium text-gray-500">Merchant Name</label>
                    <div className="mt-1 text-sm text-gray-900">
                      {job.extraction_result?.merchant_name || 'Not found'}
                    </div>
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-500">Date</label>
                    <div className="mt-1 text-sm text-gray-900">
                      {job.extraction_result?.date || 'Not found'}
                    </div>
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-500">Currency</label>
                    <div className="mt-1 text-sm text-gray-900">
                      {job.extraction_result?.currency || 'Not found'}
                    </div>
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-500">Total Amount</label>
                    <div className="mt-1 text-sm font-medium text-gray-900">
                      {job.extraction_result?.total 
                        ? job.extraction_result.total.toFixed(2)
                        : 'Not found'
                      }
                    </div>
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-500">Subtotal</label>
                    <div className="mt-1 text-sm text-gray-900">
                      {job.extraction_result?.subtotal 
                        ? job.extraction_result.subtotal.toFixed(2)
                        : 'Not found'
                      }
                    </div>
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-500">Tax Total</label>
                    <div className="mt-1 text-sm text-gray-900">
                      {job.extraction_result?.tax_total 
                        ? job.extraction_result.tax_total.toFixed(2)
                        : 'Not found'
                      }
                    </div>
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-500">Payment Method</label>
                    <div className="mt-1 text-sm text-gray-900">
                      {job.extraction_result?.payment_method || 'Not found'}
                    </div>
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-500">Receipt Number</label>
                    <div className="mt-1 text-sm text-gray-900">
                      {job.extraction_result?.receipt_number || 'Not found'}
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Confidence Score */}
            <div className="bg-gray-50 rounded-lg p-4">
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-gray-900">Extraction Confidence</span>
                <span className="text-sm text-gray-600">
                  {((job.extraction_result?.confidence || 0) * 100).toFixed(1)}%
                </span>
              </div>
              <div className="mt-2">
                <div className="bg-gray-200 rounded-full h-2">
                  <div
                    className={`h-2 rounded-full ${
                      (job.extraction_result?.confidence || 0) >= 0.7
                        ? 'bg-green-500'
                        : (job.extraction_result?.confidence || 0) >= 0.5
                        ? 'bg-yellow-500'
                        : 'bg-red-500'
                    }`}
                    style={{ width: `${(job.extraction_result?.confidence || 0) * 100}%` }}
                  ></div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* OCR Results Tab */}
        {activeTab === 'ocr' && (
          <div className="space-y-4">
            <div className="bg-white border border-gray-200 rounded-lg">
              <div className="px-4 py-3 border-b border-gray-200">
                <h3 className="text-sm font-medium text-gray-900">OCR Information</h3>
              </div>
              <div className="p-4">
                <div className="grid grid-cols-2 gap-4 mb-4">
                  <div>
                    <span className="text-sm text-gray-500">Detected Language:</span>
                    <span className="ml-2 text-sm text-gray-900">
                      {job.ocr_result?.detected_language?.toUpperCase() || 'Not found'}
                    </span>
                  </div>
                  <div>
                    <span className="text-sm text-gray-500">Processing Time:</span>
                    <span className="ml-2 text-sm text-gray-900">
                      {job.processing_time || job.ocr_result?.processing_time || 0}ms
                    </span>
                  </div>
                  <div>
                    <span className="text-sm text-gray-500">OCR Confidence:</span>
                    <span className="ml-2 text-sm text-gray-900">
                      {((job.ocr_result?.confidence || 0) * 100).toFixed(1)}%
                    </span>
                  </div>
                  <div>
                    <span className="text-sm text-gray-500">Text Lines:</span>
                    <span className="ml-2 text-sm text-gray-900">
                      {job.ocr_result?.textLines?.length || 0}
                    </span>
                  </div>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-900 mb-2">Full Text</label>
                  <div className="bg-gray-50 rounded p-3 text-sm font-mono">
                    {job.ocr_result?.text || 'Not found'}
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Manual Verification Tab */}
        {activeTab === 'verification' && (
          <div className="space-y-4">
            <div className="bg-white border border-gray-200 rounded-lg">
              <div className="px-4 py-3 border-b border-gray-200 flex items-center justify-between">
                <h3 className="text-sm font-medium text-gray-900">Manual Verification</h3>
                <button
                  onClick={() => setIsEditing(!isEditing)}
                  className="text-sm text-blue-600 hover:text-blue-700"
                >
                  {isEditing ? 'Cancel' : 'Edit'}
                </button>
              </div>
              <div className="p-4">
                {isEditing ? (
                  <div className="space-y-6">
                    {/* Document Classification Section */}
                    <div className="bg-gray-50 rounded-lg p-4">
                      <h4 className="text-sm font-medium text-gray-900 mb-3">Document Classification</h4>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                          <label className="block text-xs font-medium text-gray-700">Document Type</label>
                          <select
                            value={editedData.document_type || 'unknown'}
                            onChange={(e) => setEditedData({...editedData, document_type: e.target.value})}
                            className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                          >
                            <option value="receipt">Receipt</option>
                            <option value="invoice">Invoice</option>
                            <option value="unknown">Unknown</option>
                          </select>
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-700">Document Type Confidence</label>
                          <input
                            type="number"
                            step="0.1"
                            min="0"
                            max="1"
                            value={editedData.document_type_confidence || ''}
                            onChange={(e) => setEditedData({...editedData, document_type_confidence: parseFloat(e.target.value) || 0})}
                            className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                            placeholder="0.0 - 1.0"
                          />
                        </div>
                      </div>
                    </div>

                    {/* Main Fields Section */}
                    <div>
                      <h4 className="text-sm font-medium text-gray-900 mb-3">Extracted Information</h4>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                          <label className="block text-xs font-medium text-gray-700">Merchant Name</label>
                          <input
                            type="text"
                            value={editedData.merchant_name || ''}
                            onChange={(e) => setEditedData({...editedData, merchant_name: e.target.value})}
                            className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                            placeholder="Enter merchant name"
                          />
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-700">Date</label>
                          <input
                            type="date"
                            value={editedData.date ? new Date(editedData.date).toISOString().split('T')[0] : ''}
                            onChange={(e) => setEditedData({...editedData, date: e.target.value ? new Date(e.target.value).toISOString() : null})}
                            className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                          />
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-700">Currency</label>
                          <select
                            value={editedData.currency || 'USD'}
                            onChange={(e) => setEditedData({...editedData, currency: e.target.value})}
                            className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                          >
                            <option value="USD">USD</option>
                            <option value="EUR">EUR</option>
                            <option value="GBP">GBP</option>
                            <option value="JPY">JPY</option>
                            <option value="SEK">SEK</option>
                            <option value="NOK">NOK</option>
                            <option value="DKK">DKK</option>
                            <option value="CHF">CHF</option>
                          </select>
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-700">Total Amount</label>
                          <input
                            type="number"
                            step="0.01"
                            value={editedData.total || ''}
                            onChange={(e) => setEditedData({...editedData, total: parseFloat(e.target.value) || 0})}
                            className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                            placeholder="0.00"
                          />
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-700">Subtotal</label>
                          <input
                            type="number"
                            step="0.01"
                            value={editedData.subtotal || ''}
                            onChange={(e) => setEditedData({...editedData, subtotal: parseFloat(e.target.value) || null})}
                            className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                            placeholder="0.00"
                          />
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-700">Tax Total</label>
                          <input
                            type="number"
                            step="0.01"
                            value={editedData.tax_total || ''}
                            onChange={(e) => setEditedData({...editedData, tax_total: parseFloat(e.target.value) || null})}
                            className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                            placeholder="0.00"
                          />
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-700">Payment Method</label>
                          <input
                            type="text"
                            value={editedData.payment_method || ''}
                            onChange={(e) => setEditedData({...editedData, payment_method: e.target.value})}
                            className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                            placeholder="e.g., cash, card, mobile"
                          />
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-700">Receipt Number</label>
                          <input
                            type="text"
                            value={editedData.receipt_number || ''}
                            onChange={(e) => setEditedData({...editedData, receipt_number: e.target.value})}
                            className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                            placeholder="Enter receipt number"
                          />
                        </div>
                      </div>
                    </div>

                    {/* Confidence Section */}
                    <div className="bg-gray-50 rounded-lg p-4">
                      <h4 className="text-sm font-medium text-gray-900 mb-3">Extraction Quality</h4>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                          <label className="block text-xs font-medium text-gray-700">Overall Confidence</label>
                          <input
                            type="number"
                            step="0.1"
                            min="0"
                            max="1"
                            value={editedData.confidence || ''}
                            onChange={(e) => setEditedData({...editedData, confidence: parseFloat(e.target.value) || 0})}
                            className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                            placeholder="0.0 - 1.0"
                          />
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-700">Needs Verification</label>
                          <select
                            value={editedData.needs_verification ? 'true' : 'false'}
                            onChange={(e) => setEditedData({...editedData, needs_verification: e.target.value === 'true'})}
                            className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                          >
                            <option value="false">No - Data is correct</option>
                            <option value="true">Yes - Data needs review</option>
                          </select>
                        </div>
                      </div>
                    </div>

                    {/* Action Buttons */}
                    <div className="flex justify-end space-x-3 pt-4 border-t border-gray-200">
                      <button
                        onClick={() => setIsEditing(false)}
                        className="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
                      >
                        Cancel
                      </button>
                      <button
                        onClick={handleSaveVerification}
                        className="px-4 py-2 text-sm text-white bg-blue-600 rounded-md hover:bg-blue-700"
                      >
                        Save Verified Data
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="space-y-4">
                    {/* Show current data in read-only format matching extracted fields */}
                    <div>
                      <h4 className="text-sm font-medium text-gray-900 mb-3">Current Verified Data</h4>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                          <label className="block text-xs font-medium text-gray-500">Merchant Name</label>
                          <div className="mt-1 text-sm text-gray-900">
                            {editedData.merchant_name || job.extraction_result?.merchant_name || 'Not set'}
                          </div>
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-500">Date</label>
                          <div className="mt-1 text-sm text-gray-900">
                            {editedData.date || job.extraction_result?.date || 'Not set'}
                          </div>
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-500">Currency</label>
                          <div className="mt-1 text-sm text-gray-900">
                            {editedData.currency || job.extraction_result?.currency || 'Not set'}
                          </div>
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-500">Total Amount</label>
                          <div className="mt-1 text-sm font-medium text-gray-900">
                            {editedData.total || job.extraction_result?.total || 'Not set'}
                          </div>
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-500">Subtotal</label>
                          <div className="mt-1 text-sm text-gray-900">
                            {editedData.subtotal || job.extraction_result?.subtotal || 'Not set'}
                          </div>
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-500">Tax Total</label>
                          <div className="mt-1 text-sm text-gray-900">
                            {editedData.tax_total || job.extraction_result?.tax_total || 'Not set'}
                          </div>
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-500">Payment Method</label>
                          <div className="mt-1 text-sm text-gray-900">
                            {editedData.payment_method || job.extraction_result?.payment_method || 'Not set'}
                          </div>
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-500">Receipt Number</label>
                          <div className="mt-1 text-sm text-gray-900">
                            {editedData.receipt_number || job.extraction_result?.receipt_number || 'Not set'}
                          </div>
                        </div>
                      </div>
                    </div>
                    <div className="text-center py-4 text-gray-500">
                      <p>Click "Edit" to manually verify and correct the extracted data.</p>
                      <p className="text-xs mt-1">This will create verified training data for ML improvement.</p>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}