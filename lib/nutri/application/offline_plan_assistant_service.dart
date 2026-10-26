import '../domain/food.dart';
import '../domain/nutrition/nutrient.dart';
import 'nutrition_calculator.dart';
import 'unified_food_search_service.dart';

typedef OfflineFoodSearch = Future<FoodSearchResults> Function(String query);

class OfflinePlanAssistantRequest {
  final String prompt;
  final double? targetKcal;
  final double? targetProteinGrams;

  const OfflinePlanAssistantRequest({
    required this.prompt,
    this.targetKcal,
    this.targetProteinGrams,
  });
}

class OfflinePlanDraftItem {
  final Food food;
  final double grams;

  const OfflinePlanDraftItem({required this.food, required this.grams});

  OfflinePlanDraftItem copyWith({double? grams}) =>
      OfflinePlanDraftItem(food: food, grams: grams ?? this.grams);
}

class OfflinePlanDraftMeal {
  final String name;
  final List<OfflinePlanDraftItem> items;

  const OfflinePlanDraftMeal({required this.name, required this.items});
}

class OfflinePlanDraft {
  final String title;
  final String rationale;
  final double targetKcal;
  final double? targetProteinGrams;
  final bool usedFallbackEnergyTarget;
  final List<OfflinePlanDraftMeal> meals;

  const OfflinePlanDraft({
    required this.title,
    required this.rationale,
    required this.targetKcal,
    required this.targetProteinGrams,
    required this.usedFallbackEnergyTarget,
    required this.meals,
  });

  NutritionTotals get totals => NutritionCalculator.forPortions(
    meals
        .expand((meal) => meal.items)
        .map((item) => FoodAmount(food: item.food, grams: item.grams)),
  );
}

enum _FoodRole { protein, carbohydrate, produce, flexible }

class _FoodSlot {
  final List<String> queries;
  final double grams;
  final _FoodRole role;

  const _FoodSlot({
    required this.queries,
    required this.grams,
    required this.role,
  });
}

class _MealTemplate {
  final String name;
  final List<_FoodSlot> slots;

  const _MealTemplate(this.name, this.slots);
}

class _Preferences {
  final bool vegetarian;
  final bool vegan;
  final bool lactoseFree;
  final bool glutenFree;
  final bool eggFree;
  final bool nutFree;
  final bool highProtein;
  final bool economical;

  const _Preferences({
    required this.vegetarian,
    required this.vegan,
    required this.lactoseFree,
    required this.glutenFree,
    required this.eggFree,
    required this.nutFree,
    required this.highProtein,
    required this.economical,
  });
}

class OfflinePlanAssistantService {
  final OfflineFoodSearch _search;

  OfflinePlanAssistantService({OfflineFoodSearch? search})
    : _search = search ?? _defaultSearch;

  static Future<FoodSearchResults> _defaultSearch(String query) =>
      UnifiedFoodSearchService().search(
        query,
        professionalLimit: 8,
        officialLimit: 12,
      );

