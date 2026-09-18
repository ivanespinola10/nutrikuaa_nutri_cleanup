import 'package:flutter/material.dart';

import '../application/food_library_service.dart';
import '../application/meal_plan_service.dart';
import '../application/plan_nutrition_service.dart';
import '../data/nutri_database.dart';
import '../data/patient_repository.dart';
import '../domain/food.dart';
import '../domain/meal_plan.dart';
import '../domain/nutrition/nutrient.dart';
import '../domain/patient.dart';

class NutriWorkspacePage extends StatefulWidget {
  const NutriWorkspacePage({super.key});

  @override
  State<NutriWorkspacePage> createState() => _NutriWorkspacePageState();
}

class _NutriWorkspacePageState extends State<NutriWorkspacePage> {
  final PatientRepository _patients = PatientRepository();
  final FoodLibraryService _foods = FoodLibraryService();
  final MealPlanService _plans = MealPlanService();
  final PlanNutritionService _nutrition = PlanNutritionService();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _energyTarget = TextEditingController(text: '2000');
  final _proteinTarget = TextEditingController(text: '100');

  final _foodName = TextEditingController();
  final _foodBrand = TextEditingController();
  final _foodEnergy = TextEditingController(text: '100');
  final _foodProtein = TextEditingController(text: '10');
  final _foodCarbohydrate = TextEditingController(text: '8');
  final _foodFat = TextEditingController(text: '3');
  final _grams = TextEditingController(text: '150');

  List<Patient> _patientList = const [];
  List<Food> _foodList = const [];
  List<NutritionTarget> _selectedTargets = const [];

  int? _selectedPatientId;
  int? _selectedFoodId;
  int? _lastPlanId;
  PlanNutritionSummary? _summary;

  bool _busy = false;
  bool _initializing = true;
  String? _error;
  String _status = 'Inicializando base local...';

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _energyTarget,
      _proteinTarget,
      _foodName,
      _foodBrand,
      _foodEnergy,
      _foodProtein,
      _foodCarbohydrate,
      _foodFat,
      _grams,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _number(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
  }

  Future<void> _refreshData({
    int? preferPatientId,
    int? preferFoodId,
  }) async {
    try {
      await NutriDatabase.instance.database;
      final patients = await _patients.search('', activeOnly: false);
      final foods = await _foods.search('');

      int? patientId = preferPatientId ?? _selectedPatientId;
      int? foodId = preferFoodId ?? _selectedFoodId;

      if (!patients.any((patient) => patient.id == patientId)) {
        patientId = patients.isEmpty ? null : patients.first.id;
      }
      if (!foods.any((food) => food.id == foodId)) {
        foodId = foods.isEmpty ? null : foods.first.id;
      }

      final targets = patientId == null
          ? const <NutritionTarget>[]
          : await _patients.targetsFor(patientId);

      if (!mounted) return;
      setState(() {
        _patientList = patients;
        _foodList = foods;
        _selectedPatientId = patientId;
        _selectedFoodId = foodId;
        _selectedTargets = targets;
        _initializing = false;
        _error = null;
        _status = 'SQLite local activo · persistencia del navegador';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = error.toString();
        _status = 'No se pudo iniciar SQLite local';
      });
    }
  }

  Future<void> _selectPatient(int? patientId) async {
    if (patientId == null) return;
    final targets = await _patients.targetsFor(patientId);
    if (!mounted) return;
    setState(() {
      _selectedPatientId = patientId;
      _selectedTargets = targets;
      _summary = null;
      _lastPlanId = null;
    });
  }

  Future<void> _createPatient() async {
    final first = _firstName.text.trim();
    if (first.isEmpty) {
      _message('Escribe al menos el nombre del paciente.');
      return;
    }

    await _execute(() async {
      final id = await _patients.create(
        Patient(
          firstName: first,
          lastName: _lastName.text.trim(),
        ),
      );

      final targets = <NutritionTarget>[];
      final energy = _number(_energyTarget);
      final protein = _number(_proteinTarget);

      if (energy > 0) {
        targets.add(
          NutritionTarget(
            patientId: id,
            nutrientCode: NutrientCodes.energyKcal,
            targetValue: energy,
            unit: NutrientUnit.kilocalorie,
          ),
        );
      }
      if (protein > 0) {
        targets.add(
          NutritionTarget(
            patientId: id,
            nutrientCode: NutrientCodes.protein,
            targetValue: protein,
            unit: NutrientUnit.gram,
          ),
        );
      }

      await _patients.setTargets(id, targets);
      _firstName.clear();
      _lastName.clear();
      await _refreshData(preferPatientId: id);
      _message('Paciente y objetivos guardados.');
    });
  }

