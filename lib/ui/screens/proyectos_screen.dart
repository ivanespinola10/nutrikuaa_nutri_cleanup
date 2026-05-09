import 'package:flutter/material.dart';
import '../../data/database/database_helper.dart';
import '../../models/proyecto_model.dart';
import 'detalle_proyecto_screen.dart'; // La crearemos a continuación

class ProyectosScreen extends StatefulWidget {
  const ProyectosScreen({super.key});

  @override
  State<ProyectosScreen> createState() => _ProyectosScreenState();
}

class _ProyectosScreenState extends State<ProyectosScreen> {
  List<ProyectoModel> _proyectos = [];

  @override
  void initState() {
    super.initState();
    _cargarProyectos();
  }

  Future<void> _cargarProyectos() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> res = await db.query(
      'proyectos',
      orderBy: 'id DESC',
    );
    setState(() {
      _proyectos = res.map((m) => ProyectoModel.fromMap(m)).toList();
    });
  }

  void _nuevoProyecto() async {
    // Diálogo rápido para el nombre
    String nombre = "";
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nuevo Proyecto I+D"),
        content: TextField(
          onChanged: (v) => nombre = v,
          decoration: const InputDecoration(
            hintText: "Nombre (Ej: Muffin Proteico v1)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombre.isNotEmpty) {
                final p = ProyectoModel(
                  nombre: nombre,
                  fecha: DateTime.now().toString().split(' ')[0],
                );
                await DatabaseHelper.instance.guardarProyecto(p);
                Navigator.pop(context);
                _cargarProyectos();
              }
            },
            child: const Text("Crear"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Proyectos I+D 🏭"),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: _proyectos.isEmpty
          ? const Center(
              child: Text("Crea tu primer proyecto para empezar a formular."),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _proyectos.length,
              itemBuilder: (context, index) {
                final p = _proyectos[index];
                return Card(
                  elevation: 3,
                  child: ListTile(
                    leading: const Icon(Icons.biotech, color: Colors.blue),
                    title: Text(
                      p.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("Región: ${p.region} | Fecha: ${p.fecha}"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // TODO: Navegar al detalle (El Mezclador)
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoProyecto,
        label: const Text("NUEVA FÓRMULA"),
        icon: const Icon(Icons.science),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
