class OfficialFoodCatalogManifest {
  final int schemaVersion;
  final String dataVersion;
  final String sourceName;
  final String sourceRelease;
  final String databaseFile;
  final bool bundled;

  const OfficialFoodCatalogManifest({
    required this.schemaVersion,
    required this.dataVersion,
    required this.sourceName,
    required this.sourceRelease,
    required this.databaseFile,
    required this.bundled,
  });

  factory OfficialFoodCatalogManifest.fromJson(Map<String, dynamic> json) {
    return OfficialFoodCatalogManifest(
      schemaVersion: json['schemaVersion'] as int,
      dataVersion: json['dataVersion'] as String,
      sourceName: json['sourceName'] as String,
      sourceRelease: json['sourceRelease'] as String,
      databaseFile: json['databaseFile'] as String,
      bundled: json['bundled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'dataVersion': dataVersion,
        'sourceName': sourceName,
        'sourceRelease': sourceRelease,
        'databaseFile': databaseFile,
        'bundled': bundled,
      };
}

enum OfficialCatalogInstallResult {
  installed,
  updated,
  alreadyCurrent,
  noCatalogBundled,
}
