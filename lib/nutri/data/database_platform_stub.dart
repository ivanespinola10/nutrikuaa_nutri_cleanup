Future<void> configureDatabasePlatform() async {
  // Native platforms use sqflite's default database factory.
}

Future<void> recoverDatabasePlatform() async {
  // Native platforms do not need a browser-worker fallback.
}
