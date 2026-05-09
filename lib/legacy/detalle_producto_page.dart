import 'package:flutter/material.dart';
import '../data/database/database_helper.dart';
import 'pdf_service.dart';
import '../core/calculos_nutricionales.dart'; // Importamos la nueva lógica

class DetalleProductoPage extends StatefulWidget {
  final Map<String, dynamic> producto;
  const DetalleProductoPage({super.key, required this.producto});

  @override
  State<DetalleProductoPage> createState() => _DetalleProductoPageState();
}

class _DetalleProductoPageState extends State<DetalleProductoPage> {
  // Controladores agrupados por categoría para orden mental
  late TextEditingController _nombreCtrl, _ingredientesCtrl;
  late TextEditingController _kcalCtrl, _protCtrl, _carboCtrl, _grasaCtrl;
  late TextEditingController _sodioCtrl, _azucarAddCtrl, _grasasSatCtrl;

  List<String> _alergenosSeleccionados = [];
  List<String> _sellosActivos = [];

  final List<String> _listaAlergenosOficial = [
    "Trigo (Gluten)",
    "Avena",
    "Cebada",
    "Centeno",
    "Crustáceos",
    "Huevos",
    "Pescado",
    "Maní",
    "Soja",
    "Leche",
    "Frutos de Cáscara",
    "Apio",
    "Mostaza",
    "Sésamo",
    "Sulfitos",
    "Altramuces",
    "NINGUNO",
  ];

  @override
  void initState() {
    super.initState();
    _inicializarControladores();
    _cargarAlergenos();
    _ejecutarAnalisis();
  }

  void _inicializarControladores() {
    final p = widget.producto;
    _nombreCtrl = TextEditingController(text: p['nombre']);
    _ingredientesCtrl = TextEditingController(
      text: p['ingredientes_lista'] ?? "",
    );
    _kcalCtrl = TextEditingController(
      text: (p['energia_kcal'] ?? 0).toString(),
    );
    _protCtrl = TextEditingController(text: (p['proteina_g'] ?? 0).toString());
    _carboCtrl = TextEditingController(
      text: (p['carbohidratos_g'] ?? 0).toString(),
    );
    _grasaCtrl = TextEditingController(
      text: (p['grasa_total_g'] ?? 0).toString(),
    );
    _sodioCtrl = TextEditingController(text: (p['sodio_mg'] ?? 0).toString());
    _azucarAddCtrl = TextEditingController(
      text: (p['azucares_anadidos_g'] ?? 0).toString(),
    );
    _grasasSatCtrl = TextEditingController(
      text: (p['grasas_sat_g'] ?? 0).toString(),
    );
  }

  // --- LÓGICA DE ACTUALIZACIÓN ---

  void _ejecutarAnalisis() {
    setState(() {
      _sellosActivos = NutriCalculos.evaluarSellos(
        kcal: NutriCalculos.parse(_kcalCtrl.text),
        azucaresAnadidos: NutriCalculos.parse(_azucarAddCtrl.text),
        grasasSat: NutriCalculos.parse(_grasasSatCtrl.text),
        sodio: NutriCalculos.parse(_sodioCtrl.text),
      );
    });
  }

  void _onMacronutrienteChanged() {
    final nuevaKcal = NutriCalculos.calcularKcal(
      proteinas: NutriCalculos.parse(_protCtrl.text),
      carbohidratos: NutriCalculos.parse(_carboCtrl.text),
      grasas: NutriCalculos.parse(_grasaCtrl.text),
    );
    _kcalCtrl.text = nuevaKcal.toStringAsFixed(1);
    _ejecutarAnalisis();
  }

