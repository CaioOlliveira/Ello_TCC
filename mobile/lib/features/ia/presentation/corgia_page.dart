import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class CorgiaPage extends ConsumerStatefulWidget {
  const CorgiaPage({super.key});

  @override
  ConsumerState<CorgiaPage> createState() => _CorgiaPageState();
}

class _CorgiaPageState extends ConsumerState<CorgiaPage> {
  final _questionController = TextEditingController();
  final _messages = <_ChatMessage>[];
  var _conversations = <AiConversa>[];
  AiConversa? _activeConversation;
  var _loading = false;
  var _loadingHistory = false;
  var _openingConversation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConversations());
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final usuario = ref.read(authSessionProvider);
    if (usuario == null || usuario.id.isEmpty) return;

    setState(() => _loadingHistory = true);
    try {
      final conversas = await ref.read(apiClientProvider).listarConversasIa(
            usuarioId: usuario.id,
          );
      if (!mounted) return;
      setState(() => _conversations = conversas);
    } catch (_) {
      if (!mounted) return;
      setState(() => _conversations = const []);
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<AiConversa?> _ensureConversation() async {
    if (_activeConversation != null) return _activeConversation;

    final usuario = ref.read(authSessionProvider);
    if (usuario == null || usuario.id.isEmpty) {
      _addErrorMessage('Entre na sua conta para usar a IA.');
      return null;
    }

    final idoso = ref.read(selectedIdosoProvider);
    final conversa = await ref.read(apiClientProvider).criarConversaIa(
          usuarioId: usuario.id,
          idosoId: idoso?.id,
        );

    setState(() {
      _activeConversation = conversa;
      _conversations = [conversa, ..._conversations];
    });
    return conversa;
  }

  Future<void> _startNewChat() async {
    if (_loading || _openingConversation) return;

    setState(() {
      _messages.clear();
      _activeConversation = null;
    });
  }

  Future<void> _openConversation(AiConversa conversa) async {
    final usuario = ref.read(authSessionProvider);
    if (usuario == null || usuario.id.isEmpty || _openingConversation) return;

    Navigator.of(context).maybePop();
    setState(() {
      _openingConversation = true;
      _activeConversation = conversa;
      _messages.clear();
    });

    try {
      final mensagens = await ref.read(apiClientProvider).listarMensagensIa(
            conversaId: conversa.id,
            usuarioId: usuario.id,
          );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(
            mensagens.map(
              (mensagem) => _ChatMessage(
                text: _cleanAiText(mensagem.conteudo),
                fromUser: mensagem.fromUser,
              ),
            ),
          );
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      _addErrorMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _addErrorMessage('Nao foi possivel abrir este chat.');
    } finally {
      if (mounted) setState(() => _openingConversation = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _questionController.text.trim();
    if (text.isEmpty || _loading || _openingConversation) return;

    final usuario = ref.read(authSessionProvider);
    if (usuario == null || usuario.id.isEmpty) {
      _addErrorMessage('Entre na sua conta para usar a IA.');
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _questionController.clear();
      _loading = true;
    });

    try {
      final conversa = await _ensureConversation();
      if (conversa == null) return;

      final idoso = ref.read(selectedIdosoProvider);
      final resultado = await ref.read(apiClientProvider).perguntarIa(
            usuarioId: usuario.id,
            conversaId: conversa.id,
            idosoId: idoso?.id,
            mensagem: text,
          );
      if (!mounted) return;

      setState(() {
        _messages.add(
          _ChatMessage(
            text: resultado.resposta.isEmpty
                ? 'Nao consegui gerar uma resposta agora. Tente novamente.'
                : _cleanAiText(resultado.resposta),
            fromUser: false,
          ),
        );
        if (resultado.conversa != null) {
          _activeConversation = resultado.conversa;
          _upsertConversation(resultado.conversa!);
        }
      });
      await _loadConversations();
    } on ApiException catch (error) {
      if (!mounted) return;
      _addErrorMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _addErrorMessage('Nao foi possivel falar com a IA agora.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _upsertConversation(AiConversa conversa) {
    final updated = [
      conversa,
      ..._conversations.where((item) => item.id != conversa.id),
    ];
    _conversations = updated;
  }

  void _addErrorMessage(String message) {
    setState(() {
      _messages.add(
        _ChatMessage(
          text: message.isEmpty
              ? 'Nao foi possivel falar com a IA agora.'
              : message,
          fromUser: false,
          isError: true,
        ),
      );
    });
  }

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _HistorySheet(
          conversations: _conversations,
          activeConversationId: _activeConversation?.id,
          loading: _loadingHistory,
          onNewChat: () {
            Navigator.of(context).pop();
            _startNewChat();
          },
          onOpenConversation: _openConversation,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _activeConversation?.titulo ?? 'CoraIA';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _ChatHeader(
                    title: title,
                    loading: _loadingHistory || _openingConversation,
                    onHistory: _showHistory,
                    onNewChat: _startNewChat,
                  ),
                  Expanded(
                    child: _messages.isEmpty &&
                            !_loading &&
                            !_openingConversation
                        ? const _EmptyChat()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                            itemCount: _messages.length +
                                (_loading || _openingConversation ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if ((_loading || _openingConversation) &&
                                  index == _messages.length) {
                                return const _TypingBubble();
                              }

                              return _MessageBubble(message: _messages[index]);
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                    child: _QuestionInput(
                      controller: _questionController,
                      loading: _loading || _openingConversation,
                      onSubmitted: _sendMessage,
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

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.loading,
    required this.onHistory,
    required this.onNewChat,
  });

  final String title;
  final bool loading;
  final VoidCallback onHistory;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5EAEC))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Historico',
            onPressed: loading ? null : onHistory,
            icon: const Icon(Icons.history_rounded, color: Color(0xFF003B4F)),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF003B4F),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Novo chat',
            onPressed: loading ? null : onNewChat,
            icon:
                const Icon(Icons.add_comment_rounded, color: Color(0xFF003B4F)),
          ),
        ],
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({
    required this.conversations,
    required this.activeConversationId,
    required this.loading,
    required this.onNewChat,
    required this.onOpenConversation,
  });

  final List<AiConversa> conversations;
  final String? activeConversationId;
  final bool loading;
  final VoidCallback onNewChat;
  final ValueChanged<AiConversa> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupConversationsByDay(conversations);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFD0D8DC),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chats',
                      style: TextStyle(
                        color: Color(0xFF003B4F),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onNewChat,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF087F8C),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Novo'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF087F8C),
                      ),
                    )
                  : conversations.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum chat salvo ainda.',
                            style: TextStyle(
                              color: Color(0xFF6F8288),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                          children: [
                            for (final entry in grouped.entries) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    color: Color(0xFF6F8288),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              for (final conversa in entry.value)
                                _HistoryTile(
                                  conversa: conversa,
                                  selected: conversa.id == activeConversationId,
                                  onTap: () => onOpenConversation(conversa),
                                ),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.conversa,
    required this.selected,
    required this.onTap,
  });

  final AiConversa conversa;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      selected: selected,
      selectedTileColor: const Color(0xFFE4F3F5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF087F8C)),
      title: Text(
        conversa.titulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        _formatTime(conversa.atualizadoEm),
        style: const TextStyle(color: Color(0xFF6F8288)),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CoraAvatar(size: 74),
            SizedBox(height: 16),
            Text(
              'Como posso ajudar no cuidado hoje?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF003B4F),
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.fromUser,
    this.isError = false,
  });

  final String text;
  final bool fromUser;
  final bool isError;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final alignment =
        message.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = message.fromUser
        ? const Color(0xFF3A7287)
        : message.isError
            ? const Color(0xFFFFE5E2)
            : const Color(0xFFD9E0E3);
    final textColor = message.fromUser ? Colors.white : const Color(0xFF101820);

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 270),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border:
            message.isError ? Border.all(color: const Color(0xFFD95B4F)) : null,
      ),
      child: Text(
        message.text,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    if (message.fromUser) {
      return Align(alignment: alignment, child: bubble);
    }

    return Align(
      alignment: alignment,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CoraAvatar(size: 44),
          const SizedBox(width: 8),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _CoraAvatar extends StatelessWidget {
  const _CoraAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/cora_avatar.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CoraAvatar(size: 44),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD9E0E3),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF087F8C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionInput extends StatelessWidget {
  const _QuestionInput({
    required this.controller,
    required this.loading,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.only(left: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !loading,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmitted(),
              decoration: const InputDecoration(
                hintText: 'Pergunte ao CoraIA',
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: loading ? null : onSubmitted,
            icon: Icon(
              loading ? Icons.hourglass_top_rounded : Icons.send_rounded,
              color: const Color(0xFF111111),
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, List<AiConversa>> _groupConversationsByDay(
  List<AiConversa> conversations,
) {
  final grouped = <String, List<AiConversa>>{};
  for (final conversa in conversations) {
    final label = _formatDay(conversa.atualizadoEm);
    grouped.putIfAbsent(label, () => []).add(conversa);
  }
  return grouped;
}

String _formatDay(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;

  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Ontem';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _cleanAiText(String text) {
  return text
      .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (match) => match.group(1)!)
      .replaceAllMapped(RegExp(r'__(.*?)__'), (match) => match.group(1)!)
      .replaceAllMapped(
        RegExp(r'(^|\s)\*([^*\n]+)\*(?=\s|[.,!?;:]|$)'),
        (match) => '${match.group(1)}${match.group(2)}',
      )
      .replaceAllMapped(RegExp(r'`([^`]+)`'), (match) => match.group(1)!)
      .replaceAll(RegExp(r'^\s*[*-]\s+', multiLine: true), '- ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
