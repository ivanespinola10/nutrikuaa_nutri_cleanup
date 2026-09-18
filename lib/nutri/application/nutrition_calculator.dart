import '../domain/food.dart';

class FoodAmount {
  final Food food;
  final double grams;

  const FoodAmount({
    required this.food,
    required this.grams,
  });
}

class NutritionTotals {
  final Map<String, double> values;

  const NutritionTotals(this.values);

  double value(String nutrientCode) => values[nutrientCode] ?? 0;

  NutritionTotals operator +(NutritionTotals other) {
    final merged = <String, double>{...values};
    for (final entry in other.values.entries) {
      merged.update(
        entry.key,
        (current) => current + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    return NutritionTotals(merged);
  }
}

class NutritionCalculator {
  NutritionCalculator._();

  static NutritionTotals forFood(Food food, double grams) {
    if (grams <= 0) return const NutritionTotals({});

    return NutritionTotals({
      for (final nutrient in food.nutrients)
        nutrient.code: nutrient.valuePer100g * grams / 100,
    });
  }

  static NutritionTotals forPortions(Iterable<FoodAmount> portions) {
    var totals = const NutritionTotals(<String, double>{});

    for (final portion in portions) {
      totals = totals + forFood(portion.food, portion.grams);
    }

    return totals;
  }

  static double difference({
    required double actual,
    required double target,
  }) {
    return actual - target;
  }

  static double percentOfTarget({
    required double actual,
    required double target,
  }) {
    if (target <= 0) return 0;
    return actual / target * 100;
  }
}
