// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'processing_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProcessingResult _$ProcessingResultFromJson(Map<String, dynamic> json) =>
    ProcessingResult(
      success: json['success'] as bool,
      processingTime: (json['processingTime'] as num).toInt(),
      outputPath: json['outputPath'] as String?,
      errorMessage: json['errorMessage'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      appliedTransformations: (json['appliedTransformations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      qualityScore: (json['qualityScore'] as num?)?.toDouble() ?? 0.0,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$ProcessingResultToJson(ProcessingResult instance) =>
    <String, dynamic>{
      'success': instance.success,
      'processingTime': instance.processingTime,
      'outputPath': instance.outputPath,
      'errorMessage': instance.errorMessage,
      'confidence': instance.confidence,
      'appliedTransformations': instance.appliedTransformations,
      'qualityScore': instance.qualityScore,
      'metadata': instance.metadata,
    };

OCRResult _$OCRResultFromJson(Map<String, dynamic> json) => OCRResult(
      success: json['success'] as bool,
      processingTime: (json['processingTime'] as num).toInt(),
      recognizedText: json['recognizedText'] as String?,
      detectedLanguage: json['detectedLanguage'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
      errorMessage: json['errorMessage'] as String?,
      textBlocks: (json['textBlocks'] as List<dynamic>?)
              ?.map((e) => TextBlock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      textLines: (json['textLines'] as List<dynamic>?)
              ?.map((e) => TextLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$OCRResultToJson(OCRResult instance) => <String, dynamic>{
      'success': instance.success,
      'processingTime': instance.processingTime,
      'recognizedText': instance.recognizedText,
      'detectedLanguage': instance.detectedLanguage,
      'confidence': instance.confidence,
      'wordCount': instance.wordCount,
      'errorMessage': instance.errorMessage,
      'textBlocks': instance.textBlocks,
      'textLines': instance.textLines,
      'metadata': instance.metadata,
    };

TextBlock _$TextBlockFromJson(Map<String, dynamic> json) => TextBlock(
      text: json['text'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      boundingBox: (json['boundingBox'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      language: json['language'] as String?,
    );

Map<String, dynamic> _$TextBlockToJson(TextBlock instance) => <String, dynamic>{
      'text': instance.text,
      'confidence': instance.confidence,
      'boundingBox': instance.boundingBox,
      'language': instance.language,
    };

TextLine _$TextLineFromJson(Map<String, dynamic> json) => TextLine(
      text: json['text'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      boundingBox: (json['boundingBox'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      elements: (json['elements'] as List<dynamic>?)
              ?.map((e) => TextBlock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TextLineToJson(TextLine instance) => <String, dynamic>{
      'text': instance.text,
      'confidence': instance.confidence,
      'boundingBox': instance.boundingBox,
      'elements': instance.elements,
    };

ExtractionResult _$ExtractionResultFromJson(Map<String, dynamic> json) =>
    ExtractionResult(
      success: json['success'] as bool,
      processingTime: (json['processingTime'] as num).toInt(),
      extractedData: json['extractedData'] as Map<String, dynamic>? ?? const {},
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      errorMessage: json['errorMessage'] as String?,
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      appliedPatterns: (json['appliedPatterns'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$ExtractionResultToJson(ExtractionResult instance) =>
    <String, dynamic>{
      'success': instance.success,
      'processingTime': instance.processingTime,
      'extractedData': instance.extractedData,
      'confidence': instance.confidence,
      'errorMessage': instance.errorMessage,
      'warnings': instance.warnings,
      'appliedPatterns': instance.appliedPatterns,
      'metadata': instance.metadata,
    };
