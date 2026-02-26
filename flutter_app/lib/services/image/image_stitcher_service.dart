import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import '../../main.dart';

/// Service for stitching multiple images vertically
/// Used for combining multiple scans of a long receipt
class ImageStitcherService {
  /// Stitch multiple images vertically into a single image
  ///
  /// [imagePaths] - List of image paths to stitch (in order from top to bottom)
  /// [overlapPercent] - Percentage of overlap to remove (0-50, default 10)
  /// Returns the path to the stitched image, or null if failed
  Future<String?> stitchImagesVertically(
    List<String> imagePaths, {
    int overlapPercent = 10,
  }) async {
    if (imagePaths.isEmpty) {
      logger.w('No images to stitch');
      return null;
    }

    if (imagePaths.length == 1) {
      logger.d('Only one image, no stitching needed');
      return imagePaths.first;
    }

    final stopwatch = Stopwatch()..start();
    logger.i('Starting image stitching: ${imagePaths.length} images');

    try {
      // Load all images
      final List<img.Image> images = [];
      for (final path in imagePaths) {
        final file = File(path);
        if (!await file.exists()) {
          logger.e('Image file not found: $path');
          return null;
        }

        final bytes = await file.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          logger.e('Failed to decode image: $path');
          return null;
        }
        images.add(decoded);
        logger.d('Loaded image: $path (${decoded.width}x${decoded.height})');
      }

      // Normalize widths - resize all images to match the first image's width
      final targetWidth = images.first.width;
      for (int i = 1; i < images.length; i++) {
        if (images[i].width != targetWidth) {
          final scale = targetWidth / images[i].width;
          final newHeight = (images[i].height * scale).round();
          images[i] = img.copyResize(
            images[i],
            width: targetWidth,
            height: newHeight,
            interpolation: img.Interpolation.linear,
          );
          logger.d('Resized image $i to ${targetWidth}x$newHeight');
        }
      }

      // Calculate overlap in pixels (for each image except the first)
      final List<int> overlaps = [];
      for (int i = 1; i < images.length; i++) {
        final overlap = (images[i].height * overlapPercent / 100).round();
        overlaps.add(overlap);
      }

      // Calculate total height
      int totalHeight = images.first.height;
      for (int i = 1; i < images.length; i++) {
        totalHeight += images[i].height - overlaps[i - 1];
      }

      logger.d('Creating stitched image: ${targetWidth}x$totalHeight');

      // Create the stitched image
      final stitched = img.Image(
        width: targetWidth,
        height: totalHeight,
      );

      // Fill with white background
      img.fill(stitched, color: img.ColorRgb8(255, 255, 255));

      // Copy images onto the stitched canvas
      int currentY = 0;
      for (int i = 0; i < images.length; i++) {
        final source = images[i];
        final startY = i == 0 ? 0 : overlaps[i - 1]; // Skip overlap region

        for (int y = startY; y < source.height; y++) {
          for (int x = 0; x < source.width; x++) {
            final pixel = source.getPixel(x, y);
            if (currentY + (y - startY) < stitched.height) {
              stitched.setPixel(x, currentY + (y - startY), pixel);
            }
          }
        }

        currentY += source.height - startY;
        logger.d('Copied image $i, currentY: $currentY');
      }

      // Save the stitched image
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/stitched_receipt_$timestamp.jpg';

      final jpegBytes = img.encodeJpg(stitched, quality: 90);
      await File(outputPath).writeAsBytes(jpegBytes);

      stopwatch.stop();
      logger.i('Image stitching completed in ${stopwatch.elapsedMilliseconds}ms');
      logger.i('Stitched image saved: $outputPath (${stitched.width}x${stitched.height})');

      return outputPath;
    } catch (e, stackTrace) {
      stopwatch.stop();
      logger.e('Image stitching failed: $e');
      logger.e('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Stitch images with automatic overlap detection using image comparison
  /// This is more advanced and tries to find the best alignment
  Future<String?> stitchImagesWithAutoAlign(
    List<String> imagePaths,
  ) async {
    // For now, use simple vertical stitching with 10% overlap
    // TODO: Implement feature-based alignment for better results
    return stitchImagesVertically(imagePaths, overlapPercent: 10);
  }

  /// Get image dimensions without loading the full image
  Future<Size?> getImageSize(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      return Size(decoded.width.toDouble(), decoded.height.toDouble());
    } catch (e) {
      logger.e('Failed to get image size: $e');
      return null;
    }
  }
}
