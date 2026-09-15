import 'package:ello_mobile/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mantem o Client ID oficial do Google em todos os builds', () {
    const expectedClientId =
        '318821887059-iukcc2mai6klc7ml1a1h121ev37rvsvm.apps.googleusercontent.com';
    const config = AppConfig();

    expect(AppConfig.defaultGoogleWebClientId, expectedClientId);
    expect(config.googleClientId, expectedClientId);
    expect(config.googleServerClientId, expectedClientId);
    expect(config.googleWebClientId, expectedClientId);
  });
}
