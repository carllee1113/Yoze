import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/dose_record.dart';
import '../models/medication.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _focusedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('yyyy年 M月', 'zh_TW').format(_focusedMonth);

    return Scaffold(
      appBar: AppBar(title: const Text('服藥歷史（月曆）')),
      body: Column(
        children: [
          _buildMonthHeader(monthLabel),
          Expanded(
            child: FutureBuilder<Map<DateTime, DayProgress>>(
              future: _loadMonthProgress(_focusedMonth),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildCalendar(snapshot.data!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(String monthLabel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month - 1,
                  1,
                );
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                monthLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month + 1,
                  1,
                );
              });
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(Map<DateTime, DayProgress> progressMap) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstWeekday = DateTime(year, month, 1).weekday % 7;

    final cells = <Widget>[];

    const weekdays = ['日', '一', '二', '三', '四', '五', '六'];
    for (final w in weekdays) {
      cells.add(
        Center(
          child: Text(
            w,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      );
    }

    for (int i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final progress = progressMap[normalizedDate];
      final isToday = normalizedDate == today;

      cells.add(
        Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(
              color: isToday ? Colors.blue : Colors.grey.shade300,
              width: isToday ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$day',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildDayMarker(progress),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: GridView.count(
        crossAxisCount: 7,
        childAspectRatio: 0.82,
        children: cells,
      ),
    );
  }

  Widget _buildDayMarker(DayProgress? progress) {
    if (progress == null || progress.totalSlots == 0) {
      return const SizedBox(height: 16);
    }

    if (progress.ratio == 1.0) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 18);
    }

    if (progress.ratio >= 0.8) {
      return const Icon(Icons.check_circle, color: Colors.blue, size: 18);
    }

    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }

  Future<Map<DateTime, DayProgress>> _loadMonthProgress(
    DateTime monthStart,
  ) async {
    final enabledMeds = await DatabaseHelper.getActiveMedications();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final daysInMonth = DateUtils.getDaysInMonth(
      monthStart.year,
      monthStart.month,
    );
    final result = <DateTime, DayProgress>{};

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(monthStart.year, monthStart.month, day);
      final normalizedDate = DateTime(date.year, date.month, date.day);

      // Future days stay blank on calendar.
      if (normalizedDate.isAfter(today)) {
        continue;
      }

      final nextDate = date.add(const Duration(days: 1));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final activeMeds = enabledMeds
          .where((m) => m.createdAt.isBefore(nextDate))
          .toList();
      final slotGroups = _groupMedicationsByTime(activeMeds);

      final totalSlots = slotGroups.length;
      if (totalSlots == 0) {
        result[normalizedDate] = const DayProgress(0, 0);
        continue;
      }

      final records = await DatabaseHelper.getDoseRecordsForDate(dateStr);
      final confirmedByMedId = <int, bool>{
        for (final r in records)
          r.medicationId: r.status == DoseStatus.confirmed,
      };

      int completedSlots = 0;
      for (final medIds in slotGroups.values) {
        final allDone = medIds.every((id) => confirmedByMedId[id] == true);
        if (allDone) completedSlots++;
      }

      result[normalizedDate] = DayProgress(completedSlots, totalSlots);
    }

    return result;
  }

  Map<String, List<int>> _groupMedicationsByTime(List<Medication> meds) {
    final map = <String, List<int>>{};
    for (final med in meds) {
      final key =
          '${med.hour.toString().padLeft(2, '0')}:${med.minute.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => <int>[]);
      map[key]!.add(med.id!);
    }
    return map;
  }
}

class DayProgress {
  final int completedSlots;
  final int totalSlots;

  const DayProgress(this.completedSlots, this.totalSlots);

  double get ratio => totalSlots == 0 ? 0 : completedSlots / totalSlots;
}
