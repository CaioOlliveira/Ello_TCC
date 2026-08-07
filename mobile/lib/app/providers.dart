import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/auth/google_auth_service.dart';
import '../core/config/app_config.dart';

class UsuarioSessao {
  const UsuarioSessao({
    required this.id,
    required this.nome,
    required this.email,
    this.telefone,
    this.urlFoto,
  });

  factory UsuarioSessao.fromJson(Map<String, dynamic> json) {
    return UsuarioSessao(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      telefone: json['telefone']?.toString(),
      urlFoto: json['urlFoto']?.toString() ?? json['url_foto']?.toString(),
    );
  }

  final String id;
  final String nome;
  final String email;
  final String? telefone;
  final String? urlFoto;

  UsuarioSessao copyWith({
    String? nome,
    String? email,
    String? telefone,
    String? urlFoto,
  }) {
    return UsuarioSessao(
      id: id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      telefone: telefone ?? this.telefone,
      urlFoto: urlFoto ?? this.urlFoto,
    );
  }
}

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return ApiClient(baseUrl: config.apiBaseUrl);
});

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  final config = ref.watch(appConfigProvider);
  return GoogleAuthService(config: config);
});

final authSessionProvider = StateProvider<UsuarioSessao?>((ref) => null);

final selectedIdosoProvider = StateProvider<IdosoResumo?>((ref) => null);

final idososDoUsuarioProvider = FutureProvider.autoDispose<List<IdosoResumo>>((
  ref,
) {
  final usuario = ref.watch(authSessionProvider);

  if (usuario == null || usuario.id.isEmpty) {
    return Future.value(const []);
  }

  return ref.watch(apiClientProvider).listarIdosos(usuarioId: usuario.id);
});

final fichasAdministradasProvider =
    FutureProvider.autoDispose<List<IdosoResumo>>((ref) {
  final usuario = ref.watch(authSessionProvider);

  if (usuario == null || usuario.id.isEmpty) {
    return Future.value(const []);
  }

  return ref
      .watch(apiClientProvider)
      .listarIdososAdministrados(usuarioId: usuario.id);
});

final healthCheckProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(apiClientProvider).getHealth();
});
