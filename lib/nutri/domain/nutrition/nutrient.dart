enum NutrientUnit {
  kilocalorie,
  gram,
  milligram,
  microgram,
  internationalUnit,
}

class NutrientCodes {
  NutrientCodes._();

  static const energyKcal = 'energy_kcal';
  static const protein = 'protein_g';
  static const carbohydrate = 'carbohydrate_g';
  static const fat = 'fat_g';
  static const fiber = 'fiber_g';
  static const sugars = 'sugars_g';
  static const sodium = 'sodium_mg';
  static const calcium = 'calcium_mg';
  static const iron = 'iron_mg';
  static const potassium = 'potassium_mg';
  static const vitaminA = 'vitamin_a_ug';
  static const vitaminC = 'vitamin_c_mg';
  static const vitaminD = 'vitamin_d_ug';
}

class NutrientValue {
  final String code;
  final double valuePer100g;
  final NutrientUnit unit;

  const NutrientValue({
    required this.code,
    required this.valuePer100g,
    required this.unit,
  });

  NutrientValue copyWith({
    String? code,
    double? valuePer100g,
    NutrientUnit? unit,
  }) {
    return NutrientValue(
      code: code ?? this.code,
      valuePer100g: valuePer100g ?? this.valuePer100g,
      unit: unit ?? this.unit,
    );
  }
}
