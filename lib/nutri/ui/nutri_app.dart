import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/tester_firebase_options.dart';
import 'nutri_main_shell.dart';
import 'tester_access_gate.dart';

class NutrikuaaNutriApp extends StatelessWidget {
  const NutrikuaaNutriApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF176B57);
    return MaterialApp(
      title: 'Nutrikuaa Nutri',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(), filled: true, fillColor: Colors.white,
        ),
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      ),
      home: kIsWeb
          ? TesterFirebaseOptions.ready
              ? const TesterAccessGate()
              : const Scaffold(
                  body: Center(
                    child: Text('Configuración de acceso para testers pendiente. Consulta docs/TESTER_ACCESS.md.'),
                  ),
                )
          : const NutriMainShell(),
    );
  }
}
