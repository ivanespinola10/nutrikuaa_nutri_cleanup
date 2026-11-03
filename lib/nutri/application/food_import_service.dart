import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../domain/food.dart';
import '../domain/nutrition/nutrient.dart';

class FoodImportPreview {
  final List<Food> foods;
  final int rowsRead;
  final int rejectedRows;
  final List<String> warnings;

  const FoodImportPreview({
    required this.foods,
    required this.rowsRead,
    required this.rejectedRows,
    required this.warnings,
  });

  FoodImportPreview withSourceName(String sourceName) => FoodImportPreview(
    foods: foods
        .map((food) => food.copyWith(sourceName: sourceName.trim()))
        .toList(growable: false),
    rowsRead: rowsRead,
    rejectedRows: rejectedRows,
    warnings: warnings,
  );
}

class FoodImportService {
  static const _required = {'name', 'energy', 'protein', 'carbs', 'fat'};

  static const Map<String, List<String>> _aliases = {
    'id': ['id', 'codigo', 'código', 'food id', 'food_id'],
    'name': [
      'nombre',
      'alimento',
      'name',
      'food',
      'food name',
      'food_name',
      'descripcion',
      'descripción',
      'description',
    ],
    'brand': ['marca', 'brand'],
    'country': ['pais', 'país', 'country', 'country code', 'country_code'],
    'source': ['fuente', 'source', 'procedencia', 'origen', 'referencia'],
    'energy': [
      'calorias',
      'calorías',
      'energia',
      'energía',
      'kcal',
      'energy',
      'energy kcal',
      'energy_kcal',
    ],
    'protein': [
      'proteina',
      'proteína',
      'proteinas',
      'proteínas',
      'protein',
      'proteins',
    ],
    'carbs': [
      'hidratos',
      'hidratos de carbono',
      'carbohidrato',
      'carbohidratos',
      'carbohydrate',
      'carbohydrates',
      'carbs',
    ],
    'fat': ['lipidos', 'lípidos', 'grasa', 'grasas', 'fat', 'total fat'],
    'fiber': ['fibra', 'fiber', 'fibre'],
    'sugars': ['azucar', 'azúcar', 'azucares', 'azúcares', 'sugar', 'sugars'],
    'sodium': ['sodio', 'sodium', 'sodio mg', 'sodium mg'],
    'calcium': ['calcio', 'calcium', 'calcio mg', 'calcium mg'],
    'iron': ['hierro', 'iron', 'hierro mg', 'iron mg'],
    'potassium': ['potasio', 'potassium', 'potasio mg', 'potassium mg'],
    'vitamin_a': ['vitamina a', 'vitamin a', 'retinol'],
    'vitamin_c': ['vitamina c', 'vitamin c'],
    'vitamin_d': ['vitamina d', 'vitamin d'],
    'serving': [
      'porcion g',
      'porción g',
      'porcion gramos',
      'porción gramos',
      'serving grams',
      'serving_g',
      'serving',
    ],
    'measure': [
      'medida casera',
      'household measure',
      'household_measure',
      'measure',
    ],
    'allergens': ['alergenos', 'alérgenos', 'allergens'],
    'notes': ['notas', 'notes', 'observaciones', 'observación'],
  };

