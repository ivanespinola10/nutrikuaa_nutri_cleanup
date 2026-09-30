import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'nutri/config/tester_firebase_options.dart';
import 'nutri/data/app_settings_repository.dart';
import 'nutri/data/database_platform.dart';
import 'nutri/localization/nutri_i18n.dart';
import 'nutri/ui/nutri_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb && TesterFirebaseOptions.ready) {
    await Firebase.initializeApp(options: TesterFirebaseOptions.web);
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  } else if (!kIsWeb) {
    await configureDatabasePlatform();
    final settings = await AppSettingsRepository().load();
    NutriI18n.setLanguage(settings.languageCode);
  }
  runApp(const NutrikuaaNutriApp());
}
