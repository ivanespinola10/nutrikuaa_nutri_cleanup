import 'package:flutter_test/flutter_test.dart';
import 'package:nutrikuaa_app/nutri/application/official_food_search_aliases.dart';

void main() {
  test('maps common Spanish foods to official English catalog terms', () {
    expect(
      OfficialFoodSearchAliases.forOfficialCatalog('leche'),
      'milk',
    );
    expect(
      OfficialFoodSearchAliases.forOfficialCatalog('arroz'),
      'rice',
    );
    expect(
      OfficialFoodSearchAliases.forOfficialCatalog('pollo'),
      'chicken',
    );
  });

  test('maps common Portuguese foods to official English catalog terms', () {
    expect(
      OfficialFoodSearchAliases.forOfficialCatalog('leite'),
      'milk',
    );
    expect(
      OfficialFoodSearchAliases.forOfficialCatalog('frango'),
      'chicken',
    );
  });

  test('keeps unknown search terms unchanged', () {
    expect(
      OfficialFoodSearchAliases.forOfficialCatalog('quinoa'),
      'quinoa',
    );
  });
}
