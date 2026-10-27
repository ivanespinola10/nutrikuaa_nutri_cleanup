import 'package:flutter_test/flutter_test.dart';
import 'package:nutrikuaa_app/nutri/application/patient_document_text.dart';
import 'package:nutrikuaa_app/nutri/config/app_build_info.dart';
import 'package:nutrikuaa_app/nutri/domain/food.dart';

void main() {
  test('official USDA food gets a patient-friendly Spanish name', () {
    final food = Food(
      name: 'Chicken, breast, boneless, skinless, raw',
      sourceType: FoodSourceType.officialDatabase,
      sourceName: 'USDA FoodData Central',
    );

    expect(
      PatientDocumentText.foodDisplayName(food, 'es'),
      'Pechuga de pollo sin piel ni hueso, cruda',
    );
  });

  test('professional custom food keeps its original name', () {
    final food = Food(
      name: 'Chipa guasu de la casa',
      sourceType: FoodSourceType.professionalCustom,
    );
    expect(
      PatientDocumentText.foodDisplayName(food, 'es'),
      'Chipa guasu de la casa',
    );
  });

  test('internal Nutri IA note is hidden from patient-facing text', () {
    expect(
      PatientDocumentText.patientFacingPortionNote(
        'Borrador Nutri IA offline · revisar profesionalmente',
      ),
      isNull,
    );
  });

  test('real portion note is preserved', () {
    expect(PatientDocumentText.patientFacingPortionNote('1 taza'), '1 taza');
  });

  test('visible version is centralized', () {
    expect(NutriBuildInfo.version, '1.0.0');
    expect(NutriBuildInfo.displayLabel, 'PREVENTA · 1.0.0');
  });
}
