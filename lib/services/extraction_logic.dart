import '../models/extracted_medication.dart';

class OcrTextBlock {
  final String text;
  final int start;
  final int end;

  OcrTextBlock({required this.text, required this.start, required this.end});
}

class ExtractionLogic {
  static final RegExp _mealPattern = RegExp(
    r'(?:早餐|午餐|晚餐|睡前|早|中|晚|飯前|飯後|空腹|用餐前|用餐後)',
    caseSensitive: false,
  );

  static final RegExp _frequencyPattern = RegExp(
    r'(?:每日|每天|每晚|每早|每中午|一天|兩天|接著)\s*(\d+)?\s*(?:次|次\/日|次\/天|次\/晚|粒|顆|片|包)',
    caseSensitive: false,
  );

  static List<ExtractedMedication> parseTextBlocks(
    List<OcrTextBlock> blocks,
    String fullText,
  ) {
    final hasBlocks = blocks.isNotEmpty;
    final medications = <ExtractedMedication>[];

    final hkParsed = _parseHKLabelFormat(fullText);
    if (hkParsed != null && hkParsed.drugName.isNotEmpty) {
      medications.add(hkParsed);
      return medications;
    }

    final drugNameFound = _findDrugNameInText(fullText);
    if (drugNameFound != null) {
      medications.add(drugNameFound);
      return medications;
    }

    final permitContext = _extractByPermitNumber(fullText);
    if (permitContext != null) {
      medications.add(permitContext);
      return medications;
    }

    final englishDrug = _findEnglishDrugName(fullText);
    if (englishDrug != null) {
      medications.add(englishDrug);
      return medications;
    }

    if (hasBlocks && fullText.trim().isEmpty) {
      return medications;
    }

    return medications;
  }

  static ExtractedMedication? _findDrugNameInText(String text) {
    final drugKeywords = [
      'PARACETAMOL',
      'ACETAMINOPHEN',
      'AMOXICILLIN',
      'AZITHROMYCIN',
      'IBUPROFEN',
      'NAPROXEN',
      'METFORMIN',
      'ATORVASTATIN',
      'RAMIPRIL',
      'LOSARTAN',
      'AMLODIPINE',
      'METOPROLOL',
      'OMEPRAZOLE',
      'PANTOPRAZOLE',
      'LANSOPRAZOLE',
      'ESOMEPRAZOLE',
      'SIMVASTATIN',
      'ROSUVASTATIN',
      'PRAVASTATIN',
      'GLIMEPIRIDE',
      'GLIPIZIDE',
      'CETIRIZINE',
      'LORATADINE',
      'CHLORPHENIRAMINE',
      'DICLOFENAC',
      'CELECOXIB',
      'TRAMADOL',
      'PANADOL',
      'BIOGLYN',
      'FEXOFENADINE',
      'MONTELUKAST',
      'ASPIRIN',
      'CLOPIDOGREL',
      'FUROSEMIDE',
      'SPIRONOLACTONE',
      'BENDROFLUMETHIAZIDE',
      'HYDROCHLOROTHIAZIDE',
      'INDAPAMIDE',
      'ZYRTEC',
      'FAMOTIDINE',
      'BROMHEXINE',
      'DEQUALINIUM',
      'METRONIDAZOLE',
      'CIPROFLOXACIN',
      'LEVOFLOXACIN',
      'LORATADINE',
      'DESLORATADINE',
      'CHLORPHENIRAMINE',
      'DEXTROMETHORPHAN',
      'GUAIFENESIN',
      'SALBUTAMOL',
      'BECLOMETHASONE',
    ];

    final upperText = text.toUpperCase();
    for (final drug in drugKeywords) {
      if (upperText.contains(drug)) {
        final index = upperText.indexOf(drug);

        final contextStart = (index - 20).clamp(0, text.length);
        final contextEnd = (index + drug.length + 30).clamp(0, text.length);
        final context = text.substring(contextStart, contextEnd).toUpperCase();

        String? form;
        String? dosage;
        for (final formName in [
          'TABLET',
          'CAPSULE',
          'LOZENGE',
          'SYRUP',
          'CREAM',
          'INJECTION',
          'DROP',
          'POWDER',
        ]) {
          if (context.contains(formName)) {
            form = formName;
            break;
          }
        }

        final dosagePattern = RegExp(
          r'(\d+\.?\d*)\s*(mg|g|ml|mcg)',
          caseSensitive: false,
        );
        final dosageMatch = dosagePattern.firstMatch(context);
        if (dosageMatch != null) {
          dosage =
              '${dosageMatch.group(1)}${dosageMatch.group(2)}'.toUpperCase();
        }

        final freq = _extractFrequencyFromContext(text);
        final admin = _extractAdministration(text);
        final dosePerTime = _extractDosePerTime(text);
        final duration = _extractDuration(text);
        final total = _extractTotalQuantity(text);
        final permit = _extractPermitNumber(text);

        return ExtractedMedication(
          drugName: drug,
          form: form ?? '',
          dosagePerUnit: dosage ?? '',
          administration: admin,
          frequency: freq,
          dosePerTime: dosePerTime,
          durationDays: duration,
          totalQuantity: total,
          permitNo: permit,
          schedule: _extractSchedule(text),
          hour: 8,
          minute: 0,
          colorIndex: 0,
          confidence: 0.8,
          rawText: text,
        );
      }
    }
    return null;
  }

