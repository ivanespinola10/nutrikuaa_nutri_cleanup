class ProyectoModel {
  final int? id;
  final String nombre;
  final String region; // Mercosur, USA, etc.
  final double mermaTotal; // Factor de pérdida en proceso
  final double porcionSugerida; // Porción de consumo
  final String fecha;

  ProyectoModel({
    this.id,
    required this.nombre,
    this.region = "Mercosur",
    this.mermaTotal = 0.0,
    this.porcionSugerida = 100.0,
    required this.fecha,
  });

  factory ProyectoModel.fromMap(Map<String, dynamic> map) {
    return ProyectoModel(
      id: map['id'],
      nombre: map['nombre'],
      region: map['region'] ?? "Mercosur",
      mermaTotal: (map['merma_total'] ?? 0.0).toDouble(),
      porcionSugerida: (map['porcion_sugerida'] ?? 100.0).toDouble(),
      fecha: map['fecha'] ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'region': region,
      'merma_total': mermaTotal,
      'porcion_sugerida': porcionSugerida,
      'fecha': fecha,
    };
  }
}
