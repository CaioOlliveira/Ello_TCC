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

  final AppConfig _config;
  bool _initialized = false;

  Future<GoogleAuthResult?> signIn() async {
    await _initialize();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const GoogleAuthException(
        'Este login com Google ainda nao esta disponivel nesta plataforma.',
      );
    }

    final GoogleSignInAccount account;
    try {
      await GoogleSignIn.instance.signOut();
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleAuthException(
          'Nao foi possivel concluir o login com Google. '
          'Tente selecionar a conta novamente.',
        );
      }

      throw GoogleAuthException(
        'Nao foi possivel entrar com Google: ${error.code.name}'
        '${error.description == null ? '' : ' - ${error.description}'}',
      );
    } catch (error) {
      throw GoogleAuthException(
        'Nao foi possivel abrir o login com Google: $error',
      );
    }

    final idToken = account.authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw const GoogleAuthException(
        'Nao foi possivel obter o token do Google.',
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
    if (_initialized) return;

    final clientId = _config.googleClientId.trim();
    final serverClientId = _config.googleServerClientId.trim().isNotEmpty
        ? _config.googleServerClientId.trim()
        : clientId;

    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb && clientId.isNotEmpty ? clientId : null,
      serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
    );

    _initialized = true;
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
