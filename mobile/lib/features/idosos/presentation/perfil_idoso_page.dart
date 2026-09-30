import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/staggered_entry.dart';

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
            child: const Text('Selecionar pessoa idosa'),
          ),
        ),
      );
    }

    final personText = idoso.elderText;

    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFAFAFA), AppDarkColors.bg),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: [
                AppPageHeader(
                  title: 'Perfil da pessoa idosa',
                  trailing: PopupMenuButton<_PerfilIdosoMenuAction>(
                    tooltip: 'Opcoes da ficha',
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Color(0xFF0E6F7E),
                    ),
                    onSelected: (action) {
                      switch (action) {
                        case _PerfilIdosoMenuAction.edit:
                          context.go('/idosos/editar?from=idoso-perfil');
                        case _PerfilIdosoMenuAction.share:
                          _showCompartilharSheet(context, idoso.id);
                        case _PerfilIdosoMenuAction.caregiverProfile:
                          context.go('/perfil?from=idoso-perfil');
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _PerfilIdosoMenuAction.edit,
                        child: _PerfilIdosoMenuItem(
                          icon: Icons.edit_rounded,
                          label: 'Editar ficha',
                        ),
                      ),
                      PopupMenuItem(
                        value: _PerfilIdosoMenuAction.share,
                        child: _PerfilIdosoMenuItem(
                          icon: Icons.ios_share_rounded,
                          label: 'Compartilhar ficha',
                        ),
                      ),
                      PopupMenuItem(
                        value: _PerfilIdosoMenuAction.caregiverProfile,
                        child: _PerfilIdosoMenuItem(
                          icon: Icons.person_rounded,
                          label: 'Perfil do cuidador',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                StaggeredEntry(index: 0, child: _HeroCard(idoso: idoso)),
                const SizedBox(height: 16),
                StaggeredEntry(
                  index: 1,
                  child: _EmergencyActionsCard(idoso: idoso),
                ),
                const SizedBox(height: 16),
                if (idoso.tipoSanguineo?.isNotEmpty == true)
                  StaggeredEntry(
                    index: 2,
                    child: _InfoCard(
                      icon: Icons.water_drop_rounded,
                      title: 'Tipo sanguíneo',
                      value: idoso.tipoSanguineo!,
                    ),
                  ),
                if (idoso.sexo?.isNotEmpty == true)
                  StaggeredEntry(
                    index: 3,
                    child: _InfoCard(
                      icon: Icons.badge_rounded,
                      title: 'Sexo',
                      value: idoso.sexo!,
                    ),
                  ),
                if (idoso.condicoes.isNotEmpty)
                  StaggeredEntry(
                    index: 4,
                    child: _InfoCard(
                      icon: Icons.monitor_heart_rounded,
                      title: 'Condições de saúde',
                      value: idoso.condicoes.join(' e '),
                    ),
                  ),
                if (idoso.contatoEmergenciaNome?.isNotEmpty == true ||
                    idoso.contatoEmergenciaTelefone?.isNotEmpty == true)
                  StaggeredEntry(
                    index: 5,
                    child: _InfoCard(
                      icon: Icons.phone_rounded,
                      title: 'Contato de emergência',
                      value: [
                        if (idoso.contatoEmergenciaNome?.isNotEmpty == true)
                          '${idoso.contatoEmergenciaNome}${idoso.contatoEmergenciaParentesco?.isNotEmpty == true ? ' (${idoso.contatoEmergenciaParentesco})' : ''}',
                        if (idoso.contatoEmergenciaTelefone?.isNotEmpty == true)
                          _formatPhone(idoso.contatoEmergenciaTelefone!),
                      ].join('\n'),
                    ),
                  ),
                if (idoso.alergiasRestricoes?.isNotEmpty == true)
                  StaggeredEntry(
                    index: 6,
                    child: _InfoCard(
                      icon: Icons.warning_amber_rounded,
                      title: 'Alergias ${personText.of}',
                      value:
                          _joinWithAnd(_splitList(idoso.alergiasRestricoes!)),
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

enum _PerfilIdosoMenuAction { edit, share, caregiverProfile }

class _PerfilIdosoMenuItem extends StatelessWidget {
  const _PerfilIdosoMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0E6F7E)),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

void _showCompartilharSheet(BuildContext context, String idosoId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CompartilharFichaSheet(idosoId: idosoId),
  );
}

class _CompartilharFichaSheet extends ConsumerStatefulWidget {
  const _CompartilharFichaSheet({required this.idosoId});

  final String idosoId;

  @override
  ConsumerState<_CompartilharFichaSheet> createState() =>
      _CompartilharFichaSheetState();
}

class _CompartilharFichaSheetState
    extends ConsumerState<_CompartilharFichaSheet> {
  bool _loading = true;
  String? _codigo;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _gerarCodigo();
  }

  Future<void> _gerarCodigo() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final usuarioId = ref.read(authSessionProvider)?.id;
      final codigo = await ref.read(apiClientProvider).gerarConviteIdoso(
            idosoId: widget.idosoId,
            convidadoPorId: usuarioId,
          );
      if (!mounted) return;
      setState(() {
        _codigo = codigo;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _erro = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível gerar o código. Tente novamente.';
        _loading = false;
      });
    }
  }

  Future<void> _copiarCodigo() async {
    final codigo = _codigo;
    if (codigo == null) return;
    await Clipboard.setData(ClipboardData(text: codigo));
    if (!mounted) return;
    _ignoreBottomMessage();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        decoration: BoxDecoration(
          color: adaptive(context, Colors.white, AppDarkColors.surfaceElevated),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: adaptive(
                    context, const Color(0xFFE0E0E0), AppDarkColors.border),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2BA8BA), Color(0xFF0E6F7E)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Compartilhar ficha',
              style: TextStyle(
                color: adaptive(context, const Color(0xFF073248),
                    AppDarkColors.textPrimary),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Peça para a outra pessoa abrir o Ello, tocar em\n'
              '"Adicionar ficha" e escolher "Sou o cuidador". Ela pode ler o QR Code ou digitar o código.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: adaptive(context, const Color(0xFF5E6B73),
                    AppDarkColors.textSecondary),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Color(0xFF2BA8BA),
                        ),
                      ),
                    )
                  : _erro != null
                      ? Column(
                          key: const ValueKey('erro'),
                          children: [
                            Text(
                              _erro!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFC0392B),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton(
                              onPressed: _gerarCodigo,
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        )
                      : Column(
                          key: const ValueKey('codigo'),
                          children: [
                            Semantics(
                              label: 'QR Code do convite da ficha',
                              child: Container(
                                width: 190,
                                height: 190,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFF8BD2DC),
                                  ),
                                ),
                                child: QrImageView(
                                  data: _codigo ?? '',
                                  version: QrVersions.auto,
                                  padding: EdgeInsets.zero,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Color(0xFF0D6E80),
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Color(0xFF17324D),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: _copiarCodigo,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  color: adaptive(
                                      context,
                                      const Color(0xFFE7F4F6),
                                      AppDarkColors.tintedInfo),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: adaptive(
                                        context,
                                        const Color(0xFF8BD2DC),
                                        AppDarkColors.border),
                                  ),
                                ),
                                child: Text(
                                  _codigo ?? '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF0D6E80),
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 6,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: FilledButton.icon(
                                onPressed: _copiarCodigo,
                                icon: const Icon(Icons.copy_rounded, size: 19),
                                label: const Text('Copiar código'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0E6F7E),
                                  foregroundColor: Colors.white,
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
                            const SizedBox(height: 10),
                            Text(
                              'Válido por 7 dias e para um único uso.',
                              style: TextStyle(
                                color: adaptive(
                                    context,
                                    const Color(0xFF9B9B9B),
                                    AppDarkColors.textMuted),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyActionsCard extends StatelessWidget {
  const _EmergencyActionsCard({required this.idoso});

  static const _samuPhone = '192';

  final IdosoResumo? idoso;

  @override
  Widget build(BuildContext context) {
    final emergencyPhone = idoso?.contatoEmergenciaTelefone?.trim();
    final emergencyName = idoso?.contatoEmergenciaNome?.trim();
    final hasEmergencyContact =
        emergencyPhone != null && emergencyPhone.isNotEmpty;
    final contactLabel = emergencyName != null && emergencyName.isNotEmpty
        ? 'Contato: $emergencyName'
        : 'Contato de emergência';

    return _InfoPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Emergência',
            style: TextStyle(
              color: adaptive(
                context,
                const Color(0xFF073248),
                AppDarkColors.textPrimary,
              ),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: () => _callPhone(context, _samuPhone),
              icon: const Icon(Icons.local_hospital_outlined, size: 20),
              label: const Text('Ligar SAMU 192'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC0392B),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: hasEmergencyContact
                  ? () => _callPhone(context, emergencyPhone)
                  : null,
              icon: const Icon(Icons.contact_phone_outlined, size: 20),
              label: Text(
                hasEmergencyContact ? contactLabel : 'Contato não cadastrado',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0B6985),
                disabledForegroundColor: adaptive(
                  context,
                  const Color(0xFF8FA4AA),
                  AppDarkColors.textSecondary,
                ),
                side: BorderSide(
                  color: hasEmergencyContact
                      ? const Color(0xFF238FA1)
                      : adaptive(
                          context,
                          const Color(0xFFD9E2E5),
                          AppDarkColors.border,
                        ),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        border: Border.all(
          color:
              adaptive(context, const Color(0xFFE4EFF1), AppDarkColors.border),
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
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
      padding: const EdgeInsets.fromLTRB(24, 13, 20, 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2BA8BA), Color(0xFF0E6F7E)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E6F7E).withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 2,
              ),
            ),
            child: CircleAvatar(
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
                      size: 50,
                    )
                  : null,
            ),
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
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                if (idoso.idade > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${idoso.idade} anos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              adaptive(context, const Color(0xFFE4EFF1), AppDarkColors.border),
        ),
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
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE7F4F6), Color(0xFFCFEBF0)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF0D899D), size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF249CB0),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF17324D),
                        AppDarkColors.textPrimary),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
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

Future<void> _callPhone(BuildContext context, String phone) async {
  final digits = _phoneNumberForCall(phone);
  if (digits.isEmpty) {
    _ignoreBottomMessage();
    return;
  }

  final uri = Uri(scheme: 'tel', path: digits);
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (launched && context.mounted) {
    _ignoreBottomMessage();
    return;
  }

  if (!launched && context.mounted) {
    _ignoreBottomMessage();
  }
}

String _phoneNumberForCall(String phone) {
  final normalized = phone.trim();
  if (normalized.startsWith('+')) {
    return '+${normalized.substring(1).replaceAll(RegExp(r'\D'), '')}';
  }

  return normalized.replaceAll(RegExp(r'\D'), '');
}

void _ignoreBottomMessage() {}
