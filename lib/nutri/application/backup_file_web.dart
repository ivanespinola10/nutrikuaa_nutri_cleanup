import 'dart:html' as html;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

const _backupType = XTypeGroup(
  label: 'Nutrikuaa backup',
  extensions: ['nutrikuaa'],
  mimeTypes: ['application/json', 'application/octet-stream'],
  webWildCards: ['application/json', 'application/octet-stream'],
);

Future<void> saveNutrikuaaBackup(
  Uint8List bytes, {
  required String suggestedName,
}) async {
  final blob = html.Blob(
    [bytes],
    'application/octet-stream',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..download = suggestedName
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<Uint8List?> pickNutrikuaaBackup() async {
  final file = await openFile(
    acceptedTypeGroups: const [_backupType],
  );
  if (file == null) return null;
  return file.readAsBytes();
}
