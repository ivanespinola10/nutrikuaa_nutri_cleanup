import 'package:flutter/material.dart';
import '../../data/database/database_helper.dart';
import '../../models/insumo_model.dart';
import '../../core/calculos_nutricionales.dart';
import 'nuevo_insumo_screen.dart';

class InsumosScreen extends StatefulWidget {
  const InsumosScreen({super.key});

  @override
  State<InsumosScreen> createState() => _InsumosScreenState();
}

class _InsumosScreenState extends State<InsumosScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<InsumoModel> _resultados = [];
  List<String> _listaPaises = [];
  String _filtroPais = "Todos";
  bool _soloPropios = false;

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  // Carga inicial dinámica de filtros y resultados
  Future<void> _inicializarDatos() async {
    final paises = await DatabaseHelper.instance.getPaisesExistentes();
    setState(() => _listaPaises = paises);
    _ejecutarBusqueda();
  }

  Future<void> _ejecutarBusqueda() async {
    final res = await DatabaseHelper.instance.buscarInsumosPro(
      query: _searchCtrl.text,
      paisFiltro: _filtroPais,
      soloPropios: _soloPropios,
    );
    setState(() => _resultados = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Biblioteca Técnica 🔬"),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(115),
          child: _buildHeaderFiltros(),
        ),
      ),
      body: _resultados.isEmpty
          ? const Center(
              child: Text("Sin datos. Verifique la base de datos o filtros."),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _resultados.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) =>
                  _buildInsumoTile(_resultados[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ok = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NuevoInsumoScreen()),
          );
          if (ok == true) _inicializarDatos();
        },
        backgroundColor: Colors.orange[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeaderFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Buscar alimento o ingrediente...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (_) => _ejecutarBusqueda(),
            ),
          ),
          const SizedBox(height: 10),
          // SCROLL HORIZONTAL DE FILTROS
          SizedBox(
            height: 45,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Chips de países dinámicos
                ..._listaPaises.map(
                  (pais) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(pais),
                      selected: _filtroPais == pais,
                      onSelected: (selected) {
                        setState(() => _filtroPais = selected ? pais : "Todos");
                        _ejecutarBusqueda();
                      },
                    ),
                  ),
                ),
                const VerticalDivider(),
                FilterChip(
                  label: const Text("💎 Mis Insumos"),
                  selected: _soloPropios,
                  onSelected: (v) {
                    setState(() => _soloPropios = v);
                    _ejecutarBusqueda();
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: const Text("Limpiar"),
                  onPressed: () {
                    setState(() {
                      _filtroPais = "Todos";
                      _soloPropios = false;
                      _searchCtrl.clear();
                    });
                    _ejecutarBusqueda();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsumoTile(InsumoModel insumo) {
    return ListTile(
      title: Text(
        insumo.nombre,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text("${insumo.alimento} | ${insumo.pais}"),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            "${NutriCalculos.formatear(insumo.calorias)} kcal",
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "${NutriCalculos.formatear(insumo.proteinas)}g Prot",
            style: const TextStyle(color: Colors.blue, fontSize: 12),
          ),
          Text(
            "\$ ${NutriCalculos.formatear(insumo.precioPorKg)}/kg",
            style: const TextStyle(color: Colors.green, fontSize: 12),
          ),
        ],
      ),
      onTap: () async {
        final ok = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NuevoInsumoScreen(insumoParaEditar: insumo),
          ),
        );
        if (ok == true) _ejecutarBusqueda();
      },
    );
  }
}
