import 'package:flutter/material.dart';

class VerInsumoPage extends StatelessWidget {
  final Map<String, dynamic> insumo;

  const VerInsumoPage({super.key, required this.insumo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(insumo['nombre']),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ENCABEZADO
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.science, size: 50, color: Colors.green),
                  const SizedBox(height: 10),
                  Text(
                    insumo['nombre'],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Base de cálculo: 100g",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // GRUPO 1: MACROS
            _tituloSeccion("⚡ Energía y Macros"),
            _cardDato(
              "Energía",
              "${insumo['energia_kcal'] ?? 0} kcal",
              Colors.orange,
            ),
            Row(
              children: [
                Expanded(
                  child: _cardDato(
                    "Proteínas",
                    "${insumo['proteina_g'] ?? 0} g",
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _cardDato(
                    "Carbos",
                    "${insumo['carbohidratos_g'] ?? 0} g",
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _cardDato(
                    "Grasas",
                    "${insumo['grasa_total_g'] ?? 0} g",
                    Colors.amber,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // GRUPO 2: DETALLES CRÍTICOS
            _tituloSeccion("⚠️ Grasas y Azúcares (Detalle)"),
            Card(
              child: Column(
                children: [
                  _filaDetalle(
                    "Grasas Saturadas",
                    "${insumo['grasas_sat_g'] ?? 0} g",
                  ),
                  const Divider(),
                  _filaDetalle(
                    "Grasas Trans",
                    "${insumo['grasas_trans_mg'] ?? 0} mg/g",
                  ), // Asumiendo unidad
                  const Divider(),
                  _filaDetalle(
                    "Azúcares Totales",
                    "${insumo['azucares_totales_g'] ?? 0} g",
                  ),
                  const Divider(),
                  _filaDetalle(
                    "Azúcares Añadidos",
                    "${insumo['azucares_anadidos_g'] ?? 0} g",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // GRUPO 3: MICROS
            _tituloSeccion("🔬 Micronutrientes"),
            Card(
              child: Column(
                children: [
                  _filaDetalle("Sodio", "${insumo['sodio_mg'] ?? 0} mg"),
                  const Divider(),
                  _filaDetalle("Calcio", "${insumo['calcio_mg'] ?? 0} mg"),
                  const Divider(),
                  _filaDetalle("Hierro", "${insumo['hierro_mg'] ?? 0} mg"),
                  const Divider(),
                  _filaDetalle("Zinc", "${insumo['zinc_mg'] ?? 0} mg"),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // GRUPO 4: OTROS
            if (insumo['alergenos'] != null &&
                insumo['alergenos'].toString().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.yellow[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "ALÉRGENOS: ${insumo['alergenos']}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tituloSeccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(
        titulo,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _cardDato(String label, String valor, Color color) {
    return Card(
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              valor,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaDetalle(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            valor,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
