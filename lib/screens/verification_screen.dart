import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  TimeOfDay _dayStartTime = const TimeOfDay(hour: 8, minute: 0);
  bool _didInit = false;

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
      }
      if (widget.startWithCamera) {
        await _addFromPhoto();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(photoScanProvider);
    final medications = scanState.extractedMedications;
    final slotCount = _slotCountFor(medications);
    final slots = SchedulePlanner.generateDailySlots(
      startHour: _dayStartTime.hour,
      startMinute: _dayStartTime.minute,
      slotCount: slotCount,
    );
    final plan = SchedulePlanner.buildPlan(
      medications: medications,
      startHour: _dayStartTime.hour,
      startMinute: _dayStartTime.minute,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('批量設定藥物'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: Column(
        children: [
          _buildTopControls(medications, slots),
          if ((scanState.diagnosticMessage ?? '').isNotEmpty)
            _buildOcrDiagnostic(scanState.diagnosticMessage!),
          const Divider(height: 1),
          Expanded(
            child: medications.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: medications.length,
                    itemBuilder: (context, index) {
                      return _MedicationCard(
                        medication: medications[index],
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
                      );
                    },
                  ),
          ),
          if (medications.isNotEmpty)
            _buildPlanPreview(plan),
          _buildActionBar(medications),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  Widget _buildActionBar(List<ExtractedMedication> medications) {
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
            onPressed: medications.isEmpty || _isSaving ? null : _saveAll,
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
                    '儲存排程 (${medications.length} 種藥)',
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
          Icon(Icons.medication_outlined, size: 64, color: Colors.grey.shade400),
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
        builder: (_) => const PhotoCaptureScreen(returnExtractedMedications: true),
      ),
    );

    if (!mounted || result == null || result.isEmpty) return;

    final needsManualInput = result.any((med) => med.confidence <= 0.1);
    final currentMedications = ref.read(photoScanProvider).extractedMedications;
    final nextMedications = <ExtractedMedication>[
      ...currentMedications,
      ...result.map(
        (med) => med.copyWith(
          form: med.form.isEmpty ? '藥丸' : med.form,
          administration: med.administration.isEmpty ? '飯後' : med.administration,
          dosePerTime: med.dosePerTime.isEmpty ? '4' : med.dosePerTime,
          frequency: med.frequency <= 0 ? 1 : med.frequency,
        ),
      ),
    ];

    ref.read(photoScanProvider.notifier).setMedications(nextMedications);

    if (mounted && needsManualInput) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未能自動識別，已建立空白藥物卡，請手動填寫。')),
      );
    }
  }

  void _addEmptyMedication() {
    ref.read(photoScanProvider.notifier).addMedication(
          ExtractedMedication(
            drugName: '',
            form: '藥丸',
            administration: '飯後',
            dosePerTime: '4',
            frequency: 1,
            colorIndex: ref.read(photoScanProvider).extractedMedications.length,
          ),
        );
  }

  Future<void> _saveAll() async {
    final medications = ref.read(photoScanProvider).extractedMedications;
    if (medications.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final plan = SchedulePlanner.buildPlan(
        medications: medications,
        startHour: _dayStartTime.hour,
        startMinute: _dayStartTime.minute,
      );

      for (final slot in plan.slots) {
        for (final extracted in slot.medications) {
          if (extracted.drugName.trim().isEmpty) continue;

          final med = Medication(
            name: extracted.drugName.trim(),
            form: extracted.form,
            dosagePerUnit: extracted.dosagePerUnit,
            administration: extracted.administration,
            dosePerTime: extracted.dosePerTime,
            durationDays: extracted.durationDays,
            totalQuantity: extracted.totalQuantity,
            dosage: extracted.dosePerTime,
            colorIndex: extracted.colorIndex ?? 0,
            hour: slot.hour,
            minute: slot.minute,
            isEnabled: true,
            sourcePhotoPath: widget.imagePath,
          );

          final id = await DatabaseHelper.insertMedication(med);
          if (id > 0) {
            await NotificationService.scheduleMedicationReminder(
              medicationId: id,
              medicationName: med.name,
              colorIndex: med.colorIndex,
              hour: med.hour,
              minute: med.minute,
            );
          }
        }
      }

      if (mounted) {
        ref.read(photoScanProvider.notifier).reset();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失敗: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _goBack() {
    ref.read(photoScanProvider.notifier).reset();
    Navigator.of(context).pop();
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
  late TextEditingController _totalQuantityController;
  late int _selectedColorIndex;
  late int _frequency;
  late String _selectedForm;
  late String _selectedAdministration;
  late String _selectedDosePerTime;

  static const List<String> _formOptions = ['藥丸', '膠囊', '藥水', '膏藥'];
  static const List<String> _administrationOptions = ['飯前', '飯後', '空肚食', '飽肚食'];
  static const List<String> _dosePerTimeOptions = ['1', '2', '3', '4'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medication.drugName);
    _dosagePerUnitController = TextEditingController(text: widget.medication.dosagePerUnit);
    _durationController = TextEditingController(text: widget.medication.durationDays?.toString() ?? '');
    _totalQuantityController = TextEditingController(text: widget.medication.totalQuantity?.toString() ?? '');
    _selectedColorIndex = widget.medication.colorIndex ?? widget.index;
    _frequency = widget.medication.frequency > 0 ? widget.medication.frequency : 1;
    _selectedForm = _normalizeForm(widget.medication.form);
    _selectedAdministration = _normalizeAdministration(widget.medication.administration);
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
    _totalQuantityController.dispose();
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
    if (upper.contains('CREAM') || upper.contains('OINTMENT') || upper.contains('GEL') || upper.contains('PATCH')) {
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
    if (normalized.contains('一') || normalized.contains('1')) return '1';
    if (normalized.contains('二') || normalized.contains('兩') || normalized.contains('2')) return '2';
    if (normalized.contains('三') || normalized.contains('3')) return '3';
    if (normalized.contains('四') || normalized.contains('4')) return '4';
    return '4';
  }

  @override
  Widget build(BuildContext context) {
    final color = RainbowColors.colors[_selectedColorIndex % RainbowColors.colors.length];

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
                      RainbowColors.labels[_selectedColorIndex % RainbowColors.labels.length],
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                  .map((option) => DropdownMenuItem(value: option, child: Text(option)))
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
                widget.onUpdate(widget.medication.copyWith(dosagePerUnit: value));
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
                  .map((option) => DropdownMenuItem(value: option, child: Text(option)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedAdministration = value;
                });
                widget.onUpdate(widget.medication.copyWith(administration: value));
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedDosePerTime,
              decoration: const InputDecoration(
                labelText: '每次份量',
                border: OutlineInputBorder(),
              ),
              items: _dosePerTimeOptions
                  .map((option) => DropdownMenuItem(value: option, child: Text(option)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedDosePerTime = value;
                });
                widget.onUpdate(widget.medication.copyWith(dosePerTime: value));
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('每日次數:', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _frequency,
                  items: [1, 2, 3, 4, 5, 6]
                      .map((f) => DropdownMenuItem(value: f, child: Text('$f 次')))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _frequency = value;
                    });
                    widget.onUpdate(widget.medication.copyWith(frequency: value));
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: '持續天數',
                      hintText: '14',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 16),
                    onChanged: (value) {
                      widget.onUpdate(widget.medication.copyWith(
                        durationDays: int.tryParse(value),
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _totalQuantityController,
                    decoration: const InputDecoration(
                      labelText: '總數',
                      hintText: '112',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 16),
                    onChanged: (value) {
                      widget.onUpdate(widget.medication.copyWith(
                        totalQuantity: int.tryParse(value),
                      ));
                    },
                  ),
                ),
              ],
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
                  border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
              ),
            );
          }),
        ),
      ],
    );
  }
}
