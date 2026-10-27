import '../domain/food.dart';
import '../domain/nutrition/nutrient.dart';
import 'offline_plan_assistant_service.dart';

enum PlanValidationSeverity { pass, warning, blocking }

class PlanValidationCheck {
  final String id;
  final String title;
  final String detail;
  final PlanValidationSeverity severity;

  const PlanValidationCheck({
    required this.id,
    required this.title,
    required this.detail,
    required this.severity,
  });
}

class OfflinePlanValidationReport {
  final List<PlanValidationCheck> checks;

  const OfflinePlanValidationReport(this.checks);

  bool get hasBlockingIssues =>
      checks.any((check) => check.severity == PlanValidationSeverity.blocking);

  bool get hasWarnings =>
      checks.any((check) => check.severity == PlanValidationSeverity.warning);

  bool get canApply => !hasBlockingIssues;

  int get blockingCount => checks
      .where((check) => check.severity == PlanValidationSeverity.blocking)
      .length;

  int get warningCount => checks
      .where((check) => check.severity == PlanValidationSeverity.warning)
      .length;
}

class OfflinePlanValidationRequest {
  final OfflinePlanDraft draft;
  final String prompt;
  final double? targetKcal;
  final double? targetProteinGrams;
  final double? targetCarbohydrateGrams;
  final double? targetFatGrams;
  final String? patientAllergies;
  final String? patientIntolerances;

  const OfflinePlanValidationRequest({
    required this.draft,
    required this.prompt,
    this.targetKcal,
    this.targetProteinGrams,
    this.targetCarbohydrateGrams,
    this.targetFatGrams,
    this.patientAllergies,
    this.patientIntolerances,
  });
}

class OfflinePlanValidatorService {
  const OfflinePlanValidatorService();

