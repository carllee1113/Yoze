import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/medication.dart';
import '../models/extracted_medication.dart';
import '../providers/photo_scan_provider.dart';
import '../theme/rainbow_colors.dart';
import '../services/notification_service.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  final String imagePath;

  const VerificationScreen({super.key, required this.imagePath});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(photoScanProvider);
    final medications = scanState.extractedMedications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('確認藥物'),
        actions: [
          TextButton(
            onPressed: () {
              // Show help about single medicine per photo
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('拍攝提示'),
                  content: const Text(
                    '每張照片只拍攝一種藥物的標籤。\n\n'
                    '请确保：\n'
                    '• 光线充足\n'
                    '• 標籤平整放置\n'
                    '• 文字清晰可见\n\n'
                    '这样可以获得最佳的识别效果。',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('?'),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _goBack(),
        ),
      ),
      body: Column(
        children: [
          // Image preview thumbnail
          Container(
            height: 80,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(widget.imagePath),
                    height: 60,
                    width: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '請確認識別的藥物資料',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: () => _retake(),
                  child: const Text('重拍'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Single medicine indicator
          if (medications.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '每次拍攝一種藥物',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 14),
                  ),
                ],
              ),
            ),

          // Medications list
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

          // Add medication button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _addEmptyMedication,
              icon: const Icon(Icons.add),
              label: const Text('手動新增藥物'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),

          // Save button
          Container(
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
                          '添加全部 (${medications.length})',
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '無法識別出藥物',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            '請嘗試重新拍攝，或手動新增藥物',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    ref.read(photoScanProvider.notifier).reset();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _retake() {
    ref.read(photoScanProvider.notifier).reset();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _addEmptyMedication() {
    ref.read(photoScanProvider.notifier).addMedication(
          ExtractedMedication(
            drugName: '',
            form: '藥丸',
            administration: '飯後',
            dosePerTime: '4',
            colorIndex: ref.read(photoScanProvider).extractedMedications.length,
          ),
        );
  }

  Future<void> _saveAll() async {
    final scanState = ref.read(photoScanProvider);
    final medications = scanState.extractedMedications;

    if (medications.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      for (int i = 0; i < medications.length; i++) {
        final extracted = medications[i];

        final allTimes = extracted.getAllTimes();

        for (int t = 0; t < allTimes.length; t++) {
          final timeSlot = allTimes[t];

          if (extracted.drugName.isEmpty) {
            continue;
          }

          final med = Medication(
            name: extracted.drugName,
            form: extracted.form,
            dosagePerUnit: extracted.dosagePerUnit,
            administration: extracted.administration,
            dosePerTime: extracted.dosePerTime,
            durationDays: extracted.durationDays,
            totalQuantity: extracted.totalQuantity,
            dosage: extracted.dosePerTime,
            colorIndex: extracted.colorIndex ?? i,
            hour: timeSlot['hour']!,
            minute: timeSlot['minute']!,
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
  late TimeOfDay _firstTime;
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
    _firstTime = TimeOfDay(
      hour: widget.medication.hour ?? 8,
      minute: widget.medication.minute ?? 0,
    );
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
        med.dosePerTime != _selectedDosePerTime) {
      widget.onUpdate(
        med.copyWith(
          form: _selectedForm,
          administration: _selectedAdministration,
          dosePerTime: _selectedDosePerTime,
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
            // Header with color dot and delete
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

            // Drug name input
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '藥物名稱',
                hintText: '例如：二甲雙胍',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18),
              onChanged: (value) {
                widget.onUpdate(widget.medication.copyWith(drugName: value));
              },
            ),
            const SizedBox(height: 12),

            // Form selector
            DropdownButtonFormField<String>(
              initialValue: _selectedForm,
              decoration: const InputDecoration(
                labelText: '形式',
                border: OutlineInputBorder(),
              ),
              items: _formOptions
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
                  _selectedForm = value;
                });
                widget.onUpdate(widget.medication.copyWith(form: value));
              },
            ),
            const SizedBox(height: 12),

            // Dosage per unit input
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

            // Administration selector
            DropdownButtonFormField<String>(
              initialValue: _selectedAdministration,
              decoration: const InputDecoration(
                labelText: '服用形式',
                border: OutlineInputBorder(),
              ),
              items: _administrationOptions
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
                  _selectedAdministration = value;
                });
                widget.onUpdate(widget.medication.copyWith(administration: value));
              },
            ),
            const SizedBox(height: 12),

            // Dose per time selector
            DropdownButtonFormField<String>(
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
                widget.onUpdate(widget.medication.copyWith(dosePerTime: value));
              },
            ),
            const SizedBox(height: 12),

            // Duration and total quantity row
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
            const SizedBox(height: 16),

            // Time picker
            _buildTimePicker(),
            const SizedBox(height: 16),

            // Color picker
            _buildColorPicker(),

            // Confidence indicator
            if (widget.medication.confidence > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    widget.medication.confidence > 0.5
                        ? Icons.check_circle
                        : Icons.help_outline,
                    size: 16,
                    color: widget.medication.confidence > 0.5
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '識別可信度: ${(widget.medication.confidence * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    final allTimes = widget.medication.getAllTimes();
    final intervalHours = _frequency > 1 ? 24 ~/ _frequency : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Frequency selector
        Row(
          children: [
            const Text('服藥頻率:', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _frequency,
              items: [1, 2, 3, 4].map((f) => DropdownMenuItem(
                value: f,
                child: Text('每日$f次'),
              )).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _frequency = value;
                  });
                  widget.onUpdate(widget.medication.copyWith(frequency: value));
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // First time picker
        InkWell(
          onTap: _pickTime,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 24),
                const SizedBox(width: 8),
                Text(
                  '首次服藥: ${_firstTime.hour.toString().padLeft(2, '0')}:${_firstTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 18),
                ),
                const Spacer(),
                const Icon(Icons.edit, size: 20, color: Colors.grey),
              ],
            ),
          ),
        ),

        // Show calculated times
        if (_frequency > 1 && allTimes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '服藥時間: ${allTimes.map((t) => '${t['hour']!.toString().padLeft(2, '0')}:${t['minute']!.toString().padLeft(2, '0')}').join(', ')}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Text(
            '(每 $intervalHours 小時一次)',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ],
    );
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _firstTime,
      helpText: '選擇首次服藥時間',
      cancelText: '取消',
      confirmText: '確認',
    );
    if (time != null) {
      setState(() {
        _firstTime = time;
      });
      widget.onUpdate(widget.medication.copyWith(
        hour: time.hour,
        minute: time.minute,
        frequency: _frequency,
      ));
    }
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
}
