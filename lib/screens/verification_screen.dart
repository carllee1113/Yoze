import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/extracted_medication.dart';
import '../models/medication.dart';
import '../providers/photo_scan_provider.dart';
import '../services/notification_service.dart';
import '../services/schedule_planner.dart';
import '../theme/rainbow_colors.dart';
import 'photo_capture_screen.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  final String? imagePath;
  final bool startWithCamera;

  const VerificationScreen({
    super.key,
    this.imagePath,
    this.startWithCamera = false,
  });

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  bool _isSaving = false;
  bool _isLoadingSaved = true;
  TimeOfDay _dayStartTime = const TimeOfDay(hour: 8, minute: 0);
  bool _didInit = false;
  List<Medication> _activeMedications = [];
  List<Medication> _archivedMedications = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final notifier = ref.read(photoScanProvider.notifier);
      if (!_didInit) {
        _didInit = true;
        if ((widget.imagePath ?? '').isEmpty) {
          notifier.reset();
        }
        await _loadSavedMedications();
      }
      if (widget.startWithCamera) {
        await _addFromPhoto();
      }
    });
  }

  Future<void> _loadSavedMedications() async {
    final active = await DatabaseHelper.getActiveMedications(
      orderBy: 'createdAt DESC, hour ASC, minute ASC',
    );
    final archived = await DatabaseHelper.getArchivedMedications();
    if (!mounted) return;
    setState(() {
      _activeMedications = active;
      _archivedMedications = archived;
      _isLoadingSaved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(photoScanProvider);
    final draftMedications = scanState.extractedMedications;
    final activeMedicationGroups = _groupSavedMedications(_activeMedications);
    final archivedMedicationGroups = _groupSavedMedications(
      _archivedMedications,
    );
    final slotCount = _slotCountFor(draftMedications);
    final slots = SchedulePlanner.generateDailySlots(
      startHour: _dayStartTime.hour,
      startMinute: _dayStartTime.minute,
      slotCount: slotCount,
    );
    final plan = SchedulePlanner.buildPlan(
      medications: draftMedications,
      startHour: _dayStartTime.hour,
      startMinute: _dayStartTime.minute,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('藥物設定'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: Column(
        children: [
          _buildTopControls(draftMedications, slots),
          if ((scanState.diagnosticMessage ?? '').isNotEmpty)
            _buildOcrDiagnostic(scanState.diagnosticMessage!),
          const Divider(height: 1),
          Expanded(
            child: _isLoadingSaved
                ? const Center(child: CircularProgressIndicator())
                : draftMedications.isEmpty &&
                      activeMedicationGroups.isEmpty &&
                      archivedMedicationGroups.isEmpty
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (
                        int index = 0;
                        index < draftMedications.length;
                        index++
                      )
                        _MedicationCard(
                          medication: draftMedications[index],
                          index: index,
                          onUpdate: (updated) {
                            ref
                                .read(photoScanProvider.notifier)
                                .updateMedication(index, updated);
                          },
                          onDelete: () {
                            ref
                                .read(photoScanProvider.notifier)
                                .removeMedication(index);
                          },
                        ),
                      if (activeMedicationGroups.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildSectionTitle('目前服用中'),
                        const SizedBox(height: 8),
                        for (final group in activeMedicationGroups)
                          _SavedMedicationCard(
                            group: group,
                            onEdit: () => _editMedicationGroup(group),
                            onViewPhoto: () => _showMedicationPhoto(group),
                            onArchive: () => _archiveMedication(group),
                            onDelete: () => _confirmDeleteMedication(group),
                          ),
                      ],
                      _buildArchivedSection(archivedMedicationGroups),
                    ],
                  ),
          ),
          if (draftMedications.isNotEmpty) _buildPlanPreview(plan),
          _buildActionBar(draftMedications, activeMedicationGroups),
        ],
      ),
    );
  }

  Widget _buildTopControls(
    List<ExtractedMedication> medications,
    List<ScheduleSlot> slots,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addEmptyMedication,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('手動新增'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addFromPhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('拍照新增'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _pickDayStartTime,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '每日開始時間: ${_formatTime(_dayStartTime.hour, _dayStartTime.minute)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (medications.isNotEmpty)
                    Text(
                      '${slots.length} 個時段',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (slots.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '建議時段: ${slots.map((s) => _formatTime(s.hour, s.minute)).join('、')}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOcrDiagnostic(String message) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade50,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: const Icon(Icons.bug_report_outlined),
        title: const Text(
          'OCR 診斷',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          '拍照後如未能識別，請展開查看原因',
          style: TextStyle(fontSize: 12),
        ),
        children: [
          SelectableText(
            message,
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanPreview(SchedulePlan plan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      color: Colors.blueGrey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '服藥分配預覽',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final slot in plan.slots)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${_formatTime(slot.hour, slot.minute)}: '
                '${slot.medications.isEmpty ? '（無）' : slot.medications.map((m) => m.drugName).join('、')}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar(
    List<ExtractedMedication> medications,
    List<_MedicationGroup> activeGroups,
  ) {
    if (medications.isEmpty && activeGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    medications.isEmpty
                        ? '更新每日服藥時間'
                        : '儲存並重新整理時間 (${medications.length} 種)',
                    style: const TextStyle(fontSize: 18),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '先新增藥物再排程',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            '可混合手動輸入與拍照識別',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
  }

  List<_MedicationGroup> _groupSavedMedications(List<Medication> medications) {
    final grouped = <String, List<Medication>>{};
    for (final medication in medications) {
      grouped.putIfAbsent(_savedMedicationGroupKey(medication), () => []);
      grouped[_savedMedicationGroupKey(medication)]!.add(medication);
    }

    final groups = grouped.values.map(_MedicationGroup.new).toList();
    groups.sort((a, b) => b.primary.createdAt.compareTo(a.primary.createdAt));
    return groups;
  }

  String _savedMedicationGroupKey(Medication medication) {
    if (medication.medicineCode > 0) {
      return 'code:${medication.medicineCode}|${medication.isArchived ? 'archived' : 'active'}';
    }
    return [
      medication.name.trim().toLowerCase(),
      medication.form.trim().toLowerCase(),
      medication.dosagePerUnit.trim().toLowerCase(),
      medication.administration.trim().toLowerCase(),
      medication.dosePerTime.trim().toLowerCase(),
      (medication.permitNo ?? '').trim().toLowerCase(),
      medication.isArchived ? 'archived' : 'active',
    ].join('|');
  }

  Widget _buildArchivedSection(List<_MedicationGroup> archivedGroups) {
    if (archivedGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          '已封存 (${archivedGroups.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        children: [
          for (final group in archivedGroups)
            _SavedMedicationCard(
              group: group,
              isArchivedView: true,
              onEdit: () => _editMedicationGroup(group),
              onViewPhoto: () => _showMedicationPhoto(group),
              onArchive: null,
              onDelete: () => _confirmDeleteMedication(group),
            ),
        ],
      ),
    );
  }

  int _slotCountFor(List<ExtractedMedication> medications) {
    if (medications.isEmpty) return 0;
    final maxFreq = medications
        .map((m) => m.frequency.clamp(1, 8))
        .reduce((a, b) => a > b ? a : b);
    return maxFreq;
  }

  String _formatTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDayStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dayStartTime,
      helpText: '選擇每日起始時間',
      cancelText: '取消',
      confirmText: '確認',
    );
    if (picked != null) {
      setState(() {
        _dayStartTime = picked;
      });
    }
  }

  Future<void> _addFromPhoto() async {
    final result = await Navigator.of(context).push<List<ExtractedMedication>>(
      MaterialPageRoute(
        builder: (_) =>
            const PhotoCaptureScreen(returnExtractedMedications: true),
      ),
    );

    if (!mounted || result == null || result.isEmpty) return;

    final needsManualInput = result.any((med) => med.confidence <= 0.1);
    final currentMedications = ref.read(photoScanProvider).extractedMedications;
    final nextMedications = <ExtractedMedication>[
      ...result.map(
        (med) => med.copyWith(
          form: med.form.isEmpty ? '藥丸' : med.form,
          administration: med.administration.isEmpty
              ? '飯後'
              : med.administration,
          dosePerTime: med.dosePerTime.isEmpty ? '1' : med.dosePerTime,
          frequency: med.frequency <= 0 ? 1 : med.frequency,
        ),
      ),
      ...currentMedications,
    ];

    ref.read(photoScanProvider.notifier).setMedications(nextMedications);

    if (mounted && needsManualInput) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未能自動識別，已建立空白藥物卡，請手動填寫。')));
    }
  }

  void _addEmptyMedication() {
    ref
        .read(photoScanProvider.notifier)
        .addMedication(
          ExtractedMedication(
            drugName: '',
            form: '藥丸',
            administration: '飯後',
            dosePerTime: '1',
            frequency: 1,
            colorIndex: ref.read(photoScanProvider).extractedMedications.length,
          ),
        );
  }

  Future<void> _showMedicationPhoto(_MedicationGroup group) async {
    final path = group.primary.sourcePhotoPath;
    if (path == null || path.isEmpty || !File(path).existsSync()) return;

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                group.primary.name.isEmpty ? '藥物相片' : group.primary.name,
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMedicationGroup(_MedicationGroup group) async {
    final edited = await showDialog<_MedicationEditResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MedicationEditDialog(
        group: group,
        imagePicker: _imagePicker,
        saveImage: (file) =>
            ref.read(photoScanProvider.notifier).saveImage(file),
      ),
    );

    if (edited == null) return;

    final extracted = ExtractedMedication(
      drugName: edited.name,
      form: edited.form,
      dosagePerUnit: edited.dosagePerUnit,
      administration: edited.administration,
      frequency: edited.frequency,
      dosePerTime: edited.dosePerTime,
      durationDays: edited.durationDays,
      totalQuantity: edited.totalQuantity,
      permitNo: edited.permitNo,
      colorIndex: edited.colorIndex,
      sourcePhotoPath: edited.photoPath,
      medicineCode: group.primary.medicineCode,
    );

    if (group.primary.isArchived) {
      for (final medication in group.medications) {
        if (medication.id == null) continue;
        await DatabaseHelper.updateMedication(
          _medicationFromEditResult(
            existing: medication,
            edited: edited,
            hour: medication.hour,
            minute: medication.minute,
          ),
        );
      }
    } else {
      final source = _ScheduleMedicationSource(
        medication: extracted,
        existingGroup: group,
      );
      final slots = SchedulePlanner.generateDailySlots(
        startHour: _dayStartTime.hour,
        startMinute: _dayStartTime.minute,
        slotCount: edited.frequency,
      );
      await _saveScheduleSource(source, slots);
    }

    await _loadSavedMedications();
  }

  Medication _medicationFromEditResult({
    required Medication existing,
    required _MedicationEditResult edited,
    required int hour,
    required int minute,
  }) {
    return Medication(
      id: existing.id,
      name: edited.name,
      form: edited.form,
      dosagePerUnit: edited.dosagePerUnit,
      administration: edited.administration,
      dosePerTime: edited.dosePerTime,
      durationDays: edited.durationDays,
      totalQuantity: edited.totalQuantity,
      permitNo: edited.permitNo,
      dosage: edited.dosePerTime,
      colorIndex: edited.colorIndex,
      medicineCode: existing.medicineCode,
      hour: hour,
      minute: minute,
      isEnabled: existing.isEnabled,
      isArchived: existing.isArchived,
      createdAt: existing.createdAt,
      archivedAt: existing.archivedAt,
      sourcePhotoPath: edited.photoPath,
    );
  }

  Future<void> _archiveMedication(_MedicationGroup group) async {
    for (final medication in group.medications) {
      if (medication.id == null) continue;
      await DatabaseHelper.archiveMedication(medication.id!);
      await NotificationService.cancelReminder(medication.id!);
    }
    await _loadSavedMedications();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${group.primary.name} 已封存，將不再出現在首頁提醒。')),
    );
  }

  Future<void> _confirmDeleteMedication(_MedicationGroup group) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除藥物？'),
        content: const Text(
          '刪除會把此藥物從資料庫移除，並從首頁提醒列表移除，記錄不會再出現。\n\n'
          '如果你想保存曾經服用過的記錄，請使用「封存」。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('取消'),
          ),
          if (!group.primary.isArchived)
            TextButton(
              onPressed: () => Navigator.of(context).pop('archive'),
              child: const Text('改用封存'),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop('delete'),
            child: const Text('永久刪除'),
          ),
        ],
      ),
    );

    if (action == 'archive') {
      await _archiveMedication(group);
      return;
    }

    if (action != 'delete') return;
    for (final medication in group.medications) {
      if (medication.id == null) continue;
      await NotificationService.cancelReminder(medication.id!);
      await DatabaseHelper.deleteMedication(medication.id!);
    }
    await _loadSavedMedications();
  }

  Future<void> _saveAll() async {
    final draftMedications = ref.read(photoScanProvider).extractedMedications;

    setState(() {
      _isSaving = true;
    });

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayStatus = await DatabaseHelper.getTodayDoseStatusMap(today);
      final completedTodayIds = todayStatus.entries
          .where((entry) => (entry.value['status'] as int? ?? 0) == 1)
          .map((entry) => entry.key)
          .toSet();

      final sources =
          <_ScheduleMedicationSource>[
                for (final group in _groupSavedMedications(_activeMedications))
                  _ScheduleMedicationSource(
                    medication: _extractedFromSavedGroup(group),
                    existingGroup: group,
                  ),
                for (final draft in draftMedications)
                  _ScheduleMedicationSource(medication: draft),
              ]
              .where((source) => source.medication.drugName.trim().isNotEmpty)
              .toList();
      if (sources.isEmpty) return;

      final plan = SchedulePlanner.buildPlan(
        medications: sources.map((source) => source.medication).toList(),
        startHour: _dayStartTime.hour,
        startMinute: _dayStartTime.minute,
      );

      final sourceByMedication = {
        for (final source in sources) source.medication: source,
      };
      final slotsBySource = {
        for (final source in sources) source: <ScheduleSlot>[],
      };

      for (final slot in plan.slots) {
        for (final extracted in slot.medications) {
          final source = sourceByMedication[extracted];
          if (source == null) continue;
          slotsBySource[source]!.add(slot);
        }
      }

      for (final source in sources) {
        await _saveScheduleSource(
          source,
          slotsBySource[source] ?? const [],
          completedTodayIds: completedTodayIds,
        );
      }

      if (mounted) {
        ref.read(photoScanProvider.notifier).reset();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失敗: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  ExtractedMedication _extractedFromSavedGroup(_MedicationGroup group) {
    final medication = group.primary;
    return ExtractedMedication(
      drugName: medication.name,
      form: medication.form,
      dosagePerUnit: medication.dosagePerUnit,
      administration: medication.administration,
      frequency: group.dailyTimes,
      dosePerTime: medication.dosePerTime,
      durationDays: medication.durationDays,
      totalQuantity: medication.totalQuantity,
      permitNo: medication.permitNo,
      colorIndex: medication.colorIndex,
      sourcePhotoPath: medication.sourcePhotoPath,
      medicineCode: medication.medicineCode,
    );
  }

  Future<void> _saveScheduleSource(
    _ScheduleMedicationSource source,
    List<ScheduleSlot> slots, {
    Set<int> completedTodayIds = const {},
  }) async {
    if (slots.isEmpty) return;

    final extracted = source.medication;
    final existingRows =
        source.existingGroup?.medications ?? const <Medication>[];
    final completedRows = existingRows
        .where((row) => row.id != null && completedTodayIds.contains(row.id))
        .toList();
    final reschedulableRows = existingRows
        .where((row) => row.id == null || !completedTodayIds.contains(row.id))
        .toList();
    final completedTimeKeys = completedRows
        .map(
          (row) =>
              '${row.hour.toString().padLeft(2, '0')}:${row.minute.toString().padLeft(2, '0')}',
        )
        .toSet();
    final reschedulableSlotCount = (slots.length - completedRows.length)
        .clamp(0, slots.length)
        .toInt();
    final reschedulableSlots = slots
        .where(
          (slot) =>
              !completedTimeKeys.contains(_formatTime(slot.hour, slot.minute)),
        )
        .take(reschedulableSlotCount)
        .toList();
    final medicineCode =
        source.existingGroup?.primary.medicineCode ??
        extracted.medicineCode ??
        await DatabaseHelper.getNextMedicineCode();
    final savedPhotoPath = source.existingGroup == null
        ? await _persistPhotoPath(extracted.sourcePhotoPath)
        : extracted.sourcePhotoPath;

    for (final completed in completedRows) {
      await NotificationService.cancelReminder(completed.id!);
    }

    for (int i = 0; i < reschedulableSlots.length; i++) {
      final slot = reschedulableSlots[i];
      final existing = i < reschedulableRows.length
          ? reschedulableRows[i]
          : null;
      final med = Medication(
        id: existing?.id,
        name: extracted.drugName.trim(),
        form: extracted.form,
        dosagePerUnit: extracted.dosagePerUnit,
        administration: extracted.administration,
        dosePerTime: extracted.dosePerTime,
        durationDays: extracted.durationDays,
        totalQuantity: extracted.totalQuantity,
        permitNo: extracted.permitNo,
        dosage: extracted.dosePerTime,
        medicineCode: medicineCode,
        colorIndex: extracted.colorIndex ?? existing?.colorIndex ?? 0,
        hour: slot.hour,
        minute: slot.minute,
        isEnabled: true,
        isArchived: false,
        createdAt: existing?.createdAt,
        sourcePhotoPath: savedPhotoPath,
      );

      final id = existing?.id == null
          ? await DatabaseHelper.insertMedication(med)
          : await _updateExistingMedication(med);
      if (id <= 0) continue;

      await NotificationService.cancelReminder(id);
      await NotificationService.scheduleMedicationReminder(
        medicationId: id,
        medicationName: med.name,
        colorIndex: med.colorIndex,
        hour: med.hour,
        minute: med.minute,
      );
    }

    for (int i = reschedulableSlots.length; i < reschedulableRows.length; i++) {
      final id = reschedulableRows[i].id;
      if (id == null) continue;
      await NotificationService.cancelReminder(id);
      await DatabaseHelper.deleteMedication(id);
    }
  }

  Future<int> _updateExistingMedication(Medication medication) async {
    await DatabaseHelper.updateMedication(medication);
    return medication.id ?? 0;
  }

  void _goBack() {
    ref.read(photoScanProvider.notifier).reset();
    Navigator.of(context).pop();
  }

  Future<String?> _persistPhotoPath(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return ref.read(photoScanProvider.notifier).saveImage(file);
  }
}

class _MedicationGroup {
  final List<Medication> medications;

  _MedicationGroup(List<Medication> source)
    : medications = List<Medication>.from(source)
        ..sort((a, b) {
          final aValue = a.hour * 60 + a.minute;
          final bValue = b.hour * 60 + b.minute;
          return aValue.compareTo(bValue);
        });

  Medication get primary => medications.first;

  String get codeLabel {
    final code = primary.medicineCode;
    return code > 0 ? code.toString().padLeft(2, '0') : '--';
  }

  List<String> get timeLabels =>
      medications.map((medication) => medication.timeLabel).toSet().toList();

  int get dailyTimes => timeLabels.length;

  DateTime get joinedAt => medications
      .map((medication) => medication.createdAt)
      .reduce((a, b) => a.isBefore(b) ? a : b);

  DateTime? get archivedAt {
    final dates = medications
        .map((medication) => medication.archivedAt)
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

class _ScheduleMedicationSource {
  final ExtractedMedication medication;
  final _MedicationGroup? existingGroup;

  const _ScheduleMedicationSource({
    required this.medication,
    this.existingGroup,
  });
}

class _SavedMedicationCard extends StatelessWidget {
  final _MedicationGroup group;
  final VoidCallback onEdit;
  final VoidCallback onViewPhoto;
  final VoidCallback? onArchive;
  final VoidCallback onDelete;
  final bool isArchivedView;

  const _SavedMedicationCard({
    required this.group,
    required this.onEdit,
    required this.onViewPhoto,
    required this.onArchive,
    required this.onDelete,
    this.isArchivedView = false,
  });

  @override
  Widget build(BuildContext context) {
    final medication = group.primary;
    final color = RainbowColors
        .colors[medication.colorIndex % RainbowColors.colors.length];
    final path = medication.sourcePhotoPath;
    final hasPhoto = path != null && path.isNotEmpty && File(path).existsSync();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final archivedAt = group.archivedAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isArchivedView
              ? Colors.grey.shade300
              : color.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: hasPhoto ? onViewPhoto : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: hasPhoto
                            ? Image.file(
                                File(path),
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 72,
                                height: 72,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.medication_outlined),
                              ),
                      ),
                      if (hasPhoto)
                        Container(
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.zoom_out_map,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${group.codeLabel} ${medication.name.isEmpty ? '未命名藥物' : medication.name}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.timeLabels.join('、')} 服用',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '每日 ${group.dailyTimes} 次，每次 ${medication.dosePerTime.isEmpty ? '未填' : medication.dosePerTime} 份量',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '加入日期: ${dateFormat.format(group.joinedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '封存日期: ${archivedAt == null ? '空白' : dateFormat.format(archivedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: '形式', value: medication.form),
                _InfoChip(label: '劑量', value: medication.dosagePerUnit),
                _InfoChip(label: '服用形式', value: medication.administration),
                _InfoChip(label: '每次份量', value: medication.dosePerTime),
                _InfoChip(label: '每日次數', value: '${group.dailyTimes}'),
                _InfoChip(
                  label: '持續',
                  value: medication.durationDays == null
                      ? '每天都有'
                      : '${medication.durationDays}日',
                ),
                if ((medication.permitNo ?? '').isNotEmpty)
                  _InfoChip(label: '編號', value: medication.permitNo!),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('編輯'),
                ),
                if (onArchive != null)
                  TextButton.icon(
                    onPressed: onArchive,
                    icon: const Icon(Icons.archive_outlined, size: 18),
                    label: const Text('封存'),
                  ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 18,
                  ),
                  label: const Text('刪除', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final shownValue = value.trim().isEmpty ? '未填' : value.trim();
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text('$label: $shownValue'),
    );
  }
}

class _MedicationEditResult {
  final String name;
  final String form;
  final String dosagePerUnit;
  final String administration;
  final int frequency;
  final String dosePerTime;
  final int? durationDays;
  final int? totalQuantity;
  final String? permitNo;
  final int colorIndex;
  final String? photoPath;

  const _MedicationEditResult({
    required this.name,
    required this.form,
    required this.dosagePerUnit,
    required this.administration,
    required this.frequency,
    required this.dosePerTime,
    required this.durationDays,
    required this.totalQuantity,
    required this.permitNo,
    required this.colorIndex,
    required this.photoPath,
  });
}

class _MedicationEditDialog extends StatefulWidget {
  final _MedicationGroup group;
  final ImagePicker imagePicker;
  final Future<String?> Function(File file) saveImage;

  const _MedicationEditDialog({
    required this.group,
    required this.imagePicker,
    required this.saveImage,
  });

  @override
  State<_MedicationEditDialog> createState() => _MedicationEditDialogState();
}

class _MedicationEditDialogState extends State<_MedicationEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _durationController;
  late TextEditingController _permitController;
  late String _form;
  late String _administration;
  late String _dosePerTime;
  late int _frequency;
  late int _colorIndex;
  String? _photoPath;
  bool _isSavingPhoto = false;

  static const List<String> _formOptions = ['藥丸', '膠囊', '藥水', '膏藥'];
  static const List<String> _administrationOptions = ['飯前', '飯後', '空肚食', '飽肚食'];
  static const List<String> _dosePerTimeOptions = [
    '0.5',
    '1',
    '1.5',
    '2',
    '2.5',
    '3',
    '3.5',
    '4',
  ];

  @override
  void initState() {
    super.initState();
    final medication = widget.group.primary;
    _nameController = TextEditingController(text: medication.name);
    _dosageController = TextEditingController(text: medication.dosagePerUnit);
    _durationController = TextEditingController(
      text: medication.durationDays?.toString() ?? '',
    );
    _permitController = TextEditingController(text: medication.permitNo ?? '');
    _form = _normalizeForm(medication.form);
    _administration = _normalizeAdministration(medication.administration);
    _dosePerTime = _normalizeDosePerTime(medication.dosePerTime);
    _frequency = widget.group.dailyTimes.clamp(1, 8);
    _colorIndex = medication.colorIndex;
    _photoPath = medication.sourcePhotoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _durationController.dispose();
    _permitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        _photoPath != null &&
        _photoPath!.isNotEmpty &&
        File(_photoPath!).existsSync();

    return AlertDialog(
      title: const Text('編輯藥物'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPhotoEditor(hasPhoto),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '藥物名稱',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _form,
                decoration: const InputDecoration(
                  labelText: '形式',
                  border: OutlineInputBorder(),
                ),
                items: _formOptions
                    .map(
                      (option) =>
                          DropdownMenuItem(value: option, child: Text(option)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _form = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: '劑量',
                  hintText: '例如：500MG',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _administration,
                decoration: const InputDecoration(
                  labelText: '服用形式',
                  border: OutlineInputBorder(),
                ),
                items: _administrationOptions
                    .map(
                      (option) =>
                          DropdownMenuItem(value: option, child: Text(option)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _administration = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _frequency,
                      decoration: const InputDecoration(
                        labelText: '每日次數',
                        border: OutlineInputBorder(),
                      ),
                      items: [1, 2, 3, 4, 5, 6, 7, 8]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _frequency = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _dosePerTime,
                      decoration: const InputDecoration(
                        labelText: '每次份量',
                        border: OutlineInputBorder(),
                      ),
                      items: _dosePerTimeOptions
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _dosePerTime = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '每日 $_frequency 次，每次 $_dosePerTime 份量',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '持續天數',
                  hintText: '空白 = 每天都有',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _permitController,
                decoration: const InputDecoration(
                  labelText: '藥物編號',
                  hintText: 'HK-XXXXX',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _buildColorPicker(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('儲存')),
      ],
    );
  }

  Widget _buildPhotoEditor(bool hasPhoto) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: hasPhoto
                ? Image.file(
                    File(_photoPath!),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 72,
                    height: 72,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.photo_camera_outlined),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _isSavingPhoto
                      ? null
                      : () => _pickPhoto(ImageSource.camera),
                  child: const Text('拍照'),
                ),
                OutlinedButton(
                  onPressed: _isSavingPhoto
                      ? null
                      : () => _pickPhoto(ImageSource.gallery),
                  child: const Text('相簿'),
                ),
                if (hasPhoto)
                  TextButton(
                    onPressed: _isSavingPhoto
                        ? null
                        : () => setState(() => _photoPath = null),
                    child: const Text('移除相片'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('顏色標籤', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(RainbowColors.colors.length, (index) {
            final isSelected = _colorIndex == index;
            return GestureDetector(
              onTap: () => setState(() => _colorIndex = index),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: RainbowColors.colors[index],
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.black, width: 3)
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await widget.imagePicker.pickImage(source: source);
    if (picked == null) return;
    setState(() => _isSavingPhoto = true);
    final savedPath = await widget.saveImage(File(picked.path));
    if (!mounted) return;
    setState(() {
      _isSavingPhoto = false;
      if (savedPath != null) {
        _photoPath = savedPath;
      }
    });
    if (savedPath == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未能保存藥物相片')));
    }
  }

  void _submit() {
    Navigator.of(context).pop(
      _MedicationEditResult(
        name: _nameController.text.trim(),
        form: _form,
        dosagePerUnit: _dosageController.text.trim(),
        administration: _administration,
        frequency: _frequency,
        dosePerTime: _dosePerTime,
        durationDays: int.tryParse(_durationController.text.trim()),
        totalQuantity: null,
        permitNo: _permitController.text.trim().isEmpty
            ? null
            : _permitController.text.trim(),
        colorIndex: _colorIndex,
        photoPath: _photoPath,
      ),
    );
  }

  String _normalizeForm(String value) {
    final normalized = value.trim();
    if (_formOptions.contains(normalized)) return normalized;
    final upper = normalized.toUpperCase();
    if (upper.contains('CAPSULE')) return '膠囊';
    if (upper.contains('SYRUP') || upper.contains('SUSPENSION')) return '藥水';
    if (upper.contains('CREAM') ||
        upper.contains('OINTMENT') ||
        upper.contains('GEL') ||
        upper.contains('PATCH')) {
      return '膏藥';
    }
    return '藥丸';
  }

  String _normalizeAdministration(String value) {
    final normalized = value.trim();
    if (_administrationOptions.contains(normalized)) return normalized;
    if (normalized.contains('前')) return '飯前';
    if (normalized.contains('後')) return '飯後';
    if (normalized.contains('空腹') || normalized.contains('空肚')) return '空肚食';
    if (normalized.contains('飽') || normalized.contains('飯飽')) return '飽肚食';
    return '飯後';
  }

  String _normalizeDosePerTime(String value) {
    final normalized = value.trim();
    if (_dosePerTimeOptions.contains(normalized)) return normalized;
    if (normalized.contains('0.5')) return '0.5';
    if (normalized.contains('1.5')) return '1.5';
    if (normalized.contains('2.5')) return '2.5';
    if (normalized.contains('3.5')) return '3.5';
    if (normalized.contains('一') || normalized.contains('1')) return '1';
    if (normalized.contains('二') ||
        normalized.contains('兩') ||
        normalized.contains('2')) {
      return '2';
    }
    if (normalized.contains('三') || normalized.contains('3')) return '3';
    if (normalized.contains('四') || normalized.contains('4')) return '4';
    return '1';
  }
}

class _MedicationCard extends StatefulWidget {
  final ExtractedMedication medication;
  final int index;
  final void Function(ExtractedMedication) onUpdate;
  final VoidCallback onDelete;

  const _MedicationCard({
    required this.medication,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends State<_MedicationCard> {
  late TextEditingController _nameController;
  late TextEditingController _dosagePerUnitController;
  late TextEditingController _durationController;
  late int _selectedColorIndex;
  late int _frequency;
  late String _selectedForm;
  late String _selectedAdministration;
  late String _selectedDosePerTime;
  final ImagePicker _imagePicker = ImagePicker();

  static const List<String> _formOptions = ['藥丸', '膠囊', '藥水', '膏藥'];
  static const List<String> _administrationOptions = ['飯前', '飯後', '空肚食', '飽肚食'];
  static const List<String> _dosePerTimeOptions = [
    '0.5',
    '1',
    '1.5',
    '2',
    '2.5',
    '3',
    '3.5',
    '4',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medication.drugName);
    _dosagePerUnitController = TextEditingController(
      text: widget.medication.dosagePerUnit,
    );
    _durationController = TextEditingController(
      text: widget.medication.durationDays?.toString() ?? '',
    );
    _selectedColorIndex = widget.medication.colorIndex ?? widget.index;
    _frequency = widget.medication.frequency > 0
        ? widget.medication.frequency
        : 1;
    _selectedForm = _normalizeForm(widget.medication.form);
    _selectedAdministration = _normalizeAdministration(
      widget.medication.administration,
    );
    _selectedDosePerTime = _normalizeDosePerTime(widget.medication.dosePerTime);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncNormalizedDefaultsToState();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosagePerUnitController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _syncNormalizedDefaultsToState() {
    final med = widget.medication;
    if (med.form != _selectedForm ||
        med.administration != _selectedAdministration ||
        med.dosePerTime != _selectedDosePerTime ||
        med.frequency != _frequency) {
      widget.onUpdate(
        med.copyWith(
          form: _selectedForm,
          administration: _selectedAdministration,
          dosePerTime: _selectedDosePerTime,
          frequency: _frequency,
        ),
      );
    }
  }

  String _normalizeForm(String value) {
    final normalized = value.trim();
    if (_formOptions.contains(normalized)) return normalized;
    final upper = normalized.toUpperCase();
    if (upper.contains('CAPSULE')) return '膠囊';
    if (upper.contains('SYRUP') || upper.contains('SUSPENSION')) return '藥水';
    if (upper.contains('CREAM') ||
        upper.contains('OINTMENT') ||
        upper.contains('GEL') ||
        upper.contains('PATCH')) {
      return '膏藥';
    }
    return '藥丸';
  }

  String _normalizeAdministration(String value) {
    final normalized = value.trim();
    if (_administrationOptions.contains(normalized)) return normalized;
    if (normalized.contains('前')) return '飯前';
    if (normalized.contains('後')) return '飯後';
    if (normalized.contains('空腹') || normalized.contains('空肚')) return '空肚食';
    if (normalized.contains('飽') || normalized.contains('飯飽')) return '飽肚食';
    return '飯後';
  }

  String _normalizeDosePerTime(String value) {
    final normalized = value.trim();
    if (_dosePerTimeOptions.contains(normalized)) return normalized;
    if (normalized.contains('0.5')) return '0.5';
    if (normalized.contains('1.5')) return '1.5';
    if (normalized.contains('2.5')) return '2.5';
    if (normalized.contains('3.5')) return '3.5';
    if (normalized.contains('一') || normalized.contains('1')) return '1';
    if (normalized.contains('二') ||
        normalized.contains('兩') ||
        normalized.contains('2')) {
      return '2';
    }
    if (normalized.contains('三') || normalized.contains('3')) return '3';
    if (normalized.contains('四') || normalized.contains('4')) return '4';
    return '1';
  }

  @override
  Widget build(BuildContext context) {
    final color =
        RainbowColors.colors[_selectedColorIndex % RainbowColors.colors.length];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      RainbowColors.labels[_selectedColorIndex %
                          RainbowColors.labels.length],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '藥物 ${widget.index + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPhotoSection(),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '藥物名稱',
                hintText: '例如：PARACETAMOL',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18),
              onChanged: (value) {
                widget.onUpdate(widget.medication.copyWith(drugName: value));
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedForm,
              decoration: const InputDecoration(
                labelText: '形式',
                border: OutlineInputBorder(),
              ),
              items: _formOptions
                  .map(
                    (option) =>
                        DropdownMenuItem(value: option, child: Text(option)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedForm = value;
                });
                widget.onUpdate(widget.medication.copyWith(form: value));
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dosagePerUnitController,
              decoration: const InputDecoration(
                labelText: '劑量',
                hintText: '例如：500MG',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 16),
              onChanged: (value) {
                widget.onUpdate(
                  widget.medication.copyWith(dosagePerUnit: value),
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedAdministration,
              decoration: const InputDecoration(
                labelText: '服用形式',
                border: OutlineInputBorder(),
              ),
              items: _administrationOptions
                  .map(
                    (option) =>
                        DropdownMenuItem(value: option, child: Text(option)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedAdministration = value;
                });
                widget.onUpdate(
                  widget.medication.copyWith(administration: value),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _frequency,
                    decoration: const InputDecoration(
                      labelText: '每日次數',
                      border: OutlineInputBorder(),
                    ),
                    items: [1, 2, 3, 4, 5, 6, 7, 8]
                        .map(
                          (f) => DropdownMenuItem(value: f, child: Text('$f')),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _frequency = value;
                      });
                      widget.onUpdate(
                        widget.medication.copyWith(frequency: value),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedDosePerTime,
                    decoration: const InputDecoration(
                      labelText: '每次份量',
                      border: OutlineInputBorder(),
                    ),
                    items: _dosePerTimeOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedDosePerTime = value;
                      });
                      widget.onUpdate(
                        widget.medication.copyWith(dosePerTime: value),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '每日 $_frequency 次，每次 $_selectedDosePerTime 份量',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: '持續天數',
                hintText: '空白 = 每天都有',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 16),
              onChanged: (value) {
                widget.onUpdate(
                  widget.medication.copyWith(durationDays: int.tryParse(value)),
                );
              },
            ),
            const SizedBox(height: 14),
            _buildColorPicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('顏色標籤', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(RainbowColors.colors.length, (i) {
            final isSelected = _selectedColorIndex == i;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColorIndex = i;
                });
                widget.onUpdate(widget.medication.copyWith(colorIndex: i));
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: RainbowColors.colors[i],
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.black, width: 3)
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    final path = widget.medication.sourcePhotoPath;
    final hasPhoto = path != null && path.isNotEmpty && File(path).existsSync();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: hasPhoto
                ? Image.file(
                    File(path),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 64,
                    height: 64,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.photo_camera_outlined),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '藥物相片',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  hasPhoto ? '可更新或移除此相片' : '可為此藥物加入一張相片',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _pickDraftPhoto(ImageSource.camera),
                      child: const Text('拍照'),
                    ),
                    OutlinedButton(
                      onPressed: () => _pickDraftPhoto(ImageSource.gallery),
                      child: const Text('相簿'),
                    ),
                    if (hasPhoto)
                      TextButton(
                        onPressed: () {
                          widget.onUpdate(
                            widget.medication.copyWith(
                              clearSourcePhotoPath: true,
                            ),
                          );
                        },
                        child: const Text('移除'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDraftPhoto(ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source);
    if (picked == null) return;
    widget.onUpdate(widget.medication.copyWith(sourcePhotoPath: picked.path));
  }
}
