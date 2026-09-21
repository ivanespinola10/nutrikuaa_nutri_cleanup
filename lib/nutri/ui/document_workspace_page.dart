import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../localization/nutri_i18n.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../application/meal_plan_service.dart';
import '../application/plan_pdf_service.dart';
import '../data/app_settings_repository.dart';
import '../data/patient_repository.dart';
import '../data/professional_profile_repository.dart';
import '../domain/app_settings.dart';
import '../domain/meal_plan.dart';
import '../domain/patient.dart';
import '../domain/professional_profile.dart';

class DocumentWorkspacePage extends StatefulWidget {
  final int refreshToken;

  const DocumentWorkspacePage({
    super.key,
    this.refreshToken = 0,
  });

  @override
  State<DocumentWorkspacePage> createState() => _DocumentWorkspacePageState();
}

class _DocumentWorkspacePageState extends State<DocumentWorkspacePage> {
  final PatientRepository _patients = PatientRepository();
  final MealPlanService _plans = MealPlanService();
  final ProfessionalProfileRepository _profileRepository =
      ProfessionalProfileRepository();
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();
  final PlanPdfService _pdfService = PlanPdfService();

  final _fullName = TextEditingController();
  final _credentials = TextEditingController();
  final _registration = TextEditingController();
  final _practice = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _footer = TextEditingController();

  List<Patient> _patientList = const [];
  List<MealPlan> _planList = const [];
  int? _selectedPatientId;
  int? _selectedPlanId;

  Uint8List? _nutrikuaaLogoBytes;
  Uint8List? _customLogoBytes;
  String? _customLogoFileName;
  Uint8List? _pdfBytes;
  AppSettings _settings = const AppSettings();

  bool _includeNutrition = true;
  bool _includeRecipeInstructions = true;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant DocumentWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _refreshPatients();
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _credentials,
      _registration,
      _practice,
      _phone,
      _email,
      _footer,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final profile = await _profileRepository.load();
      final settings = await _settingsRepository.load();
      final asset = await rootBundle.load('assets/logo.png');

      if (!mounted) return;
      setState(() {
        _nutrikuaaLogoBytes = asset.buffer.asUint8List();
        _customLogoBytes = profile.logoBytes;
        _customLogoFileName = profile.logoFileName;
        _settings = settings;
        _applyProfile(profile);
      });

      await _refreshPatients();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyProfile(ProfessionalProfile profile) {
    _fullName.text = profile.fullName;
    _credentials.text = profile.credentials ?? '';
    _registration.text = profile.registrationNumber ?? '';
    _practice.text = profile.practiceName ?? '';
    _phone.text = profile.phone ?? '';
    _email.text = profile.email ?? '';
    _footer.text = profile.footerText ?? '';
  }

  ProfessionalProfile _profileFromForm() {
    return ProfessionalProfile(
      fullName: _fullName.text.trim(),
      credentials: _nullIfBlank(_credentials.text),
      registrationNumber: _nullIfBlank(_registration.text),
      practiceName: _nullIfBlank(_practice.text),
      phone: _nullIfBlank(_phone.text),
      email: _nullIfBlank(_email.text),
      footerText: _nullIfBlank(_footer.text),
      logoBytes: _customLogoBytes,
      logoFileName: _customLogoFileName,
    );
  }

  Future<void> _refreshPatients() async {
    final patients = await _patients.search('', activeOnly: false);
    if (!mounted) return;

    var patientId = _selectedPatientId;
    if (!patients.any((patient) => patient.id == patientId)) {
      patientId = patients.isEmpty ? null : patients.first.id;
    }

    setState(() {
      _patientList = patients;
      _selectedPatientId = patientId;
      _pdfBytes = null;
    });

    if (patientId != null) {
      await _loadPlans(patientId);
    } else {
      setState(() {
        _planList = const [];
        _selectedPlanId = null;
      });
    }
  }

  Future<void> _loadPlans(int patientId) async {
    final plans = await _plans.listForPatient(patientId);
    if (!mounted) return;

    var planId = _selectedPlanId;
    if (!plans.any((plan) => plan.id == planId)) {
      planId = plans.isEmpty ? null : plans.first.id;
    }

    setState(() {
      _selectedPatientId = patientId;
      _planList = plans;
      _selectedPlanId = planId;
      _pdfBytes = null;
    });
  }

  Future<void> _pickLogo() async {
    const typeGroup = XTypeGroup(
      label: 'Logos',
      extensions: ['png', 'jpg', 'jpeg'],
      mimeTypes: ['image/png', 'image/jpeg'],
      uniformTypeIdentifiers: ['public.png', 'public.jpeg'],
      webWildCards: ['image/png', 'image/jpeg'],
    );

    final file = await openFile(
      acceptedTypeGroups: const [typeGroup],
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      _message(NutriI18n.t('El archivo está vacío.'));
      return;
    }
    if (bytes.length > 2 * 1024 * 1024) {
      _message(NutriI18n.t('El logo debe pesar menos de 2 MB.'));
      return;
    }
    if (!_isPngOrJpeg(bytes)) {
      _message(NutriI18n.t('Usa un archivo PNG o JPG válido.'));
      return;
    }

    if (!mounted) return;
    setState(() {
      _customLogoBytes = bytes;
      _customLogoFileName = file.name;
      _pdfBytes = null;
    });

    await _profileRepository.save(_profileFromForm());
    _message(NutriI18n.t('Logo profesional guardado.'));
  }