  OfflinePlanValidationReport validate(OfflinePlanValidationRequest request) {
    final checks = <PlanValidationCheck>[];
    final draft = request.draft;
    final totals = draft.totals;

    final targetKcal = _positiveOrNull(request.targetKcal) ?? draft.targetKcal;
    final targetProtein =
        _positiveOrNull(request.targetProteinGrams) ??
        _positiveOrNull(draft.targetProteinGrams);

    checks.add(
      _nutrientCheck(
        id: 'energy',
        title: 'Energía',
        actual: totals.value(NutrientCodes.energyKcal),
        target: targetKcal,
        unit: 'kcal',
        passTolerance: 0.10,
      ),
    );

    if (targetProtein != null) {
      checks.add(
        _nutrientCheck(
          id: 'protein',
          title: 'Proteína',
          actual: totals.value(NutrientCodes.protein),
          target: targetProtein,
          unit: 'g',
          passTolerance: 0.15,
        ),
      );
    }

    final targetCarbs = _positiveOrNull(request.targetCarbohydrateGrams);
    if (targetCarbs != null) {
      checks.add(
        _nutrientCheck(
          id: 'carbohydrate',
          title: 'Carbohidratos',
          actual: totals.value(NutrientCodes.carbohydrate),
          target: targetCarbs,
          unit: 'g',
          passTolerance: 0.15,
        ),
      );
    }

    final targetFat = _positiveOrNull(request.targetFatGrams);
    if (targetFat != null) {
      checks.add(
        _nutrientCheck(
          id: 'fat',
          title: 'Grasas',
          actual: totals.value(NutrientCodes.fat),
          target: targetFat,
          unit: 'g',
          passTolerance: 0.15,
        ),
      );
    }

    if (draft.usedFallbackEnergyTarget &&
        _positiveOrNull(request.targetKcal) == null) {
      checks.add(
        const PlanValidationCheck(
          id: 'fallback-energy',
          title: 'Meta energética',
          detail:
              'Se usó una referencia de 2000 kcal porque el paciente no tiene '
              'una meta energética definida. Debe revisarse antes de entregar.',
          severity: PlanValidationSeverity.warning,
        ),
      );
    }

    checks.addAll(_quantityChecks(draft));

    final restrictions = _Restrictions.from(
      prompt: request.prompt,
      patientAllergies: request.patientAllergies,
      patientIntolerances: request.patientIntolerances,
    );

    checks.add(_restrictionCheck(draft, restrictions));

    if (restrictions.hasAny) {
      final unknownAllergenFoods = draft.meals
          .expand((meal) => meal.items)
          .where((item) => item.food.allergens.isEmpty)
          .map((item) => item.food.name)
          .toSet();

      if (unknownAllergenFoods.isNotEmpty) {
        checks.add(
          PlanValidationCheck(
            id: 'allergen-metadata',
            title: 'Datos de alérgenos',
            detail:
                '${unknownAllergenFoods.length} alimento(s) no tienen una '
                'declaración estructurada de alérgenos. Esto no significa que '
                'sean libres de alérgenos; revisar nombre, marca y etiqueta.',
            severity: PlanValidationSeverity.warning,
          ),
        );
      }
    }

    final missingEnergy = draft.meals
        .expand((meal) => meal.items)
        .where(
          (item) =>
              (item.food.nutrient(NutrientCodes.energyKcal)?.valuePer100g ??
                  0) <=
              0,
        )
        .map((item) => item.food.name)
        .toSet();

    if (missingEnergy.isNotEmpty) {
      checks.add(
        PlanValidationCheck(
          id: 'missing-energy',
          title: 'Composición nutricional',
          detail:
              '${missingEnergy.length} alimento(s) no tienen energía válida '
              'por 100 g. Corrige la ficha del alimento antes de aplicar.',
          severity: PlanValidationSeverity.blocking,
        ),
      );
    }

    final hasWarnings = checks.any(
      (check) => check.severity == PlanValidationSeverity.warning,
    );
    final hasBlocking = checks.any(
      (check) => check.severity == PlanValidationSeverity.blocking,
    );

    if (!hasBlocking) {
      checks.add(
        PlanValidationCheck(
          id: 'professional-review',
          title: 'Revisión profesional',
          detail: hasWarnings
              ? 'El borrador puede aplicarse al planificador, pero conserva '
                    'advertencias que el nutricionista debe revisar.'
              : 'No se detectaron incompatibilidades automáticas. El borrador '
                    'sigue requiriendo revisión profesional antes de entregarse.',
          severity: hasWarnings
              ? PlanValidationSeverity.warning
              : PlanValidationSeverity.pass,
        ),
      );
    }

    return OfflinePlanValidationReport(List.unmodifiable(checks));
  }

  static PlanValidationCheck _nutrientCheck({
    required String id,
    required String title,
    required double actual,
    required double target,
    required String unit,
    required double passTolerance,
  }) {
    if (target <= 0 || !target.isFinite) {
      return PlanValidationCheck(
        id: id,
        title: title,
        detail: 'Sin meta válida para comparar.',
        severity: PlanValidationSeverity.warning,
      );
    }

    final difference = actual - target;
    final relative = difference.abs() / target;
    final percent = difference / target * 100;
    final sign = percent >= 0 ? '+' : '';

    return PlanValidationCheck(
      id: id,
      title: title,
      detail:
          '${actual.toStringAsFixed(1)} $unit vs '
          '${target.toStringAsFixed(1)} $unit '
          '($sign${percent.toStringAsFixed(1)}%). '
          '${relative <= passTolerance ? 'Dentro del rango de control.' : 'Revisar y ajustar.'}',
      severity: relative <= passTolerance
          ? PlanValidationSeverity.pass
          : PlanValidationSeverity.warning,
    );
  }

