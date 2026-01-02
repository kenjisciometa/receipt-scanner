import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../core/config/app_config.dart';
import '../../core/errors/exceptions.dart';
import '../../data/models/processing_result.dart';
import '../../main.dart';

/// Image preprocessing service for receipt optimization
class ImagePreprocessor {
  
  /// Process receipt image with comprehensive enhancements
  Future<ProcessingResult> processReceiptImage(String inputPath) async {
    final stopwatch = Stopwatch()..start();
    final appliedTransformations = <String>[];
    
    try {
      logger.d('Starting image preprocessing: $inputPath');
      
      // Load and validate image
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        throw FileNotFoundStorageException(inputPath);
      }

      final imageBytes = await inputFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) {
        throw ImageCorruptedException();
      }

      logger.d('Original image: ${image.width}x${image.height}');

      // Step 1: Resize if too large
      if (image.width > AppConfig.maxImageWidth || image.height > AppConfig.maxImageHeight) {
        image = _resizeImage(image);
        appliedTransformations.add('resize');
      }

      // Step 2: Convert to grayscale for better processing
      final grayscaleImage = _convertToGrayscale(image);
      appliedTransformations.add('grayscale');

      // Step 3: Enhance brightness and contrast
      final enhancedImage = _enhanceBrightnessContrast(grayscaleImage);
      appliedTransformations.add('brightness_enhancement');

      // Step 4: Apply noise reduction
      final denoisedImage = _reduceNoise(enhancedImage);
      appliedTransformations.add('noise_reduction');

      // Step 5: Sharpen for better text clarity
      final sharpenedImage = _sharpenImage(denoisedImage);
      appliedTransformations.add('sharpening');

      // Step 6: Normalize contrast (CLAHE-like)
      final normalizedImage = _normalizeContrast(sharpenedImage);
      appliedTransformations.add('contrast_normalization');

      // Calculate quality score
      final qualityScore = _calculateImageQuality(normalizedImage);

      // Save processed image
      final outputPath = await _saveProcessedImage(normalizedImage);
      
      stopwatch.stop();
      final processingTime = stopwatch.elapsedMilliseconds;

      logger.i('Image processing completed in ${processingTime}ms, quality: ${qualityScore.toStringAsFixed(2)}');

