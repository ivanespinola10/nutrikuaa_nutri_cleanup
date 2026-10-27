import 'package:flutter/material.dart';

import '../application/offline_plan_assistant_service.dart';
import '../application/patient_document_text.dart';
import '../application/offline_plan_validator_service.dart';
import '../domain/nutrition/nutrient.dart';
import '../localization/nutri_i18n.dart';

class OfflinePlanAssistantSheet extends StatefulWidget {
  final String dayLabel;
  final double? targetKcal;
  final double? targetProteinGrams;
  final double? targetCarbohydrateGrams;
  final double? targetFatGrams;
  final String? patientAllergies;
  final String? patientIntolerances;
  final Future<void> Function(OfflinePlanDraft draft) onApply;

  const OfflinePlanAssistantSheet({
    super.key,
    required this.dayLabel,
    required this.onApply,
    this.targetKcal,
    this.targetProteinGrams,
    this.targetCarbohydrateGrams,
    this.targetFatGrams,
    this.patientAllergies,
    this.patientIntolerances,
  });

  @override
  State<OfflinePlanAssistantSheet> createState() =>
      _OfflinePlanAssistantSheetState();
}

class _OfflinePlanAssistantSheetState extends State<OfflinePlanAssistantSheet> {
  final OfflinePlanAssistantService _assistant = OfflinePlanAssistantService();
  final OfflinePlanValidatorService _validator =
      const OfflinePlanValidatorService();
  final TextEditingController _prompt = TextEditingController(
    text: '5 comidas, práctico y variado',
  );

  OfflinePlanDraft? _draft;
  OfflinePlanValidationReport? _validation;
  String? _error;
  bool _generating = false;
  bool _applying = false;

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  void _invalidateDraft() {
    if (_draft == null && _validation == null) return;
    setState(() {
      _draft = null;
      _validation = null;
    });
  }

  void _addQualifier(String value) {
    final current = _prompt.text.trim();
    final normalized = current.toLowerCase();
    if (normalized.contains(value.toLowerCase())) return;
    _prompt.text = current.isEmpty ? value : '$current, $value';
    _prompt.selection = TextSelection.collapsed(offset: _prompt.text.length);
    _invalidateDraft();
  }

  OfflinePlanValidationReport _validate(OfflinePlanDraft draft) {
    return _validator.validate(
      OfflinePlanValidationRequest(
        draft: draft,
        prompt: _prompt.text,
        targetKcal: widget.targetKcal,
        targetProteinGrams: widget.targetProteinGrams,
        targetCarbohydrateGrams: widget.targetCarbohydrateGrams,
        targetFatGrams: widget.targetFatGrams,
        patientAllergies: widget.patientAllergies,
        patientIntolerances: widget.patientIntolerances,
      ),
    );
  }

  Future<void> _generate() async {
    if (_generating || _applying) return;
    setState(() {
      _generating = true;
      _error = null;
      _validation = null;
    });

    try {
      final draft = await _assistant.generate(
        OfflinePlanAssistantRequest(
          prompt: _prompt.text,
          targetKcal: widget.targetKcal,
          targetProteinGrams: widget.targetProteinGrams,
        ),
      );
      final validation = _validate(draft);
      if (mounted) {
        setState(() {
          _draft = draft;
          _validation = validation;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _apply() async {
    final draft = _draft;
    if (draft == null || _applying || _generating) return;

    final freshValidation = _validate(draft);
    if (!freshValidation.canApply) {
      setState(() {
        _validation = freshValidation;
        _error =
            'El validador detectó una incompatibilidad bloqueante. '
            'Corrige el pedido o genera un nuevo borrador antes de aplicar.';
      });
      return;
    }

    setState(() {
      _applying = true;
      _error = null;
      _validation = freshValidation;
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
    final validation = _validation;
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
                        Text(
                          'Genera un borrador y lo valida con una segunda capa independiente.',
                        ),
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
                            onChanged: (_) => _invalidateDraft(),
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
                              if ((widget.patientAllergies ?? '')
                                  .trim()
                                  .isNotEmpty)
                                const Chip(
                                  avatar: Icon(
                                    Icons.health_and_safety_outlined,
                                    size: 18,
                                  ),
                                  label: Text('Alergias de ficha activas'),
                                ),
                              if ((widget.patientIntolerances ?? '')
                                  .trim()
                                  .isNotEmpty)
                                const Chip(
                                  avatar: Icon(Icons.rule_outlined, size: 18),
                                  label: Text('Intolerancias de ficha activas'),
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
                                  ? 'Prearmando y validando…'
                                  : 'Generar y validar borrador',
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
                  if (validation != null) ...[
                    const SizedBox(height: 12),
                    _validationCard(validation),
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
                    Expanded(
                      child: Text(
                        validation?.hasBlockingIssues == true
                            ? 'El validador bloqueó este borrador. Corrige el pedido y vuelve a generarlo.'
                            : 'Al aplicar se reemplazarán las 5 comidas del día seleccionado. El profesional conserva la decisión final.',
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _applying || validation?.canApply != true
                          ? null
                          : _apply,
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

  Widget _validationCard(OfflinePlanValidationReport report) {
    final scheme = Theme.of(context).colorScheme;
    final blocking = report.hasBlockingIssues;

    return Card(
      color: blocking ? scheme.errorContainer : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  blocking
                      ? Icons.gpp_bad_outlined
                      : Icons.verified_user_outlined,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    blocking
                        ? 'REQUIERE CORRECCIÓN ANTES DE APLICAR'
                        : 'APTO PARA REVISIÓN PROFESIONAL',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${report.blockingCount} bloqueo(s) · '
              '${report.warningCount} advertencia(s)',
            ),
            const SizedBox(height: 12),
            for (final check in report.checks) _validationRow(check),
          ],
        ),
      ),
    );
  }

  Widget _validationRow(PlanValidationCheck check) {
    final (icon, label) = switch (check.severity) {
      PlanValidationSeverity.pass => (Icons.check_circle_outline, 'OK'),
      PlanValidationSeverity.warning => (
        Icons.warning_amber_outlined,
        'Revisar',
      ),
      PlanValidationSeverity.blocking => (Icons.cancel_outlined, 'Bloqueo'),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${check.title} · $label',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(check.detail),
              ],
            ),
          ),
        ],
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
                      title: Text(
                        PatientDocumentText.foodDisplayName(
                          item.food,
                          NutriI18n.languageCode,
                        ),
                      ),
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
              'Beta de preventa: el generador y el validador son capas locales separadas. '
              'La validación automática detecta incompatibilidades y desvíos evidentes, '
              'pero no diagnostica ni sustituye el criterio del nutricionista.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
