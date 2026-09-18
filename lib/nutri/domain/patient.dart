import 'nutrition/nutrient.dart';

class Patient {
  final int? id;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String? sex;
  final String? email;
  final String? phone;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Patient({
    this.id,
    required this.firstName,
    required this.lastName,
    this.dateOfBirth,
    this.sex,
    this.email,
    this.phone,
    this.notes,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get displayName => [firstName, lastName]
      .where((value) => value.trim().isNotEmpty)
      .join(' ');
}

class NutritionTarget {
  final int? id;
  final int patientId;
  final String nutrientCode;
  final double targetValue;
  final NutrientUnit unit;
  final double? minimumValue;
  final double? maximumValue;

  const NutritionTarget({
    this.id,
    required this.patientId,
    required this.nutrientCode,
    required this.targetValue,
    required this.unit,
    this.minimumValue,
    this.maximumValue,
  });
}
