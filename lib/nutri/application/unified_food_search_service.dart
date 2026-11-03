import '../data/nutri_database.dart';
import '../data/official_food_catalog.dart';
import '../domain/food.dart';
import 'official_food_search_aliases.dart';

class FoodSearchResults {
  final List<Food> professional;
  final List<Food> official;

  const FoodSearchResults({required this.professional, required this.official});

  bool get isEmpty => professional.isEmpty && official.isEmpty;

  List<Food> get combined => [...professional, ...official];
}

class UnifiedFoodSearchService {
  final NutriDatabase privateDatabase;
  final OfficialFoodCatalog officialCatalog;

  UnifiedFoodSearchService({
    NutriDatabase? privateDatabase,
    OfficialFoodCatalog? officialCatalog,
  }) : privateDatabase = privateDatabase ?? NutriDatabase.instance,
       officialCatalog = officialCatalog ?? OfficialFoodCatalog();

  Future<FoodSearchResults> search(
    String query, {
    String? countryCode,
    int professionalLimit = 20,
    int officialLimit = 50,
    bool includeProfessional = true,
    bool includeOfficial = true,
  }) async {
    final trimmed = query.trim();
    final officialQuery = OfficialFoodSearchAliases.forOfficialCatalog(trimmed);

    final professional = <Food>[];
    if (includeProfessional) {
      final privateQueries = <String>{
        trimmed,
        officialQuery,
        ...OfficialFoodSearchAliases.forProfessionalCatalog(trimmed),
      };
      final seen = <String>{};

      for (final privateQuery in privateQueries) {
        final matches = await privateDatabase.searchFoods(
          privateQuery,
          countryCode: countryCode,
          limit: professionalLimit,
        );

        for (final food in matches) {
          final key = food.id != null
              ? 'id:${food.id}'
              : '${food.sourceType.name}|${food.name}|${food.brand ?? ''}';
          if (seen.add(key)) professional.add(food);
          if (professional.length >= professionalLimit) break;
        }
        if (professional.length >= professionalLimit) break;
      }
    }

    List<Food> official = <Food>[];
    if (includeOfficial) {
      try {
        official = await officialCatalog.search(
          officialQuery,
          limit: officialLimit,
        );
      } catch (_) {
        official = const [];
      }
    }

    final snapshotKeys = professional
        .where((food) => food.sourceType == FoodSourceType.officialSnapshot)
        .map(_sourceKey)
        .whereType<String>()
        .toSet();

    official = official.where((food) {
      final key = _sourceKey(food);
      return key == null || !snapshotKeys.contains(key);
    }).toList();

    return FoodSearchResults(professional: professional, official: official);
  }

  static String? _sourceKey(Food food) {
    final sourceName = food.sourceName;
    final sourceFoodId = food.sourceFoodId;
    if (sourceName == null || sourceFoodId == null) return null;

    return [sourceName, sourceFoodId, food.sourceRelease ?? ''].join('|');
  }
}
