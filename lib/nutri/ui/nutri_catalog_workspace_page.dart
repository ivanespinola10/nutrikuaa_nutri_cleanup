import 'package:flutter/material.dart';

import '../application/food_library_service.dart';
import '../application/unified_food_search_service.dart';
import '../data/app_settings_repository.dart';
import '../data/nutri_database.dart';
import '../data/official_food_catalog.dart';
import '../data/official_food_catalog_installer.dart';
import '../data/official_food_catalog_manifest.dart';
import '../domain/food.dart';
import '../domain/nutrition/nutrient.dart';

const _nutrientFields = <(String, String, NutrientUnit)>[
  (NutrientCodes.energyKcal, 'Energía (kcal)', NutrientUnit.kilocalorie),
  (NutrientCodes.protein, 'Proteínas (g)', NutrientUnit.gram),
  (NutrientCodes.carbohydrate, 'Carbohidratos (g)', NutrientUnit.gram),
  (NutrientCodes.fat, 'Grasas (g)', NutrientUnit.gram),
  (NutrientCodes.fiber, 'Fibra (g)', NutrientUnit.gram),
  (NutrientCodes.sugars, 'Azúcares (g)', NutrientUnit.gram),
  (NutrientCodes.sodium, 'Sodio (mg)', NutrientUnit.milligram),
  (NutrientCodes.calcium, 'Calcio (mg)', NutrientUnit.milligram),
  (NutrientCodes.iron, 'Hierro (mg)', NutrientUnit.milligram),
  (NutrientCodes.potassium, 'Potasio (mg)', NutrientUnit.milligram),
  (NutrientCodes.vitaminA, 'Vitamina A (µg)', NutrientUnit.microgram),
  (NutrientCodes.vitaminC, 'Vitamina C (mg)', NutrientUnit.milligram),
  (NutrientCodes.vitaminD, 'Vitamina D (µg)', NutrientUnit.microgram),
];

const _allergenLabels = <String, String>{
  'gluten': 'Cereales con gluten',
  'milk': 'Leche',
  'egg': 'Huevo',
  'peanut': 'Maní / cacahuete',
  'tree_nuts': 'Frutos secos',
  'soy': 'Soja',
  'fish': 'Pescado',
  'crustaceans': 'Crustáceos',
  'molluscs': 'Moluscos',
  'sesame': 'Sésamo',
  'celery': 'Apio',
  'mustard': 'Mostaza',
  'lupin': 'Altramuces',
  'sulphites': 'Sulfitos',
};

class NutriCatalogWorkspacePage extends StatefulWidget {
  const NutriCatalogWorkspacePage({super.key});

  @override
  State<NutriCatalogWorkspacePage> createState() =>
      _NutriCatalogWorkspacePageState();
}

