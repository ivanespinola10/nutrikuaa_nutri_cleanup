import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

const _backupType = XTypeGroup(
  label: 'Nutrikuaa backup',
  extensions: ['nutrikuaa'],
  mimeTypes: ['application/json', 'application/octet-stream'],
  uniformTypeIdentifiers: ['public.data'],
  webWildCards: ['application/json', 'application/octet-stream'],
);

Future<void> saveNutrikuaaBackup(
  Uint8List bytes, {
  required String suggestedName,
}) async {
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [_backupType],
  );
  if (location == null) return;

  final file = XFile.fromData(
    bytes,
    mimeType: 'application/octet-stream',
    name: suggestedName,
  );
  await file.saveTo(location.path);
}

Future<Uint8List?> pickNutrikuaaBackup() async {
  final file = await openFile(
    acceptedTypeGroups: const [_backupType],
  );
  if (file == null) return null;
  return file.readAsBytes();
}
