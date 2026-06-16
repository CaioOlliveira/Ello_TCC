class AppConfig {
  const AppConfig();

  String get apiBaseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:3000/api/v1',
      );
}
