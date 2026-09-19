import '../data/nutri_database.dart';
import '../data/official_food_catalog.dart';
import '../domain/food.dart';

class FoodSearchResults {
  final List<Food> professional;
  final List<Food> official;

  const FoodSearchResults({
    required this.professional,
    required this.official,
  });

  bool get isEmpty => professional.isEmpty && official.isEmpty;

  List<Food> get combined => [
        ...professional,
        ...official,
      ];
}

class UnifiedFoodSearchService {
  final NutriDatabase privateDatabase;
  final OfficialFoodCatalog officialCatalog;

  UnifiedFoodSearchService({
    NutriDatabase? privateDatabase,
    OfficialFoodCatalog? officialCatalog,
  })  : privateDatabase = privateDatabase ?? NutriDatabase.instance,
        officialCatalog = officialCatalog ?? OfficialFoodCatalog();

  Future<FoodSearchResults> search(
    String query, {
    String? countryCode,
    int professionalLimit = 20,
    int officialLimit = 50,
  }) async {
    final professional = await privateDatabase.searchFoods(
      query,
      countryCode: countryCode,
      limit: professionalLimit,
    );

    List<Food> official;
    try {
      official = await officialCatalog.search(
        query,
        limit: officialLimit,
      );
    } catch (_) {
      official = const [];
    }

    final snapshotKeys = professional
        .where((food) => food.sourceType == FoodSourceType.officialSnapshot)
        .map(_sourceKey)
        .whereType<String>()
        .toSet();

    official = official
        .where((food) {
          final key = _sourceKey(food);
          return key == null || !snapshotKeys.contains(key);
        })
        .toList();

    return FoodSearchResults(
      professional: professional,
      official: official,
    );
  }

  static String? _sourceKey(Food food) {
    final sourceName = food.sourceName;
    final sourceFoodId = food.sourceFoodId;
    if (sourceName == null || sourceFoodId == null) return null;

    return [
      sourceName,
      sourceFoodId,
      food.sourceRelease ?? '',
    ].join('|');
  }
}
