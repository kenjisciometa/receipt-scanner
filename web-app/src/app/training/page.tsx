'use client';

import { useState, useEffect } from 'react';
import { TrainingDataStatistics } from '@/types/training';

export default function TrainingPage() {
  const [statistics, setStatistics] = useState<TrainingDataStatistics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string>('');
  const [exporting, setExporting] = useState(false);

  useEffect(() => {
    fetchStatistics();
    // Auto-refresh every 30 seconds
    const interval = setInterval(fetchStatistics, 30000);
    return () => clearInterval(interval);
  }, []);

  const fetchStatistics = async () => {
    try {
      setLoading(true);
      const response = await fetch('/api/training/stats');
      const result = await response.json();

      if (result.success) {
        setStatistics(result.statistics);
        setError('');
      } else {
        setError(result.error || 'Failed to fetch statistics');
      }
    } catch (err) {
      setError('Network error while fetching statistics');
    } finally {
      setLoading(false);
    }
  };

  const handleExport = async (type: string) => {
    setExporting(true);
    try {
      const response = await fetch(`/api/training/export?type=${type}`);
      const result = await response.json();

      if (result.success) {
        // Create download link
        const blob = new Blob([JSON.stringify(result.data, null, 2)], {
          type: 'application/json'
        });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `training_data_${type}_${Date.now()}.json`;
        a.click();
        window.URL.revokeObjectURL(url);
      } else {
        setError(result.error || 'Export failed');
      }
    } catch (err) {
      setError('Export failed');
    } finally {
      setExporting(false);
    }
  };

  const getQualityColor = (score: number) => {
    if (score >= 0.8) return 'text-green-600 bg-green-50';
    if (score >= 0.6) return 'text-yellow-600 bg-yellow-50';
    return 'text-red-600 bg-red-50';
  };

  const getProgressColor = (percentage: number) => {
    if (percentage >= 80) return 'bg-green-500';
    if (percentage >= 50) return 'bg-yellow-500';
    return 'bg-blue-500';
  };

  if (loading && !statistics) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="container mx-auto py-8 px-4">
        <div className="max-w-6xl mx-auto">
          {/* Header */}
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-gray-900">Training Data Dashboard</h1>
            <p className="text-gray-600 mt-2">
              Monitor machine learning training data collection and quality
            </p>
          </div>

          {error && (
            <div className="bg-red-50 border border-red-200 rounded-md p-4 mb-6">
              <p className="text-red-800">{error}</p>
            </div>
          )}

          {statistics && (
            <div className="space-y-6">
              {/* Summary Cards */}
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <div className="bg-white rounded-lg shadow p-6">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center">
                        <svg className="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                          <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                      </div>
                    </div>
                    <div className="ml-4">
                      <p className="text-sm font-medium text-gray-500">Raw Samples</p>
                      <p className="text-2xl font-bold text-gray-900">
                        {statistics.summary.total_raw_samples.toLocaleString()}
                      </p>
                    </div>
                  </div>
                </div>

                <div className="bg-white rounded-lg shadow p-6">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center">
                        <svg className="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                          <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                      </div>
                    </div>
                    <div className="ml-4">
                      <p className="text-sm font-medium text-gray-500">Verified Samples</p>
                      <p className="text-2xl font-bold text-gray-900">
                        {statistics.summary.total_verified_samples.toLocaleString()}
                      </p>
                    </div>
                  </div>
                </div>

                <div className="bg-white rounded-lg shadow p-6">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 bg-purple-500 rounded-full flex items-center justify-center">
                        <svg className="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                          <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                      </div>
                    </div>
                    <div className="ml-4">
                      <p className="text-sm font-medium text-gray-500">Verification Rate</p>
                      <p className="text-2xl font-bold text-gray-900">
                        {(statistics.summary.verification_rate * 100).toFixed(1)}%
                      </p>
                    </div>
                  </div>
                </div>

                <div className="bg-white rounded-lg shadow p-6">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className={`w-8 h-8 rounded-full flex items-center justify-center ${
                        statistics.summary.data_quality_score >= 0.8 ? 'bg-green-500' :
                        statistics.summary.data_quality_score >= 0.6 ? 'bg-yellow-500' : 'bg-red-500'
                      }`}>
                        <svg className="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                          <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                      </div>
                    </div>
                    <div className="ml-4">
                      <p className="text-sm font-medium text-gray-500">Data Quality</p>
                      <p className="text-2xl font-bold text-gray-900">
                        {(statistics.summary.data_quality_score * 100).toFixed(1)}%
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Progress Tracking */}
              <div className="bg-white rounded-lg shadow p-6">
                <h3 className="text-lg font-medium text-gray-900 mb-4">Progress to Target</h3>
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">
                      {statistics.progress_tracking.current_samples} / {statistics.progress_tracking.target_samples} samples
                    </span>
                    <span className="text-sm font-medium text-gray-900">
                      {statistics.progress_tracking.completion_percentage.toFixed(1)}%
                    </span>
                  </div>
                  <div className="bg-gray-200 rounded-full h-3">
                    <div
                      className={`h-3 rounded-full ${getProgressColor(statistics.progress_tracking.completion_percentage)}`}
                      style={{ width: `${Math.min(100, statistics.progress_tracking.completion_percentage)}%` }}
                    ></div>
                  </div>
                  <p className="text-sm text-gray-600">
                    Estimated completion: {statistics.progress_tracking.estimated_completion_date}
                  </p>
                </div>
              </div>

              {/* Distribution Charts */}
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* Language Distribution */}
                <div className="bg-white rounded-lg shadow p-6">
                  <h3 className="text-lg font-medium text-gray-900 mb-4">Language Distribution</h3>
                  <div className="space-y-3">
                    {Object.entries(statistics.distribution.by_language).map(([lang, count]) => (
                      <div key={lang} className="flex items-center justify-between">
                        <span className="text-sm text-gray-600 uppercase">{lang}</span>
                        <div className="flex items-center">
                          <span className="text-sm font-medium text-gray-900 mr-2">{count}</span>
                          <div className="w-16 bg-gray-200 rounded-full h-2">
                            <div
                              className="bg-blue-500 h-2 rounded-full"
                              style={{
                                width: `${Math.min(100, (count / Math.max(...Object.values(statistics.distribution.by_language))) * 100)}%`
                              }}
                            ></div>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Document Type Distribution */}
                <div className="bg-white rounded-lg shadow p-6">
                  <h3 className="text-lg font-medium text-gray-900 mb-4">Document Types</h3>
                  <div className="space-y-3">
                    {Object.entries(statistics.distribution.by_document_type).map(([type, count]) => (
                      <div key={type} className="flex items-center justify-between">
                        <span className="text-sm text-gray-600 capitalize">{type}</span>
                        <div className="flex items-center">
                          <span className="text-sm font-medium text-gray-900 mr-2">{count}</span>
                          <div className="w-16 bg-gray-200 rounded-full h-2">
                            <div
                              className="bg-green-500 h-2 rounded-full"
                              style={{
                                width: `${Math.min(100, (count / Math.max(...Object.values(statistics.distribution.by_document_type))) * 100)}%`
                              }}
                            ></div>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              {/* Label Quality */}
              <div className="bg-white rounded-lg shadow p-6">
                <h3 className="text-lg font-medium text-gray-900 mb-4">Label Distribution</h3>
                <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                  {Object.entries(statistics.label_quality.label_distribution).map(([label, count]) => (
                    <div key={label} className="text-center">
                      <p className="text-lg font-bold text-gray-900">{count}</p>
                      <p className="text-sm text-gray-600">{label.replace(/_/g, ' ')}</p>
                    </div>
                  ))}
                </div>
              </div>

              {/* Export Actions */}
              <div className="bg-white rounded-lg shadow p-6">
                <h3 className="text-lg font-medium text-gray-900 mb-4">Export Training Data</h3>
                <div className="flex flex-wrap gap-4">
                  <button
                    onClick={() => handleExport('unified')}
                    disabled={exporting}
                    className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 disabled:opacity-50"
                  >
                    Export Unified Dataset
                  </button>
                  <button
                    onClick={() => handleExport('raw')}
                    disabled={exporting}
                    className="bg-gray-600 text-white px-4 py-2 rounded-md hover:bg-gray-700 disabled:opacity-50"
                  >
                    Export Raw Data
                  </button>
                  <button
                    onClick={() => handleExport('verified')}
                    disabled={exporting}
                    className="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 disabled:opacity-50"
                  >
                    Export Verified Data
                  </button>
                  <button
                    onClick={() => handleExport('stats')}
                    disabled={exporting}
                    className="bg-purple-600 text-white px-4 py-2 rounded-md hover:bg-purple-700 disabled:opacity-50"
                  >
                    Export Statistics
                  </button>
                </div>
                {exporting && (
                  <p className="text-sm text-gray-600 mt-2">Preparing export...</p>
                )}
              </div>

              {/* Refresh Button */}
              <div className="text-center">
                <button
                  onClick={fetchStatistics}
                  disabled={loading}
                  className="bg-gray-600 text-white px-6 py-2 rounded-md hover:bg-gray-700 disabled:opacity-50"
                >
                  {loading ? 'Refreshing...' : 'Refresh Statistics'}
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}