  Future<OfflinePlanDraft> generate(OfflinePlanAssistantRequest request) async {
    final prompt = request.prompt.trim();
    if (prompt.isEmpty) {
      throw ArgumentError('Describe el tipo de plan que quieres prearmar.');
    }

    final normalized = _normalize(prompt);
    final explicitKcal = _extractNumber(
      normalized,
      RegExp(r'(\d{3,4})\s*kcal'),
    );
    final providedKcal = _positiveOrNull(request.targetKcal);
    final usedFallbackEnergyTarget =
        explicitKcal == null && providedKcal == null;
    final targetKcal = explicitKcal ?? providedKcal ?? 2000.0;

    final explicitProtein = _extractNumber(
      normalized,
      RegExp(r'(\d{2,3})\s*g(?:\s+de)?\s+prote'),
    );
    final targetProtein =
        explicitProtein ?? _positiveOrNull(request.targetProteinGrams);

    final preferences = _preferencesFrom(normalized);
    final templates = _templates(preferences);
    final cache = <String, FoodSearchResults>{};
    final usedFoods = <String>{};
    final meals = <OfflinePlanDraftMeal>[];

    Future<FoodSearchResults> cachedSearch(String query) async {
      final cached = cache[query];
      if (cached != null) return cached;
      final result = await _search(query);
      cache[query] = result;
      return result;
    }

    for (final template in templates) {
      final items = <OfflinePlanDraftItem>[];
      for (final slot in template.slots) {
        final food = await _findFood(
          slot,
          preferences,
          usedFoods,
          cachedSearch,
        );
        if (food == null) continue;
        usedFoods.add(_foodIdentity(food));
        items.add(OfflinePlanDraftItem(food: food, grams: slot.grams));
      }
      if (items.isNotEmpty) {
        meals.add(OfflinePlanDraftMeal(name: template.name, items: items));
      }
    }

    if (meals.length < 3) {
      throw StateError(
        'No hay suficientes alimentos compatibles en las bases locales para '
        'armar un borrador. Agrega alimentos a tu biblioteca o amplía el catálogo.',
      );
    }

    var adjustedMeals = _scaleToEnergy(meals, targetKcal);
    if (targetProtein != null && targetProtein > 0) {
      adjustedMeals = _boostProtein(adjustedMeals, targetProtein);
    }

    final tags = <String>[
      if (preferences.highProtein) 'alto en proteína',
      if (preferences.economical) 'económico',
      if (preferences.vegan)
        'vegano'
      else if (preferences.vegetarian)
        'vegetariano',
      if (preferences.lactoseFree) 'sin lácteos/lactosa',
      if (preferences.glutenFree) 'sin gluten',
      if (preferences.eggFree) 'sin huevo',
      if (preferences.nutFree) 'sin frutos secos/maní',
    ];

    final rationale = [
      usedFallbackEnergyTarget
          ? 'No se encontró un objetivo energético del paciente ni en el texto; '
                'se usaron 2000 kcal solo como referencia de borrador.'
          : 'El borrador usa el objetivo energético indicado por el profesional.',
      if (tags.isNotEmpty) 'Preferencias detectadas: ${tags.join(', ')}.',
      'Los alimentos provienen únicamente de las bases locales activas. '
          'Las cantidades y nutrientes se calculan con el motor de Nutrikuaa.',
      'Es un borrador de apoyo y requiere revisión profesional antes de entregarse.',
    ].join(' ');

    return OfflinePlanDraft(
      title: 'Borrador diario · ${targetKcal.toStringAsFixed(0)} kcal',
      rationale: rationale,
      targetKcal: targetKcal,
      targetProteinGrams: targetProtein,
      usedFallbackEnergyTarget: usedFallbackEnergyTarget,
      meals: adjustedMeals,
    );
  }

  Future<Food?> _findFood(
    _FoodSlot slot,
    _Preferences preferences,
    Set<String> usedFoods,
    Future<FoodSearchResults> Function(String query) search,
  ) async {
    for (final query in slot.queries) {
      final results = await search(query);
      final candidates = [...results.professional, ...results.official];
      for (final food in candidates) {
        if (usedFoods.contains(_foodIdentity(food))) continue;
        if (!_acceptable(food, preferences)) continue;
        if (!_fitsRole(food, slot.role)) continue;
        return food;
      }
    }
    return null;
  }

  static bool _fitsRole(Food food, _FoodRole role) {
    final kcal = food.nutrient(NutrientCodes.energyKcal)?.valuePer100g ?? 0;
    final protein = food.nutrient(NutrientCodes.protein)?.valuePer100g ?? 0;
    final carbs = food.nutrient(NutrientCodes.carbohydrate)?.valuePer100g ?? 0;
    if (kcal <= 0) return false;

    return switch (role) {
      _FoodRole.protein => protein >= 4,
      _FoodRole.carbohydrate => carbs >= 4 || kcal >= 70,
      _FoodRole.produce => true,
      _FoodRole.flexible => true,
    };
  }

