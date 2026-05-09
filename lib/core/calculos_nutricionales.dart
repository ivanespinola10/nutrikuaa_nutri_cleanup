class NutriCalculos {
  /// 1. Balance de Materia con Merma
  /// Calcula la densidad real tras la pérdida en planta (evaporación, etc.)
  static double aplicarMerma(double valor, double porcentajeMerma) {
    if (porcentajeMerma <= 0) return valor;
    // Si hay 10% de merma, el nutriente se concentra en menos masa total
    return valor / (1 - (porcentajeMerma / 100));
  }

  /// 2. Factor de Atwater Profesional
  /// Calcula Kcal totales basándose en gramos por 100g
  static double calcularKcal({
    required double p, // Proteína
    required double c, // Carbos
    required double g, // Grasa
  }) {
    return (p * 4) + (c * 4) + (g * 9);
  }

  /// 3. Conversión a Porción Personalizada
  /// Pasa cualquier valor de base 100g a la porción que tú definas
  static double calcularPorPorcion(double valorBase100, double gramosPorcion) {
    return (valorBase100 * gramosPorcion) / 100;
  }

  /// 4. Análisis Económico (MBA Focus)
  /// Calcula el costo de la porción basada en el precio por Kg
  static double calcularCostoPorcion(double precioPorKg, double gramosPorcion) {
    return (precioPorKg / 1000) * gramosPorcion;
  }

  /// 5. Formateo de Ingeniería
  /// Evita los decimales infinitos que vimos en tus capturas
  static String formatear(double valor, {int decimales = 1}) {
    return valor.toStringAsFixed(decimales);
  }

  static double parse(String text) {
    final limpio = text.trim().replaceAll(',', '.');
    return double.tryParse(limpio) ?? 0.0;
  }
}
