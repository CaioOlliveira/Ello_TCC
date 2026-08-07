class AppConfig {
  const AppConfig();

  String get apiBaseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://ello-tcc.onrender.com/api/v1',
      );

  String get googleClientId => const String.fromEnvironment(
        'GOOGLE_CLIENT_ID',
        defaultValue:
            '318821887059-iukcc2mai6klc7ml1a1h121ev37rvsvm.apps.googleusercontent.com',
      );

  String get googleServerClientId => const String.fromEnvironment(
        'GOOGLE_SERVER_CLIENT_ID',
        defaultValue:
            '318821887059-iukcc2mai6klc7ml1a1h121ev37rvsvm.apps.googleusercontent.com',
      );
}
