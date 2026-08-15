class AppConfig {
  const AppConfig();

  static const String defaultGoogleWebClientId =
      '318821887059-iukcc2mai6klc7ml1a1h121ev37rvsvm.apps.googleusercontent.com';

  String get apiBaseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://ello-tcc.onrender.com/api/v1',
      );

  String get googleClientId {
    const value = String.fromEnvironment('GOOGLE_CLIENT_ID');
    if (value.trim().isNotEmpty) return value.trim();
    return googleWebClientId;
  }

  String get googleServerClientId {
    const serverValue = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    if (serverValue.trim().isNotEmpty) return serverValue.trim();
    return googleWebClientId;
  }

  String get googleWebClientId {
    const webValue = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    if (webValue.trim().isNotEmpty) return webValue.trim();
    return defaultGoogleWebClientId;
  }
}
