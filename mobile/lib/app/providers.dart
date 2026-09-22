import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';
import '../core/auth/google_auth_service.dart';
import '../core/config/app_config.dart';
import '../features/chat/application/chat_inbox_controller.dart';

class UsuarioSessao {
  const UsuarioSessao({
    required this.id,
    required this.nome,
    required this.email,
    this.telefone,
    this.urlFoto,
    this.sexo,
    this.accessToken,
  });

  factory UsuarioSessao.fromJson(Map<String, dynamic> json) {
    return UsuarioSessao(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      telefone: json['telefone']?.toString(),
      urlFoto: json['urlFoto']?.toString() ?? json['url_foto']?.toString(),
      sexo: json['sexo']?.toString(),
      accessToken:
          json['accessToken']?.toString() ?? json['access_token']?.toString(),
    );
  }

  final String id;
  final String nome;
  final String email;
  final String? telefone;
  final String? urlFoto;
  final String? sexo;
  final String? accessToken;

  UsuarioSessao copyWith({
    String? nome,
    String? email,
    String? telefone,
    String? urlFoto,
    String? sexo,
    String? accessToken,
  }) {
    return UsuarioSessao(
      id: id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      telefone: telefone ?? this.telefone,
      urlFoto: urlFoto ?? this.urlFoto,
      sexo: sexo ?? this.sexo,
      accessToken: accessToken ?? this.accessToken,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'email': email,
        'telefone': telefone,
        'urlFoto': urlFoto,
        'sexo': sexo,
        'accessToken': accessToken,
      };
}

class SessaoUsuarioLocal {
  static const _storageKey = 'sessao_usuario_v1';

  Future<UsuarioSessao?> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final usuario = UsuarioSessao.fromJson(decoded);
      if (usuario.id.isEmpty || usuario.email.isEmpty) return null;
      return usuario;
    } catch (_) {
      return null;
    }
  }

  Future<void> salvar(UsuarioSessao usuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(usuario.toJson()));
  }

  Future<void> limpar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

class AppNavigationState {
  const AppNavigationState({
    required this.location,
    required this.idosoId,
  });

  final String location;
  final String? idosoId;
}

class AppNavigationStateLocal {
  static const _locationKey = 'app_navigation_location_v1';
  static const _idosoIdKey = 'app_navigation_idoso_id_v1';

  Future<AppNavigationState?> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final location = prefs.getString(_locationKey);
    if (location == null || location.isEmpty || location == '/') {
      return null;
    }

    return AppNavigationState(
      location: location,
      idosoId: prefs.getString(_idosoIdKey),
    );
  }

  Future<void> salvar({
    required String location,
    String? idosoId,
  }) async {
    if (!_isRestorableLocation(location)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationKey, location);

    if (idosoId == null || idosoId.isEmpty) {
      await prefs.remove(_idosoIdKey);
    } else {
      await prefs.setString(_idosoIdKey, idosoId);
    }
  }

  Future<void> limpar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_locationKey);
    await prefs.remove(_idosoIdKey);
  }

  static bool _isRestorableLocation(String location) {
    final uri = Uri.tryParse(location);
    final path = uri?.path ?? location;

    if (path == '/' || path == '/login' || path.startsWith('/chat/')) {
      return false;
    }

    return path == '/dashboard' ||
        path == '/monitoramento' ||
        path == '/chat' ||
        path == '/relatorios' ||
        path == '/idoso/perfil' ||
        path == '/agenda' ||
        path == '/agenda/historico' ||
        path == '/glicemia' ||
        path == '/alimentacao' ||
        path == '/gastos' ||
        path == '/medicamentos' ||
        path == '/equipamentos' ||
        path == '/equipamentos/historico' ||
        path == '/insumos' ||
        path == '/humor' ||
        path == '/pressao' ||
        path == '/oxigenacao' ||
        path == '/temperatura' ||
        path == '/corgia' ||
        path == '/coraia' ||
        path.startsWith('/historico/');
  }
}

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return ApiClient(baseUrl: config.apiBaseUrl);
});

final chatInboxProvider =
    StateNotifierProvider<ChatInboxController, ChatInboxState>((ref) {
  return ChatInboxController(ref.watch(apiClientProvider));
});

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  final config = ref.watch(appConfigProvider);
  return GoogleAuthService(config: config);
});

final authSessionProvider = StateProvider<UsuarioSessao?>((ref) => null);

final sessaoUsuarioLocalProvider = Provider<SessaoUsuarioLocal>(
  (ref) => SessaoUsuarioLocal(),
);

final appNavigationStateLocalProvider = Provider<AppNavigationStateLocal>(
  (ref) => AppNavigationStateLocal(),
);

final selectedIdosoProvider = StateProvider<IdosoResumo?>((ref) => null);

final idososDoUsuarioProvider = FutureProvider<List<IdosoResumo>>((
  ref,
) {
  final usuario = ref.watch(authSessionProvider);

  if (usuario == null || usuario.id.isEmpty) {
    return Future.value(const []);
  }

  return ref.watch(apiClientProvider).listarIdosos(usuarioId: usuario.id);
});

final fichasAdministradasProvider = FutureProvider<List<IdosoResumo>>((ref) {
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
