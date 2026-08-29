import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/notifications/local_notification_service.dart';

class ChatInboxState {
  const ChatInboxState({
    this.usuarioId,
    this.idosoId,
    this.loading = false,
    this.conversas = const [],
    this.error,
  });

  final String? usuarioId;
  final String? idosoId;
  final bool loading;
  final List<MembroFicha> conversas;
  final String? error;

  ChatInboxState copyWith({
    String? usuarioId,
    String? idosoId,
    bool? loading,
    List<MembroFicha>? conversas,
    String? error,
    bool clearError = false,
  }) {
    return ChatInboxState(
      usuarioId: usuarioId ?? this.usuarioId,
      idosoId: idosoId ?? this.idosoId,
      loading: loading ?? this.loading,
      conversas: conversas ?? this.conversas,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ChatIncomingMessage {
  const ChatIncomingMessage({
    required this.idosoId,
    required this.peerId,
    this.messageId,
  });

  final String idosoId;
  final String peerId;
  final String? messageId;
}

class ChatInboxController extends StateNotifier<ChatInboxState> {
  ChatInboxController(this._api) : super(const ChatInboxState());

  static const _inboxPollInterval = Duration(milliseconds: 900);

  final ApiClient _api;
  final _incomingMessages = StreamController<ChatIncomingMessage>.broadcast();
  final _unreadByPeer = <String, int>{};

  Timer? _timer;
  String? _accessToken;
  String? _activePeerId;
  DateTime? _lastPresenceAt;
  var _refreshing = false;
  var _sendingPresence = false;
  var _hasUnreadBaseline = false;
  var _appActive = true;

  Stream<ChatIncomingMessage> get incomingMessages => _incomingMessages.stream;

  void configure({
    required String? usuarioId,
    required String? idosoId,
    required String? accessToken,
  }) {
    final hasConfiguration = usuarioId != null &&
        usuarioId.isNotEmpty &&
        idosoId != null &&
        idosoId.isNotEmpty &&
        accessToken != null &&
        accessToken.isNotEmpty;
    final sameConfiguration = state.usuarioId == usuarioId &&
        state.idosoId == idosoId &&
        _accessToken == accessToken;
    if (sameConfiguration) return;

    _timer?.cancel();
    _accessToken = hasConfiguration ? accessToken : null;
    _activePeerId = null;
    _lastPresenceAt = null;
    _hasUnreadBaseline = false;
    _unreadByPeer.clear();

    if (!hasConfiguration) {
      if (usuarioId != null &&
          usuarioId.isNotEmpty &&
          idosoId != null &&
          idosoId.isNotEmpty) {
        state = ChatInboxState(
          usuarioId: usuarioId,
          idosoId: idosoId,
          error: 'Sua sessao expirou. Entre novamente para continuar.',
        );
      } else if (usuarioId != null && usuarioId.isNotEmpty) {
        state = ChatInboxState(
          usuarioId: usuarioId,
          error: 'Selecione uma ficha para abrir o chat.',
        );
      } else {
        state = const ChatInboxState(
          error: 'Entre na sua conta para conversar.',
        );
      }
      return;
    }

    state =
        ChatInboxState(usuarioId: usuarioId, idosoId: idosoId, loading: true);
    _startPolling();
  }

  void setAppActive(bool active) {
    if (_appActive == active) return;
    _appActive = active;
    _timer?.cancel();
    if (active) _startPolling();
  }

  void setActiveConversation(String? peerId) {
    _activePeerId = peerId;
  }

  void notifyIncomingMessage(ChatIncomingMessage message) {
    if (message.idosoId != state.idosoId) return;
    _incomingMessages.add(message);
    unawaited(refresh());
  }

  void applyOutgoingMessage({
    required String peerId,
    required String preview,
    required DateTime createdAt,
  }) {
    final conversations = [...state.conversas];
    final index = conversations.indexWhere((item) => item.usuarioId == peerId);
    if (index == -1) return;
    conversations[index] = conversations[index].copyWith(
      ultimaMensagemPreview: preview,
      ultimaMensagemEm: createdAt,
    );
    conversations.sort(_compareConversations);
    state = state.copyWith(conversas: conversations, clearError: true);
  }

  void markConversationAsRead(String peerId) {
    final conversations = state.conversas
        .map(
          (item) => item.usuarioId == peerId
              ? item.copyWith(mensagensNaoLidas: 0)
              : item,
        )
        .toList();
    _unreadByPeer[peerId] = 0;
    state = state.copyWith(conversas: conversations, clearError: true);
  }

  Future<void> refresh({bool showLoading = false}) async {
    final usuarioId = state.usuarioId;
    final idosoId = state.idosoId;
    final accessToken = _accessToken;
    if (_refreshing ||
        !_appActive ||
        usuarioId == null ||
        idosoId == null ||
        accessToken == null) {
      return;
    }

    _refreshing = true;
    if (showLoading && state.conversas.isEmpty) {
      state = state.copyWith(loading: true, clearError: true);
    }
    _recordPresenceIfNeeded(accessToken);

    try {
      final conversations = await _api.listarConversasFamilia(
        idosoId: idosoId,
        accessToken: accessToken,
      );
      if (state.usuarioId != usuarioId || state.idosoId != idosoId) return;

      final sorted = [...conversations]..sort(_compareConversations);
      await _showNewMessageNotifications(
        usuarioId: usuarioId,
        idosoId: idosoId,
        conversations: sorted,
      );
      if (!_sameConversations(state.conversas, sorted) ||
          state.loading ||
          state.error != null) {
        state = state.copyWith(
          loading: false,
          conversas: sorted,
          clearError: true,
        );
      }
    } catch (error) {
      if (state.usuarioId != usuarioId || state.idosoId != idosoId) return;
      if (state.conversas.isEmpty) {
        state = state.copyWith(
          loading: false,
          error: _messageForError(error),
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  void _startPolling() {
    if (!_appActive || state.usuarioId == null || state.idosoId == null) return;
    _timer?.cancel();
    unawaited(_refreshAndScheduleNext(showLoading: true));
  }

  Future<void> _refreshAndScheduleNext({bool showLoading = false}) async {
    _timer?.cancel();
    await refresh(showLoading: showLoading);
    if (!_appActive || state.usuarioId == null || state.idosoId == null) return;
    _timer = Timer(_inboxPollInterval, () {
      unawaited(_refreshAndScheduleNext());
    });
  }

  void _recordPresenceIfNeeded(String accessToken) {
    final now = DateTime.now();
    if (_sendingPresence ||
        (_lastPresenceAt != null &&
            now.difference(_lastPresenceAt!) < const Duration(seconds: 30))) {
      return;
    }
    _sendingPresence = true;
    _lastPresenceAt = now;
    unawaited(
      _api
          .registrarPresencaChat(accessToken: accessToken)
          .catchError((_) {})
          .whenComplete(() {
        _sendingPresence = false;
      }),
    );
  }

  Future<void> _showNewMessageNotifications({
    required String usuarioId,
    required String idosoId,
    required List<MembroFicha> conversations,
  }) async {
    final currentPeers = <String>{};
    for (final conversation in conversations) {
      final peerId = conversation.usuarioId;
      if (peerId.isEmpty || peerId == usuarioId) continue;
      currentPeers.add(peerId);

      final unread = conversation.mensagensNaoLidas;
      final previous = _unreadByPeer[peerId] ?? 0;
      if (_hasUnreadBaseline && unread > previous && _activePeerId != peerId) {
        final count = unread - previous;
        final preview = conversation.ultimaMensagemPreview?.trim();
        await LocalNotificationService.instance.showNow(
          id: stableNotificationId('chat:$idosoId:$peerId'),
          title: 'Nova mensagem no Chat do Cuidado',
          body: count > 1
              ? '${conversation.nome} enviou $count mensagens.'
              : (preview != null && preview.isNotEmpty
                  ? '${conversation.nome}: $preview'
                  : '${conversation.nome} enviou uma mensagem.'),
          payload: 'chat:$idosoId:$peerId',
        );
      }
      _unreadByPeer[peerId] = unread;
    }
    _unreadByPeer.removeWhere((peerId, _) => !currentPeers.contains(peerId));
    _hasUnreadBaseline = true;
  }

  String _messageForError(Object error) {
    if (error is ApiException) return error.message;
    return 'Nao foi possivel carregar as conversas.';
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_incomingMessages.close());
    super.dispose();
  }
}

int _compareConversations(MembroFicha first, MembroFicha second) {
  final firstMessageAt = first.ultimaMensagemEm;
  final secondMessageAt = second.ultimaMensagemEm;
  if (firstMessageAt == null && secondMessageAt != null) return 1;
  if (firstMessageAt != null && secondMessageAt == null) return -1;
  if (firstMessageAt != null && secondMessageAt != null) {
    final comparison = secondMessageAt.compareTo(firstMessageAt);
    if (comparison != 0) return comparison;
  }
  return first.nome.compareTo(second.nome);
}

bool _sameConversations(List<MembroFicha> first, List<MembroFicha> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    final current = first[index];
    final updated = second[index];
    if (current.usuarioId != updated.usuarioId ||
        current.nome != updated.nome ||
        current.urlFoto != updated.urlFoto ||
        current.funcao != updated.funcao ||
        current.status != updated.status ||
        current.online != updated.online ||
        current.ultimoVistoEm != updated.ultimoVistoEm ||
        current.mensagensNaoLidas != updated.mensagensNaoLidas ||
        current.ultimaMensagemPreview != updated.ultimaMensagemPreview ||
        current.ultimaMensagemEm != updated.ultimaMensagemEm) {
      return false;
    }
  }
  return true;
}
