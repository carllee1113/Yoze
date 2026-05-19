import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/medication.dart';
import '../models/dose_record.dart';
import '../theme/rainbow_colors.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服藥歷史'),
      ),
      body: _HistoryBody(),
    );
  }
}

class _HistoryBody extends ConsumerStatefulWidget {
  @override
  ConsumerState<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends ConsumerState<_HistoryBody> {
  DateTime _selectedDate = DateTime.now();
  late String _dateStr;

  @override
  void initState() {
    super.initState();
    _dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Date navigator
        _buildDateNavigator(),
        // History content
        Expanded(child: _buildHistory()),
      ],
    );
  }

  Widget _buildDateNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 32),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                _dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
              });
            },
          ),
          GestureDetector(
            onTap: _pickDate,
            child: Text(
              DateFormat('M月d日 EEEE', 'zh_TW').format(_selectedDate),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 32),
            onPressed: _selectedDate.isBefore(DateTime.now())
                ? () {
                    setState(() {
                      _selectedDate =
                          _selectedDate.add(const Duration(days: 1));
                      _dateStr =
                          DateFormat('yyyy-MM-dd').format(_selectedDate);
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      helpText: '選擇日期',
      cancelText: '取消',
      confirmText: '確認',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateStr = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Widget _buildHistory() {
    return FutureBuilder<List<Medication>>(
      future: DatabaseHelper.getAllMedications(),
      builder: (context, medSnapshot) {
        if (!medSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final medications = medSnapshot.data!;
        if (medications.isEmpty) {
          return const Center(
            child: Text('還沒有藥物記錄', style: TextStyle(fontSize: 18)),
          );
        }

        return FutureBuilder<List<DoseRecord>>(
          future: DatabaseHelper.getDoseRecordsForDate(_dateStr),
          builder: (context, doseSnapshot) {
            if (!doseSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final records = doseSnapshot.data!;
            if (records.isEmpty && medications.isEmpty) {
              return const Center(
                child: Text('當天沒有記錄', style: TextStyle(fontSize: 18)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: medications.length,
              itemBuilder: (context, i) {
                final med = medications[i];
                final record = records.where(
                  (r) => r.medicationId == med.id,
                );

                final status = record.isNotEmpty
                    ? record.first.status
                    : DoseStatus.pending;
                final confirmedAt = record.isNotEmpty
                    ? record.first.confirmedAt
                    : null;

                return _buildHistoryCard(med, status, confirmedAt);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryCard(
      Medication med, DoseStatus status, DateTime? confirmedAt) {
    final color =
        RainbowColors.colors[med.colorIndex % RainbowColors.colors.length];
    final timeLabel =
        '${med.hour.toString().padLeft(2, '0')}:${med.minute.toString().padLeft(2, '0')}';

    IconData icon;
    String statusText;
    Color statusColor;

    switch (status) {
      case DoseStatus.confirmed:
        icon = Icons.check_circle;
        statusText = '已吃';
        statusColor = Colors.green;
      case DoseStatus.missed:
        icon = Icons.warning;
        statusText = '漏服';
        statusColor = Colors.red;
      case DoseStatus.skipped:
        icon = Icons.skip_next;
        statusText = '跳過';
        statusColor = Colors.orange;
      case DoseStatus.pending:
        icon = Icons.schedule;
        statusText = '待處理';
        statusColor = Colors.grey;
    }

    final isToday = _dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Card(
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          '$timeLabel  ${med.name}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: med.dosage.isNotEmpty
            ? Text(med.dosage, style: const TextStyle(fontSize: 16))
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: statusColor, size: 28),
            const SizedBox(height: 2),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 13,
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isToday && status == DoseStatus.pending && _isPastTime(med))
              Text(
                '⚠️',
                style: TextStyle(fontSize: 16, color: Colors.red.shade400),
              ),
          ],
        ),
      ),
    );
  }

  bool _isPastTime(Medication med) {
    final now = DateTime.now();
    return med.hour < now.hour || (med.hour == now.hour && med.minute < now.minute);
  }
}
