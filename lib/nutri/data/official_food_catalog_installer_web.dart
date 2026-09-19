import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import 'official_food_catalog_manifest.dart';

class OfficialFoodCatalogInstaller {
  OfficialFoodCatalogInstaller._();

  static const _assetDirectory = 'assets/data';
  static const _manifestAsset = '$_assetDirectory/food_db_manifest.json';

  static Future<OfficialFoodCatalogManifest> readBundledManifest() async {
    final raw = await rootBundle.loadString(_manifestAsset);
    return OfficialFoodCatalogManifest.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  static Future<OfficialCatalogInstallResult> installIfNeeded() async {
    final bundled = await readBundledManifest();
    if (!bundled.bundled) {
      return OfficialCatalogInstallResult.noCatalogBundled;
    }

    final path = bundled.databaseFile;
    final existed = await databaseFactory.databaseExists(path);

    if (existed && await _matchesBundledVersion(path, bundled)) {
      return OfficialCatalogInstallResult.alreadyCurrent;
    }

    if (existed) {
      await databaseFactory.deleteDatabase(path);
    }

    final assetPath = '$_assetDirectory/${bundled.databaseFile}';
    final data = await rootBundle.load(assetPath);
    final bytes = Uint8List.sublistView(data);

    await databaseFactory.writeDatabaseBytes(path, bytes);

    return existed
        ? OfficialCatalogInstallResult.updated
        : OfficialCatalogInstallResult.installed;
  }

  static Future<Database?> openReadOnly() async {
    final bundled = await readBundledManifest();
    if (!bundled.bundled) return null;

    await installIfNeeded();

    return openDatabase(
      bundled.databaseFile,
      singleInstance: true,
    );
  }

  static Future<bool> _matchesBundledVersion(
    String path,
    OfficialFoodCatalogManifest bundled,
  ) async {
    Database? db;
    try {
      db = await openDatabase(path, singleInstance: true);
      final rows = await db.query(
        'catalog_metadata',
        where: 'key IN (?, ?)',
        whereArgs: ['schema_version', 'source_release'],
      );

      final metadata = <String, String>{
        for (final row in rows)
          row['key'] as String: row['value'] as String,
      };

      return metadata['schema_version'] == bundled.schemaVersion.toString() &&
          metadata['source_release'] == bundled.sourceRelease;
    } catch (_) {
      return false;
    } finally {
      await db?.close();
    }
  }
}
