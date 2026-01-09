import 'dart:io';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

import '../../main.dart';

/// Result from document scanning
class DocumentScanResult {
  final List<String> imagePaths;
  final String? pdfPath;
  final int pageCount;
  final int processingTimeMs;

  DocumentScanResult({
    required this.imagePaths,
    this.pdfPath,
    required this.pageCount,
    required this.processingTimeMs,
  });

  /// Get the first scanned image path (most common use case)
  String? get firstImagePath => imagePaths.isNotEmpty ? imagePaths.first : null;

  /// Check if scan was successful
  bool get isSuccess => imagePaths.isNotEmpty;
}

/// Service for document scanning using Google ML Kit
///
/// This provides iOS-like document scanning functionality:
/// - Automatic edge detection
/// - Perspective correction
/// - Image enhancement
/// - Multi-page scanning
///
/// Note: Android only (iOS support pending in ML Kit)
class DocumentScannerService {
  DocumentScanner? _scanner;

  /// Scan documents with automatic edge detection
  ///
  /// [pageLimit] - Maximum number of pages to scan (1 for single receipt)
  /// [galleryImportAllowed] - Allow importing from gallery
  /// [scannerMode] - Filter mode for image quality (base, baseWithFilter, full)
  Future<DocumentScanResult?> scanDocument({
    int pageLimit = 1,
    bool galleryImportAllowed = true,
    ScannerMode scannerMode = ScannerMode.full,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      logger.d('Starting document scan (pageLimit: $pageLimit, mode: $scannerMode)');

      // Configure scanner options
      final options = DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: scannerMode,
        pageLimit: pageLimit,
        isGalleryImport: galleryImportAllowed,
      );

      // Create scanner instance
      _scanner = DocumentScanner(options: options);

      // Start scanning
      final result = await _scanner!.scanDocument();

      stopwatch.stop();

      if (result.images.isEmpty) {
        logger.w('Document scan cancelled or no images captured');
        return null;
      }

      logger.i('Document scan completed: ${result.images.length} page(s) in ${stopwatch.elapsedMilliseconds}ms');

      // Extract PDF path if available
      String? pdfPath;
      if (result.pdf != null) {
        pdfPath = result.pdf!.uri;
      }

      return DocumentScanResult(
        imagePaths: result.images,
        pdfPath: pdfPath,
        pageCount: result.images.length,
        processingTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      logger.e('Document scan failed: $e');
      return null;
    } finally {
      _scanner?.close();
      _scanner = null;
    }
  }

  /// Scan a single receipt (convenience method)
  Future<DocumentScanResult?> scanReceipt() async {
    return scanDocument(
      pageLimit: 1,
      galleryImportAllowed: true,
      scannerMode: ScannerMode.full,
    );
  }

  /// Scan multiple pages (for multi-page receipts)
  Future<DocumentScanResult?> scanMultiPage({int maxPages = 5}) async {
    return scanDocument(
      pageLimit: maxPages,
      galleryImportAllowed: true,
      scannerMode: ScannerMode.full,
    );
  }

  /// Check if scanned file exists
  Future<bool> fileExists(String path) async {
    return File(path).exists();
  }

  /// Delete scanned file (cleanup)
  Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        logger.d('Deleted scanned file: $path');
      }
    } catch (e) {
      logger.w('Failed to delete file: $path - $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _scanner?.close();
    _scanner = null;
    logger.d('DocumentScannerService disposed');
  }
}
