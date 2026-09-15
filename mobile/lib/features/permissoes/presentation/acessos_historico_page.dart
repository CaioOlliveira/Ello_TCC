import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_page_header.dart';

class AcessosHistoricoPage extends ConsumerStatefulWidget {
  const AcessosHistoricoPage({required this.idosoId, super.key});

  final String idosoId;

  @override
  ConsumerState<AcessosHistoricoPage> createState() =>
      _AcessosHistoricoPageState();
}

class _AcessosHistoricoPageState extends ConsumerState<AcessosHistoricoPage> {
  bool _loading = true;
  String? _erro;
  IdosoResumo? _idoso;
  List<MembroFicha> _membros = const [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (widget.idosoId.isEmpty) {
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
      final api = ref.read(apiClientProvider);
      final resultado = await Future.wait([
        api.buscarIdoso(idosoId: widget.idosoId),
        api.listarParticipantes(idosoId: widget.idosoId),
      ]);
      if (!mounted) return;
      final membros = resultado[1] as List<MembroFicha>;
      membros.sort((a, b) {
        final aData = a.ultimoVistoEm ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bData = b.ultimoVistoEm ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bData.compareTo(aData);
      });
      setState(() {
        _idoso = resultado[0] as IdosoResumo;
        _membros =
            membros.where((membro) => membro.ultimoVistoEm != null).toList();
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _erro = error.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar os acessos recentes.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFCFCFC), AppDarkColors.bg),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPageHeader(
                    title: 'Acessos recentes',
                    onBack: () => context.go('/perfil/seguranca/historico'),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Acessos recentes${_idoso == null ? '' : ' - ${_idoso!.nome}'}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF238FA1),
                          AppDarkColors.textPrimary),
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(child: _body(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF238FA1)),
      );
    }
    if (_erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_erro!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _carregar, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }
    if (_membros.isEmpty) {
      return const Center(
        child: Text(
          'Ainda não há acessos recentes para esta ficha.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      itemCount: _membros.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _AcessoCard(membro: _membros[index]),
    );
  }
}

class _AcessoCard extends StatelessWidget {
  const _AcessoCard({required this.membro});

  final MembroFicha membro;

  @override
  Widget build(BuildContext context) {
    final acessadoEm = membro.ultimoVistoEm!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: const Color(0xFFD1F2F6),
            backgroundImage: membro.urlFoto?.startsWith('http') == true
                ? NetworkImage(membro.urlFoto!)
                : null,
            child: membro.urlFoto?.startsWith('http') == true
                ? null
                : const Icon(Icons.person_outline_rounded,
                    color: Color(0xFF238FA1)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membro.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF17324D),
                        AppDarkColors.textPrimary),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Acessou a ficha',
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF737D80),
                        AppDarkColors.textSecondary),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatarDataHora(acessadoEm),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: adaptive(context, const Color(0xFF737D80),
                  AppDarkColors.textSecondary),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatarDataHora(DateTime value) {
  final local = value.toLocal();
  final data = '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
  final hora = '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '$data\n$hora';
}
