import 'dart:convert';

class Medication {
  final int? id;
  final String name;           // 藥名: PARACETAMOL
  final String form;          // 形式: TABLET
  final String dosagePerUnit;  // 每粒成份: 500MG
  final String administration; // 服用形式: 口服
  final String dosePerTime;    // 每次份量: 每次兩粒
  final int? durationDays;     // 持續時間: 14 (days)
  final int? totalQuantity;    // 總數: 112
  final String? permitNo;      // HK-XXXXX
  final String dosage;         // 劑量 (保留向後兼容)
  final String notes;
  final int colorIndex;
  final int hour;
  final int minute;
  final bool isEnabled;
  final DateTime createdAt;

  final String? sourcePhotoPath;

  Medication({
    this.id,
    required this.name,
    this.form = '',
    this.dosagePerUnit = '',
    this.administration = '',
    this.dosePerTime = '',
    this.durationDays,
    this.totalQuantity,
    this.permitNo,
    this.dosage = '',
    this.notes = '',
    required this.colorIndex,
    required this.hour,
    required this.minute,
    this.isEnabled = true,
    DateTime? createdAt,
    this.sourcePhotoPath,
  }) : createdAt = createdAt ?? DateTime.now();

  Medication copyWith({
    int? id,
    String? name,
    String? form,
    String? dosagePerUnit,
    String? administration,
    String? dosePerTime,
    int? durationDays,
    int? totalQuantity,
    String? permitNo,
    String? dosage,
    String? notes,
    int? colorIndex,
    int? hour,
    int? minute,
    bool? isEnabled,
    DateTime? createdAt,
    String? sourcePhotoPath,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      form: form ?? this.form,
      dosagePerUnit: dosagePerUnit ?? this.dosagePerUnit,
      administration: administration ?? this.administration,
      dosePerTime: dosePerTime ?? this.dosePerTime,
      durationDays: durationDays ?? this.durationDays,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      permitNo: permitNo ?? this.permitNo,
      dosage: dosage ?? this.dosage,
      notes: notes ?? this.notes,
      colorIndex: colorIndex ?? this.colorIndex,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      sourcePhotoPath: sourcePhotoPath ?? this.sourcePhotoPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'form': form,
      'dosagePerUnit': dosagePerUnit,
      'administration': administration,
      'dosePerTime': dosePerTime,
      'durationDays': durationDays,
      'totalQuantity': totalQuantity,
      'permitNo': permitNo ?? '',
      'dosage': dosage,
      'notes': notes,
      'colorIndex': colorIndex,
      'hour': hour,
      'minute': minute,
      'isEnabled': isEnabled ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'sourcePhotoPath': sourcePhotoPath,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] as int?,
      name: map['name'] as String,
      form: (map['form'] as String?) ?? '',
      dosagePerUnit: (map['dosagePerUnit'] as String?) ?? '',
      administration: (map['administration'] as String?) ?? '',
      dosePerTime: (map['dosePerTime'] as String?) ?? '',
      durationDays: map['durationDays'] as int?,
      totalQuantity: map['totalQuantity'] as int?,
      permitNo: map['permitNo'] as String?,
      dosage: (map['dosage'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      colorIndex: map['colorIndex'] as int,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      isEnabled: (map['isEnabled'] as int?) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      sourcePhotoPath: map['sourcePhotoPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory Medication.fromJson(String source) =>
      Medication.fromMap(json.decode(source) as Map<String, dynamic>);

  String get timeLabel => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}