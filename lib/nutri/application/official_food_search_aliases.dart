class OfficialFoodSearchAliases {
  OfficialFoodSearchAliases._();

  static const Map<String, String> _aliases = {
    // Spanish
    'leche': 'milk',
    'yogur': 'yogurt',
    'yogurt': 'yogurt',
    'arroz': 'rice',
    'pollo': 'chicken',
    'huevo': 'egg',
    'huevos': 'egg',
    'pan': 'bread',
    'avena': 'oat',
    'manzana': 'apple',
    'banana': 'banana',
    'platano': 'banana',
    'plátano': 'banana',
    'papa': 'potato',
    'patata': 'potato',
    'queso': 'cheese',
    'carne': 'beef',
    'cerdo': 'pork',
    'pescado': 'fish',
    'frutilla': 'strawberry',
    'fresa': 'strawberry',

    // Portuguese
    'leite': 'milk',
    'iogurte': 'yogurt',
    'frango': 'chicken',
    'ovo': 'egg',
    'ovos': 'egg',
    'pão': 'bread',
    'pao': 'bread',
    'aveia': 'oat',
    'maçã': 'apple',
    'maca': 'apple',
    'batata': 'potato',
    'queijo': 'cheese',
    'carne bovina': 'beef',
    'porco': 'pork',
    'peixe': 'fish',
    'morango': 'strawberry',
  };

  static String forOfficialCatalog(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return query.trim();
    return _aliases[normalized] ?? query.trim();
  }
}
