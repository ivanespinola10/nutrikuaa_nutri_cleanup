import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'official_food_catalog_manifest.dart';
import 'official_food_catalog_verifier.dart';

class OfficialFoodCatalogInstaller {
  OfficialFoodCatalogInstaller._();

  static const _assetDirectory = 'assets/data';
  static const _manifestAsset = '$_assetDirectory/food_db_manifest.json';
  static const _installedManifestFile = 'nutrikuaa_foods.manifest.json';

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

    final dbDir = await getDatabasesPath();
    final targetDb = File(p.join(dbDir, bundled.installedFile));
    final localManifest = File(p.join(dbDir, _installedManifestFile));
    final previous = await _readInstalledManifest(localManifest);

    if (await targetDb.exists()) {
      try {
        await OfficialFoodCatalogVerifier.verifyBytes(
          await targetDb.readAsBytes(), bundled,
        );
        final db = await openDatabase(
          targetDb.path, readOnly: true, singleInstance: false,
        );
        try {
          await OfficialFoodCatalogVerifier.verifyDatabase(db, bundled);
        } finally {
          await db.close();
        }
        return OfficialCatalogInstallResult.alreadyCurrent;
      } catch (_) {
        // Reinstall a damaged copy from the checked bundled asset.
      }
    }

    final existed = previous != null ||
        await File(p.join(dbDir, bundled.databaseFile)).exists() ||
        await targetDb.exists();
    final assetPath = '$_assetDirectory/${bundled.databaseFile}';
    final bytes = await rootBundle.load(assetPath);

    final catalogBytes = bytes.buffer.asUint8List(
      bytes.offsetInBytes, bytes.lengthInBytes,
    );
    await OfficialFoodCatalogVerifier.verifyBytes(catalogBytes, bundled);
    await _installChecked(
      targetDb,
      catalogBytes,
      bundled,
    );

    final temporaryManifest = File('${localManifest.path}.tmp');
    await temporaryManifest.writeAsString(
      const JsonEncoder.withIndent('  ').convert(bundled.toJson()),
      flush: true,
    );
    if (await localManifest.exists()) await localManifest.delete();
    await temporaryManifest.rename(localManifest.path);

    return existed
        ? OfficialCatalogInstallResult.updated
        : OfficialCatalogInstallResult.installed;
  }

  static Future<Database?> openReadOnly() async {
    final bundled = await readBundledManifest();
    if (!bundled.bundled) return null;

    await installIfNeeded();

    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, bundled.installedFile);
    return openDatabase(
      path,
      readOnly: true,
      singleInstance: true,
    );
  }

  static Future<OfficialFoodCatalogManifest?> _readInstalledManifest(
    File file,
  ) async {
    if (!await file.exists()) return null;

    try {
      final raw = await file.readAsString();
      return OfficialFoodCatalogManifest.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _installChecked(
    File destination,
    Uint8List bytes,
    OfficialFoodCatalogManifest manifest,
  ) async {
    final temporary = File('${destination.path}.tmp');

    if (await temporary.exists()) {
      await temporary.delete();
    }

    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await OfficialFoodCatalogVerifier.verifyBytes(
        await temporary.readAsBytes(), manifest,
      );
      final db = await openDatabase(
        temporary.path, readOnly: true, singleInstance: false,
      );
      try {
        await OfficialFoodCatalogVerifier.verifyDatabase(db, manifest);
      } finally {
        await db.close();
      }
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destination.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
