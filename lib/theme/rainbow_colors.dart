import 'package:flutter/material.dart';

class RainbowColors {
  static const List<Color> colors = [
    Color(0xFFE53935), // Red - 第1次
    Color(0xFFFDD835), // Yellow - 第2次
    Color(0xFF1E88E5), // Blue - 第3次
    Color(0xFF43A047), // Green - 第4次
    Color(0xFFFB8C00), // Orange - 第5次
    Color(0xFF8E24AA), // Purple - 第6次
    Color(0xFF00ACC1), // Cyan - 第7次
  ];

  static const List<String> labels = ['红', '黄', '蓝', '绿', '橙', '紫', '青'];
  static const List<String> fullLabels = ['红色', '黄色', '蓝色', '绿色', '橙色', '紫色', '青色'];

  static Color grey = Colors.grey.shade300;
  static Color confirmed(int index) => colors[index % colors.length];
  static Color pending(int index) => colors[index % colors.length].withValues(alpha: 0.4);
  static Color missed = Colors.red.shade800;
}
