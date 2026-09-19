import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nutrikuaa_app/nutri/application/food_library_service.dart';
import 'package:nutrikuaa_app/nutri/application/food_snapshot_service.dart';
import 'package:nutrikuaa_app/nutri/application/meal_plan_service.dart';
import 'package:nutrikuaa_app/nutri/application/plan_nutrition_service.dart';
import 'package:nutrikuaa_app/nutri/application/recipe_service.dart';
import 'package:nutrikuaa_app/nutri/application/unified_food_search_service.dart';
import 'package:nutrikuaa_app/nutri/data/nutri_database.dart';
import 'package:nutrikuaa_app/nutri/data/official_food_catalog.dart';
import 'package:nutrikuaa_app/nutri/data/patient_repository.dart';
import 'package:nutrikuaa_app/nutri/domain/food.dart';
import 'package:nutrikuaa_app/nutri/domain/meal_plan.dart';
import 'package:nutrikuaa_app/nutri/domain/nutrition/nutrient.dart';
import 'package:nutrikuaa_app/nutri/domain/patient.dart';
import 'package:nutrikuaa_app/nutri/domain/recipe.dart';

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
