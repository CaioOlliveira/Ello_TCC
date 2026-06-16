import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return ApiClient(baseUrl: config.apiBaseUrl);
});

final healthCheckProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(apiClientProvider).getHealth();
});
