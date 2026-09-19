import 'dart:typed_data';

class ProfessionalProfile {
  final String fullName;
  final String? credentials;
  final String? registrationNumber;
  final String? practiceName;
  final String? phone;
  final String? email;
  final String? footerText;
  final Uint8List? logoBytes;
  final String? logoFileName;

  const ProfessionalProfile({
    required this.fullName,
    this.credentials,
    this.registrationNumber,
    this.practiceName,
    this.phone,
    this.email,
    this.footerText,
    this.logoBytes,
    this.logoFileName,
  });

  ProfessionalProfile copyWith({
    String? fullName,
    String? credentials,
    String? registrationNumber,
    String? practiceName,
    String? phone,
    String? email,
    String? footerText,
    Uint8List? logoBytes,
    String? logoFileName,
    bool clearLogo = false,
  }) {
    return ProfessionalProfile(
      fullName: fullName ?? this.fullName,
      credentials: credentials ?? this.credentials,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      practiceName: practiceName ?? this.practiceName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      footerText: footerText ?? this.footerText,
      logoBytes: clearLogo ? null : (logoBytes ?? this.logoBytes),
      logoFileName: clearLogo ? null : (logoFileName ?? this.logoFileName),
    );
  }
}
