import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/medication.dart';
import '../models/dose_record.dart';

class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'yoze.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Migration from version 1 to version 2 - add new columns
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE medications ADD COLUMN form TEXT DEFAULT \'\' ',
      );
      await db.execute(
        'ALTER TABLE medications ADD COLUMN dosagePerUnit TEXT DEFAULT \'\' ',
      );
      await db.execute(
        'ALTER TABLE medications ADD COLUMN administration TEXT DEFAULT \'\' ',
      );
      await db.execute(
        'ALTER TABLE medications ADD COLUMN dosePerTime TEXT DEFAULT \'\' ',
      );
      await db.execute(
        'ALTER TABLE medications ADD COLUMN durationDays INTEGER',
      );
      await db.execute(
        'ALTER TABLE medications ADD COLUMN totalQuantity INTEGER',
      );
      await db.execute(
        'ALTER TABLE medications ADD COLUMN permitNo TEXT DEFAULT \'\' ',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE medications ADD COLUMN isArchived INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE medications ADD COLUMN archivedAt TEXT');
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE medications ADD COLUMN medicineCode INTEGER DEFAULT 0',
      );
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        form TEXT DEFAULT '',
        dosagePerUnit TEXT DEFAULT '',
        administration TEXT DEFAULT '',
        dosePerTime TEXT DEFAULT '',
        durationDays INTEGER,
        totalQuantity INTEGER,
        permitNo TEXT DEFAULT '',
        dosage TEXT DEFAULT '',
        notes TEXT DEFAULT '',
        medicineCode INTEGER DEFAULT 0,
        colorIndex INTEGER NOT NULL,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        isEnabled INTEGER DEFAULT 1,
        isArchived INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL,
        archivedAt TEXT,
        sourcePhotoPath TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE dose_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicationId INTEGER NOT NULL,
        date TEXT NOT NULL,
        doseIndex INTEGER NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        confirmedAt TEXT,
        notifiedAt TEXT,
        FOREIGN KEY (medicationId) REFERENCES medications(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_dose_date ON dose_records(date)');
    await db.execute('''
      CREATE TABLE scanned_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        extracted_count INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // --- Medications ---

  static Future<int> insertMedication(Medication med) async {
    final db = await database;
    final id = await db.insert('medications', med.toMap());
    return id;
  }

  static Future<List<Medication>> getAllMedications() async {
    final db = await database;
    await ensureMedicineCodes();
    final maps = await db.query('medications', orderBy: 'hour ASC, minute ASC');
    return maps.map((m) => Medication.fromMap(m)).toList();
  }

  static Future<List<Medication>> getActiveMedications({
    String orderBy = 'hour ASC, minute ASC',
  }) async {
    final db = await database;
    await ensureMedicineCodes();
    final maps = await db.query(
      'medications',
      where: 'isEnabled = ? AND isArchived = ?',
      whereArgs: [1, 0],
      orderBy: orderBy,
    );
    return maps.map((m) => Medication.fromMap(m)).toList();
  }

  static Future<List<Medication>> getArchivedMedications() async {
    final db = await database;
    await ensureMedicineCodes();
    final maps = await db.query(
      'medications',
      where: 'isArchived = ?',
      whereArgs: [1],
      orderBy: 'archivedAt DESC, createdAt DESC',
    );
    return maps.map((m) => Medication.fromMap(m)).toList();
  }

  static Future<Medication?> getMedication(int id) async {
    final db = await database;
    await ensureMedicineCodes();
    final maps = await db.query(
      'medications',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Medication.fromMap(maps.first);
  }

  static Future<int> updateMedication(Medication med) async {
    final db = await database;
    return db.update(
      'medications',
      med.toMap(),
      where: 'id = ?',
      whereArgs: [med.id],
    );
  }

  static Future<int> deleteMedication(int id) async {
    final db = await database;
    await db.delete('dose_records', where: 'medicationId = ?', whereArgs: [id]);
    return db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> archiveMedication(int id) async {
    final db = await database;
    return db.update(
      'medications',
      {
        'isEnabled': 0,
        'isArchived': 1,
        'archivedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> getNextMedicineCode() async {
    final db = await database;
    await ensureMedicineCodes();
    final result = await db.rawQuery(
      'SELECT MAX(medicineCode) as maxCode FROM medications',
    );
    final maxCode = (result.first['maxCode'] as int?) ?? 0;
    return maxCode + 1;
  }

  static Future<void> ensureMedicineCodes() async {
    final db = _database;
    if (db == null) return;

    final rows = await db.query(
      'medications',
      where: 'medicineCode IS NULL OR medicineCode = ?',
      whereArgs: [0],
      orderBy: 'createdAt ASC, id ASC',
    );
    if (rows.isEmpty) return;

    final maxResult = await db.rawQuery(
      'SELECT MAX(medicineCode) as maxCode FROM medications',
    );
    var nextCode = ((maxResult.first['maxCode'] as int?) ?? 0) + 1;
    final assignedKeys = <String, int>{};

    for (final row in rows) {
      final id = row['id'] as int?;
      if (id == null) continue;
      final key = _medicineCodeGroupKey(row);
      final code = assignedKeys.putIfAbsent(key, () => nextCode++);
      await db.update(
        'medications',
        {'medicineCode': code},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  static String _medicineCodeGroupKey(Map<String, Object?> row) {
    String value(String key) =>
        ((row[key] as String?) ?? '').trim().toLowerCase();
    return [
      value('name'),
      value('form'),
      value('dosagePerUnit'),
      value('administration'),
      value('dosePerTime'),
      value('permitNo'),
      row['isArchived'] ?? 0,
    ].join('|');
  }

  // --- Dose Records ---

  static Future<int> insertDoseRecord(DoseRecord record) async {
    final db = await database;
    return db.insert('dose_records', record.toMap());
  }

  static Future<List<DoseRecord>> getDoseRecordsForDate(String date) async {
    final db = await database;
    final maps = await db.query(
      'dose_records',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'doseIndex ASC',
    );
    return maps.map((m) => DoseRecord.fromMap(m)).toList();
  }

  static Future<DoseRecord?> getDoseRecord(
    int medicationId,
    String date,
    int doseIndex,
  ) async {
    final db = await database;
    final maps = await db.query(
      'dose_records',
      where: 'medicationId = ? AND date = ? AND doseIndex = ?',
      whereArgs: [medicationId, date, doseIndex],
    );
    if (maps.isEmpty) return null;
    return DoseRecord.fromMap(maps.first);
  }

  static Future<int> updateDoseRecord(DoseRecord record) async {
    final db = await database;
    return db.update(
      'dose_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  static Future<int> confirmDose(
    int medicationId,
    String date,
    int doseIndex,
  ) async {
    final db = await database;
    final existing = await getDoseRecord(medicationId, date, doseIndex);
    final now = DateTime.now().toIso8601String();
    if (existing != null) {
      return db.update(
        'dose_records',
        {'status': DoseStatus.confirmed.index, 'confirmedAt': now},
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      return db.insert('dose_records', {
        'medicationId': medicationId,
        'date': date,
        'doseIndex': doseIndex,
        'status': DoseStatus.confirmed.index,
        'confirmedAt': now,
        'notifiedAt': null,
      });
    }
  }

  static Future<int> markMissed(
    int medicationId,
    String date,
    int doseIndex,
  ) async {
    final db = await database;
    final existing = await getDoseRecord(medicationId, date, doseIndex);
    if (existing != null && existing.status == DoseStatus.pending) {
      return db.update(
        'dose_records',
        {'status': DoseStatus.missed.index},
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    }
    return 0;
  }

  static Future<int> setDoseStatus({
    required int medicationId,
    required String date,
    required int doseIndex,
    required DoseStatus status,
  }) async {
    final db = await database;
    final existing = await getDoseRecord(medicationId, date, doseIndex);
    final confirmedAt = status == DoseStatus.confirmed
        ? DateTime.now().toIso8601String()
        : null;

    if (existing != null) {
      return db.update(
        'dose_records',
        {'status': status.index, 'confirmedAt': confirmedAt},
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    }

    return db.insert('dose_records', {
      'medicationId': medicationId,
      'date': date,
      'doseIndex': doseIndex,
      'status': status.index,
      'confirmedAt': confirmedAt,
      'notifiedAt': null,
    });
  }

  static Future<List<Map<String, dynamic>>> getTodaySummary(String date) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT m.id, m.name, m.dosage, m.colorIndex, m.hour, m.minute,
             COALESCE(d.status, 0) as doseStatus, d.confirmedAt
      FROM medications m
      LEFT JOIN dose_records d ON m.id = d.medicationId AND d.date = ? AND d.doseIndex = 0
      WHERE m.isEnabled = 1 AND m.isArchived = 0
      ORDER BY m.hour ASC, m.minute ASC
    ''',
      [date],
    );
    return result;
  }

  static Future<Map<int, Map<String, dynamic>>> getTodayDoseStatusMap(
    String date,
  ) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT medicationId, status, confirmedAt
      FROM dose_records
      WHERE date = ? AND doseIndex = 0
    ''',
      [date],
    );
    final map = <int, Map<String, dynamic>>{};
    for (final row in rows) {
      map[row['medicationId'] as int] = row;
    }
    return map;
  }
}
