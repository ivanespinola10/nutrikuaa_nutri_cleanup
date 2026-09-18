import 'nutrition/nutrient.dart';

enum FoodSourceType {
  officialDatabase,
  brandLabel,
  professionalCustom,
  imported,
}

class Food {
  final int? id;
  final String name;
  final String? brand;
  final String? countryCode;
  final FoodSourceType sourceType;
  final String? sourceName;
  final String? sourceFoodId;
  final double? servingQuantity;
  final String? servingUnit;
  final String? householdMeasure;
  final String? notes;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<NutrientValue> nutrients;

  Food({
    this.id,
    required this.name,
    this.brand,
    this.countryCode,
    required this.sourceType,
    this.sourceName,
    this.sourceFoodId,
    this.servingQuantity,
    this.servingUnit,
    this.householdMeasure,
    this.notes,
    this.isArchived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.nutrients = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isBranded => brand != null && brand!.trim().isNotEmpty;

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
    double? servingQuantity,
    String? servingUnit,
    String? householdMeasure,
    String? notes,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<NutrientValue>? nutrients,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      countryCode: countryCode ?? this.countryCode,
      sourceType: sourceType ?? this.sourceType,
      sourceName: sourceName ?? this.sourceName,
      sourceFoodId: sourceFoodId ?? this.sourceFoodId,
      servingQuantity: servingQuantity ?? this.servingQuantity,
      servingUnit: servingUnit ?? this.servingUnit,
      householdMeasure: householdMeasure ?? this.householdMeasure,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nutrients: nutrients ?? this.nutrients,
    );
  }
}
