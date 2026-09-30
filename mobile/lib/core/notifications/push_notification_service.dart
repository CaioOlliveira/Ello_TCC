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

class MedicationCancellationPushPayload {
  const MedicationCancellationPushPayload({
    required this.idosoId,
    required this.requestId,
    required this.title,
    required this.body,
  });

  factory MedicationCancellationPushPayload.fromMessage(
    RemoteMessage message,
  ) {
    return MedicationCancellationPushPayload(
      idosoId: message.data['idosoId']?.toString() ?? '',
      requestId: message.data['solicitacaoId']?.toString() ?? '',
      title: message.notification?.title ?? 'Solicitação de medicação',
      body: message.notification?.body ??
          'Há uma nova solicitação relacionada a uma dose.',
    );
  }

  final String idosoId;
  final String requestId;
  final String title;
  final String body;

  bool get isValid => idosoId.isNotEmpty && requestId.isNotEmpty;
}

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  final _foregroundMessages = StreamController<ChatPushPayload>.broadcast();
  final _openedMessages = StreamController<ChatPushPayload>.broadcast();
  final _foregroundMedicationMessages =
      StreamController<MedicationCancellationPushPayload>.broadcast();
  final _openedMedicationMessages =
      StreamController<MedicationCancellationPushPayload>.broadcast();

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
  Stream<MedicationCancellationPushPayload> get foregroundMedicationMessages =>
      _foregroundMedicationMessages.stream;
  Stream<MedicationCancellationPushPayload> get openedMedicationMessages =>
      _openedMedicationMessages.stream;

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
        _emitForeground,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _emitOpened,
      );
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (_) => unawaited(_registerCurrentToken()),
      );

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) _emitOpened(initialMessage);
    } catch (_) {
      // Firebase remains optional until the project receives its production
      // configuration file. Polling continues to deliver the chat in foreground.
      _firebaseReady = false;
    }
  }

  void _emitForeground(RemoteMessage message) {
    if (message.data['type'] == 'medicamento_cancelamento') {
      final payload = MedicationCancellationPushPayload.fromMessage(message);
      if (payload.isValid) _foregroundMedicationMessages.add(payload);
      return;
    }
    final payload = ChatPushPayload.fromData(message.data);
    if (payload.isValid) _foregroundMessages.add(payload);
  }

  void _emitOpened(RemoteMessage message) {
    if (message.data['type'] == 'medicamento_cancelamento') {
      final payload = MedicationCancellationPushPayload.fromMessage(message);
      if (payload.isValid) _openedMedicationMessages.add(payload);
      return;
    }
    final payload = ChatPushPayload.fromData(message.data);
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
    unawaited(_foregroundMedicationMessages.close());
    unawaited(_openedMedicationMessages.close());
  }
}
