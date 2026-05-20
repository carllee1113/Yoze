import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'processing_screen.dart';

class PhotoCaptureScreen extends ConsumerStatefulWidget {
  final bool returnExtractedMedications;

  const PhotoCaptureScreen({
    super.key,
    this.returnExtractedMedications = false,
  });

  @override
  ConsumerState<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends ConsumerState<PhotoCaptureScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  FlashMode _flashMode = FlashMode.auto;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _errorMessage = '找不到相機';
        });
        return;
      }

      final camera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      await _configureCameraForLabels();
      await _controller!.setFlashMode(_flashMode);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '相機初始化失敗: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    setState(() {
      _flashMode = switch (_flashMode) {
        FlashMode.auto => FlashMode.always,
        FlashMode.always => FlashMode.off,
        _ => FlashMode.auto,
      };
    });
    await _controller!.setFlashMode(_flashMode);
  }

  Future<void> _configureCameraForLabels() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
      await controller.setFocusPoint(const Offset(0.5, 0.5));
      await controller.setExposurePoint(const Offset(0.5, 0.5));
    } catch (_) {
      // Some Android camera drivers do not support manual focus/exposure points.
    }
  }

  Future<void> _captureImage() async {
    if (_controller == null || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      await _configureCameraForLabels();
      await Future<void>.delayed(const Duration(milliseconds: 250));

      final XFile image = await _controller!.takePicture();

      final savedPath = await _saveImage(image.path);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProcessingScreen(
              imagePath: savedPath,
              returnExtractedMedications: widget.returnExtractedMedications,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍攝失敗: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<String> _saveImage(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/scanned_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final savedPath = '${photosDir.path}/$timestamp.jpg';

    // OCR works best with the full label. The on-screen frame is only a guide.
    await File(sourcePath).copy(savedPath);

    return savedPath;
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      final savedPath = await _saveImage(image.path);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProcessingScreen(
              imagePath: savedPath,
              returnExtractedMedications: widget.returnExtractedMedications,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('讀取圖片失敗: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _errorMessage != null
            ? _buildError()
            : !_isInitialized
                ? _buildLoading()
                : _buildCamera(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            '相機初始化中...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCamera() {
    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(_controller!),
        ),

        // Overlay guide
        _buildOverlayGuide(),

        // Top controls
        _buildTopControls(),

        // Bottom controls
        _buildBottomControls(),
      ],
    );
  }

  Widget _buildOverlayGuide() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _OverlayGuidePainter(),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 32),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _pickFromGallery,
                icon: const Icon(
                  Icons.photo_library,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              IconButton(
                onPressed: _toggleFlash,
                icon: Icon(
                  _flashMode == FlashMode.off
                      ? Icons.flash_off
                      : _flashMode == FlashMode.always
                          ? Icons.flash_on
                          : Icons.flash_auto,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Column(
        children: [
          const Text(
            '將藥物標籤平整放置於框內',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery button
              GestureDetector(
                onTap: _pickFromGallery,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              // Capture button
              GestureDetector(
                onTap: _isCapturing ? null : _captureImage,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: _isCapturing
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.grey,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              // Spacer for symmetry
              const SizedBox(width: 56),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '或點擊左側圖庫上傳藥物標籤',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class CameraPreview extends StatelessWidget {
  final CameraController controller;

  const CameraPreview(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final scale = size.aspectRatio * controller.value.aspectRatio;

        return ClipRect(
          child: Transform.scale(
            scale: scale < 1 ? 1 / scale : scale,
            child: Center(
              child: CameraPreview2(controller: controller),
            ),
          ),
        );
      },
    );
  }
}

class CameraPreview2 extends StatelessWidget {
  final CameraController controller;

  const CameraPreview2({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return controller.buildPreview();
  }
}

class _OverlayGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    const frameWidth = 0.85;
    const frameHeight = 0.35;
    const cornerRadius = 16.0;

    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * frameWidth,
      height: size.height * frameHeight,
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(cornerRadius)));

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(cornerRadius)),
      borderPaint,
    );

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;

    final corners = [
      Offset(frameRect.left, frameRect.top),
      Offset(frameRect.right, frameRect.top),
      Offset(frameRect.left, frameRect.bottom),
      Offset(frameRect.right, frameRect.bottom),
    ];

    for (int i = 0; i < corners.length; i++) {
      final corner = corners[i];
      final isLeft = i % 2 == 0;
      final isTop = i < 2;

      canvas.drawLine(
        Offset(isLeft ? corner.dx : corner.dx - cornerLength, corner.dy),
        corner,
        cornerPaint,
      );
      canvas.drawLine(
        Offset(corner.dx, isTop ? corner.dy : corner.dy - cornerLength),
        corner,
        cornerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
