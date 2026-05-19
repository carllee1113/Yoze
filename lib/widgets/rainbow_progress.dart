import 'package:flutter/material.dart';
import '../theme/rainbow_colors.dart';
import '../models/dose_record.dart';

class RainbowProgress extends StatelessWidget {
  final List<SlotData> slots;
  final void Function(SlotData slot)? onTap;

  const RainbowProgress({super.key, required this.slots, this.onTap});

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
      children: slots.map((slot) => GestureDetector(
        onTap: onTap != null ? () => onTap!(slot) : null,
        child: _buildSlotCard(context, slot),
      )).toList(),
    );
  }

  Widget _buildSlotCard(BuildContext context, SlotData slot) {
    final bgColor = switch (slot.status) {
      DoseStatus.confirmed => slot.color.withValues(alpha: 0.2),
      DoseStatus.missed => Colors.red.shade50,
      _ => Colors.grey.shade50,
    };

    final borderColor = switch (slot.status) {
      DoseStatus.confirmed => slot.color,
      DoseStatus.missed => RainbowColors.missed,
      DoseStatus.pending => slot.color.withValues(alpha: 0.3),
      _ => Colors.grey.shade200,
    };

    final icon = switch (slot.status) {
      DoseStatus.confirmed => Icons.check_circle,
      DoseStatus.missed => Icons.warning_amber_rounded,
      _ => Icons.access_time,
    };

    final statusText = switch (slot.status) {
      DoseStatus.confirmed => '已完成',
      DoseStatus.missed => '漏服',
      DoseStatus.pending => slot.isActive ? '現在可以吃了！' : '等待中',
      DoseStatus.skipped => '已跳過',
    };

    final statusColor = switch (slot.status) {
      DoseStatus.confirmed => Colors.green.shade700,
      DoseStatus.missed => RainbowColors.missed,
      DoseStatus.pending => slot.isActive ? slot.color : Colors.grey,
      DoseStatus.skipped => Colors.grey,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Color indicator
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: slot.status == DoseStatus.confirmed
                    ? slot.color
                    : slot.color.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 16),
            // Time and medication info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        slot.timeLabel,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: slot.status == DoseStatus.confirmed
                              ? Colors.black87
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: slot.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          slot.colorLabel,
                          style: TextStyle(
                            fontSize: 14,
                            color: slot.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slot.medicationName,
                    style: const TextStyle(fontSize: 18),
                  ),
                  if (slot.dosage.isNotEmpty)
                    Text(
                      slot.dosage,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            // Status badge
            Column(
              children: [
                Icon(icon, color: statusColor, size: 28),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 13,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SlotData {
  final int medicationId;
  final String medicationName;
  final String dosage;
  final int colorIndex;
  final Color color;
  final String colorLabel;
  final String timeLabel;
  final DoseStatus status;
  final bool isActive;

  SlotData({
    required this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.colorIndex,
    required this.color,
    required this.colorLabel,
    required this.timeLabel,
    required this.status,
    this.isActive = false,
  });

  static List<SlotData> fromDoseData(
    List<DoseDatum> data,
    int currentHour,
    int currentMinute,
  ) {
    return data.map((d) {
      final color = RainbowColors.colors[d.colorIndex % RainbowColors.colors.length];
      final label = RainbowColors.fullLabels[d.colorIndex % RainbowColors.colors.length];
      final timeLabel =
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      final isActive = d.status == DoseStatus.pending &&
          (d.hour < currentHour ||
              (d.hour == currentHour && d.minute <= currentMinute + 30));

      return SlotData(
        medicationId: d.medicationId,
        medicationName: d.medicationName,
        dosage: d.dosage,
        colorIndex: d.colorIndex,
        color: color,
        colorLabel: label,
        timeLabel: timeLabel,
        status: d.status,
        isActive: isActive,
      );
    }).toList();
  }
}

class DoseDatum {
  final int medicationId;
  final String medicationName;
  final String dosage;
  final int colorIndex;
  final int hour;
  final int minute;
  final DoseStatus status;

  DoseDatum({
    required this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.colorIndex,
    required this.hour,
    required this.minute,
    required this.status,
  });
}
