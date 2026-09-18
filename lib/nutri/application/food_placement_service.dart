import '../domain/food.dart';
import 'food_snapshot_service.dart';
import 'meal_plan_service.dart';

class FoodPlacementService {
  final FoodSnapshotService snapshots;
  final MealPlanService plans;

  FoodPlacementService({
    FoodSnapshotService? snapshots,
    MealPlanService? plans,
  })  : snapshots = snapshots ?? FoodSnapshotService(),
        plans = plans ?? MealPlanService();

  Future<Food> resolveForProfessionalUse(Food selectedFood) async {
    if (selectedFood.sourceType == FoodSourceType.officialDatabase) {
      return snapshots.materializeOfficialFood(selectedFood);
    }

    if (selectedFood.id == null) {
      throw ArgumentError(
        'A non-official food must already exist in the private library.',
      );
    }

    return selectedFood;
  }

  Future<int> addSelectedFoodToMeal({
    required int mealId,
    required Food selectedFood,
    required double quantityGrams,
    String? notes,
    int sortOrder = 0,
  }) async {
    final resolved = await resolveForProfessionalUse(selectedFood);

    return plans.addFood(
      mealId: mealId,
      foodId: resolved.id!,
      quantityGrams: quantityGrams,
      notes: notes,
      sortOrder: sortOrder,
    );
  }
}