  static bool _acceptable(Food food, _Preferences preferences) {
    final name = _normalize(food.name);
    final allergens = food.allergens.map(_normalize).toSet();

    if ((preferences.vegetarian || preferences.vegan) &&
        _containsAny(name, const [
          'chicken',
          'pollo',
          'beef',
          'carne',
          'pork',
          'cerdo',
          'ham',
          'jamon',
          'fish',
          'pescado',
          'tuna',
          'atun',
          'turkey',
          'pavo',
          'shrimp',
          'camaron',
        ])) {
      return false;
    }

    if (preferences.vegan &&
        (_containsAny(name, const [
              'egg',
              'huevo',
              'milk',
              'leche',
              'yogurt',
              'yoghurt',
              'queso',
              'cheese',
              'butter',
              'manteca',
              'cream',
              'crema',
            ]) ||
            allergens.contains('milk') ||
            allergens.contains('egg'))) {
      return false;
    }

    if (preferences.lactoseFree &&
        (_containsAny(name, const [
              'milk',
              'leche',
              'yogurt',
              'yoghurt',
              'cheese',
              'queso',
              'buttermilk',
              'cream',
              'crema',
              'whey',
            ]) ||
            allergens.contains('milk'))) {
      return false;
    }

    if (preferences.glutenFree &&
        (_containsAny(name, const [
              'wheat',
              'trigo',
              'bread',
              'pan',
              'barley',
              'cebada',
              'rye',
              'centeno',
              'pasta',
              'oat',
              'avena',
            ]) ||
            allergens.contains('gluten'))) {
      return false;
    }

    if (preferences.eggFree &&
        (_containsAny(name, const ['egg', 'huevo']) ||
            allergens.contains('egg'))) {
      return false;
    }

    if (preferences.nutFree &&
        (_containsAny(name, const [
              'almond',
              'almendra',
              'peanut',
              'mani',
              'cacahuete',
              'walnut',
              'nuez',
              'cashew',
              'anacardo',
              'pistachio',
              'pistacho',
              'hazelnut',
            ]) ||
            allergens.contains('tree_nuts') ||
            allergens.contains('peanut'))) {
      return false;
    }

    return true;
  }

  static List<_MealTemplate> _templates(_Preferences p) {
    final breakfastProtein = p.vegan
        ? const ['soy', 'beans', 'tofu']
        : p.vegetarian
        ? const ['egg', 'yogurt', 'beans']
        : const ['egg', 'yogurt', 'milk'];

    final mainProtein = p.vegan
        ? const ['beans', 'lentil', 'soy', 'tofu']
        : p.vegetarian
        ? const ['egg', 'beans', 'lentil', 'yogurt']
        : p.economical
        ? const ['egg', 'beans', 'chicken', 'fish']
        : const ['chicken', 'fish', 'egg', 'beans'];

    final snack = p.lactoseFree || p.vegan
        ? const ['banana', 'apple', 'peanut', 'almond']
        : const ['yogurt', 'banana', 'apple', 'milk'];

    return [
      _MealTemplate('Desayuno', [
        _FoodSlot(
          queries: breakfastProtein,
          grams: p.highProtein ? 130 : 100,
          role: _FoodRole.protein,
        ),
        _FoodSlot(
          queries: p.glutenFree
              ? const ['rice', 'corn', 'potato']
              : const ['oat', 'bread', 'rice'],
          grams: 60,
          role: _FoodRole.carbohydrate,
        ),
        const _FoodSlot(
          queries: ['banana', 'apple'],
          grams: 120,
          role: _FoodRole.produce,
        ),
      ]),
      _MealTemplate('Media mañana', [
        _FoodSlot(queries: snack, grams: 140, role: _FoodRole.flexible),
      ]),
      _MealTemplate('Almuerzo', [
        _FoodSlot(
          queries: mainProtein,
          grams: p.highProtein ? 190 : 160,
          role: _FoodRole.protein,
        ),
        const _FoodSlot(
          queries: ['rice', 'potato', 'beans', 'corn'],
          grams: 180,
          role: _FoodRole.carbohydrate,
        ),
        const _FoodSlot(
          queries: ['carrot', 'broccoli', 'tomato', 'spinach'],
          grams: 140,
          role: _FoodRole.produce,
        ),
      ]),
      _MealTemplate('Merienda', [
        _FoodSlot(
          queries: snack.reversed.toList(),
          grams: 140,
          role: _FoodRole.flexible,
        ),
      ]),
      _MealTemplate('Cena', [
        _FoodSlot(
          queries: mainProtein.reversed.toList(),
          grams: p.highProtein ? 180 : 150,
          role: _FoodRole.protein,
        ),
        const _FoodSlot(
          queries: ['potato', 'rice', 'beans', 'corn'],
          grams: 160,
          role: _FoodRole.carbohydrate,
        ),
        const _FoodSlot(
          queries: ['broccoli', 'carrot', 'tomato', 'spinach'],
          grams: 140,
          role: _FoodRole.produce,
        ),
      ]),
    ];
  }

