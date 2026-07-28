import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/staggered_entry.dart';

class PermissoesFichasPage extends ConsumerWidget {
  const PermissoesFichasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fichasAsync = ref.watch(fichasAdministradasProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StaggeredEntry(
                      index: 0,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: () => context.go('/perfil'),
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
                    ),
                    const SizedBox(height: 12),
                    const StaggeredEntry(
                      index: 1,
                      child: Text(
                        'Permissões',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const StaggeredEntry(
                      index: 2,
                      child: Text(
                        'Fichas em que voce é administrador. Toque em uma '
                        'para gerenciar acessos e permissões.',
                        style: TextStyle(
                          color: Color(0xFF4C4C4C),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: fichasAsync.when(
                        data: (fichas) => fichas.isEmpty
                            ? const _EmptyAdminState()
                            : _FichasAdministradasList(fichas: fichas),
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF238FA1),
                          ),
                        ),
                        error: (_, __) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                color: Color(0xFF238FA1),
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Nao foi possivel carregar as fichas.',
                                style: TextStyle(
                                  color: Color(0xFF4C4C4C),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () => ref.invalidate(
                                  fichasAdministradasProvider,
                                ),
                                child: const Text('Tentar novamente'),
                              ),
                            ],
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

class _FichasAdministradasList extends StatelessWidget {
  const _FichasAdministradasList({required this.fichas});

  final List<IdosoResumo> fichas;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: fichas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final idoso = fichas[index];
        return StaggeredEntry(
          index: index,
          child: _FichaAdminCard(idoso: idoso),
        );
      },
    );
  }
}

class _FichaAdminCard extends StatelessWidget {
  const _FichaAdminCard({required this.idoso});

  final IdosoResumo idoso;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataImageBytes(idoso.urlFoto);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/idoso/acessos?idosoId=${idoso.id}'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4EFF1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFD1F2F6),
                backgroundImage: bytes != null
                    ? MemoryImage(bytes)
                    : idoso.urlFoto != null && idoso.urlFoto!.startsWith('http')
                        ? NetworkImage(idoso.urlFoto!) as ImageProvider
                        : null,
                child: bytes == null &&
                        (idoso.urlFoto == null ||
                            !idoso.urlFoto!.startsWith('http'))
                    ? const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF238FA1),
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      idoso.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF17324D),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (idoso.idade > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${idoso.idade} anos',
                        style: const TextStyle(
                          color: Color(0xFF8A8A8A),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CB2B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAdminState extends StatelessWidget {
  const _EmptyAdminState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                color: Color(0xFFE7F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: Color(0xFF2BA8BA),
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma ficha administrada',
              style: TextStyle(
                color: Color(0xFF073248),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Voce ainda não é administrador de nenhuma ficha. '
              'Fichas que voce criar aparecerão aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF5E6B73), fontSize: 12.5, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

Uint8List? _dataImageBytes(String? value) {
  if (value == null || !value.startsWith('data:image')) return null;
  final commaIndex = value.indexOf(',');
  if (commaIndex == -1) return null;
  try {
    return base64Decode(value.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}
