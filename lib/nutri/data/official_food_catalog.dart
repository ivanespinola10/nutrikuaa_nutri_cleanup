import 'package:sqflite/sqflite.dart';

import '../domain/food.dart';
import '../domain/nutrition/nutrient.dart';
import 'official_food_catalog_installer.dart';

typedef OfficialCatalogOpener = Future<Database?> Function();

class OfficialFoodCatalog {
  final OfficialCatalogOpener _open;

  OfficialFoodCatalog({OfficialCatalogOpener? open})
      : _open = open ?? OfficialFoodCatalogInstaller.openReadOnly;

  Future<List<Food>> search(
    String query, {
    int limit = 50,
  }) async {
    final db = await _open();
    if (db == null) return const [];

    final trimmed = query.trim();
    final rows = await db.query(
      'foods',
      where: trimmed.isEmpty ? null : 'name LIKE ?',
      whereArgs: trimmed.isEmpty ? null : ['%$trimmed%'],
      orderBy: 'name COLLATE NOCASE',
      limit: limit,
    );

    final foods = <Food>[];
    for (final row in rows) {
      foods.add(await _hydrate(db, row));
    }
    return foods;
  }

  Future<Food?> getBySourceFoodId(String sourceFoodId) async {
    final db = await _open();
    if (db == null) return null;

    final rows = await db.query(
      'foods',
      where: 'source_food_id = ?',
      whereArgs: [sourceFoodId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _hydrate(db, rows.first);
  }

  Future<Food> _hydrate(
    Database db,
    Map<String, Object?> row,
  ) async {
    final foodId = row['id'] as int;

    final nutrientRows = await db.query(
      'food_nutrients',
      where: 'food_id = ?',
      whereArgs: [foodId],
      orderBy: 'nutrient_code',
    );

    final portionRows = await db.query(
      'food_portions',
      where: 'food_id = ?',
      whereArgs: [foodId],
      orderBy: 'sequence, id',
    );

    return Food(
      name: row['name'] as String,
      sourceType: FoodSourceType.officialDatabase,
      sourceName: row['source_name'] as String?,
      sourceFoodId: row['source_food_id'] as String?,
      sourceRelease: row['source_release'] as String?,
      nutrients: nutrientRows
          .map(
            (nutrient) => NutrientValue(
              code: nutrient['nutrient_code'] as String,
              valuePer100g:
                  (nutrient['value_per_100g'] as num).toDouble(),
              unit: NutrientUnit.values.byName(
                nutrient['unit'] as String,
              ),
            ),
          )
          .toList(),
      portions: portionRows
          .map(
            (portion) => FoodPortion(
              amount: (portion['amount'] as num?)?.toDouble(),
              measure: portion['measure'] as String?,
              gramWeight: (portion['gram_weight'] as num).toDouble(),
              modifier: portion['modifier'] as String?,
              sequence: portion['sequence'] as int?,
            ),
          )
          .toList(),
    );
  }
}
