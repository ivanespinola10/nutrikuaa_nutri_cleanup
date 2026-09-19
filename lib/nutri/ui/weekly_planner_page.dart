import 'package:flutter/material.dart';

import '../application/food_placement_service.dart';
import '../application/meal_plan_service.dart';
import '../application/plan_nutrition_service.dart';
import '../application/recipe_service.dart';
import '../application/unified_food_search_service.dart';
import '../data/nutri_database.dart';
import '../data/patient_repository.dart';
import '../domain/food.dart';
import '../domain/meal_plan.dart';
import '../domain/nutrition/nutrient.dart';
import '../domain/patient.dart';
import '../domain/recipe.dart';

class WeeklyPlannerPage extends StatefulWidget {
  final int refreshToken;

  const WeeklyPlannerPage({
    super.key,
    this.refreshToken = 0,
  });

  @override
  State<WeeklyPlannerPage> createState() => _WeeklyPlannerPageState();
}

class _WeeklyPlannerPageState extends State<WeeklyPlannerPage> {
  static const _days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static const _mealNames = [
    'Desayuno',
    'Media mañana',
    'Almuerzo',
    'Merienda',
    'Cena',
  ];

  final PatientRepository _patients = PatientRepository();
  final MealPlanService _plans = MealPlanService();
  final PlanNutritionService _nutrition = PlanNutritionService();
  final UnifiedFoodSearchService _foodSearch = UnifiedFoodSearchService();
  final FoodPlacementService _placement = FoodPlacementService();
  final RecipeService _recipes = RecipeService();
  final NutriDatabase _database = NutriDatabase.instance;

  final _query = TextEditingController();
  final _grams = TextEditingController(text: '150');
  final _servings = TextEditingController(text: '1');
  final _portionAmount = TextEditingController(text: '1');

  List<Patient> _patientList = const [];
  List<MealPlan> _patientPlans = const [];
  List<NutritionTarget> _targets = const [];
  MealPlanDetails? _details;
  PlanNutritionSummary? _summary;
  FoodSearchResults _foodResults =
      const FoodSearchResults(professional: [], official: []);
  List<Recipe> _recipeResults = const [];

  final Map<int, String> _itemLabels = {};

  int? _selectedPatientId;
  int? _selectedPlanId;
  int _selectedDay = 0;
  String _selectedMealName = 'Desayuno';
  Food? _selectedFood;
  FoodPortion? _selectedPortion;
  Recipe? _selectedRecipe;
  bool _recipeMode = false;
  bool _usePortion = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant WeeklyPlannerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _refreshFromDatabase();
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _grams.dispose();
    _servings.dispose();
    _portionAmount.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _database.database;
      await _refreshFromDatabase();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshFromDatabase() async {
    final patients = await _patients.search('', activeOnly: false);
    if (!mounted) return;

    if (patients.isEmpty) {
      setState(() {
        _patientList = const [];
        _selectedPatientId = null;
        _patientPlans = const [];
        _targets = const [];
        _selectedPlanId = null;
        _details = null;
        _summary = null;
      });
      return;
    }

    var patientId = _selectedPatientId;
    final stillExists = patients.any((patient) => patient.id == patientId);
    if (!stillExists) {
      patientId = patients.first.id;
    }

    setState(() {
      _patientList = patients;
      _selectedPatientId = patientId;
    });

    await _loadPatient(patientId!);
  }

  Future<void> _loadPatient(int patientId) async {
    final plans = await _plans.listForPatient(patientId);
    final targets = await _patients.targetsFor(patientId);

    if (!mounted) return;
    setState(() {
      _selectedPatientId = patientId;
      _patientPlans = plans;
      _targets = targets;
      _selectedPlanId = plans.isEmpty ? null : plans.first.id;
      _details = null;
      _summary = null;
    });

    if (_selectedPlanId != null) {
      await _loadPlan(_selectedPlanId!);
    }
  }

