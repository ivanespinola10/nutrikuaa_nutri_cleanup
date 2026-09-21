import 'package:flutter/material.dart';

import '../localization/nutri_i18n.dart';

import '../application/food_library_service.dart';
import '../application/food_placement_service.dart';
import '../application/meal_plan_service.dart';
import '../application/plan_nutrition_service.dart';
import '../application/unified_food_search_service.dart';
import '../data/app_settings_repository.dart';
import '../data/nutri_database.dart';
import '../data/official_food_catalog.dart';
import '../data/official_food_catalog_installer.dart';
import '../data/official_food_catalog_manifest.dart';
import '../data/patient_repository.dart';
import '../domain/food.dart';
import '../domain/meal_plan.dart';
import '../domain/nutrition/nutrient.dart';
import '../domain/patient.dart';

class NutriCatalogWorkspacePage extends StatefulWidget {
  const NutriCatalogWorkspacePage({super.key});

  @override
  State<NutriCatalogWorkspacePage> createState() =>
      _NutriCatalogWorkspacePageState();
}

class _NutriCatalogWorkspacePageState
    extends State<NutriCatalogWorkspacePage> {
  final PatientRepository _patients = PatientRepository();
  final FoodLibraryService _foods = FoodLibraryService();
  final UnifiedFoodSearchService _search = UnifiedFoodSearchService();
  final OfficialFoodCatalog _officialCatalog = OfficialFoodCatalog();
  final MealPlanService _plans = MealPlanService();
  final FoodPlacementService _placement = FoodPlacementService();
  final PlanNutritionService _nutrition = PlanNutritionService();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _energyTarget = TextEditingController(text: '2000');
  final _proteinTarget = TextEditingController(text: '100');

  final _customName = TextEditingController();
  final _customBrand = TextEditingController();
  final _customEnergy = TextEditingController(text: '100');
  final _customProtein = TextEditingController(text: '10');
  final _customCarbs = TextEditingController(text: '8');
  final _customFat = TextEditingController(text: '3');
  final _customServingGrams = TextEditingController();
  final _customHouseholdMeasure = TextEditingController();

  final _searchQuery = TextEditingController(text: 'milk');
  final _grams = TextEditingController(text: '150');

  List<Patient> _patientList = const [];
  List<NutritionTarget> _targets = const [];
  FoodSearchResults _searchResults =
      const FoodSearchResults(professional: [], official: []);

  int? _selectedPatientId;
  Food? _selectedFood;
  PlanNutritionSummary? _summary;
  int? _lastPlanId;

  bool _initializing = true;
  bool _busy = false;
  bool _privateReady = false;
  bool _catalogReady = false;
  int _catalogCount = 0;
  int _professionalFoodCount = 0;
  String? _error;
  String? _catalogError;
  OfficialFoodCatalogManifest? _manifest;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _energyTarget,
      _proteinTarget,
      _customName,
      _customBrand,
      _customEnergy,
      _customProtein,
      _customCarbs,
      _customFat,
      _customServingGrams,
      _customHouseholdMeasure,
      _searchQuery,
      _grams,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _number(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
  }

  Future<void> _initialize() async {
    setState(() {
      _initializing = true;
      _error = null;
      _catalogError = null;
    });

    try {
      await NutriDatabase.instance.database.timeout(
        const Duration(seconds: 12),
      );
      _privateReady = true;
    } catch (error) {
      _privateReady = false;
      _error = 'Base profesional: $error';
    }

    if (_privateReady) {
      await _refreshPatients();
      await _refreshProfessionalCount();
    }

    try {
      _manifest = await OfficialFoodCatalogInstaller.readBundledManifest();
      final result = await OfficialFoodCatalogInstaller.installIfNeeded();
      _catalogReady =
          result != OfficialCatalogInstallResult.noCatalogBundled;
      if (_catalogReady) {
        _catalogCount = await _officialCatalog.count();
      }
    } catch (error) {
      _catalogReady = false;
      _catalogError = 'Catálogo oficial: $error';
    }

    if (_privateReady) {
      await _runSearch();
    }

    if (!mounted) return;
    setState(() => _initializing = false);
  }

  Future<void> _refreshPatients({int? preferId}) async {
    final patients = await _patients.search('', activeOnly: false);

    int? selected = preferId ?? _selectedPatientId;
    if (!patients.any((patient) => patient.id == selected)) {
      selected = patients.isEmpty ? null : patients.first.id;
    }

    final targets = selected == null
        ? const <NutritionTarget>[]
        : await _patients.targetsFor(selected);

    if (!mounted) return;
    setState(() {
      _patientList = patients;
      _selectedPatientId = selected;
      _targets = targets;
    });
  }

  Future<void> _refreshProfessionalCount() async {
    final foods = await _foods.search('', limit: 5000);
    if (!mounted) return;
    setState(() => _professionalFoodCount = foods.length);
  }

  Future<void> _runSearch() async {
    if (!_privateReady) return;
    final query = _searchQuery.text.trim();

    final results = await _search.search(
      query,
      professionalLimit: 20,
      officialLimit: 25,
    );

    if (!mounted) return;
    setState(() => _searchResults = results);
  }

  Future<void> _createPatient() async {
    final first = _firstName.text.trim();
    if (first.isEmpty) {
      _message(NutriI18n.t('Escribe el nombre del paciente.'));
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
      await _refreshPatients(preferId: id);
      _message(NutriI18n.t('Paciente guardado.'));
    });
  }

  Future<void> _createCustomFood() async {
    final name = _customName.text.trim();
    if (name.isEmpty) {
      _message(NutriI18n.t('Escribe el nombre del alimento.'));
      return;
    }

    await _execute(() async {
      final nutrients = [
        NutrientValue(
          code: NutrientCodes.energyKcal,
          valuePer100g: _number(_customEnergy),
          unit: NutrientUnit.kilocalorie,
        ),
        NutrientValue(
          code: NutrientCodes.protein,
          valuePer100g: _number(_customProtein),
          unit: NutrientUnit.gram,
        ),
        NutrientValue(
          code: NutrientCodes.carbohydrate,
          valuePer100g: _number(_customCarbs),
          unit: NutrientUnit.gram,
        ),
        NutrientValue(
          code: NutrientCodes.fat,
          valuePer100g: _number(_customFat),
          unit: NutrientUnit.gram,
        ),
      ];

      final brand = _customBrand.text.trim();
      final settings = await AppSettingsRepository().load();
      final countryCode = settings.countryCode;
      final servingGrams = _number(_customServingGrams);
      final household = _customHouseholdMeasure.text.trim();
      final id = brand.isEmpty
          ? await _foods.addProfessionalFood(
              name: name,
              countryCode: countryCode,
              servingQuantity: servingGrams > 0 ? servingGrams : null,
              servingUnit: servingGrams > 0 ? 'g' : null,
              householdMeasure: household.isEmpty ? null : household,
              nutrients: nutrients,
            )
          : await _foods.addBrandedFood(
              name: name,
              brand: brand,
              countryCode: countryCode,
              servingQuantity: servingGrams > 0 ? servingGrams : null,
              servingUnit: servingGrams > 0 ? 'g' : null,
              householdMeasure: household.isEmpty ? null : household,
              nutrients: nutrients,
            );

      _selectedFood = await NutriDatabase.instance.getFood(id);
      _customName.clear();
      _customBrand.clear();
      _customServingGrams.clear();
      _customHouseholdMeasure.clear();
      await _refreshProfessionalCount();
      await _runSearch();
      _message(NutriI18n.t('Alimento guardado en tu biblioteca.'));
    });
  }

  Future<void> _selectPatient(int? id) async {
    if (id == null) return;
    final targets = await _patients.targetsFor(id);
    if (!mounted) return;
    setState(() {
      _selectedPatientId = id;
      _targets = targets;
      _summary = null;
      _lastPlanId = null;
    });
  }

  void _selectFood(Food food) {
    setState(() {
      _selectedFood = food;
      _summary = null;
      _lastPlanId = null;
    });
    _message(
      food.sourceType == FoodSourceType.officialDatabase
          ? 'Alimento USDA seleccionado. Se congelará al agregarlo al plan.'
          : 'Alimento de tu biblioteca seleccionado.',
    );
  }

  Future<void> _createPlan() async {
    final patientId = _selectedPatientId;
    final food = _selectedFood;
    final grams = _number(_grams);

    if (patientId == null) {
      _message(NutriI18n.t('Selecciona un paciente.'));
      return;
    }
    if (food == null) {
      _message(NutriI18n.t('Busca y selecciona un alimento.'));
      return;
    }
    if (grams <= 0) {
      _message(NutriI18n.t('La cantidad debe ser mayor que cero.'));
      return;
    }

    await _execute(() async {
      final planId = await _plans.createPlan(
        MealPlan(
          patientId: patientId,
          name: 'Prueba catálogo V0.2',
          startDate: DateTime.now(),
        ),
      );

      final mealId = await _plans.addMeal(
        planId: planId,
        dayIndex: 0,
        name: 'Desayuno',
      );

      await _placement.addSelectedFoodToMeal(
        mealId: mealId,
        selectedFood: food,
        quantityGrams: grams,
      );

      final summary = await _nutrition.calculate(planId);

      await _refreshProfessionalCount();
      await _runSearch();

      if (!mounted) return;
      setState(() {
        _lastPlanId = planId;
        _summary = summary;
      });

      _message(
        food.sourceType == FoodSourceType.officialDatabase
            ? 'Plan guardado. El alimento USDA quedó snapshotteado.'
            : 'Plan guardado desde tu biblioteca.',
      );
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
      _message(NutriI18n.t('Ocurrió un error. Revisa el diagnóstico superior.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  NutritionTarget? _target(String code) {
    for (final target in _targets) {
      if (target.nutrientCode == code) return target;
    }
    return null;
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
                'Chrome MVP · V0.2',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _body(),
    );
  }

  Widget _body() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statusCard(),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final half = width >= 760 ? (width - 16) / 2 : width;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(width: half, child: _patientCard()),
                      SizedBox(width: half, child: _customFoodCard()),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _searchCard(),
              const SizedBox(height: 16),
              _planCard(),
              const SizedBox(height: 16),
              _resultCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    final manifest = _manifest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(NutriI18n.t('Catálogo + biblioteca profesional'),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(
                    _privateReady ? Icons.check_circle : Icons.error_outline,
                    size: 18,
                  ),
                  label: Text(
                    _privateReady
                        ? 'Base profesional activa'
                        : 'Base profesional no disponible',
                  ),
                ),
                Chip(
                  avatar: Icon(
                    _catalogReady ? Icons.verified : Icons.warning_amber,
                    size: 18,
                  ),
                  label: Text(
                    _catalogReady
                        ? 'USDA activo · $_catalogCount alimentos'
                        : 'Catálogo USDA no disponible',
                  ),
                ),
                Chip(
                  label: Text('Mi biblioteca · $_professionalFoodCount'),
                ),
              ],
            ),
            if (manifest != null) ...[
              const SizedBox(height: 8),
              Text(
                '${manifest.sourceRelease} · offline · versionado',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (_error != null || _catalogError != null) ...[
              const SizedBox(height: 10),
              if (_error != null)
                SelectableText(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_catalogError != null)
                SelectableText(
                  _catalogError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _patientCard() {
    return _section(
      number: '1',
      title: NutriI18n.t('Paciente'),
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
                child: _field(_proteinTarget, 'Meta proteína g', numeric: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy || !_privateReady ? null : _createPatient,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(NutriI18n.t('Guardar paciente')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customFoodCard() {
    return _section(
      number: '2',
      title: NutriI18n.t('Alimento propio o de marca'),
      subtitle: NutriI18n.t('Editable por el profesional'),
      child: Column(
        children: [
          _field(_customName, 'Nombre del alimento'),
          const SizedBox(height: 10),
          _field(_customBrand, 'Marca (opcional)'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(_customEnergy, 'kcal /100 g', numeric: true)),
              const SizedBox(width: 8),
              Expanded(child: _field(_customProtein, 'Prot. g', numeric: true)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _field(_customCarbs, 'Carb. g', numeric: true)),
              const SizedBox(width: 8),
              Expanded(child: _field(_customFat, 'Grasa g', numeric: true)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _field(
                  _customServingGrams,
                  'Porción habitual (g)',
                  numeric: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _field(
                  _customHouseholdMeasure,
                  'Medida casera (ej. 1 pote)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy || !_privateReady ? null : _createCustomFood,
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(NutriI18n.t('Guardar en mi biblioteca')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchCard() {
    return _section(
      number: '3',
      title: NutriI18n.t('Buscar alimento'),
      subtitle: NutriI18n.t('Tu biblioteca primero · USDA después'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchQuery,
                  onSubmitted: (_) => _runSearch(),
                  decoration: InputDecoration(
                    labelText: NutriI18n.t('Buscar'),
                    hintText: NutriI18n.t('Ej.: leche, arroz, pollo, yogurt'),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _busy ? null : _runSearch,
                child: Text(NutriI18n.t('Buscar')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_searchResults.professional.isNotEmpty) ...[
            const _ResultHeader(
              icon: Icons.bookmark_added_outlined,
              title: NutriI18n.t('Mi biblioteca'),
            ),
            const SizedBox(height: 6),
            ..._searchResults.professional.map(
              (food) => _foodTile(food, isOfficial: false),
            ),
            const SizedBox(height: 14),
          ],
          if (_searchResults.official.isNotEmpty) ...[
            const _ResultHeader(
              icon: Icons.verified_outlined,
              title: 'USDA Foundation Foods',
            ),
            const SizedBox(height: 6),
            ..._searchResults.official.map(
              (food) => _foodTile(food, isOfficial: true),
            ),
          ],
          if (_searchResults.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(NutriI18n.t('No se encontraron alimentos para esta búsqueda.')),
            ),
        ],
      ),
    );
  }

  Widget _foodTile(Food food, {required bool isOfficial}) {
    final selected = identical(food, _selectedFood) ||
        (_selectedFood?.sourceName == food.sourceName &&
            _selectedFood?.sourceFoodId == food.sourceFoodId &&
            food.sourceFoodId != null);

    final nutrients = <String>[];
    final kcal = food.nutrient(NutrientCodes.energyKcal)?.valuePer100g;
    final protein = food.nutrient(NutrientCodes.protein)?.valuePer100g;
    if (kcal != null) nutrients.add('${kcal.toStringAsFixed(0)} kcal');
    if (protein != null) nutrients.add('P ${protein.toStringAsFixed(1)} g');

    return Card(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerLowest,
      child: ListTile(
        leading: Icon(
          isOfficial ? Icons.verified_outlined : Icons.inventory_2_outlined,
        ),
        title: Text(
          food.brand == null
              ? food.name
              : '${food.name} · ${food.brand}',
        ),
        subtitle: Text(
          [
            if (isOfficial) 'USDA · FDC ${food.sourceFoodId}',
            if (!isOfficial) 'Biblioteca profesional',
            ...nutrients,
          ].join(' · '),
        ),
        trailing: FilledButton.tonal(
          onPressed: _busy ? null : () => _selectFood(food),
          child: Text(selected ? 'Seleccionado' : 'Usar'),
        ),
      ),
    );
  }

  Widget _planCard() {
    final food = _selectedFood;

    return _section(
      number: '4',
      title: NutriI18n.t('Crear prueba de plan'),
      subtitle: NutriI18n.t('Día 1 · Desayuno'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            value: _selectedPatientId,
            isExpanded: true,
            decoration: InputDecoration(labelText: NutriI18n.t('Paciente')),
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
          InputDecorator(
            decoration: InputDecoration(labelText: NutriI18n.t('Alimento seleccionado')),
            child: Text(
              food == null
                  ? 'Busca un alimento arriba y pulsa “Usar”'
                  : food.brand == null
                      ? food.name
                      : '${food.name} · ${food.brand}',
            ),
          ),
          if (food?.sourceType == FoodSourceType.officialDatabase) ...[
            const SizedBox(height: 6),
            Text(NutriI18n.t('Al agregarlo, Nutrikuaa guardará un snapshot con fuente, FDC ID y release.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          _field(_grams, 'Cantidad en gramos', numeric: true),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy || !_privateReady ? null : _createPlan,
              icon: const Icon(Icons.calculate_outlined),
              label: Text(NutriI18n.t('Guardar y calcular plan')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard() {
    final summary = _summary;
    if (summary == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Text(NutriI18n.t('Selecciona un alimento de tu biblioteca o de USDA y crea el plan para ver el resultado.'),
          ),
        ),
      );
    }

    final total = summary.totalsForDay(0);
    final energy = total.value(NutrientCodes.energyKcal);
    final protein = total.value(NutrientCodes.protein);
    final carbs = total.value(NutrientCodes.carbohydrate);
    final fat = total.value(NutrientCodes.fat);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resultado del plan #${_lastPlanId ?? '-'}',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(
                  'Energía',
                  energy,
                  'kcal',
                  _target(NutrientCodes.energyKcal)?.targetValue,
                ),
                _metric(
                  'Proteína',
                  protein,
                  'g',
                  _target(NutrientCodes.protein)?.targetValue,
                ),
                _metric('Carbohidratos', carbs, 'g', null),
                _metric('Grasas', fat, 'g', null),
              ],
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
    final percent = target == null || target <= 0 ? null : value / target * 100;
    return Container(
      width: 215,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (percent != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1).toDouble(),
            ),
            const SizedBox(height: 4),
            Text('${percent.toStringAsFixed(1)}% de la meta'),
          ],
        ],
      ),
    );
  }

  Widget _section({
    required String number,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
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
                  child: Text(number),
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

class _ResultHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ResultHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
