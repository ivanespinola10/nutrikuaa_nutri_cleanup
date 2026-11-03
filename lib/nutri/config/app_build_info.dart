class NutriBuildInfo {
  NutriBuildInfo._();

  static const version = '1.0.0';
  static const stage = 'RC';
  static const isProduction = bool.fromEnvironment(
    'NUTRI_PRODUCTION',
    defaultValue: false,
  );

  static const displayLabel = isProduction ? version : '$stage · $version';
}
