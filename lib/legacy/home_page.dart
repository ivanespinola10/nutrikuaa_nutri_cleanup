import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'ingredients_page.dart';
import 'receta_page.dart';
import 'proyectos_page.dart';
import 'paywall_page.dart';
import 'biblioteca_page.dart';
import '../services/consultor_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final consultor = NutrikuaaConsultant();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _mensajes = [
    {
      'texto': "👋 Hola, soy tu Consultor ISO. ¿En qué te ayudo hoy?",
      'esUsuario': false,
    },
  ];

  bool _pensando = false;
  bool _esUsuarioVip = false;
  int _consultasRealizadas = 0;
  final int _limiteGratis = 3;

  @override
  void initState() {
    super.initState();
    _cargarDatosLocales();
  }

  Future<void> _cargarDatosLocales() async {
    final prefs = await SharedPreferences.getInstance();
    final ultimoDia = prefs.getString('ultimo_dia_uso') ?? "";
    final hoy = DateTime.now().toIso8601String().split('T')[0];

    setState(() {
      _esUsuarioVip = prefs.getBool('es_vip') ?? false;
      if (ultimoDia != hoy) {
        _consultasRealizadas = 0;
        prefs.setString('ultimo_dia_uso', hoy);
        prefs.setInt('consultas_hoy', 0);
      } else {
        _consultasRealizadas = prefs.getInt('consultas_hoy') ?? 0;
      }
    });
  }

  Future<void> _guardarConsumo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('consultas_hoy', _consultasRealizadas);
  }

  void _mostrarAlertaDeVenta() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🚀 Límite Gratuito Alcanzado"),
        content: const Text(
          "Has utilizado tus 3 consultas gratuitas de hoy.\n\n"
          "Para obtener soporte ilimitado y exportación de documentos, "
          "pásate a NutriKuaa PRO.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaywallPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text("VER PLANES"),
          ),
        ],
      ),
    );
  }

  void _enviarMensaje() async {
    if (_textController.text.trim().isEmpty) return;
    if (!_esUsuarioVip && _consultasRealizadas >= _limiteGratis) {
      _mostrarAlertaDeVenta();
      return;
    }

    final pregunta = _textController.text;
    setState(() {
      _mensajes.add({'texto': pregunta, 'esUsuario': true});
      _pensando = true;
      _textController.clear();
      if (!_esUsuarioVip) {
        _consultasRealizadas++;
        _guardarConsumo();
      }
    });

    _scrollAlFondo();

    String? respuesta;
    try {
      respuesta = await consultor.preguntar(pregunta);
    } catch (e) {
      respuesta = "Lo siento, hubo un error de conexión. Intenta de nuevo.";
    }

    if (mounted) {
      setState(() {
        _mensajes.add({
          'texto': respuesta ?? "No pude obtener una respuesta.",
          'esUsuario': false,
        });
        _pensando = false;
      });
      _scrollAlFondo();
    }
  }

  void _scrollAlFondo() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'NutriKuaa Pro',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[800],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_esUsuarioVip)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Text(
                  "${_limiteGratis - _consultasRealizadas} restantes",
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.green[800]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    child: Icon(Icons.person, color: Colors.green, size: 35),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user?.email ?? "Usuario",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.green),
              title: const Text('Inicio'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book, color: Colors.green),
              title: const Text('Biblioteca Técnica'),
              subtitle: const Text('Fuentes oficiales vigentes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BibliotecaPage()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Cerrar Sesión'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted)
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(user),
            const SizedBox(height: 20),
            _buildMenuGrid(context),
            const SizedBox(height: 20),
            _buildProBanner(context),
            const SizedBox(height: 20),
            _buildChatSection(context),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES RECONSTRUIDOS ---

  Widget _buildHeader(User? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[800],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 35, color: Colors.green),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Hola,",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                Text(
                  user?.email ?? "Usuario",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _menuItem(
            context,
            "Nueva Fórmula",
            "Calculadora",
            Icons.science,
            Colors.indigo,
            const RecetaPage(),
          ),
          const SizedBox(height: 15),
          _menuItem(
            context,
            "Mis Proyectos",
            "Historial",
            Icons.folder_shared,
            Colors.orange[800]!,
            const ProyectosPage(),
          ),
          const SizedBox(height: 15),
          _menuItem(
            context,
            "Base de Datos",
            "Ingredientes",
            Icons.storage,
            Colors.teal,
            const IngredientsPage(esSeleccion: false),
          ),
        ],
      ),
    );
  }

  Widget _buildProBanner(BuildContext context) {
    if (_esUsuarioVip) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified, color: Colors.green, size: 40),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Modo PRO Activo",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "Tienes acceso ilimitado.",
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade700, Colors.purple.shade400],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Pásate a PRO",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "Exportación ilimitada y soporte.",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaywallPage()),
            ).then((_) => _cargarDatosLocales()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.purple,
            ),
            child: const Text("VER"),
          ),
        ],
      ),
    );
  }

  Widget _buildChatSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "💬 Consultor Virtual (Beta)",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            height: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.green.shade200),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 5),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(15),
                    itemCount: _mensajes.length,
                    itemBuilder: (context, index) {
                      final msg = _mensajes[index];
                      return Align(
                        alignment: msg['esUsuario']
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: msg['esUsuario']
                                ? Colors.green[100]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          child: Text(msg['texto']),
                        ),
                      );
                    },
                  ),
                ),
                if (_pensando)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Escribiendo...",
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                _buildChatInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: "Pregunta sobre ISO...",
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _enviarMensaje(),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.send,
              color: _pensando ? Colors.grey : Colors.green[800],
            ),
            onPressed: _pensando ? null : _enviarMensaje,
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Widget page,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
