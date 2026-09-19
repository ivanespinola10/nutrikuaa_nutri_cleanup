class ProfessionalProfile {
  final String fullName;
  final String? credentials;
  final String? registrationNumber;
  final String? practiceName;
  final String? phone;
  final String? email;
  final String? footerText;

  const ProfessionalProfile({
    required this.fullName,
    this.credentials,
    this.registrationNumber,
    this.practiceName,
    this.phone,
    this.email,
    this.footerText,
  });

  ProfessionalProfile copyWith({
    String? fullName,
    String? credentials,
    String? registrationNumber,
    String? practiceName,
    String? phone,
    String? email,
    String? footerText,
  }) {
    return ProfessionalProfile(
      fullName: fullName ?? this.fullName,
      credentials: credentials ?? this.credentials,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      practiceName: practiceName ?? this.practiceName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      footerText: footerText ?? this.footerText,
    );
  }
}
