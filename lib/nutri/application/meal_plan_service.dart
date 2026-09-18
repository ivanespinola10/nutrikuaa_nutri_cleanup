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
