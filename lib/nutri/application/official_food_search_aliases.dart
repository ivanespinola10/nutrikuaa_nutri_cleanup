class OfficialFoodSearchAliases {
  OfficialFoodSearchAliases._();

  static const Map<String, String> _aliases = {
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
    'poroto': 'beans',
    'porotos': 'beans',
    'frijol': 'beans',
    'frijoles': 'beans',
    'lenteja': 'lentil',
    'lentejas': 'lentil',
    'maíz': 'corn',
    'maiz': 'corn',
    'tomate': 'tomato',
    'cebolla': 'onion',
    'zanahoria': 'carrot',
    'brócoli': 'broccoli',
    'brocoli': 'broccoli',
    'espinaca': 'spinach',
    'soja': 'soy',
    'maní': 'peanut',
    'mani': 'peanut',
    'almendra': 'almond',
    'entera': 'whole',
    'natural': 'plain',
    'pechuga': 'breast',
    'arroz integral': 'rice brown',
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
    'feijão': 'beans',
    'feijao': 'beans',
    'lentilha': 'lentil',
    'milho': 'corn',
    'cenoura': 'carrot',
    'espinafre': 'spinach',
    'brócolis': 'broccoli',
    'brocolis': 'broccoli',
    'amendoim': 'peanut',
  };

  static const Map<String, List<String>> _professionalAliases = {
    'milk': ['leche', 'leite'],
    'yogurt': ['yogur', 'iogurte'],
    'rice': ['arroz'],
    'chicken': ['pollo', 'frango'],
    'egg': ['huevo', 'ovo'],
    'bread': ['pan', 'pão', 'pao'],
    'oat': ['avena', 'aveia'],
    'apple': ['manzana', 'maçã', 'maca'],
    'banana': ['banana', 'plátano', 'platano'],
    'potato': ['papa', 'patata', 'batata'],
    'cheese': ['queso', 'queijo'],
    'beef': ['carne', 'carne bovina'],
    'pork': ['cerdo', 'porco'],
    'fish': ['pescado', 'peixe'],
    'beans': ['poroto', 'porotos', 'frijol', 'frijoles', 'feijão', 'feijao'],
    'lentil': ['lenteja', 'lentejas', 'lentilha'],
    'corn': ['maíz', 'maiz', 'milho'],
    'tomato': ['tomate'],
    'carrot': ['zanahoria', 'cenoura'],
    'broccoli': ['brócoli', 'brocoli', 'brócolis', 'brocolis'],
    'spinach': ['espinaca', 'espinafre'],
    'soy': ['soja'],
    'tofu': ['tofu'],
    'peanut': ['maní', 'mani', 'amendoim'],
    'almond': ['almendra'],
  };

  static String forOfficialCatalog(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return query.trim();

    final exact = _aliases[normalized];
    if (exact != null) return exact;

    final tokens = normalized.split(RegExp(r'[\s,;]+'));
    return tokens.map((token) => _aliases[token] ?? token).join(' ');
  }

  static List<String> forProfessionalCatalog(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return const [''];

    final normalized = clean.toLowerCase();
    final variants = <String>{clean};

    final exact = _professionalAliases[normalized];
    if (exact != null) variants.addAll(exact);

    return variants.toList(growable: false);
  }
}
