import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nutrikuaa_app/nutri/application/food_library_service.dart';
import 'package:nutrikuaa_app/nutri/application/food_snapshot_service.dart';
import 'package:nutrikuaa_app/nutri/application/meal_plan_service.dart';
import 'package:nutrikuaa_app/nutri/application/nutri_backup_service.dart';
import 'package:nutrikuaa_app/nutri/application/plan_nutrition_service.dart';
import 'package:nutrikuaa_app/nutri/application/plan_pdf_service.dart';
import 'package:nutrikuaa_app/nutri/application/recipe_nutrition_service.dart';
import 'package:nutrikuaa_app/nutri/application/recipe_service.dart';
import 'package:nutrikuaa_app/nutri/application/shopping_list_service.dart';
import 'package:nutrikuaa_app/nutri/application/unified_food_search_service.dart';
import 'package:nutrikuaa_app/nutri/data/app_settings_repository.dart';
import 'package:nutrikuaa_app/nutri/data/nutri_database.dart';
import 'package:nutrikuaa_app/nutri/data/official_food_catalog.dart';
import 'package:nutrikuaa_app/nutri/data/patient_repository.dart';
import 'package:nutrikuaa_app/nutri/data/professional_profile_repository.dart';
import 'package:nutrikuaa_app/nutri/domain/app_settings.dart';
import 'package:nutrikuaa_app/nutri/domain/food.dart';
import 'package:nutrikuaa_app/nutri/domain/meal_plan.dart';
import 'package:nutrikuaa_app/nutri/domain/nutrition/nutrient.dart';
import 'package:nutrikuaa_app/nutri/domain/patient.dart';
import 'package:nutrikuaa_app/nutri/domain/professional_profile.dart';
import 'package:nutrikuaa_app/nutri/domain/recipe.dart';
import 'package:nutrikuaa_app/nutri/localization/nutri_i18n.dart';

