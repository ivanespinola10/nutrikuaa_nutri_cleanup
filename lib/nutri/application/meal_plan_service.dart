import '../data/nutri_database.dart';
import '../domain/meal_plan.dart';

class MealWithItems {
  final Meal meal;
  final List<MealItem> items;

  const MealWithItems({
    required this.meal,
    required this.items,
  });
}

class MealPlanDetails {
  final MealPlan plan;
  final List<MealWithItems> meals;

  const MealPlanDetails({
    required this.plan,
    required this.meals,
  });
}

class MealPlanService {
  final NutriDatabase database;

  MealPlanService({NutriDatabase? database})
      : database = database ?? NutriDatabase.instance;

  Future<int> createPlan(MealPlan plan) async {
    final db = await database.database;
    return db.insert('meal_plans', {
      'patient_id': plan.patientId,
      'name': plan.name.trim(),
      'start_date': plan.startDate?.toIso8601String(),
      'end_date': plan.endDate?.toIso8601String(),
      'notes': plan.notes,
      'created_at': plan.createdAt.toIso8601String(),
      'updated_at': plan.updatedAt.toIso8601String(),
    });
  }

  Future<int> addMeal({
    required int planId,
    required int dayIndex,
    required String name,
    int sortOrder = 0,
  }) async {
    if (dayIndex < 0) {
      throw ArgumentError('dayIndex cannot be negative.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Meal name is required.');
    }

    final db = await database.database;
    return db.insert('meals', {
      'plan_id': planId,
      'day_index': dayIndex,
      'name': name.trim(),
      'sort_order': sortOrder,
    });
  }

  Future<int> getOrCreateMeal({
    required int planId,
    required int dayIndex,
    required String name,
    int sortOrder = 0,
  }) async {
    final db = await database.database;
    final rows = await db.query(
      'meals',
      columns: ['id'],
      where: 'plan_id = ? AND day_index = ? AND name = ?',
      whereArgs: [planId, dayIndex, name.trim()],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return rows.first['id'] as int;
    }

    return addMeal(
      planId: planId,
      dayIndex: dayIndex,
      name: name,
      sortOrder: sortOrder,
    );
  }

  Future<void> updateFoodQuantity({
    required int mealItemId,
    required double quantityGrams,
  }) async {
    if (quantityGrams <= 0) {
      throw ArgumentError('Food quantity must be greater than zero.');
    }

    final db = await database.database;
    await db.update(
      'meal_items',
      {'quantity_g': quantityGrams},
      where: 'id = ? AND item_type = ?',
      whereArgs: [mealItemId, MealItemType.food.name],
    );
  }

  Future<void> removeMealItem(int mealItemId) async {
    final db = await database.database;
    await db.delete(
      'meal_items',
      where: 'id = ?',
      whereArgs: [mealItemId],
    );
  }

  Future<void> updateRecipeServings({
    required int mealItemId,
    required double servings,
  }) async {
    if (servings <= 0) {
      throw ArgumentError('Recipe servings must be greater than zero.');
    }

    final db = await database.database;
    await db.update(
      'meal_items',
      {'servings': servings},
      where: 'id = ? AND item_type = ?',
      whereArgs: [mealItemId, MealItemType.recipe.name],
    );
  }

  Future<void> clearMeal(int mealId) async {
    final db = await database.database;
    await db.delete(
      'meal_items',
      where: 'meal_id = ?',
      whereArgs: [mealId],
    );
  }

  Future<void> copyMealItems({
    required int sourceMealId,
    required int targetMealId,
    bool replaceTarget = true,
  }) async {
    final db = await database.database;

    await db.transaction((txn) async {
      if (replaceTarget) {
        await txn.delete(
          'meal_items',
          where: 'meal_id = ?',
          whereArgs: [targetMealId],
        );
      }

      final rows = await txn.query(
        'meal_items',
        where: 'meal_id = ?',
        whereArgs: [sourceMealId],
        orderBy: 'sort_order, id',
      );

      for (final row in rows) {
        await txn.insert('meal_items', {
          'meal_id': targetMealId,
          'item_type': row['item_type'],
          'food_id': row['food_id'],
          'recipe_id': row['recipe_id'],
          'quantity_g': row['quantity_g'],
          'servings': row['servings'],
          'notes': row['notes'],
          'sort_order': row['sort_order'],
        });
      }
    });
  }

  Future<void> copyDay({
    required int planId,
    required int sourceDayIndex,
    required int targetDayIndex,
    bool replaceTarget = true,
  }) async {
    if (sourceDayIndex == targetDayIndex) {
      throw ArgumentError('Source and target day must be different.');
    }

    final db = await database.database;

    await db.transaction((txn) async {
      final sourceMeals = await txn.query(
        'meals',
        where: 'plan_id = ? AND day_index = ?',
        whereArgs: [planId, sourceDayIndex],
        orderBy: 'sort_order, id',
      );

      for (final sourceMeal in sourceMeals) {
        final name = sourceMeal['name'] as String;
        final sortOrder = sourceMeal['sort_order'] as int? ?? 0;

        final targetRows = await txn.query(
          'meals',
          columns: ['id'],
          where: 'plan_id = ? AND day_index = ? AND name = ?',
          whereArgs: [planId, targetDayIndex, name],
          limit: 1,
        );

        final targetMealId = targetRows.isNotEmpty
            ? targetRows.first['id'] as int
            : await txn.insert('meals', {
                'plan_id': planId,
                'day_index': targetDayIndex,
                'name': name,
                'sort_order': sortOrder,
              });

        if (replaceTarget) {
          await txn.delete(
            'meal_items',
            where: 'meal_id = ?',
            whereArgs: [targetMealId],
          );
        }

        final items = await txn.query(
          'meal_items',
          where: 'meal_id = ?',
          whereArgs: [sourceMeal['id']],
          orderBy: 'sort_order, id',
        );

        for (final item in items) {
          await txn.insert('meal_items', {
            'meal_id': targetMealId,
            'item_type': item['item_type'],
            'food_id': item['food_id'],
            'recipe_id': item['recipe_id'],
            'quantity_g': item['quantity_g'],
            'servings': item['servings'],
            'notes': item['notes'],
            'sort_order': item['sort_order'],
          });
        }
      }
    });
  }