  static List<OfflinePlanDraftMeal> _scaleToEnergy(
    List<OfflinePlanDraftMeal> meals,
    double targetKcal,
  ) {
    final current = _totalsFor(meals).value(NutrientCodes.energyKcal);
    if (current <= 0 || targetKcal <= 0) return meals;
    final factor = (targetKcal / current).clamp(0.65, 1.65).toDouble();
    return _scale(meals, (item) => factor);
  }

  static List<OfflinePlanDraftMeal> _boostProtein(
    List<OfflinePlanDraftMeal> meals,
    double targetProtein,
  ) {
    final current = _totalsFor(meals).value(NutrientCodes.protein);
    if (current <= 0 || current >= targetProtein * 0.90) return meals;
    final factor = (targetProtein / current).clamp(1.0, 1.35).toDouble();

    return _scale(meals, (item) {
      final density =
          item.food.nutrient(NutrientCodes.protein)?.valuePer100g ?? 0;
      return density >= 8 ? factor : 1.0;
    });
  }

  static List<OfflinePlanDraftMeal> _scale(
    List<OfflinePlanDraftMeal> meals,
    double Function(OfflinePlanDraftItem item) factorFor,
  ) {
    return meals
        .map(
          (meal) => OfflinePlanDraftMeal(
            name: meal.name,
            items: meal.items
                .map((item) {
                  final grams = (item.grams * factorFor(item))
                      .clamp(25.0, 450.0)
                      .toDouble();
                  return item.copyWith(grams: grams);
                })
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  static NutritionTotals _totalsFor(List<OfflinePlanDraftMeal> meals) =>
      NutritionCalculator.forPortions(
        meals
            .expand((meal) => meal.items)
            .map((item) => FoodAmount(food: item.food, grams: item.grams)),
      );

  static _Preferences _preferencesFrom(String normalized) {
    final vegan = normalized.contains('vegan');
    final vegetarian = vegan || normalized.contains('vegetar');
    final lactoseFree =
        normalized.contains('sin lactosa') ||
        normalized.contains('lactose free') ||
        normalized.contains('sin leche') ||
        normalized.contains('alergia leche') ||
        normalized.contains('alergia a la leche');
    final glutenFree =
        normalized.contains('sin gluten') ||
        normalized.contains('gluten free') ||
        normalized.contains('celiac');
    final eggFree =
        normalized.contains('sin huevo') ||
        normalized.contains('egg free') ||
        normalized.contains('alergia huevo') ||
        normalized.contains('alergia al huevo');
    final nutFree =
        normalized.contains('sin frutos secos') ||
        normalized.contains('sin nueces') ||
        normalized.contains('sin mani') ||
        normalized.contains('nut free') ||
        normalized.contains('alergia mani');

    return _Preferences(
      vegetarian: vegetarian,
      vegan: vegan,
      lactoseFree: lactoseFree,
      glutenFree: glutenFree,
      eggFree: eggFree,
      nutFree: nutFree,
      highProtein:
          normalized.contains('alto en prote') ||
          normalized.contains('high protein') ||
          normalized.contains('mas prote'),
      economical:
          normalized.contains('econom') ||
          normalized.contains('barato') ||
          normalized.contains('budget'),
    );
  }

  static double? _extractNumber(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  static double? _positiveOrNull(double? value) =>
      value != null && value.isFinite && value > 0 ? value : null;

  static String _foodIdentity(Food food) => [
    food.id?.toString() ?? '',
    food.sourceName ?? '',
    food.sourceFoodId ?? '',
    _normalize(food.name),
  ].join('|');

  static bool _containsAny(String text, List<String> terms) =>
      terms.any(text.contains);

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
}
