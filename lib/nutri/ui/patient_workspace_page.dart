import 'package:flutter/material.dart';

import '../application/meal_plan_service.dart';
import '../data/app_settings_repository.dart';
import '../data/patient_repository.dart';
import '../domain/app_settings.dart';
import '../domain/meal_plan.dart';
import '../domain/nutrition/nutrient.dart';
import '../domain/patient.dart';

class PatientWorkspacePage extends StatefulWidget {
  final int refreshToken;

  const PatientWorkspacePage({
    super.key,
    this.refreshToken = 0,
  });

  @override
  State<PatientWorkspacePage> createState() => _PatientWorkspacePageState();
}

class _PatientWorkspacePageState extends State<PatientWorkspacePage> {
  final PatientRepository _patients = PatientRepository();
  final MealPlanService _plans = MealPlanService();
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _birthDate = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();

  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _waist = TextEditingController();
  final _measurementNotes = TextEditingController();

  final _energy = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _sodium = TextEditingController();

  List<Patient> _patientList = const [];
  List<PatientMeasurement> _measurements = const [];
  List<MealPlan> _planHistory = const [];

  int? _selectedPatientId;
  String? _sex;
  bool _isActive = true;
  AppSettings _settings = const AppSettings();
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final settings = await _settingsRepository.load();
      if (!mounted) return;
      setState(() => _settings = settings);
      await _refreshPatients();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant PatientWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _refreshPatients(selectId: _selectedPatientId);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _birthDate,
      _email,
      _phone,
      _notes,
      _weight,
      _height,
      _waist,
      _measurementNotes,
      _energy,
      _protein,
      _carbs,
      _fat,
      _fiber,
      _sodium,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _imperial => _settings.unitSystem == UnitSystem.imperial;

  double? _weightInputToKg(double? value) {
    if (value == null) return null;
    return _imperial ? value / 2.2046226218 : value;
  }

  double? _lengthInputToCm(double? value) {
    if (value == null) return null;
    return _imperial ? value * 2.54 : value;
  }

  String _displayWeight(double valueKg) {
    final value = _imperial ? valueKg * 2.2046226218 : valueKg;
    final unit = _imperial ? 'lb' : 'kg';
    return '${value.toStringAsFixed(1)} $unit';
  }

  String _displayLength(double valueCm) {
    final value = _imperial ? valueCm / 2.54 : valueCm;
    final unit = _imperial ? 'in' : 'cm';
    return '${value.toStringAsFixed(1)} $unit';
  }

