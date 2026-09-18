enum MealItemType {
  food,
  recipe,
}

class MealPlan {
  final int? id;
  final int patientId;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  MealPlan({
    this.id,
    required this.patientId,
    required this.name,
    this.startDate,
    this.endDate,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}

class Meal {
  final int? id;
  final int planId;
  final int dayIndex;
  final String name;
  final int sortOrder;

  const Meal({
    this.id,
    required this.planId,
    required this.dayIndex,
    required this.name,
    this.sortOrder = 0,
  });
}

class MealItem {
  final int? id;
  final int mealId;
  final MealItemType itemType;
  final int? foodId;
  final int? recipeId;
  final double? quantityGrams;
  final double? servings;
  final String? notes;
  final int sortOrder;

  const MealItem({
    this.id,
    required this.mealId,
    required this.itemType,
    this.foodId,
    this.recipeId,
    this.quantityGrams,
    this.servings,
    this.notes,
    this.sortOrder = 0,
  }) : assert(
          (itemType == MealItemType.food && foodId != null && recipeId == null) ||
              (itemType == MealItemType.recipe &&
                  recipeId != null &&
                  foodId == null),
          'MealItem must reference exactly one food or recipe.',
        );
}
