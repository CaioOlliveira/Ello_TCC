import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

class ChatPushPayload {
  const ChatPushPayload({
    required this.idosoId,
    required this.peerId,
    this.messageId,
  });

  factory ChatPushPayload.fromData(Map<String, dynamic> data) {
    return ChatPushPayload(
      idosoId: data['idosoId']?.toString() ?? '',
      peerId: data['peerId']?.toString() ?? '',
      messageId: data['mensagemId']?.toString(),
    );
  }

  final String idosoId;
  final String peerId;
  final String? messageId;

  bool get isValid => idosoId.isNotEmpty && peerId.isNotEmpty;
}

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  final _foregroundMessages = StreamController<ChatPushPayload>.broadcast();
  final _openedMessages = StreamController<ChatPushPayload>.broadcast();

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  ApiClient? _api;
  String? _accessToken;
  String? _usuarioId;
  var _firebaseReady = false;
  var _initialized = false;

  Stream<ChatPushPayload> get foregroundMessages => _foregroundMessages.stream;
  Stream<ChatPushPayload> get openedMessages => _openedMessages.stream;

  Future<void> configure({
    required ApiClient api,
    required String? usuarioId,
    required String? accessToken,
  }) async {
    _api = api;
    _usuarioId = usuarioId;
    _accessToken = accessToken;
    if (usuarioId == null ||
        usuarioId.isEmpty ||
        accessToken == null ||
        accessToken.isEmpty) {
      return;
    }

    if (!_initialized) await _initializeFirebase();
    if (!_firebaseReady) return;
    await _registerCurrentToken();
  }

  Future<void> _initializeFirebase() async {
    _initialized = true;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      await FirebaseMessaging.instance.requestPermission();

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        (message) => _emitForeground(message.data),
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _emitOpened(message.data),
      );
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (_) => unawaited(_registerCurrentToken()),
      );

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) _emitOpened(initialMessage.data);
    } catch (_) {
      // Firebase remains optional until the project receives its production
      // configuration file. Polling continues to deliver the chat in foreground.
      _firebaseReady = false;
    }
  }

  void _emitForeground(Map<String, dynamic> data) {
    final payload = ChatPushPayload.fromData(data);
    if (payload.isValid) _foregroundMessages.add(payload);
  }

  void _emitOpened(Map<String, dynamic> data) {
    final payload = ChatPushPayload.fromData(data);
    if (payload.isValid) _openedMessages.add(payload);
  }

  Future<void> _registerCurrentToken() async {
    final api = _api;
    final accessToken = _accessToken;
    final usuarioId = _usuarioId;
    if (api == null ||
        accessToken == null ||
        accessToken.isEmpty ||
        usuarioId == null ||
        usuarioId.isEmpty ||
        !_firebaseReady) {
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await api.registrarDispositivoPushChat(
        token: token,
        plataforma: _platformName(),
        accessToken: accessToken,
      );
    } catch (_) {
      // The next startup, token refresh, or session refresh retries registration.
    }
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  void dispose() {
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    _tokenSubscription?.cancel();
    unawaited(_foregroundMessages.close());
    unawaited(_openedMessages.close());
  }
}
