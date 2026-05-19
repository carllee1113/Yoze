import 'package:flutter_test/flutter_test.dart';
import 'package:yoze/services/extraction_logic.dart';

void main() {
  test('parseTextBlocks extracts drug form dosage and frequency', () {
    const text = 'PARACETAMOL TABLET 500MG 口服 每日四次 112 TAB HK-12345';
    final meds = ExtractionLogic.parseTextBlocks(const [], text);

    expect(meds, isNotEmpty);
    expect(meds.first.drugName, 'PARACETAMOL');
    expect(meds.first.form, 'TABLET');
    expect(meds.first.dosagePerUnit, '500MG');
    expect(meds.first.frequency, 4);
    expect(meds.first.permitNo, 'HK-12345');
  });

  test('parseTextBlocks returns empty when no recognizable medication data', () {
    const text = '今天下午三點去散步，天氣很好。';
    final meds = ExtractionLogic.parseTextBlocks(const [], text);
    expect(meds, isEmpty);
  });
}