  static Iterable<PlanValidationCheck> _quantityChecks(
    OfflinePlanDraft draft,
  ) sync* {
    final invalid = <String>[];
    final unusual = <String>[];

    for (final meal in draft.meals) {
      for (final item in meal.items) {
        if (!item.grams.isFinite || item.grams <= 0) {
          invalid.add('${item.food.name} (${item.grams} g)');
        } else if (item.grams < 10 || item.grams > 450) {
          unusual.add('${item.food.name} (${item.grams.toStringAsFixed(0)} g)');
        }
      }
    }

    if (invalid.isNotEmpty) {
      yield PlanValidationCheck(
        id: 'invalid-quantity',
        title: 'Cantidades',
        detail:
            'Hay cantidades inválidas: ${invalid.take(3).join(', ')}. '
            'No se puede aplicar el borrador.',
        severity: PlanValidationSeverity.blocking,
      );
    } else if (unusual.isNotEmpty) {
      yield PlanValidationCheck(
        id: 'unusual-quantity',
        title: 'Cantidades',
        detail:
            'Revisar porciones poco habituales: ${unusual.take(3).join(', ')}.',
        severity: PlanValidationSeverity.warning,
      );
    } else {
      yield const PlanValidationCheck(
        id: 'quantity',
        title: 'Cantidades',
        detail: 'No se detectaron cantidades inválidas o extremas.',
        severity: PlanValidationSeverity.pass,
      );
    }
  }

  static PlanValidationCheck _restrictionCheck(
    OfflinePlanDraft draft,
    _Restrictions restrictions,
  ) {
    if (!restrictions.hasAny) {
      return const PlanValidationCheck(
        id: 'restrictions',
        title: 'Restricciones',
        detail:
            'No se detectaron restricciones específicas en el pedido ni en '
            'la ficha del paciente.',
        severity: PlanValidationSeverity.pass,
      );
    }

    final conflicts = <String>{};
    for (final item in draft.meals.expand((meal) => meal.items)) {
      if (restrictions.conflictsWith(item.food)) {
        conflicts.add(item.food.name);
      }
    }

    if (conflicts.isNotEmpty) {
      return PlanValidationCheck(
        id: 'restrictions',
        title: 'Restricciones y alérgenos',
        detail:
            'Incompatibilidad detectada en: ${conflicts.take(5).join(', ')}. '
            'Corrige el borrador antes de aplicarlo.',
        severity: PlanValidationSeverity.blocking,
      );
    }

    return PlanValidationCheck(
      id: 'restrictions',
      title: 'Restricciones y alérgenos',
      detail:
          'No se detectaron incompatibilidades con: '
          '${restrictions.labels.join(', ')}.',
      severity: PlanValidationSeverity.pass,
    );
  }

  static double? _positiveOrNull(double? value) =>
      value != null && value.isFinite && value > 0 ? value : null;
}

class _Restrictions {
  final bool vegetarian;
  final bool vegan;
  final bool milk;
  final bool gluten;
  final bool egg;
  final bool peanutOrTreeNut;
  final bool soy;
  final bool sesame;
  final bool shellfish;
  final bool hasUnmappedPatientText;

  const _Restrictions({
    required this.vegetarian,
    required this.vegan,
    required this.milk,
    required this.gluten,
    required this.egg,
    required this.peanutOrTreeNut,
    required this.soy,
    required this.sesame,
    required this.shellfish,
    required this.hasUnmappedPatientText,
  });

