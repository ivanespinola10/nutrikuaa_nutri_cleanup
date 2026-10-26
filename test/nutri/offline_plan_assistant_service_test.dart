import 'package:flutter_test/flutter_test.dart';
import 'package:nutrikuaa_app/nutri/application/offline_plan_assistant_service.dart';
import 'package:nutrikuaa_app/nutri/application/unified_food_search_service.dart';
import 'package:nutrikuaa_app/nutri/domain/food.dart';
import 'package:nutrikuaa_app/nutri/domain/nutrition/nutrient.dart';

void main() {
  Food food(
    String name,
    double kcal,
    double protein,
    double carbs,
    double fat, {
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

  final catalog = <Food>[
    food('Egg', 143, 13, 1, 10, allergens: ['egg']),
    food('Oat', 389, 17, 66, 7, allergens: ['gluten']),
    food('Banana', 89, 1.1, 23, 0.3),
    food('Yogurt', 78, 4, 6, 4, allergens: ['milk']),
    food('Milk', 61, 3.2, 4.8, 3.3, allergens: ['milk']),
    food('Chicken breast', 165, 31, 0, 3.6),
    food('Fish fillet', 140, 25, 0, 4),
    food('Rice', 130, 2.7, 28, 0.3),
    food('Beans', 127, 8.7, 23, 0.5),
    food('Potato', 87, 1.9, 20, 0.1),
    food('Apple', 52, 0.3, 14, 0.2),
    food('Carrot', 41, 0.9, 10, 0.2),
    food('Broccoli', 34, 2.8, 7, 0.4),
    food('Tomato', 18, 0.9, 3.9, 0.2),
    food('Corn', 96, 3.4, 21, 1.5),
  ];

  Future<FoodSearchResults> search(String query) async {
    final q = query.trim().toLowerCase();
    final matches = q.isEmpty
        ? catalog
        : catalog.where((item) => item.name.toLowerCase().contains(q)).toList();
    return FoodSearchResults(professional: matches, official: const []);
  }

  test('creates a local draft with five meal slots when foods exist', () async {
    final service = OfflinePlanAssistantService(search: search);
    final draft = await service.generate(
      const OfflinePlanAssistantRequest(
        prompt: '1800 kcal, alto en proteína y económico',
        targetProteinGrams: 110,
      ),
    );

    expect(draft.meals.length, greaterThanOrEqualTo(4));
    expect(draft.targetKcal, 1800);
    expect(draft.totals.value(NutrientCodes.energyKcal), greaterThan(1000));
  });

  test('vegetarian draft does not select meat or fish', () async {
    final service = OfflinePlanAssistantService(search: search);
    final draft = await service.generate(
      const OfflinePlanAssistantRequest(
        prompt: '2000 kcal, vegetariano, económico',
      ),
    );

    final names = draft.meals
        .expand((meal) => meal.items)
        .map((item) => item.food.name.toLowerCase())
        .join(' ');
    expect(names, isNot(contains('chicken')));
    expect(names, isNot(contains('fish')));
  });

  test('lactose-free draft excludes foods declared with milk', () async {
    final service = OfflinePlanAssistantService(search: search);
    final draft = await service.generate(
      const OfflinePlanAssistantRequest(prompt: '1900 kcal, sin lactosa'),
    );

    final items = draft.meals.expand((meal) => meal.items);
    expect(items.any((item) => item.food.allergens.contains('milk')), isFalse);
  });
}
