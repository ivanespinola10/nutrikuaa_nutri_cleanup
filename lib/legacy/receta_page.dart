import 'package:flutter/material.dart';
import 'ingredients_page.dart';
import 'detalle_producto_page.dart';

class RecetaPage extends StatefulWidget {
  const RecetaPage({super.key});

  @override
  State<RecetaPage> createState() => _RecetaPageState();
}

class _RecetaPageState extends State<RecetaPage> {
  // LISTA DE INGREDIENTES EN LA RECETA
  List<Map<String, dynamic>> _ingredientesSeleccionados = [];

  // DATOS TOTALES (Balance)
  double _totalPeso = 0;
  double _totalKcal = 0;
  double _totalProt = 0;
  double _totalCarb = 0;
  double _totalGrasa = 0;
  double _totalSodio = 0; // <--- NUEVO CAMPO

  // Controladores
  final _nombreRecetaController = TextEditingController();

  void _agregarIngrediente() async {
    final ingrediente = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const IngredientsPage(esSeleccion: true),
      ),
    );

    if (ingrediente != null) {
      _mostrarDialogoPeso(ingrediente);
    }
  }

  void _mostrarDialogoPeso(Map<String, dynamic> item) {
    final pesoController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Peso para ${item['nombre']}"),
        content: TextField(
          controller: pesoController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Gramos (g)",
            suffixText: "g",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              double? peso = double.tryParse(pesoController.text);
              if (peso != null && peso > 0) {
                setState(() {
                  Map<String, dynamic> nuevoItem = Map.from(item);
                  nuevoItem['peso_usado'] = peso;
                  _ingredientesSeleccionados.add(nuevoItem);
                  _calcularTotales();
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Agregar"),
          ),
        ],
      ),
    );
  }

  void _calcularTotales() {
    double p = 0, k = 0, pr = 0, c = 0, g = 0, s = 0;

    for (var item in _ingredientesSeleccionados) {
      double peso = item['peso_usado'];
      p += peso;
      // Regla de tres simple: (Valor / 100) * Peso
      k += (item['energia_kcal'] ?? 0) * (peso / 100);
      pr += (item['proteina_g'] ?? 0) * (peso / 100);
      c += (item['carbohidratos_g'] ?? 0) * (peso / 100);
      g += (item['grasa_total_g'] ?? 0) * (peso / 100);
      s += (item['sodio_mg'] ?? 0) * (peso / 100); // <--- SUMAMOS EL SODIO
    }

    setState(() {
      _totalPeso = p;
      _totalKcal = k;
      _totalProt = pr;
      _totalCarb = c;
      _totalGrasa = g;
      _totalSodio = s;
    });
  }

  void _finalizarReceta() {
    if (_ingredientesSeleccionados.isEmpty) return;
    if (_nombreRecetaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ponle un nombre a la fórmula")),
      );
      return;
    }

    // Preparamos el objeto final (Base 100g para la ficha)
    double factor = _totalPeso > 0 ? (100 / _totalPeso) : 0;

    Map<String, dynamic> productoFinal = {
      'id': DateTime.now().millisecondsSinceEpoch, // ID temporal
      'nombre': _nombreRecetaController.text,
      'energia_kcal': _totalKcal * factor,
      'proteina_g': _totalProt * factor,
      'carbohidratos_g': _totalCarb * factor,
      'grasa_total_g': _totalGrasa * factor,
      'sodio_mg': _totalSodio * factor, // <--- GUARDAMOS SODIO
      'ingredientes_lista': _generarListaIngredientesTexto(),
      'alergenos': _detectarAlergenos(),
      'es_receta': true,
    };

    // Vamos a la pantalla de detalle/pdf
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleProductoPage(producto: productoFinal),
      ),
    );
  }

  String _generarListaIngredientesTexto() {
    // Ordenamos de mayor a menor peso
    _ingredientesSeleccionados.sort(
      (a, b) => b['peso_usado'].compareTo(a['peso_usado']),
    );
    return _ingredientesSeleccionados.map((e) => e['nombre']).join(", ") + ".";
  }

  String _detectarAlergenos() {
    Set<String> alergenos = {};
    for (var item in _ingredientesSeleccionados) {
      if (item['alergenos'] != null &&
          item['alergenos'].toString().isNotEmpty) {
        alergenos.add(item['alergenos']);
      }
    }
    return alergenos.isEmpty ? "Ninguno" : alergenos.join(", ");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nueva Fórmula"),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          // --- TARJETA DE RESUMEN (Modificada con Sodio) ---
          Container(
            color: Colors.indigo[50],
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                TextField(
                  controller: _nombreRecetaController,
                  decoration: const InputDecoration(
                    labelText: "Nombre del Producto (Ej. Pan Integral)",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _datoResumen("Peso", "${_totalPeso.toStringAsFixed(0)} g"),
                    _datoResumen("Kcal", _totalKcal.toStringAsFixed(0)),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _datoResumen("Carb", "${_totalCarb.toStringAsFixed(1)}"),
                    _datoResumen("Prot", "${_totalProt.toStringAsFixed(1)}"),
                    _datoResumen("Grasa", "${_totalGrasa.toStringAsFixed(1)}"),
                    // --- AQUÍ EL NUEVO DATO ---
                    _datoResumen(
                      "Sodio",
                      "${_totalSodio.toStringAsFixed(0)}",
                      esAlerta: true,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // LISTA DE INGREDIENTES
          Expanded(
            child: ListView.builder(
              itemCount: _ingredientesSeleccionados.length,
              itemBuilder: (context, index) {
                final item = _ingredientesSeleccionados[index];
                return ListTile(
                  title: Text(item['nombre']),
                  subtitle: Text("${item['peso_usado']} g"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _ingredientesSeleccionados.removeAt(index);
                        _calcularTotales();
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "btn1",
            onPressed: _agregarIngrediente,
            child: const Icon(Icons.add),
            backgroundColor: Colors.indigo,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "btn2",
            onPressed: _finalizarReceta,
            label: const Text("Finalizar"),
            icon: const Icon(Icons.check),
            backgroundColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _datoResumen(String label, String valor, {bool esAlerta = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: esAlerta ? Colors.red[800] : Colors.indigo,
          ),
        ),
        if (esAlerta)
          const Text("mg", style: TextStyle(fontSize: 8, color: Colors.red)),
      ],
    );
  }
}
