import 'package:flutter/material.dart';

import '../application/backup_file.dart';
import '../application/nutri_backup_service.dart';
import '../data/app_settings_repository.dart';
import '../domain/app_settings.dart';

class SettingsWorkspacePage extends StatefulWidget {
  final VoidCallback onDataRestored;
  final VoidCallback onSettingsChanged;

  const SettingsWorkspacePage({
    super.key,
    required this.onDataRestored,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsWorkspacePage> createState() => _SettingsWorkspacePageState();
}

class _SettingsWorkspacePageState extends State<SettingsWorkspacePage> {
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();
  final NutriBackupService _backupService = NutriBackupService();

  final _country = TextEditingController(text: 'PY');

  String _languageCode = 'es';
  UnitSystem _unitSystem = UnitSystem.metric;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _country.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsRepository.load();
      if (!mounted) return;
      setState(() {
        _languageCode = settings.languageCode;
        _country.text = settings.countryCode;
        _unitSystem = settings.unitSystem;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    final country = _country.text.trim().toUpperCase();
    if (country.length != 2) {
      _message('Usa un código de país ISO de 2 letras, por ejemplo PY, AR o ES.');
      return;
    }

    await _execute(() async {
      await _settingsRepository.save(
        AppSettings(
          languageCode: _languageCode,
          countryCode: country,
          unitSystem: _unitSystem,
        ),
      );
      _country.text = country;
      widget.onSettingsChanged();
      _message('Configuración guardada.');
    });
  }

  Future<void> _exportBackup() async {
    await _execute(() async {
      final bytes = await _backupService.exportBackup();
      final now = DateTime.now();
      final fileName =
          'nutrikuaa_backup_${now.year}${_two(now.month)}${_two(now.day)}_'
          '${_two(now.hour)}${_two(now.minute)}.nutrikuaa';

      await saveNutrikuaaBackup(
        bytes,
        suggestedName: fileName,
      );
      _message('Backup generado.');
    });
  }

  Future<void> _restoreBackup() async {
    if (_busy) return;

    try {
      final bytes = await pickNutrikuaaBackup();
      if (bytes == null) return;

      final summary = await _backupService.inspect(bytes);
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restaurar backup'),
          content: Text(
            'El archivo contiene:\n\n'
            '• ${summary.patientCount} paciente(s)\n'
            '• ${summary.planCount} plan(es)\n'
            '• ${summary.recipeCount} receta(s)\n'
            '• ${summary.foodCount} alimento(s) locales/snapshots\n\n'
            'La restauración reemplazará los datos locales actuales de '
            'Nutrikuaa Nutri en este dispositivo/navegador.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await _execute(() async {
        final restored = await _backupService.restoreBackup(bytes);
        await _loadSettings();
        widget.onDataRestored();
        _message(
          'Backup restaurado: ${restored.patientCount} paciente(s), '
          '${restored.planCount} plan(es).',
        );
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
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

  String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configuración',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: Center(child: Text('V0.8')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _regionalCard(),
                      const SizedBox(height: 14),
                      _backupCard(),
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
            ),
    );
  }

  Widget _regionalCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Región y unidades',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Estas preferencias se guardan localmente. El idioma y las '
              'unidades ya se aplican al PDF profesional.',
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _languageCode,
              decoration: const InputDecoration(
                labelText: 'Idioma',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'es',
                  child: Text('Español'),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text('English'),
                ),
                DropdownMenuItem(
                  value: 'pt',
                  child: Text('Português'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _languageCode = value);
                      }
                    },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _country,
              textCapitalization: TextCapitalization.characters,
              maxLength: 2,
              decoration: const InputDecoration(
                labelText: 'País (código ISO)',
                hintText: 'PY',
                helperText: 'Ej.: PY, AR, BR, ES, US, MX, GB',
              ),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<UnitSystem>(
              value: _unitSystem,
              decoration: const InputDecoration(
                labelText: 'Sistema de unidades',
              ),
              items: const [
                DropdownMenuItem(
                  value: UnitSystem.metric,
                  child: Text('Métrico (g, kg, cm)'),
                ),
                DropdownMenuItem(
                  value: UnitSystem.imperial,
                  child: Text('Imperial (oz, lb, in)'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _unitSystem = value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _busy ? null : _saveSettings,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar configuración'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backupCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Backup y restauración',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'El archivo .nutrikuaa contiene tus datos profesionales locales, '
              'incluidos pacientes, planes, recetas, alimentos propios, '
              'snapshots USDA, configuración, identidad y logo. La base USDA '
              'oficial no se duplica en el backup.',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _exportBackup,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Crear backup .nutrikuaa'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _restoreBackup,
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('Restaurar backup'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Recomendación: crea un backup antes de cambiar de equipo, '
              'navegador o instalar una actualización importante.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
