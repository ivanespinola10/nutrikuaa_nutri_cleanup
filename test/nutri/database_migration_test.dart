import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nutrikuaa_app/nutri/data/nutri_database.dart';

void main() {
  late String databasePath;
  late NutriDatabase migrationDatabase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final root = await databaseFactoryFfi.getDatabasesPath();
    databasePath = p.join(root, 'nutrikuaa_nutri_migration_test.db');
    await databaseFactoryFfi.deleteDatabase(databasePath);
    migrationDatabase = NutriDatabase.forTesting(databasePath);
  });

  tearDown(() async {
    await migrationDatabase.close();
    await databaseFactoryFfi.deleteDatabase(databasePath);
  });

  Future<Database> createLegacyDatabase({
    required int version,
    bool includeAllergensColumn = false,
    Set<String> extraPatientColumns = const {},
    bool includeEncountersTable = false,
    bool includeObservationsTable = false,
  }) {
    return databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE foods (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              brand TEXT,
              country_code TEXT,
              source_type TEXT NOT NULL,
              source_name TEXT,
              source_food_id TEXT,
              source_release TEXT,
              serving_quantity REAL,
              serving_unit TEXT,
              household_measure TEXT,
              notes TEXT,
              ${includeAllergensColumn ? 'allergens_json TEXT,' : ''}
              is_archived INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          final extraPatientSql = extraPatientColumns
              .map((column) => '$column TEXT,')
              .join('\n');

          await db.execute('''
            CREATE TABLE patients (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              first_name TEXT NOT NULL,
              last_name TEXT NOT NULL DEFAULT '',
              date_of_birth TEXT,
              sex TEXT,
              email TEXT,
              phone TEXT,
              notes TEXT,
              $extraPatientSql
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE meal_plans (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              patient_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              start_date TEXT,
              end_date TEXT,
              notes TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          if (includeEncountersTable) {
            await db.execute('''
              CREATE TABLE patient_encounters (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                patient_id INTEGER NOT NULL,
                occurred_at TEXT NOT NULL,
                assessment TEXT,
                nutrition_problem TEXT,
                intervention TEXT,
                monitoring TEXT,
                next_review_at TEXT,
                information_source TEXT,
                plan_id INTEGER,
                created_at TEXT NOT NULL
              )
            ''');
            await db.execute(
              'CREATE INDEX idx_patient_encounters_patient_date '
              'ON patient_encounters(patient_id, occurred_at DESC)',
            );
          }

          if (includeObservationsTable) {
            await db.execute('''
              CREATE TABLE patient_observations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                patient_id INTEGER NOT NULL,
                observed_at TEXT NOT NULL,
                indicator TEXT NOT NULL,
                value REAL NOT NULL,
                unit TEXT NOT NULL,
                source TEXT NOT NULL,
                reference_range TEXT
              )
            ''');
          }

          final now = DateTime(2026, 10, 25).toIso8601String();

          await db.insert('foods', {
            'name': 'Alimento legado',
            'source_type': 'professionalCustom',
            if (includeAllergensColumn) 'allergens_json': '["milk"]',
            'created_at': now,
            'updated_at': now,
          });

          await db.insert('patients', {
            'first_name': 'Paciente',
            'last_name': 'Legado',
            if (extraPatientColumns.contains('consultation_reason'))
              'consultation_reason': 'Consulta previa',
            if (extraPatientColumns.contains('dietary_history'))
              'dietary_history': 'Historia preservada',
            'created_at': now,
            'updated_at': now,
          });
        },
      ),
    );
  }

  Future<Set<String>> columns(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows
        .map((row) => row['name']?.toString())
        .whereType<String>()
        .toSet();
  }

  Future<bool> objectExists(
    Database db, {
    required String type,
    required String name,
  }) async {
    final rows = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ? AND name = ?',
      whereArgs: [type, name],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  const expectedPatientColumns = <String>{
    'consultation_reason',
    'dietary_history',
    'food_context',
    'reported_allergies',
    'reported_intolerances',
    'clinical_context',
    'history_source',
  };

  test('v8 -> v10 preserves data and adds all new schema elements', () async {
    final legacy = await createLegacyDatabase(version: 8);
    await legacy.close();

    final upgraded = await migrationDatabase.database;

    expect(
      Sqflite.firstIntValue(await upgraded.rawQuery('PRAGMA user_version')),
      NutriDatabase.databaseVersion,
    );

    final foodColumns = await columns(upgraded, 'foods');
    expect(foodColumns, contains('allergens_json'));

    final patientColumns = await columns(upgraded, 'patients');
    expect(patientColumns, containsAll(expectedPatientColumns));

    expect(
      await objectExists(upgraded, type: 'table', name: 'patient_encounters'),
      isTrue,
    );
    expect(
      await objectExists(upgraded, type: 'table', name: 'patient_observations'),
      isTrue,
    );

    final food = (await upgraded.query('foods')).single;
    final patient = (await upgraded.query('patients')).single;

    expect(food['name'], 'Alimento legado');
    expect(patient['first_name'], 'Paciente');
    expect(patient['last_name'], 'Legado');
  });

  test('v9 -> v10 preserves allergens and patient data', () async {
    final legacy = await createLegacyDatabase(
      version: 9,
      includeAllergensColumn: true,
    );
    await legacy.close();

    final upgraded = await migrationDatabase.database;

    final foodColumns = await columns(upgraded, 'foods');
    expect(foodColumns.where((name) => name == 'allergens_json'), hasLength(1));

    final food = (await upgraded.query('foods')).single;
    expect(food['allergens_json'], '["milk"]');

    final patientColumns = await columns(upgraded, 'patients');
    expect(patientColumns, containsAll(expectedPatientColumns));

    final patient = (await upgraded.query('patients')).single;
    expect(patient['first_name'], 'Paciente');
    expect(patient['last_name'], 'Legado');
  });

  test(
    'partial v9 migration does not fail if allergens_json already exists',
    () async {
      final legacy = await createLegacyDatabase(
        version: 8,
        includeAllergensColumn: true,
      );
      await legacy.close();

      final upgraded = await migrationDatabase.database;

      final foodColumns = await columns(upgraded, 'foods');
      expect(
        foodColumns.where((name) => name == 'allergens_json'),
        hasLength(1),
      );
      expect((await upgraded.query('foods')), hasLength(1));
    },
  );

  test(
    'partial v10 migration resumes without duplicating columns or tables',
    () async {
      final legacy = await createLegacyDatabase(
        version: 9,
        includeAllergensColumn: true,
        extraPatientColumns: const {'consultation_reason', 'dietary_history'},
        includeEncountersTable: true,
        includeObservationsTable: true,
      );
      await legacy.close();

      final upgraded = await migrationDatabase.database;

      final patientColumns = await columns(upgraded, 'patients');

      for (final column in expectedPatientColumns) {
        expect(
          patientColumns.where((name) => name == column),
          hasLength(1),
          reason: 'La columna $column debe existir una sola vez.',
        );
      }

      final patient = (await upgraded.query('patients')).single;
      expect(patient['consultation_reason'], 'Consulta previa');
      expect(patient['dietary_history'], 'Historia preservada');

      expect(
        await objectExists(upgraded, type: 'table', name: 'patient_encounters'),
        isTrue,
      );
      expect(
        await objectExists(
          upgraded,
          type: 'table',
          name: 'patient_observations',
        ),
        isTrue,
      );
      expect(
        await objectExists(
          upgraded,
          type: 'index',
          name: 'idx_patient_encounters_patient_date',
        ),
        isTrue,
      );
      expect(
        await objectExists(
          upgraded,
          type: 'index',
          name: 'idx_patient_observations_patient_date',
        ),
        isTrue,
      );

      expect(
        Sqflite.firstIntValue(await upgraded.rawQuery('PRAGMA user_version')),
        NutriDatabase.databaseVersion,
      );
    },
  );
}
