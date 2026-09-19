import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'official_food_catalog_manifest.dart';

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
    final targetDb = File(p.join(dbDir, bundled.databaseFile));
    final localManifest = File(p.join(dbDir, _installedManifestFile));

    final previous = await _readInstalledManifest(localManifest);
    final isCurrent = previous != null &&
        previous.schemaVersion == bundled.schemaVersion &&
        previous.dataVersion == bundled.dataVersion &&
        await targetDb.exists();

    if (isCurrent) {
      return OfficialCatalogInstallResult.alreadyCurrent;
    }

    final existed = await targetDb.exists();
    final assetPath = '$_assetDirectory/${bundled.databaseFile}';
    final bytes = await rootBundle.load(assetPath);

    await _replaceAtomically(
      targetDb,
      bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      ),
    );

    await localManifest.writeAsString(
      const JsonEncoder.withIndent('  ').convert(bundled.toJson()),
      flush: true,
    );

    return existed
        ? OfficialCatalogInstallResult.updated
        : OfficialCatalogInstallResult.installed;
  }

  static Future<Database?> openReadOnly() async {
    final bundled = await readBundledManifest();
    if (!bundled.bundled) return null;

    await installIfNeeded();

    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, bundled.databaseFile);
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

  static Future<void> _replaceAtomically(
    File destination,
    Uint8List bytes,
  ) async {
    final temporary = File('${destination.path}.tmp');

    if (await temporary.exists()) {
      await temporary.delete();
    }

    await temporary.writeAsBytes(bytes, flush: true);

    if (await destination.exists()) {
      await destination.delete();
    }

    await temporary.rename(destination.path);
  }
}
