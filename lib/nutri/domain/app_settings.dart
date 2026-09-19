enum UnitSystem {
  metric,
  imperial,
}

class AppSettings {
  final String languageCode;
  final String countryCode;
  final UnitSystem unitSystem;

  const AppSettings({
    this.languageCode = 'es',
    this.countryCode = 'PY',
    this.unitSystem = UnitSystem.metric,
  });

  AppSettings copyWith({
    String? languageCode,
    String? countryCode,
    UnitSystem? unitSystem,
  }) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      countryCode: countryCode ?? this.countryCode,
      unitSystem: unitSystem ?? this.unitSystem,
    );
  }
}