void main() {
  late Database officialDb;
  late String privateDbPath;
  late String officialDbPath;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await NutriDatabase.instance.close();

    final databasesPath = await databaseFactoryFfi.getDatabasesPath();
    privateDbPath = p.join(databasesPath, NutriDatabase.databaseName);
    officialDbPath = p.join(databasesPath, 'nutrikuaa_foods_test.db');

    await databaseFactoryFfi.deleteDatabase(privateDbPath);
    await databaseFactoryFfi.deleteDatabase(officialDbPath);

    officialDb = await databaseFactoryFfi.openDatabase(
      officialDbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE foods (
              id INTEGER PRIMARY KEY,
              source_food_id TEXT NOT NULL UNIQUE,
              name TEXT NOT NULL,
              data_type TEXT,
              category_id TEXT,
              publication_date TEXT,
              source_name TEXT NOT NULL,
              source_release TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE food_nutrients (
              food_id INTEGER NOT NULL,
              nutrient_code TEXT NOT NULL,
              value_per_100g REAL NOT NULL,
              unit TEXT NOT NULL,
              source_nutrient_id TEXT,
              PRIMARY KEY (food_id, nutrient_code)
            )
          ''');

          await db.execute('''
            CREATE TABLE food_portions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              food_id INTEGER NOT NULL,
              amount REAL,
              measure TEXT,
              gram_weight REAL NOT NULL,
              modifier TEXT,
              sequence INTEGER
            )
          ''');
        },
      ),
    );

    await officialDb.insert('foods', {
      'id': 101,
      'source_food_id': '101',
      'name': 'Yogurt, Greek, plain',
      'data_type': 'foundation_food',
      'source_name': 'USDA FoodData Central',
      'source_release': 'USDA FDC 2026-04',
    });

    await officialDb.insert('food_nutrients', {
      'food_id': 101,
      'nutrient_code': NutrientCodes.energyKcal,
      'value_per_100g': 100.0,
      'unit': NutrientUnit.kilocalorie.name,
      'source_nutrient_id': '1008',
    });

    await officialDb.insert('food_nutrients', {
      'food_id': 101,
      'nutrient_code': NutrientCodes.protein,
      'value_per_100g': 10.0,
      'unit': NutrientUnit.gram.name,
      'source_nutrient_id': '1003',
    });

    await officialDb.insert('food_portions', {
      'food_id': 101,
      'amount': 1.0,
      'measure': 'container',
      'gram_weight': 150.0,
      'sequence': 1,
    });

    await officialDb.insert('foods', {
      'id': 202,
      'source_food_id': '202',
      'name': 'Milk, whole',
      'data_type': 'foundation_food',
      'source_name': 'USDA FoodData Central',
      'source_release': 'USDA FDC 2026-04',
    });

    await officialDb.insert('food_nutrients', {
      'food_id': 202,
      'nutrient_code': NutrientCodes.energyKcal,
      'value_per_100g': 61.0,
      'unit': NutrientUnit.kilocalorie.name,
      'source_nutrient_id': '1008',
    });
  });

  tearDown(() async {
    await NutriDatabase.instance.close();
    await officialDb.close();
    await databaseFactoryFfi.deleteDatabase(privateDbPath);
    await databaseFactoryFfi.deleteDatabase(officialDbPath);
  });

  test('Spanish multiword food search finds official names across commas', () async {
    final search = UnifiedFoodSearchService(
      officialCatalog: OfficialFoodCatalog(open: () async => officialDb),
    );

    final milk = await search.search('leche entera');
    expect(milk.official.map((food) => food.sourceFoodId), contains('202'));
    expect(milk.official.single.name, 'Milk, whole');

    final yogurt = await search.search('yogur natural');
    expect(yogurt.official.map((food) => food.sourceFoodId), contains('101'));
    expect(yogurt.official.single.sourceName, 'USDA FoodData Central');

    final literal = await search.search('%');
    expect(literal.official, isEmpty);
  });

  test('complete local-first nutrition backend flow', () async {
    final officialCatalog = OfficialFoodCatalog(
      open: () async => officialDb,
    );

    final foodLibrary = FoodLibraryService();
    final localYogurtId = await foodLibrary.addBrandedFood(
      name: 'Yogur natural',
      brand: 'Marca local',
      countryCode: 'PY',
      servingQuantity: 150,
      servingUnit: 'g',
      nutrients: const [
        NutrientValue(
          code: NutrientCodes.energyKcal,
          valuePer100g: 90,
          unit: NutrientUnit.kilocalorie,
        ),
        NutrientValue(
          code: NutrientCodes.protein,
          valuePer100g: 6,
          unit: NutrientUnit.gram,
        ),
      ],
    );
    expect(localYogurtId, greaterThan(0));

    final search = UnifiedFoodSearchService(
      officialCatalog: officialCatalog,
    );
    final results = await search.search('yog');

    expect(results.professional, hasLength(1));
    expect(results.professional.first.brand, 'Marca local');
    expect(results.official, hasLength(1));
    expect(results.official.first.sourceFoodId, '101');

    final snapshot = await FoodSnapshotService().materializeOfficialFood(
      results.official.first,
    );

    expect(snapshot.sourceType, FoodSourceType.officialSnapshot);
    expect(snapshot.sourceRelease, 'USDA FDC 2026-04');
    expect(snapshot.portions.single.gramWeight, 150);

    final sameSnapshot = await FoodSnapshotService().materializeOfficialFood(
      results.official.first,
    );
    expect(sameSnapshot.id, snapshot.id);

    final patientRepository = PatientRepository();
    final patientId = await patientRepository.create(
      Patient(
        firstName: 'Ana',
        lastName: 'Perez',
      ),
    );

    await patientRepository.setTargets(patientId, [
      NutritionTarget(
        patientId: patientId,
        nutrientCode: NutrientCodes.energyKcal,
        targetValue: 2000,
        unit: NutrientUnit.kilocalorie,
      ),
      NutritionTarget(
        patientId: patientId,
        nutrientCode: NutrientCodes.protein,
        targetValue: 120,
        unit: NutrientUnit.gram,
      ),
    ]);

    final targets = await patientRepository.targetsFor(patientId);
    expect(targets, hasLength(2));

    final recipeService = RecipeService();
    final recipeId = await recipeService.create(
      Recipe(
        name: 'Yogur con extra de yogur',
        servings: 1,
      ),
      [
        RecipeIngredientInput(
          foodId: snapshot.id!,
          quantityGrams: 150,
          sortOrder: 0,
        ),
        RecipeIngredientInput(
          foodId: localYogurtId,
          quantityGrams: 100,
          sortOrder: 1,
        ),
      ],
    );

    final planService = MealPlanService();
    final planId = await planService.createPlan(
      MealPlan(
        patientId: patientId,
        name: 'Plan semanal inicial',
      ),
    );

    final breakfastId = await planService.addMeal(
      planId: planId,
      dayIndex: 0,
      name: 'Desayuno',
      sortOrder: 0,
    );

    await planService.addRecipe(
      mealId: breakfastId,
      recipeId: recipeId,
      servings: 1,
    );

    final shopping = await ShoppingListService().forPlan(planId);
    expect(shopping, hasLength(2));
    expect(shopping.firstWhere((entry) => entry.food.id == snapshot.id).grams,
        closeTo(150, 0.001));
    expect(shopping.firstWhere((entry) => entry.food.id == localYogurtId).grams,
        closeTo(100, 0.001));

    final summary = await PlanNutritionService().calculate(planId);
    final day = summary.totalsForDay(0);

    expect(day.value(NutrientCodes.energyKcal), closeTo(240, 0.001));
    expect(day.value(NutrientCodes.protein), closeTo(21, 0.001));

    final duplicatedPlanId = await planService.duplicatePlan(
      planId,
      newName: 'Plan semana 2',
    );
    final duplicated = await planService.getById(duplicatedPlanId);

    expect(duplicated, isNotNull);
    expect(duplicated!.meals, hasLength(1));
    expect(duplicated.meals.single.items, hasLength(1));
  });

  test('v9 migration preserves a patient and adds longitudinal tables', () async {
    await NutriDatabase.instance.close();
    await databaseFactoryFfi.deleteDatabase(privateDbPath);
    final old = await databaseFactoryFfi.openDatabase(
      privateDbPath,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: (db, version) async {
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
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    final now = DateTime(2026, 9, 29).toIso8601String();
    await old.insert('patients', {
      'first_name': 'Antes',
      'last_name': 'Migración',
      'created_at': now,
      'updated_at': now,
    });
    await old.close();

    final upgraded = await NutriDatabase.instance.database;
    final patient = (await PatientRepository().search('Antes')).single;
    expect(patient.displayName, 'Antes Migración');
    expect(patient.consultationReason, isNull);
    expect(await upgraded.query('patient_encounters'), isEmpty);
    expect(await upgraded.query('patient_observations'), isEmpty);
  });

  test('patient assessment and dated visits survive backup without mixing patients', () async {
    final patients = PatientRepository();
    final firstId = await patients.create(Patient(
      firstName: 'Ana',
      lastName: 'Prueba',
      consultationReason: 'Objetivo acordado de prueba',
      dietaryHistory: 'Horarios declarados',
      foodContext: 'Preferencias declaradas',
      reportedAllergies: 'Sin verificar',
      historySource: 'Declarado por paciente ficticio',
    ));
    final secondId = await patients.create(Patient(firstName: 'Otro'));
    final planId = await MealPlanService().createPlan(
      MealPlan(patientId: firstId, name: 'Plan de prueba'),
    );
    final at = DateTime(2026, 9, 29);
    await patients.addEncounter(PatientEncounter(
      patientId: firstId,
      occurredAt: at,
      assessment: 'Cambio reportado',
      intervention: 'Ajustar plan con el profesional',
      monitoring: 'Revisar en 14 días',
      nextReviewAt: DateTime(2026, 10, 13),
      informationSource: 'Entrevista',
      planId: planId,
    ));
    await patients.addObservation(PatientObservation(
      patientId: firstId,
      observedAt: at,
      indicator: 'Indicador de prueba',
      value: 5.2,
      unit: 'unidad',
      source: 'Informe ficticio',
      referenceRange: '4 a 6',
    ));
    expect((await patients.getById(firstId))!.dietaryHistory,
        'Horarios declarados');
    expect((await patients.encountersFor(firstId)).single.planId, planId);
    expect(await patients.encountersFor(secondId), isEmpty);
    expect(await patients.observationsFor(secondId), isEmpty);
    expect(
      patients.addEncounter(PatientEncounter(
        patientId: secondId,
        occurredAt: at,
        assessment: 'Plan equivocado',
        planId: planId,
      )),
      throwsArgumentError,
    );

    final backup = NutriBackupService();
    final bytes = await backup.exportBackup();
    await backup.restoreBackup(bytes);
    expect((await patients.getById(firstId))!.historySource,
        'Declarado por paciente ficticio');
    final history = await patients.encountersFor(firstId);
    expect(history, hasLength(1));
    expect(history.single.nextReviewAt, DateTime(2026, 10, 13));
    expect(history.single.informationSource, 'Entrevista');
    final indicators = await patients.observationsFor(firstId);
    expect(indicators, hasLength(1));
    expect(indicators.single.value, 5.2);
    expect(indicators.single.source, 'Informe ficticio');
  });

  test('custom micronutrients and declared allergens survive edit and backup', () async {
    final library = FoodLibraryService();
    final id = await library.addProfessionalFood(
      name: 'Alimento de prueba',
      sourceName: 'Etiqueta revisada por profesional',
      allergens: const ['milk', 'soy'],
      nutrients: const [
        NutrientValue(
          code: NutrientCodes.calcium,
          valuePer100g: 120,
          unit: NutrientUnit.milligram,
        ),
      ],
    );
    final saved = (await NutriDatabase.instance.getFood(id))!;
    expect(saved.allergens, ['milk', 'soy']);
    expect(saved.sourceName, 'Etiqueta revisada por profesional');
    expect(saved.nutrient(NutrientCodes.calcium)?.valuePer100g, 120);
    expect(saved.nutrient(NutrientCodes.iron), isNull);

    await library.update(saved.copyWith(allergens: const ['milk']));
    expect((await NutriDatabase.instance.getFood(id))!.allergens, ['milk']);

    final backup = NutriBackupService();
    final bytes = await backup.exportBackup();
    await backup.restoreBackup(bytes);
    final restored = (await library.search('Alimento de prueba')).single;
    expect(restored.allergens, ['milk']);
    expect(restored.nutrient(NutrientCodes.calcium)?.valuePer100g, 120);
  });

  test('shopping list adds direct foods and scaled recipes across days', () async {
    final foods = FoodLibraryService();
    final rice = await foods.addProfessionalFood(
      name: 'Arroz', nutrients: const [],
    );
    final beans = await foods.addProfessionalFood(
      name: 'Porotos', nutrients: const [],
    );
    final recipeId = await RecipeService().create(
      Recipe(name: 'Guiso', servings: 4),
      [
        RecipeIngredientInput(foodId: rice, quantityGrams: 400),
        RecipeIngredientInput(foodId: beans, quantityGrams: 200),
      ],
    );
    final patientId = await PatientRepository().create(
      Patient(firstName: 'Prueba', lastName: 'Ficticia'),
    );
    final plans = MealPlanService();
    final planId = await plans.createPlan(
      MealPlan(patientId: patientId, name: 'Tres días'),
    );
    final monday = await plans.addMeal(
      planId: planId, dayIndex: 0, name: 'Almuerzo',
    );
    final wednesday = await plans.addMeal(
      planId: planId, dayIndex: 2, name: 'Cena',
    );
    await plans.addFood(mealId: monday, foodId: rice, quantityGrams: 50);
    await plans.addRecipe(
      mealId: monday, recipeId: recipeId, servings: 2,
    );
    await plans.addRecipe(
      mealId: wednesday, recipeId: recipeId, servings: 1,
    );

    final entries = await ShoppingListService().forPlan(planId);
    expect(entries, hasLength(2));
    expect(entries.firstWhere((entry) => entry.food.id == rice).grams, 350);
    expect(entries.firstWhere((entry) => entry.food.id == beans).grams, 150);
  });

  test('editing a used custom food keeps previous plan and recipe totals', () async {
    final foods = FoodLibraryService();
    final originalId = await foods.addProfessionalFood(
      name: 'Pan local',
      nutrients: const [
        NutrientValue(
          code: NutrientCodes.energyKcal,
          valuePer100g: 100,
          unit: NutrientUnit.kilocalorie,
        ),
      ],
    );
    final recipeId = await RecipeService().create(
      Recipe(name: 'Tostada', servings: 1),
      [RecipeIngredientInput(foodId: originalId, quantityGrams: 100)],
    );
    final patientId = await PatientRepository().create(
      Patient(firstName: 'Historial', lastName: 'Seguro'),
    );
    final plans = MealPlanService();
    final planId = await plans.createPlan(
      MealPlan(patientId: patientId, name: 'Plan entregado'),
    );
    final mealId = await plans.addMeal(
      planId: planId, dayIndex: 0, name: 'Desayuno',
    );
    await plans.addFood(mealId: mealId, foodId: originalId, quantityGrams: 100);
    await plans.addRecipe(mealId: mealId, recipeId: recipeId);
    final nutrition = PlanNutritionService();
    expect(
      (await nutrition.calculate(planId)).totalsForDay(0).value(NutrientCodes.energyKcal),
      200,
    );

    final original = (await NutriDatabase.instance.getFood(originalId))!;
    final revisionId = await foods.update(original.copyWith(
      nutrients: const [
        NutrientValue(
          code: NutrientCodes.energyKcal,
          valuePer100g: 250,
          unit: NutrientUnit.kilocalorie,
        ),
      ],
    ));

    expect(revisionId, isNot(originalId));
    expect((await NutriDatabase.instance.getFood(originalId))!.isArchived, true);
    expect((await NutriDatabase.instance.getFood(originalId))!
        .nutrient(NutrientCodes.energyKcal)!.valuePer100g, 100);
    expect((await NutriDatabase.instance.getFood(revisionId))!
        .nutrient(NutrientCodes.energyKcal)!.valuePer100g, 250);
    expect((await foods.search('Pan local')).map((food) => food.id), [revisionId]);
    expect(
      (await nutrition.calculate(planId)).totalsForDay(0).value(NutrientCodes.energyKcal),
      200,
    );
  });

  test('weekly plan supports reusable meals and multiple days', () async {
    final patients = PatientRepository();
    final patientId = await patients.create(
      Patient(firstName: 'Weekly', lastName: 'Tester'),
    );

    final foods = FoodLibraryService();
    final foodId = await foods.addProfessionalFood(
      name: 'Rice test',
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
      ],
    );

    final plans = MealPlanService();
    final planId = await plans.createPlan(
      MealPlan(
        patientId: patientId,
        name: 'Weekly test',
      ),
    );

    final mondayBreakfast = await plans.getOrCreateMeal(
      planId: planId,
      dayIndex: 0,
      name: 'Desayuno',
      sortOrder: 0,
    );
    final sameMondayBreakfast = await plans.getOrCreateMeal(
      planId: planId,
      dayIndex: 0,
      name: 'Desayuno',
      sortOrder: 0,
    );
    expect(sameMondayBreakfast, mondayBreakfast);

    final tuesdayLunch = await plans.getOrCreateMeal(
      planId: planId,
      dayIndex: 1,
      name: 'Almuerzo',
      sortOrder: 2,
    );

    await plans.addFood(
      mealId: mondayBreakfast,
      foodId: foodId,
      quantityGrams: 100,
    );
    final secondItemId = await plans.addFood(
      mealId: mondayBreakfast,
      foodId: foodId,
      quantityGrams: 50,
    );
    await plans.addFood(
      mealId: tuesdayLunch,
      foodId: foodId,
      quantityGrams: 200,
    );

    var summary = await PlanNutritionService().calculate(planId);
    expect(
      summary.totalsForDay(0).value(NutrientCodes.energyKcal),
      closeTo(195, 0.001),
    );
    expect(
      summary.totalsForDay(1).value(NutrientCodes.energyKcal),
      closeTo(260, 0.001),
    );

    await plans.updateFoodQuantity(
      mealItemId: secondItemId,
      quantityGrams: 100,
    );
    summary = await PlanNutritionService().calculate(planId);
    expect(
      summary.totalsForDay(0).value(NutrientCodes.energyKcal),
      closeTo(260, 0.001),
    );

    await plans.removeMealItem(secondItemId);
    summary = await PlanNutritionService().calculate(planId);
    expect(
      summary.totalsForDay(0).value(NutrientCodes.energyKcal),
      closeTo(130, 0.001),
    );
  });

  test('weekly productivity actions copy meals and days safely', () async {
    final patients = PatientRepository();
    final patientId = await patients.create(
      Patient(firstName: 'Copy', lastName: 'Tester'),
    );

    final foods = FoodLibraryService();
    final foodId = await foods.addProfessionalFood(
      name: 'Oats test',
      nutrients: const [
        NutrientValue(
          code: NutrientCodes.energyKcal,
          valuePer100g: 400,
          unit: NutrientUnit.kilocalorie,
        ),
      ],
    );

    final plans = MealPlanService();
    final planId = await plans.createPlan(
      MealPlan(
        patientId: patientId,
        name: 'Copy week',
      ),
    );

    final mondayBreakfast = await plans.getOrCreateMeal(
      planId: planId,
      dayIndex: 0,
      name: 'Desayuno',
      sortOrder: 0,
    );
    final tuesdayBreakfast = await plans.getOrCreateMeal(
      planId: planId,
      dayIndex: 1,
      name: 'Desayuno',
      sortOrder: 0,
    );

    final itemId = await plans.addFood(
      mealId: mondayBreakfast,
      foodId: foodId,
      quantityGrams: 40,
    );

    await plans.copyMealItems(
      sourceMealId: mondayBreakfast,
      targetMealId: tuesdayBreakfast,
    );

    var summary = await PlanNutritionService().calculate(planId);
    expect(
      summary.totalsForDay(1).value(NutrientCodes.energyKcal),
      closeTo(160, 0.001),
    );

    await plans.updateFoodQuantity(
      mealItemId: itemId,
      quantityGrams: 50,
    );

    await plans.copyDay(
      planId: planId,
      sourceDayIndex: 0,
      targetDayIndex: 2,
    );

    summary = await PlanNutritionService().calculate(planId);
    expect(
      summary.totalsForDay(0).value(NutrientCodes.energyKcal),
      closeTo(200, 0.001),
    );
    expect(
      summary.totalsForDay(2).value(NutrientCodes.energyKcal),
      closeTo(200, 0.001),
    );

    await plans.clearMeal(tuesdayBreakfast);
    summary = await PlanNutritionService().calculate(planId);
    expect(
      summary.totalsForDay(1).value(NutrientCodes.energyKcal),
      closeTo(0, 0.001),
    );
  });

  test('recipe editor flow calculates, updates and reuses recipes', () async {
    final foods = FoodLibraryService();

    final eggId = await foods.addProfessionalFood(
      name: 'Egg test',
      nutrients: const [
        NutrientValue(
          code: NutrientCodes.energyKcal,
          valuePer100g: 150,
          unit: NutrientUnit.kilocalorie,
        ),
        NutrientValue(
          code: NutrientCodes.protein,
          valuePer100g: 12,
          unit: NutrientUnit.gram,
        ),
      ],
    );

    final cheeseId = await foods.addProfessionalFood(
      name: 'Cheese test',
      nutrients: const [
        NutrientValue(
          code: NutrientCodes.energyKcal,
          valuePer100g: 300,
          unit: NutrientUnit.kilocalorie,
        ),
        NutrientValue(
          code: NutrientCodes.protein,
          valuePer100g: 20,
          unit: NutrientUnit.gram,
        ),
      ],
    );

    final recipes = RecipeService();
    final recipeId = await recipes.create(
      Recipe(
        name: 'Omelette test',
        servings: 2,
        yieldGrams: 220,
      ),
      [
        RecipeIngredientInput(
          foodId: eggId,
          quantityGrams: 200,
          sortOrder: 0,
        ),
        RecipeIngredientInput(
          foodId: cheeseId,
          quantityGrams: 20,
          sortOrder: 1,
        ),
      ],
    );

    final nutrition = RecipeNutritionService(recipes: recipes);
    var summary = await nutrition.calculate(recipeId);

    expect(
      summary.total.value(NutrientCodes.energyKcal),
      closeTo(360, 0.001),
    );
    expect(
      summary.perServing.value(NutrientCodes.energyKcal),
      closeTo(180, 0.001),
    );
    expect(
      summary.perServing.value(NutrientCodes.protein),
      closeTo(14, 0.001),
    );

    final current = await recipes.getById(recipeId);
    expect(current, isNotNull);

    await recipes.update(
      Recipe(
        id: recipeId,
        name: 'Omelette updated',
        servings: 2,
        yieldGrams: 240,
        createdAt: current!.recipe.createdAt,
      ),
      [
        RecipeIngredientInput(
          foodId: eggId,
          quantityGrams: 200,
          sortOrder: 0,
        ),
        RecipeIngredientInput(
          foodId: cheeseId,
          quantityGrams: 40,
          sortOrder: 1,
        ),
      ],
    );

    summary = await nutrition.calculate(recipeId);
    expect(
      summary.total.value(NutrientCodes.energyKcal),
      closeTo(420, 0.001),
    );
    expect(
      summary.perServing.value(NutrientCodes.energyKcal),
      closeTo(210, 0.001),
    );

    final patients = PatientRepository();
    final patientId = await patients.create(
      Patient(firstName: 'Recipe', lastName: 'Tester'),
    );

    final plans = MealPlanService();
    final planId = await plans.createPlan(
      MealPlan(
        patientId: patientId,
        name: 'Recipe plan',
      ),
    );
    final breakfast = await plans.addMeal(
      planId: planId,
      dayIndex: 0,
      name: 'Desayuno',
    );
    await plans.addRecipe(
      mealId: breakfast,
      recipeId: recipeId,
      servings: 1,
    );

    final planSummary = await PlanNutritionService().calculate(planId);
    expect(
      planSummary.totalsForDay(0).value(NutrientCodes.energyKcal),
      closeTo(210, 0.001),
    );

    await expectLater(
      recipes.delete(recipeId),
      throwsA(isA<StateError>()),
    );

    await expectLater(
      recipes.update(
        Recipe(
          id: recipeId,
          name: 'Should stay immutable in used plan',
          servings: 2,
          yieldGrams: 240,
          createdAt: current.recipe.createdAt,
        ),
        [
          RecipeIngredientInput(
            foodId: eggId,
            quantityGrams: 200,
          ),
        ],
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('patient workspace persists profile targets measurements and history', () async {
    final patients = PatientRepository();
    final patientId = await patients.create(
      Patient(
        firstName: 'Patient',
        lastName: 'Profile',
        dateOfBirth: DateTime(1990, 5, 10),
        email: 'patient@example.com',
        phone: '+595000000',
        notes: 'Initial note',
      ),
    );

    await patients.setTargets(patientId, [
      NutritionTarget(
        patientId: patientId,
        nutrientCode: NutrientCodes.energyKcal,
        targetValue: 2200,
        unit: NutrientUnit.kilocalorie,
      ),
      NutritionTarget(
        patientId: patientId,
        nutrientCode: NutrientCodes.protein,
        targetValue: 130,
        unit: NutrientUnit.gram,
      ),
      NutritionTarget(
        patientId: patientId,
        nutrientCode: NutrientCodes.carbohydrate,
        targetValue: 250,
        unit: NutrientUnit.gram,
      ),
    ]);

    final firstMeasurementId = await patients.addMeasurement(
      PatientMeasurement(
        patientId: patientId,
        measuredAt: DateTime(2026, 9, 1),
        weightKg: 80,
        heightCm: 180,
        waistCm: 90,
      ),
    );
    expect(firstMeasurementId, greaterThan(0));

    await patients.addMeasurement(
      PatientMeasurement(
        patientId: patientId,
        measuredAt: DateTime(2026, 9, 19),
        weightKg: 78,
        heightCm: 180,
        waistCm: 87,
        notes: 'Follow-up',
      ),
    );

    final measurements = await patients.measurementsFor(patientId);
    expect(measurements, hasLength(2));
    expect(measurements.first.weightKg, 78);
    expect(measurements.first.bmi, closeTo(24.074, 0.001));

    final current = await patients.getById(patientId);
    expect(current, isNotNull);

    await patients.update(
      Patient(
        id: patientId,
        firstName: 'Patient',
        lastName: 'Profile Updated',
        dateOfBirth: current!.dateOfBirth,
        email: current.email,
        phone: current.phone,
        notes: 'Updated note',
        createdAt: current.createdAt,
      ),
    );

    final updated = await patients.getById(patientId);
    expect(updated!.lastName, 'Profile Updated');
    expect(updated.notes, 'Updated note');

    final targets = await patients.targetsFor(patientId);
    expect(targets, hasLength(3));
    expect(
      targets
          .firstWhere((target) => target.nutrientCode == NutrientCodes.energyKcal)
          .targetValue,
      2200,
    );

    final plans = MealPlanService();
    await plans.createPlan(
      MealPlan(
        patientId: patientId,
        name: 'Patient history plan',
        startDate: DateTime(2026, 9, 21),
        endDate: DateTime(2026, 9, 27),
      ),
    );

    final history = await plans.listForPatient(patientId);
    expect(history, hasLength(1));
    expect(history.first.name, 'Patient history plan');

    await patients.deleteMeasurement(firstMeasurementId);
    final afterDelete = await patients.measurementsFor(patientId);
    expect(afterDelete, hasLength(1));
  });

  test('professional profile persists and plan PDF is generated offline', () async {
    final profileRepository = ProfessionalProfileRepository();
    final logoBytes = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x01,
      0x02,
      0x03,
    ]);
    final profile = ProfessionalProfile(
      fullName: 'Lic. Test Nutricionista',
      credentials: 'Nutricionista',
      registrationNumber: 'PY-123',
      practiceName: 'Consulta Test',
      phone: '+595 000 000',
      email: 'test@example.com',
      footerText: 'Documento de prueba',
      logoBytes: logoBytes,
      logoFileName: 'logo_test.png',
    );

    await profileRepository.save(profile);
    final savedProfile = await profileRepository.load();
    expect(savedProfile.fullName, profile.fullName);
    expect(savedProfile.practiceName, profile.practiceName);
    expect(savedProfile.registrationNumber, profile.registrationNumber);
    expect(savedProfile.logoFileName, 'logo_test.png');
    expect(savedProfile.logoBytes, orderedEquals(logoBytes));

    final patients = PatientRepository();
    final patientId = await patients.create(
      Patient(
        firstName: 'PDF',
        lastName: 'Paciente',
      ),
    );

    await patients.setTargets(patientId, [
      NutritionTarget(
        patientId: patientId,
        nutrientCode: NutrientCodes.energyKcal,
        targetValue: 2000,
        unit: NutrientUnit.kilocalorie,
      ),
      NutritionTarget(
        patientId: patientId,
        nutrientCode: NutrientCodes.protein,
        targetValue: 100,
        unit: NutrientUnit.gram,
      ),
    ]);

    final foods = FoodLibraryService();
    final foodId = await foods.addBrandedFood(
      name: 'Yogur natural',
      brand: 'Marca PDF',
      servingQuantity: 150,
      servingUnit: 'g',
      householdMeasure: '1 pote',
      nutrients: const [
        NutrientValue(
          code: NutrientCodes.energyKcal,
          valuePer100g: 100,
          unit: NutrientUnit.kilocalorie,
        ),
        NutrientValue(
          code: NutrientCodes.protein,
          valuePer100g: 10,
          unit: NutrientUnit.gram,
        ),
        NutrientValue(
          code: NutrientCodes.carbohydrate,
          valuePer100g: 8,
          unit: NutrientUnit.gram,
        ),
        NutrientValue(
          code: NutrientCodes.fat,
          valuePer100g: 3,
          unit: NutrientUnit.gram,
        ),
      ],
    );

    final plans = MealPlanService();
    final planId = await plans.createPlan(
      MealPlan(
        patientId: patientId,
        name: 'Prueba catálogo V0.2',
        startDate: DateTime(2026, 9, 21),
        endDate: DateTime(2026, 9, 27),
        notes: 'Mantener buena hidratación.',
      ),
    );
    final breakfastId = await plans.addMeal(
      planId: planId,
      dayIndex: 0,
      name: 'Desayuno',
      sortOrder: 0,
    );
    await plans.addFood(
      mealId: breakfastId,
      foodId: foodId,
      quantityGrams: 300,
    );

    // Exercise page breaks with several filled days and incomplete weekends.
    for (var dayIndex = 1; dayIndex < 5; dayIndex++) {
      final lunchId = await plans.addMeal(
        planId: planId,
        dayIndex: dayIndex,
        name: 'Almuerzo',
      );
      for (var itemIndex = 0; itemIndex < 4; itemIndex++) {
        await plans.addFood(
          mealId: lunchId,
          foodId: foodId,
          quantityGrams: 150,
        );
      }
    }

    final bytes = await PlanPdfService().build(
      planId: planId,
      profile: savedProfile,
      includeNutritionSummary: true,
      includeRecipeInstructions: true,
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('V0.8 backup restores portable data settings and logo', () async {
    final settingsRepository = AppSettingsRepository();
    await settingsRepository.save(
      const AppSettings(
        languageCode: 'en',
        countryCode: 'US',
        unitSystem: UnitSystem.imperial,
      ),
    );

    final profileRepository = ProfessionalProfileRepository();
    final logo = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
    await profileRepository.save(
      ProfessionalProfile(
        fullName: 'Backup Nutritionist',
        practiceName: 'Portable Practice',
        logoBytes: logo,
        logoFileName: 'portable_logo.png',
      ),
    );

    final patients = PatientRepository();
    final patientId = await patients.create(
      Patient(
        firstName: 'Portable',
        lastName: 'Patient',
      ),
    );

    final foods = FoodLibraryService();
    final foodId = await foods.addProfessionalFood(
      name: 'Portable food',
      nutrients: const [
        NutrientValue(
          code: NutrientCodes.energyKcal,
          valuePer100g: 120,
          unit: NutrientUnit.kilocalorie,
        ),
      ],
    );

    final plans = MealPlanService();
    final planId = await plans.createPlan(
      MealPlan(
        patientId: patientId,
        name: 'Portable plan',
      ),
    );
    final mealId = await plans.addMeal(
      planId: planId,
      dayIndex: 0,
      name: 'Desayuno',
    );
    await plans.addFood(
      mealId: mealId,
      foodId: foodId,
      quantityGrams: 100,
    );

    final backup = NutriBackupService();
    final bytes = await backup.exportBackup();
    expect(bytes.length, greaterThan(100));

    final summary = await backup.inspect(bytes);
    expect(summary.patientCount, 1);
    expect(summary.planCount, 1);
    expect(summary.foodCount, 1);

    await patients.create(
      Patient(
        firstName: 'Should',
        lastName: 'Disappear',
      ),
    );
    await settingsRepository.save(const AppSettings());

    final restored = await backup.restoreBackup(bytes);
    expect(restored.patientCount, 1);
    expect(restored.planCount, 1);

    final restoredPatients = await patients.search('', activeOnly: false);
    expect(restoredPatients, hasLength(1));
    expect(restoredPatients.single.displayName, 'Portable Patient');

    final restoredSettings = await settingsRepository.load();
    expect(restoredSettings.languageCode, 'en');
    expect(restoredSettings.countryCode, 'US');
    expect(restoredSettings.unitSystem, UnitSystem.imperial);

    final restoredProfile = await profileRepository.load();
    expect(restoredProfile.fullName, 'Backup Nutritionist');
    expect(restoredProfile.logoFileName, 'portable_logo.png');
    expect(restoredProfile.logoBytes, orderedEquals(logo));

    final restoredPlan = await plans.getById(planId);
    expect(restoredPlan, isNotNull);
    expect(restoredPlan!.meals.single.items.single.quantityGrams, 100);
  });

  test('PDF accepts English and imperial international settings', () async {
    final patients = PatientRepository();
    final patientId = await patients.create(
      Patient(firstName: 'International', lastName: 'Patient'),
    );

    final foods = FoodLibraryService();
    final foodId = await foods.addProfessionalFood(
      name: 'International food',
      nutrients: const [
        NutrientValue(
          code: NutrientCodes.energyKcal,
          valuePer100g: 100,
          unit: NutrientUnit.kilocalorie,
        ),
      ],
    );

    final plans = MealPlanService();
    final planId = await plans.createPlan(
      MealPlan(
        patientId: patientId,
        name: 'International week',
      ),
    );
    final mealId = await plans.addMeal(
      planId: planId,
      dayIndex: 0,
      name: 'Desayuno',
    );
    await plans.addFood(
      mealId: mealId,
      foodId: foodId,
      quantityGrams: 100,
    );

    final bytes = await PlanPdfService().build(
      planId: planId,
      profile: const ProfessionalProfile(fullName: 'International RD'),
      settings: const AppSettings(
        languageCode: 'en',
        countryCode: 'US',
        unitSystem: UnitSystem.imperial,
      ),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('V0.8.1 encrypted backup round-trip rejects wrong password', () async {
    final patients = PatientRepository();
    await patients.create(
      Patient(
        firstName: 'Encrypted',
        lastName: 'Patient',
      ),
    );

    final backup = NutriBackupService();
    final plain = await backup.exportBackup();
    final encrypted = await backup.encryptBackup(
      plain,
      'correct-horse-battery',
    );

    expect(backup.isEncrypted(encrypted), isTrue);
    expect(backup.isEncrypted(plain), isFalse);

    await expectLater(
      backup.decryptBackup(encrypted, 'wrong-password'),
      throwsA(isA<StateError>()),
    );

    final decrypted = await backup.decryptBackup(
      encrypted,
      'correct-horse-battery',
    );
    final summary = await backup.inspect(decrypted);
    expect(summary.patientCount, 1);

    await patients.create(
      Patient(
        firstName: 'Temporary',
        lastName: 'Patient',
      ),
    );
    expect(
      await patients.search('', activeOnly: false),
      hasLength(2),
    );

    await backup.restoreBackup(decrypted);
    final restored = await patients.search('', activeOnly: false);
    expect(restored, hasLength(1));
    expect(restored.single.displayName, 'Encrypted Patient');
  });

  test('V0.8.1 centralized interface translations support ES EN PT', () {
    addTearDown(() => NutriI18n.setLanguage('es'));

    NutriI18n.setLanguage('en');
    expect(NutriI18n.t('Pacientes'), 'Patients');
    expect(NutriI18n.day('Lunes'), 'Monday');
    expect(NutriI18n.meal('Desayuno'), 'Breakfast');

    NutriI18n.setLanguage('pt');
    expect(NutriI18n.t('Recetas'), 'Receitas');
    expect(NutriI18n.day('Martes'), 'Terça-feira');
    expect(NutriI18n.meal('Cena'), 'Jantar');

    NutriI18n.setLanguage('es');
    expect(NutriI18n.t('Configuración'), 'Configuración');
  });

  test('Spanish alias finds local snapshot and hides official duplicate', () async {
    final officialCatalog = OfficialFoodCatalog(
      open: () async => officialDb,
    );
    final search = UnifiedFoodSearchService(
      officialCatalog: officialCatalog,
    );

    final initial = await search.search('leche');
    expect(initial.official, hasLength(1));
    expect(initial.official.first.name, 'Milk, whole');

    final snapshot = await FoodSnapshotService().materializeOfficialFood(
      initial.official.first,
    );
    expect(snapshot.sourceType, FoodSourceType.officialSnapshot);

    final afterSnapshot = await search.search('leche');

    expect(
      afterSnapshot.professional.any(
        (food) =>
            food.sourceType == FoodSourceType.officialSnapshot &&
            food.sourceFoodId == '202',
      ),
      isTrue,
    );
    expect(
      afterSnapshot.official.any((food) => food.sourceFoodId == '202'),
      isFalse,
    );
  });
}