  // --- PERSISTENCIA Y UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editor de Ficha 📝"),
        backgroundColor: Colors.orange[800],
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _guardarCambios),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSeccionSellos(),
            const SizedBox(height: 20),
            _buildInput(_nombreCtrl, "Nombre del Producto", Icons.abc),
            const SizedBox(height: 10),
            _buildInput(
              _ingredientesCtrl,
              "Ingredientes",
              Icons.list,
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            _buildAlergenosCard(),
            const SizedBox(height: 20),
            _buildGridMacros(),
            const SizedBox(height: 20),
            _buildFormularioCritico(),
            const SizedBox(height: 30),
            _buildBotonGuardar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionSellos() {
    if (_sellosActivos.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black12),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: _sellosActivos.map((t) => _widgetOctogono(t)).toList(),
      ),
    );
  }

  Widget _widgetOctogono(String texto) {
    return Container(
      width: 90,
      height: 90,
      alignment: Alignment.center,
      decoration: const ShapeDecoration(
        color: Colors.black,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildGridMacros() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInput(
                _kcalCtrl,
                "Kcal Totales",
                Icons.bolt,
                isNum: true,
                onChange: _ejecutarAnalisis,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildInput(
                _protCtrl,
                "Proteína (g)",
                Icons.fitness_center,
                isNum: true,
                onChange: _onMacronutrienteChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildInput(
                _carboCtrl,
                "Carbs (g)",
                Icons.bakery_dining,
                isNum: true,
                onChange: _onMacronutrienteChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildInput(
                _grasaCtrl,
                "Grasa Total (g)",
                Icons.opacity,
                isNum: true,
                onChange: _onMacronutrienteChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormularioCritico() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          const Text(
            "⚡ NUTRIENTES CRÍTICOS (SISTEMA DE SELLOS)",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 15),
          _buildInput(
            _azucarAddCtrl,
            "Azúcares Añadidos (g)",
            Icons.warning,
            isNum: true,
            onChange: _ejecutarAnalisis,
          ),
          const SizedBox(height: 10),
          _buildInput(
            _grasasSatCtrl,
            "Grasas Saturadas (g)",
            Icons.warning,
            isNum: true,
            onChange: _ejecutarAnalisis,
          ),
          const SizedBox(height: 10),
          _buildInput(
            _sodioCtrl,
            "Sodio (mg)",
            Icons.warning,
            isNum: true,
            onChange: _ejecutarAnalisis,
          ),
        ],
      ),
    );
  }

  // --- COMPONENTES REUTILIZABLES ---

  Widget _buildInput(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isNum = false,
    int maxLines = 1,
    VoidCallback? onChange,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: isNum
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (_) => onChange?.call(),
    );
  }

  // ... (Mantén _buildAlergenosCard, _abrirSelectorAlergenos y _guardarCambios con la misma lógica de negocio que tenías, pero usando NutriCalculos.parse para limpiar datos)

  void _cargarAlergenos() {
    String raw = widget.producto['alergenos'] ?? "";
    if (raw.isNotEmpty) {
      _alergenosSeleccionados = raw.split(', ').map((e) => e.trim()).toList();
    }
  }

  void _guardarCambios() async {
    // Implementación de guardado similar a la anterior pero más limpia
    List<String> tempAlergenos = List.from(_alergenosSeleccionados);
    if (tempAlergenos.length > 1) tempAlergenos.remove("NINGUNO");

    Map<String, dynamic> data = {
      'id': widget.producto['id'],
      'nombre': _nombreCtrl.text,
      'energia_kcal': NutriCalculos.parse(_kcalCtrl.text),
      'grasas_sat_g': NutriCalculos.parse(_grasasSatCtrl.text),
      'azucares_anadidos_g': NutriCalculos.parse(_azucarAddCtrl.text),
      'sodio_mg': NutriCalculos.parse(_sodioCtrl.text),
      'alergenos': tempAlergenos.join(', '),
      'es_receta_propia': 1,
    };

    await DatabaseHelper.instance.actualizarProducto(data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Ficha Técnica y Sellos actualizados")),
      );
    }
  }

  Widget _buildBotonGuardar() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.cloud_upload),
      label: const Text("GUARDAR EN MIS PROYECTOS"),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 55),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _guardarCambios,
    );
  }

  Widget _buildAlergenosCard() {
    // (Tu widget de alérgenos actual, se mantiene igual pero puedes mejorar el estilo aquí)
    return Card(
      color: Colors.orange[50],
      child: ListTile(
        title: const Text(
          "🛡️ Gestión de Alérgenos",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _alergenosSeleccionados.isEmpty
              ? "NINGUNO"
              : _alergenosSeleccionados.join(', '),
        ),
        trailing: const Icon(Icons.edit),
        onTap: _abrirSelectorAlergenos,
      ),
    );
  }

  // ... (Aquí iría el método _abrirSelectorAlergenos que ya tienes)
  void _abrirSelectorAlergenos() async {
    await showDialog(
      context: context,
      builder: (context) {
        // Creamos una copia temporal para no modificar el estado hasta confirmar
        List<String> temp = List.from(_alergenosSeleccionados);
        return StatefulBuilder(
          builder: (context, setD) {
            return AlertDialog(
              title: const Text("Seleccionar Alérgenos"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView(
                  children: _listaAlergenosOficial.map((a) {
                    return CheckboxListTile(
                      title: Text(a),
                      value: temp.contains(a),
                      onChanged: (v) {
                        setD(() {
                          if (v!) {
                            if (a == "NINGUNO") {
                              temp.clear();
                            } else {
                              temp.remove("NINGUNO");
                            }
                            temp.add(a);
                          } else {
                            temp.remove(a);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _alergenosSeleccionados = temp);
                    Navigator.pop(context);
                  },
                  child: const Text("Confirmar"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