  Future<void> _createFood() async {
    final name = _foodName.text.trim();
    if (name.isEmpty) {
      _message('Escribe el nombre del alimento.');
      return;
    }

    await _execute(() async {
      final nutrients = [
        NutrientValue(
          code: NutrientCodes.energyKcal,
          valuePer100g: _number(_foodEnergy),
          unit: NutrientUnit.kilocalorie,
        ),
        NutrientValue(
          code: NutrientCodes.protein,
          valuePer100g: _number(_foodProtein),
          unit: NutrientUnit.gram,
        ),
        NutrientValue(
          code: NutrientCodes.carbohydrate,
          valuePer100g: _number(_foodCarbohydrate),
          unit: NutrientUnit.gram,
        ),
        NutrientValue(
          code: NutrientCodes.fat,
          valuePer100g: _number(_foodFat),
          unit: NutrientUnit.gram,
        ),
      ];

      final brand = _foodBrand.text.trim();
      final id = brand.isEmpty
          ? await _foods.addProfessionalFood(
              name: name,
              countryCode: 'PY',
              nutrients: nutrients,
            )
          : await _foods.addBrandedFood(
              name: name,
              brand: brand,
              countryCode: 'PY',
              servingQuantity: 100,
              servingUnit: 'g',
              nutrients: nutrients,
            );

      _foodName.clear();
      _foodBrand.clear();
      await _refreshData(preferFoodId: id);
      _message('Alimento guardado.');
    });
  }

  Future<void> _createPlanTest() async {
    final patientId = _selectedPatientId;
    final foodId = _selectedFoodId;
    final grams = _number(_grams);

    if (patientId == null || foodId == null) {
      _message('Selecciona un paciente y un alimento.');
      return;
    }
    if (grams <= 0) {
      _message('La cantidad debe ser mayor que cero.');
      return;
    }

    await _execute(() async {
      final planId = await _plans.createPlan(
        MealPlan(
          patientId: patientId,
          name: 'Prueba Chrome V0.1',
          startDate: DateTime.now(),
        ),
      );

      final mealId = await _plans.addMeal(
        planId: planId,
        dayIndex: 0,
        name: 'Desayuno',
      );

      await _plans.addFood(
        mealId: mealId,
        foodId: foodId,
        quantityGrams: grams,
      );

      final summary = await _nutrition.calculate(planId);
      final targets = await _patients.targetsFor(patientId);

      if (!mounted) return;
      setState(() {
        _lastPlanId = planId;
        _summary = summary;
        _selectedTargets = targets;
      });
      _message('Plan guardado y recalculado desde SQLite.');
    });
  }

  Future<void> _seedDemo() async {
    await _execute(() async {
      final existingPatients = await _patients.search(
        'Paciente Chrome',
        activeOnly: false,
      );

      final patientId = existingPatients.isEmpty
          ? await _patients.create(
              Patient(firstName: 'Paciente', lastName: 'Chrome'),
            )
          : existingPatients.first.id!;

      await _patients.setTargets(patientId, [
        NutritionTarget(
          patientId: patientId,
          nutrientCode: NutrientCodes.energyKcal,
          targetValue: 2000,
          unit: NutrientUnit.kilocalorie,
        ),
        NutritionTarget(
          patientId: patientId,
          nutrientCode: NutrientCodes.protein,
          targetValue: 100,
          unit: NutrientUnit.gram,
        ),
      ]);

      final existingFoods = await _foods.search('Yogur griego Chrome');
      final foodId = existingFoods.isEmpty
          ? await _foods.addBrandedFood(
              name: 'Yogur griego Chrome',
              brand: 'Demo PY',
              countryCode: 'PY',
              servingQuantity: 150,
              servingUnit: 'g',
              nutrients: const [
                NutrientValue(
                  code: NutrientCodes.energyKcal,
                  valuePer100g: 97,
                  unit: NutrientUnit.kilocalorie,
                ),
                NutrientValue(
                  code: NutrientCodes.protein,
                  valuePer100g: 9,
                  unit: NutrientUnit.gram,
                ),
                NutrientValue(
                  code: NutrientCodes.carbohydrate,
                  valuePer100g: 6,
                  unit: NutrientUnit.gram,
                ),
                NutrientValue(
                  code: NutrientCodes.fat,
                  valuePer100g: 4,
                  unit: NutrientUnit.gram,
                ),
              ],
            )
          : existingFoods.first.id!;

      await _refreshData(
        preferPatientId: patientId,
        preferFoodId: foodId,
      );
      _message('Datos demo cargados.');
    });
  }

