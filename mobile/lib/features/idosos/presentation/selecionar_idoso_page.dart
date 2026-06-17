import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';

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
                    const SizedBox(height: 25),
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
                      height: 40,
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 26),
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
                    const Spacer(),
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
      child: GridView.count(
        physics: const AlwaysScrollableScrollPhysics(),
        crossAxisCount: 2,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.9,
        children: [
          for (final idoso in idosos)
            _CompactGridCell(
              child: _IdosoCard(
                idoso: idoso,
                onTap: () {
                  ref.read(selectedIdosoProvider.notifier).state = idoso;
                  context.go('/dashboard');
                },
              ),
            ),
          _CompactGridCell(
            child: _AddFichaCard(onTap: () => context.go('/idosos/cadastro')),
          ),
        ],
      ),
    );
  }
}

class _IdosoCard extends StatelessWidget {
  const _IdosoCard({
    required this.idoso,
    required this.onTap,
  });

  final IdosoResumo idoso;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _FichaTile(
      onTap: onTap,
      child: Stack(
        children: [
          Positioned(
            right: 7,
            top: 7,
            child: Icon(
              Icons.more_vert_rounded,
              color: const Color(0xFF0E7890).withValues(alpha: 0.95),
              size: 19,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: const Color(0xFFD1F2F6),
                  backgroundImage: _avatarImage(idoso.urlFoto),
                  child: idoso.urlFoto == null || idoso.urlFoto!.isEmpty
                      ? const Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFF238FA1),
                          size: 52,
                        )
                      : null,
                ),
                const SizedBox(height: 9),
                Text(
                  _primeiroNome(idoso.nome),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactGridCell extends StatelessWidget {
  const _CompactGridCell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.82,
      heightFactor: 0.82,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

class _AddFichaCard extends StatelessWidget {
  const _AddFichaCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _FichaTile(
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFC8EAF0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFF17324D),
                size: 45,
              ),
            ),
            const SizedBox(height: 13),
            const Text(
              'Adicionar ficha',
              style: TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FichaTile extends StatelessWidget {
  const _FichaTile({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFF37AFC3), width: 1),
          ),
          child: child,
        ),
      ),
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
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  return NetworkImage(url);
}

String _primeiroNome(String nome) {
  final trimmed = nome.trim();
  if (trimmed.isEmpty) return 'Sem nome';
  return trimmed.split(RegExp(r'\s+')).first;
}
