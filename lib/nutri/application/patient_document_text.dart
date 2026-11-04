import '../domain/food.dart';

class PatientDocumentText {
  PatientDocumentText._();

  static const _assistantNoteMarkers = [
    'borrador nutri ia offline',
    'nutri ia offline',
    'revisar profesionalmente',
    'nutrikuaa:assistant-draft',
  ];

  static const Map<String, String> _spanishOfficialNames = {
    'egg, white, dried': 'Clara de huevo deshidratada',
    'egg, white, raw, frozen, pasteurized':
        'Clara de huevo cruda, congelada y pasteurizada',
    'egg, whole, raw, fresh': 'Huevo entero crudo',
    'egg, burrito': 'Burrito de huevo',
    'egg, burrito, with bacon': 'Burrito de huevo con tocino',
    'oat milk, unsweetened, plain, refrigerated':
        'Bebida de avena sin azúcar, natural, refrigerada',
    'almond milk, unsweetened, plain, refrigerated':
        'Bebida de almendras sin azúcar, natural, refrigerada',
    'flour, almond': 'Harina de almendras',
    'oats, whole grain, rolled, old fashioned': 'Avena integral en hojuelas',
    'oat bran cereal, cooked': 'Cereal de salvado de avena cocido',
    'bananas, overripe, raw': 'Banana madura cruda',
    'bananas, raw': 'Banana cruda',
    'yogurt, greek, plain, nonfat': 'Yogur griego natural descremado',
    'yogurt, greek, plain, whole milk': 'Yogur griego natural entero',
    'yogurt parfait, lowfat, with fruit and granola':
        'Parfait de yogur descremado con fruta y granola',
    'yogurt parfait, with fruit': 'Parfait de yogur con fruta',
    'chicken, breast, boneless, skinless, raw':
        'Pechuga de pollo sin piel ni hueso, cruda',
    'chicken, "wings" with hot sauce, from fast food / restaurant':
        'Alitas de pollo con salsa picante, comida rápida/restaurante',
    'rice, black, unenriched, raw': 'Arroz negro crudo',
    'rice, white, long-grain, regular, raw, unenriched':
        'Arroz blanco de grano largo, crudo',
    'rice and vermicelli mix, beef flavor, prepared with 80% margarine':
        'Mezcla de arroz y fideos sabor carne, preparada con margarina',
    'beans and brown rice': 'Frijoles con arroz integral',
    'carrots, baby, raw': 'Zanahoria baby cruda',
    'carrots, raw': 'Zanahoria cruda',
    'carrot juice, 100%': 'Jugo de zanahoria 100%',
    'broccoli, raw': 'Brócoli crudo',
    'broccoli and cauliflower, cooked, fat added':
        'Brócoli y coliflor cocidos con grasa añadida',
    'potatoes, gold, without skin, raw': 'Papa amarilla pelada, cruda',
    'potatoes, raw, skin': 'Papa con piel, cruda',
    'potato chips, baked, flavored': 'Chips de papa horneados saborizados',
    'beans, black, canned, sodium added, drained and rinsed':
        'Frijoles negros enlatados, escurridos y enjuagados',
    'beans, black, mature seeds, cooked, boiled, without salt':
        'Frijoles negros cocidos sin sal',
    "milk 'n cereal bar": 'Barra de leche y cereal',
    'apple, raw': 'Manzana cruda',
    'apples, raw, with skin': 'Manzana con piel, cruda',
    'tomatoes, red, ripe, raw, year round average': 'Tomate rojo maduro, crudo',
    'spinach, raw': 'Espinaca cruda',
    'corn, sweet, yellow, raw': 'Maíz dulce amarillo, crudo',
  };

  static String foodDisplayName(Food food, String languageCode) {
    final cleanName = _clean(food.name);
    final cleanBrand = _clean(food.brand ?? '');

    final localizedName = languageCode.toLowerCase() == 'es' && food.isOfficial
        ? _spanishOfficialName(cleanName)
        : cleanName;

    if (cleanBrand.isEmpty ||
        cleanBrand.toLowerCase() == cleanName.toLowerCase() ||
        cleanBrand.toLowerCase() == localizedName.toLowerCase()) {
      return localizedName;
    }

    return '$localizedName - $cleanBrand';
  }

  static String? patientFacingPortionNote(String? rawNote) {
    final note = rawNote?.trim();
    if (note == null || note.isEmpty) return null;

    final repaired = _repairMojibake(note);
    final normalized = _normalize(repaired);
    if (_assistantNoteMarkers.any(normalized.contains)) return null;
    return repaired;
  }

  static String _spanishOfficialName(String name) =>
      _spanishOfficialNames[name.toLowerCase()] ?? name;

  static String _clean(String value) =>
      _repairMojibake(value).trim().replaceAll(RegExp(r'\s+'), ' ');

  static String _normalize(String value) => _repairMojibake(value)
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'\s+'), ' ');

  static String _repairMojibake(String value) {
    return value;
  }
}
