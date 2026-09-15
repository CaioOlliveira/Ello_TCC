class AppConfig {
  const AppConfig();

  // OAuth IDs are application identifiers, not environment-specific secrets.
  // Keeping them here prevents a build flag or a Firebase file update from
  // silently changing the Google Sign-In audience.
  static const String defaultGoogleWebClientId =
      '318821887059-iukcc2mai6klc7ml1a1h121ev37rvsvm.apps.googleusercontent.com';

  String get apiBaseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://ellotcc-production.up.railway.app/api/v1',
      );

  String get googleClientId => defaultGoogleWebClientId;

  String get googleServerClientId => defaultGoogleWebClientId;

  String get googleWebClientId => defaultGoogleWebClientId;
}
