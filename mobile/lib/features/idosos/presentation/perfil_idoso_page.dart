import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';

class PerfilIdosoPage extends ConsumerWidget {
  const PerfilIdosoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idoso = ref.watch(selectedIdosoProvider);

    if (idoso == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/idosos'),
            child: const Text('Selecionar idoso'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ficha do Idoso',
                            style: TextStyle(
                              color: Color(0xFF073248),
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          SizedBox(height: 5),
                          SizedBox(
                            width: 74,
                            height: 3,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFF2BA8BA),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(999)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar ficha',
                      onPressed: () =>
                          context.go('/idosos/editar?from=idoso-perfil'),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Color(0xFF2BA8BA),
                        size: 34,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Perfil do cuidador',
                      onPressed: () => context.go('/perfil?from=idoso-perfil'),
                      icon: const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF2BA8BA),
                        size: 34,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _HeroCard(idoso: idoso),
                const SizedBox(height: 14),
                if (idoso.tipoSanguineo?.isNotEmpty == true)
                  _InfoCard(
                    icon: Icons.water_drop,
                    title: 'Tipo Sanguineo',
                    value: idoso.tipoSanguineo!,
                  ),
                if (idoso.condicoes.isNotEmpty)
                  _InfoCard(
                    icon: Icons.monitor_heart_rounded,
                    title: 'Doencas',
                    value: idoso.condicoes.join(' e '),
                  ),
                if (idoso.contatoEmergenciaNome?.isNotEmpty == true ||
                    idoso.contatoEmergenciaTelefone?.isNotEmpty == true)
                  _InfoCard(
                    icon: Icons.phone_rounded,
                    title: 'Contato de Emergencia',
                    value: [
                      if (idoso.contatoEmergenciaNome?.isNotEmpty == true)
                        '${idoso.contatoEmergenciaNome}${idoso.contatoEmergenciaParentesco?.isNotEmpty == true ? ' (${idoso.contatoEmergenciaParentesco})' : ''}',
                      if (idoso.contatoEmergenciaTelefone?.isNotEmpty == true)
                        _formatPhone(idoso.contatoEmergenciaTelefone!),
                    ].join('\n'),
                  ),
                if (idoso.alergiasRestricoes?.isNotEmpty == true)
                  _InfoCard(
                    icon: Icons.warning_amber_rounded,
                    title: 'Alergias',
                    value: _joinWithAnd(_splitList(idoso.alergiasRestricoes!)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AcessosIdosoPage extends StatelessWidget {
  const AcessosIdosoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.group_outlined,
                  color: Color(0xFF2BA8BA),
                  size: 58,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Acessos',
                  style: TextStyle(
                    color: Color(0xFF073248),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Essa funcionalidade vai chegar em breve.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5E6B73), fontSize: 16),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Voltar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.idoso});

  final dynamic idoso;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataImageBytes(idoso.urlFoto);
    return Container(
      height: 122,
      padding: const EdgeInsets.fromLTRB(26, 13, 20, 13),
      decoration: BoxDecoration(
        color: const Color(0xFF3CAAB6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 42,
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
                    size: 52,
                  )
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  idoso.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(height: 1.5, width: 98, color: Colors.white),
                if (idoso.idade > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${idoso.idade} anos',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              color: Color(0xFFE7F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF0D899D), size: 39),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF249CB0),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
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

List<String> _splitList(String value) {
  return value
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _joinWithAnd(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  if (items.length == 2) return '${items[0]} e ${items[1]}';
  return '${items.sublist(0, items.length - 1).join(', ')} e ${items.last}';
}

String _formatPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 11) {
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7, 11)}';
  }
  if (digits.length >= 10) {
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6, 10)}';
  }
  return value;
}
