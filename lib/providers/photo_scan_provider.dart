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
  final String? diagnosticMessage;
  final double progress;

  PhotoScanState({
    this.state = ScanState.idle,
    this.imagePath,
    this.extractedMedications = const [],
    this.errorMessage,
    this.diagnosticMessage,
    this.progress = 0.0,
  });

  PhotoScanState copyWith({
    ScanState? state,
    String? imagePath,
    List<ExtractedMedication>? extractedMedications,
    String? errorMessage,
    String? diagnosticMessage,
    double? progress,
  }) {
    return PhotoScanState(
      state: state ?? this.state,
      imagePath: imagePath ?? this.imagePath,
      extractedMedications: extractedMedications ?? this.extractedMedications,
      errorMessage: errorMessage ?? this.errorMessage,
      diagnosticMessage: diagnosticMessage ?? this.diagnosticMessage,
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
    state = PhotoScanState(
      state: ScanState.processing,
      imagePath: imagePath,
      progress: 0.1,
    );

    try {
      state = state.copyWith(progress: 0.3);
      final medications = (await OcrService.processImage(
        imagePath,
      )).map((med) => med.copyWith(sourcePhotoPath: imagePath)).toList();

      state = state.copyWith(
        state: ScanState.verified,
        extractedMedications: medications,
        diagnosticMessage: OcrService.lastDiagnostic,
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        state: ScanState.error,
        errorMessage: '識別失敗：$e',
        diagnosticMessage: OcrService.lastDiagnostic,
      );
    }
  }

  void updateMedication(int index, ExtractedMedication updated) {
    final updatedList = List<ExtractedMedication>.from(
      state.extractedMedications,
    );
    updatedList[index] = updated;
    state = state.copyWith(extractedMedications: updatedList);
  }

  void removeMedication(int index) {
    final updatedList = List<ExtractedMedication>.from(
      state.extractedMedications,
    );
    updatedList.removeAt(index);
    state = state.copyWith(extractedMedications: updatedList);
  }

  void addMedication(ExtractedMedication medication) {
    final updatedList = List<ExtractedMedication>.from(
      state.extractedMedications,
    );
    updatedList.insert(0, medication);
    state = state.copyWith(extractedMedications: updatedList);
  }

  void setMedications(List<ExtractedMedication> medications) {
    state = state.copyWith(
      extractedMedications: List<ExtractedMedication>.from(medications),
      state: ScanState.verified,
      progress: 1.0,
      errorMessage: null,
    );
  }

  void reset() {
    state = PhotoScanState();
  }
}

final photoScanProvider =
    StateNotifierProvider<PhotoScanNotifier, PhotoScanState>((ref) {
      return PhotoScanNotifier();
    });
