import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  final _imagePicker = ImagePicker();
  final _speech = stt.SpeechToText();
  final _messages = <_ChatMessage>[];
  var _conversations = <AiConversa>[];
  AiConversa? _activeConversation;
  AiRelatorioInicial? _initialReport;
  int? _initialReportIndex;
  _PendingImage? _pendingImage;
  var _loading = false;
  var _loadingHistory = false;
  var _openingConversation = false;
  var _loadingReport = false;
  var _listening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConversations());
  }

  @override
  void dispose() {
    _speech.stop();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final usuario = ref.read(authSessionProvider);
    if (usuario == null || usuario.id.isEmpty) return;
    final idosoId = ref.read(selectedIdosoProvider)?.id;

    setState(() => _loadingHistory = true);
    try {
      final conversas = await ref.read(apiClientProvider).listarConversasIa(
            usuarioId: usuario.id,
            idosoId: idosoId,
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
    if (_loading || _openingConversation || _loadingReport) return;

    setState(() {
      _messages.clear();
      _initialReport = null;
      _initialReportIndex = null;
      _pendingImage = null;
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
      _initialReport = null;
      _initialReportIndex = null;
      _pendingImage = null;
      _messages.clear();
    });

    try {
      final mensagens = await ref.read(apiClientProvider).listarMensagensIa(
            conversaId: conversa.id,
            usuarioId: usuario.id,
            idosoId: ref.read(selectedIdosoProvider)?.id,
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
    if ((text.isEmpty && _pendingImage == null) ||
        _loading ||
        _openingConversation ||
        _loadingReport) {
      return;
    }

    if (_shouldShowInitialPrompt && _isAffirmative(text)) {
      _questionController.clear();
      await _loadInitialReport(userText: text);
      return;
    }
    final wasInitialPrompt = _shouldShowInitialPrompt;

    final usuario = ref.read(authSessionProvider);
    if (usuario == null || usuario.id.isEmpty) {
      _addErrorMessage('Entre na sua conta para usar a IA.');
      return;
    }

    setState(() {
      if (wasInitialPrompt) {
        _messages
            .add(_ChatMessage(text: _initialPromptText(), fromUser: false));
      }
      _messages.add(
        _ChatMessage(
          text: text.isEmpty ? 'Analise esta imagem.' : text,
          fromUser: true,
          imageDataUrl: _pendingImage?.dataUrl,
        ),
      );
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
            mensagem: text.isEmpty ? 'Analise esta imagem.' : text,
            imagem: _pendingImage == null
                ? null
                : {
                    'mimeType': _pendingImage!.mimeType,
                    'base64': _pendingImage!.base64Data,
                  },
          );
      if (!mounted) return;

      setState(() {
        _pendingImage = null;
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

  Future<void> _pickImage(ImageSource source) async {
    if (_loading || _openingConversation || _loadingReport) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1280,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final mimeType = _mimeTypeFromPath(image.name);
      if (!mounted) return;
      setState(() {
        _pendingImage = _PendingImage(
          mimeType: mimeType,
          base64Data: base64Encode(bytes),
        );
      });
    } catch (_) {
      if (!mounted) return;
      _addErrorMessage('Nao foi possivel anexar a imagem.');
    }
  }

  Future<void> _showImageOptions() async {
    if (_loading || _openingConversation || _loadingReport) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
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

    if (source != null) await _pickImage(source);
  }

  Future<void> _toggleListening() async {
    if (_loading || _openingConversation || _loadingReport) return;

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final available = await _speech.initialize();
    if (!available) {
      _addErrorMessage('Nao foi possivel iniciar o microfone.');
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: 'pt_BR',
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (result) {
        _questionController.text = result.recognizedWords;
        _questionController.selection = TextSelection.fromPosition(
          TextPosition(offset: _questionController.text.length),
        );
        if (result.finalResult && mounted) {
          setState(() => _listening = false);
        }
      },
    );
  }

  Future<void> _loadInitialReport({String userText = 'Ola, quero sim!'}) async {
    if (_loading || _openingConversation || _loadingReport) return;

    final usuario = ref.read(authSessionProvider);
    final idoso = ref.read(selectedIdosoProvider);
    if (usuario == null || usuario.id.isEmpty) {
      _addErrorMessage('Entre na sua conta para usar a IA.');
      return;
    }
    if (idoso == null || idoso.id.isEmpty) {
      _addErrorMessage('Selecione um idoso para gerar o relatorio.');
      return;
    }

    setState(() {
      if (_messages.isEmpty) {
        _messages
            .add(_ChatMessage(text: _initialPromptText(), fromUser: false));
      }
      _messages.add(_ChatMessage(text: userText, fromUser: true));
      _loadingReport = true;
    });

    try {
      final relatorio =
          await ref.read(apiClientProvider).obterRelatorioInicialIa(
                usuarioId: usuario.id,
                idosoId: idoso.id,
              );
      if (!mounted) return;
      setState(() {
        _initialReport = relatorio;
        _initialReportIndex = _messages.length;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      _addErrorMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _addErrorMessage('Nao foi possivel carregar o relatorio da IA.');
    } finally {
      if (mounted) setState(() => _loadingReport = false);
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
    ref.listen<IdosoResumo?>(selectedIdosoProvider, (previous, next) {
      if (previous?.id == next?.id) return;
      setState(() {
        _messages.clear();
        _conversations = const [];
        _activeConversation = null;
        _initialReport = null;
        _initialReportIndex = null;
        _pendingImage = null;
      });
      _loadConversations();
    });

    final title = _activeConversation?.titulo ?? 'CoraIA';
    final idoso = ref.watch(selectedIdosoProvider);
    final showInitialPrompt = _shouldShowInitialPrompt;
    final showBusy = _loading || _openingConversation || _loadingReport;
    final reportVisible = _initialReport != null && _initialReportIndex != null;
    final reportIndex =
        reportVisible ? _initialReportIndex!.clamp(0, _messages.length) : null;
    final reportExtra = reportVisible ? 1 : 0;
    final itemCount = _messages.length + reportExtra + (showBusy ? 1 : 0);

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
                    child: showInitialPrompt
                        ? _InitialAnalysisPrompt(
                            idosoName: idoso?.nome,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                            itemCount: itemCount,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (showBusy && index == itemCount - 1) {
                                return const _TypingBubble();
                              }

                              if (reportVisible && index == reportIndex) {
                                return _MessagePopIn(
                                  child: _InitialReportCard(
                                    report: _initialReport!,
                                  ),
                                );
                              }

                              final messageIndex = reportVisible &&
                                      reportIndex != null &&
                                      index > reportIndex
                                  ? index - 1
                                  : index;

                              if (messageIndex >= 0 &&
                                  messageIndex < _messages.length) {
                                return _MessagePopIn(
                                  child: _MessageBubble(
                                    message: _messages[messageIndex],
                                  ),
                                );
                              }

                              return const SizedBox.shrink();
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                    child: Column(
                      children: [
                        if (_pendingImage != null)
                          _PendingImagePreview(
                            imageDataUrl: _pendingImage!.dataUrl,
                            onRemove: () => setState(() {
                              _pendingImage = null;
                            }),
                          ),
                        _QuestionInput(
                          controller: _questionController,
                          loading: showBusy,
                          listening: _listening,
                          hasImage: _pendingImage != null,
                          onImage: _showImageOptions,
                          onMic: _toggleListening,
                          onSubmitted: _sendMessage,
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

  bool get _shouldShowInitialPrompt =>
      _messages.isEmpty &&
      _initialReport == null &&
      !_loading &&
      !_openingConversation &&
      !_loadingReport;

  String _initialPromptText() {
    final idoso = ref.read(selectedIdosoProvider);
    final name = idoso == null || idoso.nome.trim().isEmpty
        ? 'o idoso selecionado'
        : idoso.nome.trim();
    return 'Ola, cuidador! Analisei os dados de $name nos ultimos dias e preparei o relatorio de saude geral. Quer dar uma olhada?';
  }
}

bool _isAffirmative(String text) {
  final normalized = text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\sáàâãéêíóôõúç]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return normalized == 'sim' ||
      normalized == 'quero' ||
      normalized == 'quero sim' ||
      normalized == 'olá quero sim' ||
      normalized == 'ola quero sim' ||
      normalized.contains('quero sim') ||
      normalized.contains('pode mostrar') ||
      normalized.contains('mostrar resumo') ||
      normalized.contains('ver resumo') ||
      normalized.contains('ver relatorio') ||
      normalized.contains('ver relatório');
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

class _InitialAnalysisPrompt extends StatelessWidget {
  const _InitialAnalysisPrompt({
    required this.idosoName,
  });

  final String? idosoName;

  @override
  Widget build(BuildContext context) {
    final name = idosoName == null || idosoName!.trim().isEmpty
        ? 'o idoso selecionado'
        : idosoName!.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CoraAvatar(size: 44),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9E0E3),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Ola, cuidador! Analisei os dados de $name nos ultimos dias e preparei o relatorio de saude geral. Quer dar uma olhada?',
                    style: const TextStyle(
                      color: Color(0xFF101820),
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InitialReportCard extends StatelessWidget {
  const _InitialReportCard({required this.report});

  final AiRelatorioInicial report;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF33A7BA)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            for (var index = 0; index < report.secoes.length; index++) ...[
              _ReportSection(section: report.secoes[index]),
              if (index < report.secoes.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFF79C6D2),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.section});

  final AiRelatorioSecao section;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Icon(
            _sectionIcon(section.tipo),
            color: const Color(0xFF087F8C),
            size: 42,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Color(0xFF101820),
                fontSize: 12.4,
                height: 1.24,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(
                  text: '${section.titulo}: ',
                  style: const TextStyle(
                    color: Color(0xFF087F8C),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(text: section.texto),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

IconData _sectionIcon(String tipo) {
  switch (tipo) {
    case 'glicemia':
      return Icons.water_drop_rounded;
    case 'humor':
      return Icons.sentiment_satisfied_alt_rounded;
    default:
      return Icons.tips_and_updates_rounded;
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.fromUser,
    this.isError = false,
    this.imageDataUrl,
  });

  final String text;
  final bool fromUser;
  final bool isError;
  final String? imageDataUrl;
}

class _MessagePopIn extends StatelessWidget {
  const _MessagePopIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, builtChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: builtChild,
          ),
        );
      },
      child: child,
    );
  }
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

    final imageBytes = _decodeDataUrl(message.imageDataUrl);
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 270),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border:
            message.isError ? Border.all(color: const Color(0xFFD95B4F)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                imageBytes,
                width: 230,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            message.text,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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

class _PendingImage {
  const _PendingImage({
    required this.mimeType,
    required this.base64Data,
  });

  final String mimeType;
  final String base64Data;

  String get dataUrl => 'data:$mimeType;base64,$base64Data';
}

class _PendingImagePreview extends StatelessWidget {
  const _PendingImagePreview({
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF9BD3DC)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              bytes,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Imagem anexada para analise',
              style: TextStyle(
                color: Color(0xFF003B4F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remover imagem',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, color: Color(0xFF003B4F)),
          ),
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFD9E0E3),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 10,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              final phase = (_controller.value - index * 0.2) % 1.0;
              final bounce = phase < 0.5
                  ? Curves.easeOut.transform(phase * 2)
                  : Curves.easeIn.transform((1 - phase) * 2);
              return Transform.translate(
                offset: Offset(0, -bounce * 5),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF087F8C),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _QuestionInput extends StatelessWidget {
  const _QuestionInput({
    required this.controller,
    required this.loading,
    required this.listening,
    required this.hasImage,
    required this.onImage,
    required this.onMic,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool loading;
  final bool listening;
  final bool hasImage;
  final VoidCallback onImage;
  final VoidCallback onMic;
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
          IconButton(
            tooltip: 'Enviar foto',
            onPressed: loading ? null : onImage,
            icon: Icon(
              hasImage
                  ? Icons.image_rounded
                  : Icons.add_photo_alternate_rounded,
              color: const Color(0xFF111111),
              size: 21,
            ),
          ),
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
            tooltip: listening ? 'Parar ditado' : 'Falar',
            onPressed: loading ? null : onMic,
            icon: Icon(
              listening ? Icons.mic_rounded : Icons.mic_none_rounded,
              color:
                  listening ? const Color(0xFF087F8C) : const Color(0xFF111111),
              size: 21,
            ),
          ),
          IconButton(
            tooltip: 'Enviar',
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
