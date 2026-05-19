import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/medication.dart';
import '../models/dose_record.dart';
import '../theme/rainbow_colors.dart';
import '../widgets/rainbow_progress.dart';
import '../services/notification_service.dart';

final medicationListProvider = FutureProvider<List<Medication>>((ref) async {
  return DatabaseHelper.getAllMedications();
});

final todayStatusProvider =
    FutureProvider.family<Map<int, DoseStatus>, String>(
        (ref, date) async {
  final map = await DatabaseHelper.getTodayDoseStatusMap(date);
  return map.map((k, v) => MapEntry(k, DoseStatus.values[v['status'] as int? ?? 0]));
});

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

          final now = DateTime.now();
          final statusMap = statusAsync.valueOrNull ?? {};

          final doseData = medications
              .where((m) => m.isEnabled)
              .map((m) {
                final status = statusMap[m.id!] ?? DoseStatus.pending;
                return DoseDatum(
                  medicationId: m.id!,
                  medicationName: m.name,
                  dosage: m.dosage,
                  colorIndex: m.colorIndex,
                  hour: m.hour,
                  minute: m.minute,
                  status: status,
                );
              })
              .toList();

          final slots = SlotData.fromDoseData(
            doseData,
            now.hour,
            now.minute,
          );

          final confirmed = slots.where((s) => s.status == DoseStatus.confirmed).length;
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
                _buildProgressHeader(medications, confirmed, total, progress),
                const SizedBox(height: 16),
                RainbowProgress(
                  slots: slots,
                  onTap: (slot) => _confirmDose(slot),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Camera button (smaller, above)
          SizedBox(
            width: 52,
            height: 52,
            child: FloatingActionButton(
              heroTag: 'camera_fab',
              backgroundColor: Colors.blue.shade600,
              onPressed: () {
                Navigator.of(context).pushNamed('/capture');
              },
              child: const Icon(Icons.camera_alt, size: 26, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          // Add medication button (main)
          SizedBox(
            width: 64,
            height: 64,
            child: FloatingActionButton(
              key: const Key('add_medication_fab'),
              heroTag: 'add_fab',
              onPressed: () async {
                await Navigator.of(context).pushNamed('/add');
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

  Future<void> _confirmDose(SlotData slot) async {
    if (slot.status == DoseStatus.confirmed) return;

    await DatabaseHelper.confirmDose(
      slot.medicationId,
      _today,
      0,
    );

    NotificationService.speak('${slot.medicationName} 已吃');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${slot.medicationName} 已記錄'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.invalidate(todayStatusProvider(_today));
    }
  }

  Widget _buildProgressHeader(
    List<Medication> medications,
    int confirmed,
    int total,
    double progress,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '👴 今天服藥進度',
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
              progress == 1.0
                  ? '🎉 今日全部完成！'
                  : '$confirmed / $total 次已完成',
              style: TextStyle(
                fontSize: 18,
                color: progress == 1.0
                    ? Colors.green.shade700
                    : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
