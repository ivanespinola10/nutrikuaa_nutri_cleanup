import '../data/nutri_database.dart';
import '../domain/food.dart';
import '../domain/nutrition/nutrient.dart';

class FoodLibraryService {
  final NutriDatabase database;

  FoodLibraryService({NutriDatabase? database})
      : database = database ?? NutriDatabase.instance;

  Future<int> addBrandedFood({
    required String name,
    required String brand,
    required List<NutrientValue> nutrients,
    String? countryCode,
    double? servingQuantity,
    String? servingUnit,
    String? householdMeasure,
    String? notes,
  }) {
    return database.createFood(
      Food(
        name: name,
        brand: brand,
        countryCode: countryCode,
        sourceType: FoodSourceType.brandLabel,
        sourceName: 'Nutrition label entered by professional',
        servingQuantity: servingQuantity,
        servingUnit: servingUnit,
        householdMeasure: householdMeasure,
        notes: notes,
        nutrients: nutrients,
      ),
    );
  }

  Future<int> addProfessionalFood({
    required String name,
    required List<NutrientValue> nutrients,
    String? countryCode,
    double? servingQuantity,
    String? servingUnit,
    String? householdMeasure,
    String? notes,
  }) {
    return database.createFood(
      Food(
        name: name,
        countryCode: countryCode,
        sourceType: FoodSourceType.professionalCustom,
        sourceName: 'Professional library',
        servingQuantity: servingQuantity,
        servingUnit: servingUnit,
        householdMeasure: householdMeasure,
        notes: notes,
        nutrients: nutrients,
      ),
    );
  }

  Future<int> copyAsProfessionalFood(
    Food source, {
    String? name,
    String? brand,
    String? countryCode,
  }) {
    final provenance = [
      if (source.sourceName != null) source.sourceName!,
      if (source.sourceFoodId != null) 'ID ' + source.sourceFoodId!,
      if (source.sourceRelease != null) source.sourceRelease!,
    ].join(' · ');

    return database.createFood(
      Food(
        name: name ?? source.name,
        brand: brand ?? source.brand,
        countryCode: countryCode ?? source.countryCode,
        sourceType: FoodSourceType.professionalCustom,
        sourceName: provenance.isEmpty
            ? 'Professional copy'
            : 'Professional copy of ' + provenance,
        sourceFoodId: source.sourceFoodId,
        sourceRelease: source.sourceRelease,
        servingQuantity: source.servingQuantity,
        servingUnit: source.servingUnit,
        householdMeasure: source.householdMeasure,
        notes: source.notes,
        nutrients: List.unmodifiable(source.nutrients),
        portions: List.unmodifiable(source.portions),
      ),
    );
  }

  Future<int> update(Food food) => database.updateFood(food);

  Future<List<Food>> search(
    String query, {
    String? countryCode,
    int limit = 50,
  }) {
    return database.searchFoods(
      query,
      countryCode: countryCode,
      limit: limit,
    );
  }
}
