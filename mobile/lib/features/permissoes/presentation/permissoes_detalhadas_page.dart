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
import '../../monitoramento/presentation/monitoramento_catalog.dart';

class _ModuloPermissao {
  const _ModuloPermissao({required this.id, required this.titulo});

  final String id;
  final String titulo;
}

final _modulosPermissao = [
  const _ModuloPermissao(id: 'Ficha', titulo: 'Ficha da pessoa idosa'),
  for (final option in monitoramentoOptions)
    _ModuloPermissao(id: option.id, titulo: option.title),
];

class PermissoesDetalhadasPage extends ConsumerStatefulWidget {
  const PermissoesDetalhadasPage({super.key, required this.membroId});

  final String membroId;

  @override
  ConsumerState<PermissoesDetalhadasPage> createState() =>
      _PermissoesDetalhadasPageState();
}

class _PermissoesDetalhadasPageState
    extends ConsumerState<PermissoesDetalhadasPage> {
  bool _loading = true;
  bool _salvando = false;
  bool _sujo = false;
  String? _erro;
  MembroFicha? _membro;
  Set<String> _visualizar = {};
  Set<String> _editar = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final membro = await ref
          .read(apiClientProvider)
          .buscarMembro(membroId: widget.membroId);
      if (!mounted) return;
      setState(() {
        _membro = membro;
        _visualizar = membro.permissoesVisualizar.toSet();
        _editar = membro.permissoesEditar.toSet();
        _loading = false;
        _sujo = false;
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
        _erro = 'Nao foi possivel carregar as permissoes.';
        _loading = false;
      });
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await ref.read(apiClientProvider).atualizarMembro(
            membroId: widget.membroId,
            visualizar: _visualizar.toList(),
            editar: _editar.toList(),
            atualizadoPorId: ref.read(authSessionProvider)?.id,
          );
      if (!mounted) return;
      setState(() {
        _sujo = false;
        _salvando = false;
      });
      if (context.canPop()) {
        context.pop();
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel salvar.')),
      );
    }
  }

  void _toggleVisualizar(String id) {
    setState(() {
      _sujo = true;
      if (_visualizar.contains(id)) {
        _visualizar.remove(id);
        _editar.remove(id);
      } else {
        _visualizar.add(id);
      }
    });
  }

  void _toggleEditar(String id) {
    setState(() {
      _sujo = true;
      if (_editar.contains(id)) {
        _editar.remove(id);
      } else {
        _editar.add(id);
        _visualizar.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adaptive(context, const Color(0xFFFCFCFC), AppDarkColors.bg),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDarkMode(context) ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
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
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/permissoes'),
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            color: Color(0xFF238FA1),
                            size: 32,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Permissões detalhadas',
                            style: TextStyle(
                              color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
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

    final membro = _membro;
    if (_erro != null || membro == null) {
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
                style: TextStyle(color: adaptive(context, const Color(0xFF4C4C4C), AppDarkColors.textSecondary), fontSize: 12),
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

    final ehFamiliar = membro.funcao == 'familiar';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              StaggeredEntry(index: 0, child: _MembroCard(membro: membro)),
              const SizedBox(height: 18),
              if (ehFamiliar)
                StaggeredEntry(
                  index: 1,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: adaptive(context, const Color(0xFFE7F4F6), AppDarkColors.tintedInfo),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF0D6E80),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Como familiar, esta pessoa pode visualizar e '
                            'editar todas as informacoes da ficha.',
                            style: TextStyle(
                              color: Color(0xFF0D6E80),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                StaggeredEntry(
                  index: 1,
                  child: _PermissaoSecao(
                    titulo: 'Pode visualizar',
                    icon: Icons.visibility_outlined,
                    selecionados: _visualizar,
                    onToggle: _toggleVisualizar,
                  ),
                ),
                const SizedBox(height: 16),
                StaggeredEntry(
                  index: 2,
                  child: _PermissaoSecao(
                    titulo: 'Pode registrar/editar',
                    icon: Icons.edit_outlined,
                    selecionados: _editar,
                    onToggle: _toggleEditar,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!ehFamiliar)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: adaptive(context, const Color(0xFFFCFCFC), AppDarkColors.bg),
              border: Border(
                top: BorderSide(color: adaptive(context, const Color(0xFFE4EFF1), AppDarkColors.border)),
              ),
            ),
            child: SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: (_salvando || !_sujo) ? null : _salvar,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0E6F7E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: adaptive(context, const Color(0xFFCFE1E4), AppDarkColors.borderStrong),
                  disabledForegroundColor: adaptive(context, Colors.white, AppDarkColors.textMuted),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_sujo ? 'Salvar permissões' : 'Nenhuma alteração'),
              ),
            ),
          ),
      ],
    );
  }
}