  Future<void> _execute(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
      _message('Ocurrió un error. Revisa el mensaje superior.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  NutritionTarget? _target(String code) {
    for (final target in _selectedTargets) {
      if (target.nutrientCode == code) return target;
    }
    return null;
  }

  Food? get _selectedFood {
    for (final food in _foodList) {
      if (food.id == _selectedFoodId) return food;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: const Row(
          children: [
            Icon(Icons.eco_outlined),
            SizedBox(width: 10),
            Text(
              'Nutrikuaa Nutri',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: Text(
                'Chrome MVP · V0.1',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _workspace(),
    );
  }

  Widget _workspace() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _hero(),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final cardWidth = width >= 1020
                      ? (width - 32) / 3
                      : width >= 680
                          ? (width - 16) / 2
                          : width;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(width: cardWidth, child: _patientPanel()),
                      SizedBox(width: cardWidth, child: _foodPanel()),
                      SizedBox(width: cardWidth, child: _planPanel()),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _resultPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    final colors = Theme.of(context).colorScheme;

    return Card(
      color: colors.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                const Text(
                  'Laboratorio funcional V0.1',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Chip(
                  avatar: Icon(
                    _error == null ? Icons.check_circle : Icons.error_outline,
                    size: 18,
                  ),
                  label: Text(_status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Prueba el flujo real: paciente → objetivos → alimento → '
              'plan → cálculo. Los datos quedan en SQLite local.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                _error!,
                style: TextStyle(color: colors.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _seedDemo,
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('Cargar datos demo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patientPanel() {
    return _panel(
      step: '1',
      title: 'Paciente',
      subtitle: '${_patientList.length} guardado(s)',
      child: Column(
        children: [
          _field(_firstName, 'Nombre'),
          const SizedBox(height: 10),
          _field(_lastName, 'Apellido'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(_energyTarget, 'Meta kcal', numeric: true)),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  _proteinTarget,
                  'Meta proteína g',
                  numeric: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _createPatient,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Guardar paciente'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _foodPanel() {
    return _panel(
      step: '2',
      title: 'Alimento',
      subtitle: '${_foodList.length} en biblioteca',
      child: Column(
        children: [
          _field(_foodName, 'Nombre del alimento'),
          const SizedBox(height: 10),
          _field(_foodBrand, 'Marca (opcional)'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(_foodEnergy, 'kcal /100 g', numeric: true)),
              const SizedBox(width: 8),
              Expanded(child: _field(_foodProtein, 'Prot. g', numeric: true)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _field(_foodCarbohydrate, 'Carb. g', numeric: true),
              ),
              const SizedBox(width: 8),
              Expanded(child: _field(_foodFat, 'Grasa g', numeric: true)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _createFood,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Guardar alimento'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planPanel() {
    return _panel(
      step: '3',
      title: 'Plan de prueba',
      subtitle: 'Día 1 · Desayuno',
      child: Column(
        children: [
          DropdownButtonFormField<int>(
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
            onChanged: _busy ? null : _selectPatient,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: _selectedFoodId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Alimento'),
            items: _foodList
                .map(
                  (food) => DropdownMenuItem(
                    value: food.id,
                    child: Text(
                      food.brand == null
                          ? food.name
                          : '${food.name} · ${food.brand}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) => setState(() {
                      _selectedFoodId = value;
                      _summary = null;
                      _lastPlanId = null;
                    }),
          ),
          const SizedBox(height: 10),
          _field(_grams, 'Cantidad en gramos', numeric: true),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _createPlanTest,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Crear y calcular plan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultPanel() {
    final summary = _summary;
    final food = _selectedFood;

    if (summary == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Icon(Icons.insights_outlined, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'El resultado aparecerá aquí. Para la prueba rápida, pulsa '
                  '“Cargar datos demo” y luego “Crear y calcular plan”.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final total = summary.totalsForDay(0);
    final energy = total.value(NutrientCodes.energyKcal);
    final protein = total.value(NutrientCodes.protein);
    final carbs = total.value(NutrientCodes.carbohydrate);
    final fat = total.value(NutrientCodes.fat);
    final energyTarget = _target(NutrientCodes.energyKcal)?.targetValue;
    final proteinTarget = _target(NutrientCodes.protein)?.targetValue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resultado del plan #${_lastPlanId ?? '-'}',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              food == null
                  ? 'Desayuno'
                  : 'Desayuno · ${food.name} · ${_grams.text} g',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric('Energía', energy, 'kcal', energyTarget),
                _metric('Proteína', protein, 'g', proteinTarget),
                _metric('Carbohidratos', carbs, 'g', null),
                _metric('Grasas', fat, 'g', null),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              'El plan se guardó en SQLite y PlanNutritionService volvió a '
              'leerlo para calcular estos totales.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(
    String label,
    double value,
    String unit,
    double? target,
  ) {
    final percent = target == null || target <= 0
        ? null
        : (value / target * 100).clamp(0, 999).toDouble();

    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (percent != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (percent / 100).clamp(0, 1)),
            const SizedBox(height: 5),
            Text('${percent.toStringAsFixed(1)}% de la meta'),
          ],
        ],
      ),
    );
  }

  Widget _panel({
    required String step,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  child: Text(step),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    );
  }
}
