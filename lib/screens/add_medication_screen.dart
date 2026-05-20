import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/medication.dart';
import '../theme/rainbow_colors.dart';
import '../services/notification_service.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosagePerUnitController = TextEditingController();
  final _notesController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay(hour: 8, minute: 0);
  int _selectedColorIndex = 0;
  bool _saving = false;
  String _selectedForm = '藥丸';
  String _selectedAdministration = '飯後';
  String _selectedDosePerTime = '1';

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
  void dispose() {
    _nameController.dispose();
    _dosagePerUnitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加藥物')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medication name
              const Text('藥物名称', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(fontSize: 20),
                decoration: _inputDecoration('例如：二甲雙胍'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入藥物名称' : null,
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
                autocorrect: false,
              ),
              const SizedBox(height: 20),

              // Form
              const Text('形式', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedForm,
                decoration: _inputDecoration(''),
                items: _formOptions
                    .map(
                      (option) =>
                          DropdownMenuItem(value: option, child: Text(option)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedForm = value);
                },
              ),
              const SizedBox(height: 20),

              // Dosage per unit
              const Text('劑量（可選）', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dosagePerUnitController,
                style: const TextStyle(fontSize: 20),
                decoration: _inputDecoration('例如：500MG'),
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
              ),
              const SizedBox(height: 20),

              // Administration
              const Text('服用形式', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedAdministration,
                decoration: _inputDecoration(''),
                items: _administrationOptions
                    .map(
                      (option) =>
                          DropdownMenuItem(value: option, child: Text(option)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedAdministration = value);
                },
              ),
              const SizedBox(height: 20),

              // Dose per time
              const Text('每次份量', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedDosePerTime,
                decoration: _inputDecoration(''),
                items: _dosePerTimeOptions
                    .map(
                      (option) =>
                          DropdownMenuItem(value: option, child: Text(option)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedDosePerTime = value);
                },
              ),
              const SizedBox(height: 20),

              // Time
              const Text('服药时间', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              _buildTimePicker(),
              const SizedBox(height: 20),

              // Color
              const Text('顏色標籤', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              _buildColorPicker(),
              const SizedBox(height: 20),

              // Notes
              const Text('備註（可選）', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                style: const TextStyle(fontSize: 18),
                decoration: _inputDecoration('例如：飯後服用'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Camera add button
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed('/capture');
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('拍照添加'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  key: const Key('save_medication'),
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('儲存', style: TextStyle(fontSize: 20)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    return InkWell(
      onTap: _pickTime,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 28, color: Colors.grey),
            const SizedBox(width: 12),
            Text(
              _selectedTime.format(context),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      initialEntryMode: TimePickerEntryMode.dial,
      helpText: '選擇服藥時間',
      cancelText: '取消',
      confirmText: '確認',
      hourLabelText: '時',
      minuteLabelText: '分',
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(RainbowColors.colors.length, (i) {
        final isSelected = _selectedColorIndex == i;
        return GestureDetector(
          onTap: () => setState(() => _selectedColorIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: RainbowColors.colors[i].withValues(
                alpha: isSelected ? 1.0 : 0.4,
              ),
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.black87, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: RainbowColors.colors[i].withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                RainbowColors.labels[i],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black54,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 18, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final med = Medication(
        name: _nameController.text.trim(),
        form: _selectedForm,
        dosagePerUnit: _dosagePerUnitController.text.trim(),
        administration: _selectedAdministration,
        dosePerTime: _selectedDosePerTime,
        dosage: _selectedDosePerTime,
        notes: _notesController.text.trim(),
        medicineCode: await DatabaseHelper.getNextMedicineCode(),
        colorIndex: _selectedColorIndex,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        isEnabled: true,
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

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失敗: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