  FoodImportPreview parse({
    required Uint8List bytes,
    required String fileName,
    String? sourceName,
    String? countryCode,
  }) {
    final lower = fileName.toLowerCase();
    final rows = lower.endsWith('.csv')
        ? _readCsv(bytes)
        : lower.endsWith('.xlsx')
        ? _readExcel(bytes)
        : throw const FormatException('Formato no compatible. Usa CSV o XLSX.');

    if (rows.isEmpty)
      throw const FormatException('El archivo no contiene filas.');

    final headerIndex = _detectHeaderRow(rows);
    final normalizedHeaders = rows[headerIndex]
        .map(_normalize)
        .toList(growable: false);
    final columns = _resolveColumns(normalizedHeaders);
    final missing = _required
        .where((key) => !columns.containsKey(key))
        .toList();

    if (missing.isNotEmpty) {
      throw FormatException(
        'Faltan columnas obligatorias: ${missing.map(_label).join(', ')}. '
        'Se requieren nombre, kcal, proteínas, carbohidratos y grasas por 100 g.',
      );
    }

    final foods = <Food>[];
    final warnings = <String>[];
    final seen = <String>{};
    var rejected = 0;
    final defaultSource = sourceName?.trim().isNotEmpty == true
        ? sourceName!.trim()
        : _baseName(fileName);

    for (var rowIndex = headerIndex + 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (row.every((cell) => cell.trim().isEmpty)) continue;

      final name = _value(row, columns['name']).trim();
      final energy = _number(_value(row, columns['energy']));
      final protein = _number(_value(row, columns['protein']));
      final carbs = _number(_value(row, columns['carbs']));
      final fat = _number(_value(row, columns['fat']));

      if (name.isEmpty ||
          !_requiredNumber(energy, 1000) ||
          !_requiredNumber(protein, 100) ||
          !_requiredNumber(carbs, 100) ||
          !_requiredNumber(fat, 100)) {
        rejected++;
        if (warnings.length < 10) {
          warnings.add(
            'Fila ${rowIndex + 1}: "${name.isEmpty ? 'sin nombre' : name}" omitida por datos básicos inválidos.',
          );
        }
        continue;
      }

      final brand = _nullable(_value(row, columns['brand']));
      final dedupeKey = '${_normalize(name)}|${_normalize(brand ?? '')}';
      if (!seen.add(dedupeKey)) {
        rejected++;
        if (warnings.length < 10)
          warnings.add(
            'Fila ${rowIndex + 1}: "$name" duplicado dentro del archivo.',
          );
        continue;
      }

      final nutrients = <NutrientValue>[
        NutrientValue(
          code: NutrientCodes.energyKcal,
          valuePer100g: energy!,
          unit: NutrientUnit.kilocalorie,
        ),
        NutrientValue(
          code: NutrientCodes.protein,
          valuePer100g: protein!,
          unit: NutrientUnit.gram,
        ),
        NutrientValue(
          code: NutrientCodes.carbohydrate,
          valuePer100g: carbs!,
          unit: NutrientUnit.gram,
        ),
        NutrientValue(
          code: NutrientCodes.fat,
          valuePer100g: fat!,
          unit: NutrientUnit.gram,
        ),
      ];

      _optionalNutrient(
        nutrients,
        NutrientCodes.fiber,
        NutrientUnit.gram,
        _value(row, columns['fiber']),
        100,
      );
      _optionalNutrient(
        nutrients,
        NutrientCodes.sugars,
        NutrientUnit.gram,
        _value(row, columns['sugars']),
        100,
      );
      _optionalNutrient(
        nutrients,
        NutrientCodes.sodium,
        NutrientUnit.milligram,
        _value(row, columns['sodium']),
        100000,
      );
      _optionalNutrient(
        nutrients,
        NutrientCodes.calcium,
        NutrientUnit.milligram,
        _value(row, columns['calcium']),
        100000,
      );
      _optionalNutrient(
        nutrients,
        NutrientCodes.iron,
        NutrientUnit.milligram,
        _value(row, columns['iron']),
        10000,
      );
      _optionalNutrient(
        nutrients,
        NutrientCodes.potassium,
        NutrientUnit.milligram,
        _value(row, columns['potassium']),
        100000,
      );
      _optionalNutrient(
        nutrients,
        NutrientCodes.vitaminA,
        NutrientUnit.microgram,
        _value(row, columns['vitamin_a']),
        1000000,
      );
      _optionalNutrient(
        nutrients,
        NutrientCodes.vitaminC,
        NutrientUnit.milligram,
        _value(row, columns['vitamin_c']),
        100000,
      );
      _optionalNutrient(
        nutrients,
        NutrientCodes.vitaminD,
        NutrientUnit.microgram,
        _value(row, columns['vitamin_d']),
        100000,
      );

      final serving = _boundedNumber(_value(row, columns['serving']), 10000);
      final rowSource = _nullable(_value(row, columns['source']));
      final rowCountry = _nullable(_value(row, columns['country']));

      foods.add(
        Food(
          name: name,
          brand: brand,
          countryCode: (rowCountry ?? countryCode)?.trim().toUpperCase(),
          sourceType: FoodSourceType.imported,
          sourceName: rowSource ?? defaultSource,
          sourceFoodId: _nullable(_value(row, columns['id'])),
          sourceRelease:
              'Importación local ${DateTime.now().toIso8601String().substring(0, 10)}',
          servingQuantity: serving,
          servingUnit: serving == null ? null : 'g',
          householdMeasure: _nullable(_value(row, columns['measure'])),
          notes: _nullable(_value(row, columns['notes'])),
          nutrients: nutrients,
          allergens: _allergens(_value(row, columns['allergens'])),
        ),
      );
    }

    if (foods.isEmpty)
      throw const FormatException(
        'No se encontró ningún alimento válido para importar.',
      );

    return FoodImportPreview(
      foods: foods,
      rowsRead: rows.length - headerIndex - 1,
      rejectedRows: rejected,
      warnings: warnings,
    );
  }

