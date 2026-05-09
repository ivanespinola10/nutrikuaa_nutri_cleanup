import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BibliotecaPage extends StatelessWidget {
  const BibliotecaPage({super.key});

  final List<OrganismoOficial> organismos = const [
    OrganismoOficial(
      nombre: "INAN",
      region: "Paraguay",
      logo: "🇵🇾",
      url: "https://www.inan.gov.py/site/?page_id=835",
    ),
    OrganismoOficial(
      nombre: "MERCOSUR",
      region: "Regional",
      logo: "🏁",
      url: "https://www.mercosur.int/documentos-y-normativa/normativa/",
    ),
    OrganismoOficial(
      nombre: "CODEX ALIMENTARIUS",
      region: "Global",
      logo: "🌍",
      url: "https://www.fao.org/fao-who-codexalimentarius/home/es/",
    ),
    OrganismoOficial(
      nombre: "FDA",
      region: "USA",
      logo: "🇺🇸",
      url: "https://www.fda.gov/food",
    ),
    OrganismoOficial(
      nombre: "EFSA",
      region: "Europa",
      logo: "🇪🇺",
      url: "https://www.efsa.europa.eu/",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fuentes Oficiales"),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: organismos.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final org = organismos[index];
                return ListTile(
                  leading: Text(org.logo, style: const TextStyle(fontSize: 30)),
                  title: Text(
                    org.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Región: ${org.region}"),
                  trailing: const Icon(
                    Icons.open_in_new,
                    color: Colors.blue,
                    size: 20,
                  ),
                  onTap: () => _abrirEnlace(org.url),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.grey[200],
            child: Text(
              "NutriKuaa Pro recomienda verificar siempre la última versión vigente en el sitio oficial del organismo regulador antes de finalizar cualquier Ficha Técnica o Rotulado Profesional.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirEnlace(String url) async {
    final Uri uri = Uri.parse(url);
    // Usamos el modo externalApplication para que abra el navegador del celular
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("No se pudo abrir $url");
    }
  }
}

// Esta clase DEBE estar aquí o en un archivo aparte para que no dé error
class OrganismoOficial {
  final String nombre, region, logo, url;
  const OrganismoOficial({
    required this.nombre,
    required this.region,
    required this.logo,
    required this.url,
  });
}
