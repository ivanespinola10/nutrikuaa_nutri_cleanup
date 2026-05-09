import 'package:flutter/material.dart';
import 'data/database/database_helper.dart';
import 'ui/screens/insumos_screen.dart';

void main() async {
  // Aseguramos que Flutter esté listo antes de inicializar la DB
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicialización de la Base de Datos Industrial
  // Esto importa tu CSV de 22 columnas si la tabla está vacía
  await DatabaseHelper.instance.importarCSV();

  runApp(const NutrikuaaApp());
}

class NutrikuaaApp extends StatelessWidget {
  const NutrikuaaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutrikuaa Pro',
      debugShowCheckedModeBanner: false,

      // Configuración de Tema (Estilo Industrial/Limpio)
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Verde Industrial (ISO)
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFFE65100), // Naranja (Acción/MBA)
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
      ),

      // Definimos la pantalla de inicio: La Biblioteca de Insumos
      home: const InsumosScreen(),
    );
  }
}
