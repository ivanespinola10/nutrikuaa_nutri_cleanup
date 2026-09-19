import '../data/nutri_database.dart';
import '../domain/food.dart';
import 'nutrition_calculator.dart';
import 'recipe_service.dart';

class RecipeNutritionSummary {
  final NutritionTotals total;
  final NutritionTotals perServing;
  final double servings;
  final double totalIngredientGrams;
  final double? yieldGrams;

  const RecipeNutritionSummary({
    required this.total,
    required this.perServing,
    required this.servings,
    required this.totalIngredientGrams,
    required this.yieldGrams,
  });
}

class RecipeNutritionService {
  final NutriDatabase database;
  final RecipeService recipes;

  RecipeNutritionService({
    NutriDatabase? database,
    RecipeService? recipes,
  })  : database = database ?? NutriDatabase.instance,
        recipes = recipes ?? RecipeService(database: database);

  Future<RecipeNutritionSummary> calculate(int recipeId) async {
    final details = await recipes.getById(recipeId);
    if (details == null) {
      throw StateError('Recipe does not exist.');
    }

    var total = const NutritionTotals(<String, double>{});
    var ingredientGrams = 0.0;

    for (final item in details.items) {
      final food = await database.getFood(item.foodId);
      if (food == null) {
        throw StateError('Food referenced by recipe no longer exists.');
      }

      ingredientGrams += item.quantityGrams;
      total = total +
          NutritionCalculator.forFood(
            food,
            item.quantityGrams,
          );
    }

    final servings = details.recipe.servings <= 0
        ? 1.0
        : details.recipe.servings;

    final perServing = NutritionTotals({
      for (final entry in total.values.entries)
        entry.key: entry.value / servings,
    });

    return RecipeNutritionSummary(
      total: total,
      perServing: perServing,
      servings: servings,
      totalIngredientGrams: ingredientGrams,
      yieldGrams: details.recipe.yieldGrams,
    );
  }

  Future<List<Food>> ingredientFoods(int recipeId) async {
    final details = await recipes.getById(recipeId);
    if (details == null) return const [];

    final foods = <Food>[];
    for (final item in details.items) {
      final food = await database.getFood(item.foodId);
      if (food != null) foods.add(food);
    }
    return foods;
  }
}
