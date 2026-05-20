import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/dose_record.dart';
import '../models/medication.dart';
import '../services/notification_service.dart';
import '../theme/rainbow_colors.dart';
import '../widgets/rainbow_progress.dart';

final medicationListProvider = FutureProvider<List<Medication>>((ref) async {
  return DatabaseHelper.getAllMedications();
});

final todayStatusProvider = FutureProvider.family<Map<int, DoseStatus>, String>(
  (ref, date) async {
    final map = await DatabaseHelper.getTodayDoseStatusMap(date);
    return map.map((k, v) => MapEntry(k, DoseStatus.values[v['status'] as int? ?? 0]));
  },
);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final String _today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final medicationsAsync = ref.watch(medicationListProvider);
    final statusAsync = ref.watch(todayStatusProvider(_today));

    return Scaffold(
      appBar: AppBar(
        title: const Text('YOZE 藥師'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, size: 28),
            onPressed: () {
              Navigator.of(context).pushNamed('/history');
            },
          ),
        ],
      ),
      body: medicationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('載入失敗: $e')),
        data: (medications) {
          if (medications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.medication_liquid, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '還沒有添加藥物',
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '點下方 + 開始設定',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final statusMap = statusAsync.valueOrNull ?? {};
          final slots = _buildGroupedSlots(medications, statusMap);

          final confirmed = slots.where((s) => s.isComplete).length;
          final total = slots.length;
          final progress = total > 0 ? confirmed / total : 0.0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(medicationListProvider);
              ref.invalidate(todayStatusProvider(_today));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProgressHeader(confirmed, total, progress),
                const SizedBox(height: 16),
                RainbowProgress(
                  slots: slots,
                  onToggleAll: _toggleAllInSlot,
                  onToggleItem: _toggleSingleMedication,
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: FloatingActionButton(
              heroTag: 'camera_fab',
              backgroundColor: Colors.blue.shade600,
              onPressed: () async {
                await Navigator.of(context).pushNamed(
                  '/setup',
                  arguments: {'startWithCamera': true},
                );
                ref.invalidate(medicationListProvider);
                ref.invalidate(todayStatusProvider(_today));
              },
              child: const Icon(Icons.camera_alt, size: 26, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 64,
            height: 64,
            child: FloatingActionButton(
              key: const Key('add_medication_fab'),
              heroTag: 'add_fab',
              onPressed: () async {
                await Navigator.of(context).pushNamed('/setup');
                ref.invalidate(medicationListProvider);
                ref.invalidate(todayStatusProvider(_today));
              },
              child: const Icon(Icons.add, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  List<IntakeSlotData> _buildGroupedSlots(
    List<Medication> medications,
    Map<int, DoseStatus> statusMap,
  ) {
    final grouped = <String, List<SlotMedicationItem>>{};

    for (final med in medications.where((m) => m.isEnabled)) {
      final status = statusMap[med.id!] ?? DoseStatus.pending;
      final key = '${med.hour.toString().padLeft(2, '0')}:${med.minute.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => <SlotMedicationItem>[]);
      grouped[key]!.add(
        SlotMedicationItem(
          medicationId: med.id!,
          medicationName: med.name,
          dosage: med.dosePerTime.isNotEmpty ? med.dosePerTime : med.dosage,
          colorIndex: med.colorIndex,
          color: RainbowColors.colors[med.colorIndex % RainbowColors.colors.length],
          colorLabel: RainbowColors.labels[med.colorIndex % RainbowColors.labels.length],
          status: status,
        ),
      );
    }

    final slots = <IntakeSlotData>[];
    for (final entry in grouped.entries) {
      final parts = entry.key.split(':');
      slots.add(
        IntakeSlotData(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
          items: entry.value,
        ),
      );
    }

    slots.sort((a, b) {
      final aValue = a.hour * 60 + a.minute;
      final bValue = b.hour * 60 + b.minute;
      return aValue.compareTo(bValue);
    });

    return slots;
  }

  Future<void> _toggleAllInSlot(IntakeSlotData slot, bool complete) async {
    final targetStatus = complete ? DoseStatus.confirmed : DoseStatus.pending;
    for (final item in slot.items) {
      await DatabaseHelper.setDoseStatus(
        medicationId: item.medicationId,
        date: _today,
        doseIndex: 0,
        status: targetStatus,
      );
    }

    if (complete && slot.items.isNotEmpty) {
      NotificationService.speak('${slot.timeLabel} 的藥已全部完成');
    }

    ref.invalidate(todayStatusProvider(_today));
  }

  Future<void> _toggleSingleMedication(
    IntakeSlotData slot,
    SlotMedicationItem item,
    bool complete,
  ) async {
    await DatabaseHelper.setDoseStatus(
      medicationId: item.medicationId,
      date: _today,
      doseIndex: 0,
      status: complete ? DoseStatus.confirmed : DoseStatus.pending,
    );

    if (complete) {
      NotificationService.speak('${item.medicationName} 已吃');
    }

    ref.invalidate(todayStatusProvider(_today));
  }

  Widget _buildProgressHeader(int confirmed, int total, double progress) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '🐱 今天服藥進度',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 20,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  progress == 1.0 ? Colors.green : RainbowColors.colors[0],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progress == 1.0 ? '🎉 今日全部完成！' : '$confirmed / $total 次已完成',
              style: TextStyle(
                fontSize: 18,
                color: progress == 1.0 ? Colors.green.shade700 : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