  static String _extractPermitNumber(String text) {
    final pattern = RegExp(r'(HK-\d{5})');
    final match = pattern.firstMatch(text);
    return match?.group(1) ?? '';
  }

  static ExtractedMedication? _extractByPermitNumber(String text) {
    final permitPattern = RegExp(r'HK-\d{5}');
    final permitMatch = permitPattern.firstMatch(text);
    if (permitMatch == null) return null;

    final permitIndex = permitMatch.start;
    final context = _getContextAround(text, permitIndex, 100);

    final formPattern = RegExp(
      r'([A-Za-z]+)\s+(TABLET|CAPSULE|CREAM|INJECTION|SYRUP|DROP|POWDER|PATCH|SPRAY|OINTMENT|GEL|SOLUTION)\s+(\d+\.?\d*\s*(mg|g|ml|mcg))',
      caseSensitive: false,
    );
    final formMatch = formPattern.firstMatch(context);
    if (formMatch != null) {
      final drugName = formMatch.group(1)!.toUpperCase();
      final form = formMatch.group(2)!.toUpperCase();
      final dosage = formMatch.group(3)!.toUpperCase();

      final freq = _extractFrequencyFromContext(text);
      final admin = _extractAdministration(text);
      final dosePerTime = _extractDosePerTime(text);
      final duration = _extractDuration(text);
      final total = _extractTotalQuantity(text);

      return ExtractedMedication(
        drugName: drugName,
        form: form,
        dosagePerUnit: dosage,
        administration: admin,
        frequency: freq,
        dosePerTime: dosePerTime,
        durationDays: duration,
        totalQuantity: total,
        permitNo: permitMatch.group(0),
        schedule: _extractSchedule(text),
        hour: 8,
        minute: 0,
        colorIndex: 0,
        confidence: 0.85,
        rawText: text,
      );
    }
    return null;
  }

  static ExtractedMedication? _findEnglishDrugName(String text) {
    final pattern = RegExp(
      r'([A-Za-z]{3,30})\s+(TABLET|CAPSULE|TAB|CAP|cream|injection|syrup|drop|powder)\s*(\d+\.?\d*\s*(mg|g|ml|mcg))?',
      caseSensitive: false,
    );

    final match = pattern.firstMatch(text);
    if (match != null) {
      final drugName = match.group(1)!.toUpperCase();
      final form = match.group(2)!.toUpperCase();
      final dosage = match.group(3) ?? '';

      if (_isEnglishMedicalNoise(drugName)) return null;

      final freq = _extractFrequencyFromContext(text);
      final admin = _extractAdministration(text);
      final dosePerTime = _extractDosePerTime(text);
      final duration = _extractDuration(text);
      final total = _extractTotalQuantity(text);

      return ExtractedMedication(
        drugName: drugName,
        form: form == 'TAB' ? 'TABLET' : form == 'CAP' ? 'CAPSULE' : form,
        dosagePerUnit: dosage,
        administration: admin,
        frequency: freq,
        dosePerTime: dosePerTime,
        durationDays: duration,
        totalQuantity: total,
        schedule: _extractSchedule(text),
        hour: 8,
        minute: 0,
        colorIndex: 0,
        confidence: 0.7,
        rawText: text,
      );
    }
    return null;
  }

