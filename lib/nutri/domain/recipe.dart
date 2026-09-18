class Recipe {
  final int? id;
  final String name;
  final String? description;
  final double servings;
  final double? yieldGrams;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Recipe({
    this.id,
    required this.name,
    this.description,
    this.servings = 1,
    this.yieldGrams,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}

class RecipeItem {
  final int? id;
  final int recipeId;
  final int foodId;
  final double quantityGrams;
  final int sortOrder;

  const RecipeItem({
    this.id,
    required this.recipeId,
    required this.foodId,
    required this.quantityGrams,
    this.sortOrder = 0,
  });
}
