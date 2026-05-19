import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/extracted_medication.dart';
import 'extraction_logic.dart';
import 'fuzzy_matcher_service.dart';

class OcrService {
  static final TextRecognizer _textRecognizer = TextRecognizer();
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    await FuzzyMatcherService.loadReference();
    _isInitialized = true;
  }

  static Future<List<ExtractedMedication>> processImage(String imagePath) async {
    // Ensure reference data is loaded
    await initialize();

    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    if (recognizedText.text.isEmpty) {
      return [];
    }

    final fullText = recognizedText.text;
    final blocks = recognizedText.blocks.map((block) {
      return OcrTextBlock(
        text: block.text,
        start: block.boundingBox.left.toInt(),
        end: block.boundingBox.right.toInt(),
      );
    }).toList();

    // Parse with extraction logic
    final medications = ExtractionLogic.parseTextBlocks(blocks, fullText);

    // Cross-reference with medicine database to fix typos and fill missing fields
    final correctedMedications = <ExtractedMedication>[];
    for (final med in medications) {
      final corrected = await _crossReferenceAndCorrect(med, fullText);
      correctedMedications.add(corrected);
    }

    return correctedMedications;
  }

  static Future<ExtractedMedication> _crossReferenceAndCorrect(
    ExtractedMedication med,
    String rawText,
  ) async {
    // Try to extract permit number from raw text
    final permitNo = FuzzyMatcherService.extractPermitNumber(rawText);

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
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
