import 'package:ello_mobile/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mantem o Client ID oficial do Google em todos os builds', () {
    const expectedClientId =
        '301144381543-gq4k0torscv89l971lvea6hop3g3lkp6.apps.googleusercontent.com';
    const config = AppConfig();

    expect(AppConfig.defaultGoogleWebClientId, expectedClientId);
    expect(config.googleClientId, expectedClientId);
    expect(config.googleServerClientId, expectedClientId);
    expect(config.googleWebClientId, expectedClientId);
  });
}
