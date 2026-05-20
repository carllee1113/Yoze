class ExtractedMedication {
  final String drugName; // 藥名: PARACETAMOL
  final String form; // 形式: TABLET
  final String dosagePerUnit; // 每粒成份: 500MG
  final String administration; // 服用形式: 口服
  final int frequency; // 每日服用次數: 4 (times per day)
  final String dosePerTime; // 每次份量: 每次兩粒
  final int? durationDays; // 持續時間: 14 (days)
  final int? totalQuantity; // 總數: 112
  final String? permitNo; // HK-XXXXX registration number
  final String schedule;
  final int? colorIndex;
  final int? hour;
  final int? minute;
  final double confidence;
  final String? rawText;
  final String? sourcePhotoPath;
  final int? medicineCode;

  ExtractedMedication({
    required this.drugName,
    this.form = '',
    this.dosagePerUnit = '',
    this.administration = '',
    this.frequency = 1,
    this.dosePerTime = '',
    this.durationDays,
    this.totalQuantity,
    this.permitNo,
    this.schedule = '',
    this.colorIndex,
    this.hour,
    this.minute,
    this.confidence = 0.5,
    this.rawText,
    this.sourcePhotoPath,
    this.medicineCode,
  });

  ExtractedMedication copyWith({
    String? drugName,
    String? form,
    String? dosagePerUnit,
    String? administration,
    int? frequency,
    String? dosePerTime,
    int? durationDays,
    int? totalQuantity,
    String? permitNo,
    String? schedule,
    int? colorIndex,
    int? hour,
    int? minute,
    double? confidence,
    String? rawText,
    String? sourcePhotoPath,
    int? medicineCode,
    bool clearSourcePhotoPath = false,
  }) {
    return ExtractedMedication(
      drugName: drugName ?? this.drugName,
      form: form ?? this.form,
      dosagePerUnit: dosagePerUnit ?? this.dosagePerUnit,
      administration: administration ?? this.administration,
      frequency: frequency ?? this.frequency,
      dosePerTime: dosePerTime ?? this.dosePerTime,
      durationDays: durationDays ?? this.durationDays,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      permitNo: permitNo ?? this.permitNo,
      schedule: schedule ?? this.schedule,
      colorIndex: colorIndex ?? this.colorIndex,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      confidence: confidence ?? this.confidence,
      rawText: rawText ?? this.rawText,
      sourcePhotoPath: clearSourcePhotoPath
          ? null
          : sourcePhotoPath ?? this.sourcePhotoPath,
      medicineCode: medicineCode ?? this.medicineCode,
    );
  }

  bool get hasTime => hour != null && minute != null;

  // Calculate all times based on first time and frequency
  List<Map<String, int>> getAllTimes() {
    if (hour == null || minute == null) return [];
    final times = <Map<String, int>>[];
    times.add({'hour': hour!, 'minute': minute!});
    if (frequency > 1) {
      final intervalHours = 24 ~/ frequency;
      for (int i = 1; i < frequency; i++) {
        var nextHour = (hour! + intervalHours * i) % 24;
        times.add({'hour': nextHour, 'minute': minute!});
      }
    }
    return times;
  }
}
