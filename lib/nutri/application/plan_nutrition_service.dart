import '../data/nutri_database.dart';
import '../domain/meal_plan.dart';
import 'meal_plan_service.dart';
import 'nutrition_calculator.dart';
import 'recipe_service.dart';

class MealNutrition {
  final Meal meal;
  final NutritionTotals totals;

  const MealNutrition({
    required this.meal,
    required this.totals,
  });
}

class PlanNutritionSummary {
  final Map<int, NutritionTotals> dayTotals;
  final List<MealNutrition> meals;

  const PlanNutritionSummary({
    required this.dayTotals,
    required this.meals,
  });

  NutritionTotals totalsForDay(int dayIndex) =>
      dayTotals[dayIndex] ?? const NutritionTotals({});
}

class PlanNutritionService {
  final NutriDatabase database;
  final MealPlanService plans;
  final RecipeService recipes;

  PlanNutritionService({
    NutriDatabase? database,
    MealPlanService? plans,
    RecipeService? recipes,
  })  : database = database ?? NutriDatabase.instance,
        plans = plans ?? MealPlanService(database: database),
        recipes = recipes ?? RecipeService(database: database);

  Future<PlanNutritionSummary> calculate(int planId) async {
    final details = await plans.getById(planId);
    if (details == null) {
      throw StateError('Meal plan does not exist.');
    }

    final dayTotals = <int, NutritionTotals>{};
    final mealTotals = <MealNutrition>[];

    for (final mealWithItems in details.meals) {
      var total = const NutritionTotals(<String, double>{});

      for (final item in mealWithItems.items) {
        if (item.itemType == MealItemType.food) {
          final food = await database.getFood(item.foodId!);
          if (food == null) {
            throw StateError('Food referenced by plan no longer exists.');
          }

          total = total +
              NutritionCalculator.forFood(
                food,
                item.quantityGrams ?? 0,
              );
        } else {
          total = total + await _recipeTotals(
            item.recipeId!,
            selectedServings: item.servings ?? 1,
          );
        }
      }

      mealTotals.add(
        MealNutrition(
          meal: mealWithItems.meal,
          totals: total,
        ),
      );

      dayTotals.update(
        mealWithItems.meal.dayIndex,
        (current) => current + total,
        ifAbsent: () => total,
      );
    }

    return PlanNutritionSummary(
      dayTotals: dayTotals,
      meals: mealTotals,
    );
  }

  Future<NutritionTotals> _recipeTotals(
    int recipeId, {
    required double selectedServings,
  }) async {
    final details = await recipes.getById(recipeId);
    if (details == null) {
      throw StateError('Recipe referenced by plan no longer exists.');
    }

    var totalRecipe = const NutritionTotals(<String, double>{});

    for (final ingredient in details.items) {
      final food = await database.getFood(ingredient.foodId);
      if (food == null) {
        throw StateError('Food referenced by recipe no longer exists.');
      }

      totalRecipe = totalRecipe +
          NutritionCalculator.forFood(
            food,
            ingredient.quantityGrams,
          );
    }

    final factor = selectedServings / details.recipe.servings;
    return NutritionTotals({
      for (final entry in totalRecipe.values.entries)
        entry.key: entry.value * factor,
    });
  }
}
