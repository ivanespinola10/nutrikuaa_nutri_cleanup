import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrikuaa_app/nutri/application/food_import_service.dart';
import 'package:nutrikuaa_app/nutri/domain/food.dart';
import 'package:nutrikuaa_app/nutri/domain/nutrition/nutrient.dart';

void main() {
  final service = FoodImportService();

  test('imports Spanish semicolon CSV with decimal comma', () {
    final csv = [
      'Nombre;Calorias;Proteinas;Hidratos;Lipidos;Fibra;Alergenos',
      'Chipa;320;11,5;42,0;12,5;2,1;Leche|Huevo',
      'Mandioca hervida;125;1,0;30,0;0,3;1,8;',
    ].join('\n');

    final preview = service.parse(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      fileName: 'paraguay.csv',
      sourceName: 'Base Paraguay',
      countryCode: 'PY',
    );

    expect(preview.foods, hasLength(2));
    expect(preview.rejectedRows, 0);
    final chipa = preview.foods.first;
    expect(chipa.sourceType, FoodSourceType.imported);
    expect(chipa.sourceName, 'Base Paraguay');
    expect(chipa.countryCode, 'PY');
    expect(chipa.nutrient(NutrientCodes.energyKcal)?.valuePer100g, 320);
    expect(chipa.nutrient(NutrientCodes.protein)?.valuePer100g, 11.5);
    expect(chipa.allergens, containsAll(['milk', 'egg']));
  });

  test('rejects impossible required macros', () {
    final csv = [
      'Nombre,Calorias,Proteinas,Hidratos,Lipidos',
      'Correcto,100,5,10,2',
      'Roto,100,150,10,2',
    ].join('\n');
    final preview = service.parse(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      fileName: 'foods.csv',
    );
    expect(preview.foods, hasLength(1));
    expect(preview.rejectedRows, 1);
  });

  test('requires five clinical calculation columns', () {
    final csv = ['Nombre,Calorias,Proteinas', 'Arroz,130,2.5'].join('\n');
    expect(
      () => service.parse(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileName: 'incomplete.csv',
      ),
      throwsFormatException,
    );
  });
}
