import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final idoso = ref.read(selectedIdosoProvider);
    final usuario = ref.read(authSessionProvider);

    if (idoso == null || idoso.id.isEmpty) {
      setState(() {
        _loading = false;
        _peers = const [];
        _summaries = const {};
        _error = 'Selecione uma ficha para abrir o chat.';
      });
      return;
    }

    if (usuario == null || usuario.id.isEmpty) {
      setState(() {
        _loading = false;
        _peers = const [];
        _summaries = const {};
        _error = 'Entre na sua conta para conversar.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final participantes = await ref
          .read(apiClientProvider)
          .listarParticipantes(idosoId: idoso.id);
      final peers = participantes
          .where((membro) => membro.usuarioId != usuario.id)
          .map(FamiliaChatPeer.fromMembro)
          .where((peer) => peer.id.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final summaries = <String, _ChatSummary>{};
      for (final peer in peers) {
        summaries[peer.id] = await _loadSummary(
          ownerId: usuario.id,
          idosoId: idoso.id,
          peer: peer,
        );
      }
      if (!mounted) return;
      setState(() {
        _peers = peers;
        _summaries = summaries;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Nao foi possivel carregar os contatos.';
      });
    }
  }

  Future<_ChatSummary> _loadSummary({
    required String ownerId,
    required String idosoId,
    required FamiliaChatPeer peer,
  }) async {
    try {
      final apiMessages =
          await ref.read(apiClientProvider).listarMensagensFamilia(
                idosoId: idosoId,
                usuarioId: ownerId,
                outroUsuarioId: peer.id,
              );
      final messages = apiMessages
          .map((message) => _FamilyChatMessage.fromApi(message, ownerId))
          .toList();
      if (messages.isNotEmpty) {
        await _FamilyChatStore.saveMessages(
          ownerId: ownerId,
          idosoId: idosoId,
          peerId: peer.id,
          messages: messages,
        );
        return _ChatSummary.fromMessage(messages.last);
      }
    } catch (_) {
      // Se a API estiver indisponivel, a tela segue com o historico local.
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
              child: RefreshIndicator(
                color: const Color(0xFF1598AA),
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 102),
                  children: [
                    const _FamiliaChatHeader(),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
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
                                  'Chat da Familia',
                                  style: TextStyle(
                                    color: adaptive(
                                        context,
                                        const Color(0xFF00808F),
                                        AppDarkColors.textPrimary),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Converse com as pessoas que cuidam junto com voce',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: adaptive(
                                        context,
                                        const Color(0xFF64757C),
                                        AppDarkColors.textSecondary),
                                    fontSize: 10.5,
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
                    Text(
                      'Conversas',
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF00808F),
                            AppDarkColors.textPrimary),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _ConversationPanel(
                      loading: _loading,
                      error: _error,
                      peers: _peers,
                      summaries: _summaries,
                      onTap: _openChat,
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

  @override
  void initState() {
    super.initState();
    _peer = widget.initialPeer ??
        FamiliaChatPeer(
          id: widget.peerId,
          name: 'Contato',
          role: 'cuidador',
        );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMessages());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final usuario = ref.read(authSessionProvider);
    final idoso = ref.read(selectedIdosoProvider);
    if (usuario == null || idoso == null) return;

    var messages = <_FamilyChatMessage>[];
    try {
      final apiMessages =
          await ref.read(apiClientProvider).listarMensagensFamilia(
                idosoId: idoso.id,
                usuarioId: usuario.id,
                outroUsuarioId: _peer.id,
              );
      messages = apiMessages
          .map((message) => _FamilyChatMessage.fromApi(message, usuario.id))
          .toList();
      if (messages.isNotEmpty) {
        await _FamilyChatStore.saveMessages(
          ownerId: usuario.id,
          idosoId: idoso.id,
          peerId: _peer.id,
          messages: messages,
        );
      } else {
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

    if (!mounted) return;
    setState(() => _messages = messages);
    await _persistMessages();
    _scrollToEnd();
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
        const SnackBar(content: Text('Nao foi possivel anexar a imagem.')),
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
                  _ChatDetailHeader(peer: _peer),
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
                          return _FamilyMessageBubble(
                            message: _messages[index - 1],
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
          'ello',
          style: TextStyle(
            color: adaptive(
                context, const Color(0xFF007C8A), AppDarkColors.textPrimary),
            fontSize: 28,
            height: 1,
            fontWeight: FontWeight.w400,
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
          ? const SizedBox(
              height: 118,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1598AA)),
              ),
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
                            unreadCount: index == 0 ? 1 : 0,
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
    return SizedBox(
      height: 118,
      child: Center(
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
          padding: const EdgeInsets.fromLTRB(4, 9, 0, 9),
          child: Row(
            children: [
              _PeerAvatar(peer: peer, size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            peer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adaptive(context, const Color(0xFF142B31),
                                  AppDarkColors.textPrimary),
                              fontSize: 13,
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
                            fontSize: 10.5,
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
                        fontSize: 11,
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
                      fontSize: 9.5,
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
  const _ChatDetailHeader({required this.peer});

  final FamiliaChatPeer peer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 14, 0),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Voltar',
                  onPressed: () => context.go('/chat'),
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFF008EA0),
                    size: 28,
                  ),
                ),
              ),
              Text(
                'ello',
                style: TextStyle(
                  color: adaptive(
                    context,
                    const Color(0xFF007C8A),
                    AppDarkColors.textPrimary,
                  ),
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              _PeerAvatar(peer: peer, size: 54),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            peer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adaptive(context, const Color(0xFF006B78),
                                  AppDarkColors.textPrimary),
                              fontSize: 16,
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
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Online',
                      style: TextStyle(
                        color: adaptive(
                          context,
                          const Color(0xFF66767B),
                          AppDarkColors.textSecondary,
                        ),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: adaptive(
            context, const Color(0xFFEAF8FA), AppDarkColors.tintedInfo),
        borderRadius: BorderRadius.circular(size >= 50 ? 9 : 7),
        image: bytes == null
            ? peer.photoUrl != null && peer.photoUrl!.startsWith('http')
                ? DecorationImage(
                    image: NetworkImage(peer.photoUrl!),
                    fit: BoxFit.cover,
                  )
                : null
            : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
      child: bytes == null &&
              (peer.photoUrl == null || !peer.photoUrl!.startsWith('http'))
          ? Text(
              initials,
              style: TextStyle(
                color: const Color(0xFF007C8A),
                fontSize: size >= 50 ? 20 : 15,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
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
  const _FamilyMessageBubble({required this.message});

  final _FamilyChatMessage message;

  @override
  Widget build(BuildContext context) {
    final imageBytes = _decodeDataUrl(message.imageDataUrl);
    final isMine = message.fromMe;
    final bubbleColor = isMine
        ? adaptive(context, const Color(0xFFCBEFF3), AppDarkColors.tintedInfo)
        : adaptive(context, Colors.white, AppDarkColors.surfaceAlt);
    final borderColor = isMine
        ? const Color(0xFF9BD3DC)
        : adaptive(context, const Color(0xFFE5EAEC), AppDarkColors.border);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
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
            if (imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  imageBytes,
                  width: 222,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
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
                    fontSize: 11.5,
                    height: 1.25,
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
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.done_all_rounded,
                    size: 12,
                    color: Color(0xFF52AFC0),
                  ),
                ],
              ],
            ),
          ],
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
            height: 38,
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
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextStyle(
                      color: adaptive(
                        context,
                        const Color(0xFF22343B),
                        AppDarkColors.textPrimary,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Audio',
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
              width: 42,
              height: 42,
              child: Icon(
                Icons.send_rounded,
                color: Color(0xFF007C8A),
                size: 22,
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
  });

  factory FamiliaChatPeer.fromMembro(MembroFicha membro) {
    return FamiliaChatPeer(
      id: membro.usuarioId,
      name: membro.nome,
      role: membro.funcao ?? 'cuidador',
      photoUrl: membro.urlFoto,
    );
  }

  final String id;
  final String name;
  final String role;
  final String? photoUrl;

  String get roleLabel => _roleLabel(role);
}

class _FamilyChatMessage {
  const _FamilyChatMessage({
    required this.id,
    required this.text,
    required this.fromMe,
    required this.createdAt,
    this.imageDataUrl,
  });

  factory _FamilyChatMessage.fromJson(Map<String, dynamic> json) {
    return _FamilyChatMessage(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      fromMe: json['fromMe'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      imageDataUrl: json['imageDataUrl']?.toString(),
    );
  }

  factory _FamilyChatMessage.fromApi(
    FamiliaChatMensagem message,
    String usuarioId,
  ) {
    return _FamilyChatMessage(
      id: message.id,
      text: message.conteudo,
      fromMe: message.fromMe(usuarioId),
      createdAt: message.criadoEm,
      imageDataUrl: message.imageDataUrl,
    );
  }

  final String id;
  final String text;
  final bool fromMe;
  final DateTime createdAt;
  final String? imageDataUrl;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'fromMe': fromMe,
      'createdAt': createdAt.toIso8601String(),
      if (imageDataUrl != null) 'imageDataUrl': imageDataUrl,
    };
  }
}

class _ChatSummary {
  const _ChatSummary({required this.preview, required this.updatedAt});

  factory _ChatSummary.fromMessage(_FamilyChatMessage message) {
    return _ChatSummary(
      preview: message.text.isNotEmpty ? message.text : 'Foto enviada',
      updatedAt: message.createdAt,
    );
  }

  final String preview;
  final DateTime updatedAt;
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
      ? '$firstName acompanha a ficha com voce.'
      : '$firstName tambem cuida desta ficha.';
}

String _roleLabel(String? role) {
  final normalized = role?.toLowerCase().trim();
  if (normalized == 'familiar') return 'Familiar';
  return 'Cuidador';
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
