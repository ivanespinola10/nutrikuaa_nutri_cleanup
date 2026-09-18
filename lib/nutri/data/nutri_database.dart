import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/food.dart';
import '../domain/nutrition/nutrient.dart';
import '../domain/patient.dart';

class NutriDatabase {
  NutriDatabase._();

  static final NutriDatabase instance = NutriDatabase._();

  static const databaseName = 'nutrikuaa_nutri.db';
  static const databaseVersion = 4;

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final path = kIsWeb
        ? databaseName
        : join(await getDatabasesPath(), databaseName);

    _database = await openDatabase(
      path,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );

    return _database!;
  }

  Future<void> close() async {
    final db = _database;
    if (db == null) return;
    await db.close();
    _database = null;
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        brand TEXT,
        country_code TEXT,
        source_type TEXT NOT NULL,
        source_name TEXT,
        source_food_id TEXT,
        source_release TEXT,
        serving_quantity REAL,
        serving_unit TEXT,
        household_measure TEXT,
        notes TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE food_nutrients (
        food_id INTEGER NOT NULL,
        nutrient_code TEXT NOT NULL,
        value_per_100g REAL NOT NULL,
        unit TEXT NOT NULL,
        PRIMARY KEY (food_id, nutrient_code),
        FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE food_portions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        food_id INTEGER NOT NULL,
        amount REAL,
        measure TEXT,
        gram_weight REAL NOT NULL,
        modifier TEXT,
        sequence INTEGER,
        FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE patients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL DEFAULT '',
        date_of_birth TEXT,
        sex TEXT,
        email TEXT,
        phone TEXT,
        notes TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE nutrition_targets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        nutrient_code TEXT NOT NULL,
        target_value REAL NOT NULL,
        unit TEXT NOT NULL,
        minimum_value REAL,
        maximum_value REAL,
        UNIQUE(patient_id, nutrient_code),
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        servings REAL NOT NULL DEFAULT 1,
        yield_grams REAL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE recipe_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        food_id INTEGER NOT NULL,
        quantity_g REAL NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
        FOREIGN KEY (food_id) REFERENCES foods(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        start_date TEXT,
        end_date TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        day_index INTEGER NOT NULL DEFAULT 0,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (plan_id) REFERENCES meal_plans(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_id INTEGER NOT NULL,
        item_type TEXT NOT NULL CHECK(item_type IN ('food', 'recipe')),
        food_id INTEGER,
        recipe_id INTEGER,
        quantity_g REAL,
        servings REAL,
        notes TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (meal_id) REFERENCES meals(id) ON DELETE CASCADE,
        FOREIGN KEY (food_id) REFERENCES foods(id),
        FOREIGN KEY (recipe_id) REFERENCES recipes(id),
        CHECK (
          (item_type = 'food' AND food_id IS NOT NULL AND recipe_id IS NULL) OR
          (item_type = 'recipe' AND recipe_id IS NOT NULL AND food_id IS NULL)
        )
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_foods_name ON foods(name COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX idx_foods_brand ON foods(brand COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX idx_foods_country ON foods(country_code)',
    );
    await db.execute(
      'CREATE INDEX idx_recipes_name ON recipes(name COLLATE NOCASE)',
    );
    await db.execute('''
      CREATE UNIQUE INDEX idx_official_food_snapshot
      ON foods(source_name, source_food_id, source_release)
      WHERE source_type = 'officialSnapshot'
    ''');
    await db.execute(
      'CREATE INDEX idx_meals_plan_day ON meals(plan_id, day_index, sort_order)',
    );
  }

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE foods ADD COLUMN source_release TEXT');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS food_portions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          food_id INTEGER NOT NULL,
          amount REAL,
          measure TEXT,
          gram_weight REAL NOT NULL,
          modifier TEXT,
          sequence INTEGER,
          FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_official_food_snapshot
        ON foods(source_name, source_food_id, source_release)
        WHERE source_type = 'officialSnapshot'
      ''');
    }

    // Future migrations must be additive and preserve professional data.
  }

  Future<int> createFood(Food food) async {
    final db = await database;

    return db.transaction((txn) async {
      final foodId = await txn.insert('foods', _foodToMap(food));

      for (final nutrient in food.nutrients) {
        await txn.insert(
          'food_nutrients',
          _nutrientToMap(foodId, nutrient),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final portion in food.portions) {
        await txn.insert(
          'food_portions',
          _portionToMap(foodId, portion),
        );
      }

      return foodId;
    });
  }

  Future<void> updateFood(Food food) async {
    final foodId = food.id;
    if (foodId == null) {
      throw ArgumentError('A persisted food must have an id before update.');
    }
    if (!food.isUserEditable) {
      throw StateError('Official database foods are read-only.');
    }

    final db = await database;

    await db.transaction((txn) async {
      await txn.update(
        'foods',
        _foodToMap(food.copyWith(updatedAt: DateTime.now())),
        where: 'id = ?',
        whereArgs: [foodId],
      );

      await txn.delete(
        'food_nutrients',
        where: 'food_id = ?',
        whereArgs: [foodId],
      );

      for (final nutrient in food.nutrients) {
        await txn.insert(
          'food_nutrients',
          _nutrientToMap(foodId, nutrient),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await txn.delete(
        'food_portions',
        where: 'food_id = ?',
        whereArgs: [foodId],
      );

      for (final portion in food.portions) {
        await txn.insert(
          'food_portions',
          _portionToMap(foodId, portion),
        );
      }
    });
  }

  Future<Food?> getFood(int id) async {
    final db = await database;
    final rows = await db.query(
      'foods',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final nutrients = await _getFoodNutrients(db, id);
    final portions = await _getFoodPortions(db, id);
    return _foodFromMap(rows.first, nutrients, portions);
  }

  Future<List<Food>> searchFoods(
    String query, {
    String? countryCode,
    bool includeArchived = false,
    int limit = 50,
  }) async {
    final db = await database;
    final trimmed = query.trim();

    final where = <String>[];
    final args = <Object?>[];

    if (!includeArchived) {
      where.add('is_archived = 0');
    }

    if (trimmed.isNotEmpty) {
      where.add('(name LIKE ? OR brand LIKE ?)');
      args
        ..add('%$trimmed%')
        ..add('%$trimmed%');
    }

    if (countryCode != null && countryCode.trim().isNotEmpty) {
      where.add('(country_code = ? OR country_code IS NULL)');
      args.add(countryCode.trim().toUpperCase());
    }

    final rows = await db.query(
      'foods',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: '''
        CASE source_type
          WHEN 'professionalCustom' THEN 0
          WHEN 'brandLabel' THEN 1
          WHEN 'imported' THEN 2
          ELSE 3
        END,
        name COLLATE NOCASE
      ''',
      limit: limit,
    );

    final foods = <Food>[];
    for (final row in rows) {
      final id = row['id'] as int;
      final nutrients = await _getFoodNutrients(db, id);
      final portions = await _getFoodPortions(db, id);
      foods.add(_foodFromMap(row, nutrients, portions));
    }

    return foods;
  }

  Future<int> createPatient(Patient patient) async {
    final db = await database;
    return db.insert('patients', {
      'first_name': patient.firstName,
      'last_name': patient.lastName,
      'date_of_birth': patient.dateOfBirth?.toIso8601String(),
      'sex': patient.sex,
      'email': patient.email,
      'phone': patient.phone,
      'notes': patient.notes,
      'is_active': patient.isActive ? 1 : 0,
      'created_at': patient.createdAt.toIso8601String(),
      'updated_at': patient.updatedAt.toIso8601String(),
    });
  }

  Future<void> upsertNutritionTarget(NutritionTarget target) async {
    final db = await database;

    await db.insert(
      'nutrition_targets',
      {
        'patient_id': target.patientId,
        'nutrient_code': target.nutrientCode,
        'target_value': target.targetValue,
        'unit': target.unit.name,
        'minimum_value': target.minimumValue,
        'maximum_value': target.maximumValue,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<NutritionTarget>> getNutritionTargets(int patientId) async {
    final db = await database;
    final rows = await db.query(
      'nutrition_targets',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'nutrient_code',
    );

    return rows
        .map(
          (row) => NutritionTarget(
            id: row['id'] as int?,
            patientId: row['patient_id'] as int,
            nutrientCode: row['nutrient_code'] as String,
            targetValue: (row['target_value'] as num).toDouble(),
            unit: NutrientUnit.values.byName(row['unit'] as String),
            minimumValue: (row['minimum_value'] as num?)?.toDouble(),
            maximumValue: (row['maximum_value'] as num?)?.toDouble(),
          ),
        )
        .toList();
  }

  static Map<String, Object?> _foodToMap(Food food) {
    return {
      'name': food.name.trim(),
      'brand': _nullIfBlank(food.brand),
      'country_code': _nullIfBlank(food.countryCode)?.toUpperCase(),
      'source_type': food.sourceType.name,
      'source_name': _nullIfBlank(food.sourceName),
      'source_food_id': _nullIfBlank(food.sourceFoodId),
      'source_release': _nullIfBlank(food.sourceRelease),
      'serving_quantity': food.servingQuantity,
      'serving_unit': _nullIfBlank(food.servingUnit),
      'household_measure': _nullIfBlank(food.householdMeasure),
      'notes': _nullIfBlank(food.notes),
      'is_archived': food.isArchived ? 1 : 0,
      'created_at': food.createdAt.toIso8601String(),
      'updated_at': food.updatedAt.toIso8601String(),
    };
  }

  static Map<String, Object?> _nutrientToMap(
    int foodId,
    NutrientValue nutrient,
  ) {
    return {
      'food_id': foodId,
      'nutrient_code': nutrient.code,
      'value_per_100g': nutrient.valuePer100g,
      'unit': nutrient.unit.name,
    };
  }

  static Map<String, Object?> _portionToMap(
    int foodId,
    FoodPortion portion,
  ) {
    return {
      'food_id': foodId,
      'amount': portion.amount,
      'measure': _nullIfBlank(portion.measure),
      'gram_weight': portion.gramWeight,
      'modifier': _nullIfBlank(portion.modifier),
      'sequence': portion.sequence,
    };
  }

  static Future<List<NutrientValue>> _getFoodNutrients(
    DatabaseExecutor db,
    int foodId,
  ) async {
    final rows = await db.query(
      'food_nutrients',
      where: 'food_id = ?',
      whereArgs: [foodId],
      orderBy: 'nutrient_code',
    );

    return rows
        .map(
          (row) => NutrientValue(
            code: row['nutrient_code'] as String,
            valuePer100g: (row['value_per_100g'] as num).toDouble(),
            unit: NutrientUnit.values.byName(row['unit'] as String),
          ),
        )
        .toList();
  }

  static Future<List<FoodPortion>> _getFoodPortions(
    DatabaseExecutor db,
    int foodId,
  ) async {
    final rows = await db.query(
      'food_portions',
      where: 'food_id = ?',
      whereArgs: [foodId],
      orderBy: 'sequence, id',
    );

    return rows
        .map(
          (row) => FoodPortion(
            amount: (row['amount'] as num?)?.toDouble(),
            measure: row['measure'] as String?,
            gramWeight: (row['gram_weight'] as num).toDouble(),
            modifier: row['modifier'] as String?,
            sequence: row['sequence'] as int?,
          ),
        )
        .toList();
  }

  static Food _foodFromMap(
    Map<String, Object?> row,
    List<NutrientValue> nutrients,
    List<FoodPortion> portions,
  ) {
    return Food(
      id: row['id'] as int?,
      name: row['name'] as String,
      brand: row['brand'] as String?,
      countryCode: row['country_code'] as String?,
      sourceType: FoodSourceType.values.byName(row['source_type'] as String),
      sourceName: row['source_name'] as String?,
      sourceFoodId: row['source_food_id'] as String?,
      sourceRelease: row['source_release'] as String?,
      servingQuantity: (row['serving_quantity'] as num?)?.toDouble(),
      servingUnit: row['serving_unit'] as String?,
      householdMeasure: row['household_measure'] as String?,
      notes: row['notes'] as String?,
      isArchived: (row['is_archived'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      nutrients: nutrients,
      portions: portions,
    );
  }

  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