class _NutriCatalogWorkspacePageState extends State<NutriCatalogWorkspacePage> {
  final _foods = FoodLibraryService();
  final _search = UnifiedFoodSearchService();
  final _official = OfficialFoodCatalog();
  final _query = TextEditingController();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _source = TextEditingController();
  final _serving = TextEditingController();
  final _measure = TextEditingController();
  final _notes = TextEditingController();
  final _values = {
    for (final field in _nutrientFields) field.$1: TextEditingController(),
  };
  final _editorKey = GlobalKey();
  final _selectedAllergens = <String>{};
  FoodSearchResults _results =
      const FoodSearchResults(professional: [], official: []);
  Food? _editing;
  OfficialFoodCatalogManifest? _manifest;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _privateReady = false;
  bool _catalogReady = false;
  bool _showEditor = false;
  int _officialCount = 0;
  int _ownCount = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    for (final controller in [
      _query, _name, _brand, _source, _serving, _measure, _notes,
      ..._values.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await NutriDatabase.instance.database.timeout(const Duration(seconds: 12));
      _privateReady = true;
      _ownCount = (await _foods.search('', limit: 5000)).length;
    } catch (error) {
      _error = 'Base profesional: $error';
    }
    try {
      _manifest = await OfficialFoodCatalogInstaller.readBundledManifest();
      _catalogReady = await OfficialFoodCatalogInstaller.installIfNeeded() !=
          OfficialCatalogInstallResult.noCatalogBundled;
      if (_catalogReady) _officialCount = await _official.count();
    } catch (error) {
      _error = 'Catálogo: $error';
    }
    if (_privateReady) await _runSearch();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _runSearch() async {
    if (!_privateReady) return;
    try {
      final result = await _search.search(
        _query.text.trim(), professionalLimit: 25, officialLimit: 25);
      if (mounted) setState(() => _results = result);
    } catch (error) {
      if (mounted) setState(() => _error = 'Búsqueda: $error');
    }
  }

  void _openEditor([Food? food]) {
    _editing = food;
    _name.text = food?.name ?? '';
    _brand.text = food?.brand ?? '';
    _source.text = food?.sourceName ?? '';
    _serving.text = food?.servingQuantity?.toString() ?? '';
    _measure.text = food?.householdMeasure ?? '';
    _notes.text = food?.notes ?? '';
    for (final field in _nutrientFields) {
      _values[field.$1]!.text =
          food?.nutrient(field.$1)?.valuePer100g.toString() ?? '';
    }
    _selectedAllergens
      ..clear()
      ..addAll(food?.allergens ?? const []);
    setState(() => _showEditor = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _editorKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target,
            duration: const Duration(milliseconds: 280), alignment: 0.04);
      }
    });
  }

  void _closeEditor() => setState(() {
        _editing = null;
        _showEditor = false;
      });

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _saveFood() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      _message('Escribe el nombre del alimento.');
      return;
    }
    if (_source.text.trim().isEmpty) {
      _message('Indica la fuente o referencia de los valores.');
      return;
    }
    final nutrients = <NutrientValue>[];
    for (final field in _nutrientFields) {
      final raw = _values[field.$1]!.text.trim();
      if (raw.isEmpty) {
        if (_nutrientFields.take(4).any((basic) => basic.$1 == field.$1)) {
          _message('Completa energía, proteínas, carbohidratos y grasas por 100 g.');
          return;
        }
        continue;
      }
      final value = _parse(raw);
      final max = field.$1 == NutrientCodes.energyKcal
          ? 1000.0
          : field.$3 == NutrientUnit.gram ? 100.0 : null;
      if (value == null || !value.isFinite || value < 0 ||
          (max != null && value > max)) {
        _message('Revisa ' + field.$2 + ': usa un valor válido por 100 g.');
        return;
      }
      nutrients.add(NutrientValue(
          code: field.$1, valuePer100g: value, unit: field.$3));
    }
    final portionText = _serving.text.trim();
    final portion = portionText.isEmpty ? null : _parse(portionText);
    if (portionText.isNotEmpty &&
        (portion == null || !portion.isFinite || portion <= 0 || portion > 10000)) {
      _message('La porción debe ser un peso en gramos mayor que cero.');
      return;
    }
    setState(() => _busy = true);
    try {
      final current = _editing;
      final brand = _brand.text.trim();
      final source = _source.text.trim();
      final measure = _measure.text.trim();
      final notes = _notes.text.trim();
      final allergens = _selectedAllergens.toList()..sort();
      int id;
      if (current != null) {
        id = await _foods.update(Food(
          id: current.id,
          name: name,
          brand: brand.isEmpty ? null : brand,
          countryCode: current.countryCode,
          sourceType: current.sourceType,
          sourceName: source.isEmpty ? null : source,
          sourceFoodId: current.sourceFoodId,
          sourceRelease: current.sourceRelease,
          servingQuantity: portion,
          servingUnit: portion == null ? null : 'g',
          householdMeasure: measure.isEmpty ? null : measure,
          notes: notes.isEmpty ? null : notes,
          isArchived: current.isArchived,
          createdAt: current.createdAt,
          nutrients: [
            ...current.nutrients.where((item) => !_values.containsKey(item.code)),
            ...nutrients,
          ],
          portions: current.portions,
          allergens: allergens,
        ));
      } else {
        final country = (await AppSettingsRepository().load()).countryCode;
        id = await (brand.isEmpty
            ? _foods.addProfessionalFood(
                name: name, countryCode: country, servingQuantity: portion,
                servingUnit: portion == null ? null : 'g',
                householdMeasure: measure.isEmpty ? null : measure,
                sourceName: source.isEmpty ? null : source,
                notes: notes.isEmpty ? null : notes,
                nutrients: nutrients, allergens: allergens)
            : _foods.addBrandedFood(
                name: name, brand: brand, countryCode: country,
                servingQuantity: portion,
                servingUnit: portion == null ? null : 'g',
                householdMeasure: measure.isEmpty ? null : measure,
                sourceName: source.isEmpty ? null : source,
                notes: notes.isEmpty ? null : notes,
                nutrients: nutrients, allergens: allergens));
      }
      _ownCount = (await _foods.search('', limit: 5000)).length;
      _closeEditor();
      await _runSearch();
      _message(current != null && current.id != id
          ? 'Nueva versión guardada. Los planes anteriores conservan sus valores.'
          : 'Alimento guardado en tu biblioteca.');
    } catch (error) {
      if (mounted) setState(() => _error = 'Guardado: $error');
      _message('No se pudo guardar el alimento.');
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

  void _showDetails(Food food) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.78,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(food.name, style: Theme.of(sheetContext).textTheme.headlineSmall),
              if (food.brand != null) Text(food.brand!),
              const SizedBox(height: 12),
              Text('Fuente: ' + (food.sourceName ?? 'No declarada')),
              if (food.sourceFoodId != null) Text('ID: ' + food.sourceFoodId!),
              if (food.sourceRelease != null) Text('Versión: ' + food.sourceRelease!),
              const SizedBox(height: 18),
              Text('Valores por 100 g',
                  style: Theme.of(sheetContext).textTheme.titleMedium),
              for (final nutrient in food.nutrients)
                ListTile(
                  dense: true,
                  title: Text(_nutrientFields.where((f) => f.$1 == nutrient.code)
                      .map((f) => f.$2).firstOrNull ?? nutrient.code),
                  trailing: Text(nutrient.valuePer100g.toString() +
                      ' ' + _unit(nutrient.unit)),
                ),
              const Divider(),
              Text('Alérgenos declarados',
                  style: Theme.of(sheetContext).textTheme.titleMedium),
              Text(food.allergens.isEmpty
                  ? 'Sin información declarada. No implica ausencia de alérgenos.'
                  : food.allergens.map((code) => _allergenLabels[code] ?? code).join(', ')),
              if (food.notes?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text('Notas: ' + food.notes!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _unit(NutrientUnit unit) => switch (unit) {
        NutrientUnit.kilocalorie => 'kcal',
        NutrientUnit.gram => 'g',
        NutrientUnit.milligram => 'mg',
        NutrientUnit.microgram => 'µg',
        NutrientUnit.internationalUnit => 'UI',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Biblioteca de alimentos')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _overview(),
                          const SizedBox(height: 12),
                          if (_showEditor) ...[
                            Container(key: _editorKey, child: _editor()),
                            const SizedBox(height: 12),
                          ],
                          _searchCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      );

  Widget _overview() => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Catálogo y biblioteca profesional',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                Chip(label: Text(_privateReady
                    ? 'Mi biblioteca · ' + _ownCount.toString()
                    : 'Biblioteca no disponible')),
                Chip(label: Text(_catalogReady
                    ? 'USDA · ' + _officialCount.toString() + ' alimentos'
                    : 'Catálogo no disponible')),
              ]),
              if (_manifest != null)
                Text(_manifest!.sourceRelease + ' · offline · versionado',
                    style: Theme.of(context).textTheme.bodySmall),
              if (_error != null)
                SelectableText(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _busy || !_privateReady ? null : () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo alimento'),
              ),
            ],
          ),
        ),
      );

  Widget _editor() => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_editing == null ? 'Nuevo alimento' : 'Editar alimento',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('Registra los valores por 100 g y conserva la fuente.'),
              const SizedBox(height: 12),
              _field(_name, 'Nombre del alimento'),
              _field(_brand, 'Marca (opcional)'),
              _field(_source, 'Fuente / referencia (obligatoria)'),
              const SizedBox(height: 12),
              Text('Energía y macronutrientes · por 100 g',
                  style: Theme.of(context).textTheme.titleMedium),
              _numberGrid(_nutrientFields.take(4).toList()),
              ExpansionTile(
                title: const Text('Fibra, azúcares y micronutrientes'),
                subtitle: const Text('Opcionales; deja vacío si no hay dato confiable'),
                children: [_numberGrid(_nutrientFields.skip(4).toList())],
              ),
              ExpansionTile(
                title: const Text('Alérgenos declarados'),
                subtitle: const Text('Sin selección significa información desconocida'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (final entry in _allergenLabels.entries)
                          FilterChip(
                            label: Text(entry.value),
                            selected: _selectedAllergens.contains(entry.key),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _selectedAllergens.add(entry.key);
                              } else {
                                _selectedAllergens.remove(entry.key);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Verifica la etiqueta y la contaminación cruzada. '
                        'Estos datos no se infieren del nombre del alimento.'),
                  ),
                ],
              ),
              ExpansionTile(
                title: const Text('Porción y notas'),
                children: [
                  _field(_serving, 'Porción habitual en gramos', numeric: true),
                  _field(_measure, 'Medida casera (ej.: 1 taza)'),
                  _field(_notes, 'Notas del profesional'),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _saveFood,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar alimento'),
                ),
                TextButton(
                  onPressed: _busy ? null : _closeEditor,
                  child: const Text('Cancelar'),
                ),
              ]),
            ],
          ),
        ),
      );

  Widget _numberGrid(List<(String, String, NutrientUnit)> fields) =>
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth >= 520
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(spacing: 12, children: [
          for (final field in fields)
            SizedBox(
              width: width,
              child: _field(_values[field.$1]!, field.$2, numeric: true),
            ),
        ]);
      });

  Widget _field(TextEditingController controller, String label,
          {bool numeric = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget _searchCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Buscar alimentos',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('Mi biblioteca primero · catálogo USDA después'),
              const SizedBox(height: 12),
              TextField(
                controller: _query,
                onSubmitted: (_) => _runSearch(),
                decoration: InputDecoration(
                  labelText: 'Nombre del alimento',
                  hintText: 'Ej.: leche entera, arroz, pollo',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Buscar',
                    onPressed: _runSearch,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_results.professional.isNotEmpty) ...[
                const Text('Mi biblioteca',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ..._results.professional.map(_foodTile),
              ],
              if (_results.official.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Catálogo USDA',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ..._results.official.map(_foodTile),
              ],
              if (_results.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No se encontraron alimentos para esta búsqueda.'),
                ),
            ],
          ),
        ),
      );

  Widget _foodTile(Food food) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(food.name),
        subtitle: Text([
          if (food.brand != null) food.brand!,
          if (food.isOfficial) 'USDA · FDC ' + (food.sourceFoodId ?? '-'),
          if (!food.isOfficial) 'Biblioteca profesional',
          if (food.nutrient(NutrientCodes.energyKcal) != null)
            food.nutrient(NutrientCodes.energyKcal)!.valuePer100g
                .toStringAsFixed(0) + ' kcal/100 g',
        ].join(' · ')),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: 'Ver ficha',
              onPressed: () => _showDetails(food),
              icon: const Icon(Icons.info_outline),
            ),
            if (food.isUserEditable)
              IconButton(
                tooltip: 'Editar alimento',
                onPressed: _busy ? null : () => _openEditor(food),
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
      );
}
