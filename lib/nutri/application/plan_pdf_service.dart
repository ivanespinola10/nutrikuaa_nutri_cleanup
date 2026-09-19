import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/nutri_database.dart';
import '../data/patient_repository.dart';
import '../domain/app_settings.dart';
import '../domain/meal_plan.dart';
import '../domain/nutrition/nutrient.dart';
import '../domain/patient.dart';
import '../domain/professional_profile.dart';
import 'meal_plan_service.dart';
import 'nutrition_calculator.dart';
import 'plan_nutrition_service.dart';
import 'recipe_service.dart';

class PlanPdfService {
  final NutriDatabase database;
  final PatientRepository patients;
  final MealPlanService plans;
  final PlanNutritionService nutrition;
  final RecipeService recipes;

  PlanPdfService({
    NutriDatabase? database,
    PatientRepository? patients,
    MealPlanService? plans,
    PlanNutritionService? nutrition,
    RecipeService? recipes,
  })  : database = database ?? NutriDatabase.instance,
        patients = patients ?? PatientRepository(database: database),
        plans = plans ?? MealPlanService(database: database),
        nutrition = nutrition ?? PlanNutritionService(database: database),
        recipes = recipes ?? RecipeService(database: database);

  Future<Uint8List> build({
    required int planId,
    required ProfessionalProfile profile,
    Uint8List? logoBytes,
    bool includeNutritionSummary = true,
    bool includeRecipeInstructions = true,
    AppSettings settings = const AppSettings(),
  }) async {
    final details = await plans.getById(planId);
    if (details == null) {
      throw StateError('Meal plan does not exist.');
    }

    final patient = await patients.getById(details.plan.patientId);
    if (patient == null) {
      throw StateError('Patient referenced by plan does not exist.');
    }

    final labels = _PdfLabels(settings.languageCode);
    final targets = await patients.targetsFor(patient.id!);
    final summary = await nutrition.calculate(planId);
    final resolved = await _resolveMeals(
      details,
      labels: labels,
      unitSystem: settings.unitSystem,
    );
    final recipeInstructions = includeRecipeInstructions
        ? await _resolveRecipeInstructions(details)
        : const <_RecipeInstruction>[];

    final document = pw.Document(
      title: '${labels.planTitle} - ${patient.displayName}',
      author: profile.fullName.trim().isEmpty
          ? 'Nutrikuaa Nutri'
          : profile.fullName.trim(),
      creator: 'Nutrikuaa Nutri',
    );

    final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);
    final primary = PdfColors.teal700;
    final soft = PdfColors.teal50;
    final border = PdfColors.grey300;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 34, 34, 42),
        header: (context) => _header(
          profile: profile,
          logo: logo,
          primary: primary,
          labels: labels,
        ),
        footer: (context) => _footer(
          context,
          profile: profile,
          labels: labels,
        ),
        build: (context) => [
          pw.SizedBox(height: 10),
          _patientCard(
            patient: patient,
            plan: details.plan,
            primary: primary,
            soft: soft,
            border: border,
          ),
          if (targets.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _targetsCard(
              targets: targets,
              primary: primary,
              border: border,
              labels: labels,
            ),
          ],
          pw.SizedBox(height: 16),
          pw.Text(
            labels.weeklyPlan,
            style: pw.TextStyle(
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            ),
          ),
          pw.SizedBox(height: 8),
          ...List.generate(7, (dayIndex) {
            final dayMeals = resolved
                .where((meal) => meal.dayIndex == dayIndex)
                .toList();
            final totals = summary.totalsForDay(dayIndex);
            return _daySection(
              dayIndex: dayIndex,
              meals: dayMeals,
              totals: totals,
              includeNutritionSummary: includeNutritionSummary,
              primary: primary,
              soft: soft,
              border: border,
              labels: labels,
            );
          }),
          if (details.plan.notes != null &&
              details.plan.notes!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _textSection(
              title: labels.generalInstructions,
              body: details.plan.notes!.trim(),
              primary: primary,
              border: border,
            ),
          ],
          if (recipeInstructions.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              labels.preparations,
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
            pw.SizedBox(height: 6),
            ...recipeInstructions.map(
              (recipe) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: border),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      recipe.name,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      recipe.instructions,
                      style: const pw.TextStyle(fontSize: 9.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return document.save();
  }

  Future<List<_ResolvedMeal>> _resolveMeals(
    MealPlanDetails details, {
    required _PdfLabels labels,
    required UnitSystem unitSystem,
  }) async {
    final meals = <_ResolvedMeal>[];

    for (final mealWithItems in details.meals) {
      final items = <_ResolvedItem>[];

      for (final item in mealWithItems.items) {
        if (item.itemType == MealItemType.food) {
          final food = await database.getFood(item.foodId!);
          if (food == null) continue;

          final label = food.brand == null || food.brand!.trim().isEmpty
              ? food.name
              : '${food.name} - ${food.brand}';
          final grams = item.quantityGrams ?? 0;
          final portionText = item.notes?.trim();

          items.add(
            _ResolvedItem(
              label: label,
              quantity: portionText == null || portionText.isEmpty
                  ? _formatFoodWeight(grams, unitSystem)
                  : '$portionText (${_formatFoodWeight(grams, unitSystem)})',
            ),
          );
        } else {
          final recipe = await recipes.getById(item.recipeId!);
          if (recipe == null) continue;
          final servings = item.servings ?? 1;

          items.add(
            _ResolvedItem(
              label: recipe.recipe.name,
              quantity: '${_number(servings)} ${labels.servings}',
            ),
          );
        }
      }

      meals.add(
        _ResolvedMeal(
          dayIndex: mealWithItems.meal.dayIndex,
          name: mealWithItems.meal.name,
          items: items,
        ),
      );
    }

    return meals;
  }

  Future<List<_RecipeInstruction>> _resolveRecipeInstructions(
    MealPlanDetails details,
  ) async {
    final ids = <int>{};
    for (final meal in details.meals) {
      for (final item in meal.items) {
        if (item.itemType == MealItemType.recipe && item.recipeId != null) {
          ids.add(item.recipeId!);
        }
      }
    }

    final result = <_RecipeInstruction>[];
    for (final id in ids) {
      final details = await recipes.getById(id);
      if (details == null) continue;
      final notes = details.recipe.notes?.trim();
      if (notes == null || notes.isEmpty) continue;

      result.add(
        _RecipeInstruction(
          name: details.recipe.name,
          instructions: notes,
        ),
      );
    }
    return result;
  }

  pw.Widget _header({
    required ProfessionalProfile profile,
    required pw.MemoryImage? logo,
    required PdfColor primary,
    required _PdfLabels labels,
  }) {
    final professionalLines = <String>[
      if (profile.practiceName != null &&
          profile.practiceName!.trim().isNotEmpty)
        profile.practiceName!.trim(),
      if (profile.fullName.trim().isNotEmpty) profile.fullName.trim(),
      [
        if (profile.credentials != null &&
            profile.credentials!.trim().isNotEmpty)
          profile.credentials!.trim(),
        if (profile.registrationNumber != null &&
            profile.registrationNumber!.trim().isNotEmpty)
          'Reg. ${profile.registrationNumber!.trim()}',
      ].where((value) => value.isNotEmpty).join(' - '),
    ].where((value) => value.isNotEmpty).toList();

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logo != null) ...[
          pw.Container(
            width: 42,
            height: 42,
            child: pw.Image(
              logo,
              fit: pw.BoxFit.contain,
            ),
          ),
          pw.SizedBox(width: 10),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                professionalLines.isEmpty
                    ? labels.planTitle
                    : professionalLines.first,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: primary,
                ),
              ),
              ...professionalLines.skip(1).map(
                    (line) => pw.Text(
                      line,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              labels.planTitle.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
            pw.Text(
              'Nutrikuaa Nutri',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _footer(
    pw.Context context, {
    required ProfessionalProfile profile,
    required _PdfLabels labels,
  }) {
    final contact = [
      if (profile.phone != null && profile.phone!.trim().isNotEmpty)
        profile.phone!.trim(),
      if (profile.email != null && profile.email!.trim().isNotEmpty)
        profile.email!.trim(),
    ].join(' - ');

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.grey300,
            width: 0.5,
          ),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              profile.footerText?.trim().isNotEmpty == true
                  ? profile.footerText!.trim()
                  : contact,
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.Text(
            '${labels.page} ${context.pageNumber} ${labels.ofWord} ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 7.5,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _patientCard({
    required Patient patient,
    required MealPlan plan,
    required PdfColor primary,
    required PdfColor soft,
    required PdfColor border,
  }) {
    final dates = _planDates(plan);
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: soft,
        border: pw.Border.all(color: border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  patient.displayName,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: primary,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  plan.name,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          if (dates.isNotEmpty)
            pw.Text(
              dates,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _targetsCard({
    required List<NutritionTarget> targets,
    required PdfColor primary,
    required PdfColor border,
    required _PdfLabels labels,
  }) {
    final wanted = [
      NutrientCodes.energyKcal,
      NutrientCodes.protein,
      NutrientCodes.carbohydrate,
      NutrientCodes.fat,
      NutrientCodes.fiber,
    ];

    final values = <NutritionTarget>[];
    for (final code in wanted) {
      for (final target in targets) {
        if (target.nutrientCode == code) {
          values.add(target);
          break;
        }
      }
    }

    if (values.isEmpty) return pw.SizedBox();

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            labels.dailyTargets,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Wrap(
            spacing: 14,
            runSpacing: 4,
            children: values
                .map(
                  (target) => pw.Text(
                    '${labels.nutrient(target.nutrientCode)}: '
                    '${_number(target.targetValue)} '
                    '${_unit(target.unit)}',
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  pw.Widget _daySection({
    required int dayIndex,
    required List<_ResolvedMeal> meals,
    required NutritionTotals totals,
    required bool includeNutritionSummary,
    required PdfColor primary,
    required PdfColor soft,
    required PdfColor border,
    required _PdfLabels labels,
  }) {
    final nonEmptyMeals = meals.where((meal) => meal.items.isNotEmpty).toList();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 11),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: pw.BoxDecoration(
              color: soft,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    labels.days[dayIndex],
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: primary,
                    ),
                  ),
                ),
                if (includeNutritionSummary)
                  pw.Text(
                    '${_number(totals.value(NutrientCodes.energyKcal))} kcal'
                    ' | P ${_number(totals.value(NutrientCodes.protein))} g'
                    ' | C ${_number(totals.value(NutrientCodes.carbohydrate))} g'
                    ' | G ${_number(totals.value(NutrientCodes.fat))} g',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColors.grey700,
                    ),
                  ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: nonEmptyMeals.isEmpty
                ? pw.Text(
                    labels.emptyDay,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  )
                : pw.Column(
                    children: nonEmptyMeals
                        .map(
                          (meal) => pw.Container(
                            margin: const pw.EdgeInsets.only(bottom: 7),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  labels.meal(meal.name),
                                  style: pw.TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                ...meal.items.map(
                                  (item) => pw.Padding(
                                    padding:
                                        const pw.EdgeInsets.only(bottom: 2),
                                    child: pw.Row(
                                      crossAxisAlignment:
                                          pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(
                                          '• ',
                                          style: const pw.TextStyle(
                                            fontSize: 9,
                                          ),
                                        ),
                                        pw.Expanded(
                                          child: pw.Text(
                                            item.label,
                                            style: const pw.TextStyle(
                                              fontSize: 9,
                                            ),
                                          ),
                                        ),
                                        pw.SizedBox(width: 8),
                                        pw.Text(
                                          item.quantity,
                                          style: const pw.TextStyle(
                                            fontSize: 9,
                                            color: PdfColors.grey700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  pw.Widget _textSection({
    required String title,
    required String body,
    required PdfColor primary,
    required PdfColor border,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            body,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  String _planDates(MealPlan plan) {
    if (plan.startDate == null && plan.endDate == null) return '';
    if (plan.startDate != null && plan.endDate != null) {
      return '${_date(plan.startDate!)} - ${_date(plan.endDate!)}';
    }
    return _date(plan.startDate ?? plan.endDate!);
  }

  String _date(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  String _unit(NutrientUnit unit) {
    switch (unit) {
      case NutrientUnit.kilocalorie:
        return 'kcal';
      case NutrientUnit.gram:
        return 'g';
      case NutrientUnit.milligram:
        return 'mg';
      case NutrientUnit.microgram:
        return 'µg';
      case NutrientUnit.internationalUnit:
        return 'UI';
    }
  }

  static String _formatFoodWeight(
    double grams,
    UnitSystem unitSystem,
  ) {
    if (unitSystem == UnitSystem.imperial) {
      final ounces = grams / 28.349523125;
      return '${_number(ounces)} oz';
    }
    return '${_number(grams)} g';
  }

  static String _number(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _ResolvedMeal {
  final int dayIndex;
  final String name;
  final List<_ResolvedItem> items;

  const _ResolvedMeal({
    required this.dayIndex,
    required this.name,
    required this.items,
  });
}

class _ResolvedItem {
  final String label;
  final String quantity;

  const _ResolvedItem({
    required this.label,
    required this.quantity,
  });
}

class _RecipeInstruction {
  final String name;
  final String instructions;

  const _RecipeInstruction({
    required this.name,
    required this.instructions,
  });
}


class _PdfLabels {
  final String languageCode;

  _PdfLabels(String languageCode)
      : languageCode = const ['es', 'en', 'pt'].contains(languageCode)
            ? languageCode
            : 'es';

  List<String> get days {
    switch (languageCode) {
      case 'en':
        return const [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];
      case 'pt':
        return const [
          'Segunda-feira',
          'Terça-feira',
          'Quarta-feira',
          'Quinta-feira',
          'Sexta-feira',
          'Sábado',
          'Domingo',
        ];
      default:
        return const [
          'Lunes',
          'Martes',
          'Miércoles',
          'Jueves',
          'Viernes',
          'Sábado',
          'Domingo',
        ];
    }
  }

  String get planTitle => _t(
        es: 'Plan nutricional',
        en: 'Nutrition plan',
        pt: 'Plano nutricional',
      );

  String get weeklyPlan => _t(
        es: 'Plan semanal',
        en: 'Weekly plan',
        pt: 'Plano semanal',
      );

  String get generalInstructions => _t(
        es: 'Indicaciones generales',
        en: 'General instructions',
        pt: 'Orientações gerais',
      );

  String get preparations => _t(
        es: 'Preparaciones',
        en: 'Preparations',
        pt: 'Preparações',
      );

  String get dailyTargets => _t(
        es: 'Objetivos diarios',
        en: 'Daily targets',
        pt: 'Metas diárias',
      );

  String get emptyDay => _t(
        es: 'Sin alimentos ni recetas.',
        en: 'No foods or recipes.',
        pt: 'Sem alimentos ou receitas.',
      );

  String get servings => _t(
        es: 'porción(es)',
        en: 'serving(s)',
        pt: 'porção(ões)',
      );

  String get page => _t(es: 'Página', en: 'Page', pt: 'Página');
  String get ofWord => _t(es: 'de', en: 'of', pt: 'de');

  String nutrient(String code) {
    switch (code) {
      case NutrientCodes.energyKcal:
        return _t(es: 'Energía', en: 'Energy', pt: 'Energia');
      case NutrientCodes.protein:
        return _t(es: 'Proteína', en: 'Protein', pt: 'Proteína');
      case NutrientCodes.carbohydrate:
        return _t(
          es: 'Carbohidratos',
          en: 'Carbohydrates',
          pt: 'Carboidratos',
        );
      case NutrientCodes.fat:
        return _t(es: 'Grasas', en: 'Fat', pt: 'Gorduras');
      case NutrientCodes.fiber:
        return _t(es: 'Fibra', en: 'Fiber', pt: 'Fibra');
      default:
        return code;
    }
  }

  String meal(String value) {
    final key = value.trim().toLowerCase();
    const map = {
      'desayuno': ['Breakfast', 'Café da manhã'],
      'media mañana': ['Morning snack', 'Lanche da manhã'],
      'almuerzo': ['Lunch', 'Almoço'],
      'merienda': ['Afternoon snack', 'Lanche da tarde'],
      'cena': ['Dinner', 'Jantar'],
    };

    final translated = map[key];
    if (translated == null || languageCode == 'es') return value;
    return languageCode == 'en' ? translated[0] : translated[1];
  }

  String _t({
    required String es,
    required String en,
    required String pt,
  }) {
    switch (languageCode) {
      case 'en':
        return en;
      case 'pt':
        return pt;
      default:
        return es;
    }
  }
}
