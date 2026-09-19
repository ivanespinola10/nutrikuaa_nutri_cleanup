import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../domain/professional_profile.dart';
import 'nutri_database.dart';

class ProfessionalProfileRepository {
  final NutriDatabase database;

  ProfessionalProfileRepository({NutriDatabase? database})
      : database = database ?? NutriDatabase.instance;

  Future<ProfessionalProfile> load() async {
    final db = await database.database;
    final rows = await db.query(
      'professional_profile',
      where: 'id = 1',
      limit: 1,
    );

    if (rows.isEmpty) {
      return const ProfessionalProfile(fullName: '');
    }

    final row = rows.first;
    return ProfessionalProfile(
      fullName: row['full_name'] as String? ?? '',
      credentials: row['credentials'] as String?,
      registrationNumber: row['registration_number'] as String?,
      practiceName: row['practice_name'] as String?,
      phone: row['phone'] as String?,
      email: row['email'] as String?,
      footerText: row['footer_text'] as String?,
      logoBytes: row['logo_bytes'] as Uint8List?,
      logoFileName: row['logo_file_name'] as String?,
    );
  }

  Future<void> save(ProfessionalProfile profile) async {
    final db = await database.database;
    await db.insert(
      'professional_profile',
      {
        'id': 1,
        'full_name': profile.fullName.trim(),
        'credentials': _nullIfBlank(profile.credentials),
        'registration_number': _nullIfBlank(profile.registrationNumber),
        'practice_name': _nullIfBlank(profile.practiceName),
        'phone': _nullIfBlank(profile.phone),
        'email': _nullIfBlank(profile.email),
        'footer_text': _nullIfBlank(profile.footerText),
        'logo_bytes': profile.logoBytes,
        'logo_file_name': _nullIfBlank(profile.logoFileName),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
