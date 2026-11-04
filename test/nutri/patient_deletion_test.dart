import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/utils/utils.dart' show firstIntValue;

import 'package:nutrikuaa_app/nutri/application/food_library_service.dart';
import 'package:nutrikuaa_app/nutri/application/meal_plan_service.dart';
import 'package:nutrikuaa_app/nutri/data/nutri_database.dart';
import 'package:nutrikuaa_app/nutri/data/patient_repository.dart';
import 'package:nutrikuaa_app/nutri/domain/meal_plan.dart';
import 'package:nutrikuaa_app/nutri/domain/nutrition/nutrient.dart';
import 'package:nutrikuaa_app/nutri/domain/patient.dart';

void main() {
  late String dbPath;
  late NutriDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dir = await databaseFactoryFfi.getDatabasesPath();
    dbPath = p.join(dir, 'nutrikuaa_patient_delete_test.db');
    await databaseFactoryFfi.deleteDatabase(dbPath);
    database = NutriDatabase.forTesting(dbPath);
    await database.database;
  });

  tearDown(() async {
    await database.close();
    await databaseFactoryFfi.deleteDatabase(dbPath);
  });

  test('definitive patient deletion cascades clinical and plan data', () async {
    final patients = PatientRepository(database: database);
    final plans = MealPlanService(database: database);
    final foods = FoodLibraryService(database: database);

    final patientId = await patients.create(
      Patient(firstName: 'Paciente', lastName: 'Eliminar'),
    );

    await patients.setTargets(patientId, [
      NutritionTarget(
        patientId: patientId,
        nutrientCode: NutrientCodes.energyKcal,
        targetValue: 2000,
        unit: NutrientUnit.kilocalorie,
      ),
    ]);

    await patients.addMeasurement(
      PatientMeasurement(
        patientId: patientId,
        measuredAt: DateTime(2026, 11, 3),
        weightKg: 70,
      ),
    );

    await patients.addObservation(
      PatientObservation(
        patientId: patientId,
        observedAt: DateTime(2026, 11, 3),
        indicator: 'Glucosa',
        value: 90,
        unit: 'mg/dL',
        source: 'Laboratorio',
      ),
    );

    final planId = await plans.createPlan(
      MealPlan(patientId: patientId, name: 'Semana test'),
    );
    final mealId = await plans.addMeal(
      planId: planId,
      dayIndex: 0,
      name: 'Almuerzo',
      sortOrder: 0,
    );

    final foodId = await foods.addProfessionalFood(
      name: 'Arroz test',
      sourceName: 'Test',
      nutrients: const [
        NutrientValue(
          code: NutrientCodes.energyKcal,
          valuePer100g: 130,
          unit: NutrientUnit.kilocalorie,
        ),
        NutrientValue(
          code: NutrientCodes.protein,
          valuePer100g: 2.7,
          unit: NutrientUnit.gram,
        ),
        NutrientValue(
          code: NutrientCodes.carbohydrate,
          valuePer100g: 28,
          unit: NutrientUnit.gram,
        ),
        NutrientValue(
          code: NutrientCodes.fat,
          valuePer100g: 0.3,
          unit: NutrientUnit.gram,
        ),
      ],
    );

    await plans.addFood(mealId: mealId, foodId: foodId, quantityGrams: 150);

    await patients.addEncounter(
      PatientEncounter(
        patientId: patientId,
        occurredAt: DateTime(2026, 11, 3),
        assessment: 'Seguimiento',
        informationSource: 'Paciente',
        planId: planId,
      ),
    );

    await patients.deletePermanently(patientId);

    expect(await patients.getById(patientId), isNull);
    expect(await patients.targetsFor(patientId), isEmpty);
    expect(await patients.measurementsFor(patientId), isEmpty);
    expect(await patients.observationsFor(patientId), isEmpty);
    expect(await patients.encountersFor(patientId), isEmpty);
    expect(await plans.listForPatient(patientId), isEmpty);

    final db = await database.database;
    expect(
      firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM meal_plans WHERE patient_id = ?',
          [patientId],
        ),
      ),
      0,
    );
    expect(firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM meals')), 0);
    expect(
      firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM meal_items')),
      0,
    );

    // Global food library is not patient-owned and must remain.
    expect(await database.getFood(foodId), isNotNull);
  });
}
