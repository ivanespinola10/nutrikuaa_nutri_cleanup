import 'package:flutter_test/flutter_test.dart';
import 'package:nutrikuaa_app/nutri/application/offline_plan_assistant_service.dart';
import 'package:nutrikuaa_app/nutri/application/offline_plan_validator_service.dart';
import 'package:nutrikuaa_app/nutri/domain/food.dart';
import 'package:nutrikuaa_app/nutri/domain/nutrition/nutrient.dart';

void main() {
  Food food(
    String name, {
    required double kcal,
    required double protein,
    double carbs = 0,
    double fat = 0,
    List<String> allergens = const [],
  }) {
    return Food(
      id: name.hashCode.abs(),
      name: name,
      sourceType: FoodSourceType.professionalCustom,
      allergens: allergens,
      nutrients: [
        NutrientValue(
          code: NutrientCodes.energyKcal,
          valuePer100g: kcal,
          unit: NutrientUnit.kilocalorie,
        ),
        NutrientValue(
          code: NutrientCodes.protein,
          valuePer100g: protein,
          unit: NutrientUnit.gram,
        ),
        NutrientValue(
          code: NutrientCodes.carbohydrate,
          valuePer100g: carbs,
          unit: NutrientUnit.gram,
        ),
        NutrientValue(
          code: NutrientCodes.fat,
          valuePer100g: fat,
          unit: NutrientUnit.gram,
        ),
      ],
    );
  }

  OfflinePlanDraft draft({
    required List<OfflinePlanDraftItem> items,
    double targetKcal = 1800,
    double? targetProtein = 100,
    bool fallback = false,
  }) {
    return OfflinePlanDraft(
      title: 'Test',
      rationale: 'Test',
      targetKcal: targetKcal,
      targetProteinGrams: targetProtein,
      usedFallbackEnergyTarget: fallback,
      meals: [OfflinePlanDraftMeal(name: 'Almuerzo', items: items)],
    );
  }

  const validator = OfflinePlanValidatorService();

  test('valid plan has no blocking issues', () {
    final rice = food('Rice', kcal: 180, protein: 5, carbs: 36, fat: 2);
    final chicken = food(
      'Chicken breast',
      kcal: 200,
      protein: 30,
      carbs: 0,
      fat: 7,
    );

    final result = validator.validate(
      OfflinePlanValidationRequest(
        draft: draft(
          items: [
            OfflinePlanDraftItem(food: rice, grams: 500),
            OfflinePlanDraftItem(food: chicken, grams: 450),
          ],
          targetKcal: 1800,
          targetProtein: 160,
        ),
        prompt: 'alto en proteína',
        targetKcal: 1800,
        targetProteinGrams: 160,
      ),
    );

    expect(result.hasBlockingIssues, isFalse);
    expect(result.canApply, isTrue);
  });

  test('lactose restriction blocks milk conflict', () {
    final milk = food(
      'Milk, whole',
      kcal: 61,
      protein: 3.2,
      carbs: 4.8,
      fat: 3.3,
      allergens: const ['milk'],
    );

    final result = validator.validate(
      OfflinePlanValidationRequest(
        draft: draft(
          items: [OfflinePlanDraftItem(food: milk, grams: 250)],
          targetKcal: 200,
          targetProtein: null,
        ),
        prompt: 'sin lactosa',
        targetKcal: 200,
      ),
    );

    expect(result.hasBlockingIssues, isTrue);
    expect(
      result.checks.any(
        (check) =>
            check.id == 'restrictions' &&
            check.severity == PlanValidationSeverity.blocking,
      ),
      isTrue,
    );
  });

  test('patient egg allergy blocks egg even if prompt does not mention it', () {
    final egg = food(
      'Egg, whole',
      kcal: 143,
      protein: 13,
      allergens: const ['egg'],
    );

    final result = validator.validate(
      OfflinePlanValidationRequest(
        draft: draft(
          items: [OfflinePlanDraftItem(food: egg, grams: 140)],
          targetKcal: 200,
          targetProtein: null,
        ),
        prompt: 'práctico',
        patientAllergies: 'Alergia al huevo',
        targetKcal: 200,
      ),
    );

    expect(result.hasBlockingIssues, isTrue);
  });

  test('large nutrient deviation warns but does not auto-block', () {
    final rice = food('Rice', kcal: 130, protein: 2.7, carbs: 28);

    final result = validator.validate(
      OfflinePlanValidationRequest(
        draft: draft(
          items: [OfflinePlanDraftItem(food: rice, grams: 100)],
          targetKcal: 2000,
          targetProtein: null,
        ),
        prompt: 'variado',
        targetKcal: 2000,
      ),
    );

    expect(result.hasBlockingIssues, isFalse);
    expect(result.hasWarnings, isTrue);
    expect(result.canApply, isTrue);
  });

  test('invalid quantity is blocking', () {
    final rice = food('Rice', kcal: 130, protein: 2.7, carbs: 28);

    final result = validator.validate(
      OfflinePlanValidationRequest(
        draft: draft(items: [OfflinePlanDraftItem(food: rice, grams: 0)]),
        prompt: 'variado',
        targetKcal: 1800,
      ),
    );

    expect(result.hasBlockingIssues, isTrue);
  });
}
