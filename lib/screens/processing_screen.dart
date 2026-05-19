import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/photo_scan_provider.dart';
import 'verification_screen.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  final String imagePath;

  const ProcessingScreen({super.key, required this.imagePath});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(photoScanProvider.notifier).processImage(widget.imagePath);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(photoScanProvider);

    ref.listen<PhotoScanState>(photoScanProvider, (previous, next) {
      if (next.state == ScanState.verified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VerificationScreen(imagePath: widget.imagePath),
          ),
        );
      } else if (next.state == ScanState.error) {
        _showError(next.errorMessage ?? '識別失敗');
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Image preview
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: FileImage(File(widget.imagePath)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Processing indicator
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),

              // Status text
              Text(
                _getStatusText(scanState.progress),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: scanState.progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade800,
                  valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
                ),
              ),
              const SizedBox(height: 16),

              // Hints
              Text(
                '請稍候，正在識別文字...',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(double progress) {
    if (progress < 0.3) return '正在讀取圖片...';
    if (progress < 0.6) return '正在識別文字...';
    if (progress < 0.9) return '正在分析藥物...';
    return '即將完成...';
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('識別失敗'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('返回重拍'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(photoScanProvider.notifier).reset();
            },
            child: const Text('手動輸入'),
          ),
        ],
      ),
    );
  }
}