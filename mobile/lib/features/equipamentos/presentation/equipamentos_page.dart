import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/staggered_entry.dart';

part 'equipamentos_formularios.dart';
part 'equipamentos_modelos.dart';
part 'equipamentos_widgets.dart';

enum _EquipamentosView { lista, cadastro, edicao, detalhes, manutencao }

class EquipamentosPage extends ConsumerStatefulWidget {
  const EquipamentosPage({super.key});

  @override
  ConsumerState<EquipamentosPage> createState() => _EquipamentosPageState();
}

class _EquipamentosPageState extends ConsumerState<EquipamentosPage> {
  var _view = _EquipamentosView.lista;
  var _loading = true;
  var _saving = false;
  Equipamento? _selected;
  List<Equipamento> _equipamentos = [];
  List<ManutencaoEquipamento> _manutencoes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final data = await ref
          .read(apiClientProvider)
          .listarEquipamentos(idosoId: idoso.id);
      if (!mounted) return;
      setState(() {
        _equipamentos = data.map(Equipamento.fromJson).toList();
        if (_selected != null) {
          _selected = _equipamentos
              .where((item) => item.id == _selected!.id)
              .firstOrNull;
        }
      });
      ref
          .read(apiClientProvider)
          .listarHistoricoEquipamentos(idosoId: idoso.id)
          .catchError((_) => const <Map<String, dynamic>>[]);
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Nao foi possivel carregar equipamentos.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadManutencoes(Equipamento item) async {
    setState(() {
      _selected = item;
      _view = _EquipamentosView.detalhes;
      _manutencoes = [];
    });

    try {
      final data = await ref
          .read(apiClientProvider)
          .listarManutencoesEquipamento(id: item.id);
      if (!mounted) return;
      setState(() {
        _manutencoes = data.map(ManutencaoEquipamento.fromJson).toList();
      });
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Nao foi possivel carregar manutencoes.');
    }
  }

