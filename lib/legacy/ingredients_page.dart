import 'package:flutter/material.dart';
import '../data/database/database_helper.dart';
import 'nuevo_insumo_page.dart';
import 'ver_insumo_page.dart'; // Asegúrate de tener este archivo creado

class IngredientsPage extends StatefulWidget {
  // Variable para saber si venimos a SELECCIONAR (true) o a VER (false)
  final bool esSeleccion;

  // Por defecto es 'false' (Modo Ver)
  const IngredientsPage({super.key, this.esSeleccion = false});

  @override
  State<IngredientsPage> createState() => _IngredientsPageState();
}

class _IngredientsPageState extends State<IngredientsPage> {
  List<Map<String, dynamic>> _ingredientes = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  void _cargarDatos() async {
    // Verificamos si está montado antes de iniciar (buena práctica)
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Simulamos la espera de la base de datos
    await DatabaseHelper.instance.importarCSV();
    final datos = await DatabaseHelper.instance.buscarIngredientes("");

    // --- AQUÍ ESTÁ LA CORRECCIÓN MÁGICA ---
    // Si el usuario cerró la pantalla mientras cargaba, "mounted" será false.
    // Si es false, detenemos todo con un return para evitar el error.
    if (!mounted) return;
    // -------------------------------------

    setState(() {
      _ingredientes = datos;
      _isLoading = false;
    });
  }

  void _buscar(String texto) async {
    final resultados = await DatabaseHelper.instance.buscarIngredientes(texto);

    // También protegemos la búsqueda
    if (!mounted) return;

    setState(() => _ingredientes = resultados);
  }

  void _crearNuevoInsumo() async {
    bool? guardado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NuevoInsumoPage()),
    );
    // Si guardó algo, recargamos la lista
    if (guardado == true) {
      _cargarDatos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.esSeleccion ? 'Seleccionar para Receta' : 'Base de Datos',
        ),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar (ej. Harina, Suero)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _buscar,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _ingredientes.length,
                    itemBuilder: (context, index) {
                      final item = _ingredientes[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: widget.esSeleccion
                              ? Colors.indigo
                              : Colors.green,
                          child: Text(
                            item['nombre'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          item['nombre'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Kcal: ${item['energia_kcal'] ?? '-'} | Prot: ${item['proteina_g'] ?? '-'}g",
                        ),

                        onTap: () {
                          if (widget.esSeleccion) {
                            // MODO RECETA: Devuelve el ingrediente
                            Navigator.pop(context, item);
                          } else {
                            // MODO CONSULTA: Abre la ficha técnica
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    VerInsumoPage(insumo: item),
                              ),
                            );
                          }
                        },

                        trailing: widget.esSeleccion
                            ? IconButton(
                                icon: const Icon(
                                  Icons.info_outline,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          VerInsumoPage(insumo: item),
                                    ),
                                  );
                                },
                              )
                            : const Icon(Icons.chevron_right),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearNuevoInsumo,
        label: const Text("Nuevo Insumo"),
        icon: const Icon(Icons.add_circle),
        backgroundColor: Colors.green[800],
      ),
    );
  }
}
