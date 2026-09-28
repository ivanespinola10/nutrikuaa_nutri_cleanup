import 'package:sqflite/sqflite.dart';

import '../domain/food.dart';
import '../domain/nutrition/nutrient.dart';
import 'official_food_catalog_installer.dart';

typedef OfficialCatalogOpener = Future<Database?> Function();

class OfficialFoodCatalog {
  final OfficialCatalogOpener _open;

  OfficialFoodCatalog({OfficialCatalogOpener? open})
      : _open = open ?? OfficialFoodCatalogInstaller.openReadOnly;

  Future<int> count() async {
    final db = await _open();
    if (db == null) return 0;

    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM foods');
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<List<Food>> search(
    String query, {
    int limit = 50,
  }) async {
    final db = await _open();
    if (db == null) return const [];

    final trimmed = query.trim();
    // Match all words regardless of order or punctuation. INSTR treats user
    // input literally, so '%' and '_' cannot broaden a search as SQL wildcards.
    final tokens = trimmed
        .split(RegExp(r'[\s,;]+'))
        .where((token) => token.isNotEmpty)
        .toList();
    final List<Map<String, Object?>> rows;
    if (tokens.isEmpty) {
      rows = await db.query(
        'foods',
        orderBy: 'name COLLATE NOCASE',
        limit: limit,
      );
    } else {
      final predicates = List.filled(
        tokens.length,
        'INSTR(LOWER(name), LOWER(?)) > 0',
      ).join(' AND ');
      rows = await db.rawQuery(
        'SELECT * FROM foods WHERE $predicates '
        'ORDER BY CASE '
        'WHEN LOWER(name) = LOWER(?) THEN 0 '
        "WHEN INSTR(LOWER(name), LOWER(?)) = 1 THEN 1 "
        'ELSE 2 END, name COLLATE NOCASE LIMIT ?',
        [...tokens, trimmed, tokens.first, limit],
      );
    }

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