  Future<int> addFood({
    required int mealId,
    required int foodId,
    required double quantityGrams,
    String? notes,
    int sortOrder = 0,
  }) async {
    if (quantityGrams <= 0) {
      throw ArgumentError('Food quantity must be greater than zero.');
    }

    final db = await database.database;
    return db.insert('meal_items', {
      'meal_id': mealId,
      'item_type': MealItemType.food.name,
      'food_id': foodId,
      'recipe_id': null,
      'quantity_g': quantityGrams,
      'servings': null,
      'notes': notes,
      'sort_order': sortOrder,
    });
  }

  Future<int> addRecipe({
    required int mealId,
    required int recipeId,
    double servings = 1,
    String? notes,
    int sortOrder = 0,
  }) async {
    if (servings <= 0) {
      throw ArgumentError('Recipe servings must be greater than zero.');
    }

    final db = await database.database;
    return db.insert('meal_items', {
      'meal_id': mealId,
      'item_type': MealItemType.recipe.name,
      'food_id': null,
      'recipe_id': recipeId,
      'quantity_g': null,
      'servings': servings,
      'notes': notes,
      'sort_order': sortOrder,
    });
  }

  Future<MealPlanDetails?> getById(int planId) async {
    final db = await database.database;
    final planRows = await db.query(
      'meal_plans',
      where: 'id = ?',
      whereArgs: [planId],
      limit: 1,
    );

    if (planRows.isEmpty) return null;

    final mealRows = await db.query(
      'meals',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'day_index, sort_order, id',
    );

    final meals = <MealWithItems>[];
    for (final mealRow in mealRows) {
      final mealId = mealRow['id'] as int;
      final itemRows = await db.query(
        'meal_items',
        where: 'meal_id = ?',
        whereArgs: [mealId],
        orderBy: 'sort_order, id',
      );

      meals.add(
        MealWithItems(
          meal: _mealFromMap(mealRow),
          items: itemRows.map(_itemFromMap).toList(),
        ),
      );
    }

    return MealPlanDetails(
      plan: _planFromMap(planRows.first),
      meals: meals,
    );
  }

  Future<List<MealPlan>> listForPatient(int patientId) async {
    final db = await database.database;
    final rows = await db.query(
      'meal_plans',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'created_at DESC',
    );

    return rows.map(_planFromMap).toList();
  }

  Future<int> duplicatePlan(
    int planId, {
    String? newName,
    DateTime? newStartDate,
    DateTime? newEndDate,
  }) async {
    final source = await getById(planId);
    if (source == null) {
      throw StateError('Meal plan does not exist.');
    }

    final db = await database.database;

    return db.transaction((txn) async {
      final now = DateTime.now();
      final newPlanId = await txn.insert('meal_plans', {
        'patient_id': source.plan.patientId,
        'name': newName ?? (source.plan.name + ' (copy)'),
        'start_date': newStartDate?.toIso8601String(),
        'end_date': newEndDate?.toIso8601String(),
        'notes': source.plan.notes,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      for (final mealWithItems in source.meals) {
        final newMealId = await txn.insert('meals', {
          'plan_id': newPlanId,
          'day_index': mealWithItems.meal.dayIndex,
          'name': mealWithItems.meal.name,
          'sort_order': mealWithItems.meal.sortOrder,
        });

        for (final item in mealWithItems.items) {
          await txn.insert('meal_items', {
            'meal_id': newMealId,
            'item_type': item.itemType.name,
            'food_id': item.foodId,
            'recipe_id': item.recipeId,
            'quantity_g': item.quantityGrams,
            'servings': item.servings,
            'notes': item.notes,
            'sort_order': item.sortOrder,
          });
        }
      }

      return newPlanId;
    });
  }

  static MealPlan _planFromMap(Map<String, Object?> row) {
    return MealPlan(
      id: row['id'] as int,
      patientId: row['patient_id'] as int,
      name: row['name'] as String,
      startDate: row['start_date'] == null
          ? null
          : DateTime.parse(row['start_date'] as String),
      endDate: row['end_date'] == null
          ? null
          : DateTime.parse(row['end_date'] as String),
      notes: row['notes'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  static Meal _mealFromMap(Map<String, Object?> row) {
    return Meal(
      id: row['id'] as int,
      planId: row['plan_id'] as int,
      dayIndex: row['day_index'] as int,
      name: row['name'] as String,
      sortOrder: row['sort_order'] as int? ?? 0,
    );
  }

  static MealItem _itemFromMap(Map<String, Object?> row) {
    return MealItem(
      id: row['id'] as int,
      mealId: row['meal_id'] as int,
      itemType: MealItemType.values.byName(row['item_type'] as String),
      foodId: row['food_id'] as int?,
      recipeId: row['recipe_id'] as int?,
      quantityGrams: (row['quantity_g'] as num?)?.toDouble(),
      servings: (row['servings'] as num?)?.toDouble(),
      notes: row['notes'] as String?,
      sortOrder: row['sort_order'] as int? ?? 0,
    );
  }
}
