import 'dart:convert';

enum DoseStatus { pending, confirmed, missed, skipped }

class DoseRecord {
  final int? id;
  final int medicationId;
  final String date;
  final int doseIndex;
  final DoseStatus status;
  final DateTime? confirmedAt;
  final DateTime? notifiedAt;

  DoseRecord({
    this.id,
    required this.medicationId,
    required this.date,
    required this.doseIndex,
    this.status = DoseStatus.pending,
    this.confirmedAt,
    this.notifiedAt,
  });

  DoseRecord copyWith({
    int? id,
    int? medicationId,
    String? date,
    int? doseIndex,
    DoseStatus? status,
    DateTime? confirmedAt,
    DateTime? notifiedAt,
  }) {
    return DoseRecord(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      date: date ?? this.date,
      doseIndex: doseIndex ?? this.doseIndex,
      status: status ?? this.status,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      notifiedAt: notifiedAt ?? this.notifiedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'medicationId': medicationId,
      'date': date,
      'doseIndex': doseIndex,
      'status': status.index,
      'confirmedAt': confirmedAt?.toIso8601String(),
      'notifiedAt': notifiedAt?.toIso8601String(),
    };
  }

  factory DoseRecord.fromMap(Map<String, dynamic> map) {
    return DoseRecord(
      id: map['id'] as int?,
      medicationId: map['medicationId'] as int,
      date: map['date'] as String,
      doseIndex: map['doseIndex'] as int,
      status: DoseStatus.values[map['status'] as int? ?? 0],
      confirmedAt: map['confirmedAt'] != null
          ? DateTime.parse(map['confirmedAt'] as String)
          : null,
      notifiedAt: map['notifiedAt'] != null
          ? DateTime.parse(map['notifiedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory DoseRecord.fromJson(String source) =>
      DoseRecord.fromMap(json.decode(source) as Map<String, dynamic>);
}
