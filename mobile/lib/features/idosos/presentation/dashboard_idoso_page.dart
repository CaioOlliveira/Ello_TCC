import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';

class DashboardIdosoPage extends ConsumerWidget {
  const DashboardIdosoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idoso = ref.watch(selectedIdosoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'ello',
                    style: TextStyle(
                      color: Color(0xFF0E6F7E),
                      fontSize: 42,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0,
                      height: 1,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () => context.go('/perfil?from=dashboard'),
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD1F2F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFF238FA1),
                          size: 27,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _IdosoHeroCard(
                nome: idoso?.nome ?? 'Selecione uma ficha',
                idade: idoso?.idade,
                foto: idoso?.urlFoto,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdosoHeroCard extends StatelessWidget {
  const _IdosoHeroCard({
    required this.nome,
    this.idade,
    this.foto,
  });

  final String nome;
  final int? idade;
  final String? foto;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataImageBytes(foto);

    return Container(
      height: 125,
      padding: const EdgeInsets.fromLTRB(26, 14, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF3CAAB6),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 43,
            backgroundColor: const Color(0xFFD1F2F6),
            backgroundImage: bytes != null
                ? MemoryImage(bytes)
                : foto != null && foto!.startsWith('http')
                    ? NetworkImage(foto!) as ImageProvider
                    : null,
            child: bytes == null && (foto == null || !foto!.startsWith('http'))
                ? const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF238FA1),
                    size: 52,
                  )
                : null,
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(width: 92, height: 1.5, color: Colors.white),
                const SizedBox(height: 8),
                if (idade != null && idade! > 0)
                  Row(
                    children: [
                      const Icon(
                        Icons.cake_outlined,
                        color: Colors.white,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$idade anos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
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
