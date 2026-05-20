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

  test('generateDailySlots keeps high frequency medicines inside 12 hours', () {
    final slots = SchedulePlanner.generateDailySlots(
      startHour: 8,
      startMinute: 0,
      slotCount: 7,
    );

    expect(slots.length, 7);
    expect(slots.first.hour, 8);
    expect(slots.first.minute, 0);
    expect(slots.last.hour, 20);
    expect(slots.last.minute, 0);

    final minutes = slots.map((s) => s.hour * 60 + s.minute).toList();
    expect(minutes, isNot(contains(0)));
    expect(minutes, isNot(contains(180)));
    expect(minutes.every((minute) => minute >= 8 * 60), isTrue);
    expect(minutes.every((minute) => minute <= 20 * 60), isTrue);
  });
}
