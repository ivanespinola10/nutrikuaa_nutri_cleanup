import '../data/nutri_database.dart';
import '../domain/food.dart';

class FoodSnapshotService {
  final NutriDatabase database;

  FoodSnapshotService({NutriDatabase? database})
      : database = database ?? NutriDatabase.instance;

  Future<Food> materializeOfficialFood(Food officialFood) async {
    if (officialFood.sourceType != FoodSourceType.officialDatabase) {
      throw ArgumentError(
        'Only foods from the official catalog can be materialized.',
      );
    }

    final sourceFoodId = officialFood.sourceFoodId;
    final sourceName = officialFood.sourceName;

    if (sourceFoodId == null || sourceFoodId.isEmpty) {
      throw ArgumentError('Official food is missing sourceFoodId.');
    }
    if (sourceName == null || sourceName.isEmpty) {
      throw ArgumentError('Official food is missing sourceName.');
    }

    final db = await database.database;
    final existing = await db.query(
      'foods',
      columns: ['id'],
      where: '''
        source_type = ? AND
        source_name = ? AND
        source_food_id = ? AND
        COALESCE(source_release, '') = ?
      ''',
      whereArgs: [
        FoodSourceType.officialSnapshot.name,
        sourceName,
        sourceFoodId,
        officialFood.sourceRelease ?? '',
      ],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final existingFood = await database.getFood(existing.first['id'] as int);
      if (existingFood != null) return existingFood;
    }

    final snapshot = Food(
      name: officialFood.name,
      brand: officialFood.brand,
      countryCode: officialFood.countryCode,
      sourceType: FoodSourceType.officialSnapshot,
      sourceName: officialFood.sourceName,
      sourceFoodId: officialFood.sourceFoodId,
      sourceRelease: officialFood.sourceRelease,
      servingQuantity: officialFood.servingQuantity,
      servingUnit: officialFood.servingUnit,
      householdMeasure: officialFood.householdMeasure,
      notes: officialFood.notes,
      nutrients: List.unmodifiable(officialFood.nutrients),
      portions: List.unmodifiable(officialFood.portions),
    );

    final id = await database.createFood(snapshot);
    return (await database.getFood(id))!;
  }
}
