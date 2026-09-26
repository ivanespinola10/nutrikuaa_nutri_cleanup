import '../data/nutri_database.dart';
import '../domain/food.dart';
import '../domain/meal_plan.dart';
import 'meal_plan_service.dart';
import 'recipe_service.dart';

class ShoppingListEntry {
  final Food food;
  final double grams;

  const ShoppingListEntry({required this.food, required this.grams});
}

/// Totals the ingredients actually entered in a plan. No suggested swaps,
/// yields, package sizes or household conversions are inferred here.
class ShoppingListService {
  final NutriDatabase database;
  final MealPlanService plans;
  final RecipeService recipes;

  ShoppingListService({
    NutriDatabase? database,
    MealPlanService? plans,
    RecipeService? recipes,
  })  : database = database ?? NutriDatabase.instance,
        plans = plans ?? MealPlanService(database: database),
        recipes = recipes ?? RecipeService(database: database);

  Future<List<ShoppingListEntry>> forPlan(int planId) async {
    final plan = await plans.getById(planId);
    if (plan == null) throw StateError('Meal plan does not exist.');

    final quantities = <int, double>{};
    for (final meal in plan.meals) {
      for (final item in meal.items) {
        if (item.itemType == MealItemType.food) {
          final grams = item.quantityGrams;
          if (grams == null || grams <= 0) {
            throw StateError('Invalid food quantity in meal plan.');
          }
          quantities.update(item.foodId!, (value) => value + grams,
              ifAbsent: () => grams);
          continue;
        }

        final recipe = await recipes.getById(item.recipeId!);
        if (recipe == null) {
          throw StateError('Recipe referenced by plan no longer exists.');
        }
        final servings = item.servings ?? 1;
        if (servings <= 0 || recipe.recipe.servings <= 0) {
          throw StateError('Invalid recipe servings in meal plan.');
        }
        final multiplier = servings / recipe.recipe.servings;
        for (final ingredient in recipe.items) {
          final grams = ingredient.quantityGrams * multiplier;
          if (grams <= 0) {
            throw StateError('Invalid recipe ingredient quantity.');
          }
          quantities.update(ingredient.foodId, (value) => value + grams,
              ifAbsent: () => grams);
        }
      }
    }

    final result = <ShoppingListEntry>[];
    for (final entry in quantities.entries) {
      final food = await database.getFood(entry.key);
      if (food == null) {
        throw StateError('Food referenced by plan no longer exists.');
      }
      result.add(ShoppingListEntry(food: food, grams: entry.value));
    }
    result.sort((a, b) {
      final order = a.food.name.toLowerCase().compareTo(b.food.name.toLowerCase());
      return order != 0 ? order : a.food.id!.compareTo(b.food.id!);
    });
    return result;
  }
}
