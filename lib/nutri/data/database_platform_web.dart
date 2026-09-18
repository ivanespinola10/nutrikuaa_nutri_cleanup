import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<void> configureDatabasePlatform() async {
  databaseFactory = createDatabaseFactoryFfiWeb(
    options: SqfliteFfiWebOptions(
      sqlite3WasmUri: Uri.parse('sqlite3.wasm?v=2'),
      sharedWorkerUri: Uri.parse('sqflite_sw.js?v=2'),
      indexedDbName: 'nutrikuaa_nutri_web_v1',
    ),
  );
}
