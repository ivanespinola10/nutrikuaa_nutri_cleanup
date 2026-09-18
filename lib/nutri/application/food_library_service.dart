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
    String? householdMeasure,
    String? notes,
  }) {
    return database.createFood(
      Food(
        name: name,
        countryCode: countryCode,
        sourceType: FoodSourceType.professionalCustom,
        sourceName: 'Professional library',
        householdMeasure: householdMeasure,
        notes: notes,
        nutrients: nutrients,
      ),
    );
  }

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
