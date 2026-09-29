import 'package:flutter/material.dart';

import '../localization/nutri_i18n.dart';

import '../application/meal_plan_service.dart';
import '../data/app_settings_repository.dart';
import '../data/patient_repository.dart';
import '../domain/app_settings.dart';
import '../domain/meal_plan.dart';
import '../domain/nutrition/nutrient.dart';
import '../domain/patient.dart';

class PatientWorkspacePage extends StatefulWidget {
  final int refreshToken;
  final ValueChanged<int>? onPlanForPatient;

  const PatientWorkspacePage({
    super.key,
    this.refreshToken = 0,
    this.onPlanForPatient,
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
  final _reason = TextEditingController();
  final _dietaryHistory = TextEditingController();
  final _foodContext = TextEditingController();
  final _reportedAllergies = TextEditingController();
  final _clinicalContext = TextEditingController();
  final _historySource = TextEditingController();

  final _encounterDate = TextEditingController();
  final _encounterAssessment = TextEditingController();
  final _encounterProblem = TextEditingController();
  final _encounterIntervention = TextEditingController();
  final _encounterMonitoring = TextEditingController();
  final _encounterReview = TextEditingController();
  final _encounterSource = TextEditingController();
  final _observationDate = TextEditingController();
  final _observationIndicator = TextEditingController();
  final _observationValue = TextEditingController();
  final _observationUnit = TextEditingController();
  final _observationSource = TextEditingController();
  final _observationRange = TextEditingController();

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
  List<PatientEncounter> _encounters = const [];
  List<PatientObservation> _observations = const [];
  int? _encounterPlanId;

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
      _reason,
      _dietaryHistory,
      _foodContext,
      _reportedAllergies,
      _clinicalContext,
      _historySource,
      _encounterDate,
      _encounterAssessment,
      _encounterProblem,
      _encounterIntervention,
      _encounterMonitoring,
      _encounterReview,
      _encounterSource,
      _observationDate,
      _observationIndicator,
      _observationValue,
      _observationUnit,
      _observationSource,
      _observationRange,
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
      _reason.clear();
      _dietaryHistory.clear();
      _foodContext.clear();
      _reportedAllergies.clear();
      _clinicalContext.clear();
      _historySource.clear();
      _clearEncounterDraft();
      _clearObservationDraft();
      _clearTargets();
      _clearMeasurementDraft();
      _measurements = const [];
      _planHistory = const [];
      _encounters = const [];
      _observations = const [];
      _error = null;
    });
  }

  Future<void> _loadPatient(int patientId) async {
    final patient = await _patients.getById(patientId);
    if (patient == null) return;

    final targets = await _patients.targetsFor(patientId);
    final measurements = await _patients.measurementsFor(patientId);
    final plans = await _plans.listForPatient(patientId);
    final encounters = await _patients.encountersFor(patientId);
    final observations = await _patients.observationsFor(patientId);

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
      _reason.text = patient.consultationReason ?? '';
      _dietaryHistory.text = patient.dietaryHistory ?? '';
      _foodContext.text = patient.foodContext ?? '';
      _reportedAllergies.text = patient.reportedAllergies ?? '';
      _clinicalContext.text = patient.clinicalContext ?? '';
      _historySource.text = patient.historySource ?? '';
      _isActive = patient.isActive;
      _measurements = measurements;
      _planHistory = plans;
      _encounters = encounters;
      _observations = observations;
      _applyTargets(targets);
      _clearMeasurementDraft();
      _clearEncounterDraft();
      _clearObservationDraft();
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

  void _clearEncounterDraft() {
    _encounterDate.text = _date(DateTime.now());
    _encounterAssessment.clear();
    _encounterProblem.clear();
    _encounterIntervention.clear();
    _encounterMonitoring.clear();
    _encounterReview.clear();
    _encounterSource.clear();
    _encounterPlanId = null;
  }

  void _clearObservationDraft() {
    _observationDate.text = _date(DateTime.now());
    _observationIndicator.clear();
    _observationValue.clear();
    _observationUnit.clear();
    _observationSource.clear();
    _observationRange.clear();
  }

  DateTime? _parseBirthDate() {
    final value = _birthDate.text.trim();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  DateTime? _parseCalendarDate(String text) {
    final value = text.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final parsed = DateTime.tryParse(value);
    return parsed != null && _date(parsed) == value ? parsed : null;
  }

  Future<void> _savePatient() async {
    final first = _firstName.text.trim();
    if (first.isEmpty) {
      _message(NutriI18n.t('El nombre es obligatorio.'));
      return;
    }

    final birthText = _birthDate.text.trim();
    final birthDate = _parseBirthDate();
    if (birthText.isNotEmpty && birthDate == null) {
      _message(NutriI18n.t('Usa fecha AAAA-MM-DD.'));
      return;
    }
    if ([
      _reason,
      _dietaryHistory,
      _foodContext,
      _reportedAllergies,
      _clinicalContext,
    ].any((field) => field.text.trim().isNotEmpty) &&
        _historySource.text.trim().isEmpty) {
      _message('Indica la fuente de la evaluación inicial.');
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
            consultationReason: _nullIfBlank(_reason.text),
            dietaryHistory: _nullIfBlank(_dietaryHistory.text),
            foodContext: _nullIfBlank(_foodContext.text),
            reportedAllergies: _nullIfBlank(_reportedAllergies.text),
            clinicalContext: _nullIfBlank(_clinicalContext.text),
            historySource: _nullIfBlank(_historySource.text),
            isActive: _isActive,
          ),
        );
      } else {
        final current = await _patients.getById(currentId);
        if (current == null) {
          throw StateError(NutriI18n.t('El paciente ya no existe.'));
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
            consultationReason: _nullIfBlank(_reason.text),
            dietaryHistory: _nullIfBlank(_dietaryHistory.text),
            foodContext: _nullIfBlank(_foodContext.text),
            reportedAllergies: _nullIfBlank(_reportedAllergies.text),
            clinicalContext: _nullIfBlank(_clinicalContext.text),
            historySource: _nullIfBlank(_historySource.text),
            isActive: _isActive,
            createdAt: current.createdAt,
          ),
        );
        patientId = currentId;
      }

      await _saveTargets(patientId);
      await _refreshPatients(selectId: patientId);
      _message(currentId == null
          ? NutriI18n.t('Paciente creado.')
          : NutriI18n.t('Paciente actualizado.'));
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
      _message(NutriI18n.t('Guarda primero la ficha del paciente.'));
      return;
    }

    final weight = _weightInputToKg(_optionalNumber(_weight));
    final height = _lengthInputToCm(_optionalNumber(_height));
    final waist = _lengthInputToCm(_optionalNumber(_waist));

    if (weight == null && height == null && waist == null) {
      _message(NutriI18n.t('Ingresa al menos una medición.'));
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
      _message(NutriI18n.t('Evaluación guardada.'));
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

  Future<void> _addEncounter() async {
    final patientId = _selectedPatientId;
    if (patientId == null) {
      _message('Guarda primero la ficha del paciente.');
      return;
    }
    final date = _parseCalendarDate(_encounterDate.text);
    final reviewText = _encounterReview.text.trim();
    final review = reviewText.isEmpty ? null : _parseCalendarDate(reviewText);
    if (date == null) {
      _message('Revisa la fecha AAAA-MM-DD de la consulta.');
      return;
    }
    if (reviewText.isNotEmpty &&
        (review == null || review.isBefore(date))) {
      _message('Revisa las fechas AAAA-MM-DD de la consulta y seguimiento.');
      return;
    }
    if (_encounterSource.text.trim().isEmpty) {
      _message('Indica la fuente de la información de esta consulta.');
      return;
    }
    if ([
      _encounterAssessment,
      _encounterProblem,
      _encounterIntervention,
      _encounterMonitoring,
    ].every((field) => field.text.trim().isEmpty)) {
      _message('Registra al menos una observación o intervención.');
      return;
    }

    await _execute(() async {
      await _patients.addEncounter(PatientEncounter(
        patientId: patientId,
        occurredAt: date,
        assessment: _nullIfBlank(_encounterAssessment.text),
        nutritionProblem: _nullIfBlank(_encounterProblem.text),
        intervention: _nullIfBlank(_encounterIntervention.text),
        monitoring: _nullIfBlank(_encounterMonitoring.text),
        nextReviewAt: review,
        informationSource: _encounterSource.text.trim(),
        planId: _encounterPlanId,
      ));
      final encounters = await _patients.encountersFor(patientId);
      if (!mounted) return;
      setState(() {
        _encounters = encounters;
        _clearEncounterDraft();
      });
      _message('Consulta agregada al historial.');
    });
  }

  Future<void> _addObservation() async {
    final patientId = _selectedPatientId;
    final date = _parseCalendarDate(_observationDate.text);
    final value = _optionalNumber(_observationValue);
    if (patientId == null) {
      _message('Guarda primero la ficha del paciente.');
      return;
    }
    if (date == null || value == null || !value.isFinite ||
        _observationIndicator.text.trim().isEmpty ||
        _observationUnit.text.trim().isEmpty ||
        _observationSource.text.trim().isEmpty) {
      _message('Completa fecha, indicador, valor, unidad y fuente.');
      return;
    }
    await _execute(() async {
      await _patients.addObservation(PatientObservation(
        patientId: patientId,
        observedAt: date,
        indicator: _observationIndicator.text.trim(),
        value: value,
        unit: _observationUnit.text.trim(),
        source: _observationSource.text.trim(),
        referenceRange: _nullIfBlank(_observationRange.text),
      ));
      final observations = await _patients.observationsFor(patientId);
      if (!mounted) return;
      setState(() {
        _observations = observations;
        _clearObservationDraft();
      });
      _message('Indicador guardado sin interpretación automática.');
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
        title: Text(NutriI18n.t('Pacientes'),
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
              label: Text(NutriI18n.t('Nuevo paciente')),
            ),
          ),
        ),
        Expanded(
          child: _patientList.isEmpty
              ? Center(child: Text(NutriI18n.t('Todavía no hay pacientes.')))
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
                      subtitle: Text(
                        patient.isActive
                            ? NutriI18n.t('Activo')
                            : NutriI18n.t('Archivado'),
                      ),
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
              Card(
                child: ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Beta: utiliza pacientes ficticios'),
                  subtitle: const Text(
                    'Los expedientes se guardan en este navegador. '
                    'Aún no hay bloqueo local ni cifrado de la base activa. '
                    'Exporta backups cifrados si necesitas conservar pruebas.',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _identityCard(),
              const SizedBox(height: 14),
              _assessmentCard(),
              const SizedBox(height: 14),
              _targetsCard(),
              const SizedBox(height: 14),
              _measurementCard(),
              const SizedBox(height: 14),
              _observationCard(),
              const SizedBox(height: 14),
              _encounterCard(),
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
                decoration: InputDecoration(labelText: NutriI18n.t('Paciente')),
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
              tooltip: NutriI18n.t('Nuevo paciente'),
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
            Text(NutriI18n.t('Ficha del paciente'),
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
                    decoration: InputDecoration(
                      labelText: NutriI18n.t('Sexo (opcional)'),
                    ),
                    items: [
                      DropdownMenuItem(value: 'female', child: Text(NutriI18n.t('Femenino'))),
                      DropdownMenuItem(value: 'male', child: Text(NutriI18n.t('Masculino'))),
                      DropdownMenuItem(value: 'other', child: Text(NutriI18n.t('Otro'))),
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
              decoration: InputDecoration(
                labelText: NutriI18n.t('Notas profesionales'),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(NutriI18n.t('Paciente activo')),
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
                      ? NutriI18n.t('Crear paciente')
                      : NutriI18n.t('Guardar ficha y objetivos'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assessmentCard() {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.assignment_outlined),
        title: const Text('Evaluación inicial y contexto'),
        subtitle: const Text('Campos opcionales que el profesional revisa'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Registra sólo información pertinente. Alergia '
                    'reportada, intolerancia y preferencia son conceptos distintos.'),
                const SizedBox(height: 12),
                _longField(_reason, 'Motivo y objetivo acordado'),
                _longField(_dietaryHistory,
                    'Historia alimentaria: patrón, horarios y hábitos'),
                _longField(_foodContext,
                    'Preferencias, restricciones, cultura, presupuesto y acceso'),
                _longField(_reportedAllergies,
                    'Alergias o intolerancias reportadas y reacción'),
                _longField(_clinicalContext,
                    'Condiciones y medicación relevantes para la atención'),
                _field(_historySource,
                    'Fuente: paciente, cuidador, derivación o documento'),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : _savePatient,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar evaluación y ficha'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _observationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Indicadores y analíticas relevantes',
                style: Theme.of(context).textTheme.titleLarge),
            const Text('Carga manual con fecha, unidad y fuente. '
                'La app no interpreta resultados ni indica diagnósticos.'),
            if (_selectedPatientId != null) ...[
              ExpansionTile(
                title: const Text('Agregar indicador'),
                children: [
                  _field(_observationDate, 'Fecha del resultado',
                      hint: 'AAAA-MM-DD'),
                  const SizedBox(height: 10),
                  _field(_observationIndicator,
                      'Indicador (ej.: un análisis relevante)'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field(_observationValue, 'Valor',
                        numeric: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _field(_observationUnit, 'Unidad')),
                  ]),
                  const SizedBox(height: 10),
                  _field(_observationRange, 'Rango informado (opcional)'),
                  const SizedBox(height: 10),
                  _field(_observationSource, 'Fuente (obligatoria)'),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _addObservation,
                      icon: const Icon(Icons.add),
                      label: const Text('Guardar indicador'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
              if (_observations.isEmpty)
                const Text('No hay indicadores adicionales.')
              else
                for (final observation in _observations)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.science_outlined),
                    title: Text(observation.indicator + ' · ' +
                        observation.value.toString() + ' ' + observation.unit),
                    subtitle: Text(_date(observation.observedAt) +
                        ' · ' + observation.source +
                        (observation.referenceRange == null
                            ? ''
                            : ' · Rango informado: ' +
                                observation.referenceRange!)),
                  ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Guarda primero el paciente para agregar indicadores.'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _encounterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Consultas y seguimiento',
                style: Theme.of(context).textTheme.titleLarge),
            const Text('Cada consulta queda fechada. La interpretación y '
                'las decisiones corresponden al profesional.'),
            const SizedBox(height: 8),
            if (_selectedPatientId == null)
              const Text('Guarda primero el paciente para registrar consultas.')
            else ...[
              ExpansionTile(
                title: const Text('Registrar consulta'),
                children: [
                  _field(_encounterDate, 'Fecha de consulta',
                      hint: 'AAAA-MM-DD'),
                  const SizedBox(height: 10),
                  _longField(_encounterAssessment,
                      'Evaluación: cambios y datos relevantes'),
                  _longField(_encounterProblem,
                      'Problema nutricional identificado por el profesional'),
                  _longField(_encounterIntervention,
                      'Intervención y objetivos acordados'),
                  _longField(_encounterMonitoring,
                      'Indicadores, barreras y seguimiento previsto'),
                  _field(_encounterReview, 'Próxima revisión (opcional)',
                      hint: 'AAAA-MM-DD'),
                  const SizedBox(height: 10),
                  _field(_encounterSource,
                      'Fuente de los datos (obligatoria)'),
                  if (_planHistory.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: _encounterPlanId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Plan vinculado (opcional)'),
                      items: _planHistory.map((plan) => DropdownMenuItem(
                        value: plan.id,
                        child: Text(plan.name),
                      )).toList(),
                      onChanged: (value) =>
                          setState(() => _encounterPlanId = value),
                    ),
                    if (_encounterPlanId != null)
                      TextButton(
                        onPressed: () =>
                            setState(() => _encounterPlanId = null),
                        child: const Text('Desvincular plan'),
                      ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _addEncounter,
                      icon: const Icon(Icons.add),
                      label: const Text('Guardar consulta'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
              if (_encounters.isEmpty)
                const Text('Aún no hay consultas registradas.')
              else
                for (final encounter in _encounters)
                  ExpansionTile(
                    key: ValueKey('encounter-' + encounter.id.toString()),
                    leading: const Icon(Icons.event_note_outlined),
                    title: Text(_date(encounter.occurredAt)),
                    subtitle: Text(
                      encounter.intervention ??
                      encounter.assessment ??
                      encounter.nutritionProblem ??
                      'Consulta profesional',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    children: [
                      _encounterDetail('Evaluación', encounter.assessment),
                      _encounterDetail(
                          'Problema nutricional', encounter.nutritionProblem),
                      _encounterDetail(
                          'Intervención', encounter.intervention),
                      _encounterDetail(
                          'Seguimiento', encounter.monitoring),
                      _encounterDetail('Fuente', encounter.informationSource),
                      if (encounter.nextReviewAt != null)
                        _encounterDetail('Próxima revisión',
                            _date(encounter.nextReviewAt!)),
                      if (encounter.planId != null)
                        _encounterDetail('Plan vinculado',
                            _planHistory
                                .where((plan) => plan.id == encounter.planId)
                                .map((plan) => plan.name)
                                .firstOrNull ?? 'Plan anterior'),
                    ],
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _encounterDetail(String title, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return ListTile(
      title: Text(title),
      subtitle: Text(value),
      dense: true,
    );
  }

  Widget _longField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(labelText: label),
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
            Text(NutriI18n.t('Objetivos nutricionales diarios'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(NutriI18n.t('Los objetivos los define el profesional. Nutrikuaa los usa para comparar el plan.'),
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
            Text(NutriI18n.t('Evaluación antropométrica'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(NutriI18n.t('Registro longitudinal. El IMC se muestra solo como cálculo kg/m².'),
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
                    _measurementLabel('weight'),
                    numeric: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: _field(
                    _height,
                    _measurementLabel('height'),
                    numeric: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: _field(
                    _waist,
                    _measurementLabel('waist'),
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
                        ? '${_bmiLabel()}: —'
                        : '${_bmiLabel()}: ${draft.bmi!.toStringAsFixed(1)} kg/m²',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _measurementNotes,
              decoration: InputDecoration(
                labelText: NutriI18n.t('Notas de esta evaluación (opcional)'),
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
                label: Text(NutriI18n.t('Guardar evaluación')),
              ),
            ),
            const SizedBox(height: 14),
            if (_measurements.isEmpty)
              Text(NutriI18n.t('Todavía no hay mediciones registradas.'))
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
        '${_waistLabel()} ${_displayLength(measurement.waistCm!)}',
      if (measurement.bmi != null)
        '${_bmiLabel()} ${measurement.bmi!.toStringAsFixed(1)}',
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
        tooltip: NutriI18n.t('Eliminar medición'),
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
                Expanded(
                  child: Text(NutriI18n.t('Historial de planes'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                Chip(label: Text(_planCountLabel(_planHistory.length))),
              ],
            ),
            if (_selectedPatientId != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _busy
                      ? null
                      : () => widget.onPlanForPatient?.call(_selectedPatientId!),
                  icon: const Icon(Icons.calendar_view_week_outlined),
                  label: Text(NutriI18n.t('Planificar para este paciente')),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (_selectedPatientId == null)
              Text(NutriI18n.t('Guarda el paciente para ver su historial.'))
            else if (_planHistory.isEmpty)
              Text(NutriI18n.t('Este paciente todavía no tiene planes.'))
            else
              ..._planHistory.map((plan) {
                final start =
                    plan.startDate == null ? NutriI18n.t('Sin fecha') : _date(plan.startDate!);
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

  String _measurementLabel(String type) {
    final lang = NutriI18n.languageCode;
    if (type == 'weight') {
      if (lang == 'en') return _imperial ? 'Weight (lb)' : 'Weight (kg)';
      if (lang == 'pt') return _imperial ? 'Peso (lb)' : 'Peso (kg)';
      return _imperial ? 'Peso (lb)' : 'Peso (kg)';
    }
    if (type == 'height') {
      if (lang == 'en') return _imperial ? 'Height (in)' : 'Height (cm)';
      if (lang == 'pt') return _imperial ? 'Altura (in)' : 'Altura (cm)';
      return _imperial ? 'Altura (in)' : 'Altura (cm)';
    }
    if (lang == 'en') return _imperial ? 'Waist (in)' : 'Waist (cm)';
    if (lang == 'pt') return _imperial ? 'Cintura (in)' : 'Cintura (cm)';
    return _imperial ? 'Cintura (in)' : 'Cintura (cm)';
  }

  String _bmiLabel() =>
      NutriI18n.languageCode == 'en' ? 'BMI' : 'IMC';

  String _waistLabel() {
    if (NutriI18n.languageCode == 'en') return 'waist';
    return 'cintura';
  }

  String _planCountLabel(int count) {
    if (NutriI18n.languageCode == 'en') return '$count plan(s)';
    if (NutriI18n.languageCode == 'pt') return '$count plano(s)';
    return '$count plan(es)';
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
          labelText: NutriI18n.t(label),
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
        labelText: NutriI18n.t(label),
        hintText: hint == null ? null : NutriI18n.t(hint),
      ),
    );
  }
}
