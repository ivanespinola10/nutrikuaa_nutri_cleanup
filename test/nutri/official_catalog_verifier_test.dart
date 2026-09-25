import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nutrikuaa_app/nutri/data/official_food_catalog_manifest.dart';
import 'package:nutrikuaa_app/nutri/data/official_food_catalog_verifier.dart';

void main() {
  test('bundled USDA release has matching hash, structure and energy coverage',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final raw = jsonDecode(
      File('assets/data/food_db_manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final manifest = OfficialFoodCatalogManifest.fromJson(raw);
    final file = File('assets/data/${manifest.databaseFile}');
    final bytes = await file.readAsBytes();
    await OfficialFoodCatalogVerifier.verifyBytes(bytes, manifest);

    final db = await databaseFactoryFfi.openDatabase(
      file.absolute.path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    try {
      await OfficialFoodCatalogVerifier.verifyDatabase(db, manifest);
      final energyCount = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM food_nutrients WHERE nutrient_code = 'energy_kcal'",
          )) ??
          0;
      expect(energyCount, greaterThanOrEqualTo(370));
      final specificCount = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM food_nutrients WHERE source_nutrient_id = '2048'",
          )) ??
          0;
      expect(specificCount, greaterThan(0));
    } finally {
      await db.close();
    }

    final modified = Uint8List.fromList(bytes);
    modified[modified.length - 1] ^= 1;
    await expectLater(
      OfficialFoodCatalogVerifier.verifyBytes(modified, manifest),
      throwsStateError,
    );
  });
}
