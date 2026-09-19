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

  Future<int> addMeasurement(PatientMeasurement measurement) async {
    if (measurement.weightKg != null && measurement.weightKg! <= 0) {
      throw ArgumentError('Weight must be greater than zero.');
    }
    if (measurement.heightCm != null && measurement.heightCm! <= 0) {
      throw ArgumentError('Height must be greater than zero.');
    }
    if (measurement.waistCm != null && measurement.waistCm! <= 0) {
      throw ArgumentError('Waist circumference must be greater than zero.');
    }

    final db = await database.database;
    return db.insert('patient_measurements', {
      'patient_id': measurement.patientId,
      'measured_at': measurement.measuredAt.toIso8601String(),
      'weight_kg': measurement.weightKg,
      'height_cm': measurement.heightCm,
      'waist_cm': measurement.waistCm,
      'notes': measurement.notes,
    });
  }

  Future<List<PatientMeasurement>> measurementsFor(
    int patientId, {
    int limit = 100,
  }) async {
    final db = await database.database;
    final rows = await db.query(
      'patient_measurements',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'measured_at DESC, id DESC',
      limit: limit,
    );

    return rows.map(_measurementFromMap).toList();
  }

  Future<PatientMeasurement?> latestMeasurement(int patientId) async {
    final measurements = await measurementsFor(patientId, limit: 1);
    return measurements.isEmpty ? null : measurements.first;
  }

  Future<void> deleteMeasurement(int measurementId) async {
    final db = await database.database;
    await db.delete(
      'patient_measurements',
      where: 'id = ?',
      whereArgs: [measurementId],
    );
  }

  static PatientMeasurement _measurementFromMap(
    Map<String, Object?> row,
  ) {
    return PatientMeasurement(
      id: row['id'] as int,
      patientId: row['patient_id'] as int,
      measuredAt: DateTime.parse(row['measured_at'] as String),
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      heightCm: (row['height_cm'] as num?)?.toDouble(),
      waistCm: (row['waist_cm'] as num?)?.toDouble(),
      notes: row['notes'] as String?,
    );
  }

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
