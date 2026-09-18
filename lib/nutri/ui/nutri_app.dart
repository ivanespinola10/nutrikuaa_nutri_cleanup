import 'package:flutter/material.dart';

import 'nutri_workspace_page.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const NutriWorkspacePage(),
    );
  }
}
