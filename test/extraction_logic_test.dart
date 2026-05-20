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

  test('parseTextBlocks extracts Drug colon lozenge label from OCR text', () {
    const text =
        'EZ Name: OTC EZ Drug: Dequalinium (Dexxon) 0.25mg lozenges HK-47064 '
        'eOuantity: 20 Lozenges Dispensing Date: 21/12/2022 '
        'Suck one lozenge in mouth three times a day when necessary';
    final meds = ExtractionLogic.parseTextBlocks(const [], text);

    expect(meds, isNotEmpty);
    expect(meds.first.drugName, 'DEQUALINIUM');
    expect(meds.first.form, 'LOZENGE');
    expect(meds.first.dosagePerUnit, '0.25MG');
    expect(meds.first.frequency, 3);
    expect(meds.first.dosePerTime, startsWith('1 '));
    expect(meds.first.totalQuantity, 20);
    expect(meds.first.permitNo, 'HK-47064');
  });

  test('parseTextBlocks normalizes OCR dosage typo in tablet label', () {
    const text =
        '+ PARACETAMOL TABLET 50OMG PARAO1 HN25006407 13/03/2025 '
        '0957 01 SUJR BBA 42 D 112 TAB 3C52';
    final meds = ExtractionLogic.parseTextBlocks(const [], text);

    expect(meds, isNotEmpty);
    expect(meds.first.drugName, 'PARACETAMOL');
    expect(meds.first.form, 'TABLET');
    expect(meds.first.dosagePerUnit, '500MG');
    expect(meds.first.totalQuantity, 112);
  });

  test('parseTextBlocks returns empty when no recognizable medication data', () {
    const text = '今天下午三點去散步，天氣很好。';
    final meds = ExtractionLogic.parseTextBlocks(const [], text);
    expect(meds, isEmpty);
  });
}
