import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/extracted_medication.dart';
import 'extraction_logic.dart';
import 'fuzzy_matcher_service.dart';

class OcrService {
  static final TextRecognizer _latinTextRecognizer = TextRecognizer();
  static final TextRecognizer _chineseTextRecognizer =
      TextRecognizer(script: TextRecognitionScript.chinese);
  static bool _isInitialized = false;
  static String _lastDiagnostic = '';

  static String get lastDiagnostic => _lastDiagnostic;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    await FuzzyMatcherService.loadReference();
    _isInitialized = true;
  }

  static Future<List<ExtractedMedication>> processImage(String imagePath) async {
    // Ensure reference data is loaded
    await initialize();

    final inputImage = InputImage.fromFilePath(imagePath);
    final imageSize = await _safeImageSize(imagePath);
    final latinText = await _latinTextRecognizer.processImage(inputImage);

    var fullText = latinText.text;
    var blocks = _toOcrTextBlocks(latinText);
    var chineseChars = 0;
    var chineseBlocks = 0;
    var outcome = 'started';
    _setDiagnostic(
      imagePath: imagePath,
      imageSize: imageSize,
      latinChars: latinText.text.length,
      latinBlocks: latinText.blocks.length,
      chineseChars: chineseChars,
      chineseBlocks: chineseBlocks,
      outcome: 'Latin OCR completed',
      rawText: fullText,
    );

    // Parse with extraction logic
    var medications = ExtractionLogic.parseTextBlocks(blocks, fullText);
    if (medications.isNotEmpty) {
      outcome = 'Latin parser found medication';
    }

    if (medications.isEmpty) {
      final chineseText = await _tryChineseRecognition(inputImage);
      if (chineseText != null && chineseText.text.trim().isNotEmpty) {
        chineseChars = chineseText.text.length;
        chineseBlocks = chineseText.blocks.length;
        fullText = _mergeRecognizedText(fullText, chineseText.text);
        blocks = [
          ...blocks,
          ..._toOcrTextBlocks(chineseText),
        ];
        medications = ExtractionLogic.parseTextBlocks(blocks, fullText);
        outcome = medications.isEmpty
            ? 'Chinese OCR fallback completed; parser found no medication'
            : 'Chinese OCR fallback found medication';
      } else {
        outcome = 'Chinese OCR returned no text';
      }
    }

    if (fullText.trim().isEmpty) {
      _setDiagnostic(
        imagePath: imagePath,
        imageSize: imageSize,
        latinChars: latinText.text.length,
        latinBlocks: latinText.blocks.length,
        chineseChars: chineseChars,
        chineseBlocks: chineseBlocks,
        outcome: 'No text recognized; manual card created',
        rawText: fullText,
      );
      return [_buildManualMedication(rawText: '')];
    }

    // Fallback: when parser fails, try permit-number / weak-structure recovery
    // so user can still get an editable medication card instead of empty result.
    if (medications.isEmpty) {
      final fallback = await _buildFallbackMedication(fullText);
      if (fallback != null) {
        medications = [fallback];
      }
    }

    if (medications.isEmpty) {
      outcome = 'Text recognized but parser found no medication; manual card created';
      medications = [_buildManualMedication(rawText: fullText)];
    }

    // Cross-reference with medicine database to fix typos and fill missing fields
    final correctedMedications = <ExtractedMedication>[];
    for (final med in medications) {
      final corrected = await _crossReferenceAndCorrect(med, fullText);
      correctedMedications.add(corrected);
    }

    _setDiagnostic(
      imagePath: imagePath,
      imageSize: imageSize,
      latinChars: latinText.text.length,
      latinBlocks: latinText.blocks.length,
      chineseChars: chineseChars,
      chineseBlocks: chineseBlocks,
      outcome: '$outcome; medication cards=${correctedMedications.length}',
      rawText: fullText,
    );

    return correctedMedications;
  }

  static Future<int?> _safeImageSize(String imagePath) async {
    try {
      return await File(imagePath).length();
    } catch (_) {
      return null;
    }
  }

  static void _setDiagnostic({
    required String imagePath,
    required int? imageSize,
    required int latinChars,
    required int latinBlocks,
    required int chineseChars,
    required int chineseBlocks,
    required String outcome,
    required String rawText,
  }) {
    final preview = rawText
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final trimmedPreview = preview.length > 220
        ? '${preview.substring(0, 220)}...'
        : preview;
    final sizeLabel = imageSize == null ? 'unknown' : '${(imageSize / 1024).round()} KB';

    _lastDiagnostic = [
      'OCR diagnostic',
      'Outcome: $outcome',
      'Image: $sizeLabel',
      'Latin: $latinChars chars, $latinBlocks blocks',
      'Chinese: $chineseChars chars, $chineseBlocks blocks',
      if (trimmedPreview.isNotEmpty) 'Text preview: $trimmedPreview',
      if (trimmedPreview.isEmpty) 'Text preview: <empty>',
      'Path: $imagePath',
    ].join('\n');
    debugPrint('[YOZE OCR]\n$_lastDiagnostic');
  }

  static List<OcrTextBlock> _toOcrTextBlocks(RecognizedText recognizedText) {
    return recognizedText.blocks.map((block) {
      return OcrTextBlock(
        text: block.text,
        start: block.boundingBox.left.toInt(),
        end: block.boundingBox.right.toInt(),
      );
    }).toList();
  }

  static Future<RecognizedText?> _tryChineseRecognition(InputImage inputImage) async {
    try {
      return await _chineseTextRecognizer.processImage(inputImage);
    } catch (e) {
      _lastDiagnostic = [
        if (_lastDiagnostic.isNotEmpty) _lastDiagnostic,
        'Chinese recognizer error: $e',
      ].join('\n');
      debugPrint('[YOZE OCR] Chinese recognizer failed: $e');
      return null;
    }
  }

  static String _mergeRecognizedText(String primary, String secondary) {
    final first = primary.trim();
    final second = secondary.trim();
    if (first.isEmpty) return second;
    if (second.isEmpty || first == second || first.contains(second)) return first;
    if (second.contains(first)) return second;
    return '$first\n$second';
  }

  static Future<ExtractedMedication?> _buildFallbackMedication(String text) async {
    final permitNo = FuzzyMatcherService.extractPermitNumber(text);
    if (permitNo.isNotEmpty) {
      final byPermit = await FuzzyMatcherService.findByPermitNo(permitNo);
      if (byPermit != null) {
        return ExtractedMedication(
          drugName: byPermit.name,
          form: byPermit.form,
          dosagePerUnit: byPermit.dosage,
          administration: '',
          frequency: 1,
          dosePerTime: '',
          durationDays: null,
          totalQuantity: null,
          permitNo: byPermit.permitNo,
          schedule: '',
          hour: 8,
          minute: 0,
          colorIndex: 0,
          confidence: 0.55,
          rawText: text,
        );
      }
    }

    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.isEmpty) return null;

    final dosagePattern = RegExp(r'(\d+\.?\d*)\s*(mg|g|ml|mcg)', caseSensitive: false);
    final dosage = dosagePattern.firstMatch(normalized)?.group(0)?.toUpperCase() ?? '';

    const formKeywords = [
      'TABLET',
      'CAPSULE',
      'TAB',
      'CAP',
      'SYRUP',
      'CREAM',
      'OINTMENT',
      'PATCH',
      'SOLUTION',
      'INJECTION',
      'DROP',
      'LOZENGE',
    ];

    String form = '';
    final upper = normalized.toUpperCase();
    for (final f in formKeywords) {
      if (upper.contains(f)) {
        form = f == 'TAB' ? 'TABLET' : f == 'CAP' ? 'CAPSULE' : f;
        break;
      }
    }

    if (form.isEmpty && dosage.isEmpty && permitNo.isEmpty) {
      return null;
    }

    final lineCandidates = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    String bestName = '';
    for (final line in lineCandidates) {
      final lineUpper = line.toUpperCase();
      if (!RegExp(r'[A-Z]{3,}').hasMatch(lineUpper)) continue;
      if (lineUpper.contains('HOSPITAL') ||
          lineUpper.contains('CLINIC') ||
          lineUpper.contains('PATIENT') ||
          lineUpper.contains('DOCTOR')) {
        continue;
      }
      if (lineUpper.contains('HK-') && lineUpper.length < 16) continue;

      final stripped = lineUpper
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'[^A-Z0-9 /-]'), '')
          .trim();
      if (stripped.length < 3) continue;
      bestName = stripped;
      break;
    }

    if (bestName.isEmpty) {
      bestName = '未能完整識別（請手動確認）';
    }

    return ExtractedMedication(
      drugName: bestName,
      form: form,
      dosagePerUnit: dosage,
      administration: '',
      frequency: 1,
      dosePerTime: '',
      durationDays: null,
      totalQuantity: null,
      permitNo: permitNo,
      schedule: '',
      hour: 8,
      minute: 0,
      colorIndex: 0,
      confidence: 0.35,
      rawText: text,
    );
  }

  static ExtractedMedication _buildManualMedication({required String rawText}) {
    return ExtractedMedication(
      drugName: '',
      form: '藥丸',
      dosagePerUnit: '',
      administration: '飯後',
      frequency: 1,
      dosePerTime: '4',
      durationDays: null,
      totalQuantity: null,
      permitNo: null,
      schedule: '',
      hour: 8,
      minute: 0,
      colorIndex: 0,
      confidence: 0.05,
      rawText: rawText,
    );
  }

  static Future<ExtractedMedication> _crossReferenceAndCorrect(
    ExtractedMedication med,
    String rawText,
  ) async {
    // Try to extract permit number from raw text
    final permitNo = FuzzyMatcherService.extractPermitNumber(rawText);

    if (permitNo.isNotEmpty) {
      final permitMatch = await FuzzyMatcherService.findByPermitNo(permitNo);
      if (permitMatch != null) {
        return med.copyWith(
          drugName: permitMatch.name,
          form: med.form.isNotEmpty ? med.form : permitMatch.form,
          dosagePerUnit: med.dosagePerUnit.isNotEmpty
              ? med.dosagePerUnit
              : permitMatch.dosage,
          permitNo: permitMatch.permitNo,
        );
      }
    }

    // Find best match in database
    final matchResult = await FuzzyMatcherService.findBestMatch(med.drugName);

    if (matchResult.match != null && matchResult.confidence >= 0.5) {
      final ref = matchResult.match!;

      return med.copyWith(
        drugName: ref.name, // Correct the drug name
        form: med.form.isNotEmpty ? med.form : ref.form,
        dosagePerUnit: med.dosagePerUnit.isNotEmpty ? med.dosagePerUnit : ref.dosage,
        permitNo: permitNo.isNotEmpty ? permitNo : ref.permitNo,
        // Keep user's extracted schedule, frequency, etc.
      );
    }

    return med.copyWith(permitNo: permitNo);
  }

  static Future<String> extractRawText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final latinText = await _latinTextRecognizer.processImage(inputImage);
    final chineseText = await _tryChineseRecognition(inputImage);
    return _mergeRecognizedText(latinText.text, chineseText?.text ?? '');
  }

  static void dispose() {
    _latinTextRecognizer.close();
    _chineseTextRecognizer.close();
  }
}
