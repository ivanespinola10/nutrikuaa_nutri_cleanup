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
    'oat milk, unsweetened, plain, refrigerated':
        'Bebida de avena sin azÃºcar, natural, refrigerada',
    'almond milk, unsweetened, plain, refrigerated':
        'Bebida de almendras sin azÃºcar, natural, refrigerada',
    'flour, almond': 'Harina de almendras',
    'oats, whole grain, rolled, old fashioned': 'Avena integral en hojuelas',
    'bananas, overripe, raw': 'Banana madura cruda',
    'bananas, raw': 'Banana cruda',
    'yogurt, greek, plain, nonfat': 'Yogur griego natural descremado',
    'yogurt, greek, plain, whole milk': 'Yogur griego natural entero',
    'chicken, breast, boneless, skinless, raw':
        'Pechuga de pollo sin piel ni hueso, cruda',
    'rice, black, unenriched, raw': 'Arroz negro crudo',
    'rice, white, long-grain, regular, raw, unenriched':
        'Arroz blanco de grano largo, crudo',
    'carrots, baby, raw': 'Zanahoria baby cruda',
    'carrots, raw': 'Zanahoria cruda',
    'broccoli, raw': 'BrÃ³coli crudo',
    'potatoes, gold, without skin, raw': 'Papa amarilla pelada, cruda',
    'potatoes, raw, skin': 'Papa con piel, cruda',
    'beans, black, canned, sodium added, drained and rinsed':
        'Frijoles negros enlatados, escurridos y enjuagados',
    'beans, black, mature seeds, cooked, boiled, without salt':
        'Frijoles negros cocidos sin sal',
    'apple, raw': 'Manzana cruda',
    'apples, raw, with skin': 'Manzana con piel, cruda',
    'tomatoes, red, ripe, raw, year round average': 'Tomate rojo maduro, crudo',
    'spinach, raw': 'Espinaca cruda',
    'corn, sweet, yellow, raw': 'MaÃ­z dulce amarillo, crudo',
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

    final normalized = _normalize(note);
    if (_assistantNoteMarkers.any(normalized.contains)) return null;
    return note;
  }

  static String _spanishOfficialName(String name) {
    final normalized = name.toLowerCase();
    final exact = _spanishOfficialNames[normalized];
    if (exact != null) return exact;

    var translated = normalized;
    const replacements = <String, String>{
      'chicken breast': 'pechuga de pollo',
      'chicken': 'pollo',
      'egg white': 'clara de huevo',
      'egg': 'huevo',
      'greek yogurt': 'yogur griego',
      'yogurt': 'yogur',
      'oat milk': 'bebida de avena',
      'almond milk': 'bebida de almendras',
      'black beans': 'frijoles negros',
      'beans': 'frijoles',
      'black rice': 'arroz negro',
      'rice': 'arroz',
      'potatoes': 'papas',
      'potato': 'papa',
      'carrots': 'zanahorias',
      'carrot': 'zanahoria',
      'broccoli': 'brÃ³coli',
      'spinach': 'espinaca',
      'tomatoes': 'tomates',
      'tomato': 'tomate',
      'bananas': 'bananas',
      'banana': 'banana',
      'apples': 'manzanas',
      'apple': 'manzana',
      'unsweetened': 'sin azÃºcar',
      'plain': 'natural',
      'nonfat': 'descremado',
      'whole milk': 'entero',
      'boneless': 'sin hueso',
      'skinless': 'sin piel',
      'without skin': 'sin piel',
      'raw': 'crudo',
      'frozen': 'congelado',
      'pasteurized': 'pasteurizado',
      'dried': 'deshidratado',
      'drained and rinsed': 'escurrido y enjuagado',
      'canned': 'enlatado',
      'sodium added': 'con sodio aÃ±adido',
      'refrigerated': 'refrigerado',
      'overripe': 'maduro',
    };

    for (final entry in replacements.entries) {
      translated = translated.replaceAll(entry.key, entry.value);
    }
    if (translated == normalized) return name;

    translated = translated
        .replaceAll(RegExp(r'\s*,\s*'), ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (translated.isEmpty) return name;
    return translated[0].toUpperCase() + translated.substring(1);
  }

  static String _clean(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('Ã¡', 'a')
      .replaceAll('Ã©', 'e')
      .replaceAll('Ã­', 'i')
      .replaceAll('Ã³', 'o')
      .replaceAll('Ãº', 'u')
      .replaceAll('Ã¼', 'u')
      .replaceAll('Ã±', 'n')
      .replaceAll(RegExp(r'\s+'), ' ');
}
