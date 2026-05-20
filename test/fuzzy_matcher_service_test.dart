import 'package:flutter_test/flutter_test.dart';
import 'package:yoze/services/fuzzy_matcher_service.dart';

void main() {
  test('extractPermitNumber returns HK permit value when present', () {
    const text = '服用方式 口服 HK-54321 每日兩次';
    expect(FuzzyMatcherService.extractPermitNumber(text), 'HK-54321');
  });

  test('extractPermitNumber normalizes HK permit without hyphen', () {
    const text = '服用方式 口服 HK 54321 每日兩次';
    expect(FuzzyMatcherService.extractPermitNumber(text), 'HK-54321');
  });

  test('extractPermitNumber returns empty string when absent', () {
    const text = '服用方式 口服 每日兩次';
    expect(FuzzyMatcherService.extractPermitNumber(text), isEmpty);
  });
}
