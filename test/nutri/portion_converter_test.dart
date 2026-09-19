import 'package:flutter_test/flutter_test.dart';
import 'package:nutrikuaa_app/nutri/application/portion_converter.dart';
import 'package:nutrikuaa_app/nutri/domain/food.dart';

void main() {
  test('converts household portions to grams', () {
    const portion = FoodPortion(
      amount: 1,
      measure: 'pote',
      gramWeight: 150,
    );

    expect(
      PortionConverter.toGrams(
        portion: portion,
        requestedAmount: 2,
      ),
      300,
    );
  });

  test('supports portions whose source amount is not one', () {
    const portion = FoodPortion(
      amount: 0.5,
      measure: 'taza',
      gramWeight: 90,
    );

    expect(
      PortionConverter.toGrams(
        portion: portion,
        requestedAmount: 1,
      ),
      180,
    );
  });
}
