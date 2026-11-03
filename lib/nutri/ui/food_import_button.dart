import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../application/food_import_service.dart';
import '../application/food_library_service.dart';
import '../data/app_settings_repository.dart';

class FoodImportButton extends StatefulWidget {
  final Future<void> Function() onImported;
  const FoodImportButton({super.key, required this.onImported});

  @override
  State<FoodImportButton> createState() => _FoodImportButtonState();
}

class _FoodImportButtonState extends State<FoodImportButton> {
  final _importer = FoodImportService();
  final _library = FoodLibraryService();
  bool _busy = false;

  Future<void> _pickAndImport() async {
    if (_busy) return;
    const typeGroup = XTypeGroup(
      label: 'Base de alimentos',
      extensions: ['csv', 'xlsx'],
      mimeTypes: [
        'text/csv',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ],
      webWildCards: [
        'text/csv',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ],
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _message('El archivo está vacío.');
        return;
      }
      if (bytes.length > 25 * 1024 * 1024) {
        _message('La base debe pesar menos de 25 MB.');
        return;
      }

      final settings = await AppSettingsRepository().load();
      final preview = _importer.parse(
        bytes: bytes,
        fileName: file.name,
        sourceName: _baseName(file.name),
        countryCode: settings.countryCode,
      );
      if (!mounted) return;
      final approved = await _confirm(preview, file.name);
      if (approved == null) return;
      final imported = await _library.importFoods(approved.foods);
      await widget.onImported();
      _message(
        'Base importada: $imported alimentos. ${approved.rejectedRows} filas omitidas.',
      );
    } on FormatException catch (error) {
      _message(error.message);
    } catch (error) {
      _message('No se pudo importar la base: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<FoodImportPreview?> _confirm(
    FoodImportPreview preview,
    String fileName,
  ) async {
    final source = TextEditingController(text: _baseName(fileName));
    var rights = false;
    try {
      return await showDialog<FoodImportPreview>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: const Text('Importar mi base'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: source,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la fuente / base',
                        helperText:
                            'Se conserva como procedencia de cada alimento.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('${preview.foods.length} válidos')),
                        Chip(label: Text('${preview.rejectedRows} omitidos')),
                        Chip(label: Text('${preview.rowsRead} filas leídas')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Vista previa',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final food in preview.foods.take(8))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(food.name),
                        subtitle: Text(
                          '${food.nutrient("energy_kcal")?.valuePer100g.toStringAsFixed(0) ?? "-"} kcal · P ${food.nutrient("protein")?.valuePer100g.toStringAsFixed(1) ?? "-"} g · C ${food.nutrient("carbohydrate")?.valuePer100g.toStringAsFixed(1) ?? "-"} g · G ${food.nutrient("fat")?.valuePer100g.toStringAsFixed(1) ?? "-"} g',
                        ),
                      ),
                    if (preview.warnings.isNotEmpty) ...[
                      const Divider(),
                      Text(
                        'Revisión automática',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final warning in preview.warnings.take(6))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('• $warning'),
                        ),
                    ],
                    const Divider(),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: rights,
                      onChanged: (value) =>
                          setLocalState(() => rights = value ?? false),
                      title: const Text(
                        'Confirmo que tengo derecho a utilizar estos datos.',
                      ),
                      subtitle: const Text(
                        'La base se guarda solo en este dispositivo. Nutrikuaa no la sube a la nube.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: !rights || source.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(
                        dialogContext,
                        preview.withSourceName(source.text.trim()),
                      ),
                child: const Text('Importar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      source.dispose();
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _baseName(String fileName) {
    final name = fileName.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _busy ? null : _pickAndImport,
    icon: _busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.upload_file_outlined),
    label: Text(_busy ? 'Importando...' : 'Importar mi base'),
  );
}
