import '../data/nutri_database.dart';
import '../domain/recipe.dart';

class RecipeIngredientInput {
  final int foodId;
  final double quantityGrams;
  final int sortOrder;

  const RecipeIngredientInput({
    required this.foodId,
    required this.quantityGrams,
    this.sortOrder = 0,
  });
}

class RecipeDetails {
  final Recipe recipe;
  final List<RecipeItem> items;

  const RecipeDetails({
    required this.recipe,
    required this.items,
  });
}

class RecipeService {
  final NutriDatabase database;

  RecipeService({NutriDatabase? database})
      : database = database ?? NutriDatabase.instance;

  Future<int> create(
    Recipe recipe,
    List<RecipeIngredientInput> ingredients,
  ) async {
    if (recipe.name.trim().isEmpty) {
      throw ArgumentError('Recipe name is required.');
    }
    if (recipe.servings <= 0) {
      throw ArgumentError('Recipe servings must be greater than zero.');
    }

    final db = await database.database;

    return db.transaction((txn) async {
      final recipeId = await txn.insert('recipes', {
        'name': recipe.name.trim(),
        'description': recipe.description,
        'servings': recipe.servings,
        'yield_grams': recipe.yieldGrams,
        'notes': recipe.notes,
        'created_at': recipe.createdAt.toIso8601String(),
        'updated_at': recipe.updatedAt.toIso8601String(),
      });

      for (final ingredient in ingredients) {
        if (ingredient.quantityGrams <= 0) {
          throw ArgumentError('Recipe ingredient quantity must be positive.');
        }

        await txn.insert('recipe_items', {
          'recipe_id': recipeId,
          'food_id': ingredient.foodId,
          'quantity_g': ingredient.quantityGrams,
          'sort_order': ingredient.sortOrder,
        });
      }

      return recipeId;
    });
  }

  Future<RecipeDetails?> getById(int id) async {
    final db = await database.database;
    final recipeRows = await db.query(
      'recipes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (recipeRows.isEmpty) return null;

    final itemRows = await db.query(
      'recipe_items',
      where: 'recipe_id = ?',
      whereArgs: [id],
      orderBy: 'sort_order, id',
    );

    return RecipeDetails(
      recipe: _recipeFromMap(recipeRows.first),
      items: itemRows
          .map(
            (row) => RecipeItem(
              id: row['id'] as int,
              recipeId: row['recipe_id'] as int,
              foodId: row['food_id'] as int,
              quantityGrams: (row['quantity_g'] as num).toDouble(),
              sortOrder: row['sort_order'] as int? ?? 0,
            ),
          )
          .toList(),
    );
  }

  Future<List<Recipe>> search(
    String query, {
    int limit = 100,
  }) async {
    final db = await database.database;
    final trimmed = query.trim();

    final rows = await db.query(
      'recipes',
      where: trimmed.isEmpty ? null : 'name LIKE ?',
      whereArgs: trimmed.isEmpty ? null : ['%$trimmed%'],
      orderBy: 'name COLLATE NOCASE',
      limit: limit,
    );

    return rows.map(_recipeFromMap).toList();
  }

  Future<int> duplicate(
    int recipeId, {
    String? newName,
  }) async {
    final details = await getById(recipeId);
    if (details == null) {
      throw StateError('Recipe does not exist.');
    }

    return create(
      Recipe(
        name: newName ?? (details.recipe.name + ' (copy)'),
        description: details.recipe.description,
        servings: details.recipe.servings,
        yieldGrams: details.recipe.yieldGrams,
        notes: details.recipe.notes,
      ),
      details.items
          .map(
            (item) => RecipeIngredientInput(
              foodId: item.foodId,
              quantityGrams: item.quantityGrams,
              sortOrder: item.sortOrder,
            ),
          )
          .toList(),
    );
  }

  static Recipe _recipeFromMap(Map<String, Object?> row) {
    return Recipe(
      id: row['id'] as int,
      name: row['name'] as String,
      description: row['description'] as String?,
      servings: (row['servings'] as num).toDouble(),
      yieldGrams: (row['yield_grams'] as num?)?.toDouble(),
      notes: row['notes'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
