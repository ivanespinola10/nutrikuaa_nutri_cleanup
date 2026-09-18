import 'package:flutter/material.dart';

import 'nutri/data/database_platform.dart';
import 'nutri/ui/nutri_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDatabasePlatform();
  runApp(const NutrikuaaNutriApp());
}
