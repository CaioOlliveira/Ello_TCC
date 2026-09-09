import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';

class GoogleAuthResult {
  const GoogleAuthResult({
    required this.idToken,
    required this.email,
    this.nome,
    this.fotoUrl,
  });

  final String idToken;
  final String email;
  final String? nome;
  final String? fotoUrl;
}

class GoogleAuthService {
  GoogleAuthService({required AppConfig config}) : _config = config;

  static Future<void>? _initializeFuture;
  static bool _googleSignInInitialized = false;

  final AppConfig _config;
  bool _initialized = false;

  Future<GoogleAuthResult?> signIn() async {
    await _initialize();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const GoogleAuthException(
        'Este login com Google ainda não está disponível nesta plataforma.',
      );
    }

    final GoogleSignInAccount account;
    try {
      // Limpar credenciais antigas ajuda a mostrar a selecao de conta, mas
      // essa limpeza nao pode impedir uma nova autenticacao caso o Android
      // nao tenha uma sessao anterior para remover.
      try {
        await GoogleSignIn.instance.signOut();
      } on GoogleSignInException {
        // O fluxo de autenticacao abaixo pode seguir normalmente.
      }
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleAuthException(
          'Não foi possível concluir o login com Google. '
          'Se voce selecionou a conta e mesmo assim apareceu este aviso, '
          'verifique a configuracao OAuth Android do app.',
        );
      }

      throw GoogleAuthException(
        'Não foi possível entrar com Google: ${error.code.name}'
        '${error.description == null ? '' : ' - ${error.description}'}',
      );
    } catch (error) {
      throw GoogleAuthException(
        'Não foi possível abrir o login com Google: $error',
      );
    }

    final idToken = account.authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw const GoogleAuthException(
        'Não foi possível obter o token do Google.',
      );
    }

    return GoogleAuthResult(
      idToken: idToken,
      email: account.email,
      nome: account.displayName,
      fotoUrl: account.photoUrl,
    );
  }

  Future<void> _initialize() async {
    if (_initialized || _googleSignInInitialized) {
      _initialized = true;
      return;
    }

    final future = _initializeFuture ??= _initializeGoogleSignIn();
    try {
      await future;
      _googleSignInInitialized = true;
      _initialized = true;
    } catch (error) {
      if (_isAlreadyInitializedError(error)) {
        _googleSignInInitialized = true;
        _initialized = true;
        return;
      }

      _initializeFuture = null;
      rethrow;
    }
  }

  Future<void> _initializeGoogleSignIn() async {
    final clientId = _config.googleClientId.trim();
    final serverClientId = _config.googleServerClientId.trim();
    final effectiveServerClientId = serverClientId.isNotEmpty
        ? serverClientId
        : _config.googleWebClientId.trim();

    if (!kIsWeb && effectiveServerClientId.isEmpty) {
      throw const GoogleAuthException(
        'Login Google indisponível: Web Client ID não configurado.',
      );
    }

    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb && clientId.isNotEmpty ? clientId : null,
      serverClientId: kIsWeb ? null : effectiveServerClientId,
    );
  }

  bool _isAlreadyInitializedError(Object error) {
    return error is StateError &&
        error.message.contains('init() has already been called');
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
