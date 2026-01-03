import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../main.dart';

/// Camera screen for capturing receipt images
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isPermissionGranted = false;
  String? _errorMessage;
  bool _isFlashOn = false;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  /// Initialize camera with permission check
  Future<void> _initializeCamera() async {
    try {
      // Check camera permission
      final permissionStatus = await Permission.camera.status;
      if (permissionStatus.isDenied) {
        final result = await Permission.camera.request();
        if (result.isDenied) {
          setState(() {
            _isPermissionGranted = false;
            _errorMessage = 'Camera permission is required to scan receipts';
          });
          return;
        }
      }

      setState(() {
        _isPermissionGranted = true;
        _errorMessage = null;
      });

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras available on this device';
        });
        return;
      }

      // Find the back camera (preferred for document scanning)
      _selectedCameraIndex = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = 0; // Use first available camera
      }

      await _setupCamera(_selectedCameraIndex);
    } catch (e) {
      logger.e('Camera initialization error: $e');
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  /// Set up camera controller
  Future<void> _setupCamera(int cameraIndex) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      
      // Set camera settings for document scanning
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);
      
      setState(() {
        _isCameraInitialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      logger.e('Camera setup error: $e');
      setState(() {
        _errorMessage = 'Failed to set up camera: $e';
      });
    }
  }

  /// Toggle flash mode
  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.off : FlashMode.torch,
      );
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      logger.e('Flash toggle error: $e');
    }
  }

  /// Switch between front and back cameras
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    final newIndex = (_selectedCameraIndex + 1) % _cameras.length;
    setState(() {
      _isCameraInitialized = false;
      _selectedCameraIndex = newIndex;
    });

    await _setupCamera(newIndex);
  }

  /// Capture receipt image
  Future<void> _captureImage() async {
    if (_cameraController == null || 
        !_cameraController!.value.isInitialized ||
        _cameraController!.value.isTakingPicture) {
      return;
    }

    try {
      // Show capture animation
      _showCaptureAnimation();

      final image = await _cameraController!.takePicture();
      logger.i('Image captured: ${image.path}');

      // Navigate to preview screen with captured image
      if (mounted) {
        context.push('/preview', extra: image.path);
      }
    } catch (e) {
      logger.e('Image capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture image: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Show capture animation
  void _showCaptureAnimation() {
    // TODO: Implement capture animation
    // For now, provide haptic feedback
    // HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!_isPermissionGranted) {
      return _buildPermissionDeniedView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return _buildLoadingView();
    }

    return _buildCameraView();
  }

  /// Build permission denied view
  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 80,
              color: Colors.white70,
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            const Text(
              'Camera Permission Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.smallPadding),
            const Text(
              'Please grant camera permission to scan receipts',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.defaultPadding * 2),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Grant Permission'),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text(
                'Open Settings',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build error view
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            const Text(
              'Camera Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.defaultPadding * 2),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build loading view
  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.white,
          ),
          SizedBox(height: AppConstants.defaultPadding),
          Text(
            'Initializing camera...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Build camera view
  Widget _buildCameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        CameraPreview(_cameraController!),
        
        // Overlay and controls
        _buildOverlay(),
        
        // Top controls
        _buildTopControls(),
        
        // Bottom controls
        _buildBottomControls(),
      ],
    );
  }

  /// Build camera overlay with receipt frame guide
  Widget _buildOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
      ),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.width * 0.8 * (4/3), // 4:3 aspect ratio
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
          ),
          child: Stack(
            children: [
              // Corner guides
              ...List.generate(4, (index) => _buildCornerGuide(index)),
              
              // Center guide text
              const Center(
                child: Text(
                  'Position receipt within frame',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build corner guide for overlay
  Widget _buildCornerGuide(int index) {
    const size = 20.0;
    const thickness = 3.0;
    
    late Alignment alignment;
    late Widget child;
    
    switch (index) {
      case 0: // Top-left
        alignment = Alignment.topLeft;
        child = Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white, width: thickness),
              left: BorderSide(color: Colors.white, width: thickness),
            ),
          ),
        );
        break;
      case 1: // Top-right
        alignment = Alignment.topRight;
        child = Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white, width: thickness),
              right: BorderSide(color: Colors.white, width: thickness),
            ),
          ),
        );
        break;
      case 2: // Bottom-left
        alignment = Alignment.bottomLeft;
        child = Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white, width: thickness),
              left: BorderSide(color: Colors.white, width: thickness),
            ),
          ),
        );
        break;
      case 3: // Bottom-right
        alignment = Alignment.bottomRight;
        child = Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white, width: thickness),
              right: BorderSide(color: Colors.white, width: thickness),
            ),
          ),
        );
        break;
    }
    
    return Align(
      alignment: alignment,
      child: child,
    );
  }

  /// Build top controls
  Widget _buildTopControls() {
    return Positioned(
      top: AppConstants.defaultPadding,
      left: AppConstants.defaultPadding,
      right: AppConstants.defaultPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App title
          const Text(
            AppConfig.appName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black,
                ),
              ],
            ),
          ),
          
          // Settings button
          IconButton(
            onPressed: () {
              // TODO: Navigate to settings
            },
            icon: const Icon(
              Icons.settings,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  /// Build bottom controls
  Widget _buildBottomControls() {
    return Positioned(
      bottom: AppConstants.defaultPadding * 2,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Test image button
          IconButton(
            onPressed: _showTestReceiptDialog,
            icon: Container(
              padding: const EdgeInsets.all(AppConstants.smallPadding),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          
          // Capture button
          GestureDetector(
            onTap: _captureImage,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 4,
                ),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.black,
                size: 36,
              ),
            ),
          ),
          
          // Flash/Switch camera controls
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flash toggle
              IconButton(
                onPressed: _toggleFlash,
                icon: Container(
                  padding: const EdgeInsets.all(AppConstants.smallPadding),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              
              // Camera switch (if multiple cameras available)
              if (_cameras.length > 1)
                IconButton(
                  onPressed: _switchCamera,
                  icon: Container(
                    padding: const EdgeInsets.all(AppConstants.smallPadding),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.switch_camera,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Show test receipt selection dialog
  Future<void> _showTestReceiptDialog() async {
    final testReceipts = [
      {
        'name': 'Test Receipt (Original)',
        'path': 'assets/images/test_receipt.png',
        'description': 'Standard receipt format with VAT',
      },
      {
        'name': 'Test Receipt v2 (Table Format)',
        'path': 'assets/images/test_receipt_v2.png',
        'description': 'Receipt with Tax Breakdown table',
      },
      {
        'name': 'Test Receipt v3 (Multiple Tax Rates)',
        'path': 'assets/images/test_receipt_v3.png',
        'description': 'Receipt with multiple tax rates (14% and 24%)',
      },
      {
        'name': 'Test Receipt (Finnish)',
        'path': 'assets/images/test_receipt_fi.png',
        'description': 'Finnish receipt format (Suomi)',
      },
      {
        'name': 'Test Receipt (German)',
        'path': 'assets/images/test_receipt_de.png',
        'description': 'German receipt format (Deutsch)',
      },
      {
        'name': 'Test Receipt (Swedish)',
        'path': 'assets/images/test_receipt_sv.png',
        'description': 'Swedish receipt format (Svenska)',
      },
      {
        'name': 'Test Receipt R1',
        'path': 'assets/images/test_receipt_r1.png',
        'description': 'Real-world receipt format (R1)',
      },
      {
        'name': 'Test Receipt R2',
        'path': 'assets/images/test_receipt_r2.png',
        'description': 'Real-world receipt format (R2)',
      },
      {
        'name': 'Test Invoice R1',
        'path': 'assets/images/test_invoice_r1.png',
        'description': 'Real-world invoice format (R1)',
      },
      {
        'name': 'Test Invoice R2',
        'path': 'assets/images/test_invoice_r2.png',
        'description': 'Real-world invoice format (R2)',
      },
    ];

    if (!mounted) return;

    final selectedReceipt = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Test Receipt'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: testReceipts.length,
            itemBuilder: (context, index) {
              final receipt = testReceipts[index];
              return ListTile(
                title: Text(receipt['name']!),
                subtitle: Text(
                  receipt['description']!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                leading: const Icon(Icons.receipt),
                onTap: () {
                  Navigator.of(context).pop(receipt);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedReceipt != null) {
      await _useTestImage(selectedReceipt['path']!);
    }
  }

  /// Use test receipt image for OCR testing
  Future<void> _useTestImage(String assetPath) async {
    try {
      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      
      // Load asset image
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Extract filename from path
      final filename = assetPath.split('/').last;
      
      // Create temporary file
      final String tempPath = '${tempDir.path}/$filename';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes);
      
      logger.i('Using test receipt image: $tempPath (from $assetPath)');
      
      // Navigate to preview screen
      if (mounted) {
        context.pushNamed('preview', extra: tempPath);
      }
    } catch (e) {
      logger.e('Failed to use test image: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load test image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}