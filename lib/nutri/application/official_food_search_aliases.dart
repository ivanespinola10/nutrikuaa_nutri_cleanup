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
    'poroto': 'beans',
    'porotos': 'beans',
    'frijol': 'beans',
    'frijoles': 'beans',
    'maíz': 'corn',
    'maiz': 'corn',
    'tomate': 'tomato',
    'cebolla': 'onion',
    'zanahoria': 'carrot',
    'entera': 'whole',
    'natural': 'plain',
    'pechuga': 'breast',
    'arroz integral': 'rice brown',
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
    final exact = _aliases[normalized];
    if (exact != null) return exact;

    // Search terms may appear in any order in the official English name.
    // Keep the original name and source when presenting a match.
    final tokens = normalized.split(RegExp(r'[\s,;]+'));
    return tokens.map((token) => _aliases[token] ?? token).join(' ');
  }
}
