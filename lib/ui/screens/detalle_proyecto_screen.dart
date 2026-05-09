import 'package:flutter/material.dart';
import '../../models/proyecto_model.dart';
import '../../data/database/database_helper.dart';
import '../../core/calculos_nutricionales.dart';
import 'insumos_screen.dart'; // Para reutilizar la búsqueda

class DetalleProyectoScreen extends StatefulWidget {
  final ProyectoModel proyecto;
  const DetalleProyectoScreen({super.key, required this.proyecto});

  @override
  State<DetalleProyectoScreen> createState() => _DetalleProyectoScreenState();
}

class _DetalleProyectoScreenState extends State<DetalleProyectoScreen> {
  List<Map<String, dynamic>> _items = [];
  double _pesoTotal = 0;
  double _kcalTotales = 0;
  double _protTotales = 0;

  @override
  void initState() {
    super.initState();
    _cargarItems();
  }

  Future<void> _cargarItems() async {
    final res = await DatabaseHelper.instance.getItemsDelProyecto(
      widget.proyecto.id!,
    );
    double p = 0;
    double k = 0;
    double pr = 0;

    for (var item in res) {
      double cant = item['cantidad_g'];
      p += cant;
      k += (item['calorias'] * cant) / 100;
      pr += (item['proteinas'] * cant) / 100;
    }

    setState(() {
      _items = res;
      _pesoTotal = p;
      // Aplicamos Merma al peso final para el cálculo por 100g
      double pesoFinal = p * (1 - (widget.proyecto.mermaTotal / 100));
      _kcalTotales = pesoFinal > 0 ? (k / pesoFinal) * 100 : 0;
      _protTotales = pesoFinal > 0 ? (pr / pesoFinal) * 100 : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.proyecto.nombre),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {},
          ), // Próximamente
        ],
      ),
      body: Column(
        children: [
          _buildResumenHeader(),
          const Divider(height: 1),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text("Agrega ingredientes desde la biblioteca"),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) =>
                        _buildItemTile(_items[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirSelectorIngredientes,
        label: const Text("AÑADIR INGREDIENTE"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.orange[800],
      ),
    );
  }

  Widget _buildResumenHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueGrey[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statColumn(
            "Energía",
            "${NutriCalculos.formatear(_kcalTotales)} kcal",
          ),
          _statColumn("Proteína", "${NutriCalculos.formatear(_protTotales)}g"),
          _statColumn(
            "Peso Final",
            "${NutriCalculos.formatear(_pesoTotal * (1 - widget.proyecto.mermaTotal / 100))}g",
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    return ListTile(
      title: Text(
        item['nombre'],
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text("${item['cantidad_g']}g de ingrediente"),
      trailing: Text(
        "\$ ${NutriCalculos.formatear((item['precio_por_kg'] / 1000) * item['cantidad_g'])}",
        style: const TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _abrirSelectorIngredientes() async {
    // Aquí implementaremos mañana el buscador rápido que inyecta el ingrediente
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Buscador de biblioteca abriéndose...")),
    );
  }
}
