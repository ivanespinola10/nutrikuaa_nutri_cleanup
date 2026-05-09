import 'package:flutter/material.dart';
import '../data/database/database_helper.dart';
import 'detalle_producto_page.dart';

class ProyectosPage extends StatefulWidget {
  const ProyectosPage({super.key});

  @override
  State<ProyectosPage> createState() => _ProyectosPageState();
}

class _ProyectosPageState extends State<ProyectosPage> {
  List<Map<String, dynamic>> _misFormulas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarMisFormulas();
  }

  void _cargarMisFormulas() async {
    // Sincronizado con DatabaseHelper.getMisFormulas()
    final datos = await DatabaseHelper.instance.getMisFormulas();
    setState(() {
      _misFormulas = datos;
      _isLoading = false;
    });
  }

  void _borrarFormula(int id) async {
    bool confirmar =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("¿Eliminar Fórmula?"),
            content: const Text("Esta acción no se puede deshacer."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Eliminar"),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmar) {
      // Sincronizado con DatabaseHelper.borrarProducto()
      await DatabaseHelper.instance.borrarProducto(id);
      _cargarMisFormulas();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("🗑️ Fórmula eliminada")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Manten tu build actual, está perfecto) ...
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Proyectos I+D 🚀'),
        backgroundColor: Colors.indigo,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _misFormulas.isEmpty
          ? _buildEmptyState()
          : _buildListView(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.science_outlined, size: 80, color: Colors.grey),
          const Text("No tienes fórmulas guardadas aún."),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Ir a crear una"),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: _misFormulas.length,
      itemBuilder: (context, index) {
        final item = _misFormulas[index];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange[800],
              child: const Icon(Icons.edit, color: Colors.white),
            ),
            title: Text(
              item['nombre'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Kcal: ${item['energia_kcal']?.toStringAsFixed(0)} | Ver Detalles >",
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetalleProductoPage(producto: item),
                ),
              );
              _cargarMisFormulas();
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.grey),
              onPressed: () => _borrarFormula(item['id']),
            ),
          ),
        );
      },
    );
  }
}
