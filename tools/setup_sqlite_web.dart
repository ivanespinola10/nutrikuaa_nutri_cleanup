import 'dart:io';

Future<void> main() async {
  final repoRoot = Directory.current.absolute;
  final webDir = Directory('${repoRoot.path}${Platform.pathSeparator}web');

  if (!await webDir.exists()) {
    stderr.writeln('ERROR: ejecuta este comando desde la raiz del repositorio.');
    exitCode = 1;
    return;
  }

  final tempRoot =
      await Directory.systemTemp.createTemp('nutrikuaa_sqlite_web_');
  final projectDir = Directory(
    '${tempRoot.path}${Platform.pathSeparator}worker_project',
  );

  try {
    stdout.writeln('Generando SQLite Web en proyecto temporal limpio...');
    await _run(
      'dart',
      ['create', '-t', 'web', '--force', projectDir.path],
    );

    await _run(
      'dart',
      [
        'pub',
        'add',
        'sqflite_common_ffi_web:1.0.2',
        'sqflite_common_ffi:2.3.7+1',
        'sqlite3:2.9.4',
      ],
      workingDirectory: projectDir.path,
    );

    await _run(
      'dart',
      ['run', 'sqflite_common_ffi_web:setup', '--force'],
      workingDirectory: projectDir.path,
    );

    final generatedWeb = Directory(
      '${projectDir.path}${Platform.pathSeparator}web',
    );
    final wasm = File(
      '${generatedWeb.path}${Platform.pathSeparator}sqlite3.wasm',
    );
    final worker = File(
      '${generatedWeb.path}${Platform.pathSeparator}sqflite_sw.js',
    );

    if (!await wasm.exists() || !await worker.exists()) {
      throw StateError(
        'El proyecto temporal no genero sqlite3.wasm y sqflite_sw.js.',
      );
    }

    await wasm.copy(
      '${webDir.path}${Platform.pathSeparator}sqlite3.wasm',
    );
    await worker.copy(
      '${webDir.path}${Platform.pathSeparator}sqflite_sw.js',
    );

    stdout.writeln('SQLite Web listo:');
    stdout.writeln('  web/sqlite3.wasm');
    stdout.writeln('  web/sqflite_sw.js');
  } finally {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  }
}

Future<void> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  stdout.writeln('> $executable ${arguments.join(' ')}');

  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );

  final code = await process.exitCode;
  if (code != 0) {
    throw ProcessException(
      executable,
      arguments,
      'Comando finalizo con codigo $code',
      code,
    );
  }
}
