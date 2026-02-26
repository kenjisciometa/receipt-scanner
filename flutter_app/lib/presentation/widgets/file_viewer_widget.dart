import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Determines if the data represents a PDF file based on magic bytes
bool isPdfData(Uint8List data) {
  // PDF magic bytes: %PDF (0x25 0x50 0x44 0x46)
  if (data.length >= 4) {
    return data[0] == 0x25 && data[1] == 0x50 && data[2] == 0x44 && data[3] == 0x46;
  }
  return false;
}

/// Determines if a URL points to a PDF based on extension
bool isPdfUrl(String url) {
  final lowerUrl = url.toLowerCase();
  return lowerUrl.endsWith('.pdf');
}

/// Widget that displays either an image or a PDF based on the file type
class FileViewerWidget extends StatefulWidget {
  final Uint8List data;
  final BoxFit fit;

  const FileViewerWidget({
    super.key,
    required this.data,
    this.fit = BoxFit.contain,
  });

  @override
  State<FileViewerWidget> createState() => _FileViewerWidgetState();
}

class _FileViewerWidgetState extends State<FileViewerWidget> {
  PdfControllerPinch? _pdfController;
  bool _isPdf = false;

  @override
  void initState() {
    super.initState();
    _isPdf = isPdfData(widget.data);
    if (_isPdf) {
      _initPdfController();
    }
  }

  void _initPdfController() {
    setState(() {
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openData(widget.data),
      );
    });
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPdf) {
      if (_pdfController == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return PdfViewPinch(
        controller: _pdfController!,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
          pageLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
          errorBuilder: (_, error) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text('Error loading PDF: $error'),
              ],
            ),
          ),
        ),
      );
    } else {
      // Image viewer
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.memory(
          widget.data,
          fit: widget.fit,
        ),
      );
    }
  }
}
