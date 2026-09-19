import 'package:sqflite/sqflite.dart';

import '../domain/app_settings.dart';
import 'nutri_database.dart';

class AppSettingsRepository {
  final NutriDatabase database;

  AppSettingsRepository({NutriDatabase? database})
      : database = database ?? NutriDatabase.instance;

  Future<AppSettings> load() async {
    final db = await database.database;
    final rows = await db.query(
      'app_settings',
      where: 'id = 1',
      limit: 1,
    );

    if (rows.isEmpty) {
      return const AppSettings();
    }

    final row = rows.first;
    final unitName = row['unit_system'] as String? ?? UnitSystem.metric.name;

    return AppSettings(
      languageCode: row['language_code'] as String? ?? 'es',
      countryCode: row['country_code'] as String? ?? 'PY',
      unitSystem: UnitSystem.values.firstWhere(
        (value) => value.name == unitName,
        orElse: () => UnitSystem.metric,
      ),
    );
  }

  Future<void> save(AppSettings settings) async {
    final db = await database.database;
    await db.insert(
      'app_settings',
      {
        'id': 1,
        'language_code': settings.languageCode.trim().toLowerCase(),
        'country_code': settings.countryCode.trim().toUpperCase(),
        'unit_system': settings.unitSystem.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
