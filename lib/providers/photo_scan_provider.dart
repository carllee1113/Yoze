import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/extracted_medication.dart';
import '../services/ocr_service.dart';

enum ScanState { idle, capturing, processing, verified, error }

class PhotoScanState {
  final ScanState state;
  final String? imagePath;
  final List<ExtractedMedication> extractedMedications;
  final String? errorMessage;
  final double progress;

  PhotoScanState({
    this.state = ScanState.idle,
    this.imagePath,
    this.extractedMedications = const [],
    this.errorMessage,
    this.progress = 0.0,
  });

  PhotoScanState copyWith({
    ScanState? state,
    String? imagePath,
    List<ExtractedMedication>? extractedMedications,
    String? errorMessage,
    double? progress,
  }) {
    return PhotoScanState(
      state: state ?? this.state,
      imagePath: imagePath ?? this.imagePath,
      extractedMedications: extractedMedications ?? this.extractedMedications,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
    );
  }
}

class PhotoScanNotifier extends StateNotifier<PhotoScanState> {
  PhotoScanNotifier() : super(PhotoScanState());

  Future<String?> saveImage(File image) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${appDir.path}/scanned_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedPath = '${photosDir.path}/$timestamp.jpg';
      await image.copy(savedPath);
      return savedPath;
    } catch (e) {
      return null;
    }
  }

  Future<void> processImage(String imagePath) async {
    state = state.copyWith(
      state: ScanState.processing,
      imagePath: imagePath,
      progress: 0.1,
    );

    try {
      state = state.copyWith(progress: 0.3);
      final medications = await OcrService.processImage(imagePath);

      state = state.copyWith(
        state: ScanState.verified,
        extractedMedications: medications,
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        state: ScanState.error,
        errorMessage: '識別失敗：$e',
      );
    }
  }

  void updateMedication(int index, ExtractedMedication updated) {
    final updatedList = List<ExtractedMedication>.from(state.extractedMedications);
    updatedList[index] = updated;
    state = state.copyWith(extractedMedications: updatedList);
  }

  void removeMedication(int index) {
    final updatedList = List<ExtractedMedication>.from(state.extractedMedications);
    updatedList.removeAt(index);
    state = state.copyWith(extractedMedications: updatedList);
  }

  void addMedication(ExtractedMedication medication) {
    final updatedList = List<ExtractedMedication>.from(state.extractedMedications);
    updatedList.add(medication);
    state = state.copyWith(extractedMedications: updatedList);
  }

  void reset() {
    state = PhotoScanState();
  }
}

final photoScanProvider =
    StateNotifierProvider<PhotoScanNotifier, PhotoScanState>((ref) {
  return PhotoScanNotifier();
});