import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../application/backup_file.dart';
import '../application/nutri_backup_service.dart';
import '../data/app_settings_repository.dart';
import '../domain/app_settings.dart';
import '../localization/nutri_i18n.dart';

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
  bool _encryptBackup = true;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  String _t(String value) => NutriI18n.t(value);

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
      _message(_languageCode == 'en'
          ? 'Use a 2-letter ISO country code, for example US, AR or ES.'
          : _languageCode == 'pt'
              ? 'Use um código ISO de país com 2 letras, por exemplo BR, AR ou ES.'
              : 'Usa un código de país ISO de 2 letras, por ejemplo PY, AR o ES.');
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
      NutriI18n.setLanguage(_languageCode);
      widget.onSettingsChanged();
      _message(_t('Configuración guardada.'));
    });
  }

  Future<String?> _askNewPassword() async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    bool obscure = true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_t('Cifrar backup con contraseña')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: password,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _t('Contraseña del backup'),
                  helperText: _t('La contraseña debe tener al menos 8 caracteres.'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmation,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: _t('Confirmar contraseña'),
                  suffixIcon: IconButton(
                    tooltip: obscure ? 'Show' : 'Hide',
                    onPressed: () => setDialogState(() => obscure = !obscure),
                    icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Cancelar')),
            ),
            FilledButton(
              onPressed: () {
                if (password.text.trim().length < 8) {
                  _message(_t('La contraseña debe tener al menos 8 caracteres.'));
                  return;
                }
                if (password.text.trim() != confirmation.text.trim()) {
                  _message(_t('Las contraseñas no coinciden.'));
                  return;
                }
                Navigator.pop(context, password.text.trim());
              },
              child: Text(_t('Guardar')),
            ),
          ],
        ),
      ),
    );

    password.dispose();
    confirmation.dispose();
    return result;
  }

  Future<String?> _askExistingPassword() async {
    final password = TextEditingController();
    bool obscure = true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_t('Restaurar backup')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_t('Este backup está cifrado. Ingresa la contraseña.')),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: obscure,
                autofocus: true,
                onSubmitted: (_) {
                  if (password.text.trim().isNotEmpty) {
                    Navigator.pop(context, password.text.trim());
                  }
                },
                decoration: InputDecoration(
                  labelText: _t('Contraseña del backup'),
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(() => obscure = !obscure),
                    icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Cancelar')),
            ),
            FilledButton(
              onPressed: () {
                if (password.text.trim().isNotEmpty) {
                  Navigator.pop(context, password.text.trim());
                }
              },
              child: Text(_t('Desbloquear')),
            ),
          ],
        ),
      ),
    );

    password.dispose();
    return result;
  }

  Future<void> _exportBackup() async {
    String? password;
    if (_encryptBackup) {
      password = await _askNewPassword();
      if (password == null) return;
    }

    await _execute(() async {
      var bytes = await _backupService.exportBackup();
      if (password != null) {
        bytes = await _backupService.encryptBackup(bytes, password);
      }

      final now = DateTime.now();
      final secureSuffix = password == null ? '' : '_secure';
      final fileName =
          'nutrikuaa_backup_${now.year}${_two(now.month)}${_two(now.day)}_'
          '${_two(now.hour)}${_two(now.minute)}$secureSuffix.nutrikuaa';

      await saveNutrikuaaBackup(
        bytes,
        suggestedName: fileName,
      );
      _message(_t('Backup generado.'));
    });
  }

  Future<void> _restoreBackup() async {
    if (_busy) return;

    try {
      var bytes = await pickNutrikuaaBackup();
      if (bytes == null) return;

      if (_backupService.isEncrypted(bytes)) {
        final password = await _askExistingPassword();
        if (password == null) return;
        bytes = await _backupService.decryptBackup(bytes, password);
      }

      final summary = await _backupService.inspect(bytes);
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_t('Restaurar backup')),
          content: Text(_restoreSummary(summary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_t('Cancelar')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_t('Restaurar')),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await _execute(() async {
        final restored = await _backupService.restoreBackup(bytes!);
        await _loadSettings();
        final settings = await _settingsRepository.load();
        NutriI18n.setLanguage(settings.languageCode);
        widget.onDataRestored();
        _message(_restoredMessage(restored));
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  String _restoreSummary(BackupResult summary) {
    if (NutriI18n.languageCode == 'en') {
      return 'The file contains:\n\n'
          '• ${summary.patientCount} patient(s)\n'
          '• ${summary.planCount} plan(s)\n'
          '• ${summary.recipeCount} recipe(s)\n'
          '• ${summary.foodCount} local food(s)/snapshots\n\n'
          'Restoring will replace the current local Nutrikuaa Nutri data '
          'on this device/browser.';
    }
    if (NutriI18n.languageCode == 'pt') {
      return 'O arquivo contém:\n\n'
          '• ${summary.patientCount} paciente(s)\n'
          '• ${summary.planCount} plano(s)\n'
          '• ${summary.recipeCount} receita(s)\n'
          '• ${summary.foodCount} alimento(s) local(is)/snapshots\n\n'
          'A restauração substituirá os dados locais atuais do Nutrikuaa Nutri '
          'neste dispositivo/navegador.';
    }
    return 'El archivo contiene:\n\n'
        '• ${summary.patientCount} paciente(s)\n'
        '• ${summary.planCount} plan(es)\n'
        '• ${summary.recipeCount} receta(s)\n'
        '• ${summary.foodCount} alimento(s) locales/snapshots\n\n'
        'La restauración reemplazará los datos locales actuales de '
        'Nutrikuaa Nutri en este dispositivo/navegador.';
  }

  String _restoredMessage(BackupResult restored) {
    if (NutriI18n.languageCode == 'en') {
      return 'Backup restored: ${restored.patientCount} patient(s), '
          '${restored.planCount} plan(s).';
    }
    if (NutriI18n.languageCode == 'pt') {
      return 'Backup restaurado: ${restored.patientCount} paciente(s), '
          '${restored.planCount} plano(s).';
    }
    return 'Backup restaurado: ${restored.patientCount} paciente(s), '
        '${restored.planCount} plan(es).';
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
        title: Text(
          _t('Configuración'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: Center(child: Text('V0.8.1')),
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
    final description = NutriI18n.languageCode == 'en'
        ? 'These preferences are stored locally and apply across the professional interface and PDF documents.'
        : NutriI18n.languageCode == 'pt'
            ? 'Estas preferências são armazenadas localmente e se aplicam à interface profissional e aos documentos PDF.'
            : 'Estas preferencias se guardan localmente y se aplican a la interfaz profesional y a los documentos PDF.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t('Región y unidades'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(description),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _languageCode,
              decoration: InputDecoration(labelText: _t('Idioma')),
              items: const [
                DropdownMenuItem(value: 'es', child: Text('Español')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'pt', child: Text('Português')),
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
              decoration: InputDecoration(
                labelText: _t('País (código ISO)'),
                hintText: 'PY',
                helperText: 'PY, AR, BR, ES, US, MX, GB…',
              ),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<UnitSystem>(
              value: _unitSystem,
              decoration: InputDecoration(
                labelText: _t('Sistema de unidades'),
              ),
              items: [
                DropdownMenuItem(
                  value: UnitSystem.metric,
                  child: Text(_t('Métrico (g, kg, cm)')),
                ),
                DropdownMenuItem(
                  value: UnitSystem.imperial,
                  child: Text(_t('Imperial (oz, lb, in)')),
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
                label: Text(_t('Guardar configuración')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backupCard() {
    final description = NutriI18n.languageCode == 'en'
        ? 'The .nutrikuaa file contains your local professional data: patients, plans, recipes, custom foods, USDA snapshots, settings, identity and logo. The full official USDA catalog is not duplicated.'
        : NutriI18n.languageCode == 'pt'
            ? 'O arquivo .nutrikuaa contém seus dados profissionais locais: pacientes, planos, receitas, alimentos próprios, snapshots USDA, configurações, identidade e logo. O catálogo oficial completo do USDA não é duplicado.'
            : 'El archivo .nutrikuaa contiene tus datos profesionales locales: pacientes, planes, recetas, alimentos propios, snapshots USDA, configuración, identidad y logo. La base USDA oficial completa no se duplica.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t('Backup y restauración'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(description),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _encryptBackup,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _encryptBackup = value),
              title: Text(_t('Cifrar backup con contraseña')),
              subtitle: Text(
                NutriI18n.languageCode == 'en'
                    ? 'Recommended when the backup contains real patient data. The password is never stored.'
                    : NutriI18n.languageCode == 'pt'
                        ? 'Recomendado quando o backup contém dados reais de pacientes. A senha nunca é armazenada.'
                        : 'Recomendado cuando el backup contiene datos reales de pacientes. La contraseña nunca se guarda.',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _exportBackup,
                  icon: Icon(
                    _encryptBackup ? Icons.lock_outline : Icons.download_outlined,
                  ),
                  label: Text(_t('Crear backup .nutrikuaa')),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _restoreBackup,
                  icon: const Icon(Icons.restore_outlined),
                  label: Text(_t('Restaurar backup')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
