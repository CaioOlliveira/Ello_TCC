import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/theme/app_palette.dart';

class FamiliaChatPage extends ConsumerStatefulWidget {
  const FamiliaChatPage({super.key});

  @override
  ConsumerState<FamiliaChatPage> createState() => _FamiliaChatPageState();
}

class _FamiliaChatPageState extends ConsumerState<FamiliaChatPage> {
  var _loading = true;
  var _peers = <FamiliaChatPeer>[];
  var _summaries = <String, _ChatSummary>{};
  String? _error;
  Timer? _presenceTimer;
  Timer? _refreshTimer;
  var _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _startPresenceTimer();
      _startRefreshTimer();
    });
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPresenceTimer() {
    _sendPresence();
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendPresence();
      _load(refreshingPresence: true);
    });
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _load(refreshingPresence: true);
    });
  }

  Future<void> _sendPresence() async {
    final usuario = ref.read(authSessionProvider);
    if (usuario == null || usuario.id.isEmpty) return;
    try {
      await ref
          .read(apiClientProvider)
          .registrarPresenca(usuarioId: usuario.id);
    } catch (_) {}
  }

  Future<void> _load({bool refreshingPresence = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    final idoso = ref.read(selectedIdosoProvider);
    final usuario = ref.read(authSessionProvider);

    if (idoso == null || idoso.id.isEmpty) {
      setState(() {
        _loading = false;
        _peers = const [];
        _summaries = const {};
        _error = 'Selecione uma ficha para abrir o chat.';
      });
      _isRefreshing = false;
      return;
    }

    if (usuario == null || usuario.id.isEmpty) {
      setState(() {
        _loading = false;
        _peers = const [];
        _summaries = const {};
        _error = 'Entre na sua conta para conversar.';
      });
      _isRefreshing = false;
      return;
    }

    if (!refreshingPresence) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final participantes = await ref
          .read(apiClientProvider)
          .listarConversasFamilia(idosoId: idoso.id, usuarioId: usuario.id);
      final peers = participantes
          .where((membro) => membro.usuarioId != usuario.id)
          .map(FamiliaChatPeer.fromMembro)
          .where((peer) => peer.id.isNotEmpty)
          .toList()
        ..sort(_comparePeersByLastMessage);
      final summaries = <String, _ChatSummary>{};
      for (final peer in peers) {
        if (peer.lastMessageAt == null && _summaries[peer.id] != null) {
          summaries[peer.id] = _summaries[peer.id]!;
          continue;
        }
        summaries[peer.id] = await _loadSummary(
          ownerId: usuario.id,
          idosoId: idoso.id,
          peer: peer,
        );
      }
      if (!mounted) return;
      final contentChanged =
          !_samePeers(_peers, peers) || !_sameSummaries(_summaries, summaries);
      if (!contentChanged && refreshingPresence) return;
      setState(() {
        _peers = peers;
        _summaries = summaries;
        if (!refreshingPresence) _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        if (!refreshingPresence) _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!refreshingPresence) _loading = false;
        _error = 'Não foi possível carregar os contatos.';
      });
    } finally {
      _isRefreshing = false;
    }
  }

  Future<_ChatSummary> _loadSummary({
    required String ownerId,
    required String idosoId,
    required FamiliaChatPeer peer,
  }) async {
    final preview = peer.lastMessagePreview?.trim();
    if ((preview != null && preview.isNotEmpty) || peer.lastMessageAt != null) {
      return _ChatSummary(
        preview: preview == null || preview.isEmpty
            ? _fallbackPreview(peer)
            : preview,
        updatedAt: peer.lastMessageAt ?? DateTime.now(),
      );
    }

    return _FamilyChatStore.summary(
      ownerId: ownerId,
      idosoId: idosoId,
      peerId: peer.id,
      fallback: _fallbackPreview(peer),
    );
  }

  void _openChat(FamiliaChatPeer peer) {
    final uri = Uri(
      path: '/chat/${Uri.encodeComponent(peer.id)}',
      queryParameters: {
        'nome': peer.name,
        'funcao': peer.role,
      },
    );
    context.go(uri.toString(), extra: peer);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<IdosoResumo?>(selectedIdosoProvider, (previous, next) {
      if (previous?.id == next?.id) return;
      _load();
    });

    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFAFAFA), AppDarkColors.bg),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDarkMode(context)
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
                child: Column(
                  children: [
                    const _FamiliaChatHeader(),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: adaptive(context, const Color(0xFFEAF8FA),
                                  AppDarkColors.tintedInfo),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Color(0xFF007C8A),
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Converse com as pessoas que cuidam junto com você',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: adaptive(
                                        context,
                                        const Color(0xFF64757C),
                                        AppDarkColors.textSecondary),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Conversas',
                        style: TextStyle(
                          color: adaptive(context, const Color(0xFF00808F),
                              AppDarkColors.textPrimary),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Expanded(
                      child: RefreshIndicator(
                        color: const Color(0xFF1598AA),
                        onRefresh: _load,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: _ConversationPanel(
                                    loading: _loading,
                                    error: _error,
                                    peers: _peers,
                                    summaries: _summaries,
                                    onTap: _openChat,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FamiliaChatDetailPage extends ConsumerStatefulWidget {
  const FamiliaChatDetailPage({
    required this.peerId,
    this.initialPeer,
    super.key,
  });

  final String peerId;
  final FamiliaChatPeer? initialPeer;

  @override
  ConsumerState<FamiliaChatDetailPage> createState() =>
      _FamiliaChatDetailPageState();
}

class _FamiliaChatDetailPageState extends ConsumerState<FamiliaChatDetailPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  var _messages = <_FamilyChatMessage>[];
  _PendingImage? _pendingImage;
  late FamiliaChatPeer _peer;
  Timer? _presenceTimer;
  Timer? _refreshTimer;
  var _isLoadingMessages = false;
  var _hasMessageBaseline = false;

  @override
  void initState() {
    super.initState();
    _peer = widget.initialPeer ??
        FamiliaChatPeer(
          id: widget.peerId,
          name: 'Contato',
          role: 'cuidador',
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      _startPresenceTimer();
      _startRefreshTimer();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _presenceTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPresenceTimer() {
    _sendPresence();
    _refreshPeerPresence();
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendPresence();
      _refreshPeerPresence();
    });
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _loadMessages();
      _refreshPeerPresence();
    });
  }

  Future<void> _sendPresence() async {
    final usuario = ref.read(authSessionProvider);
    if (usuario == null || usuario.id.isEmpty) return;
    try {
      await ref
          .read(apiClientProvider)
          .registrarPresenca(usuarioId: usuario.id);
    } catch (_) {}
  }

  Future<void> _refreshPeerPresence() async {
    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null || idoso.id.isEmpty) return;
    try {
      final usuario = ref.read(authSessionProvider);
      if (usuario == null || usuario.id.isEmpty) return;
      final participantes = await ref
          .read(apiClientProvider)
          .listarConversasFamilia(idosoId: idoso.id, usuarioId: usuario.id);
      MembroFicha? membro;
      for (final participante in participantes) {
        if (participante.usuarioId == _peer.id) {
          membro = participante;
          break;
        }
      }
      if (membro == null || !mounted) return;
      final membroAtualizado = membro;
      final updatedPeer = FamiliaChatPeer.fromMembro(membroAtualizado);
      if (!_samePeer(_peer, updatedPeer)) {
        setState(() => _peer = updatedPeer);
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    if (_isLoadingMessages) return;
    _isLoadingMessages = true;
    final usuario = ref.read(authSessionProvider);
    final idoso = ref.read(selectedIdosoProvider);
    if (usuario == null || idoso == null) {
      _isLoadingMessages = false;
      return;
    }

    var messages = <_FamilyChatMessage>[];
    var loadedFromServer = false;
    try {
      final apiMessages =
          await ref.read(apiClientProvider).listarMensagensFamilia(
                idosoId: idoso.id,
                usuarioId: usuario.id,
                outroUsuarioId: _peer.id,
              );
      final remoteMessages = apiMessages
          .map((message) => _FamilyChatMessage.fromApi(message, usuario.id))
          .toList();
      messages = _mergeMessages(remoteMessages);
      loadedFromServer = true;
      if (remoteMessages.isEmpty && messages.isEmpty) {
        messages = await _FamilyChatStore.loadMessages(
          ownerId: usuario.id,
          idosoId: idoso.id,
          peerId: _peer.id,
        );
      }
    } catch (_) {
      messages = await _FamilyChatStore.loadMessages(
        ownerId: usuario.id,
        idosoId: idoso.id,
        peerId: _peer.id,
      );
    }

    if (!mounted) {
      _isLoadingMessages = false;
      return;
    }
    final hasNewMessages = _hasNewMessages(messages);
    final newIncomingMessages = _newIncomingMessages(messages);
    final shouldNotify = loadedFromServer &&
        _hasMessageBaseline &&
        newIncomingMessages.isNotEmpty;
    if (loadedFromServer) _hasMessageBaseline = true;

    if (_sameMessages(_messages, messages)) {
      _isLoadingMessages = false;
      return;
    }

    setState(() => _messages = messages);
    try {
      await _persistMessages();
    } catch (_) {}
    if (hasNewMessages) _scrollToEnd();
    if (shouldNotify) {
      unawaited(_showMessageNotification(idoso.id, newIncomingMessages.last));
    }
    _isLoadingMessages = false;
  }

  List<_FamilyChatMessage> _mergeMessages(
    List<_FamilyChatMessage> remoteMessages,
  ) {
    final remoteIds = remoteMessages.map((message) => message.id).toSet();
    final pendingMessages = _messages.where(
      (message) =>
          message.status == _MessageStatus.pending &&
          !remoteIds.contains(message.id),
    );
    return [...remoteMessages, ...pendingMessages]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  bool _hasNewMessages(List<_FamilyChatMessage> messages) {
    final previousIds = _messages.map((message) => message.id).toSet();
    return messages.any((message) => !previousIds.contains(message.id));
  }

  List<_FamilyChatMessage> _newIncomingMessages(
    List<_FamilyChatMessage> messages,
  ) {
    final previousIds = _messages.map((message) => message.id).toSet();
    return messages
        .where(
            (message) => !message.fromMe && !previousIds.contains(message.id))
        .toList();
  }

  Future<void> _showMessageNotification(
    String idosoId,
    _FamilyChatMessage message,
  ) async {
    try {
      await LocalNotificationService.instance.showNow(
        id: stableNotificationId('chat:$idosoId:${_peer.id}'),
        title: 'Nova mensagem no Chat do Cuidado',
        body:
            '${_peer.displayName}: ${message.text.isNotEmpty ? message.text : 'Foto enviada'}',
        payload: 'chat:${_peer.id}',
      );
    } catch (_) {}
  }

  Future<void> _persistMessages() async {
    final usuario = ref.read(authSessionProvider);
    final idoso = ref.read(selectedIdosoProvider);
    if (usuario == null || idoso == null) return;

    await _FamilyChatStore.saveMessages(
      ownerId: usuario.id,
      idosoId: idoso.id,
      peerId: _peer.id,
      messages: _messages,
    );
  }

  bool get _canDeleteConversation {
    final usuario = ref.read(authSessionProvider);
    final idoso = ref.read(selectedIdosoProvider);
    if (usuario == null || idoso == null) return false;
    final responsavel = idoso.ehDono == true || idoso.criadoPorId == usuario.id;
    return responsavel && _peer.removedFromFicha;
  }

  Future<void> _confirmDeleteConversation() async {
    final usuario = ref.read(authSessionProvider);
    final idoso = ref.read(selectedIdosoProvider);
    if (usuario == null || idoso == null) return;
    if (!_canDeleteConversation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Remova o cuidador da ficha antes de apagar esta conversa.',
          ),
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar conversa?'),
        content: const Text(
          'As mensagens desta conversa serão apagadas para a ficha. Esta ação só pode ser feita pelo responsável.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    if (!mounted) return;

    final confirmationController = TextEditingController();
    final typedConfirmation = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canConfirm =
                confirmationController.text.trim().toUpperCase() == 'APAGAR';

            return AlertDialog(
              title: const Text('Confirmação final'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Esta conversa será excluída para todos nesta ficha.',
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Para confirmar, digite APAGAR.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmationController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'APAGAR',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: canConfirm
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD73A3A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apagar definitivamente'),
                ),
              ],
            );
          },
        );
      },
    );
    confirmationController.dispose();
    if (typedConfirmation != true) return;

    try {
      await ref.read(apiClientProvider).apagarConversaFamilia(
            idosoId: idoso.id,
            usuarioId: usuario.id,
            outroUsuarioId: _peer.id,
          );
      await _FamilyChatStore.clearMessages(
        ownerId: usuario.id,
        idosoId: idoso.id,
        peerId: _peer.id,
      );
      if (!mounted) return;
      context.go('/chat');
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível apagar esta conversa.')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingImage == null) return;
    final usuario = ref.read(authSessionProvider);
    final idoso = ref.read(selectedIdosoProvider);
    if (usuario == null || idoso == null) return;

    final pendingImage = _pendingImage;

    final message = _FamilyChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      fromMe: true,
      createdAt: DateTime.now(),
      imageDataUrl: pendingImage?.dataUrl,
      status: _MessageStatus.pending,
    );

    setState(() {
      _messages = [..._messages, message];
      _controller.clear();
      _pendingImage = null;
    });
    await _persistMessages();

    try {
      final persisted = await ref.read(apiClientProvider).criarMensagemFamilia(
            idosoId: idoso.id,
            usuarioId: usuario.id,
            destinatarioId: _peer.id,
            mensagem: text,
            imagem: pendingImage == null
                ? null
                : {
                    'mimeType': pendingImage.mimeType,
                    'base64': pendingImage.base64Data,
                  },
          );
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .map(
              (item) => item.id == message.id
                  ? _FamilyChatMessage.fromApi(persisted, usuario.id)
                  : item,
            )
            .toList();
      });
      await _persistMessages();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Mensagem salva neste aparelho. Tente sincronizar depois.'),
        ),
      );
    }

    _scrollToEnd();
  }

  Future<void> _showImageOptions() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor:
          adaptive(context, Colors.white, AppDarkColors.surfaceElevated),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_rounded,
                    color: Color(0xFF087F8C),
                  ),
                  title: const Text('Tirar foto'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF087F8C),
                  ),
                  title: const Text('Escolher da galeria'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1280,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pendingImage = _PendingImage(
          mimeType: _mimeTypeFromPath(image.name),
          base64Data: base64Encode(bytes),
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível anexar a imagem.')),
      );
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor:
          adaptive(context, const Color(0xFFFAFAFA), AppDarkColors.bg),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDarkMode(context)
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _ChatDetailHeader(
                    peer: _peer,
                    canDelete: _canDeleteConversation,
                    onDelete: _confirmDeleteConversation,
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 16, 12, 10),
                      decoration: BoxDecoration(
                        color: adaptive(
                            context, Colors.white, AppDarkColors.surface),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: adaptive(
                            context,
                            const Color(0xFF9BD3DC),
                            AppDarkColors.border,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF1D9AAF).withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                        itemCount: _messages.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return const Center(child: _DayPill(label: 'Hoje'));
                          }
                          final message = _messages[index - 1];
                          return _FamilyMessageBubble(
                            key: ValueKey(message.id),
                            message: message,
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      10 + MediaQuery.viewInsetsOf(context).bottom * 0,
                    ),
                    child: Column(
                      children: [
                        if (_pendingImage != null)
                          _PendingFamilyImagePreview(
                            imageDataUrl: _pendingImage!.dataUrl,
                            onRemove: () =>
                                setState(() => _pendingImage = null),
                          ),
                        _FamilyInput(
                          controller: _controller,
                          hasImage: _pendingImage != null,
                          onImage: _showImageOptions,
                          onSend: _sendMessage,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FamiliaChatHeader extends StatelessWidget {
  const _FamiliaChatHeader();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Voltar',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFF008EA0),
              size: 28,
            ),
          ),
        ),
        Text(
          'Chat',
          style: TextStyle(
            color: adaptive(
                context, const Color(0xFF00808F), AppDarkColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({
    required this.loading,
    required this.error,
    required this.peers,
    required this.summaries,
    required this.onTap,
  });

  final bool loading;
  final String? error;
  final List<FamiliaChatPeer> peers;
  final Map<String, _ChatSummary> summaries;
  final ValueChanged<FamiliaChatPeer> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
      decoration: BoxDecoration(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              adaptive(context, const Color(0xFF9BD3DC), AppDarkColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D9AAF).withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1598AA)),
            )
          : error != null
              ? _PanelMessage(text: error!)
              : peers.isEmpty
                  ? const _PanelMessage(
                      text:
                          'Nenhuma outra pessoa tem acesso a esta ficha ainda.',
                    )
                  : Column(
                      children: [
                        for (var index = 0; index < peers.length; index++) ...[
                          _ConversationTile(
                            peer: peers[index],
                            summary: summaries[peers[index].id],
                            unreadCount: peers[index].unreadCount,
                            onTap: () => onTap(peers[index]),
                          ),
                          if (index < peers.length - 1)
                            Divider(
                              height: 1,
                              indent: 48,
                              color: adaptive(
                                context,
                                const Color(0xFFE3E8EA),
                                AppDarkColors.divider,
                              ),
                            ),
                        ],
                      ],
                    ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: adaptive(
              context,
              const Color(0xFF64757C),
              AppDarkColors.textSecondary,
            ),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.peer,
    required this.summary,
    required this.unreadCount,
    required this.onTap,
  });

  final FamiliaChatPeer peer;
  final _ChatSummary? summary;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 0, 12),
          child: Row(
            children: [
              _PeerAvatarWithPresence(peer: peer, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            peer.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adaptive(context, const Color(0xFF142B31),
                                  AppDarkColors.textPrimary),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          peer.roleLabel,
                          style: const TextStyle(
                            color: Color(0xFF00808F),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary?.preview ?? _fallbackPreview(peer),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF4D5D62),
                            AppDarkColors.textSecondary),
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(summary?.updatedAt ?? DateTime.now()),
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF9AA6AA),
                          AppDarkColors.textMuted),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (unreadCount > 0)
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF008EA0),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatDetailHeader extends StatelessWidget {
  const _ChatDetailHeader({
    required this.peer,
    required this.canDelete,
    required this.onDelete,
  });

  final FamiliaChatPeer peer;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 14, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => context.go('/chat'),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFF008EA0),
              size: 30,
            ),
          ),
          _PeerAvatarWithPresence(peer: peer, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        peer.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adaptive(
                            context,
                            const Color(0xFF006B78),
                            AppDarkColors.textPrimary,
                          ),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      peer.roleLabel,
                      style: const TextStyle(
                        color: Color(0xFF00808F),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _presenceText(peer),
                  style: TextStyle(
                    color: adaptive(
                      context,
                      const Color(0xFF66767B),
                      AppDarkColors.textSecondary,
                    ),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              tooltip: 'Apagar conversa',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFF008EA0),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  const _PeerAvatar({required this.peer, required this.size});

  final FamiliaChatPeer peer;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeDataUrl(peer.photoUrl);
    final initials = _initials(peer.name);
    final photoUrl = peer.photoUrl?.trim();
    ImageProvider<Object>? imageProvider;
    if (bytes != null) {
      imageProvider = MemoryImage(bytes);
    } else if (photoUrl != null && photoUrl.startsWith('http')) {
      imageProvider = NetworkImage(photoUrl);
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: adaptive(
        context,
        const Color(0xFFEAF8FA),
        AppDarkColors.tintedInfo,
      ),
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(
              initials,
              style: TextStyle(
                color: const Color(0xFF007C8A),
                fontSize: size >= 50 ? 21 : 16,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: const Color(0xFF2DBE68),
        shape: BoxShape.circle,
        border: Border.all(
          color: adaptive(context, Colors.white, AppDarkColors.bg),
          width: 1.5,
        ),
      ),
    );
  }
}

class _PeerAvatarWithPresence extends StatelessWidget {
  const _PeerAvatarWithPresence({required this.peer, required this.size});

  final FamiliaChatPeer peer;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          _PeerAvatar(peer: peer, size: size),
          if (peer.online)
            const Positioned(
              right: 1,
              bottom: 1,
              child: _OnlineDot(),
            ),
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF008EA0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF008EA0),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FamilyMessageBubble extends StatelessWidget {
  const _FamilyMessageBubble({required this.message, super.key});

  final _FamilyChatMessage message;

  @override
  Widget build(BuildContext context) {
    final hasImage = message.imageDataUrl?.isNotEmpty == true;
    final isMine = message.fromMe;
    final bubbleColor = isMine
        ? adaptive(context, const Color(0xFFCBEFF3), AppDarkColors.tintedInfo)
        : adaptive(context, Colors.white, AppDarkColors.surfaceAlt);
    final borderColor = isMine
        ? const Color(0xFF9BD3DC)
        : adaptive(context, const Color(0xFFE5EAEC), AppDarkColors.border);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 325),
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 11, 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasImage) ...[
                  _ChatMessageImage(dataUrl: message.imageDataUrl!),
                  if (message.text.isNotEmpty) const SizedBox(height: 8),
                ],
                if (message.text.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: adaptive(
                          context,
                          const Color(0xFF25363C),
                          AppDarkColors.textPrimary,
                        ),
                        fontSize: 15,
                        height: 1.28,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF9AA6AA),
                            AppDarkColors.textMuted),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      _MessageTicks(status: message.status),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMessageImage extends StatefulWidget {
  const _ChatMessageImage({required this.dataUrl});

  final String dataUrl;

  @override
  State<_ChatMessageImage> createState() => _ChatMessageImageState();
}

