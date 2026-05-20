import 'package:flutter_test/flutter_test.dart';
import 'package:yoze/models/extracted_medication.dart';
import 'package:yoze/services/schedule_planner.dart';

void main() {
  test('buildPlan uses max frequency for slot count', () {
    final meds = [
      ExtractedMedication(drugName: 'A', frequency: 3),
      ExtractedMedication(drugName: 'B', frequency: 4),
    ];

    final plan = SchedulePlanner.buildPlan(
      medications: meds,
      startHour: 8,
      startMinute: 0,
    );

    expect(plan.slots.length, 4);
    expect(plan.slots.map((s) => '${s.hour}:${s.minute}').toList(), [
      '8:0',
      '12:0',
      '16:0',
      '20:0',
    ]);
  });

  test('buildPlan distributes medications based on individual frequency', () {
    final medA = ExtractedMedication(drugName: 'A', frequency: 3);
    final medB = ExtractedMedication(drugName: 'B', frequency: 4);

    final plan = SchedulePlanner.buildPlan(
      medications: [medA, medB],
      startHour: 8,
      startMinute: 0,
    );

    final aCount = plan.slots
        .where((slot) => slot.medications.any((m) => m.drugName == 'A'))
        .length;
    final bCount = plan.slots
        .where((slot) => slot.medications.any((m) => m.drugName == 'B'))
        .length;

    expect(aCount, 3);
    expect(bCount, 4);
  });
}
