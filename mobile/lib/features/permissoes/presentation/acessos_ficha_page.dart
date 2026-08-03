import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/staggered_entry.dart';

class AcessosFichaPage extends ConsumerStatefulWidget {
  const AcessosFichaPage({super.key, this.idosoId});

  final String? idosoId;

  @override
  ConsumerState<AcessosFichaPage> createState() => _AcessosFichaPageState();
}

class _AcessosFichaPageState extends ConsumerState<AcessosFichaPage> {
  bool _loading = true;
  String? _erro;
  IdosoResumo? _idoso;
  ConviteFicha? _convite;
  List<MembroFicha> _participantes = const [];
  List<SolicitacaoPendente> _pendentes = const [];
  String? _acaoEmAndamentoId;

  String? get _idosoId => widget.idosoId ?? ref.read(selectedIdosoProvider)?.id;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final idosoId = _idosoId;
    if (idosoId == null || idosoId.isEmpty) {
      setState(() {
        _loading = false;
        _erro = 'Nenhuma ficha selecionada.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _erro = null;
    });

    try {
      final usuarioId = ref.read(authSessionProvider)?.id;
      final api = ref.read(apiClientProvider);
      final resultados = await Future.wait([
        api.buscarIdoso(idosoId: idosoId),
        api.obterConviteFicha(idosoId: idosoId, usuarioId: usuarioId),
        api.listarParticipantes(idosoId: idosoId),
        api.listarSolicitacoesPendentes(idosoId: idosoId),
      ]);

      if (!mounted) return;
      setState(() {
        _idoso = resultados[0] as IdosoResumo;
        _convite = resultados[1] as ConviteFicha;
        _participantes = resultados[2] as List<MembroFicha>;
        _pendentes = resultados[3] as List<SolicitacaoPendente>;
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
        _erro = 'Nao foi possivel carregar os acessos dessa ficha.';
        _loading = false;
      });
    }
  }

