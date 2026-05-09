import 'package:flutter/material.dart';
import '../data/database/database_helper.dart';

class NuevoInsumoPage extends StatefulWidget {
  const NuevoInsumoPage({super.key});

  @override
  State<NuevoInsumoPage> createState() => _NuevoInsumoPageState();
}

class _NuevoInsumoPageState extends State<NuevoInsumoPage> {
  // Controladores Generales
  final _nombreCtrl = TextEditingController();
  final _ingredientesCtrl = TextEditingController();

  // Macronutrientes
  final _kcalCtrl = TextEditingController();
  final _protCtrl = TextEditingController();
  final _carboCtrl = TextEditingController();
  final _grasaCtrl = TextEditingController();
  final _sodioCtrl = TextEditingController();

  // Detalles Críticos (Sellos y Micros)
  final _azucarTotCtrl = TextEditingController();
  final _azucarAddCtrl = TextEditingController();
  final _grasasSatCtrl = TextEditingController();
  final _grasasTransCtrl = TextEditingController();
  final _calcioCtrl = TextEditingController();
  final _hierroCtrl = TextEditingController();
  final _zincCtrl = TextEditingController();

  final List<String> _todosLosAlergenos = [
    'NINGUNO',
    'LECHE',
    'HUEVO',
    'SOJA',
    'TRIGO',
    'MANÍ',
    'FRUTOS SECOS',
    'PESCADO',
    'MARISCOS',
    'SULFITOS',
  ];

  List<String> _alergenosSeleccionados = [];

  // --- LÓGICA DE PERSISTENCIA Y GUARDADO ---
  void _guardarInsumo() async {
    if (_nombreCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ El nombre es obligatorio")),
      );
      return;
    }

    // LÓGICA DE LIMPIEZA DE ALÉRGENOS (Persistencia del "Ninguno")
    List<String> tempAlergenos = List.from(_alergenosSeleccionados);
    if (tempAlergenos.length > 1) {
      tempAlergenos.removeWhere((item) => item.toUpperCase() == 'NINGUNO');
    }

    // Helper para parsear decimales de forma segura (soporta coma y punto)
    double parse(String text) {
      return double.tryParse(text.trim().replaceAll(',', '.')) ?? 0.0;
    }

    // MAPEO EXACTO A LAS COLUMNAS DE TU DATABASE_HELPER
    Map<String, dynamic> nuevoInsumo = {
      'nombre': _nombreCtrl.text,
      'ingredientes_lista': _ingredientesCtrl.text, // Coincide con DB
      'alergenos': tempAlergenos.join(', '),

      'energia_kcal': parse(_kcalCtrl.text),
      'proteina_g': parse(_protCtrl.text),
      'carbohidratos_g': parse(_carboCtrl.text),
      'grasa_total_g': parse(_grasaCtrl.text),
      'sodio_mg': parse(_sodioCtrl.text),

      'azucares_totales_g': parse(_azucarTotCtrl.text),
      'azucares_anadidos_g': parse(_azucarAddCtrl.text),
      'grasas_sat_g': parse(_grasasSatCtrl.text),
      'grasas_trans_mg': parse(_grasasTransCtrl.text),

      'calcio_mg': parse(_calcioCtrl.text),
      'hierro_mg': parse(_hierroCtrl.text),
      'zinc_mg': parse(_zincCtrl.text),

      // Flag para que aparezca en "Mis Proyectos I+D"
      'es_receta_propia': 1,
    };

    await DatabaseHelper.instance.guardarProducto(nuevoInsumo);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Materia Prima guardada en Mis Proyectos"),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _mostrarDialogoAlergenos() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Seleccionar Alérgenos"),
              content: SingleChildScrollView(
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _todosLosAlergenos.map((alergeno) {
                    final isSelected = _alergenosSeleccionados.contains(
                      alergeno,
                    );
                    return FilterChip(
                      label: Text(alergeno),
                      selected: isSelected,
                      selectedColor: Colors.orange[100],
                      onSelected: (bool selected) {
                        setStateDialog(() {
                          if (alergeno == 'NINGUNO') {
                            if (selected)
                              _alergenosSeleccionados = ['NINGUNO'];
                            else
                              _alergenosSeleccionados.remove('NINGUNO');
                          } else {
                            if (selected) {
                              _alergenosSeleccionados.remove('NINGUNO');
                              _alergenosSeleccionados.add(alergeno);
                            } else {
                              _alergenosSeleccionados.remove(alergeno);
                            }
                          }
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Listo"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Alta de Insumo 🧪"),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Datos Generales (Base 100g)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: "Nombre del Insumo",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.science),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ingredientesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Lista de Ingredientes",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.list),
              ),
            ),
            const SizedBox(height: 20),

            // PANEL DE ALÉRGENOS
            _buildAlergenosCard(),

            const SizedBox(height: 20),
            _seccion("Macronutrientes Principales", [
              _campo(_kcalCtrl, "Energía (Kcal)"),
              _campo(_protCtrl, "Proteínas (g)"),
              _campo(_carboCtrl, "Carbohidratos (g)"),
              _campo(_grasaCtrl, "Grasas Totales (g)"),
            ]),

            _seccion("Detalle de Grasas y Azúcares (Sellos)", [
              _campo(_grasasSatCtrl, "Grasas Sat. (g)"),
              _campo(_grasasTransCtrl, "Grasas Trans (mg)"),
              _campo(_azucarTotCtrl, "Azúcares Tot. (g)"),
              _campo(_azucarAddCtrl, "Azúcares Añad. (g)"),
            ]),

            _seccion("Micronutrientes", [
              _campo(_sodioCtrl, "Sodio (mg)"),
              _campo(_calcioCtrl, "Calcio (mg)"),
              _campo(_hierroCtrl, "Hierro (mg)"),
              _campo(_zincCtrl, "Zinc (mg)"),
            ]),

            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("GUARDAR EN BASE DE DATOS"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
              onPressed: _guardarInsumo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlergenosCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "CONTIENE: ${_alergenosSeleccionados.isEmpty ? 'Sin definir' : _alergenosSeleccionados.join(', ')}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("Seleccionar Alérgenos"),
              onPressed: _mostrarDialogoAlergenos,
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccion(String titulo, List<Widget> hijos) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: Colors.green[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(),
          Wrap(spacing: 12, runSpacing: 12, children: hijos),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label) {
    return SizedBox(
      width: 145,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
