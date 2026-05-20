import '../models/extracted_medication.dart';

class ScheduleSlot {
  final int index;
  final int hour;
  final int minute;
  final List<ExtractedMedication> medications;

  const ScheduleSlot({
    required this.index,
    required this.hour,
    required this.minute,
    required this.medications,
  });
}

class SchedulePlan {
  final List<ScheduleSlot> slots;

  const SchedulePlan({required this.slots});
}

class SchedulePlanner {
  static List<ScheduleSlot> generateDailySlots({
    required int startHour,
    required int startMinute,
    required int slotCount,
  }) {
    if (slotCount <= 0) return const [];
    final totalStartMinutes = startHour * 60 + startMinute;
    // Product rule: all daily doses are distributed inside the user's
    // 12-hour waking window. For example, a start time of 08:00 and
    // 4 slots gives 08:00, 12:00, 16:00, 20:00.
    const activeWindowMinutes = 12 * 60;

    final slots = <ScheduleSlot>[];
    for (int i = 0; i < slotCount; i++) {
      final offsetMinutes = slotCount == 1
          ? 0
          : (activeWindowMinutes * i / (slotCount - 1)).round();
      final totalMinutes = (totalStartMinutes + offsetMinutes) % (24 * 60);
      slots.add(
        ScheduleSlot(
          index: i,
          hour: totalMinutes ~/ 60,
          minute: totalMinutes % 60,
          medications: const [],
        ),
      );
    }
    return slots;
  }

  static SchedulePlan buildPlan({
    required List<ExtractedMedication> medications,
    required int startHour,
    required int startMinute,
  }) {
    if (medications.isEmpty) {
      return const SchedulePlan(slots: []);
    }

    final maxFrequency = medications
        .map((m) => m.frequency.clamp(1, 8))
        .reduce((a, b) => a > b ? a : b);

    final baseSlots = generateDailySlots(
      startHour: startHour,
      startMinute: startMinute,
      slotCount: maxFrequency,
    );

    final slotBuckets = List<List<ExtractedMedication>>.generate(
      maxFrequency,
      (_) => <ExtractedMedication>[],
    );

    for (final med in medications) {
      final doseCount = med.frequency.clamp(1, maxFrequency);
      final indices = _evenlyDistributedIndices(maxFrequency, doseCount);
      for (final idx in indices) {
        slotBuckets[idx].add(med);
      }
    }

    final slots = <ScheduleSlot>[];
    for (int i = 0; i < baseSlots.length; i++) {
      final slot = baseSlots[i];
      slots.add(
        ScheduleSlot(
          index: slot.index,
          hour: slot.hour,
          minute: slot.minute,
          medications: slotBuckets[i],
        ),
      );
    }

    return SchedulePlan(slots: slots);
  }

  static List<int> _evenlyDistributedIndices(int totalSlots, int doseCount) {
    if (doseCount >= totalSlots) {
      return List<int>.generate(totalSlots, (i) => i);
    }

    if (doseCount == 1) {
      return const [0];
    }

    final result = <int>[];
    for (int i = 0; i < doseCount; i++) {
      final ratio = i / (doseCount - 1);
      final idx = (ratio * (totalSlots - 1)).round();
      result.add(idx);
    }

    // Ensure uniqueness while preserving order.
    final unique = <int>[];
    for (final idx in result) {
      if (!unique.contains(idx)) {
        unique.add(idx);
      }
    }

    // If rounding caused collisions, fill missing indices from start.
    if (unique.length < doseCount) {
      for (int i = 0; i < totalSlots && unique.length < doseCount; i++) {
        if (!unique.contains(i)) {
          unique.add(i);
        }
      }
      unique.sort();
    }

    return unique;
  }
}
