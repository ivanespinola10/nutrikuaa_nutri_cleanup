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
        'consultation_reason': patient.consultationReason,
        'dietary_history': patient.dietaryHistory,
        'food_context': patient.foodContext,
        'reported_allergies': patient.reportedAllergies,
        'reported_intolerances': patient.reportedIntolerances,
        'clinical_context': patient.clinicalContext,
        'history_source': patient.historySource,
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

  Future<int> addEncounter(PatientEncounter encounter) async {
    final db = await database.database;
    final existing = await getById(encounter.patientId);
    if (existing == null) throw StateError('Patient no longer exists.');
    if (encounter.planId != null) {
      final plans = await db.query('meal_plans',
          columns: ['id'],
          where: 'id = ? AND patient_id = ?',
          whereArgs: [encounter.planId, encounter.patientId],
          limit: 1);
      if (plans.isEmpty) {
        throw ArgumentError('The linked plan must belong to this patient.');
      }
    }
    return db.insert('patient_encounters', {
      'patient_id': encounter.patientId,
      'occurred_at': encounter.occurredAt.toIso8601String(),
      'assessment': encounter.assessment,
      'nutrition_problem': encounter.nutritionProblem,
      'intervention': encounter.intervention,
      'monitoring': encounter.monitoring,
      'next_review_at': encounter.nextReviewAt?.toIso8601String(),
      'information_source': encounter.informationSource,
      'plan_id': encounter.planId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<PatientEncounter>> encountersFor(
    int patientId, {
    int limit = 100,
  }) async {
    final db = await database.database;
    final rows = await db.query(
      'patient_encounters',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'occurred_at DESC, id DESC',
      limit: limit,
    );
    return rows.map((row) => PatientEncounter(
      id: row['id'] as int,
      patientId: row['patient_id'] as int,
      occurredAt: DateTime.parse(row['occurred_at'] as String),
      assessment: row['assessment'] as String?,
      nutritionProblem: row['nutrition_problem'] as String?,
      intervention: row['intervention'] as String?,
      monitoring: row['monitoring'] as String?,
      nextReviewAt: row['next_review_at'] == null
          ? null
          : DateTime.parse(row['next_review_at'] as String),
      informationSource: row['information_source'] as String?,
      planId: row['plan_id'] as int?,
    )).toList();
  }

  Future<int> addObservation(PatientObservation observation) async {
    if (observation.indicator.trim().isEmpty ||
        observation.unit.trim().isEmpty ||
        observation.source.trim().isEmpty ||
        !observation.value.isFinite) {
      throw ArgumentError('Indicator, finite value, unit and source are required.');
    }
    final db = await database.database;
    return db.insert('patient_observations', {
      'patient_id': observation.patientId,
      'observed_at': observation.observedAt.toIso8601String(),
      'indicator': observation.indicator.trim(),
      'value': observation.value,
      'unit': observation.unit.trim(),
      'source': observation.source.trim(),
      'reference_range': observation.referenceRange?.trim(),
    });
  }

  Future<List<PatientObservation>> observationsFor(
    int patientId, {
    int limit = 100,
  }) async {
    final db = await database.database;
    final rows = await db.query(
      'patient_observations',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'observed_at DESC, id DESC',
      limit: limit,
    );
    return rows.map((row) => PatientObservation(
      id: row['id'] as int,
      patientId: row['patient_id'] as int,
      observedAt: DateTime.parse(row['observed_at'] as String),
      indicator: row['indicator'] as String,
      value: (row['value'] as num).toDouble(),
      unit: row['unit'] as String,
      source: row['source'] as String,
      referenceRange: row['reference_range'] as String?,
    )).toList();
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
      consultationReason: row['consultation_reason'] as String?,
      dietaryHistory: row['dietary_history'] as String?,
      foodContext: row['food_context'] as String?,
      reportedAllergies: row['reported_allergies'] as String?,
      reportedIntolerances: row['reported_intolerances'] as String?,
      clinicalContext: row['clinical_context'] as String?,
      historySource: row['history_source'] as String?,
      isActive: (row['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
