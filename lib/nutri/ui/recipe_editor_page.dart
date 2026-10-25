import 'package:flutter/material.dart';

import '../localization/nutri_i18n.dart';

import '../application/food_placement_service.dart';
import '../application/license_service.dart';
import '../application/nutrition_calculator.dart';
import '../application/recipe_service.dart';
import '../application/unified_food_search_service.dart';
import '../domain/food.dart';
import '../domain/nutrition/nutrient.dart';
import '../domain/recipe.dart';

class RecipeEditorPage extends StatefulWidget {
  const RecipeEditorPage({super.key});

  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _DraftIngredient {
  final Food food;
  double grams;

  _DraftIngredient({
    required this.food,
    required this.grams,
  });
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  final RecipeService _recipes = RecipeService();
  final LicenseService _licenseService = LicenseService();
  final UnifiedFoodSearchService _search = UnifiedFoodSearchService();
  final FoodPlacementService _placement = FoodPlacementService();

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _servings = TextEditingController(text: '1');
  final _yieldGrams = TextEditingController();
  final _notes = TextEditingController();
  final _foodQuery = TextEditingController();
  final _ingredientGrams = TextEditingController(text: '100');

  List<Recipe> _recipeList = const [];
  FoodSearchResults _foodResults =
      const FoodSearchResults(professional: [], official: []);
  final List<_DraftIngredient> _ingredients = [];

  int? _editingRecipeId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshRecipes();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _servings,
      _yieldGrams,
      _notes,
      _foodQuery,
      _ingredientGrams,
    ]) {
      controller.dispose();
    }
    _licenseService.close();
    super.dispose();
  }

  double _number(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
  }

  Future<void> _refreshRecipes({int? selectId}) async {
    try {
      final recipes = await _recipes.search('');
      if (!mounted) return;
      setState(() {
        _recipeList = recipes;
        _loading = false;
      });
      if (selectId != null) await _loadRecipe(selectId);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  void _newRecipe() {
    setState(() {
      _editingRecipeId = null;
      _name.clear();
      _description.clear();
      _servings.text = '1';
      _yieldGrams.clear();
      _notes.clear();
      _foodQuery.clear();
      _ingredientGrams.text = '100';
      _foodResults =
          const FoodSearchResults(professional: [], official: []);
      _ingredients.clear();
      _error = null;
    });
  }

  Future<void> _loadRecipe(int recipeId) async {
    final details = await _recipes.getById(recipeId);
    if (details == null) return;

    final draft = <_DraftIngredient>[];
    for (final item in details.items) {
      final food = await _recipes.database.getFood(item.foodId);
      if (food != null) {
        draft.add(
          _DraftIngredient(
            food: food,
            grams: item.quantityGrams,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _editingRecipeId = recipeId;
      _name.text = details.recipe.name;
      _description.text = details.recipe.description ?? '';
      _servings.text = details.recipe.servings.toString();
      _yieldGrams.text = details.recipe.yieldGrams?.toString() ?? '';
      _notes.text = details.recipe.notes ?? '';
      _ingredients
        ..clear()
        ..addAll(draft);
      _error = null;
    });
  }

  Future<void> _searchFoods() async {
    final results = await _search.search(
      _foodQuery.text.trim(),
      professionalLimit: 20,
      officialLimit: 20,
    );
    if (!mounted) return;
    setState(() => _foodResults = results);
  }

  Future<void> _addIngredient(Food selectedFood) async {
    final grams = _number(_ingredientGrams);
    if (grams <= 0) {
      _message(NutriI18n.t('La cantidad debe ser mayor que cero.'));
      return;
    }

    await _execute(() async {
      final resolved = await _placement.resolveForProfessionalUse(selectedFood);
      final existingIndex = _ingredients.indexWhere(
        (item) => item.food.id == resolved.id,
      );

      if (!mounted) return;
      setState(() {
        if (existingIndex >= 0) {
          _ingredients[existingIndex].grams += grams;
        } else {
          _ingredients.add(
            _DraftIngredient(
              food: resolved,
              grams: grams,
            ),
          );
        }
      });

      await _searchFoods();
      _message(NutriI18n.t('Ingrediente agregado.'));
    });
  }

  Future<void> _editIngredient(_DraftIngredient ingredient) async {
    final controller = TextEditingController(
      text: ingredient.grams.toStringAsFixed(0),
    );

    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ingredient.food.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: NutriI18n.t('Cantidad en gramos')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(NutriI18n.t('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: Text(NutriI18n.t('Guardar')),
          ),
        ],
      ),
    );

    controller.dispose();
    if (value == null || value <= 0) return;
    setState(() => ingredient.grams = value);
  }

  NutritionTotals get _totalNutrition {
    var total = const NutritionTotals(<String, double>{});
    for (final ingredient in _ingredients) {
      total = total +
          NutritionCalculator.forFood(
            ingredient.food,
            ingredient.grams,
          );
    }
    return total;
  }

  NutritionTotals get _perServingNutrition {
    final servings = _number(_servings);
    if (servings <= 0) return const NutritionTotals({});

    return NutritionTotals({
      for (final entry in _totalNutrition.values.entries)
        entry.key: entry.value / servings,
    });
  }

  double get _ingredientWeight =>
      _ingredients.fold(0, (sum, item) => sum + item.grams);

  Future<void> _saveRecipe() async {
    final name = _name.text.trim();
    final servings = _number(_servings);
    if (name.isEmpty) {
      _message(NutriI18n.t('Escribe un nombre para la receta.'));
      return;
    }
    if (servings <= 0) {
      _message(NutriI18n.t('Las porciones deben ser mayores que cero.'));
      return;
    }
    if (_ingredients.isEmpty) {
      _message(NutriI18n.t('Agrega al menos un ingrediente.'));
      return;
    }

    final yieldWeight = _number(_yieldGrams);
    final inputs = List.generate(
      _ingredients.length,
      (index) => RecipeIngredientInput(
        foodId: _ingredients[index].food.id!,
        quantityGrams: _ingredients[index].grams,
        sortOrder: index,
      ),
    );

    await _execute(() async {
      final currentId = _editingRecipeId;
      int recipeId;

      if (currentId == null) {
        if (_recipeList.isNotEmpty &&
            !await _licenseService.isProActive()) {
          _message(NutriI18n.t(
            'Vista previa: máximo 1 receta. Activa la licencia para crear más.',
          ));
          return;
        }
        recipeId = await _recipes.create(
          Recipe(
            name: name,
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            servings: servings,
            yieldGrams: yieldWeight > 0 ? yieldWeight : null,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          ),
          inputs,
        );
      } else {
        final current = await _recipes.getById(currentId);
        if (current == null) {
          throw StateError(NutriI18n.t('La receta ya no existe.'));
        }

        await _recipes.update(
          Recipe(
            id: currentId,
            name: name,
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            servings: servings,
            yieldGrams: yieldWeight > 0 ? yieldWeight : null,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            createdAt: current.recipe.createdAt,
          ),
          inputs,
        );
        recipeId = currentId;
      }

      await _refreshRecipes(selectId: recipeId);
      _message(currentId == null
          ? NutriI18n.t('Receta creada.')
          : NutriI18n.t('Receta actualizada.'));
    });
  }

  Future<void> _duplicateRecipe() async {
    final id = _editingRecipeId;
    if (id == null) return;

    await _execute(() async {
      if (_recipeList.isNotEmpty &&
          !await _licenseService.isProActive()) {
        _message(NutriI18n.t(
          'Vista previa: máximo 1 receta. Activa la licencia para crear más.',
        ));
        return;
      }

      final newId = await _recipes.duplicate(
        id,
        newName: '${_name.text.trim()} ${_copySuffix()}',
      );
      await _refreshRecipes(selectId: newId);
      _message(NutriI18n.t('Receta duplicada.'));
    });
  }

  Future<void> _deleteRecipe() async {
    final id = _editingRecipeId;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(NutriI18n.t('Eliminar receta')),
        content: Text(NutriI18n.t('La receta se eliminará si todavía no está utilizada en un plan.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(NutriI18n.t('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(NutriI18n.t('Eliminar')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _execute(() async {
      await _recipes.delete(id);
      _newRecipe();
      await _refreshRecipes();
      _message(NutriI18n.t('Receta eliminada.'));
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
        title: Text(NutriI18n.t('Recetas'),
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: Center(child: Text('V0.5')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 980) {
                  return Row(
                    children: [
                      SizedBox(width: 300, child: _recipeSidebar()),
                      const VerticalDivider(width: 1),
                      Expanded(child: _editor()),
                    ],
                  );
                }
                return _editor(includeRecipeList: true);
              },
            ),
    );
  }

  Widget _recipeSidebar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _newRecipe,
              icon: const Icon(Icons.add),
              label: Text(NutriI18n.t('Nueva receta')),
            ),
          ),
        ),
        Expanded(
          child: _recipeList.isEmpty
              ? Center(child: Text(NutriI18n.t('Todavía no hay recetas.')))
              : ListView.builder(
                  itemCount: _recipeList.length,
                  itemBuilder: (context, index) {
                    final recipe = _recipeList[index];
                    return ListTile(
                      selected: recipe.id == _editingRecipeId,
                      leading: const Icon(Icons.restaurant_menu),
                      title: Text(recipe.name),
                      subtitle: Text(
                        _servingsText(recipe.servings),
                      ),
                      onTap: () => _loadRecipe(recipe.id!),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _editor({bool includeRecipeList = false}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (includeRecipeList) ...[
                _mobileRecipeSelector(),
                const SizedBox(height: 14),
              ],
              _headerCard(),
              const SizedBox(height: 14),
              _ingredientSearchCard(),
              const SizedBox(height: 14),
              _ingredientListCard(),
              const SizedBox(height: 14),
              _nutritionCard(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileRecipeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _editingRecipeId,
                isExpanded: true,
                decoration: InputDecoration(labelText: NutriI18n.t('Receta')),
                items: _recipeList
                    .map(
                      (recipe) => DropdownMenuItem(
                        value: recipe.id,
                        child: Text(recipe.name),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id != null) _loadRecipe(id);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: NutriI18n.t('Nueva receta'),
              onPressed: _newRecipe,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: NutriI18n.t('Nombre de la receta'),
                hintText: NutriI18n.t('Ej.: Omelette proteico'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              decoration: InputDecoration(
                labelText: NutriI18n.t('Descripción (opcional)'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _servings,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: NutriI18n.t('Porciones que rinde'),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _yieldGrams,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: NutriI18n.t('Rendimiento final g (opcional)'),
                      helperText: _ingredientWeight > 0
                          ? _ingredientsWeightText(_ingredientWeight)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: NutriI18n.t('Preparación / indicaciones (opcional)'),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _saveRecipe,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _editingRecipeId == null
                        ? NutriI18n.t('Guardar receta')
                        : NutriI18n.t('Guardar cambios'),
                  ),
                ),
                if (_editingRecipeId != null)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _duplicateRecipe,
                    icon: const Icon(Icons.copy_outlined),
                    label: Text(NutriI18n.t('Duplicar')),
                  ),
                if (_editingRecipeId != null)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _deleteRecipe,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(NutriI18n.t('Eliminar')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ingredientSearchCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(NutriI18n.t('Agregar ingredientes'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _foodQuery,
                    onSubmitted: (_) => _searchFoods(),
                    decoration: InputDecoration(
                      labelText: NutriI18n.t('Buscar alimento'),
                      hintText: NutriI18n.t('Ej.: huevo, leche, avena'),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 125,
                  child: TextField(
                    controller: _ingredientGrams,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: NutriI18n.t('Gramos')),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _searchFoods,
                  child: Text(NutriI18n.t('Buscar')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_foodResults.isEmpty)
              Text(NutriI18n.t('Busca en tu biblioteca y en el catálogo USDA.'))
            else
              ..._foodResults.combined.take(8).map(_foodResultTile),
          ],
        ),
      ),
    );
  }

  Widget _foodResultTile(Food food) {
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
            : NutriI18n.t('Biblioteca profesional'),
      ),
      trailing: FilledButton.tonal(
        onPressed: _busy ? null : () => _addIngredient(food),
        child: Text(NutriI18n.t('Agregar')),
      ),
    );
  }

  Widget _ingredientListCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _ingredientsCountText(_ingredients.length),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (_ingredients.isEmpty)
              Text(NutriI18n.t('Todavía no agregaste ingredientes.'))
            else
              ..._ingredients.map((ingredient) {
                final food = ingredient.food;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lunch_dining_outlined),
                  title: Text(
                    food.brand == null
                        ? food.name
                        : '${food.name} · ${food.brand}',
                  ),
                  subtitle: Text(
                    '${ingredient.grams.toStringAsFixed(0)} g'
                    '${food.sourceFoodId == null ? '' : ' · FDC ${food.sourceFoodId}'}',
                  ),
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      IconButton(
                        tooltip: NutriI18n.t('Editar cantidad'),
                        onPressed: _busy
                            ? null
                            : () => _editIngredient(ingredient),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: NutriI18n.t('Eliminar ingrediente'),
                        onPressed: _busy
                            ? null
                            : () => setState(
                                  () => _ingredients.remove(ingredient),
                                ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _nutritionCard() {
    final total = _totalNutrition;
    final perServing = _perServingNutrition;
    final servings = _number(_servings);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(NutriI18n.t('Nutrición calculada'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              servings > 0
                  ? _nutritionDescription(servings)
                  : NutriI18n.t('Define un número de porciones válido.'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _nutritionMetric(
                  'Energía',
                  total.value(NutrientCodes.energyKcal),
                  perServing.value(NutrientCodes.energyKcal),
                  'kcal',
                ),
                _nutritionMetric(
                  'Proteína',
                  total.value(NutrientCodes.protein),
                  perServing.value(NutrientCodes.protein),
                  'g',
                ),
                _nutritionMetric(
                  'Carbohidratos',
                  total.value(NutrientCodes.carbohydrate),
                  perServing.value(NutrientCodes.carbohydrate),
                  'g',
                ),
                _nutritionMetric(
                  'Grasas',
                  total.value(NutrientCodes.fat),
                  perServing.value(NutrientCodes.fat),
                  'g',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _copySuffix() {
    if (NutriI18n.languageCode == 'en') return '(copy)';
    if (NutriI18n.languageCode == 'pt') return '(cópia)';
    return '(copia)';
  }

  String _servingsText(double servings) {
    final value = servings.toStringAsFixed(1);
    if (NutriI18n.languageCode == 'en') return '$value serving(s)';
    if (NutriI18n.languageCode == 'pt') return '$value porção(ões)';
    return '$value porción(es)';
  }

  String _ingredientsWeightText(double grams) {
    final value = grams.toStringAsFixed(0);
    if (NutriI18n.languageCode == 'en') return 'Ingredients: $value g';
    if (NutriI18n.languageCode == 'pt') return 'Ingredientes: $value g';
    return 'Ingredientes: $value g';
  }

  String _ingredientsCountText(int count) {
    if (NutriI18n.languageCode == 'en') return 'Ingredients ($count)';
    return 'Ingredientes ($count)';
  }

  String _nutritionDescription(double servings) {
    final value = servings.toStringAsFixed(1);
    if (NutriI18n.languageCode == 'en') {
      return 'Whole recipe and per 1 of $value serving(s).';
    }
    if (NutriI18n.languageCode == 'pt') {
      return 'Receita completa e por 1 de $value porção(ões).';
    }
    return 'Por receta completa y por 1 de $value porción(es).';
  }

  String _perServingText(double value, String unit) {
    final amount = value.toStringAsFixed(1);
    if (NutriI18n.languageCode == 'en') return '$amount $unit / serving';
    if (NutriI18n.languageCode == 'pt') return '$amount $unit / porção';
    return '$amount $unit / porción';
  }

  String _totalText(double value, String unit) {
    final amount = value.toStringAsFixed(1);
    if (NutriI18n.languageCode == 'en') return '$amount $unit total';
    if (NutriI18n.languageCode == 'pt') return '$amount $unit total';
    return '$amount $unit total';
  }

  Widget _nutritionMetric(
    String label,
    double total,
    double perServing,
    String unit,
  ) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(NutriI18n.t(label)),
          const SizedBox(height: 4),
          Text(
            _perServingText(perServing, unit),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            _totalText(total, unit),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
