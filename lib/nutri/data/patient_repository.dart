import '../domain/patient.dart';
import 'nutri_database.dart';

class PatientRepository {
  final NutriDatabase database;

  PatientRepository({NutriDatabase? database})
      : database = database ?? NutriDatabase.instance;

  Future<int> create(Patient patient) => database.createPatient(patient);

  Future<Patient?> getById(int id) async {
    final db = await database.database;
    final rows = await db.query(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  Future<List<Patient>> search(
    String query, {
    bool activeOnly = true,
    int limit = 100,
  }) async {
    final db = await database.database;
    final trimmed = query.trim();

    final where = <String>[];
    final args = <Object?>[];

    if (activeOnly) {
      where.add('is_active = 1');
    }

    if (trimmed.isNotEmpty) {
      where.add(
        "(first_name LIKE ? OR last_name LIKE ? OR "
        "(first_name || ' ' || last_name) LIKE ?)",
      );
      final pattern = '%$trimmed%';
      args
        ..add(pattern)
        ..add(pattern)
        ..add(pattern);
    }

    final rows = await db.query(
      'patients',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'last_name COLLATE NOCASE, first_name COLLATE NOCASE',
      limit: limit,
    );

    return rows.map(_fromMap).toList();
  }

  Future<void> update(Patient patient) async {
    final id = patient.id;
    if (id == null) {
      throw ArgumentError('Patient must have an id before update.');
    }

    final db = await database.database;
    await db.update(
      'patients',
      {
        'first_name': patient.firstName,
        'last_name': patient.lastName,
        'date_of_birth': patient.dateOfBirth?.toIso8601String(),
        'sex': patient.sex,
        'email': patient.email,
        'phone': patient.phone,
        'notes': patient.notes,
        'is_active': patient.isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> archive(int patientId) async {
    final db = await database.database;
    await db.update(
      'patients',
      {
        'is_active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [patientId],
    );
  }

  Future<void> setTargets(
    int patientId,
    Iterable<NutritionTarget> targets,
  ) async {
    final db = await database.database;
    await db.transaction((txn) async {
      await txn.delete(
        'nutrition_targets',
        where: 'patient_id = ?',
        whereArgs: [patientId],
      );

      for (final target in targets) {
        await txn.insert(
          'nutrition_targets',
          {
            'patient_id': patientId,
            'nutrient_code': target.nutrientCode,
            'target_value': target.targetValue,
            'unit': target.unit.name,
            'minimum_value': target.minimumValue,
            'maximum_value': target.maximumValue,
          },
        );
      }
    });
  }

  Future<List<NutritionTarget>> targetsFor(int patientId) =>
      database.getNutritionTargets(patientId);

  static Patient _fromMap(Map<String, Object?> row) {
    return Patient(
      id: row['id'] as int,
      firstName: row['first_name'] as String,
      lastName: row['last_name'] as String,
      dateOfBirth: row['date_of_birth'] == null
          ? null
          : DateTime.parse(row['date_of_birth'] as String),
      sex: row['sex'] as String?,
      email: row['email'] as String?,
      phone: row['phone'] as String?,
      notes: row['notes'] as String?,
      isActive: (row['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
