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
import '../../../core/theme/app_palette.dart';
import '../../../shared/navigation/module_navigation.dart';
import '../../../shared/widgets/app_page_header.dart';
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
      if (mounted) _showMessage('Não foi possível carregar equipamentos.');
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
      if (mounted) _showMessage('Não foi possível carregar manutenções.');
    }
  }

  bool _canEditEquipamentos() {
    return ref.read(selectedIdosoProvider)?.podeEditarModulo('Equipamentos') ??
        false;
  }

  void _showNoEditPermission() {
    _showMessage('Você não tem permissão para editar equipamentos.');
  }

  Future<void> _saveEquipamento(EquipamentoFormData data) async {
    final idoso = ref.read(selectedIdosoProvider);
    final usuario = ref.read(authSessionProvider);
    if (idoso == null) {
      context.go('/idosos');
      return;
    }
    if (!idoso.podeEditarModulo('Equipamentos')) {
      _showNoEditPermission();
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
      if (mounted) _showMessage('Não foi possível salvar equipamento.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateEquipamento(EquipamentoFormData data) async {
    final selected = _selected;
    final idoso = ref.read(selectedIdosoProvider);
    final usuario = ref.read(authSessionProvider);
    if (selected == null || idoso == null) return;
    if (!idoso.podeEditarModulo('Equipamentos')) {
      _showNoEditPermission();
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = data.toPayload(
        idosoId: idoso.id,
        includeDefaultStatus: false,
        registradoPorId: usuario?.id,
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
      if (mounted) _showMessage('Não foi possível editar equipamento.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveManutencao(ManutencaoFormData data) async {
    final selected = _selected;
    final usuario = ref.read(authSessionProvider);
    if (selected == null) return;
    if (!_canEditEquipamentos()) {
      _showNoEditPermission();
      return;
    }

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
      if (mounted) _showMessage('Não foi possível registrar manutenção.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setStatus(String status) async {
    final selected = _selected;
    if (selected == null) return;
    if (!_canEditEquipamentos()) {
      _showNoEditPermission();
      return;
    }

    setState(() => _saving = true);
    try {
      final usuarioId = ref.read(authSessionProvider)?.id;
      final response = await ref.read(apiClientProvider).atualizarEquipamento(
        id: selected.id,
        data: {
          'status': status,
          if (usuarioId != null && usuarioId.isNotEmpty)
            'registradoPorId': usuarioId,
        },
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
      if (mounted) _showMessage('Não foi possível atualizar status.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteEquipamento() async {
    final selected = _selected;
    if (selected == null) return;
    if (!_canEditEquipamentos()) {
      _showNoEditPermission();
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text('Excluir equipamento'),
          content: Text(
            'Tem certeza que deseja excluir "${selected.nome}"? Essa ação não pode ser desfeita.',
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
      await ref.read(apiClientProvider).removerEquipamento(
            id: selected.id,
            usuarioId: ref.read(authSessionProvider)?.id,
          );
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
      if (mounted) _showMessage('Não foi possível excluir equipamento.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _compare(Equipamento a, Equipamento b) => a.nome.compareTo(b.nome);

  void _showMessage(String message) {
    _ignoreBottomMessage();
  }

  void _back() {
    if (_view == _EquipamentosView.lista) {
      context.go(moduleBackRoute(context));
      return;
    }
    if (_view == _EquipamentosView.manutencao ||
        _view == _EquipamentosView.edicao) {
      setState(() => _view = _EquipamentosView.detalhes);
      return;
    }
    setState(() => _view = _EquipamentosView.lista);
  }

  Future<bool> _handleSystemBack() async {
    if (_view == _EquipamentosView.lista) return true;
    _back();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);
    final pageTitle = switch (_view) {
      _EquipamentosView.lista => 'Equipamentos',
      _EquipamentosView.cadastro => 'Novo equipamento',
      _EquipamentosView.edicao => 'Editar equipamento',
      _EquipamentosView.detalhes => 'Detalhes do equipamento',
      _EquipamentosView.manutencao => 'Registrar manutenção',
    };

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
                onAdd: () {
                  if (!_canEditEquipamentos()) {
                    _showNoEditPermission();
                    return;
                  }
                  setState(() => _view = _EquipamentosView.cadastro);
                },
                onOpen: _loadManutencoes,
                onHistory: () => context.push(
                  routeWithCurrentOrigin(context, '/equipamentos/historico'),
                ),
              )
            : _EquipamentoDetails(
                equipamento: _selected!,
                manutencoes: _manutencoes,
                saving: _saving,
                onRegister: () {
                  if (!_canEditEquipamentos()) {
                    _showNoEditPermission();
                    return;
                  }
                  setState(() => _view = _EquipamentosView.manutencao);
                },
                onStatusChanged: () => _setStatus(
                  _selected!.status == 'Fora de uso' ? 'Em uso' : 'Fora de uso',
                ),
                onEdit: () {
                  if (!_canEditEquipamentos()) {
                    _showNoEditPermission();
                    return;
                  }
                  setState(() => _view = _EquipamentosView.edicao);
                },
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
                onAdd: () {
                  if (!_canEditEquipamentos()) {
                    _showNoEditPermission();
                    return;
                  }
                  setState(() => _view = _EquipamentosView.cadastro);
                },
                onOpen: _loadManutencoes,
                onHistory: () => context.push(
                  routeWithCurrentOrigin(context, '/equipamentos/historico'),
                ),
              );
    }

    return PopScope(
      canPop: _view == _EquipamentosView.lista,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack();
      },
      child: Scaffold(
        backgroundColor:
            adaptive(context, const Color(0xFFFAFAFA), AppDarkColors.bg),
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDarkMode(context)
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppPageHeader(title: pageTitle, onBack: _back),
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
              foregroundColor: adaptive(
                  context, const Color(0xFF222222), AppDarkColors.textPrimary),
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
            child: const Text('Ver Histórico'),
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
      color: adaptive(context, Colors.white, AppDarkColors.surface),
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
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: adaptive(
                                    context,
                                    const Color(0xFF222222),
                                    AppDarkColors.textPrimary),
                              ),
                            ),
                            Text(
                              'Última calibração: ${formatDate(equipamento.ultimaManutencaoEm)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _mutedStyle(context),
                            ),
                            Text(
                              'Próxima calibração: ${formatDate(equipamento.proximaManutencaoEm)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _mutedStyle(context),
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
                      Icon(
                        Icons.chevron_right_rounded,
                        color: adaptive(context, const Color(0xFF777777),
                            AppDarkColors.textSecondary),
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

void _ignoreBottomMessage() {}
