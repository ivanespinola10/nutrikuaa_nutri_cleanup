import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import 'official_food_catalog_manifest.dart';
import 'official_food_catalog_verifier.dart';

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

    final path = bundled.installedFile;
    final existed = await databaseFactory.databaseExists(path) ||
        await databaseFactory.databaseExists(bundled.databaseFile);

    if (await databaseFactory.databaseExists(path) &&
        await _matchesBundledVersion(path, bundled)) {
      return OfficialCatalogInstallResult.alreadyCurrent;
    }

    if (await databaseFactory.databaseExists(path)) {
      await databaseFactory.deleteDatabase(path);
    }

    final assetPath = '$_assetDirectory/${bundled.databaseFile}';
    final data = await rootBundle.load(assetPath);
    final bytes = Uint8List.sublistView(data);
    await OfficialFoodCatalogVerifier.verifyBytes(bytes, bundled);

    try {
      await databaseFactory.writeDatabaseBytes(path, bytes);
      if (!await _matchesBundledVersion(path, bundled)) {
        throw StateError('Installed catalog failed SQLite validation.');
      }
    } catch (_) {
      if (await databaseFactory.databaseExists(path)) {
        await databaseFactory.deleteDatabase(path);
      }
      rethrow;
    }

    return existed
        ? OfficialCatalogInstallResult.updated
        : OfficialCatalogInstallResult.installed;
  }

  static Future<Database?> openReadOnly() async {
    final bundled = await readBundledManifest();
    if (!bundled.bundled) return null;

    await installIfNeeded();

    return openDatabase(
      bundled.installedFile,
      singleInstance: true,
    );
  }

  static Future<bool> _matchesBundledVersion(
    String path,
    OfficialFoodCatalogManifest bundled,
  ) async {
    Database? db;
    try {
      db = await openDatabase(path, singleInstance: false);
      await OfficialFoodCatalogVerifier.verifyDatabase(db, bundled);
      return true;
    } catch (_) {
      return false;
    } finally {
      await db?.close();
    }
  }
}
