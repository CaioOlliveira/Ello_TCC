class AppConfig {
  const AppConfig();

  String get apiBaseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:3000/api/v1',
      );

  String get googleClientId => const String.fromEnvironment(
        'GOOGLE_CLIENT_ID',
        defaultValue: '',
      );

  String get googleServerClientId => const String.fromEnvironment(
        'GOOGLE_SERVER_CLIENT_ID',
        defaultValue: '',
      );
}
