import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';

import 'official_food_catalog_manifest.dart';

class OfficialFoodCatalogVerifier {
  OfficialFoodCatalogVerifier._();

  static Future<void> verifyBytes(
    Uint8List bytes,
    OfficialFoodCatalogManifest manifest,
  ) async {
    final digest = await Sha256().hash(bytes);
    final checksum = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    if (checksum != manifest.sha256) {
      throw StateError('Official catalog SHA-256 does not match its manifest.');
    }
  }

  static Future<void> verifyDatabase(
    Database db,
    OfficialFoodCatalogManifest manifest,
  ) async {
    final integrity = await db.rawQuery('PRAGMA quick_check');
    if (integrity.length != 1 || integrity.first.values.single != 'ok') {
      throw StateError('Official catalog SQLite integrity check failed.');
    }

    final rows = await db.query(
      'catalog_metadata',
      where: 'key IN (?, ?)',
      whereArgs: ['schema_version', 'source_release'],
    );
    final metadata = <String, String>{
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    if (metadata['schema_version'] != manifest.schemaVersion.toString() ||
        metadata['source_release'] != manifest.sourceRelease) {
      throw StateError('Official catalog metadata does not match its manifest.');
    }

    final foodCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM foods'),
        ) ??
        0;
    if (foodCount <= 0) {
      throw StateError('Official catalog contains no foods.');
    }
  }
}