  factory _Restrictions.from({
    required String prompt,
    String? patientAllergies,
    String? patientIntolerances,
  }) {
    final promptText = _normalize(prompt);
    final patientText = _normalize(
      [
        patientAllergies,
        patientIntolerances,
      ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' '),
    );

    bool mentions(List<String> values) => values.any(
      (value) => promptText.contains(value) || patientText.contains(value),
    );

    final vegan = promptText.contains('vegan');
    final vegetarian = vegan || promptText.contains('vegetar');
    final milk = mentions(const [
      'sin lactosa',
      'lactosa',
      'alergia leche',
      'alergia a la leche',
      'milk',
      'dairy',
      'caseina',
      'casein',
      'suero de leche',
      'whey',
    ]);
    final gluten = mentions(const [
      'sin gluten',
      'gluten',
      'celiac',
      'trigo',
      'wheat',
    ]);
    final egg = mentions(const ['sin huevo', 'huevo', 'egg']);
    final peanutOrTreeNut = mentions(const [
      'mani',
      'peanut',
      'nuez',
      'nueces',
      'frutos secos',
      'almendra',
      'almond',
      'avellana',
      'hazelnut',
      'pistacho',
      'pistachio',
      'cashew',
      'anacardo',
    ]);
    final soy = mentions(const ['soja', 'soy']);
    final sesame = mentions(const ['sesamo', 'sesame']);
    final shellfish = mentions(const [
      'marisco',
      'mariscos',
      'camaron',
      'camarones',
      'shrimp',
      'crustaceo',
      'crustaceos',
      'shellfish',
    ]);

    final mapped =
        milk || gluten || egg || peanutOrTreeNut || soy || sesame || shellfish;
    final hasPatientText = patientText.trim().isNotEmpty;

    return _Restrictions(
      vegetarian: vegetarian,
      vegan: vegan,
      milk: milk || vegan,
      gluten: gluten,
      egg: egg || vegan,
      peanutOrTreeNut: peanutOrTreeNut,
      soy: soy,
      sesame: sesame,
      shellfish: shellfish,
      hasUnmappedPatientText: hasPatientText && !mapped,
    );
  }

  bool get hasAny =>
      vegetarian ||
      vegan ||
      milk ||
      gluten ||
      egg ||
      peanutOrTreeNut ||
      soy ||
      sesame ||
      shellfish ||
      hasUnmappedPatientText;

  List<String> get labels => [
    if (vegan) 'vegano' else if (vegetarian) 'vegetariano',
    if (milk) 'leche/lactosa',
    if (gluten) 'gluten',
    if (egg) 'huevo',
    if (peanutOrTreeNut) 'maní/frutos secos',
    if (soy) 'soja',
    if (sesame) 'sésamo',
    if (shellfish) 'mariscos',
    if (hasUnmappedPatientText) 'otras restricciones registradas',
  ];

  bool conflictsWith(Food food) {
    final text = _normalize(
      [
        food.name,
        food.brand,
        food.notes,
        ...food.allergens,
      ].whereType<String>().join(' '),
    );

    if ((vegetarian || vegan) &&
        _containsAny(text, const [
          'chicken',
          'pollo',
          'beef',
          'carne vacuna',
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
          'shellfish',
          'marisco',
        ])) {
      return true;
    }

    if (vegan &&
        _containsAny(text, const [
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
          'egg',
          'huevo',
        ])) {
      return true;
    }

    if (milk &&
        _containsAny(text, const [
          'milk',
          'leche',
          'lactosa',
          'yogurt',
          'yoghurt',
          'queso',
          'cheese',
          'buttermilk',
          'cream',
          'crema',
          'whey',
          'casein',
          'caseina',
        ])) {
      return true;
    }

    if (gluten &&
        _containsAny(text, const [
          'gluten',
          'wheat',
          'trigo',
          'bread',
          'barley',
          'cebada',
          'rye',
          'centeno',
          'pasta',
        ])) {
      return true;
    }

    if (egg && _containsAny(text, const ['egg', 'huevo'])) return true;

    if (peanutOrTreeNut &&
        _containsAny(text, const [
          'peanut',
          'mani',
          'almond',
          'almendra',
          'walnut',
          'nuez',
          'cashew',
          'anacardo',
          'pistachio',
          'pistacho',
          'hazelnut',
          'avellana',
          'tree nuts',
          'tree_nuts',
        ])) {
      return true;
    }

    if (soy && _containsAny(text, const ['soy', 'soja'])) return true;
    if (sesame && _containsAny(text, const ['sesame', 'sesamo'])) return true;

    if (shellfish &&
        _containsAny(text, const [
          'shrimp',
          'camaron',
          'shellfish',
          'marisco',
          'crustaceo',
        ])) {
      return true;
    }

    return false;
  }

  static bool _containsAny(String text, List<String> values) =>
      values.any(text.contains);

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
}