  static String _getContextAround(String text, int position, int radius) {
    final start = (position - radius).clamp(0, text.length);
    final end = (position + radius).clamp(0, text.length);
    return text.substring(start, end);
  }

  static int _extractFrequencyFromContext(String text) {
    final patterns = [
      RegExp(r'每日([一二兩三四五六七八九十]+)次'),
      RegExp(r'每天([一二兩三四五六七八九十]+)次'),
      RegExp(r'一天([一二兩三四五六七八九十]+)次'),
      RegExp(r'qid', caseSensitive: false),
      RegExp(r'tid', caseSensitive: false),
      RegExp(r'bid', caseSensitive: false),
      RegExp(r'qd', caseSensitive: false),
    ];

    final chineseNumbers = {
      '一': 1,
      '二': 2,
      '兩': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '十': 10,
    };

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final matched = match.group(0)!.toLowerCase();
        for (final entry in chineseNumbers.entries) {
          if (matched.contains(entry.key)) {
            return entry.value;
          }
        }
        if (matched.contains('qid') || matched.contains('四次')) return 4;
        if (matched.contains('tid') || matched.contains('三次')) return 3;
        if (matched.contains('bid') || matched.contains('兩次')) return 2;
        if (matched.contains('qd') || matched.contains('一次')) return 1;
      }
    }
    return 1;
  }

  static ExtractedMedication? _parseHKLabelFormat(String text) {
    String? drugName;
    String? form;
    String? dosagePerUnit;
    String? administration;
    int frequency = 1;
    String? dosePerTime;
    int? durationDays;
    int? totalQuantity;
    String? permitNo;

    if (text.contains('PROLONGED RELEASE')) {
      final parts = text.split('PROLONGED RELEASE');
      if (parts.isNotEmpty) {
        final drugPart = parts[0].trim();
        final drugMatch = RegExp(r'([A-Za-z][A-Za-z\-]+?)\s*$').firstMatch(drugPart);
        if (drugMatch != null) {
          drugName = drugMatch.group(1)!.toUpperCase();
          form = 'TABLET';

          final dosagePattern = RegExp(
            r'(\d+\.?\d*)\s*(mg|g|ml|mcg)',
            caseSensitive: false,
          );
          final dosageMatch = dosagePattern.firstMatch(text);
          dosagePerUnit = dosageMatch != null
              ? '${dosageMatch.group(1)}${dosageMatch.group(2)}'.toUpperCase()
              : '';

          final qtyPattern = RegExp(
            r'(\d+)\s*(TAB|TABLET|粒|顆|片|LOZENGE)',
            caseSensitive: false,
          );
          final qtyMatch = qtyPattern.firstMatch(text);
          if (qtyMatch != null) {
            totalQuantity = int.tryParse(qtyMatch.group(1)!);
          }
        }
      }
    }

    if (drugName == null) {
      final labeledPattern = RegExp(
        r'藥名\s*Drug:\s*([A-Za-z][A-Za-z\-]*?)(?:\s+\([^)]+\))?\s+(\d+\.?\d*)\s*(mg|g|ml|mcg)\s+([A-Za-z]+)\s*(HK-\d{5})?',
        caseSensitive: false,
      );
      final labeledMatch = labeledPattern.firstMatch(text);
      if (labeledMatch != null) {
        drugName = labeledMatch.group(1)?.toUpperCase();
        form = labeledMatch.group(4)?.toUpperCase() ?? '';
        if (form == 'LOZENGES') form = 'LOZENGE';
        dosagePerUnit =
            '${labeledMatch.group(2)}${labeledMatch.group(3)}'.toUpperCase();
        permitNo = labeledMatch.group(5);
      }
    }

    if (drugName == null) {
      final hospitalPattern = RegExp(
        r'([A-Za-z][A-Za-z\-]*?)\s+(TABLET|CAPSULE|CREAM|INJECTION|SYRUP|DROP|POWDER|PATCH|SPRAY|OINTMENT|GEL|SOLUTION)\s+(\d+\.?\d*)\s*(mg|g|ml|mcg)',
        caseSensitive: false,
      );
      final hospitalMatch = hospitalPattern.firstMatch(text);
      if (hospitalMatch != null) {
        drugName = hospitalMatch.group(1)?.toUpperCase();
        form = hospitalMatch.group(2)?.toUpperCase();
        dosagePerUnit =
            '${hospitalMatch.group(3)}${hospitalMatch.group(4)}'.toUpperCase();
      }
    }

    if (drugName == null) {
      final simplePattern = RegExp(
        r'([A-Za-z]{3,30})\s+(TABLET|CAPSULE|LOZENGE|SYRUP|CREAM)\s+(\d+\.?\d*)\s*(mg|g|ml|mcg)',
        caseSensitive: false,
      );
      final simpleMatch = simplePattern.firstMatch(text);
      if (simpleMatch != null) {
        drugName = simpleMatch.group(1)?.toUpperCase();
        form = simpleMatch.group(2)?.toUpperCase();
        dosagePerUnit =
            '${simpleMatch.group(3)}${simpleMatch.group(4)}'.toUpperCase();
      }
    }

    if (drugName == null) {
      return null;
    }

    final adminPattern = RegExp(r'(口服|注射|外用|塗抹|噴霧|含服|滴眼|滴耳|吸入)');
    final adminMatch = adminPattern.firstMatch(text);
    administration = adminMatch?.group(1) ?? '口服';

    final freqPatterns = [
      RegExp(r'每日\s*([一二兩三四五六七八九十]+)\s*次'),
      RegExp(r'每天\s*([一二兩三四五六七八九十]+)\s*次'),
      RegExp(r'每日\s+(\d+)\s*次'),
    ];

    bool freqFound = false;
    for (final pattern in freqPatterns) {
      final freqMatch = pattern.firstMatch(text);
      if (freqMatch != null) {
        final numStr = freqMatch.group(1)!;
        final arabicNum = int.tryParse(numStr);
        if (arabicNum != null) {
          frequency = arabicNum.clamp(1, 10);
        } else {
          frequency = _chineseNumberToInt(numStr);
        }
        freqFound = true;
        break;
      }
    }

    if (!freqFound) {
      if (text.toLowerCase().contains('qid') || text.contains('四次')) {
        frequency = 4;
      } else if (text.toLowerCase().contains('tid') || text.contains('三次')) {
        frequency = 3;
      } else if (text.toLowerCase().contains('bid') || text.contains('兩次')) {
        frequency = 2;
      } else if (text.toLowerCase().contains('qd') || text.contains('一次')) {
        frequency = 1;
      } else if (
        RegExp(r'\b2\s*times?\b', caseSensitive: false).hasMatch(text)
      ) {
        frequency = 2;
      } else if (
        RegExp(r'\b3\s*times?\b', caseSensitive: false).hasMatch(text)
      ) {
        frequency = 3;
      }
    }

    final dosePattern = RegExp(r'每次([一二兩三四五六七八九十\d]+)[粒顆片包]');
    final doseMatch = dosePattern.firstMatch(text);
    if (doseMatch != null) {
      dosePerTime = doseMatch.group(0);
    }

    final totalPattern = RegExp(
      r'(\d+)\s*(TAB|TABLET|CAP|LOZENGE|粒|顆|片)',
      caseSensitive: false,
    );
    final totalMatch = totalPattern.firstMatch(text);
    if (totalMatch != null) {
      totalQuantity = int.tryParse(totalMatch.group(1)!);
    }

    final permitPattern = RegExp(r'(HK-\d{5})');
    final permitMatch = permitPattern.firstMatch(text);
    permitNo = permitMatch?.group(1) ?? permitNo;

    return ExtractedMedication(
      drugName: drugName,
      form: form ?? '',
      dosagePerUnit: dosagePerUnit ?? '',
      administration: administration,
      frequency: frequency,
      dosePerTime: dosePerTime ?? '',
      durationDays: durationDays,
      totalQuantity: totalQuantity,
      permitNo: permitNo,
      schedule: '',
      hour: 8,
      minute: 0,
      confidence: 0.85,
      rawText: text,
    );
  }

  static int _chineseNumberToInt(String text) {
    final chineseNumbers = {
      '一': 1,
      '二': 2,
      '兩': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '十': 10,
      '1': 1,
      '2': 2,
      '3': 3,
      '4': 4,
      '5': 5,
      '6': 6,
      '7': 7,
      '8': 8,
      '9': 9,
      '0': 0,
    };

    int result = 0;
    for (final char in text.split('')) {
      if (chineseNumbers.containsKey(char)) {
        result = chineseNumbers[char]!;
      }
    }
    return result == 0 ? 1 : result;
  }

  static String _extractAdministration(String text) {
    final adminPatterns = [
      '口服',
      '注射',
      '外用',
      '塗抹',
      '噴霧',
      '含服',
      '滴眼',
      '滴耳',
      'inhale',
      'oral',
      'inject',
      'topical',
      'apply',
    ];
    for (final pattern in adminPatterns) {
      if (text.toLowerCase().contains(pattern.toLowerCase())) {
        if (pattern == 'inhale') return '吸入';
        if (pattern == 'oral') return '口服';
        if (pattern == 'inject') return '注射';
        if (pattern == 'topical') return '外用';
        return pattern;
      }
    }
    return '';
  }

  static String _extractDosePerTime(String text) {
    final pattern = RegExp(r'每次[一二兩三四五六七八九十\d]+[粒顆片包]');
    final match = pattern.firstMatch(text);
    if (match != null) return match.group(0)!;

    final englishPattern = RegExp(
      r'(\d+)\s*(tablet|capsule|pill|pack)s?',
      caseSensitive: false,
    );
    final engMatch = englishPattern.firstMatch(text);
    return engMatch != null ? engMatch.group(0)! : '';
  }

  static int? _extractDuration(String text) {
    final chinesePattern = RegExp(r'(\d+)\s*天');
    final chMatch = chinesePattern.firstMatch(text);
    if (chMatch != null) return int.tryParse(chMatch.group(1)!);

    final englishPattern = RegExp(r'(\d+)\s*(day|days)', caseSensitive: false);
    final engMatch = englishPattern.firstMatch(text);
    return engMatch != null ? int.tryParse(engMatch.group(1)!) : null;
  }

  static int? _extractTotalQuantity(String text) {
    final chinesePattern = RegExp(r'總數[：:]\s*(\d+)');
    final chMatch = chinesePattern.firstMatch(text);
    if (chMatch != null) return int.tryParse(chMatch.group(1)!);

    final tabPattern = RegExp(r'(\d+)\s*(TAB|CAP|PILL)', caseSensitive: false);
    final tabMatch = tabPattern.firstMatch(text);
    return tabMatch != null ? int.tryParse(tabMatch.group(1)!) : null;
  }

  static String _extractSchedule(String text) {
    final mealMatch = _mealPattern.firstMatch(text);
    final freqMatch = _frequencyPattern.firstMatch(text);
    if (mealMatch != null) return mealMatch.group(0)!;
    if (freqMatch != null) return freqMatch.group(0)!;
    return '';
  }

  static bool _isEnglishMedicalNoise(String word) {
    const noise = [
      'tablet',
      'capsule',
      'pill',
      'dose',
      'mg',
      'ml',
      'take',
      'once',
      'daily',
      'twice',
      'every',
      'before',
      'after',
      'meal',
      'food',
      'breakfast',
      'lunch',
      'dinner',
      'bedtime',
      'morning',
      'afternoon',
      'evening',
      'prescription',
      'pharmacy',
      'doctor',
      'patient',
      'name',
      'date',
      'warning',
      'allergy',
    ];
    return noise.any((n) => word.toLowerCase().contains(n));
  }
}
