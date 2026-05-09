import 'package:flutter/material.dart';
import '../../data/database/database_helper.dart';
import '../../models/insumo_model.dart';
import '../../core/calculos_nutricionales.dart';

class NuevoInsumoScreen extends StatefulWidget {
  final InsumoModel? insumoParaEditar;
  const NuevoInsumoScreen({super.key, this.insumoParaEditar});

  @override
  State<NuevoInsumoScreen> createState() => _NuevoInsumoScreenState();
}

class _NuevoInsumoScreenState extends State<NuevoInsumoScreen> {
  final Map<String, TextEditingController> _ctrls = {
    'nombre': TextEditingController(),
    'alimento': TextEditingController(),
    'pais': TextEditingController(text: "Paraguay"),
    'precio': TextEditingController(text: "0"),
    'prot': TextEditingController(text: "0"),
    'carbo': TextEditingController(text: "0"),
    'grasa': TextEditingController(text: "0"),
    'kcal': TextEditingController(text: "0"),
    'fibra': TextEditingController(text: "0"),
    'saturados': TextEditingController(text: "0"),
    'sodio': TextEditingController(text: "0"),
    'zinc': TextEditingController(text: "0"),
    'hierro': TextEditingController(text: "0"),
    'calcio': TextEditingController(text: "0"),
    'colesterol': TextEditingController(text: "0"),
    'retinol': TextEditingController(text: "0"),
    'azucares': TextEditingController(text: "0"),
  };

  @override
  void initState() {
    super.initState();
    if (widget.insumoParaEditar != null) _cargarDatos();
  }

  void _cargarDatos() {
    final i = widget.insumoParaEditar!;
    _ctrls['nombre']!.text = i.nombre;
    _ctrls['alimento']!.text = i.alimento;
    _ctrls['pais']!.text = i.pais;
    _ctrls['precio']!.text = i.precioPorKg.toString();
    _ctrls['prot']!.text = i.proteinas.toString();
    _ctrls['carbo']!.text = i.hidratos.toString();
    _ctrls['grasa']!.text = i.lipidos.toString();
    _ctrls['kcal']!.text = i.calorias.toString();
    _ctrls['fibra']!.text = i.fibra.toString();
    _ctrls['saturados']!.text = i.saturados.toString();
    _ctrls['sodio']!.text = i.sodio.toString();
    _ctrls['zinc']!.text = i.zinc.toString();
    _ctrls['hierro']!.text = i.hierro.toString();
    _ctrls['calcio']!.text = i.calcio.toString();
    _ctrls['colesterol']!.text = i.colesterol.toString();
    _ctrls['retinol']!.text = i.retinol.toString();
    _ctrls['azucares']!.text = i.azucaresAnadidos.toString();
  }

  void _autoCalcular() {
    final p = NutriCalculos.parse(_ctrls['prot']!.text);
    final c = NutriCalculos.parse(_ctrls['carbo']!.text);
    final g = NutriCalculos.parse(_ctrls['grasa']!.text);
    setState(() {
      _ctrls['kcal']!.text = NutriCalculos.formatear(
        NutriCalculos.calcularKcal(p: p, c: c, g: g),
      );
    });
  }

  void _guardar() async {
    final nuevo = InsumoModel(
      id: widget.insumoParaEditar?.id,
      nombre: _ctrls['nombre']!.text,
      alimento: _ctrls['alimento']!.text,
      pais: _ctrls['pais']!.text,
      precioPorKg: NutriCalculos.parse(_ctrls['precio']!.text),
      proteinas: NutriCalculos.parse(_ctrls['prot']!.text),
      hidratos: NutriCalculos.parse(_ctrls['carbo']!.text),
      fibra: NutriCalculos.parse(_ctrls['fibra']!.text),
      lipidos: NutriCalculos.parse(_ctrls['grasa']!.text),
      saturados: NutriCalculos.parse(_ctrls['saturados']!.text),
      sodio: NutriCalculos.parse(_ctrls['sodio']!.text),
      zinc: NutriCalculos.parse(_ctrls['zinc']!.text),
      hierro: NutriCalculos.parse(_ctrls['hierro']!.text),
      calcio: NutriCalculos.parse(_ctrls['calcio']!.text),
      colesterol: NutriCalculos.parse(_ctrls['colesterol']!.text),
      retinol: NutriCalculos.parse(_ctrls['retinol']!.text),
      azucaresAnadidos: NutriCalculos.parse(_ctrls['azucares']!.text),
      calorias: NutriCalculos.parse(_ctrls['kcal']!.text),
      esPropio: 1,
    );

    if (widget.insumoParaEditar == null) {
      await DatabaseHelper.instance.insertarInsumo(nuevo);
    } else {
      await DatabaseHelper.instance.actualizarInsumo(nuevo);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.insumoParaEditar == null
              ? "Nuevo Insumo 🔬"
              : "Editar Insumo ✏️",
        ),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader("Datos Mandatorios (KPIs)"),
          _buildInput(_ctrls['nombre']!, "Nombre Comercial"),
          _buildInput(_ctrls['alimento']!, "Categoría Industrial"),
          _buildInput(_ctrls['pais']!, "País de Origen"),
          _buildInput(_ctrls['precio']!, "Precio por Kg/L (MBA)", isNum: true),
          const Divider(),
          _sectionHeader("Macros y Energía"),
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  _ctrls['prot']!,
                  "Prot (g)",
                  isNum: true,
                  onChange: _autoCalcular,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInput(
                  _ctrls['carbo']!,
                  "Carbs (g)",
                  isNum: true,
                  onChange: _autoCalcular,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  _ctrls['grasa']!,
                  "Grasa (g)",
                  isNum: true,
                  onChange: _autoCalcular,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInput(
                  _ctrls['kcal']!,
                  "Kcal (Auto)",
                  isNum: true,
                  readOnly: true,
                ),
              ),
            ],
          ),
          _buildInput(_ctrls['sodio']!, "Sodio (mg)", isNum: true),

          const SizedBox(height: 10),
          ExpansionTile(
            title: const Text(
              "Micronutrientes e Información Adicional",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            children: [
              _buildInput(
                _ctrls['fibra']!,
                "Fibra Alimentaria (g)",
                isNum: true,
              ),
              _buildInput(
                _ctrls['saturados']!,
                "Grasas Saturadas (g)",
                isNum: true,
              ),
              _buildInput(
                _ctrls['azucares']!,
                "Azúcares Añadidos (g)",
                isNum: true,
              ),
              _buildInput(
                _ctrls['colesterol']!,
                "Colesterol (mg)",
                isNum: true,
              ),
              _buildInput(_ctrls['hierro']!, "Hierro (mg)", isNum: true),
              _buildInput(_ctrls['zinc']!, "Zinc (mg)", isNum: true),
              _buildInput(_ctrls['calcio']!, "Calcio (mg)", isNum: true),
              _buildInput(_ctrls['retinol']!, "Retinol (mcg)", isNum: true),
            ],
          ),

          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _guardar,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.orange[900],
            ),
            child: const Text(
              "GUARDAR EN BIBLIOTECA",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.green[800],
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String label, {
    bool isNum = false,
    VoidCallback? onChange,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        readOnly: readOnly,
        keyboardType: isNum
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: readOnly,
          fillColor: readOnly ? Colors.grey[200] : null,
        ),
        onChanged: (_) => onChange?.call(),
      ),
    );
  }
}