  List<List<String>> _readCsv(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      text = latin1.decode(bytes);
    }
    if (text.startsWith('\ufeff')) text = text.substring(1);
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final firstLine = text
        .split('\n')
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
    final delimiter = _delimiter(firstLine);
    return CsvToListConverter(
          fieldDelimiter: delimiter,
          shouldParseNumbers: false,
          allowInvalid: true,
          eol: '\n',
        )
        .convert(text)
        .map((row) => row.map((value) => value?.toString() ?? '').toList())
        .toList();
  }

  List<List<String>> _readExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    for (final name in excel.tables.keys) {
      final sheet = excel.tables[name];
      if (sheet == null || sheet.maxRows == 0 || sheet.maxColumns == 0)
        continue;
      return sheet.rows
          .map((row) => row.map(_excelCellText).toList(growable: false))
          .toList(growable: false);
    }
    throw const FormatException('El libro de Excel no contiene datos.');
  }

  String _excelCellText(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';

    return switch (value) {
      TextCellValue() => _excelTextSpan(value.value),
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => value.value.toString(),
      BoolCellValue() => value.value ? 'true' : 'false',
      DateCellValue() => '${value.day}.${value.month}',
      TimeCellValue() => '${value.hour}:${value.minute}:${value.second}',
      DateTimeCellValue() => '${value.day}.${value.month}',
      FormulaCellValue() => value.formula,
    };
  }

  String _excelTextSpan(TextSpan span) {
    final buffer = StringBuffer(span.text ?? '');
    for (final child in span.children ?? const <TextSpan>[]) {
      buffer.write(_excelTextSpan(child));
    }
    return buffer.toString();
  }

  String _delimiter(String line) {
    final counts = {
      ',': ','.allMatches(line).length,
      ';': ';'.allMatches(line).length,
      '\t': '\t'.allMatches(line).length,
    };
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  int _detectHeaderRow(List<List<String>> rows) {
    var bestIndex = 0;
    var bestScore = -1;
    final limit = rows.length < 10 ? rows.length : 10;
    for (var index = 0; index < limit; index++) {
      final headers = rows[index].map(_normalize).toSet();
      var score = 0;
      for (final aliases in _aliases.values) {
        if (aliases.map(_normalize).any(headers.contains)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  Map<String, int> _resolveColumns(List<String> headers) {
    final result = <String, int>{};
    for (final entry in _aliases.entries) {
      final aliases = entry.value.map(_normalize).toSet();
      for (var index = 0; index < headers.length; index++) {
        if (aliases.contains(headers[index])) {
          result[entry.key] = index;
          break;
        }
      }
    }
    return result;
  }

  String _value(List<String> row, int? index) =>
      index == null || index < 0 || index >= row.length
      ? ''
      : row[index].trim();

  double? _number(String raw) {
    var value = raw.trim().replaceAll('\u00a0', '').replaceAll(' ', '');
    value = value.replaceAll(
      RegExp(
        r'(kcal|kj|mg|mcg|µg|ug|gramos|grams|gr|g)$',
        caseSensitive: false,
      ),
      '',
    );
    if (value.isEmpty || value == '-1' || value == '-1.0' || value == '-1,0')
      return null;
    final comma = value.lastIndexOf(',');
    final dot = value.lastIndexOf('.');
    if (comma >= 0 && dot >= 0) {
      if (comma > dot) {
        value = value.replaceAll('.', '').replaceAll(',', '.');
      } else {
        value = value.replaceAll(',', '');
      }
    } else if (comma >= 0) {
      value = value.replaceAll(',', '.');
    }
    value = value.replaceAll(RegExp(r'[^0-9eE+\-.]'), '');
    return double.tryParse(value);
  }

  bool _requiredNumber(double? value, double max) =>
      value != null && value.isFinite && value >= 0 && value <= max;
  double? _boundedNumber(String raw, double max) {
    final value = _number(raw);
    return value == null || !value.isFinite || value < 0 || value > max
        ? null
        : value;
  }

  void _optionalNutrient(
    List<NutrientValue> nutrients,
    String code,
    NutrientUnit unit,
    String raw,
    double max,
  ) {
    final value = _boundedNumber(raw, max);
    if (value != null)
      nutrients.add(NutrientValue(code: code, valuePer100g: value, unit: unit));
  }

  List<String> _allergens(String raw) {
    final result = <String>{};
    for (final item in raw.split(RegExp(r'[,;|/]')).map(_normalize)) {
      if (item.contains('gluten') ||
          item.contains('trigo') ||
          item.contains('wheat'))
        result.add('gluten');
      else if (item.contains('leche') ||
          item.contains('lacteo') ||
          item == 'milk' ||
          item.contains('dairy'))
        result.add('milk');
      else if (item.contains('huevo') || item == 'egg')
        result.add('egg');
      else if (item.contains('mani') ||
          item.contains('cacahu') ||
          item.contains('peanut'))
        result.add('peanut');
      else if (item.contains('almendra') ||
          item.contains('nuez') ||
          item.contains('avellana') ||
          item.contains('tree nut'))
        result.add('tree_nuts');
      else if (item.contains('soja') || item.contains('soy'))
        result.add('soy');
      else if (item.contains('pescado') || item.contains('fish'))
        result.add('fish');
      else if (item.contains('crustace'))
        result.add('crustaceans');
      else if (item.contains('molusc'))
        result.add('molluscs');
      else if (item.contains('sesamo') || item.contains('sesame'))
        result.add('sesame');
      else if (item.contains('apio') || item.contains('celery'))
        result.add('celery');
      else if (item.contains('mostaza') || item.contains('mustard'))
        result.add('mustard');
      else if (item.contains('altramuz') || item.contains('lupin'))
        result.add('lupin');
      else if (item.contains('sulfit'))
        result.add('sulphites');
    }
    return result.toList()..sort();
  }

  String _normalize(String value) {
    var text = value.trim().toLowerCase();
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    replacements.forEach((from, to) => text = text.replaceAll(from, to));
    return text
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _label(String key) => switch (key) {
    'name' => 'nombre',
    'energy' => 'kcal',
    'protein' => 'proteínas',
    'carbs' => 'carbohidratos',
    'fat' => 'grasas',
    _ => key,
  };
  String? _nullable(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  String _baseName(String fileName) {
    final name = fileName.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}
