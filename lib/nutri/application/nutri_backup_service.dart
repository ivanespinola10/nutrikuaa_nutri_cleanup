import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../data/nutri_database.dart';

class BackupResult {
  final int patientCount;
  final int planCount;
  final int recipeCount;
  final int foodCount;

  const BackupResult({
    required this.patientCount,
    required this.planCount,
    required this.recipeCount,
    required this.foodCount,
  });
}

class NutriBackupService {
  static const format = 'nutrikuaa-nutri-backup';
  static const backupVersion = 1;

  static const _tables = <String>[
    'foods',
    'food_nutrients',
    'food_portions',
    'patients',
    'patient_measurements',
    'nutrition_targets',
    'recipes',
    'recipe_items',
    'meal_plans',
    'meals',
    'meal_items',
    'professional_profile',
    'app_settings',
  ];

  static const _deleteOrder = <String>[
    'meal_items',
    'meals',
    'meal_plans',
    'recipe_items',
    'recipes',
    'nutrition_targets',
    'patient_measurements',
    'patients',
    'food_portions',
    'food_nutrients',
    'foods',
    'professional_profile',
    'app_settings',
  ];

  static const _insertOrder = <String>[
    'foods',
    'food_nutrients',
    'food_portions',
    'patients',
    'patient_measurements',
    'nutrition_targets',
    'recipes',
    'recipe_items',
    'meal_plans',
    'meals',
    'meal_items',
    'professional_profile',
    'app_settings',
  ];

  final NutriDatabase database;

  NutriBackupService({NutriDatabase? database})
      : database = database ?? NutriDatabase.instance;

  Future<Uint8List> exportBackup() async {
    final db = await database.database;
    final tables = <String, Object?>{};

    for (final table in _tables) {
      final rows = await db.query(table);
      tables[table] = rows.map(_encodeRow).toList();
    }

    final payload = <String, Object?>{
      'format': format,
      'backup_version': backupVersion,
      'database_version': NutriDatabase.databaseVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    };

    return Uint8List.fromList(
      utf8.encode(jsonEncode(payload)),
    );
  }

  Future<BackupResult> inspect(Uint8List bytes) async {
    final payload = _decodePayload(bytes);
    final tables = _tablesMap(payload);

    return BackupResult(
      patientCount: _rows(tables, 'patients').length,
      planCount: _rows(tables, 'meal_plans').length,
      recipeCount: _rows(tables, 'recipes').length,
      foodCount: _rows(tables, 'foods').length,
    );
  }

  Future<BackupResult> restoreBackup(Uint8List bytes) async {
    final payload = _decodePayload(bytes);
    final tables = _tablesMap(payload);

    final schemaVersion = payload['database_version'];
    if (schemaVersion is num &&
        schemaVersion.toInt() > NutriDatabase.databaseVersion) {
      throw StateError(
        'This backup was created by a newer Nutrikuaa version.',
      );
    }

    final db = await database.database;

    await db.transaction((txn) async {
      for (final table in _deleteOrder) {
        await txn.delete(table);
      }

      for (final table in _insertOrder) {
        final rows = _rows(tables, table);
        for (final row in rows) {
          await txn.insert(
            table,
            _decodeRow(row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    return BackupResult(
      patientCount: _rows(tables, 'patients').length,
      planCount: _rows(tables, 'meal_plans').length,
      recipeCount: _rows(tables, 'recipes').length,
      foodCount: _rows(tables, 'foods').length,
    );
  }

  Map<String, Object?> _decodePayload(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('Backup file is empty.');
    }

    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Invalid Nutrikuaa backup.');
    }

    final payload = Map<String, Object?>.from(decoded);
    if (payload['format'] != format) {
      throw const FormatException('This is not a Nutrikuaa Nutri backup.');
    }

    final version = payload['backup_version'];
    if (version is! num || version.toInt() > backupVersion) {
      throw const FormatException('Unsupported backup version.');
    }

    return payload;
  }

  Map<String, Object?> _tablesMap(Map<String, Object?> payload) {
    final value = payload['tables'];
    if (value is! Map) {
      throw const FormatException('Backup tables are missing.');
    }
    return Map<String, Object?>.from(value);
  }

  List<Object?> _rows(
    Map<String, Object?> tables,
    String table,
  ) {
    final value = tables[table];
    if (value == null) return const [];
    if (value is! List) {
      throw FormatException('Invalid table data: $table');
    }
    return List<Object?>.from(value);
  }

  Map<String, Object?> _encodeRow(Map<String, Object?> row) {
    return {
      for (final entry in row.entries)
        entry.key: _encodeValue(entry.value),
    };
  }

  Object? _encodeValue(Object? value) {
    if (value is Uint8List) {
      return <String, Object?>{
        '__nutrikuaa_type': 'bytes',
        'base64': base64Encode(value),
      };
    }
    return value;
  }

  Map<String, Object?> _decodeRow(Object? rawRow) {
    if (rawRow is! Map) {
      throw const FormatException('Invalid backup row.');
    }

    final row = Map<String, Object?>.from(rawRow);
    return {
      for (final entry in row.entries)
        entry.key: _decodeValue(entry.value),
    };
  }

  Object? _decodeValue(Object? value) {
    if (value is Map) {
      final map = Map<String, Object?>.from(value);
      if (map['__nutrikuaa_type'] == 'bytes') {
        final encoded = map['base64'];
        if (encoded is! String) {
          throw const FormatException('Invalid binary backup value.');
        }
        return Uint8List.fromList(base64Decode(encoded));
      }
    }
    return value;
  }
}
