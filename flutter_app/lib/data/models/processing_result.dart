import 'package:json_annotation/json_annotation.dart';

part 'processing_result.g.dart';

/// Represents the result of image processing operations
@JsonSerializable()
class ProcessingResult {
  const ProcessingResult({
    required this.success,
    required this.processingTime,
    this.outputPath,
    this.errorMessage,
    this.confidence = 0.0,
    this.appliedTransformations = const [],
    this.qualityScore = 0.0,
    this.metadata = const {},
  });
  
  /// Whether the processing was successful
  final bool success;
  
  /// Time taken to process (in milliseconds)
  final int processingTime;
  
  /// Path to the processed image file
  final String? outputPath;
  
  /// Error message if processing failed
  final String? errorMessage;
  
  /// Overall confidence score of the processing (0.0 - 1.0)
  final double confidence;
  
  /// List of transformations applied during processing
  final List<String> appliedTransformations;
  
  /// Quality score of the result (0.0 - 1.0)
  final double qualityScore;
  
  /// Additional metadata about the processing
  final Map<String, dynamic> metadata;
  
  /// Whether the result has good quality
  bool get hasGoodQuality => qualityScore >= 0.7;
  
  /// Whether the result is reliable
  bool get isReliable => success && confidence >= 0.6;
  
  /// Processing duration as Duration object
  Duration get duration => Duration(milliseconds: processingTime);
  
  /// Creates ProcessingResult from JSON
  factory ProcessingResult.fromJson(Map<String, dynamic> json) => _$ProcessingResultFromJson(json);
  
  /// Converts ProcessingResult to JSON
  Map<String, dynamic> toJson() => _$ProcessingResultToJson(this);
  
  /// Creates a successful result
  factory ProcessingResult.success({
    required String outputPath,
    required int processingTime,
    double confidence = 1.0,
    List<String> appliedTransformations = const [],
    double qualityScore = 1.0,
    Map<String, dynamic> metadata = const {},
  }) {
    return ProcessingResult(
      success: true,
      processingTime: processingTime,
      outputPath: outputPath,
      confidence: confidence,
      appliedTransformations: appliedTransformations,
      qualityScore: qualityScore,
      metadata: metadata,
    );
  }
  
  /// Creates a failed result
  factory ProcessingResult.failure({
    required String errorMessage,
    required int processingTime,
    List<String> appliedTransformations = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return ProcessingResult(
      success: false,
      processingTime: processingTime,
      errorMessage: errorMessage,
      appliedTransformations: appliedTransformations,
      metadata: metadata,
    );
  }
  
  @override
  String toString() => success 
      ? 'ProcessingResult(success: true, confidence: $confidence, time: ${processingTime}ms)'
      : 'ProcessingResult(success: false, error: $errorMessage, time: ${processingTime}ms)';
}

/// Represents the result of OCR text recognition
@JsonSerializable()
class OCRResult {
  const OCRResult({
    required this.success,
    required this.processingTime,
    this.recognizedText,
    this.detectedLanguage,
    this.confidence = 0.0,
    this.wordCount = 0,
    this.errorMessage,
    this.textBlocks = const [],
    this.textLines = const [],
    this.metadata = const {},
  });
  
  /// Whether OCR was successful
  final bool success;
  
  /// Time taken for OCR processing (in milliseconds)
  final int processingTime;
  
  /// The recognized text
  final String? recognizedText;
  
  /// Detected language code (e.g., 'en', 'fi', 'sv')
  final String? detectedLanguage;
  
  /// Overall confidence score (0.0 - 1.0)
  final double confidence;
  
  /// Number of words recognized
  final int wordCount;
  
  /// Error message if OCR failed
  final String? errorMessage;
  
  /// Individual text blocks with position information
  final List<TextBlock> textBlocks;
  
  /// Individual text lines with position information (structured from ML Kit)
  final List<TextLine> textLines;
  
  /// Additional metadata
  final Map<String, dynamic> metadata;
  
  /// Whether OCR produced good results
  bool get hasGoodResults => success && 
                            recognizedText != null && 
                            recognizedText!.isNotEmpty && 
                            confidence >= 0.6;
  
  /// Whether enough text was recognized for processing
  bool get hasSufficientText => wordCount >= 5;
  
  /// Processing duration as Duration object
  Duration get duration => Duration(milliseconds: processingTime);
  
  /// Creates OCRResult from JSON
  factory OCRResult.fromJson(Map<String, dynamic> json) => _$OCRResultFromJson(json);
  
  /// Converts OCRResult to JSON
  Map<String, dynamic> toJson() => _$OCRResultToJson(this);
  
