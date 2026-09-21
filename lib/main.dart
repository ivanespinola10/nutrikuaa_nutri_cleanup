import 'package:flutter/material.dart';

import 'nutri/data/app_settings_repository.dart';
import 'nutri/data/database_platform.dart';
import 'nutri/localization/nutri_i18n.dart';
import 'nutri/ui/nutri_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDatabasePlatform();
  final settings = await AppSettingsRepository().load();
  NutriI18n.setLanguage(settings.languageCode);
  runApp(const NutrikuaaNutriApp());
}
