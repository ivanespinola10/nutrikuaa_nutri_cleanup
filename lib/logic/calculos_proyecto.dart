import '../models/insumo_model.dart';
import '../core/calculos_nutricionales.dart';

class ProyectoLogic {
  /// Calcula la densidad de un nutriente específico en la mezcla final
  /// Aplicando la Merma (pérdida de agua/evaporación)
  static double calcularNutrienteTotal({
    required List<InsumoModel> ingredientes,
    required List<double> pesosGramos,
    required double porcentajeMerma,
    required double Function(InsumoModel) obtenerNutriente,
  }) {
    double sumaNutriente = 0;
    double pesoTotalInicial = 0;

    for (int i = 0; i < ingredientes.length; i++) {
      double peso = pesosGramos[i];
      // Nutriente por cada 100g -> lo pasamos a los gramos reales usados
      sumaNutriente += (obtenerNutriente(ingredientes[i]) * peso) / 100;
      pesoTotalInicial += peso;
    }

    if (pesoTotalInicial == 0) return 0;

    // Calculamos el peso final tras la merma en planta
    double pesoFinal = pesoTotalInicial * (1 - (porcentajeMerma / 100));

    // Devolvemos el valor normalizado a base 100g (estándar de etiquetado)
    return (sumaNutriente / pesoFinal) * 100;
  }

  /// Calcula el costo total de la receta
  static double calcularCostoReceta(
    List<InsumoModel> ingredientes,
    List<double> pesosGramos,
  ) {
    double costoTotal = 0;
    for (int i = 0; i < ingredientes.length; i++) {
      costoTotal += (ingredientes[i].precioPorKg / 1000) * pesosGramos[i];
    }
    return costoTotal;
  }
}