  /// Creates a successful OCR result
  factory OCRResult.success({
    required String recognizedText,
    required int processingTime,
    String? detectedLanguage,
    double confidence = 1.0,
    List<TextBlock> textBlocks = const [],
    List<TextLine> textLines = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    final wordCount = recognizedText.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
    
    return OCRResult(
      success: true,
      processingTime: processingTime,
      recognizedText: recognizedText,
      detectedLanguage: detectedLanguage,
      confidence: confidence,
      wordCount: wordCount,
      textBlocks: textBlocks,
      textLines: textLines,
      metadata: metadata,
    );
  }
  
  /// Creates a failed OCR result
  factory OCRResult.failure({
    required String errorMessage,
    required int processingTime,
    Map<String, dynamic> metadata = const {},
  }) {
    return OCRResult(
      success: false,
      processingTime: processingTime,
      errorMessage: errorMessage,
      metadata: metadata,
    );
  }
  
  @override
  String toString() => success 
      ? 'OCRResult(success: true, words: $wordCount, confidence: $confidence, language: $detectedLanguage)'
      : 'OCRResult(success: false, error: $errorMessage)';
}

/// Represents a text block with position information
@JsonSerializable()
class TextBlock {
  const TextBlock({
    required this.text,
    required this.confidence,
    this.boundingBox,
    this.language,
  });
  
  /// The recognized text in this block
  final String text;
  
  /// Confidence score for this text block (0.0 - 1.0)
  final double confidence;
  
  /// Bounding box coordinates (x, y, width, height)
  final List<double>? boundingBox;
  
  /// Detected language for this block
  final String? language;
  
  /// Creates TextBlock from JSON
  factory TextBlock.fromJson(Map<String, dynamic> json) => _$TextBlockFromJson(json);
  
  /// Converts TextBlock to JSON
  Map<String, dynamic> toJson() => _$TextBlockToJson(this);
  
  @override
  String toString() => 'TextBlock(text: "$text", confidence: $confidence)';
}

/// Represents a line of text with position information
@JsonSerializable()
class TextLine {
  const TextLine({
    required this.text,
    required this.confidence,
    this.boundingBox,
    this.elements = const [],
  });
  
  /// The recognized text in this line
  final String text;
  
  /// Confidence score for this line (0.0 - 1.0)
  final double confidence;
  
  /// Bounding box coordinates (x, y, width, height)
  final List<double>? boundingBox;
  
  /// Individual text elements in this line
  final List<TextBlock> elements;
  
  /// Creates TextLine from JSON
  factory TextLine.fromJson(Map<String, dynamic> json) => _$TextLineFromJson(json);
  
  /// Converts TextLine to JSON
  Map<String, dynamic> toJson() => _$TextLineToJson(this);
  
  @override
  String toString() => 'TextLine(text: "$text", confidence: $confidence)';
}

/// Represents the result of data extraction from OCR text
@JsonSerializable()
class ExtractionResult {
  const ExtractionResult({
    required this.success,
    required this.processingTime,
    this.extractedData = const {},
    this.confidence = 0.0,
    this.errorMessage,
    this.warnings = const [],
    this.appliedPatterns = const [],
    this.metadata = const {},
  });
  
  /// Whether extraction was successful
  final bool success;
  
  /// Time taken for extraction (in milliseconds)
  final int processingTime;
  
  /// Extracted structured data
  final Map<String, dynamic> extractedData;
  
  /// Overall extraction confidence (0.0 - 1.0)
  final double confidence;
  
  /// Error message if extraction failed
  final String? errorMessage;
  
  /// Warning messages about the extraction
  final List<String> warnings;
  
  /// List of regex patterns that matched
  final List<String> appliedPatterns;
  
  /// Additional metadata
  final Map<String, dynamic> metadata;
  
  /// Whether extraction produced usable results
  bool get hasUsableResults => success && extractedData.isNotEmpty && confidence >= 0.5;
  
  /// Number of fields successfully extracted
  int get extractedFieldCount => extractedData.length;
  
  /// Processing duration as Duration object
  Duration get duration => Duration(milliseconds: processingTime);
  
  /// Creates ExtractionResult from JSON
  factory ExtractionResult.fromJson(Map<String, dynamic> json) => _$ExtractionResultFromJson(json);
  
  /// Converts ExtractionResult to JSON
  Map<String, dynamic> toJson() => _$ExtractionResultToJson(this);
  
  /// Creates a successful extraction result
  factory ExtractionResult.success({
    required Map<String, dynamic> extractedData,
    required int processingTime,
    double confidence = 1.0,
    List<String> warnings = const [],
    List<String> appliedPatterns = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return ExtractionResult(
      success: true,
      processingTime: processingTime,
      extractedData: extractedData,
      confidence: confidence,
      warnings: warnings,
      appliedPatterns: appliedPatterns,
      metadata: metadata,
    );
  }
  
  /// Creates a failed extraction result
  factory ExtractionResult.failure({
    required String errorMessage,
    required int processingTime,
    List<String> warnings = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return ExtractionResult(
      success: false,
      processingTime: processingTime,
      errorMessage: errorMessage,
      warnings: warnings,
      metadata: metadata,
    );
  }
  
  @override
  String toString() => success 
      ? 'ExtractionResult(success: true, fields: $extractedFieldCount, confidence: $confidence)'
      : 'ExtractionResult(success: false, error: $errorMessage)';
}