class _ChatMessageImageState extends State<_ChatMessageImage> {
  late Uint8List? _imageBytes = _decodeDataUrl(widget.dataUrl);

  @override
  void didUpdateWidget(covariant _ChatMessageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataUrl != widget.dataUrl) {
      _imageBytes = _decodeDataUrl(widget.dataUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _imageBytes;
    if (imageBytes == null) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: 'Abrir foto enviada',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showFullScreenImage(context, imageBytes),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            imageBytes,
            width: 222,
            height: 150,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

class _PendingFamilyImagePreview extends StatelessWidget {
  const _PendingFamilyImagePreview({
    required this.imageDataUrl,
    required this.onRemove,
  });

  final String imageDataUrl;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeDataUrl(imageDataUrl);
    if (bytes == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              adaptive(context, const Color(0xFF9BD3DC), AppDarkColors.border),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child:
                Image.memory(bytes, width: 50, height: 50, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Foto anexada',
              style: TextStyle(
                color: adaptive(
                  context,
                  const Color(0xFF003B4F),
                  AppDarkColors.textPrimary,
                ),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remover foto',
            onPressed: onRemove,
            icon: Icon(
              Icons.close_rounded,
              color: adaptive(
                context,
                const Color(0xFF003B4F),
                AppDarkColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageTicks extends StatelessWidget {
  const _MessageTicks({required this.status});

  final _MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final delivered = status != _MessageStatus.pending;
    final color = status == _MessageStatus.read
        ? const Color(0xFF1E9BDE)
        : const Color(0xFF8FA1A7);

    return Icon(
      delivered ? Icons.done_all_rounded : Icons.done_rounded,
      size: 16,
      color: color,
    );
  }
}

class _FamilyInput extends StatelessWidget {
  const _FamilyInput({
    required this.controller,
    required this.hasImage,
    required this.onImage,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool hasImage;
  final VoidCallback onImage;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: adaptive(context, Colors.white, AppDarkColors.surface),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF9BD3DC)),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Enviar foto',
                  onPressed: onImage,
                  icon: Icon(
                    hasImage ? Icons.image_rounded : Icons.attach_file_rounded,
                    color: const Color(0xFF49A9BA),
                    size: 20,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Digite uma mensagem...',
                      hintStyle: TextStyle(
                        color: adaptive(
                          context,
                          const Color(0xFFC4CDD1),
                          AppDarkColors.textMuted,
                        ),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextStyle(
                      color: adaptive(
                        context,
                        const Color(0xFF22343B),
                        AppDarkColors.textPrimary,
                      ),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Áudio',
                  onPressed: () {},
                  icon: const Icon(
                    Icons.mic_none_rounded,
                    color: Color(0xFF49A9BA),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: const Color(0xFF9BDDE8),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onSend,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.send_rounded,
                color: Color(0xFF007C8A),
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FamiliaChatPeer {
  const FamiliaChatPeer({
    required this.id,
    required this.name,
    required this.role,
    this.photoUrl,
    this.status,
    this.isFichaOwner = false,
    this.sexo,
    this.online = false,
    this.lastSeenAt,
    this.unreadCount = 0,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  factory FamiliaChatPeer.fromMembro(MembroFicha membro) {
    return FamiliaChatPeer(
      id: membro.usuarioId,
      name: membro.nome,
      role: membro.funcao ?? 'cuidador',
      photoUrl: membro.urlFoto,
      status: membro.status,
      isFichaOwner: membro.eCriador,
      sexo: membro.sexo,
      online: membro.online,
      lastSeenAt: membro.ultimoVistoEm,
      unreadCount: membro.mensagensNaoLidas,
      lastMessagePreview: membro.ultimaMensagemPreview,
      lastMessageAt: membro.ultimaMensagemEm,
    );
  }

  final String id;
  final String name;
  final String role;
  final String? photoUrl;
  final String? status;
  final bool isFichaOwner;
  final String? sexo;
  final bool online;
  final DateTime? lastSeenAt;
  final int unreadCount;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  String get roleLabel =>
      isFichaOwner ? 'Responsável' : _roleLabel(role, sexo: sexo);
  String get displayName => _shortName(name);
  bool get removedFromFicha => _statusIndicaRemocaoDaFicha(status);
}

enum _MessageStatus { pending, delivered, read }

class _FamilyChatMessage {
  const _FamilyChatMessage({
    required this.id,
    required this.text,
    required this.fromMe,
    required this.createdAt,
    this.imageDataUrl,
    this.status = _MessageStatus.delivered,
  });

  factory _FamilyChatMessage.fromJson(Map<String, dynamic> json) {
    return _FamilyChatMessage(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      fromMe: _boolValue(json['fromMe']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      imageDataUrl: json['imageDataUrl']?.toString(),
      status: _messageStatusFromJson(json['status']),
    );
  }

  factory _FamilyChatMessage.fromApi(
    FamiliaChatMensagem message,
    String usuarioId,
  ) {
    final fromMe = message.fromMe(usuarioId);
    return _FamilyChatMessage(
      id: message.id,
      text: message.conteudo,
      fromMe: fromMe,
      createdAt: message.criadoEm,
      imageDataUrl: message.imageDataUrl,
      status: fromMe && message.lidoEm != null
          ? _MessageStatus.read
          : _MessageStatus.delivered,
    );
  }

  final String id;
  final String text;
  final bool fromMe;
  final DateTime createdAt;
  final String? imageDataUrl;
  final _MessageStatus status;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'fromMe': fromMe,
      'createdAt': createdAt.toIso8601String(),
      if (imageDataUrl != null) 'imageDataUrl': imageDataUrl,
      'status': status.name,
    };
  }
}

_MessageStatus _messageStatusFromJson(Object? value) {
  final normalized = value?.toString();
  return _MessageStatus.values.firstWhere(
    (status) => status.name == normalized,
    orElse: () => _MessageStatus.delivered,
  );
}

bool _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'sim';
}

class _ChatSummary {
  const _ChatSummary({required this.preview, required this.updatedAt});

  final String preview;
  final DateTime updatedAt;
}

bool _samePeers(List<FamiliaChatPeer> first, List<FamiliaChatPeer> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (!_samePeer(first[index], second[index])) return false;
  }
  return true;
}

bool _samePeer(FamiliaChatPeer first, FamiliaChatPeer second) {
  final sameLastSeen =
      first.online && second.online || first.lastSeenAt == second.lastSeenAt;
  return first.id == second.id &&
      first.name == second.name &&
      first.role == second.role &&
      first.photoUrl == second.photoUrl &&
      first.status == second.status &&
      first.isFichaOwner == second.isFichaOwner &&
      first.sexo == second.sexo &&
      first.online == second.online &&
      sameLastSeen &&
      first.unreadCount == second.unreadCount &&
      first.lastMessagePreview == second.lastMessagePreview &&
      first.lastMessageAt == second.lastMessageAt;
}

bool _sameSummaries(
  Map<String, _ChatSummary> first,
  Map<String, _ChatSummary> second,
) {
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    final other = second[entry.key];
    if (other == null ||
        other.preview != entry.value.preview ||
        other.updatedAt != entry.value.updatedAt) {
      return false;
    }
  }
  return true;
}

bool _sameMessages(
  List<_FamilyChatMessage> first,
  List<_FamilyChatMessage> second,
) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    final current = first[index];
    final updated = second[index];
    if (current.id != updated.id ||
        current.text != updated.text ||
        current.fromMe != updated.fromMe ||
        current.createdAt != updated.createdAt ||
        current.imageDataUrl != updated.imageDataUrl ||
        current.status != updated.status) {
      return false;
    }
  }
  return true;
}

Future<void> _showFullScreenImage(BuildContext context, Uint8List imageBytes) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.memory(imageBytes, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                tooltip: 'Fechar foto',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

int _comparePeersByLastMessage(FamiliaChatPeer first, FamiliaChatPeer second) {
  final firstMessageAt = first.lastMessageAt;
  final secondMessageAt = second.lastMessageAt;
  if (firstMessageAt == null && secondMessageAt != null) return 1;
  if (firstMessageAt != null && secondMessageAt == null) return -1;
  if (firstMessageAt != null && secondMessageAt != null) {
    final comparison = secondMessageAt.compareTo(firstMessageAt);
    if (comparison != 0) return comparison;
  }
  return first.name.compareTo(second.name);
}

class _PendingImage {
  const _PendingImage({
    required this.mimeType,
    required this.base64Data,
  });

  final String mimeType;
  final String base64Data;

  String get dataUrl => 'data:$mimeType;base64,$base64Data';
}

class _FamilyChatStore {
  const _FamilyChatStore._();

  static Future<List<_FamilyChatMessage>> loadMessages({
    required String ownerId,
    required String idosoId,
    required String peerId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(ownerId, idosoId, peerId));
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_FamilyChatMessage.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveMessages({
    required String ownerId,
    required String idosoId,
    required String peerId,
    required List<_FamilyChatMessage> messages,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(ownerId, idosoId, peerId),
      jsonEncode(messages.map((message) => message.toJson()).toList()),
    );
  }

  static Future<void> clearMessages({
    required String ownerId,
    required String idosoId,
    required String peerId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(ownerId, idosoId, peerId));
  }

  static Future<_ChatSummary> summary({
    required String ownerId,
    required String idosoId,
    required String peerId,
    required String fallback,
  }) async {
    final messages = await loadMessages(
      ownerId: ownerId,
      idosoId: idosoId,
      peerId: peerId,
    );
    if (messages.isEmpty) {
      return _ChatSummary(preview: fallback, updatedAt: DateTime.now());
    }
    final last = messages.last;
    return _ChatSummary(
      preview: last.text.isNotEmpty ? last.text : 'Foto enviada',
      updatedAt: last.createdAt,
    );
  }

  static String _key(String ownerId, String idosoId, String peerId) {
    return 'familia_chat_v1:$ownerId:$idosoId:$peerId';
  }
}

String _fallbackPreview(FamiliaChatPeer peer) {
  final firstName = peer.name.split(' ').first;
  return peer.role == 'familiar'
      ? '$firstName acompanha a ficha com você.'
      : '$firstName também cuida desta ficha.';
}

String _shortName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length <= 2) return parts.join(' ');
  return '${parts.first} ${parts.last}';
}

String _presenceText(FamiliaChatPeer peer) {
  if (peer.online) return 'Online';
  final lastMessageAt = peer.lastSeenAt;
  if (lastMessageAt == null) return 'Visto por último indisponível';

  final now = DateTime.now();
  final sameDay = lastMessageAt.year == now.year &&
      lastMessageAt.month == now.month &&
      lastMessageAt.day == now.day;
  final time = _formatTime(lastMessageAt);
  return sameDay
      ? 'Visto por último às $time'
      : 'Visto por último ${_formatDate(lastMessageAt)} às $time';
}

String _roleLabel(String? role, {String? sexo}) {
  final normalized = role?.toLowerCase().trim();
  if (normalized == 'familiar') return 'Familiar';
  return sexo?.trim().toLowerCase() == 'feminino' ? 'Cuidadora' : 'Cuidador';
}

bool _statusIndicaRemocaoDaFicha(String? status) {
  final normalized = status?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return false;

  return normalized == 'removido' ||
      normalized == 'revogado' ||
      normalized == 'recusado' ||
      normalized == 'inativo';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '??';
  final first = parts.first[0];
  final second = parts.length > 1 ? parts[1][0] : '';
  return (first + second).toUpperCase();
}

String _formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}';
}

String _mimeTypeFromPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

Uint8List? _decodeDataUrl(String? value) {
  if (value == null || value.isEmpty) return null;
  final commaIndex = value.indexOf(',');
  if (commaIndex == -1) return null;

  try {
    return base64Decode(value.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}