      return ProcessingResult.success(
        outputPath: outputPath,
        processingTime: processingTime,
        confidence: qualityScore,
        appliedTransformations: appliedTransformations,
        qualityScore: qualityScore,
        metadata: {
          'original_size': '${image.width}x${image.height}',
          'processed_size': '${normalizedImage.width}x${normalizedImage.height}',
          'transformations': appliedTransformations.length,
        },
      );

    } catch (e) {
      stopwatch.stop();
      logger.e('Image preprocessing failed: $e');
      
      if (e is ReceiptScannerException) {
        rethrow;
      }
      
      return ProcessingResult.failure(
        errorMessage: 'Image processing failed: $e',
        processingTime: stopwatch.elapsedMilliseconds,
        appliedTransformations: appliedTransformations,
      );
    }
  }

  /// Resize image to fit within maximum dimensions
  img.Image _resizeImage(img.Image image) {
    final maxWidth = AppConfig.maxImageWidth;
    final maxHeight = AppConfig.maxImageHeight;
    
    double scale = 1.0;
    
    if (image.width > maxWidth) {
      scale = math.min(scale, maxWidth / image.width);
    }
    
    if (image.height > maxHeight) {
      scale = math.min(scale, maxHeight / image.height);
    }
    
    if (scale < 1.0) {
      final newWidth = (image.width * scale).round();
      final newHeight = (image.height * scale).round();
      
      logger.d('Resizing image: ${image.width}x${image.height} -> ${newWidth}x${newHeight}');
      
      return img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.cubic,
      );
    }
    
    return image;
  }

  /// Convert image to grayscale for better text processing
  img.Image _convertToGrayscale(img.Image image) {
    // Create a new grayscale image
    final grayscale = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        
        // Use luminance formula for better grayscale conversion
        final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
        final grayPixel = img.ColorRgb8(gray, gray, gray);
        
        grayscale.setPixel(x, y, grayPixel);
      }
    }
    
    return grayscale;
  }

  /// Enhance brightness and contrast automatically
  img.Image _enhanceBrightnessContrast(img.Image image) {
    // Calculate image histogram
    final histogram = List.filled(256, 0);
    final totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final intensity = pixel.r.toInt(); // Already grayscale
        histogram[intensity.clamp(0, 255)]++;
      }
    }
    
    // Find optimal brightness and contrast adjustments
    double meanIntensity = 0.0;
    for (int i = 0; i < 256; i++) {
      meanIntensity += i * histogram[i];
    }
    meanIntensity /= totalPixels;
    
    // Auto-adjust brightness to center around 128
    final brightnessDelta = 128 - meanIntensity;
    final brightness = math.max(-50, math.min(50, brightnessDelta * 0.5));
    
    // Auto-adjust contrast based on histogram spread
    final contrast = _calculateOptimalContrast(histogram);
    
    logger.d('Auto-adjusting brightness: $brightness, contrast: $contrast');
    
    return img.adjustColor(
      image,
      brightness: brightness,
      contrast: contrast,
    );
  }

  /// Calculate optimal contrast adjustment
  double _calculateOptimalContrast(List<int> histogram) {
    // Find the range where 99% of pixels fall
    final totalPixels = histogram.reduce((a, b) => a + b);
    final threshold = totalPixels * 0.005; // 0.5% on each end
    
    int lowBound = 0;
    int highBound = 255;
    
    // Find lower bound
    int accumulator = 0;
    for (int i = 0; i < 256; i++) {
      accumulator += histogram[i];
      if (accumulator > threshold) {
        lowBound = i;
        break;
      }
    }
    
    // Find upper bound
    accumulator = 0;
    for (int i = 255; i >= 0; i--) {
      accumulator += histogram[i];
      if (accumulator > threshold) {
        highBound = i;
        break;
      }
    }
    
    final range = highBound - lowBound;
    if (range < 200) {
      return math.min(1.5, 256.0 / range - 1.0);
    }
    
    return 0.0; // No contrast adjustment needed
  }

  /// Apply noise reduction filter
  img.Image _reduceNoise(img.Image image) {
    // Apply a simple gaussian blur to reduce noise
    return img.gaussianBlur(image, radius: 1);
  }

  /// Sharpen image to improve text clarity
  img.Image _sharpenImage(img.Image image) {
    // Custom sharpening kernel
    final kernel = [
      [0, -1, 0],
      [-1, 5, -1],
      [0, -1, 0]
    ];
    
    return _applyConvolutionFilter(image, kernel);
  }

  /// Normalize contrast using adaptive histogram equalization
  img.Image _normalizeContrast(img.Image image) {
    // Calculate histogram
    final histogram = List.filled(256, 0);
    final totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final intensity = pixel.r.toInt();
        histogram[intensity.clamp(0, 255)]++;
      }
    }
    
    // Calculate cumulative distribution
    final cdf = List.filled(256, 0);
    cdf[0] = histogram[0];
    for (int i = 1; i < 256; i++) {
      cdf[i] = cdf[i - 1] + histogram[i];
    }
    
    // Create lookup table for histogram equalization
    final lookupTable = List.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      lookupTable[i] = ((cdf[i] * 255) / totalPixels).round();
    }
    
    // Apply lookup table with limiting to prevent over-enhancement
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final intensity = pixel.r.toInt().clamp(0, 255);
        final newIntensity = math.max(0, math.min(255, lookupTable[intensity]));
        
        // Limit enhancement to prevent over-processing
        final limitedIntensity = intensity + ((newIntensity - intensity) * 0.7).round();
        final finalIntensity = math.max(0, math.min(255, limitedIntensity));
        
        final newPixel = img.ColorRgb8(finalIntensity, finalIntensity, finalIntensity);
        result.setPixel(x, y, newPixel);
      }
    }
    
    return result;
  }

  /// Apply convolution filter with given kernel
  img.Image _applyConvolutionFilter(img.Image image, List<List<int>> kernel) {
    final result = img.Image(width: image.width, height: image.height);
    final kernelSize = kernel.length;
    final offset = kernelSize ~/ 2;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        int sum = 0;
        
        for (int ky = 0; ky < kernelSize; ky++) {
          for (int kx = 0; kx < kernelSize; kx++) {
            final pixelY = math.max(0, math.min(image.height - 1, y + ky - offset));
            final pixelX = math.max(0, math.min(image.width - 1, x + kx - offset));
            
            final pixel = image.getPixel(pixelX, pixelY);
            final intensity = pixel.r.toInt();
            
            sum += intensity * kernel[ky][kx];
          }
        }
        
        final newIntensity = math.max(0, math.min(255, sum));
        final newPixel = img.ColorRgb8(newIntensity, newIntensity, newIntensity);
        result.setPixel(x, y, newPixel);
      }
    }
    
    return result;
  }

  /// Calculate image quality score based on various metrics
  double _calculateImageQuality(img.Image image) {
    // Calculate metrics
    final contrastScore = _calculateContrastScore(image);
    final sharpnessScore = _calculateSharpnessScore(image);
    final brightnessScore = _calculateBrightnessScore(image);
    
    // Weighted average
    final qualityScore = (contrastScore * 0.4 + sharpnessScore * 0.4 + brightnessScore * 0.2);
    
    logger.d('Quality metrics - Contrast: ${contrastScore.toStringAsFixed(2)}, '
             'Sharpness: ${sharpnessScore.toStringAsFixed(2)}, '
             'Brightness: ${brightnessScore.toStringAsFixed(2)}');
    
    return math.max(0.0, math.min(1.0, qualityScore));
  }

  /// Calculate contrast score (0.0 - 1.0)
  double _calculateContrastScore(img.Image image) {
    final histogram = List.filled(256, 0);
    final totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final intensity = pixel.r.toInt();
        histogram[intensity.clamp(0, 255)]++;
      }
    }
    
    // Calculate standard deviation as contrast measure
    double mean = 0.0;
    for (int i = 0; i < 256; i++) {
      mean += i * histogram[i];
    }
    mean /= totalPixels;
    
    double variance = 0.0;
    for (int i = 0; i < 256; i++) {
      final diff = i - mean;
      variance += diff * diff * histogram[i];
    }
    variance /= totalPixels;
    
    final stdDev = math.sqrt(variance);
    return math.min(1.0, stdDev / 64.0); // Normalize to 0-1 range
  }

  /// Calculate sharpness score using Laplacian variance
  double _calculateSharpnessScore(img.Image image) {
    // Apply Laplacian operator
    final laplacianKernel = [
      [0, -1, 0],
      [-1, 4, -1],
      [0, -1, 0]
    ];
    
    double variance = 0.0;
    int count = 0;
    
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        int laplacian = 0;
        
        for (int ky = 0; ky < 3; ky++) {
          for (int kx = 0; kx < 3; kx++) {
            final pixel = image.getPixel(x + kx - 1, y + ky - 1);
            final intensity = pixel.r.toInt();
            laplacian += intensity * laplacianKernel[ky][kx];
          }
        }
        
        variance += laplacian * laplacian;
        count++;
      }
    }
    
    variance /= count;
    return math.min(1.0, variance / 10000.0); // Normalize
  }

  /// Calculate brightness score (how close to optimal brightness)
  double _calculateBrightnessScore(img.Image image) {
    double totalBrightness = 0.0;
    final totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final intensity = pixel.r.toInt();
        totalBrightness += intensity;
      }
    }
    
    final averageBrightness = totalBrightness / totalPixels;
    
    // Optimal brightness is around 128, calculate how close we are
    final deviation = (averageBrightness - 128).abs();
    return math.max(0.0, 1.0 - (deviation / 128.0));
  }

  /// Save processed image to temporary directory
  Future<String> _saveProcessedImage(img.Image processedImage) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outputPath = path.join(tempDir.path, AppConfig.processedImagesDirectory, fileName);
    
    // Ensure directory exists
    final outputDir = Directory(path.dirname(outputPath));
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    
    // Encode and save image
    final jpegBytes = img.encodeJpg(processedImage, quality: 95);
    await File(outputPath).writeAsBytes(jpegBytes);
    
    logger.d('Processed image saved: $outputPath');
    return outputPath;
  }
}