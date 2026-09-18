import 'package:flutter_test/flutter_test.dart';
import 'package:nutrikuaa_app/nutri/domain/patient.dart';

void main() {
  test('patient display name is built from first and last name', () {
    final patient = Patient(
      firstName: 'Ana',
      lastName: 'Gomez',
    );

    expect(patient.displayName, 'Ana Gomez');
  });
}
