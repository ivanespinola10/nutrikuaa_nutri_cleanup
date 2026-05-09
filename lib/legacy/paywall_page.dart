import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/purchase_service.dart'; // Asegúrate de que la ruta sea correcta

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  // --- ⚠️ INTERRUPTOR DE DESARROLLO ⚠️ ---
  // TRUE = Simula la compra (para desarrollar sin cuenta de Google).
  // FALSE = Usa RevenueCat y Google Play (para producción).
  final bool _modoSimulacion = true;

  List<Package> _paquetes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!_modoSimulacion) {
      _cargarPreciosReales();
    }
  }

  // Carga productos reales de Google Play
  void _cargarPreciosReales() async {
    setState(() => _isLoading = true);
    final offerings = await PurchaseService().getOfferings();
    if (mounted) {
      setState(() {
        _paquetes = offerings;
        _isLoading = false;
      });
    }
  }

  // Lógica de compra (Decide si es real o simulada)
  void _procesarCompra({Package? package}) async {
    setState(() => _isLoading = true);

    bool exito = false;

    if (_modoSimulacion) {
      // --- MODO SIMULACIÓN ---
      await Future.delayed(const Duration(seconds: 2)); // Fingir espera
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('es_vip', true);
      exito = true;
    } else {
      // --- MODO REAL ---
      if (package != null) {
        exito = await PurchaseService().purchasePackage(package);
      }
    }

    setState(() => _isLoading = false);

    if (exito && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🎉 ¡Bienvenido a NutriKuaa PRO!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Volvemos con éxito
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "NutriKuaa Enterprise",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              "Desbloquea el Potencial",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Herramientas avanzadas para ingeniería alimentaria.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 30),

            _beneficio("Fórmulas Ilimitadas"),
            _beneficio("PDFs Profesionales con Logo"),
            _beneficio("Base de Datos y Precios"),
            _beneficio("Soporte Técnico Prioritario"),

            const SizedBox(height: 40),

            // --- SECCIÓN DE BOTONES DE COMPRA ---
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_modoSimulacion)
              // BOTÓN DE PRUEBA (SOLO PARA TI)
              _botonCompraSimulada()
            else if (_paquetes.isEmpty)
              // SI NO HAY PRODUCTOS (Cuenta mal configurada o sin internet)
              _avisoSinProductos()
            else
              // PRODUCTOS REALES DE LA TIENDA
              ..._paquetes.map((p) => _botonProductoReal(p)),

            const SizedBox(height: 20),
            if (!_modoSimulacion)
              TextButton(
                onPressed: () async {
                  await PurchaseService().restorePurchases();
                  if (PurchaseService().isPro && mounted)
                    Navigator.pop(context, true);
                },
                child: const Text(
                  "Restaurar Compras",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _botonCompraSimulada() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.amber[100],
          child: const Text(
            "MODO PRUEBA ACTIVADO (Gratis)",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => _procesarCompra(),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text(
            "SIMULAR SUSCRIPCIÓN PRO",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _botonProductoReal(Package package) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: ElevatedButton(
        onPressed: () => _procesarCompra(package: package),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(20),
          backgroundColor: Colors.green[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              package.storeProduct.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            Text(
              package.storeProduct.priceString,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avisoSinProductos() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        children: const [
          Icon(Icons.warning_amber, color: Colors.orange, size: 40),
          SizedBox(height: 10),
          Text(
            "NO DISPONIBLE",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          SizedBox(height: 5),
          Text(
            "No se encontraron productos en Google Play. Verifica tu configuración.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _beneficio(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 15),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