  Future<void> _useNutrikuaaLogo() async {
    setState(() {
      _customLogoBytes = null;
      _customLogoFileName = null;
      _pdfBytes = null;
    });

    await _profileRepository.save(_profileFromForm());
    _message(NutriI18n.t('Se usará el logo de Nutrikuaa.'));
  }

  bool _isPngOrJpeg(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return true;
    }

    return bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
  }

  Uint8List? get _activeLogoBytes =>
      _customLogoBytes ?? _nutrikuaaLogoBytes;

  Future<void> _saveProfile() async {
    await _execute(() async {
      final profile = _profileFromForm();
      await _profileRepository.save(profile);
      _message(NutriI18n.t('Identidad profesional guardada.'));
    });
  }

  Future<void> _generatePdf() async {
    final planId = _selectedPlanId;
    if (planId == null) {
      _message(NutriI18n.t('Selecciona un paciente con un plan.'));
      return;
    }

    await _execute(() async {
      final profile = _profileFromForm();
      await _profileRepository.save(profile);

      final bytes = await _pdfService.build(
        planId: planId,
        profile: profile,
        logoBytes: _activeLogoBytes,
        includeNutritionSummary: _includeNutrition,
        includeRecipeInstructions: _includeRecipeInstructions,
        settings: _settings,
      );

      if (!mounted) return;
      setState(() => _pdfBytes = bytes);
      _message(NutriI18n.t('PDF generado.'));
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

  String get _pdfFileName {
    final patient = _patientList
        .where((patient) => patient.id == _selectedPatientId)
        .cast<Patient?>()
        .firstOrNull;
    final name = patient?.displayName.trim().replaceAll(' ', '_') ?? 'paciente';
    return 'Nutrikuaa_Plan_$name.pdf';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(NutriI18n.t('Documentos'),
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: Center(child: Text('V0.7.1')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _professionalCard(),
                      const SizedBox(height: 14),
                      _documentCard(),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        SelectableText(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (_pdfBytes != null) ...[
                        const SizedBox(height: 16),
                        _previewCard(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _professionalCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(NutriI18n.t('Identidad profesional'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(NutriI18n.t('Estos datos quedan guardados localmente y aparecerán en tus documentos.'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_fullName, 'Nombre profesional')),
                const SizedBox(width: 8),
                Expanded(child: _field(_credentials, 'Título / credencial')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _registration,
                    'Registro / matrícula profesional',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _field(
                    _practice,
                    'Consultorio / marca profesional',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _field(_phone, 'Teléfono')),
                const SizedBox(width: 8),
                Expanded(child: _field(_email, 'Email')),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _footer,
              decoration: InputDecoration(
                labelText: NutriI18n.t('Pie del documento (opcional)'),
                hintText: NutriI18n.t('Ej.: Consultas con cita previa'),
              ),
            ),
            const SizedBox(height: 14),
            _brandingRow(),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _saveProfile,
                icon: const Icon(Icons.save_outlined),
                label: Text(NutriI18n.t('Guardar identidad')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brandingRow() {
    final logo = _activeLogoBytes;
    final usingCustom = _customLogoBytes != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 72,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: logo == null
                ? const Icon(Icons.image_outlined)
                : Image.memory(
                    logo,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usingCustom
                      ? NutriI18n.t('Logo profesional')
                      : NutriI18n.t('Logo Nutrikuaa'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  usingCustom
                      ? (_customLogoFileName ?? NutriI18n.t('Logo personalizado'))
                      : NutriI18n.t('Se usa como respaldo mientras no cargues uno propio.'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pickLogo,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(
                        usingCustom
                            ? NutriI18n.t('Cambiar logo')
                            : NutriI18n.t('Cargar logo'),
                      ),
                    ),
                    if (usingCustom)
                      TextButton.icon(
                        onPressed: _busy ? null : _useNutrikuaaLogo,
                        icon: const Icon(Icons.restart_alt),
                        label: Text(NutriI18n.t('Usar logo Nutrikuaa')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(NutriI18n.t('Generar plan para el paciente'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
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
                    onChanged: _busy
                        ? null
                        : (id) {
                            if (id != null) _loadPlans(id);
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedPlanId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: NutriI18n.t('Plan / semana')),
                    items: _planList
                        .map(
                          (plan) => DropdownMenuItem(
                            value: plan.id,
                            child: Text(plan.name),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (id) => setState(() {
                            _selectedPlanId = id;
                            _pdfBytes = null;
                          }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                FilterChip(
                  label: Text(NutriI18n.t('Mostrar resumen nutricional diario')),
                  selected: _includeNutrition,
                  onSelected: (value) => setState(() {
                    _includeNutrition = value;
                    _pdfBytes = null;
                  }),
                ),
                FilterChip(
                  label: Text(NutriI18n.t('Incluir preparación de recetas')),
                  selected: _includeRecipeInstructions,
                  onSelected: (value) => setState(() {
                    _includeRecipeInstructions = value;
                    _pdfBytes = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy || _selectedPlanId == null
                  ? null
                  : _generatePdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(NutriI18n.t('Generar vista previa PDF')),
            ),
            if (_planList.isEmpty && _selectedPatientId != null) ...[
              const SizedBox(height: 8),
              Text(NutriI18n.t('Este paciente todavía no tiene planes para exportar.'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _previewCard() {
    final bytes = _pdfBytes!;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 760,
        child: PdfPreview(
          build: (_) async => bytes,
          initialPageFormat: PdfPageFormat.a4,
          canChangeOrientation: false,
          canChangePageFormat: false,
          allowPrinting: true,
          allowSharing: true,
          pdfFileName: _pdfFileName,
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: NutriI18n.t(label)),
    );
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
