import 'dart:convert';
import 'package:flutter/services.dart';

class MedicineReferenceEntry {
  final String name;
  final String permitNo;
  final List<String> activeIngredients;
  final String form;
  final String dosage;
  final String regCertHolder;

  MedicineReferenceEntry({
    required this.name,
    required this.permitNo,
    required this.activeIngredients,
    required this.form,
    required this.dosage,
    required this.regCertHolder,
  });

  factory MedicineReferenceEntry.fromJson(Map<String, dynamic> json) {
    return MedicineReferenceEntry(
      name: json['name'] as String? ?? '',
      permitNo: json['permitNo'] as String? ?? '',
      activeIngredients: (json['activeIngredients'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      form: json['form'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      regCertHolder: json['regCertHolder'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'permitNo': permitNo,
        'activeIngredients': activeIngredients,
        'form': form,
        'dosage': dosage,
        'regCertHolder': regCertHolder,
      };
}

class MatchResult {
  final MedicineReferenceEntry? match;
  final double confidence;
  final String matchedName;
  final String? matchedPermitNo;

  MatchResult({
    this.match,
    required this.confidence,
    required this.matchedName,
    this.matchedPermitNo,
  });

  bool get isValid => confidence >= 0.5;
}

class FuzzyMatcherService {
  static List<MedicineReferenceEntry>? _cache;
  static bool _isLoaded = false;

  static List<MedicineReferenceEntry> get _referenceList {
    if (_cache == null) {
      _loadReference();
    }
    return _cache ?? [];
  }

  static Future<void> loadReference() async {
    if (_isLoaded && _cache != null) return;

    try {
      final jsonString =
          await rootBundle.loadString('assets/medicine_reference.json');
      final List<dynamic> decoded = json.decode(jsonString);
      _cache = decoded.map((e) => MedicineReferenceEntry.fromJson(e)).toList();
      _isLoaded = true;
    } catch (e) {
      _cache = [];
      _isLoaded = true;
    }
  }

  static void _loadReference() {
    // Synchronous version - called only if loadReference wasn't called
    // For async loading, call loadReference() first
  }

  /// Find best match for a drug name using fuzzy matching
  static Future<MatchResult> findBestMatch(String input) async {
    await loadReference();

    if (input.isEmpty || _referenceList.isEmpty) {
      return MatchResult(confidence: 0, matchedName: input);
    }

    final normalizedInput = _normalizeString(input);
    double bestScore = 0;
    MedicineReferenceEntry? bestMatch;

    // First try exact permit number match (most reliable)
    final inputPermit = extractPermitNumber(input);
    if (inputPermit.isNotEmpty) {
      for (final entry in _referenceList) {
        if (entry.permitNo == inputPermit) {
          return MatchResult(
            match: entry,
            confidence: 1.0,
            matchedName: entry.name,
            matchedPermitNo: entry.permitNo,
          );
        }
      }
    }

    // Fuzzy match against drug names
    for (final entry in _referenceList) {
      final score = _calculateSimilarity(normalizedInput, entry.name);

      if (score > bestScore) {
        bestScore = score;
        bestMatch = entry;
      }
    }

    // If no good match, try matching against active ingredients
    if (bestScore < 0.5) {
      final ingredientMatch = _searchByActiveIngredients(normalizedInput);
      if (ingredientMatch != null) {
        return ingredientMatch;
      }
    }

    return MatchResult(
      match: bestScore >= 0.5 ? bestMatch : null,
      confidence: bestScore,
      matchedName: bestMatch?.name ?? input,
      matchedPermitNo: bestMatch?.permitNo,
    );
  }

  /// Search by active ingredient
  static MatchResult? _searchByActiveIngredients(String input) {
    double bestScore = 0;
    MedicineReferenceEntry? bestMatch;

    for (final entry in _referenceList) {
      for (final ingredient in entry.activeIngredients) {
        final score = _calculateSimilarity(input, ingredient.toLowerCase());
        if (score > bestScore) {
          bestScore = score;
          bestMatch = entry;
        }
      }
    }

    if (bestScore >= 0.5 && bestMatch != null) {
      return MatchResult(
        match: bestMatch,
        confidence: bestScore,
        matchedName: bestMatch.name,
        matchedPermitNo: bestMatch.permitNo,
      );
    }
    return null;
  }

  /// Extract HK-XXXXX permit number from text
  static String extractPermitNumber(String text) {
    final pattern = RegExp(r'HK[-\s]?(\d{5})', caseSensitive: false);
    final match = pattern.firstMatch(text);
    if (match == null) return '';
    final digits = match.group(1);
    if (digits == null || digits.length != 5) return '';
    return 'HK-$digits';
  }

  static Future<MedicineReferenceEntry?> findByPermitNo(String permitNo) async {
    await loadReference();
    if (permitNo.isEmpty || _referenceList.isEmpty) return null;
    for (final entry in _referenceList) {
      if (entry.permitNo.toUpperCase() == permitNo.toUpperCase()) {
        return entry;
      }
    }
    return null;
  }

  /// Normalize string for comparison
  static String _normalizeString(String s) {
    return s
        .toUpperCase()
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Calculate similarity between two strings using Levenshtein distance
  static double _calculateSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0;
    if (s1 == s2) return 1.0;

    final distance = _levenshteinDistance(s1, s2);
    final maxLen = s1.length > s2.length ? s1.length : s2.length;
    return 1 - (distance / maxLen);
  }

  /// Calculate Levenshtein distance
  static int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    // Use only 2 rows instead of full matrix for memory efficiency
    List<int> prev = List<int>.generate(len2 + 1, (i) => i);
    List<int> curr = List<int>.filled(len2 + 1, 0);

    for (int i = 1; i <= len1; i++) {
      curr[0] = i;
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        curr[j] = min(
          min(
            prev[j] + 1, // deletion
            curr[j - 1] + 1, // insertion
          ),
          prev[j - 1] + cost, // substitution
        );
      }
      // Swap prev and curr
      final List<int> temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[len2];
  }

  static int min(int a, int b) => a < b ? a : b;
}
