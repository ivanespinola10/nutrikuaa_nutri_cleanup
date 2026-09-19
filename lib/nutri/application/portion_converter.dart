import '../domain/food.dart';

class PortionConverter {
  PortionConverter._();

  static double toGrams({
    required FoodPortion portion,
    required double requestedAmount,
  }) {
    if (requestedAmount <= 0) return 0;

    final baseAmount =
        portion.amount == null || portion.amount! <= 0 ? 1.0 : portion.amount!;

    return portion.gramWeight * requestedAmount / baseAmount;
  }
}
