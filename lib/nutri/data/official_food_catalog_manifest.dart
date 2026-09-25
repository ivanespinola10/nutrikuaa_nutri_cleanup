class OfficialFoodCatalogManifest {
  final int schemaVersion;
  final String dataVersion;
  final String sourceName;
  final String sourceRelease;
  final String databaseFile;
  final String sha256;
  final bool bundled;

  const OfficialFoodCatalogManifest({
    required this.schemaVersion,
    required this.dataVersion,
    required this.sourceName,
    required this.sourceRelease,
    required this.databaseFile,
    required this.sha256,
    required this.bundled,
  });

  factory OfficialFoodCatalogManifest.fromJson(Map<String, dynamic> json) {
    final databaseFile = json['databaseFile'] as String;
    final checksum = json['sha256'] as String;
    if (!RegExp(r'^[a-zA-Z0-9_-]+\.db$').hasMatch(databaseFile) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(checksum)) {
      throw FormatException('Invalid catalog file or SHA-256 in manifest.');
    }
    return OfficialFoodCatalogManifest(
      schemaVersion: json['schemaVersion'] as int,
      dataVersion: json['dataVersion'] as String,
      sourceName: json['sourceName'] as String,
      sourceRelease: json['sourceRelease'] as String,
      databaseFile: databaseFile,
      sha256: checksum,
      bundled: json['bundled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'dataVersion': dataVersion,
        'sourceName': sourceName,
        'sourceRelease': sourceRelease,
        'databaseFile': databaseFile,
        'sha256': sha256,
        'bundled': bundled,
      };

  // New releases use a new storage key. A failed replacement cannot erase
  // the previously installed catalog (or the separate professional database).
  String get installedFile =>
      '${databaseFile.substring(0, databaseFile.length - 3)}-${sha256.substring(0, 16)}.db';
}

enum OfficialCatalogInstallResult {
  installed,
  updated,
  alreadyCurrent,
  noCatalogBundled,
}