  Future<void> _copiarCodigo() async {
    final codigo = _convite?.codigo;
    if (codigo == null || codigo.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: codigo));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Codigo copiado.')),
    );
  }

  Future<void> _aprovar(SolicitacaoPendente solicitacao) async {
    setState(() => _acaoEmAndamentoId = solicitacao.id);
    try {
      await ref.read(apiClientProvider).aprovarSolicitacao(
            membroId: solicitacao.id,
            usuarioId: ref.read(authSessionProvider)?.id,
          );
      await _carregar();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _acaoEmAndamentoId = null);
    }
  }

  Future<void> _negar(SolicitacaoPendente solicitacao) async {
    setState(() => _acaoEmAndamentoId = solicitacao.id);
    try {
      await ref.read(apiClientProvider).negarSolicitacao(
            membroId: solicitacao.id,
            usuarioId: ref.read(authSessionProvider)?.id,
          );
      await _carregar();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _acaoEmAndamentoId = null);
    }
  }

  Future<void> _alterarCargo(MembroFicha membro, String cargo) async {
    if (membro.id == null) return;
    setState(() => _acaoEmAndamentoId = membro.id);
    try {
      await ref.read(apiClientProvider).atualizarMembro(
            membroId: membro.id!,
            funcao: cargo,
            atualizadoPorId: ref.read(authSessionProvider)?.id,
          );
      await _carregar();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _acaoEmAndamentoId = null);
    }
  }

  Future<void> _alternarAdmin(MembroFicha membro) async {
    if (membro.id == null) return;
    setState(() => _acaoEmAndamentoId = membro.id);
    try {
      await ref.read(apiClientProvider).atualizarMembro(
            membroId: membro.id!,
            eAdministrador: !membro.eAdministrador,
            atualizadoPorId: ref.read(authSessionProvider)?.id,
          );
      await _carregar();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _acaoEmAndamentoId = null);
    }
  }

  Future<void> _removerAcesso(MembroFicha membro) async {
    if (membro.id == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover acesso'),
        content: Text('Remover o acesso de ${membro.nome} a essa ficha?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC0392B),
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _acaoEmAndamentoId = membro.id);
    try {
      await ref.read(apiClientProvider).revogarAcessoMembro(
            membroId: membro.id!,
            usuarioId: ref.read(authSessionProvider)?.id,
          );
      await _carregar();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _acaoEmAndamentoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backRoute = widget.idosoId != null ? '/permissoes' : '/idoso/perfil';
    final title = _idoso == null
        ? 'Acessos da ficha'
        : 'Acessos da ficha ${_idoso!.elderText.of}';

    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFCFCFC), AppDarkColors.bg),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 14, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.go(backRoute),
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            color: Color(0xFF238FA1),
                            size: 32,
                          ),
                        ),
                        Text(
                          title,
                          style: TextStyle(
                            color: adaptive(context, Colors.black,
                                AppDarkColors.textPrimary),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF238FA1)),
      );
    }

    if (_erro != null || _idoso == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFF238FA1),
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                _erro ?? 'Nao foi possivel carregar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF4C4C4C),
                      AppDarkColors.textSecondary),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _carregar,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final idoso = _idoso!;
    final totalParticipantes = _participantes.length;

    return RefreshIndicator(
      color: const Color(0xFF238FA1),
      onRefresh: _carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
        children: [
          StaggeredEntry(
            index: 0,
            child: _FichaResumoCard(
              idoso: idoso,
              totalParticipantes: totalParticipantes,
            ),
          ),
          const SizedBox(height: 20),
          const StaggeredEntry(
            index: 1,
            child: _SectionTitle('Compartilhar ficha'),
          ),
          const SizedBox(height: 8),
          StaggeredEntry(
            index: 2,
            child: _CompartilharCard(
              convite: _convite,
              onCopiar: _copiarCodigo,
            ),
          ),
          if (_pendentes.isNotEmpty) ...[
            const SizedBox(height: 20),
            const StaggeredEntry(
              index: 3,
              child: _SectionTitle('Convites pendentes'),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _pendentes.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: StaggeredEntry(
                  index: 4 + i,
                  child: _PendenteCard(
                    solicitacao: _pendentes[i],
                    loading: _acaoEmAndamentoId == _pendentes[i].id,
                    onAceitar: () => _aprovar(_pendentes[i]),
                    onNegar: () => _negar(_pendentes[i]),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          const StaggeredEntry(
            index: 10,
            child: _SectionTitle('Participantes'),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _participantes.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StaggeredEntry(
                index: 11 + i,
                child: _ParticipanteCard(
                  membro: _participantes[i],
                  loading: _acaoEmAndamentoId == _participantes[i].id,
                  onTap: _participantes[i].id == null
                      ? null
                      : () async {
                          await context.push(
                            '/permissoes/detalhes?membroId=${_participantes[i].id}',
                          );
                          if (mounted) _carregar();
                        },
                  onSelecionarCargo: (cargo) =>
                      _alterarCargo(_participantes[i], cargo),
                  onAlternarAdmin: () => _alternarAdmin(_participantes[i]),
                  onRemover: () => _removerAcesso(_participantes[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: adaptive(
            context, const Color(0xFF073248), AppDarkColors.textPrimary),
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FichaResumoCard extends StatelessWidget {
  const _FichaResumoCard({
    required this.idoso,
    required this.totalParticipantes,
  });

  final IdosoResumo idoso;
  final int totalParticipantes;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataImageBytes(idoso.urlFoto);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              adaptive(context, const Color(0xFFE4EFF1), AppDarkColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: adaptive(
                context, const Color(0xFFD1F2F6), AppDarkColors.tintedInfo),
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
                    size: 34,
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
                    color: Color(0xFF0D6E80),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (idoso.idade > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${idoso.idade} anos',
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF8A8A8A), AppDarkColors.textSecondary),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              const Icon(
                Icons.groups_rounded,
                color: Color(0xFF2BA8BA),
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                '$totalParticipantes ${totalParticipantes == 1 ? 'participante' : 'participantes'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF5E6B73), AppDarkColors.textSecondary),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompartilharCard extends StatelessWidget {
  const _CompartilharCard({required this.convite, required this.onCopiar});

  final ConviteFicha? convite;
  final VoidCallback onCopiar;

  @override
  Widget build(BuildContext context) {
    final convite = this.convite;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              adaptive(context, const Color(0xFF8BD2DC), AppDarkColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Qualquer pessoa com este código poderá solicitar acesso à ficha.',
            style: TextStyle(
                color: adaptive(context, const Color(0xFF5E6B73), AppDarkColors.textSecondary), fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 14),
          if (convite == null || convite.codigo.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFF2BA8BA),
                  ),
                ),
              ),
            )
          else ...[
            InkWell(
              onTap: onCopiar,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: adaptive(context, const Color(0xFFE7F4F6), AppDarkColors.tintedInfo),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      convite.codigo,
                      style: const TextStyle(
                        color: Color(0xFF0D6E80),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.copy_rounded,
                      color: Color(0xFF0D6E80),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            if (convite.expiraEm != null) ...[
              const SizedBox(height: 8),
              Text(
                'O codigo expira em ${_formatarData(convite.expiraEm!)}.',
                style: TextStyle(color: adaptive(context, const Color(0xFF9B9B9B), AppDarkColors.textMuted), fontSize: 11),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: onCopiar,
                icon: const Icon(Icons.ios_share_rounded, size: 19),
                label: const Text('Compartilhar codigo'),
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
          ],
        ],
      ),
    );
  }
}

class _PendenteCard extends StatelessWidget {
  const _PendenteCard({
    required this.solicitacao,
    required this.loading,
    required this.onAceitar,
    required this.onNegar,
  });

  final SolicitacaoPendente solicitacao;
  final bool loading;
  final VoidCallback onAceitar;
  final VoidCallback onNegar;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataImageBytes(solicitacao.urlFoto);
    final dias = DateTime.now().difference(solicitacao.criadoEm).inDays;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        borderRadius: BorderRadius.circular(16),
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
          CircleAvatar(
            radius: 24,
            backgroundColor: adaptive(
                context, const Color(0xFFD1F2F6), AppDarkColors.tintedInfo),
            backgroundImage: bytes != null ? MemoryImage(bytes) : null,
            child: bytes == null
                ? const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF238FA1),
                    size: 26,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  solicitacao.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF17324D), AppDarkColors.textPrimary),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Solicitou acesso como ${_cargoLabel(solicitacao.funcao)}',
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF5E6B73), AppDarkColors.textSecondary),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: adaptive(context, const Color(0xFF9B9B9B), AppDarkColors.textMuted),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      dias <= 0
                          ? 'Solicitado hoje'
                          : 'Aguardando ha $dias ${dias == 1 ? 'dia' : 'dias'}',
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF9B9B9B), AppDarkColors.textMuted),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF2BA8BA),
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniActionButton(
                  icon: Icons.check_rounded,
                  color: const Color(0xFF2E9D5C),
                  background: const Color(0xFFE3F6EA),
                  onTap: onAceitar,
                ),
                const SizedBox(height: 6),
                _MiniActionButton(
                  icon: Icons.close_rounded,
                  color: const Color(0xFFC0392B),
                  background: const Color(0xFFFBE6E4),
                  onTap: onNegar,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _ParticipanteCard extends StatelessWidget {
  const _ParticipanteCard({
    required this.membro,
    required this.loading,
    required this.onTap,
    required this.onSelecionarCargo,
    required this.onAlternarAdmin,
    required this.onRemover,
  });

  final MembroFicha membro;
  final bool loading;
  final VoidCallback? onTap;
  final ValueChanged<String> onSelecionarCargo;
  final VoidCallback onAlternarAdmin;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataImageBytes(membro.urlFoto);

    return Material(
      color: adaptive(context, Colors.white, AppDarkColors.surface),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: adaptive(
                  context, const Color(0xFFE4EFF1), AppDarkColors.border),
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
              CircleAvatar(
                radius: 24,
                backgroundColor: adaptive(
                    context, const Color(0xFFD1F2F6), AppDarkColors.tintedInfo),
                backgroundImage: bytes != null ? MemoryImage(bytes) : null,
                child: bytes == null
                    ? const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF238FA1),
                        size: 26,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            membro.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adaptive(context, const Color(0xFF17324D), AppDarkColors.textPrimary),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (membro.eAdministrador) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.shield_rounded,
                            size: 14,
                            color: Color(0xFF2BA8BA),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      membro.eCriador
                          ? 'Responsável pela ficha'
                          : (membro.relacao?.isNotEmpty == true
                              ? membro.relacao!
                              : (membro.telefone ?? '')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF5E6B73), AppDarkColors.textSecondary),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF2BA8BA),
                  ),
                )
              else if (membro.eCriador)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: adaptive(context, const Color(0xFFE7F4F6), AppDarkColors.tintedInfo),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Administrador',
                    style: TextStyle(
                      color: Color(0xFF0D6E80),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                _CargoMenu(
                  membro: membro,
                  onSelecionarCargo: onSelecionarCargo,
                  onAlternarAdmin: onAlternarAdmin,
                  onRemover: onRemover,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CargoMenu extends StatelessWidget {
  const _CargoMenu({
    required this.membro,
    required this.onSelecionarCargo,
    required this.onAlternarAdmin,
    required this.onRemover,
  });

  final MembroFicha membro;
  final ValueChanged<String> onSelecionarCargo;
  final VoidCallback onAlternarAdmin;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _showCargoSheet(
        context,
        membro: membro,
        onSelecionarCargo: onSelecionarCargo,
        onAlternarAdmin: onAlternarAdmin,
        onRemover: onRemover,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: adaptive(context, const Color(0xFFE7F4F6), AppDarkColors.tintedInfo),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _cargoLabel(membro.funcao),
              style: const TextStyle(
                color: Color(0xFF0D6E80),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Color(0xFF0D6E80),
            ),
          ],
        ),
      ),
    );
  }
}

void _showCargoSheet(
  BuildContext context, {
  required MembroFicha membro,
  required ValueChanged<String> onSelecionarCargo,
  required VoidCallback onAlternarAdmin,
  required VoidCallback onRemover,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _CargoSheet(
      membro: membro,
      onSelecionarCargo: (cargo) {
        Navigator.of(sheetContext).pop();
        onSelecionarCargo(cargo);
      },
      onAlternarAdmin: () {
        Navigator.of(sheetContext).pop();
        onAlternarAdmin();
      },
      onRemover: () {
        Navigator.of(sheetContext).pop();
        onRemover();
      },
    ),
  );
}

class _CargoSheet extends StatelessWidget {
  const _CargoSheet({
    required this.membro,
    required this.onSelecionarCargo,
    required this.onAlternarAdmin,
    required this.onRemover,
  });

  final MembroFicha membro;
  final ValueChanged<String> onSelecionarCargo;
  final VoidCallback onAlternarAdmin;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: adaptive(context, const Color(0xFFE0E0E0), AppDarkColors.border),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Acesso de ${membro.nome}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            _CargoOption(
              icon: Icons.diversity_3_rounded,
              title: 'Familiar',
              subtitle: 'Pode visualizar e editar tudo na ficha',
              selected: membro.funcao == 'familiar',
              onTap: () => onSelecionarCargo('familiar'),
            ),
            const SizedBox(height: 10),
            _CargoOption(
              icon: Icons.volunteer_activism_rounded,
              title: 'Cuidador',
              subtitle: 'Acesso definido por permissões específicas',
              selected: membro.funcao == 'cuidador',
              onTap: () => onSelecionarCargo('cuidador'),
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onAlternarAdmin,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF0D6E80),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Administrador',
                        style: TextStyle(
                          color: adaptive(context, const Color(0xFF17324D), AppDarkColors.textPrimary),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch(
                      value: membro.eAdministrador,
                      onChanged: (_) => onAlternarAdmin(),
                      activeThumbColor: const Color(0xFF2BA8BA),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: onRemover,
                icon: const Icon(Icons.person_remove_rounded, size: 19),
                label: const Text('Remover acesso'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC0392B),
                  side: const BorderSide(color: Color(0xFFE7A9A1)),
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
    );
  }
}

class _CargoOption extends StatelessWidget {
  const _CargoOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? adaptive(context, const Color(0xFFE7F4F6), AppDarkColors.tintedInfo)
          : adaptive(context, Colors.white, AppDarkColors.surface),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2BA8BA)
                  : adaptive(context, const Color(0xFFE4EFF1), AppDarkColors.border),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF2BA8BA)
                      : adaptive(context, const Color(0xFFE7F4F6), AppDarkColors.tintedInfo),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : const Color(0xFF0D6E80),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF17324D), AppDarkColors.textPrimary),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF8A8A8A), AppDarkColors.textSecondary),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2BA8BA),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _cargoLabel(String? funcao) {
  switch (funcao) {
    case 'familiar':
      return 'Familiar';
    case 'cuidador':
      return 'Cuidador';
    default:
      return 'Selecione o acesso';
  }
}

String _formatarData(DateTime date) {
  final local = date.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  final hora = local.hour.toString().padLeft(2, '0');
  final minuto = local.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${local.year} às $hora:$minuto';
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
