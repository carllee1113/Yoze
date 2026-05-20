import 'package:flutter/material.dart';

import '../models/dose_record.dart';

class SlotMedicationItem {
  final int medicationId;
  final String medicationName;
  final String dosage;
  final int colorIndex;
  final Color color;
  final String colorLabel;
  final DoseStatus status;

  const SlotMedicationItem({
    required this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.colorIndex,
    required this.color,
    required this.colorLabel,
    required this.status,
  });

  bool get isDone => status == DoseStatus.confirmed;
}

class IntakeSlotData {
  final int hour;
  final int minute;
  final List<SlotMedicationItem> items;

  const IntakeSlotData({
    required this.hour,
    required this.minute,
    required this.items,
  });

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  bool get isComplete => items.isNotEmpty && items.every((i) => i.isDone);
}

class RainbowProgress extends StatelessWidget {
  final List<IntakeSlotData> slots;
  final Future<void> Function(IntakeSlotData slot, bool complete)? onToggleAll;
  final Future<void> Function(
    IntakeSlotData slot,
    SlotMedicationItem item,
    bool complete,
  )? onToggleItem;

  const RainbowProgress({
    super.key,
    required this.slots,
    this.onToggleAll,
    this.onToggleItem,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '還沒有添加藥物\n點下方 + 添加',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    return Column(
      children: slots.map((slot) => _buildIntakeCard(context, slot)).toList(),
    );
  }

  Widget _buildIntakeCard(BuildContext context, IntakeSlotData slot) {
    final allDone = slot.isComplete;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: allDone ? Colors.green.shade400 : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule),
                const SizedBox(width: 8),
                Text(
                  slot.timeLabel,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Text('全部', style: TextStyle(fontWeight: FontWeight.w600)),
                Checkbox(
                  value: allDone,
                  onChanged: onToggleAll == null
                      ? null
                      : (v) {
                          if (v == null) return;
                          onToggleAll!(slot, v);
                        },
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...slot.items.map((item) => _buildMedicationCard(slot, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationCard(IntakeSlotData slot, SlotMedicationItem item) {
    final done = item.isDone;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: done ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? Colors.green.shade300 : item.color.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
            child: Center(
              child: Text(
                item.colorLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.medicationName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (item.dosage.isNotEmpty)
                  Text(
                    item.dosage,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
              ],
            ),
          ),
          Text(
            done ? '完成' : '等待中',
            style: TextStyle(
              color: done ? Colors.green.shade700 : Colors.orange.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
          Checkbox(
            value: done,
            onChanged: onToggleItem == null
                ? null
                : (v) {
                    if (v == null) return;
                    onToggleItem!(slot, item, v);
                  },
          ),
        ],
      ),
    );
  }
}
