import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/staggered_entry.dart';

class SelecionarIdosoPage extends ConsumerWidget {
  const SelecionarIdosoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idososAsync = ref.watch(idososDoUsuarioProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Header(),
                    const SizedBox(height: 5),
                    const Text(
                      'Fichas',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 23,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Selecione a ficha do idoso que deseja\nacompanhar agora',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF4C4C4C),
                        fontSize: 12.5,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Expanded(
                      child: idososAsync.when(
                        data: (idosos) => _FichasGrid(idosos: idosos),
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF238FA1),
                          ),
                        ),
                        error: (_, __) => _ErrorState(
                          onRetry: () => ref.invalidate(
                            idososDoUsuarioProvider,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/idosos/convite'),
                        icon: const Icon(Icons.mail_outline_rounded, size: 19),
                        label: const Text('Entrar com convite'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0E7890),
                          side: const BorderSide(
                            color: Color(0xFF2CA0B4),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
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

class ConviteIdosoPage extends StatelessWidget {
  const ConviteIdosoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 26),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => context.go('/idosos'),
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              color: Color(0xFF238FA1),
                              size: 32,
                            ),
                          ),
                        ),
                        const Text(
                          'ello',
                          style: TextStyle(
                            color: Color(0xFF0E6F7E),
                            fontSize: 34,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Entrar com convite',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 23,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use o codigo enviado por outro cuidador\npara acessar uma ficha compartilhada',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF4C4C4C),
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _InviteCard(),
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Text(
          'ello',
          style: TextStyle(
            color: Color(0xFF0E6F7E),
            fontSize: 34,
            fontWeight: FontWeight.w300,
            letterSpacing: 0,
            height: 1,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () => context.go('/perfil?from=idosos'),
            borderRadius: BorderRadius.circular(99),
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFD1F2F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF238FA1),
                size: 25,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FichasGrid extends ConsumerWidget {
  const _FichasGrid({required this.idosos});

  final List<IdosoResumo> idosos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: const Color(0xFF238FA1),
      onRefresh: () async {
        ref.invalidate(idososDoUsuarioProvider);
        await ref.read(idososDoUsuarioProvider.future);
      },
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        itemCount: idosos.length + 1,
        itemBuilder: (context, index) {
          if (index == idosos.length) {
            return StaggeredEntry(
              index: index,
              child: _AddFichaCard(onTap: () => context.go('/idosos/cadastro')),
            );
          }

          final idoso = idosos[index];
          return StaggeredEntry(
            index: index,
            child: _IdosoPoster(
              idoso: idoso,
              onTap: () {
                ref.read(selectedIdosoProvider.notifier).state = idoso;
                context.go('/dashboard');
              },
            ),
          );
        },
      ),
    );
  }
}

const _posterGradients = [
  [Color(0xFF0E6F7E), Color(0xFF3CAAB6)],
  [Color(0xFF2A5D8A), Color(0xFF5AA3D0)],
  [Color(0xFF7B4FA0), Color(0xFFB07FD1)],
  [Color(0xFFC06B3E), Color(0xFFE8A868)],
  [Color(0xFF3E8A5E), Color(0xFF7ECB93)],
  [Color(0xFFB2455F), Color(0xFFE38299)],
];

List<Color> _gradientFor(String seed) {
  final hash = seed.codeUnits.fold<int>(0, (acc, unit) => acc + unit);
  return _posterGradients[hash % _posterGradients.length];
}

class _IdosoPoster extends StatefulWidget {
  const _IdosoPoster({required this.idoso, required this.onTap});

  final IdosoResumo idoso;
  final VoidCallback onTap;

  @override
  State<_IdosoPoster> createState() => _IdosoPosterState();
}

class _IdosoPosterState extends State<_IdosoPoster> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final idoso = widget.idoso;
    final image = _avatarImage(idoso.urlFoto);
    final gradient = _gradientFor(idoso.id.isEmpty ? idoso.nome : idoso.id);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                Image(image: image, fit: BoxFit.cover)
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _iniciais(idoso.nome),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 46,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                      ],
                      stops: const [0.55, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _primeiroNome(idoso.nome),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (idoso.idade > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${idoso.idade} anos',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFichaCard extends StatefulWidget {
  const _AddFichaCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AddFichaCard> createState() => _AddFichaCardState();
}

class _AddFichaCardState extends State<_AddFichaCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: _OutlinedCard(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC8EAF0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Color(0xFF17324D),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Adicionar\nficha',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF17324D),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF37AFC3),
          width: 1.6,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: child,
    );
  }
}

class _InviteCard extends StatefulWidget {
  const _InviteCard();

  @override
  State<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<_InviteCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF37AFC3)),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Codigo de convite',
            style: TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Digite o codigo aqui',
              hintStyle: const TextStyle(
                color: Color(0xFF9B9B9B),
                fontSize: 13,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: Color(0xFF37AFC3)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Entrada por convite sera liberada em breve.'),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3CB1C3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Acessar ficha'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        const Icon(
          Icons.wifi_off_rounded,
          color: Color(0xFF238FA1),
          size: 42,
        ),
        const SizedBox(height: 10),
        const Text(
          'Nao foi possivel carregar as fichas.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF4C4C4C), fontSize: 12),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0E7890),
            ),
            child: const Text('Tentar novamente'),
          ),
        ),
      ],
    );
  }
}

ImageProvider? _avatarImage(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('data:image')) {
    final commaIndex = url.indexOf(',');
    if (commaIndex == -1) return null;
    try {
      return MemoryImage(base64Decode(url.substring(commaIndex + 1)));
    } catch (_) {
      return null;
    }
  }
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  return NetworkImage(url);
}

String _primeiroNome(String nome) {
  final trimmed = nome.trim();
  if (trimmed.isEmpty) return 'Sem nome';
  return trimmed.split(RegExp(r'\s+')).first;
}

String _iniciais(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+'));
  if (partes.isEmpty || partes.first.isEmpty) return '?';
  final primeira = partes.first[0];
  final ultima = partes.length > 1 ? partes.last[0] : '';
  return '$primeira$ultima'.toUpperCase();
}
