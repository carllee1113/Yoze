import 'dart:io';

class ScannedPhoto {
  final int? id;
  final String imagePath;
  final int extractedCount;
  final DateTime createdAt;

  ScannedPhoto({
    this.id,
    required this.imagePath,
    this.extractedCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'image_path': imagePath,
      'extracted_count': extractedCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ScannedPhoto.fromMap(Map<String, dynamic> map) {
    return ScannedPhoto(
      id: map['id'] as int?,
      imagePath: map['image_path'] as String,
      extractedCount: (map['extracted_count'] as int?) ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  File get imageFile => File(imagePath);
}