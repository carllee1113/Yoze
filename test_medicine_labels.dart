import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final testLabels = [
    {
      'name': 'PARACETAMOL',
      'form': 'TABLET',
      'dosage': '500MG',
      'freq': '每日四次',
      'qty': '112 TAB',
      'admin': '口服',
    },
    {
      'name': 'METFORMIN',
      'form': 'TABLET',
      'dosage': '850MG',
      'freq': '每日兩次',
      'qty': '60 TAB',
      'admin': '口服',
    },
    {
      'name': 'AMOXICILLIN',
      'form': 'CAPSULE',
      'dosage': '500MG',
      'freq': '每日三次',
      'qty': '30 CAP',
      'admin': '口服',
    },
    {
      'name': 'ATORVASTATIN',
      'form': 'TABLET',
      'dosage': '20MG',
      'freq': '每日一次',
      'qty': '28 TAB',
      'admin': '口服',
    },
    {
      'name': 'OMEPRAZOLE',
      'form': 'CAPSULE',
      'dosage': '20MG',
      'freq': '每日一次',
      'qty': '14 CAP',
      'admin': '口服',
    },
  ];

  for (int i = 0; i < testLabels.length; i++) {
    final label = testLabels[i];
    final image = img.Image(width: 800, height: 400, numChannels: 3);
    
    // White background
    img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));
    
    // Draw border
    img.drawRect(image, x1: 10, y1: 10, x2: 790, y2: 390, color: img.ColorRgba8(0, 100, 200, 255), thickness: 3);
    
    // Draw text lines - simulating medicine label
    int y = 60;
    img.drawString(image, '${label['name']} ${label['form']} ${label['dosage']}', font: img.arial48, x: 50, y: y, color: img.ColorRgba8(0, 0, 0, 255));
    y += 70;
    img.drawString(image, '服用方式: ${label['admin']}', font: img.arial24, x: 50, y: y, color: img.ColorRgba8(50, 50, 50, 255));
    y += 50;
    img.drawString(image, '頻率: ${label['freq']}', font: img.arial24, x: 50, y: y, color: img.ColorRgba8(50, 50, 50, 255));
    y += 50;
    img.drawString(image, '數量: ${label['qty']}', font: img.arial24, x: 50, y: y, color: img.ColorRgba8(50, 50, 50, 255));
    y += 50;
    img.drawString(image, 'HK-12345', font: img.arial24, x: 50, y: y, color: img.ColorRgba8(150, 150, 150, 255));

    final jpg = img.encodeJpg(image, quality: 85);
    final file = File('test_label_$i.jpg');
    await file.writeAsBytes(jpg);
    stdout.writeln('Created test_label_$i.jpg');
  }
  stdout.writeln('Done creating ${testLabels.length} test images');
}
