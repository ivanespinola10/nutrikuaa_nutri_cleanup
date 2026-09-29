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
  final String? consultationReason;
  final String? dietaryHistory;
  final String? foodContext;
  final String? reportedAllergies;
  final String? clinicalContext;
  final String? historySource;
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
    this.consultationReason,
    this.dietaryHistory,
    this.foodContext,
    this.reportedAllergies,
    this.clinicalContext,
    this.historySource,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get displayName => [firstName, lastName]
      .where((value) => value.trim().isNotEmpty)
      .join(' ');
}

/// One dated professional note. This is not an automated diagnosis.
class PatientEncounter {
  final int? id;
  final int patientId;
  final DateTime occurredAt;
  final String? assessment;
  final String? nutritionProblem;
  final String? intervention;
  final String? monitoring;
  final DateTime? nextReviewAt;
  final String? informationSource;
  final int? planId;

  const PatientEncounter({
    this.id,
    required this.patientId,
    required this.occurredAt,
    this.assessment,
    this.nutritionProblem,
    this.intervention,
    this.monitoring,
    this.nextReviewAt,
    this.informationSource,
    this.planId,
  });
}

/// Manually recorded indicator, with provenance and units; no interpretation.
class PatientObservation {
  final int? id;
  final int patientId;
  final DateTime observedAt;
  final String indicator;
  final double value;
  final String unit;
  final String source;
  final String? referenceRange;

  const PatientObservation({
    this.id,
    required this.patientId,
    required this.observedAt,
    required this.indicator,
    required this.value,
    required this.unit,
    required this.source,
    this.referenceRange,
  });
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


class PatientMeasurement {
  final int? id;
  final int patientId;
  final DateTime measuredAt;
  final double? weightKg;
  final double? heightCm;
  final double? waistCm;
  final String? notes;

  const PatientMeasurement({
    this.id,
    required this.patientId,
    required this.measuredAt,
    this.weightKg,
    this.heightCm,
    this.waistCm,
    this.notes,
  });

  double? get bmi {
    final weight = weightKg;
    final height = heightCm;
    if (weight == null || height == null || weight <= 0 || height <= 0) {
      return null;
    }

    final meters = height / 100;
    return weight / (meters * meters);
  }
}
