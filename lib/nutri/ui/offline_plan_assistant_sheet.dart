import 'package:flutter/material.dart';

import '../application/offline_plan_assistant_service.dart';
import '../domain/nutrition/nutrient.dart';

class OfflinePlanAssistantSheet extends StatefulWidget {
  final String dayLabel;
  final double? targetKcal;
  final double? targetProteinGrams;
  final Future<void> Function(OfflinePlanDraft draft) onApply;

  const OfflinePlanAssistantSheet({
    super.key,
    required this.dayLabel,
    required this.onApply,
    this.targetKcal,
    this.targetProteinGrams,
  });

  @override
  State<OfflinePlanAssistantSheet> createState() =>
      _OfflinePlanAssistantSheetState();
}

class _OfflinePlanAssistantSheetState extends State<OfflinePlanAssistantSheet> {
  final OfflinePlanAssistantService _assistant = OfflinePlanAssistantService();
  final TextEditingController _prompt = TextEditingController(
    text: '5 comidas, práctico y variado',
  );

  OfflinePlanDraft? _draft;
  String? _error;
  bool _generating = false;
  bool _applying = false;

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  void _addQualifier(String value) {
    final current = _prompt.text.trim();
    final normalized = current.toLowerCase();
    if (normalized.contains(value.toLowerCase())) return;
    _prompt.text = current.isEmpty ? value : '$current, $value';
    _prompt.selection = TextSelection.collapsed(offset: _prompt.text.length);
  }

  Future<void> _generate() async {
    if (_generating || _applying) return;
    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final draft = await _assistant.generate(
        OfflinePlanAssistantRequest(
          prompt: _prompt.text,
          targetKcal: widget.targetKcal,
          targetProteinGrams: widget.targetProteinGrams,
        ),
      );
      if (mounted) setState(() => _draft = draft);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _apply() async {
    final draft = _draft;
    if (draft == null || _applying || _generating) return;
    setState(() {
      _applying = true;
      _error = null;
    });

    try {
      await widget.onApply(draft);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nutri IA · Beta offline',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text('Prearma un borrador con tus bases locales.'),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: _applying ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lock_outline, size: 18),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Funciona sin enviar datos del paciente a la nube.',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Chip(label: Text(widget.dayLabel)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _prompt,
                            minLines: 2,
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              labelText: 'Describe el plan',
                              hintText:
                                  'Ej.: 1800 kcal, alto en proteína, económico, sin lactosa',
                              prefixIcon: Icon(Icons.chat_bubble_outline),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ActionChip(
                                label: const Text('Alto en proteína'),
                                onPressed: () =>
                                    _addQualifier('alto en proteína'),
                              ),
                              ActionChip(
                                label: const Text('Económico'),
                                onPressed: () => _addQualifier('económico'),
                              ),
                              ActionChip(
                                label: const Text('Vegetariano'),
                                onPressed: () => _addQualifier('vegetariano'),
                              ),
                              ActionChip(
                                label: const Text('Sin lactosa'),
                                onPressed: () => _addQualifier('sin lactosa'),
                              ),
                              ActionChip(
                                label: const Text('Sin gluten'),
                                onPressed: () => _addQualifier('sin gluten'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (widget.targetKcal != null &&
                                  widget.targetKcal! > 0)
                                Chip(
                                  avatar: const Icon(
                                    Icons.local_fire_department_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Meta ${widget.targetKcal!.toStringAsFixed(0)} kcal',
                                  ),
                                ),
                              if (widget.targetProteinGrams != null &&
                                  widget.targetProteinGrams! > 0)
                                Chip(
                                  avatar: const Icon(
                                    Icons.fitness_center_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Proteína ${widget.targetProteinGrams!.toStringAsFixed(0)} g',
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _generating || _applying
                                ? null
                                : _generate,
                            icon: _generating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: Text(
                              _generating
                                  ? 'Prearmando…'
                                  : 'Generar borrador offline',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(_error!),
                      ),
                    ),
                  ],
                  if (draft != null) ...[
                    const SizedBox(height: 12),
                    _draftPreview(draft),
                  ],
                ],
              ),
            ),
            if (draft != null)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Al aplicar se reemplazarán las 5 comidas del día seleccionado. Puedes editar todo después.',
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _applying ? null : _apply,
                      icon: _applying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _applying ? 'Aplicando…' : 'Aplicar borrador',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _draftPreview(OfflinePlanDraft draft) {
    final totals = draft.totals;
    final kcal = totals.value(NutrientCodes.energyKcal);
    final protein = totals.value(NutrientCodes.protein);
    final carbs = totals.value(NutrientCodes.carbohydrate);
    final fat = totals.value(NutrientCodes.fat);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              draft.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${kcal.toStringAsFixed(0)} kcal estimadas')),
                Chip(label: Text('P ${protein.toStringAsFixed(1)} g')),
                Chip(label: Text('C ${carbs.toStringAsFixed(1)} g')),
                Chip(label: Text('G ${fat.toStringAsFixed(1)} g')),
              ],
            ),
            const SizedBox(height: 8),
            Text(draft.rationale),
            const SizedBox(height: 12),
            for (final meal in draft.meals)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                initiallyExpanded: meal.name == 'Desayuno',
                title: Text(
                  meal.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${meal.items.length} alimento(s)'),
                children: [
                  for (final item in meal.items)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.restaurant_outlined),
                      title: Text(item.food.name),
                      subtitle: Text(
                        item.food.isOfficial
                            ? '${item.food.sourceName ?? 'Base oficial'} · offline'
                            : 'Mi biblioteca',
                      ),
                      trailing: Text('${item.grams.toStringAsFixed(0)} g'),
                    ),
                ],
              ),
            const Divider(),
            const Text(
              'Beta de preventa: este asistente usa reglas locales y el motor de cálculo de Nutrikuaa. '
              'No diagnostica ni sustituye el criterio del nutricionista. El modelo generativo local podrá incorporarse después sin cambiar este flujo.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