class _MembroCard extends StatelessWidget {
  const _MembroCard({required this.membro});

  final MembroFicha membro;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataImageBytes(membro.urlFoto);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: adaptive(context, const Color(0xFFE4EFF1), AppDarkColors.border)),
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
            radius: 28,
            backgroundColor: adaptive(context, const Color(0xFFD1F2F6), AppDarkColors.tintedInfo),
            backgroundImage: bytes != null ? MemoryImage(bytes) : null,
            child: bytes == null
                ? const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF238FA1),
                    size: 30,
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membro.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF17324D), AppDarkColors.textPrimary),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: adaptive(context, const Color(0xFFE7F4F6), AppDarkColors.tintedInfo),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        membro.funcao == 'familiar' ? 'Familiar' : 'Cuidador',
                        style: const TextStyle(
                          color: Color(0xFF0D6E80),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (membro.relacao?.isNotEmpty == true) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          membro.relacao!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: adaptive(context, const Color(0xFF8A8A8A), AppDarkColors.textSecondary),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (membro.telefone?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: adaptive(context, const Color(0xFF9B9B9B), AppDarkColors.textMuted),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        membro.telefone!,
                        style: TextStyle(
                          color: adaptive(context, const Color(0xFF5E6B73), AppDarkColors.textSecondary),
                          fontSize: 12,
                        ),
                      ),
                    ],
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

class _PermissaoSecao extends StatelessWidget {
  const _PermissaoSecao({
    required this.titulo,
    required this.icon,
    required this.selecionados,
    required this.onToggle,
  });

  final String titulo;
  final IconData icon;
  final Set<String> selecionados;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final pares = <List<_ModuloPermissao>>[];
    for (var i = 0; i < _modulosPermissao.length; i += 2) {
      pares.add(
        _modulosPermissao.skip(i).take(2).toList(),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8BD2DC)),
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
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0D6E80), size: 21),
              const SizedBox(width: 9),
              Text(
                titulo,
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final par in pares)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ModuloCheckbox(
                    modulo: par[0],
                    selecionado: selecionados.contains(par[0].id),
                    onTap: () => onToggle(par[0].id),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: par.length > 1
                      ? _ModuloCheckbox(
                          modulo: par[1],
                          selecionado: selecionados.contains(par[1].id),
                          onTap: () => onToggle(par[1].id),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ModuloCheckbox extends StatelessWidget {
  const _ModuloCheckbox({
    required this.modulo,
    required this.selecionado,
    required this.onTap,
  });

  final _ModuloPermissao modulo;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: selecionado
                    ? const Color(0xFF2BA8BA)
                    : adaptive(context, Colors.white, AppDarkColors.surface),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: selecionado
                      ? const Color(0xFF2BA8BA)
                      : adaptive(context, const Color(0xFFC7D8DA), AppDarkColors.border),
                  width: 1.6,
                ),
              ),
              child: selecionado
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 17,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                modulo.titulo,
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF17324D), AppDarkColors.textPrimary),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
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