  double? _optionalNumber(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  String _date(DateTime value) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  Future<void> _refreshPatients({int? selectId}) async {
    try {
      final patients = await _patients.search('', activeOnly: false);
      if (!mounted) return;

      var selected = selectId ?? _selectedPatientId;
      if (!patients.any((patient) => patient.id == selected)) {
        selected = patients.isEmpty ? null : patients.first.id;
      }

      setState(() {
        _patientList = patients;
        _selectedPatientId = selected;
        _loading = false;
      });

      if (selected != null) {
        await _loadPatient(selected);
      } else {
        _newPatient();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  void _newPatient() {
    setState(() {
      _selectedPatientId = null;
      _sex = null;
      _isActive = true;
      _firstName.clear();
      _lastName.clear();
      _birthDate.clear();
      _email.clear();
      _phone.clear();
      _notes.clear();
      _clearTargets();
      _clearMeasurementDraft();
      _measurements = const [];
      _planHistory = const [];
      _error = null;
    });
  }

  Future<void> _loadPatient(int patientId) async {
    final patient = await _patients.getById(patientId);
    if (patient == null) return;

    final targets = await _patients.targetsFor(patientId);
    final measurements = await _patients.measurementsFor(patientId);
    final plans = await _plans.listForPatient(patientId);

    if (!mounted) return;
    setState(() {
      _selectedPatientId = patientId;
      _firstName.text = patient.firstName;
      _lastName.text = patient.lastName;
      _birthDate.text =
          patient.dateOfBirth == null ? '' : _date(patient.dateOfBirth!);
      _sex = patient.sex;
      _email.text = patient.email ?? '';
      _phone.text = patient.phone ?? '';
      _notes.text = patient.notes ?? '';
      _isActive = patient.isActive;
      _measurements = measurements;
      _planHistory = plans;
      _applyTargets(targets);
      _clearMeasurementDraft();
      _error = null;
    });
  }

  void _clearTargets() {
    _energy.clear();
    _protein.clear();
    _carbs.clear();
    _fat.clear();
    _fiber.clear();
    _sodium.clear();
  }

  void _applyTargets(List<NutritionTarget> targets) {
    _clearTargets();

    for (final target in targets) {
      final text = target.targetValue.toStringAsFixed(
        target.targetValue % 1 == 0 ? 0 : 1,
      );

      switch (target.nutrientCode) {
        case NutrientCodes.energyKcal:
          _energy.text = text;
        case NutrientCodes.protein:
          _protein.text = text;
        case NutrientCodes.carbohydrate:
          _carbs.text = text;
        case NutrientCodes.fat:
          _fat.text = text;
        case NutrientCodes.fiber:
          _fiber.text = text;
        case NutrientCodes.sodium:
          _sodium.text = text;
      }
    }
  }

  void _clearMeasurementDraft() {
    _weight.clear();
    _height.clear();
    _waist.clear();
    _measurementNotes.clear();
  }

  DateTime? _parseBirthDate() {
    final value = _birthDate.text.trim();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Future<void> _savePatient() async {
    final first = _firstName.text.trim();
    if (first.isEmpty) {
      _message('El nombre es obligatorio.');
      return;
    }

    final birthText = _birthDate.text.trim();
    final birthDate = _parseBirthDate();
    if (birthText.isNotEmpty && birthDate == null) {
      _message('Usa fecha AAAA-MM-DD.');
      return;
    }

    await _execute(() async {
      final currentId = _selectedPatientId;
      int patientId;

      if (currentId == null) {
        patientId = await _patients.create(
          Patient(
            firstName: first,
            lastName: _lastName.text.trim(),
            dateOfBirth: birthDate,
            sex: _sex,
            email: _nullIfBlank(_email.text),
            phone: _nullIfBlank(_phone.text),
            notes: _nullIfBlank(_notes.text),
            isActive: _isActive,
          ),
        );
      } else {
        final current = await _patients.getById(currentId);
        if (current == null) {
          throw StateError('El paciente ya no existe.');
        }

        await _patients.update(
          Patient(
            id: currentId,
            firstName: first,
            lastName: _lastName.text.trim(),
            dateOfBirth: birthDate,
            sex: _sex,
            email: _nullIfBlank(_email.text),
            phone: _nullIfBlank(_phone.text),
            notes: _nullIfBlank(_notes.text),
            isActive: _isActive,
            createdAt: current.createdAt,
          ),
        );
        patientId = currentId;
      }

      await _saveTargets(patientId);
      await _refreshPatients(selectId: patientId);
      _message(currentId == null ? 'Paciente creado.' : 'Paciente actualizado.');
    });
  }

  Future<void> _saveTargets(int patientId) async {
    final targets = <NutritionTarget>[];

    void add(
      TextEditingController controller,
      String code,
      NutrientUnit unit,
    ) {
      final value = _optionalNumber(controller);
      if (value == null || value <= 0) return;
      targets.add(
        NutritionTarget(
          patientId: patientId,
          nutrientCode: code,
          targetValue: value,
          unit: unit,
        ),
      );
    }

    add(_energy, NutrientCodes.energyKcal, NutrientUnit.kilocalorie);
    add(_protein, NutrientCodes.protein, NutrientUnit.gram);
    add(_carbs, NutrientCodes.carbohydrate, NutrientUnit.gram);
    add(_fat, NutrientCodes.fat, NutrientUnit.gram);
    add(_fiber, NutrientCodes.fiber, NutrientUnit.gram);
    add(_sodium, NutrientCodes.sodium, NutrientUnit.milligram);

    await _patients.setTargets(patientId, targets);
  }

  Future<void> _addMeasurement() async {
    final patientId = _selectedPatientId;
    if (patientId == null) {
      _message('Guarda primero la ficha del paciente.');
      return;
    }

    final weight = _weightInputToKg(_optionalNumber(_weight));
    final height = _lengthInputToCm(_optionalNumber(_height));
    final waist = _lengthInputToCm(_optionalNumber(_waist));

    if (weight == null && height == null && waist == null) {
      _message('Ingresa al menos una medición.');
      return;
    }

    await _execute(() async {
      await _patients.addMeasurement(
        PatientMeasurement(
          patientId: patientId,
          measuredAt: DateTime.now(),
          weightKg: weight,
          heightCm: height,
          waistCm: waist,
          notes: _nullIfBlank(_measurementNotes.text),
        ),
      );

      final measurements = await _patients.measurementsFor(patientId);
      if (!mounted) return;
      setState(() {
        _measurements = measurements;
        _clearMeasurementDraft();
      });
      _message('Evaluación guardada.');
    });
  }

  Future<void> _deleteMeasurement(int measurementId) async {
    final patientId = _selectedPatientId;
    if (patientId == null) return;

    await _execute(() async {
      await _patients.deleteMeasurement(measurementId);
      final measurements = await _patients.measurementsFor(patientId);
      if (mounted) setState(() => _measurements = measurements);
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

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
          'Pacientes',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: Center(child: Text('V0.6')),
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
                      SizedBox(width: 300, child: _patientSidebar()),
                      const VerticalDivider(width: 1),
                      Expanded(child: _workspace()),
                    ],
                  );
                }
                return _workspace(includePatientSelector: true);
              },
            ),
    );
  }

  Widget _patientSidebar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _newPatient,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nuevo paciente'),
            ),
          ),
        ),
        Expanded(
          child: _patientList.isEmpty
              ? const Center(child: Text('Todavía no hay pacientes.'))
              : ListView.builder(
                  itemCount: _patientList.length,
                  itemBuilder: (context, index) {
                    final patient = _patientList[index];
                    return ListTile(
                      selected: patient.id == _selectedPatientId,
                      leading: Icon(
                        patient.isActive
                            ? Icons.person_outline
                            : Icons.person_off_outlined,
                      ),
                      title: Text(patient.displayName),
                      subtitle: Text(patient.isActive ? 'Activo' : 'Archivado'),
                      onTap: () => _loadPatient(patient.id!),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _workspace({bool includePatientSelector = false}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (includePatientSelector) ...[
                _mobilePatientSelector(),
                const SizedBox(height: 14),
              ],
              _identityCard(),
              const SizedBox(height: 14),
              _targetsCard(),
              const SizedBox(height: 14),
              _measurementCard(),
              const SizedBox(height: 14),
              _historyCard(),
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

  Widget _mobilePatientSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
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
                onChanged: (id) {
                  if (id != null) _loadPatient(id);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Nuevo paciente',
              onPressed: _newPatient,
              icon: const Icon(Icons.person_add_alt_1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _identityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ficha del paciente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_firstName, 'Nombre')),
                const SizedBox(width: 8),
                Expanded(child: _field(_lastName, 'Apellido')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _birthDate,
                    'Fecha de nacimiento',
                    hint: 'AAAA-MM-DD',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sex,
                    decoration: const InputDecoration(
                      labelText: 'Sexo (opcional)',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'female', child: Text('Femenino')),
                      DropdownMenuItem(value: 'male', child: Text('Masculino')),
                      DropdownMenuItem(value: 'other', child: Text('Otro')),
                    ],
                    onChanged: (value) => setState(() => _sex = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _field(_email, 'Email')),
                const SizedBox(width: 8),
                Expanded(child: _field(_phone, 'Teléfono')),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notas profesionales',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Paciente activo'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _busy ? null : _savePatient,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  _selectedPatientId == null
                      ? 'Crear paciente'
                      : 'Guardar ficha y objetivos',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _targetsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Objetivos nutricionales diarios',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Los objetivos los define el profesional. Nutrikuaa los usa para comparar el plan.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _targetField(_energy, 'Energía', 'kcal'),
                _targetField(_protein, 'Proteína', 'g'),
                _targetField(_carbs, 'Carbohidratos', 'g'),
                _targetField(_fat, 'Grasas', 'g'),
                _targetField(_fiber, 'Fibra', 'g'),
                _targetField(_sodium, 'Sodio', 'mg'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _measurementCard() {
    final draft = PatientMeasurement(
      patientId: _selectedPatientId ?? 0,
      measuredAt: DateTime.now(),
      weightKg: _weightInputToKg(_optionalNumber(_weight)),
      heightCm: _lengthInputToCm(_optionalNumber(_height)),
      waistCm: _lengthInputToCm(_optionalNumber(_waist)),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Evaluación antropométrica',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Registro longitudinal. El IMC se muestra solo como cálculo kg/m².',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 190,
                  child: _field(
                    _weight,
                    _imperial ? 'Peso (lb)' : 'Peso (kg)',
                    numeric: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: _field(
                    _height,
                    _imperial ? 'Altura (in)' : 'Altura (cm)',
                    numeric: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: _field(
                    _waist,
                    _imperial ? 'Cintura (in)' : 'Cintura (cm)',
                    numeric: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    draft.bmi == null
                        ? 'IMC: —'
                        : 'IMC: ${draft.bmi!.toStringAsFixed(1)} kg/m²',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _measurementNotes,
              decoration: const InputDecoration(
                labelText: 'Notas de esta evaluación (opcional)',
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _busy || _selectedPatientId == null
                    ? null
                    : _addMeasurement,
                icon: const Icon(Icons.add_chart),
                label: const Text('Guardar evaluación'),
              ),
            ),
            const SizedBox(height: 14),
            if (_measurements.isEmpty)
              const Text('Todavía no hay mediciones registradas.')
            else
              ..._measurements.take(10).map(_measurementTile),
          ],
        ),
      ),
    );
  }

  Widget _measurementTile(PatientMeasurement measurement) {
    final parts = <String>[
      if (measurement.weightKg != null)
        _displayWeight(measurement.weightKg!),
      if (measurement.heightCm != null)
        _displayLength(measurement.heightCm!),
      if (measurement.waistCm != null)
        'cintura ${_displayLength(measurement.waistCm!)}',
      if (measurement.bmi != null)
        'IMC ${measurement.bmi!.toStringAsFixed(1)}',
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.monitor_weight_outlined),
      title: Text(_date(measurement.measuredAt)),
      subtitle: Text(
        [
          parts.join(' · '),
          if (measurement.notes != null) measurement.notes!,
        ].where((value) => value.isNotEmpty).join('\n'),
      ),
      trailing: IconButton(
        tooltip: 'Eliminar medición',
        onPressed: _busy || measurement.id == null
            ? null
            : () => _deleteMeasurement(measurement.id!),
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }

  Widget _historyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Historial de planes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                Chip(label: Text('${_planHistory.length} plan(es)')),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedPatientId == null)
              const Text('Guarda el paciente para ver su historial.')
            else if (_planHistory.isEmpty)
              const Text('Este paciente todavía no tiene planes.')
            else
              ..._planHistory.map((plan) {
                final start =
                    plan.startDate == null ? 'Sin fecha' : _date(plan.startDate!);
                final end = plan.endDate == null ? null : _date(plan.endDate!);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_view_week_outlined),
                  title: Text(plan.name),
                  subtitle: Text(
                    end == null ? start : '$start → $end',
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _targetField(
    TextEditingController controller,
    String label,
    String unit,
  ) {
    return SizedBox(
      width: 210,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: unit,
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool numeric = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}
