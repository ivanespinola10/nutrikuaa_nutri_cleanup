class InsumoModel {
  final int? id;
  final String nombre, alimento, pais;
  final double calorias, proteinas, hidratos, fibra, lipidos, saturados;
  final double monoinsat,
      poliinsat,
      colesterol,
      retinol,
      calcio,
      hierro,
      sodio,
      zinc,
      azucaresAnadidos;
  final double precioPorKg;
  final int esPropio;

  InsumoModel({
    this.id,
    required this.nombre,
    required this.alimento,
    this.pais = "Paraguay",
    this.calorias = 0,
    this.proteinas = 0,
    this.hidratos = 0,
    this.fibra = 0,
    this.lipidos = 0,
    this.saturados = 0,
    this.monoinsat = 0,
    this.poliinsat = 0,
    this.colesterol = 0,
    this.retinol = 0,
    this.calcio = 0,
    this.hierro = 0,
    this.sodio = 0,
    this.zinc = 0,
    this.azucaresAnadidos = 0,
    this.precioPorKg = 0,
    this.esPropio = 0,
  });

  factory InsumoModel.fromMap(Map<String, dynamic> map) {
    return InsumoModel(
      id: map['id'],
      nombre: map['nombre'] ?? "",
      alimento: map['alimento'] ?? "",
      pais: map['pais'] ?? "",
      calorias: (map['calorias'] ?? 0).toDouble(),
      proteinas: (map['proteinas'] ?? 0).toDouble(),
      hidratos: (map['hidratos'] ?? 0).toDouble(),
      fibra: (map['fibra'] ?? 0).toDouble(),
      lipidos: (map['lipidos'] ?? 0).toDouble(),
      saturados: (map['saturados'] ?? 0).toDouble(),
      monoinsat: (map['monoinsat'] ?? 0).toDouble(),
      poliinsat: (map['poliinsat'] ?? 0).toDouble(),
      colesterol: (map['colesterol'] ?? 0).toDouble(),
      retinol: (map['retinol'] ?? 0).toDouble(),
      calcio: (map['calcio'] ?? 0).toDouble(),
      hierro: (map['hierro'] ?? 0).toDouble(),
      sodio: (map['sodio'] ?? 0).toDouble(),
      zinc: (map['zinc'] ?? 0).toDouble(),
      azucaresAnadidos: (map['azucares_anadidos_g'] ?? 0).toDouble(),
      precioPorKg: (map['precio_por_kg'] ?? 0).toDouble(),
      esPropio: map['es_propio'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'alimento': alimento,
      'pais': pais,
      'calorias': calorias,
      'proteinas': proteinas,
      'hidratos': hidratos,
      'fibra': fibra,
      'lipidos': lipidos,
      'saturados': saturados,
      'monoinsat': monoinsat,
      'poliinsat': poliinsat,
      'colesterol': colesterol,
      'retinol': retinol,
      'calcio': calcio,
      'hierro': hierro,
      'sodio': sodio,
      'zinc': zinc,
      'azucares_anadidos_g': azucaresAnadidos,
      'precio_por_kg': precioPorKg,
      'es_propio': esPropio,
    };
  }
}
