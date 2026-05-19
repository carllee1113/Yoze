import 'package:flutter_test/flutter_test.dart';
import 'package:yoze/models/extracted_medication.dart';

void main() {
  test('getAllTimes returns evenly spaced daily times', () {
    final med = ExtractedMedication(
      drugName: 'PARACETAMOL',
      hour: 8,
      minute: 30,
      frequency: 3,
    );

    expect(med.getAllTimes(), [
      {'hour': 8, 'minute': 30},
      {'hour': 16, 'minute': 30},
      {'hour': 0, 'minute': 30},
    ]);
  });

  test('getAllTimes returns empty list when no time is set', () {
    final med = ExtractedMedication(drugName: 'PARACETAMOL', frequency: 2);
    expect(med.getAllTimes(), isEmpty);
  });
}