  Future<void> _loadPlan(int planId) async {
    final details = await _plans.getById(planId);
    if (details == null) return;

    final summary = await _nutrition.calculate(planId);
    final labels = <int, String>{};

    for (final meal in details.meals) {
      for (final item in meal.items) {
        final itemId = item.id;
        if (itemId == null) continue;

        if (item.itemType == MealItemType.food) {
          final food = await _database.getFood(item.foodId!);
          labels[itemId] = food == null
              ? 'Alimento'
              : food.brand == null
                  ? food.name
                  : '${food.name} · ${food.brand}';
        } else {
          final recipe = await _recipes.getById(item.recipeId!);
          labels[itemId] = recipe?.recipe.name ?? 'Receta';
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _selectedPlanId = planId;
      _details = details;
      _summary = summary;
      _itemLabels
        ..clear()
        ..addAll(labels);
    });
  }

  Future<void> _createWeek() async {
    final patientId = _selectedPatientId;
    if (patientId == null) {
      _message('Primero crea o selecciona un paciente.');
      return;
    }

    await _execute(() async {
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      final monday = day.subtract(Duration(days: day.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final name =
          'Semana ${_two(monday.day)}/${_two(monday.month)}/${monday.year}';

      final planId = await _plans.createPlan(
        MealPlan(
          patientId: patientId,
          name: name,
          startDate: monday,
          endDate: sunday,
        ),
      );

      for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
        for (var i = 0; i < _mealNames.length; i++) {
          await _plans.addMeal(
            planId: planId,
            dayIndex: dayIndex,
            name: _mealNames[i],
            sortOrder: i,
          );
        }
      }

      final plans = await _plans.listForPatient(patientId);
      if (!mounted) return;
      setState(() {
        _patientPlans = plans;
        _selectedPlanId = planId;
        _selectedDay = 0;
        _selectedMealName = _mealNames.first;
      });
      await _loadPlan(planId);
      _message('Semana creada con 7 días y 5 comidas por día.');
    });
  }

  Future<void> _search() async {
    final query = _query.text.trim();

    if (_recipeMode) {
      final recipes = await _recipes.search(query);
      if (!mounted) return;
      setState(() => _recipeResults = recipes);
      return;
    }

    final foods = await _foodSearch.search(
      query,
      professionalLimit: 20,
      officialLimit: 20,
    );
    if (!mounted) return;
    setState(() => _foodResults = foods);
  }

  List<FoodPortion> get _availablePortions {
    final food = _selectedFood;
    if (food == null) return const [];

    final portions = <FoodPortion>[...food.portions];
    if (portions.isEmpty &&
        food.householdMeasure != null &&
        food.servingQuantity != null &&
        food.servingQuantity! > 0 &&
        food.servingUnit?.toLowerCase() == 'g') {
      portions.add(
        FoodPortion(
          amount: 1,
          measure: food.householdMeasure,
          gramWeight: food.servingQuantity!,
        ),
      );
    }
    return portions;
  }

  void _selectFood(Food food) {
    final portions = <FoodPortion>[...food.portions];
    if (portions.isEmpty &&
        food.householdMeasure != null &&
        food.servingQuantity != null &&
        food.servingQuantity! > 0 &&
        food.servingUnit?.toLowerCase() == 'g') {
      portions.add(
        FoodPortion(
          amount: 1,
          measure: food.householdMeasure,
          gramWeight: food.servingQuantity!,
        ),
      );
    }

    setState(() {
      _selectedFood = food;
      _selectedPortion = portions.isEmpty ? null : portions.first;
      _usePortion = false;
    });
  }

  double _selectedFoodGrams() {
    if (!_usePortion) {
      return double.tryParse(_grams.text.replaceAll(',', '.')) ?? 0;
    }

    final portion = _selectedPortion;
    final requested =
        double.tryParse(_portionAmount.text.replaceAll(',', '.')) ?? 0;
    if (portion == null || requested <= 0) return 0;

    final baseAmount =
        portion.amount == null || portion.amount! <= 0 ? 1.0 : portion.amount!;
    return portion.gramWeight * requested / baseAmount;
  }

  Future<void> _addSelected() async {
    final planId = _selectedPlanId;
    if (planId == null) {
      _message('Crea una semana primero.');
      return;
    }

    await _execute(() async {
      final mealId = await _plans.getOrCreateMeal(
        planId: planId,
        dayIndex: _selectedDay,
        name: _selectedMealName,
        sortOrder: _mealNames.indexOf(_selectedMealName),
      );
      if (_recipeMode) {
        final recipe = _selectedRecipe;
        if (recipe == null) {
          _message('Selecciona una receta.');
          return;
        }
        final servings =
            double.tryParse(_servings.text.replaceAll(',', '.')) ?? 0;
        if (servings <= 0) {
          _message('Las porciones deben ser mayores que cero.');
          return;
        }
        await _plans.addRecipe(
          mealId: mealId,
          recipeId: recipe.id!,
          servings: servings,
        );
      } else {
        final food = _selectedFood;
        if (food == null) {
          _message('Selecciona un alimento.');
          return;
        }
        final grams = _selectedFoodGrams();
        if (grams <= 0) {
          _message('Los gramos deben ser mayores que cero.');
          return;
        }
        await _placement.addSelectedFoodToMeal(
          mealId: mealId,
          selectedFood: food,
          quantityGrams: grams,
        );
      }

      await _loadPlan(planId);
      await _search();
      _message('Agregado a $_selectedMealName · ${_days[_selectedDay]}.');
    });
  }

  Future<void> _editItem(MealItem item) async {
    final planId = _selectedPlanId;
    if (planId == null || item.id == null) return;

    final initial = item.itemType == MealItemType.food
        ? item.quantityGrams ?? 0
        : item.servings ?? 1;
    final controller = TextEditingController(
      text: initial.toStringAsFixed(
        item.itemType == MealItemType.food ? 0 : 1,
      ),
    );

    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          item.itemType == MealItemType.food
              ? 'Editar cantidad'
              : 'Editar porciones',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: item.itemType == MealItemType.food
                ? 'Gramos'
                : 'Porciones',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(
                controller.text.replaceAll(',', '.'),
              );
              Navigator.pop(context, parsed);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (value == null || value <= 0) return;

    await _execute(() async {
      if (item.itemType == MealItemType.food) {
        await _plans.updateFoodQuantity(
          mealItemId: item.id!,
          quantityGrams: value,
        );
      } else {
        await _plans.updateRecipeServings(
          mealItemId: item.id!,
          servings: value,
        );
      }
      await _loadPlan(planId);
      _message('Cantidad actualizada.');
    });
  }

  Future<void> _copyMealToDay(MealWithItems meal) async {
    final planId = _selectedPlanId;
    if (planId == null || meal.meal.id == null) return;

    final targetDay = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Copiar ${meal.meal.name} a...'),
        children: List.generate(7, (index) {
          if (index == _selectedDay) return const SizedBox.shrink();
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, index),
            child: Text(_days[index]),
          );
        }),
      ),
    );

    if (targetDay == null) return;

    await _execute(() async {
      final targetMealId = await _plans.getOrCreateMeal(
        planId: planId,
        dayIndex: targetDay,
        name: meal.meal.name,
        sortOrder: meal.meal.sortOrder,
      );
      await _plans.copyMealItems(
        sourceMealId: meal.meal.id!,
        targetMealId: targetMealId,
        replaceTarget: true,
      );
      await _loadPlan(planId);
      _message('${meal.meal.name} copiado a ${_days[targetDay]}.');
    });
  }

  Future<void> _clearMeal(MealWithItems meal) async {
    if (meal.meal.id == null || meal.items.isEmpty) return;
    final planId = _selectedPlanId;
    if (planId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar comida'),
        content: Text(
          '¿Eliminar todos los elementos de ${meal.meal.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _execute(() async {
      await _plans.clearMeal(meal.meal.id!);
      await _loadPlan(planId);
      _message('${meal.meal.name} vaciado.');
    });
  }

  Future<void> _copyCurrentDay() async {
    final planId = _selectedPlanId;
    if (planId == null) return;

    final targetDay = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Copiar ${_days[_selectedDay]} a...'),
        children: List.generate(7, (index) {
          if (index == _selectedDay) return const SizedBox.shrink();
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, index),
            child: Text(_days[index]),
          );
        }),
      ),
    );

    if (targetDay == null) return;

    await _execute(() async {
      await _plans.copyDay(
        planId: planId,
        sourceDayIndex: _selectedDay,
        targetDayIndex: targetDay,
        replaceTarget: true,
      );
      await _loadPlan(planId);
      _message(
        '${_days[_selectedDay]} copiado a ${_days[targetDay]}.',
      );
    });
  }

  Future<void> _duplicateCurrentWeek() async {
    final planId = _selectedPlanId;
    final details = _details;
    final patientId = _selectedPatientId;
    if (planId == null || details == null || patientId == null) return;

    await _execute(() async {
      final sourceStart = details.plan.startDate ?? DateTime.now();
      final newStart = sourceStart.add(const Duration(days: 7));
      final newEnd = newStart.add(const Duration(days: 6));
      final name =
          'Semana ${_two(newStart.day)}/${_two(newStart.month)}/${newStart.year}';

      final newPlanId = await _plans.duplicatePlan(
        planId,
        newName: name,
        newStartDate: newStart,
        newEndDate: newEnd,
      );

      final plans = await _plans.listForPatient(patientId);
      if (!mounted) return;
      setState(() {
        _patientPlans = plans;
        _selectedPlanId = newPlanId;
      });
      await _loadPlan(newPlanId);
      _message('Semana duplicada.');
    });
  }

  Future<void> _removeItem(int itemId) async {
    final planId = _selectedPlanId;
    if (planId == null) return;

    await _execute(() async {
      await _plans.removeMealItem(itemId);
      await _loadPlan(planId);
      _message('Elemento eliminado del plan.');
    });
  }

  MealWithItems? _mealFor(String name) {
    final details = _details;
    if (details == null) return null;

    for (final meal in details.meals) {
      if (meal.meal.dayIndex == _selectedDay && meal.meal.name == name) {
        return meal;
      }
    }
    return null;
  }

  double _target(String code) {
    for (final target in _targets) {
      if (target.nutrientCode == code) return target.targetValue;
    }
    return 0;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  Future<void> _execute(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Planificador semanal',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar pacientes y planes',
            onPressed: _busy ? null : _refreshFromDatabase,
            icon: const Icon(Icons.refresh),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 18),
            child: Center(child: Text('V0.4')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_patientList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Todavía no hay pacientes. Créalo primero en Biblioteca.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _refreshFromDatabase,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar pacientes'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(),
              if (_error != null) ...[
                const SizedBox(height: 10),
                SelectableText(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_selectedPlanId == null)
                _emptyPlan()
              else ...[
                _weekOverview(),
                const SizedBox(height: 16),
                _daySelector(),
                const SizedBox(height: 16),
                _composer(),
                const SizedBox(height: 16),
                _mealGrid(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<int>(
                value: _selectedPatientId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Paciente'),
                items: _patientList
                    .map(
                      (patient) => DropdownMenuItem(
                        value: patient.id,
                        child: Text(patient.displayName),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (id) {
                        if (id != null) _loadPatient(id);
                      },
              ),
            ),
            SizedBox(
              width: 290,
              child: DropdownButtonFormField<int>(
                value: _selectedPlanId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Semana'),
                items: _patientPlans
                    .map(
                      (plan) => DropdownMenuItem(
                        value: plan.id,
                        child: Text(plan.name),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (id) {
                        if (id != null) _loadPlan(id);
                      },
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _createWeek,
              icon: const Icon(Icons.calendar_month),
              label: const Text('Nueva semana'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || _selectedPlanId == null
                  ? null
                  : _duplicateCurrentWeek,
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Duplicar semana'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyPlan() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.calendar_view_week_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Este paciente todavía no tiene una semana de alimentación.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _createWeek,
              child: const Text('Crear primera semana'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekOverview() {
    final summary = _summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen semanal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(7, (index) {
                  final totals = summary?.totalsForDay(index);
                  final kcal =
                      totals?.value(NutrientCodes.energyKcal) ?? 0;
                  final protein =
                      totals?.value(NutrientCodes.protein) ?? 0;
                  final selected = index == _selectedDay;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedDay = index),
                      child: Container(
                        width: 125,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _days[index],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('${kcal.toStringAsFixed(0)} kcal'),
                            Text('P ${protein.toStringAsFixed(1)} g'),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _daySelector() {
    final totals = _summary?.totalsForDay(_selectedDay);
    final kcal = totals?.value(NutrientCodes.energyKcal) ?? 0;
    final protein = totals?.value(NutrientCodes.protein) ?? 0;
    final kcalTarget = _target(NutrientCodes.energyKcal);
    final proteinTarget = _target(NutrientCodes.protein);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                7,
                (index) => ChoiceChip(
                  label: Text(_days[index]),
                  selected: index == _selectedDay,
                  onSelected: (_) => setState(() => _selectedDay = index),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _copyCurrentDay,
                icon: const Icon(Icons.copy_outlined),
                label: Text('Copiar ${_days[_selectedDay]} a otro día'),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _miniMetric('Energía', kcal, 'kcal', kcalTarget),
                _miniMetric('Proteína', protein, 'g', proteinTarget),
                _miniMetric(
                  'Carbohidratos',
                  totals?.value(NutrientCodes.carbohydrate) ?? 0,
                  'g',
                  0,
                ),
                _miniMetric(
                  'Grasas',
                  totals?.value(NutrientCodes.fat) ?? 0,
                  'g',
                  0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Agregar a $_selectedMealName · ${_days[_selectedDay]}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Alimentos'),
                  selected: !_recipeMode,
                  onSelected: (_) {
                    setState(() {
                      _recipeMode = false;
                      _selectedRecipe = null;
                    });
                    _search();
                  },
                ),
                ChoiceChip(
                  label: const Text('Recetas'),
                  selected: _recipeMode,
                  onSelected: (_) {
                    setState(() {
                      _recipeMode = true;
                      _selectedFood = null;
                    });
                    _search();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: _recipeMode
                          ? 'Buscar receta'
                          : 'Buscar alimento',
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _busy ? null : _search,
                  child: const Text('Buscar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_recipeMode) _recipeSearchResults() else _foodSearchResults(),
            const SizedBox(height: 12),
            if (!_recipeMode && _availablePortions.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Gramos'),
                    selected: !_usePortion,
                    onSelected: (_) => setState(() => _usePortion = false),
                  ),
                  ChoiceChip(
                    label: const Text('Porción doméstica'),
                    selected: _usePortion,
                    onSelected: (_) => setState(() {
                      _usePortion = true;
                      _selectedPortion ??= _availablePortions.first;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: _recipeMode
                      ? TextField(
                          controller: _servings,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              const InputDecoration(labelText: 'Porciones'),
                        )
                      : _usePortion && _availablePortions.isNotEmpty
                          ? Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _portionAmount,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Cantidad',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<FoodPortion>(
                                    value: _selectedPortion,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Medida',
                                    ),
                                    items: _availablePortions
                                        .map(
                                          (portion) => DropdownMenuItem(
                                            value: portion,
                                            child: Text(
                                              '${portion.measure ?? 'porción'} · ${portion.gramWeight.toStringAsFixed(0)} g',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) => setState(
                                      () => _selectedPortion = value,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : TextField(
                              controller: _grams,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Cantidad en gramos',
                              ),
                            ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _busy ? null : _addSelected,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _foodSearchResults() {
    final combined = _foodResults.combined.take(8).toList();
    if (combined.isEmpty) {
      return const Text(
        'Busca un alimento de tu biblioteca o del catálogo oficial.',
      );
    }

    return Column(
      children: combined.map((food) {
        final selected = identical(food, _selectedFood) ||
            (_selectedFood?.sourceName == food.sourceName &&
                _selectedFood?.sourceFoodId == food.sourceFoodId &&
                food.sourceFoodId != null);

        return ListTile(
          dense: true,
          leading: Icon(
            food.sourceType == FoodSourceType.officialDatabase
                ? Icons.verified_outlined
                : Icons.inventory_2_outlined,
          ),
          title: Text(
            food.brand == null
                ? food.name
                : '${food.name} · ${food.brand}',
          ),
          subtitle: Text(
            food.sourceType == FoodSourceType.officialDatabase
                ? 'USDA · FDC ${food.sourceFoodId}'
                : 'Biblioteca profesional',
          ),
          trailing: OutlinedButton(
            onPressed: () => _selectFood(food),
            child: Text(selected ? 'Elegido' : 'Elegir'),
          ),
        );
      }).toList(),
    );
  }

  Widget _recipeSearchResults() {
    if (_recipeResults.isEmpty) {
      return const Text(
        'No hay recetas para esta búsqueda. Las recetas guardadas podrán reutilizarse aquí.',
      );
    }

    return Column(
      children: _recipeResults.take(8).map((recipe) {
        final selected = recipe.id == _selectedRecipe?.id;
        return ListTile(
          dense: true,
          leading: const Icon(Icons.restaurant_menu),
          title: Text(recipe.name),
          subtitle: Text('${recipe.servings.toStringAsFixed(1)} porción(es) base'),
          trailing: OutlinedButton(
            onPressed: () => setState(() => _selectedRecipe = recipe),
            child: Text(selected ? 'Elegida' : 'Elegir'),
          ),
        );
      }).toList(),
    );
  }

  Widget _mealGrid() {
    return Column(
      children: _mealNames.map((mealName) {
        final meal = _mealFor(mealName);
        final selected = mealName == _selectedMealName;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            color: selected
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.45)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mealName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (meal != null && meal.items.isNotEmpty)
                            IconButton(
                              tooltip: 'Copiar comida a otro día',
                              onPressed: _busy
                                  ? null
                                  : () => _copyMealToDay(meal),
                              icon: const Icon(Icons.copy_outlined),
                            ),
                          if (meal != null && meal.items.isNotEmpty)
                            IconButton(
                              tooltip: 'Vaciar comida',
                              onPressed:
                                  _busy ? null : () => _clearMeal(meal),
                              icon: const Icon(Icons.cleaning_services_outlined),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => setState(
                              () => _selectedMealName = mealName,
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              selected ? 'Seleccionada' : 'Agregar aquí',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (meal == null || meal.items.isEmpty)
                    const Text('Sin alimentos ni recetas.')
                  else
                    ...meal.items.map(_mealItemTile),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _mealItemTile(MealItem item) {
    final label = _itemLabels[item.id] ?? 'Elemento';
    final detail = item.itemType == MealItemType.food
        ? '${(item.quantityGrams ?? 0).toStringAsFixed(0)} g'
        : '${(item.servings ?? 0).toStringAsFixed(1)} porción(es)';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        item.itemType == MealItemType.food
            ? Icons.lunch_dining_outlined
            : Icons.restaurant_menu,
      ),
      title: Text(label),
      subtitle: Text(detail),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: 'Editar cantidad',
            onPressed: _busy || item.id == null
                ? null
                : () => _editItem(item),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: _busy || item.id == null
                ? null
                : () => _removeItem(item.id!),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(
    String label,
    double value,
    String unit,
    double target,
  ) {
    final percent = target <= 0 ? null : value / target * 100;

    return Container(
      width: 205,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (percent != null) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1).toDouble(),
            ),
            const SizedBox(height: 3),
            Text('${percent.toStringAsFixed(1)}% de meta'),
          ],
        ],
      ),
    );
  }
}
