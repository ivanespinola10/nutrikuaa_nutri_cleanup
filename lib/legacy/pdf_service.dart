import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generarPDF(Map<String, dynamic> datos) async {
    final pdf = pw.Document();

    // 1. CARGAMOS EL LOGO
    final imageBytes = await rootBundle.load('assets/logo.png');
    final logoImage = pw.MemoryImage(imageBytes.buffer.asUint8List());

    // 2. PROCESAMIENTO DE ALÉRGENOS (Lógica para evitar "NINGUNO, SULFITOS")
    // Tomamos el string, lo limpiamos y filtramos
    String rawAlergenos = datos['alergenos']?.toString() ?? "NINGUNO";
    List<String> listaAlergenos = rawAlergenos
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();

    // Si hay más de un elemento (ej: "NINGUNO" y "SULFITOS"), quitamos el "NINGUNO"
    if (listaAlergenos.length > 1) {
      listaAlergenos.removeWhere(
        (item) => item == "NINGUNO" || item == "NINGUNA",
      );
    }

    // Texto final procesado para el PDF
    String textoAlergenosFinal = listaAlergenos.join(", ");

    // 3. RECUPERAMOS EL CÁLCULO DE SELLOS
    List<String> sellosIdentificados = _calcularSellos(datos);

    // Estilos
    final estiloTitulo = pw.TextStyle(
      fontSize: 24,
      fontWeight: pw.FontWeight.bold,
    );
    final estiloSubtitulo = pw.TextStyle(
      fontSize: 16,
      color: PdfColors.grey700,
    );
    final estiloNegrita = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: 10,
    );

    // Variables numéricas
    double cal = (datos['energia_kcal'] ?? 0).toDouble();
    double prot = (datos['proteina_g'] ?? 0).toDouble();
    double carb = (datos['carbohidratos_g'] ?? 0).toDouble();
    double gras = (datos['grasa_total_g'] ?? 0).toDouble();
    double sod = (datos['sodio_mg'] ?? 0).toDouble();
    double azucar = (datos['azucares_totales_g'] ?? 0).toDouble();
    double fibra = (datos['fibra_g'] ?? 0).toDouble();

    // VDs (Valores Diarios base 2000 kcal)
    const double vdCal = 2000;
    const double vdProt = 75;
    const double vdCarb = 300;
    const double vdGras = 55;
    const double vdSod = 2400;
    const double vdFibra = 25;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- ENCABEZADO CON LOGO ---
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 50,
                          height: 50,
                          child: pw.Image(logoImage),
                        ),
                        pw.SizedBox(width: 15),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              "NutriKuaa Pro",
                              style: pw.TextStyle(
                                fontSize: 18,
                                color: PdfColors.green800,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              "Ficha Técnica & Rotulado",
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Text(
                      "Versión: 1.0\nFecha: ${DateTime.now().toString().substring(0, 10)}",
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 15),

              // DATOS PRINCIPALES
              pw.Text(datos['nombre'] ?? "Sin Nombre", style: estiloTitulo),
              pw.Text(
                "ID Producto: ${datos['id'] ?? 'N/A'}",
                style: estiloSubtitulo,
              ),
              pw.SizedBox(height: 15),

              // --- ZONA DE SELLOS ---
              if (sellosIdentificados.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "ADVERTENCIAS FRONTALES SUGERIDAS:",
                        style: estiloNegrita,
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        children: sellosIdentificados
                            .map(
                              (t) => pw.Container(
                                margin: const pw.EdgeInsets.only(right: 10),
                                width: 60,
                                height: 60,
                                alignment: pw.Alignment.center,
                                decoration: const pw.BoxDecoration(
                                  color: PdfColors.black,
                                  shape: pw.BoxShape.circle,
                                ),
                                child: pw.Text(
                                  t,
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 6,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                )
              else
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  color: PdfColors.green50,
                  child: pw.Text(
                    "✅ Producto conforme (Libre de sellos)",
                    style: pw.TextStyle(
                      color: PdfColors.green800,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

              pw.SizedBox(height: 20),

              // TABLA NUTRICIONAL
              pw.Text("INFORMACIÓN NUTRICIONAL", style: estiloNegrita),
              pw.Container(
                width: 400,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black),
                ),
                child: pw.Column(
                  children: [
                    pw.Container(
                      color: PdfColors.grey200,
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Nutriente", style: estiloNegrita),
                          pw.Text("Por 100g", style: estiloNegrita),
                          pw.Text("%VD*", style: estiloNegrita),
                        ],
                      ),
                    ),
                    _fila(
                      "Valor Energético",
                      "${cal.toStringAsFixed(0)} kcal",
                      cal / vdCal * 100,
                    ),
                    _fila(
                      "Carbohidratos",
                      "${carb.toStringAsFixed(1)} g",
                      carb / vdCarb * 100,
                    ),
                    if (azucar > 0)
                      _fila(
                        "  Azúcares Totales",
                        "${azucar.toStringAsFixed(1)} g",
                        0,
                      ),
                    _fila(
                      "Proteínas",
                      "${prot.toStringAsFixed(1)} g",
                      prot / vdProt * 100,
                    ),
                    _fila(
                      "Grasas Totales",
                      "${gras.toStringAsFixed(1)} g",
                      gras / vdGras * 100,
                    ),
                    if (fibra > 0)
                      _fila(
                        "Fibra Alimentaria",
                        "${fibra.toStringAsFixed(1)} g",
                        fibra / vdFibra * 100,
                      ),
                    _fila(
                      "Sodio",
                      "${sod.toStringAsFixed(0)} mg",
                      sod / vdSod * 100,
                    ),
                  ],
                ),
              ),
              pw.Text(
                "* % Valores Diarios con base a una dieta de 2000 kcal.",
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),

              pw.SizedBox(height: 20),

              // --- INGREDIENTES ---
              pw.Text("INGREDIENTES:", style: estiloNegrita),
              pw.Text(
                datos['ingredientes_lista'] ?? "No especificado.",
                style: const pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.justify,
              ),

              pw.SizedBox(height: 10),

              // --- ZONA DE ALÉRGENOS (CRÍTICA CORREGIDA) ---
              // Solo se muestra si el texto final no está vacío y no es "NINGUNO"
              if (textoAlergenosFinal.isNotEmpty &&
                  textoAlergenosFinal != "NINGUNO")
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black),
                    color: PdfColors.yellow100,
                  ),
                  child: pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: "CONTIENE: ", style: estiloNegrita),
                        pw.TextSpan(
                          text: textoAlergenosFinal,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),

              pw.Spacer(),
              pw.Divider(),
              pw.Text(
                "Generado por NutriKuaa Software - Uso Profesional",
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  static pw.Widget _fila(String n, String c, double p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(n, style: const pw.TextStyle(fontSize: 10)),
          pw.Row(
            children: [
              pw.Text(c, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(width: 25),
              pw.Container(
                width: 30,
                alignment: pw.Alignment.centerRight,
                child: p > 0
                    ? pw.Text(
                        "${p.toStringAsFixed(0)}%",
                        style: const pw.TextStyle(fontSize: 10),
                      )
                    : pw.Text("-"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<String> _calcularSellos(Map<String, dynamic> d) {
    List<String> s = [];
    double cal = (d['energia_kcal'] ?? 0).toDouble();
    if (cal <= 0) return [];

    double azucar = (d['azucares_anadidos_g'] ?? d['azucares_totales_g'] ?? 0)
        .toDouble();
    if ((azucar * 4) / cal >= 0.10) s.add("EXCESO EN\nAZÚCARES");

    double grasSat = (d['grasas_sat_g'] ?? 0).toDouble();
    if (grasSat == 0) grasSat = (d['grasa_total_g'] ?? 0).toDouble() * 0.4;
    if ((grasSat * 9) / cal >= 0.10) s.add("EXCESO EN\nGRASAS SAT.");

    double sod = (d['sodio_mg'] ?? 0).toDouble();
    if (sod >= 1 && (sod / cal) >= 1) s.add("EXCESO EN\nSODIO");
    if (sod >= 300) s.add("EXCESO EN\nSODIO");

    return s;
  }
}