  Future<void> _saveEquipamento(EquipamentoFormData data) async {
    final idoso = ref.read(selectedIdosoProvider);
    final usuario = ref.read(authSessionProvider);
    if (idoso == null) {
      context.go('/idosos');
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = data.toPayload(
        idosoId: idoso.id,
        criadoPorId: usuario?.id,
      );
      final response =
          await ref.read(apiClientProvider).criarEquipamento(data: payload);
      final created = Equipamento.fromJson(response['dados'] ?? response);
      if (!mounted) return;
      setState(() {
        _equipamentos = [..._equipamentos, created]..sort(_compare);
        _selected = created;
        _view = _EquipamentosView.detalhes;
      });
      await _loadManutencoes(created);
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Nao foi possivel salvar equipamento.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateEquipamento(EquipamentoFormData data) async {
    final selected = _selected;
    final idoso = ref.read(selectedIdosoProvider);
    if (selected == null || idoso == null) return;

    setState(() => _saving = true);
    try {
      final payload = data.toPayload(
        idosoId: idoso.id,
        includeDefaultStatus: false,
      );
      final response = await ref.read(apiClientProvider).atualizarEquipamento(
            id: selected.id,
            data: payload,
          );
      final updated = Equipamento.fromJson(response['dados'] ?? response);
      if (!mounted) return;
      setState(() {
        _selected = updated;
        _equipamentos = [
          for (final item in _equipamentos)
            item.id == updated.id ? updated : item,
        ]..sort(_compare);
        _view = _EquipamentosView.detalhes;
      });
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Nao foi possivel editar equipamento.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveManutencao(ManutencaoFormData data) async {
    final selected = _selected;
    final usuario = ref.read(authSessionProvider);
    if (selected == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).registrarManutencaoEquipamento(
            id: selected.id,
            data: data.toPayload(registradoPorId: usuario?.id),
          );
      if (!mounted) return;
      await _load();
      final refreshed =
          _equipamentos.where((item) => item.id == selected.id).firstOrNull;
      await _loadManutencoes(refreshed ??
          selected.copyWith(
            ultimaManutencaoEm: data.dataManutencao,
            proximaManutencaoEm: data.proximaManutencaoEm,
            status: 'Em uso',
          ));
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Nao foi possivel registrar manutencao.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setStatus(String status) async {
    final selected = _selected;
    if (selected == null) return;

    setState(() => _saving = true);
    try {
      final response = await ref.read(apiClientProvider).atualizarEquipamento(
        id: selected.id,
        data: {'status': status},
      );
      final updated = Equipamento.fromJson(response['dados'] ?? response);
      if (!mounted) return;
      setState(() {
        _selected = updated;
        _equipamentos = [
          for (final item in _equipamentos)
            item.id == updated.id ? updated : item,
        ]..sort(_compare);
      });
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Nao foi possivel atualizar status.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteEquipamento() async {
    final selected = _selected;
    if (selected == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text('Excluir equipamento'),
          content: Text(
            'Tem certeza que deseja excluir "${selected.nome}"? Essa acao nao pode ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF1744),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteEquipamento(selected);
    }
  }

  Future<void> _deleteEquipamento(Equipamento selected) async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).removerEquipamento(id: selected.id);
      if (!mounted) return;
      setState(() {
        _equipamentos = [
          for (final item in _equipamentos)
            if (item.id != selected.id) item,
        ];
        _selected = null;
        _manutencoes = [];
        _view = _EquipamentosView.lista;
      });
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Nao foi possivel excluir equipamento.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _compare(Equipamento a, Equipamento b) => a.nome.compareTo(b.nome);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _back() {
    if (_view == _EquipamentosView.lista) {
      context.go('/monitoramento');
      return;
    }
    if (_view == _EquipamentosView.manutencao ||
        _view == _EquipamentosView.edicao) {
      setState(() => _view = _EquipamentosView.detalhes);
      return;
    }
    setState(() => _view = _EquipamentosView.lista);
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);

    Widget child;
    switch (_view) {
      case _EquipamentosView.cadastro:
        child = _EquipamentoForm(
          saving: _saving,
          onCancel: _back,
          onSubmit: _saveEquipamento,
        );
      case _EquipamentosView.edicao:
        child = _selected == null
            ? const SizedBox.shrink()
            : _EquipamentoForm(
                initial: _selected,
                saving: _saving,
                onCancel: _back,
                onSubmit: _updateEquipamento,
              );
      case _EquipamentosView.detalhes:
        child = _selected == null
            ? _EquipamentosList(
                loading: _loading,
                equipamentos: _equipamentos,
                personOf: idoso?.elderText.of ?? 'da pessoa idosa',
                onAdd: () => setState(() => _view = _EquipamentosView.cadastro),
                onOpen: _loadManutencoes,
                onHistory: () => context.push('/equipamentos/historico'),
              )
            : _EquipamentoDetails(
                equipamento: _selected!,
                manutencoes: _manutencoes,
                saving: _saving,
                onRegister: () =>
                    setState(() => _view = _EquipamentosView.manutencao),
                onStatusChanged: () => _setStatus(
                  _selected!.status == 'Fora de uso' ? 'Em uso' : 'Fora de uso',
                ),
                onEdit: () => setState(() => _view = _EquipamentosView.edicao),
                onDelete: _confirmDeleteEquipamento,
              );
      case _EquipamentosView.manutencao:
        child = _selected == null
            ? const SizedBox.shrink()
            : _ManutencaoForm(
                equipamento: _selected!,
                saving: _saving,
                onCancel: _back,
                onSubmit: _saveManutencao,
              );
      case _EquipamentosView.lista:
        child = idoso == null
            ? const _MessageState(
                icon: Icons.person_search_rounded,
                title: 'Escolha uma ficha',
                message: 'Selecione uma ficha para ver os equipamentos.',
              )
            : _EquipamentosList(
                loading: _loading,
                equipamentos: _equipamentos,
                personOf: idoso.elderText.of,
                onAdd: () => setState(() => _view = _EquipamentosView.cadastro),
                onOpen: _loadManutencoes,
                onHistory: () => context.push('/equipamentos/historico'),
              );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BackButton(onTap: _back),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (transitionChild, animation) =>
                            FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.03),
                              end: Offset.zero,
                            ).animate(animation),
                            child: transitionChild,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_view),
                          child: child,
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

class _EquipamentosList extends StatelessWidget {
  const _EquipamentosList({
    required this.loading,
    required this.equipamentos,
    required this.personOf,
    required this.onAdd,
    required this.onOpen,
    required this.onHistory,
  });

  final bool loading;
  final List<Equipamento> equipamentos;
  final String personOf;
  final VoidCallback onAdd;
  final ValueChanged<Equipamento> onOpen;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Lista de equipamentos',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF073248),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const _StatusLegend(),
        const SizedBox(height: 8),
        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF38AFC0)),
                )
              : equipamentos.isEmpty
                  ? _MessageState(
                      icon: Icons.medical_services_outlined,
                      title: 'Nenhum equipamento',
                      message: 'Cadastre o primeiro equipamento $personOf.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(0, 2, 0, 18),
                      itemCount: equipamentos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = equipamentos[index];
                        return StaggeredEntry(
                          index: index,
                          child: _EquipamentoCard(
                            equipamento: item,
                            onTap: () => onOpen(item),
                          ),
                        );
                      },
                    ),
        ),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_rounded, size: 22),
            label: const Text('Adicionar Equipamento'),
            style: _primaryButtonStyle(),
          ),
        ),
        const SizedBox(height: 7),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: OutlinedButton(
            onPressed: onHistory,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF222222),
              side: const BorderSide(
                color: Color(0xFF1696AA),
                width: 1.4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Ver Historico'),
          ),
        ),
      ],
    );
  }
}

class _EquipamentoCard extends StatelessWidget {
  const _EquipamentoCard({required this.equipamento, required this.onTap});

  final Equipamento equipamento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = equipamento.statusInfo;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 12,
                decoration: BoxDecoration(
                  color: status.color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                  child: Row(
                    children: [
                      _EquipmentPicture(equipamento: equipamento, size: 78),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              equipamento.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF222222),
                              ),
                            ),
                            Text(
                              'Ultima calibracao: ${formatDate(equipamento.ultimaManutencaoEm)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _mutedStyle(),
                            ),
                            Text(
                              'Proxima calibracao: ${formatDate(equipamento.proximaManutencaoEm)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _mutedStyle(),
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                Icon(status.icon,
                                    color: status.color, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Status: ${status.label}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: status.color,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF777777),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
