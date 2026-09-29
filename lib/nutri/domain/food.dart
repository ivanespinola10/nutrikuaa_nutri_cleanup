import 'nutrition/nutrient.dart';

enum FoodSourceType {
  officialDatabase,
  officialSnapshot,
  brandLabel,
  professionalCustom,
  imported,
}

class FoodPortion {
  final double? amount;
  final String? measure;
  final double gramWeight;
  final String? modifier;
  final int? sequence;

  const FoodPortion({
    this.amount,
    this.measure,
    required this.gramWeight,
    this.modifier,
    this.sequence,
  });
}

class Food {
  final int? id;
  final String name;
  final String? brand;
  final String? countryCode;
  final FoodSourceType sourceType;
  final String? sourceName;
  final String? sourceFoodId;
  final String? sourceRelease;
  final double? servingQuantity;
  final String? servingUnit;
  final String? householdMeasure;
  final String? notes;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<NutrientValue> nutrients;
  final List<FoodPortion> portions;
  /// Declared by the professional; an empty list means unknown, not allergen free.
  final List<String> allergens;

  Food({
    this.id,
    required this.name,
    this.brand,
    this.countryCode,
    required this.sourceType,
    this.sourceName,
    this.sourceFoodId,
    this.sourceRelease,
    this.servingQuantity,
    this.servingUnit,
    this.householdMeasure,
    this.notes,
    this.isArchived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.nutrients = const [],
    this.portions = const [],
    this.allergens = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isBranded => brand != null && brand!.trim().isNotEmpty;

  bool get isOfficial =>
      sourceType == FoodSourceType.officialDatabase ||
      sourceType == FoodSourceType.officialSnapshot;

  bool get isUserEditable =>
      sourceType == FoodSourceType.brandLabel ||
      sourceType == FoodSourceType.professionalCustom ||
      sourceType == FoodSourceType.imported;

  NutrientValue? nutrient(String code) {
    for (final nutrient in nutrients) {
      if (nutrient.code == code) return nutrient;
    }
    return null;
  }

  double nutrientForGrams(String code, double grams) {
    if (grams <= 0) return 0;
    final value = nutrient(code)?.valuePer100g ?? 0;
    return value * grams / 100;
  }

  Food copyWith({
    int? id,
    String? name,
    String? brand,
    String? countryCode,
    FoodSourceType? sourceType,
    String? sourceName,
    String? sourceFoodId,
    String? sourceRelease,
    double? servingQuantity,
    String? servingUnit,
    String? householdMeasure,
    String? notes,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<NutrientValue>? nutrients,
    List<FoodPortion>? portions,
    List<String>? allergens,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      countryCode: countryCode ?? this.countryCode,
      sourceType: sourceType ?? this.sourceType,
      sourceName: sourceName ?? this.sourceName,
      sourceFoodId: sourceFoodId ?? this.sourceFoodId,
      sourceRelease: sourceRelease ?? this.sourceRelease,
      servingQuantity: servingQuantity ?? this.servingQuantity,
      servingUnit: servingUnit ?? this.servingUnit,
      householdMeasure: householdMeasure ?? this.householdMeasure,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nutrients: nutrients ?? this.nutrients,
      portions: portions ?? this.portions,
      allergens: allergens ?? this.allergens,
    );
  }
}
