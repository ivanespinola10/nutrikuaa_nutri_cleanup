import 'package:flutter_test/flutter_test.dart';
import 'package:nutrikuaa_app/nutri/application/nutrition_calculator.dart';
import 'package:nutrikuaa_app/nutri/domain/food.dart';
import 'package:nutrikuaa_app/nutri/domain/nutrition/nutrient.dart';

void main() {
  test('calculates nutrients for a branded food portion', () {
    final yogurt = Food(
      name: 'Greek yogurt',
      brand: 'Local brand',
      sourceType: FoodSourceType.brandLabel,
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
      ],
    );

    final totals = NutritionCalculator.forFood(yogurt, 150);

    expect(totals.value(NutrientCodes.energyKcal), 150);
    expect(totals.value(NutrientCodes.protein), 15);
  });

  test('sums multiple food portions', () {
    final food = Food(
      name: 'Food',
      sourceType: FoodSourceType.professionalCustom,
      nutrients: const [
        NutrientValue(
          code: NutrientCodes.carbohydrate,
          valuePer100g: 20,
          unit: NutrientUnit.gram,
        ),
      ],
    );

    final totals = NutritionCalculator.forPortions([
      FoodPortion(food: food, grams: 100),
      FoodPortion(food: food, grams: 50),
    ]);

    expect(totals.value(NutrientCodes.carbohydrate), 30);
  });
}
