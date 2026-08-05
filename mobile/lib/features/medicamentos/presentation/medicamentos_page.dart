import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/navigation/module_navigation.dart';
import '../../../shared/widgets/module_header.dart';
import '../../../shared/widgets/staggered_entry.dart';

enum _Mode { resumo, form, historico, detalhe }

enum _Periodo { dia, semanal, mes }

const _kFormatos = [
  'Comprimido',
  'Cápsula',
  'Líquido/Xarope',
  'Injeção',
  'Pomada/Creme',
  'Adesivo',
  'Gotas',
  'Outro',
];

const _kDiasSemana = [
  'Domingo',
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
];

const _kTodosOsDias = 'Todos os dias';
const _kDiaAlternado = 'Dia sim, dia não';

const _kStatusDose = [
  ('tomado', 'Tomado', Icons.check_circle_rounded, Color(0xFF28A745)),
  ('atrasado', 'Atrasado', Icons.schedule_rounded, Color(0xFFE49A20)),
  ('nao_tomou', 'Não tomou', Icons.cancel_rounded, Color(0xFFD73A3A)),
  ('recusou', 'Recusou', Icons.block_rounded, Color(0xFF8A6FD6)),
];

class MedicamentosPage extends ConsumerStatefulWidget {
  const MedicamentosPage({super.key});

  @override
  ConsumerState<MedicamentosPage> createState() => _MedicamentosPageState();
}

class _MedicamentosPageState extends ConsumerState<MedicamentosPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _dosagemController = TextEditingController();
  final _estoqueController = TextEditingController();
  final _doseController = TextEditingController();
  final _observacoesController = TextEditingController();

  Future<MedicamentosResumo>? _resumoFuture;
  String? _resumoLoadedIdosoId;

  Future<List<HistoricoMedicamentoEntrada>>? _historicoFuture;
  String? _historicoLoadedIdosoId;
  _Periodo? _historicoLoadedPeriodo;
  _Periodo _historicoPeriodo = _Periodo.dia;

  _Mode _mode = _Mode.resumo;
  MedicamentoResumo? _selecionado;
  bool _editando = false;

  String? _formato;
  String _frequenciaTipo = 'diaria';
  final List<String> _diasSemana = [];
  final List<String> _horarios = [];
  DateTime? _dataInicio;
  DateTime? _dataFim;
  bool _lembretesAtivos = true;
  bool _saving = false;
  List<Map<String, dynamic>> _administracoes = [];
  bool _carregandoDetalhe = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _dosagemController.dispose();
    _estoqueController.dispose();
    _doseController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  void _ensureResumo(String idosoId) {
    if (_resumoLoadedIdosoId == idosoId && _resumoFuture != null) return;
    _resumoLoadedIdosoId = idosoId;
    _resumoFuture = _loadResumo(idosoId);
  }

  void _reloadResumo(String idosoId) {
    setState(() {
      _resumoLoadedIdosoId = idosoId;
      _resumoFuture = _loadResumo(idosoId);
    });
  }

  Future<MedicamentosResumo> _loadResumo(String idosoId) async {
    final resumo = await ref
        .read(apiClientProvider)
        .getResumoMedicamentos(idosoId: idosoId);
    await _syncMedicamentoNotifications(idosoId, resumo);
    return resumo;
  }

  void _ensureHistorico(String idosoId) {
    if (_historicoLoadedIdosoId == idosoId &&
        _historicoLoadedPeriodo == _historicoPeriodo &&
        _historicoFuture != null) {
      return;
    }
    _historicoLoadedIdosoId = idosoId;
    _historicoLoadedPeriodo = _historicoPeriodo;
    _historicoFuture = ref.read(apiClientProvider).getHistoricoMedicamentos(
          idosoId: idosoId,
          periodo: _historicoPeriodo.apiValue,
        );
  }

  void _reloadHistorico(String idosoId) {
    setState(() {
      _historicoLoadedIdosoId = idosoId;
      _historicoLoadedPeriodo = _historicoPeriodo;
      _historicoFuture = ref.read(apiClientProvider).getHistoricoMedicamentos(
            idosoId: idosoId,
            periodo: _historicoPeriodo.apiValue,
          );
    });
  }

  /// Forca o proximo _ensureHistorico a buscar dados novos, usado depois de
  /// qualquer acao que gere uma nova entrada no historico (criar, editar,
  /// remover ou registrar dose).
  void _invalidateHistorico() {
    _historicoLoadedIdosoId = null;
  }

  void _resetForm() {
    _nomeController.clear();
    _dosagemController.clear();
    _estoqueController.clear();
    _doseController.clear();
    _observacoesController.clear();
    _formato = null;
    _frequenciaTipo = 'diaria';
    _diasSemana.clear();
    _horarios.clear();
    _dataInicio = null;
    _dataFim = null;
    _lembretesAtivos = true;
  }

  Future<void> _openCreateForm() async {
    setState(() {
      _resetForm();
      _editando = false;
      _selecionado = null;
      _mode = _Mode.form;
    });
  }

  Future<void> _openEditForm(MedicamentoResumo medicamento) async {
    setState(() {
      _resetForm();
      _editando = true;
      _selecionado = medicamento;
      _nomeController.text = medicamento.nome;
      _dosagemController.text = medicamento.dosagem ?? '';
      _formato = medicamento.formato;
      _estoqueController.text = medicamento.quantidadeEstoque == null
          ? ''
          : _formatNumber(medicamento.quantidadeEstoque!);
      _mode = _Mode.form;
    });

    try {
      final horarios = await ref.read(apiClientProvider).getHorariosMedicamento(
            medicamento.id,
          );
      if (!mounted) return;
      setState(() {
        _horarios
          ..clear()
          ..addAll(horarios.map((h) => h.horario));
        if (horarios.isNotEmpty) {
          _frequenciaTipo = horarios.first.frequenciaTipo;
          _diasSemana
            ..clear()
            ..addAll(horarios.first.diasSemana);
          final dose = horarios.first.quantidadeDose;
          if (dose != null) _doseController.text = _formatNumber(dose);
        }
      });
    } catch (_) {
      // Segue com o formulario mesmo se os horarios nao carregarem.
    }
  }

  Future<void> _openDetalhe(MedicamentoResumo medicamento) async {
    setState(() {
      _selecionado = medicamento;
      _mode = _Mode.detalhe;
      _carregandoDetalhe = true;
      _administracoes = [];
    });

    try {
      final client = ref.read(apiClientProvider);
      final administracoes =
          await client.getAdministracoesMedicamento(medicamento.id);
      if (!mounted) return;
      setState(() {
        _administracoes = administracoes;
        _carregandoDetalhe = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _carregandoDetalhe = false);
    }
  }

  Future<void> _salvar() async {
    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final client = ref.read(apiClientProvider);
      final estoque = double.tryParse(
        _estoqueController.text.trim().replaceAll(',', '.'),
      );
      final dose = double.tryParse(
        _doseController.text.trim().replaceAll(',', '.'),
      );

      final String medicamentoId;
      if (_editando && _selecionado != null) {
        await client.atualizarMedicamento(
          id: _selecionado!.id,
          nome: _nomeController.text.trim(),
          dosagem: _dosagemController.text.trim(),
          formato: _formato,
          instrucoes: _observacoesController.text.trim(),
          dataInicio: _dataInicio == null ? null : _toIsoDate(_dataInicio!),
          dataFim: _dataFim == null ? null : _toIsoDate(_dataFim!),
          quantidadeEstoque: estoque,
        );
        medicamentoId = _selecionado!.id;
      } else {
        final criado = await client.criarMedicamento(
          idosoId: idoso.id,
          nome: _nomeController.text.trim(),
          dosagem: _dosagemController.text.trim(),
          formato: _formato,
          instrucoes: _observacoesController.text.trim(),
          dataInicio: _dataInicio == null ? null : _toIsoDate(_dataInicio!),
          dataFim: _dataFim == null ? null : _toIsoDate(_dataFim!),
          quantidadeEstoque: estoque,
        );
        medicamentoId = criado.id;
      }

      if (_horarios.isNotEmpty) {
        await client.substituirHorariosMedicamento(
          medicamentoId: medicamentoId,
          horarios: [
            for (final horario in _horarios)
              (horario: horario, quantidadeDose: dose, unidadeDose: null),
          ],
          frequenciaTipo: _frequenciaTipo,
          diasSemana: _frequenciaTipo == 'semanal' ? _diasSemana : null,
          registradoPorId: ref.read(authSessionProvider)?.id,
        );
      }

      if (!mounted) return;
      setState(() => _mode = _Mode.resumo);
      _invalidateHistorico();
      _reloadResumo(idoso.id);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel salvar o medicamento.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _registrarDose() async {
    final idoso = ref.read(selectedIdosoProvider);
    final medicamento = _selecionado;
    if (idoso == null || medicamento == null) return;

    setState(() => _saving = true);
    try {
      final agora = DateTime.now();
      await ref.read(apiClientProvider).registrarAdministracaoMedicamento(
            medicamentoId: medicamento.id,
            idosoId: idoso.id,
            horarioPrevisto:
                _horarioPrevistoParaAgora(medicamento.proximoHorario, agora),
            administradoEm: agora,
            status: 'tomado',
            registradoPorId: ref.read(authSessionProvider)?.id,
          );
      if (!mounted) return;
      await _openDetalhe(medicamento);
      _invalidateHistorico();
      _reloadResumo(idoso.id);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel registrar a dose.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remover(MedicamentoResumo medicamento) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover medicamento'),
        content: Text('Deseja remover "${medicamento.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;
    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null) return;

    try {
      await ref.read(apiClientProvider).removerMedicamento(medicamento.id);
      if (!mounted) return;
      setState(() => _mode = _Mode.resumo);
      _invalidateHistorico();
      await LocalNotificationService.instance.cancelGroup(
        'medicamento-${idoso.id}-${medicamento.id}',
      );
      _reloadResumo(idoso.id);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);

    return Scaffold(
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
              child: idoso == null
                  ? _NoIdosoState(onGoBack: () => context.go('/idosos'))
                  : _buildContent(idoso),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(IdosoResumo idoso) {
    _ensureResumo(idoso.id);
    _ensureHistorico(idoso.id);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(_mode),
        child: switch (_mode) {
          _Mode.form => _MedicamentoFormView(
              formKey: _formKey,
              editando: _editando,
              saving: _saving,
              nomeController: _nomeController,
              dosagemController: _dosagemController,
              estoqueController: _estoqueController,
              doseController: _doseController,
              observacoesController: _observacoesController,
              formato: _formato,
              frequenciaTipo: _frequenciaTipo,
              diasSemana: _diasSemana,
              horarios: _horarios,
              dataInicio: _dataInicio,
              dataFim: _dataFim,
              lembretesAtivos: _lembretesAtivos,
              onFormatoChanged: (value) => setState(() => _formato = value),
              onFrequenciaChanged: (tipo, dias) => setState(() {
                _frequenciaTipo = tipo;
                _diasSemana
                  ..clear()
                  ..addAll(dias);
              }),
              onHorarioAdded: (value) => setState(() {
                _horarios.add(value);
                _horarios.sort();
              }),
              onHorarioRemoved: (index) =>
                  setState(() => _horarios.removeAt(index)),
              onDataInicioChanged: (value) =>
                  setState(() => _dataInicio = value),
              onDataFimChanged: (value) => setState(() => _dataFim = value),
              onLembretesChanged: (value) =>
                  setState(() => _lembretesAtivos = value),
              onSave: _salvar,
              onCancel: () => setState(() => _mode = _Mode.resumo),
            ),
          _Mode.historico => FutureBuilder<List<HistoricoMedicamentoEntrada>>(
              future: _historicoFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2FA8B8)),
                  );
                }
                if (snapshot.hasError) {
                  return _ErrorState(
                    onBack: () => setState(() => _mode = _Mode.resumo),
                    onRetry: () => _reloadHistorico(idoso.id),
                  );
                }
                return _HistoricoView(
                  entradas: snapshot.data ?? const [],
                  periodo: _historicoPeriodo,
                  onBack: () => setState(() => _mode = _Mode.resumo),
                  onPeriodoChanged: (periodo) {
                    setState(() => _historicoPeriodo = periodo);
                    _reloadHistorico(idoso.id);
                  },
                );
              },
            ),
          _Mode.detalhe => _selecionado == null
              ? const SizedBox.shrink()
              : _DetalheView(
                  medicamento: _selecionado!,
                  administracoes: _administracoes,
                  carregando: _carregandoDetalhe,
                  saving: _saving,
                  onBack: () => setState(() => _mode = _Mode.resumo),
                  onEdit: () => _openEditForm(_selecionado!),
                  onDelete: () => _remover(_selecionado!),
                  onRegistrarDose: _registrarDose,
                ),
          _Mode.resumo => FutureBuilder<MedicamentosResumo>(
              future: _resumoFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2FA8B8)),
                  );
                }
                if (snapshot.hasError) {
                  return _ErrorState(
                    onBack: () => context.go(moduleBackRoute(context)),
                    onRetry: () => _reloadResumo(idoso.id),
                  );
                }

                final resumo =
                    snapshot.data ?? MedicamentosResumo.fromJson(const {});

                return _ResumoView(
                  resumo: resumo,
                  onBack: () => context.go(moduleBackRoute(context)),
                  onAdd: _openCreateForm,
                  onOpen: _openDetalhe,
                  onHistorico: () => setState(() => _mode = _Mode.historico),
                );
              },
            ),
        },
      ),
    );
  }

  Future<void> _syncMedicamentoNotifications(
    String idosoId,
    MedicamentosResumo resumo,
  ) async {
    try {
      final service = LocalNotificationService.instance;
      for (final medicamento in resumo.medicamentos) {
        await service.replaceGroup(
          'medicamento-$idosoId-${medicamento.id}',
          _medicamentoNotificationRequests(medicamento),
        );
      }
    } catch (_) {
      // Nao bloqueia medicamentos se o sistema negar permissoes.
    }
  }

  List<LocalNotificationRequest> _medicamentoNotificationRequests(
    MedicamentoResumo medicamento,
  ) {
    final now = DateTime.now();
    final end = now.add(const Duration(days: 30));
    final requests = <LocalNotificationRequest>[];

    for (final horario in medicamento.horarios) {
      final parts = horario.horario.split(':');
      if (parts.length < 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      for (var day = DateTime(now.year, now.month, now.day);
          !day.isAfter(end) && requests.length < 64;
          day = day.add(const Duration(days: 1))) {
        if (!_medicamentoOccursOnDay(horario, day, now)) continue;
        final scheduled = DateTime(day.year, day.month, day.day, hour, minute);
        if (!scheduled.isAfter(now)) continue;

        final dayKey = _isoDate(day);
        final key = 'medicamento:${medicamento.id}:$dayKey:${horario.horario}';
        requests.add(
          LocalNotificationRequest(
            id: stableNotificationId(key),
            scheduledAt: scheduled,
            title: 'Hora do medicamento',
            body: '${medicamento.nome} - ${horario.horario}',
            payload: key,
          ),
        );
      }
    }

    return requests;
  }
}

extension on _Periodo {
  String get apiValue => switch (this) {
        _Periodo.dia => 'dia',
        _Periodo.semanal => 'semanal',
        _Periodo.mes => 'mes',
      };
}

class _ResumoView extends StatelessWidget {
  const _ResumoView({
    required this.resumo,
    required this.onBack,
    required this.onAdd,
    required this.onOpen,
    required this.onHistorico,
  });

  final MedicamentosResumo resumo;
  final VoidCallback onBack;
  final VoidCallback onAdd;
  final ValueChanged<MedicamentoResumo> onOpen;
  final VoidCallback onHistorico;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(onBack: onBack, title: 'Medicações'),
          const SizedBox(height: 12),
          Expanded(
            child: resumo.totalMedicamentos == 0
                ? const _EmptyState()
                : ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      if (resumo.proximoMedicamento != null)
                        StaggeredEntry(
                          index: 0,
                          child: _ProximoMedicamentoCard(
                            medicamento: resumo.proximoMedicamento!,
                          ),
                        ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < resumo.medicamentos.length; i++) ...[
                        StaggeredEntry(
                          index: i + 1,
                          child: _MedicamentoCard(
                            medicamento: resumo.medicamentos[i],
                            onTap: () => onOpen(resumo.medicamentos[i]),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_rounded, size: 20),
              label: const Text('Adicionar medicamento'),
              style: _primaryButtonStyle(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: onHistorico,
              style: OutlinedButton.styleFrom(
                foregroundColor: adaptive(context, const Color(0xFF245066),
                    AppDarkColors.textPrimary),
                side: const BorderSide(color: Color(0xFF2FA3B5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Ver Historico'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.title, this.trailing});

  final VoidCallback onBack;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ModuleHeader(title: title, onBack: onBack, trailing: trailing);
  }
}

class _ProximoMedicamentoCard extends StatelessWidget {
  const _ProximoMedicamentoCard({required this.medicamento});

  final MedicamentoResumo medicamento;

  @override
  Widget build(BuildContext context) {
    final atrasado = medicamento.proximoAtrasado;
    final corDestaque =
        atrasado ? const Color(0xFFD73A3A) : const Color(0xFF148A9C);
    final corFundoIcone =
        atrasado ? const Color(0xFFF6D3D3) : const Color(0xFFD8F1F4);
    final corBadgeFundo =
        atrasado ? const Color(0xFFF6D3D3) : const Color(0xFFF3E3C4);
    final corBadgeTexto =
        atrasado ? const Color(0xFFB13030) : const Color(0xFF8A6420);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: corFundoIcone,
              shape: BoxShape.circle,
            ),
            child: Icon(
              atrasado
                  ? Icons.warning_rounded
                  : Icons.access_time_filled_rounded,
              color: corDestaque,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  atrasado ? 'Medicamento atrasado' : 'Próximo medicamento',
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF727272),
                        AppDarkColors.textSecondary),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  medicamento.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adaptive(
                        context, Colors.black, AppDarkColors.textPrimary),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (medicamento.dosagem != null)
                  Text(
                    'Dose: ${medicamento.dosagem}',
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF607178),
                          AppDarkColors.textSecondary),
                      fontSize: 12.5,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  medicamento.proximoHorario ?? '--:--',
                  style: TextStyle(
                    color: corDestaque,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: corBadgeFundo,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              atrasado ? 'Atrasado' : 'Pendente',
              style: TextStyle(
                color: corBadgeTexto,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicamentoCard extends StatelessWidget {
  const _MedicamentoCard({required this.medicamento, required this.onTap});

  final MedicamentoResumo medicamento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: adaptive(context, Colors.white, AppDarkColors.surface),
      borderRadius: BorderRadius.circular(11),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: medicamento.estoqueBaixo
                      ? const Color(0xFFD73A3A)
                      : const Color(0xFF148A9C),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(11),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medicamento.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: adaptive(context, Colors.black,
                                    AppDarkColors.textPrimary),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  medicamento.proximoAtrasado
                                      ? Icons.warning_rounded
                                      : Icons.access_time_rounded,
                                  color: medicamento.proximoAtrasado
                                      ? const Color(0xFFD73A3A)
                                      : adaptive(
                                          context,
                                          const Color(0xFF8A8A8A),
                                          AppDarkColors.textSecondary),
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  medicamento.proximoHorario == null
                                      ? 'Sem horário'
                                      : medicamento.proximoAtrasado
                                          ? 'Atrasado: ${medicamento.proximoHorario}'
                                          : 'Proximo horário: ${medicamento.proximoHorario}',
                                  style: TextStyle(
                                    color: medicamento.proximoAtrasado
                                        ? const Color(0xFFD73A3A)
                                        : adaptive(
                                            context,
                                            const Color(0xFF727272),
                                            AppDarkColors.textSecondary),
                                    fontSize: 11.5,
                                    fontWeight: medicamento.proximoAtrasado
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  color: medicamento.estoqueBaixo
                                      ? const Color(0xFFD73A3A)
                                      : adaptive(
                                          context,
                                          const Color(0xFF8A8A8A),
                                          AppDarkColors.textSecondary),
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  medicamento.quantidadeEstoque == null
                                      ? 'Estoque nao informado'
                                      : 'Estoque: ${_formatNumber(medicamento.quantidadeEstoque!)} ${medicamento.unidadeEstoque ?? ''}',
                                  style: TextStyle(
                                    color: medicamento.estoqueBaixo
                                        ? const Color(0xFFD73A3A)
                                        : adaptive(
                                            context,
                                            const Color(0xFF727272),
                                            AppDarkColors.textSecondary),
                                    fontSize: 11.5,
                                    fontWeight: medicamento.estoqueBaixo
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: adaptive(context, const Color(0xFF9AA0A6),
                            AppDarkColors.textSecondary),
                        size: 24,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: adaptive(
                  context, const Color(0xFFD8F1F4), AppDarkColors.tintedInfo),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: Color(0xFF148A9C),
              size: 50,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum medicamento cadastrado',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adaptive(
                  context, const Color(0xFF073248), AppDarkColors.textPrimary),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Cadastre o primeiro medicamento para organizar os horários e o estoque.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: adaptive(context, const Color(0xFF607178),
                    AppDarkColors.textSecondary),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicamentoFormView extends StatelessWidget {
  const _MedicamentoFormView({
    required this.formKey,
    required this.editando,
    required this.saving,
    required this.nomeController,
    required this.dosagemController,
    required this.estoqueController,
    required this.doseController,
    required this.observacoesController,
    required this.formato,
    required this.frequenciaTipo,
    required this.diasSemana,
    required this.horarios,
    required this.dataInicio,
    required this.dataFim,
    required this.lembretesAtivos,
    required this.onFormatoChanged,
    required this.onFrequenciaChanged,
    required this.onHorarioAdded,
    required this.onHorarioRemoved,
    required this.onDataInicioChanged,
    required this.onDataFimChanged,
    required this.onLembretesChanged,
    required this.onSave,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final bool editando;
  final bool saving;
  final TextEditingController nomeController;
  final TextEditingController dosagemController;
  final TextEditingController estoqueController;
  final TextEditingController doseController;
  final TextEditingController observacoesController;
  final String? formato;
  final String frequenciaTipo;
  final List<String> diasSemana;
  final List<String> horarios;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final bool lembretesAtivos;
  final ValueChanged<String?> onFormatoChanged;

  /// Recebe o novo tipo de frequencia ('diaria' | 'semanal' | 'alternado')
  /// e a lista de dias da semana (so relevante quando tipo == 'semanal').
  final void Function(String tipo, List<String> dias) onFrequenciaChanged;
  final ValueChanged<String> onHorarioAdded;
  final ValueChanged<int> onHorarioRemoved;
  final ValueChanged<DateTime?> onDataInicioChanged;
  final ValueChanged<DateTime?> onDataFimChanged;
  final ValueChanged<bool> onLembretesChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  Future<void> _escolherFormato(BuildContext context) async {
    final escolhido = await showModalBottomSheet<String>(
      context: context,
      backgroundColor:
          adaptive(context, Colors.white, AppDarkColors.surfaceElevated),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) =>
          const _OptionSheet(title: 'Formato', options: _kFormatos),
    );
    if (escolhido != null) onFormatoChanged(escolhido);
  }

  /// O que mostrar como chip no campo Frequencia. As tres opcoes (diaria,
  /// dias especificos, alternado) sao mutuamente exclusivas.
  List<String> get _frequenciaChips {
    if (frequenciaTipo == 'alternado') return const [_kDiaAlternado];
    if (frequenciaTipo == 'semanal') return diasSemana;
    if (frequenciaTipo == 'diaria') return const [_kTodosOsDias];
    return const [];
  }

  void _removerFrequencia(int index) {
    if (frequenciaTipo == 'semanal') {
      final restantes = [...diasSemana]..removeAt(index);
      onFrequenciaChanged(restantes.isEmpty ? 'diaria' : 'semanal', restantes);
      return;
    }
    onFrequenciaChanged('diaria', const []);
  }

  Future<void> _escolherFrequencia(BuildContext context) async {
    final escolha = await showModalBottomSheet<_FrequenciaEscolha>(
      context: context,
      backgroundColor:
          adaptive(context, Colors.white, AppDarkColors.surfaceElevated),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => _FrequenciaSheet(
        tipoInicial: frequenciaTipo,
        diasIniciais: diasSemana,
      ),
    );

    if (escolha != null) onFrequenciaChanged(escolha.tipo, escolha.dias);
  }

  Future<void> _escolherHorario(BuildContext context) async {
    final selecionado = await showTimePicker(
      context: Navigator.of(context, rootNavigator: true).context,
      initialTime: TimeOfDay.now(),
    );
    if (selecionado == null) return;
    final texto =
        '${selecionado.hour.toString().padLeft(2, '0')}:${selecionado.minute.toString().padLeft(2, '0')}';
    if (!horarios.contains(texto)) onHorarioAdded(texto);
  }

  Future<void> _escolherData(
    BuildContext context,
    DateTime? atual,
    ValueChanged<DateTime?> onChanged,
  ) async {
    final selecionada = await showDatePicker(
      context: Navigator.of(context, rootNavigator: true).context,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: atual ?? DateTime.now(),
    );
    if (selecionada != null) onChanged(selecionada);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 20, 10, 14),
      child: Column(
        children: [
          Text(
            editando ? 'Editar medicamento' : 'Adicionar medicamento',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF2FA3B5),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 12),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _FieldLabel('Nome do medicamento'),
                    _TextField(
                      controller: nomeController,
                      hintText: 'Digite o nome do medicamento',
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Informe o nome.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    const _FieldLabel('Dosagem'),
                    _TextField(
                      controller: dosagemController,
                      hintText: 'ex: 50mg, 1g',
                    ),
                    const SizedBox(height: 12),
                    const _FieldLabel('Formato'),
                    _ChipsField(
                      values: formato == null ? const [] : [formato!],
                      onAdd: () => _escolherFormato(context),
                      onRemove: (_) => onFormatoChanged(null),
                      addLabel: formato == null ? '+ Adicionar' : '+ Trocar',
                      maxItems: 1,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FieldLabel('Qtde. disponível'),
                              _TextField(
                                controller: estoqueController,
                                hintText: 'ex: 30 comprim.',
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FieldLabel('Qtde. por dose'),
                              _TextField(
                                controller: doseController,
                                hintText: 'ex: 1 comprim.',
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _FieldLabel('Frequencia'),
                    _ChipsField(
                      values: _frequenciaChips,
                      onAdd: () => _escolherFrequencia(context),
                      onRemove: _removerFrequencia,
                    ),
                    const SizedBox(height: 12),
                    const _FieldLabel('Horários'),
                    _ChipsField(
                      values: horarios,
                      onAdd: () => _escolherHorario(context),
                      onRemove: onHorarioRemoved,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FieldLabel('Data de início'),
                              _DateField(
                                value: dataInicio,
                                onTap: () => _escolherData(
                                  context,
                                  dataInicio,
                                  onDataInicioChanged,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FieldLabel('Data de término'),
                              _DateField(
                                value: dataFim,
                                onTap: () => _escolherData(
                                  context,
                                  dataFim,
                                  onDataFimChanged,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _FieldLabel('Observações'),
                    _TextField(
                      controller: observacoesController,
                      hintText: 'Observações sobre o uso do medicamento',
                      minLines: 3,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: _cardDecoration(context, radius: 9),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_outlined,
                            color: Color(0xFF148A9C),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ativar lembretes',
                              style: TextStyle(
                                color: adaptive(context, Colors.black,
                                    AppDarkColors.textPrimary),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Switch(
                            value: lembretesAtivos,
                            activeTrackColor: const Color(0xFF2FA3B5),
                            onChanged: onLembretesChanged,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: saving ? null : onSave,
                        style: _primaryButtonStyle(),
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(editando ? 'Salvar' : 'Salvar medicamento'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: saving ? null : onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: adaptive(
                              context,
                              const Color(0xFF245066),
                              AppDarkColors.textPrimary),
                          side: const BorderSide(color: Color(0xFF2FA3B5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5, top: 2),
      child: Text(
        text,
        style: TextStyle(
          color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.hintText,
    this.validator,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hintText;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int? minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
            color: adaptive(
                context, const Color(0xFF9B9B9B), AppDarkColors.textMuted),
            fontSize: 13.5),
        filled: true,
        fillColor: adaptive(context, Colors.white, AppDarkColors.surface),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(
              color: adaptive(
                  context, const Color(0xFFD7E0E3), AppDarkColors.border)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFF2FA3B5), width: 1.4),
        ),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: adaptive(context, Colors.white, AppDarkColors.surface),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: adaptive(
                  context, const Color(0xFFD7E0E3), AppDarkColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? 'selecionar data' : _formatDate(value!),
                style: TextStyle(
                  color: value == null
                      ? adaptive(context, const Color(0xFF9B9B9B),
                          AppDarkColors.textMuted)
                      : adaptive(
                          context, Colors.black, AppDarkColors.textPrimary),
                  fontSize: 13.5,
                ),
              ),
            ),
            Icon(
              Icons.calendar_month_rounded,
              color: adaptive(
                  context, const Color(0xFF8A8A8A), AppDarkColors.textMuted),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipsField extends StatelessWidget {
  const _ChipsField({
    required this.values,
    required this.onAdd,
    required this.onRemove,
    this.addLabel = '+ Adicionar',
    this.maxItems,
  });

  final List<String> values;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final String addLabel;
  final int? maxItems;

  @override
  Widget build(BuildContext context) {
    final podeAdicionar = maxItems == null || values.length < maxItems!;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < values.length; i++)
          Chip(
            label: Text(values[i]),
            labelStyle: const TextStyle(
              color: Color(0xFF0E6F7E),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: adaptive(
                context, const Color(0xFFD8F1F4), AppDarkColors.tintedInfo),
            deleteIcon: const Icon(Icons.close_rounded, size: 16),
            deleteIconColor: const Color(0xFF0E6F7E),
            onDeleted: () => onRemove(i),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide.none,
            ),
            visualDensity: VisualDensity.compact,
          ),
        if (podeAdicionar)
          OutlinedButton(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2FA3B5),
              side: const BorderSide(color: Color(0xFF2FA3B5)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              textStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            child: Text(addLabel),
          ),
      ],
    );
  }
}

class _OptionSheet extends StatelessWidget {
  const _OptionSheet({required this.title, required this.options});

  final String title;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: adaptive(context, const Color(0xFF073248),
                    AppDarkColors.textPrimary),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final option in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option),
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
  }
}

class _FrequenciaEscolha {
  const _FrequenciaEscolha({required this.tipo, required this.dias});

  final String tipo;
  final List<String> dias;
}

/// Bottom sheet com as 3 frequencias mutuamente exclusivas ("Todos os
/// dias", "Dias especificos" e "Dia sim, dia nao"). Quando "Dias
/// especificos" e escolhido, os chips de dia da semana aparecem para
/// selecao multipla; as outras duas opcoes fecham a folha na hora, ja
/// que nao precisam de mais nenhuma escolha.
class _FrequenciaSheet extends StatefulWidget {
  const _FrequenciaSheet({
    required this.tipoInicial,
    required this.diasIniciais,
  });

  final String tipoInicial;
  final List<String> diasIniciais;

  @override
  State<_FrequenciaSheet> createState() => _FrequenciaSheetState();
}

class _FrequenciaSheetState extends State<_FrequenciaSheet> {
  late String _tipo;
  late Set<String> _dias;

  @override
  void initState() {
    super.initState();
    _tipo = widget.tipoInicial;
    _dias = widget.tipoInicial == 'semanal'
        ? widget.diasIniciais.toSet()
        : <String>{};
  }

  void _selecionarModo(String tipo) {
    setState(() => _tipo = tipo);
    if (tipo != 'semanal') {
      Navigator.of(context).pop(_FrequenciaEscolha(tipo: tipo, dias: const []));
    }
  }

  void _confirmarDiasEspecificos() {
    Navigator.of(context).pop(
      _FrequenciaEscolha(tipo: 'semanal', dias: _dias.toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          16,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Frequência',
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF073248),
                      AppDarkColors.textPrimary),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              _FrequenciaOpcao(
                icon: Icons.event_repeat_rounded,
                label: _kTodosOsDias,
                selecionado: _tipo == 'diaria',
                onTap: () => _selecionarModo('diaria'),
              ),
              _FrequenciaOpcao(
                icon: Icons.swap_horiz_rounded,
                label: _kDiaAlternado,
                selecionado: _tipo == 'alternado',
                onTap: () => _selecionarModo('alternado'),
              ),
              _FrequenciaOpcao(
                icon: Icons.event_note_rounded,
                label: 'Dias específicos',
                selecionado: _tipo == 'semanal',
                onTap: () => _selecionarModo('semanal'),
              ),
              if (_tipo == 'semanal') ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final dia in _kDiasSemana)
                      FilterChip(
                        label: Text(dia),
                        selected: _dias.contains(dia),
                        onSelected: (selecionado) => setState(() {
                          if (selecionado) {
                            _dias.add(dia);
                          } else {
                            _dias.remove(dia);
                          }
                        }),
                        selectedColor: const Color(0xFFD8F1F4),
                        checkmarkColor: const Color(0xFF0E6F7E),
                        labelStyle: TextStyle(
                          color: _dias.contains(dia)
                              ? const Color(0xFF0E6F7E)
                              : const Color(0xFF394B52),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: _dias.isEmpty ? null : _confirmarDiasEspecificos,
                    style: _primaryButtonStyle(),
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FrequenciaOpcao extends StatelessWidget {
  const _FrequenciaOpcao({
    required this.icon,
    required this.label,
    required this.selecionado,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: selecionado
            ? const Color(0xFF0E6F7E)
            : adaptive(
                context, const Color(0xFF8A8A8A), AppDarkColors.textSecondary),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selecionado
              ? const Color(0xFF0E6F7E)
              : adaptive(context, Colors.black, AppDarkColors.textPrimary),
          fontWeight: selecionado ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      trailing: Icon(
        selecionado ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selecionado ? const Color(0xFF0E6F7E) : const Color(0xFFBBBBBB),
      ),
      onTap: onTap,
    );
  }
}

class _HistoricoView extends StatelessWidget {
  const _HistoricoView({
    required this.entradas,
    required this.periodo,
    required this.onBack,
    required this.onPeriodoChanged,
  });

  final List<HistoricoMedicamentoEntrada> entradas;
  final _Periodo periodo;
  final VoidCallback onBack;
  final ValueChanged<_Periodo> onPeriodoChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFF2A9CAE),
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
          const Center(
            child: Text(
              'ello',
              style: TextStyle(
                color: Color(0xFF0E6F7E),
                fontSize: 28,
                fontWeight: FontWeight.w300,
                letterSpacing: 0,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Histórico de Remédios',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adaptive(
                  context, const Color(0xFF073248), AppDarkColors.textPrimary),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _PeriodoSelector(periodo: periodo, onChanged: onPeriodoChanged),
          const SizedBox(height: 14),
          Expanded(
            child: entradas.isEmpty
                ? const _HistoricoVazio()
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: entradas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => StaggeredEntry(
                      index: index,
                      child: _HistoricoItem(entrada: entradas[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PeriodoSelector extends StatelessWidget {
  const _PeriodoSelector({required this.periodo, required this.onChanged});

  final _Periodo periodo;
  final ValueChanged<_Periodo> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF9BD1DA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _PeriodoItem(
            label: 'Dia',
            selected: periodo == _Periodo.dia,
            onTap: () => onChanged(_Periodo.dia),
          ),
          _PeriodoItem(
            label: 'Semanal',
            selected: periodo == _Periodo.semanal,
            onTap: () => onChanged(_Periodo.semanal),
          ),
          _PeriodoItem(
            label: 'Mês',
            selected: periodo == _Periodo.mes,
            onTap: () => onChanged(_Periodo.mes),
          ),
        ],
      ),
    );
  }
}

class _PeriodoItem extends StatelessWidget {
  const _PeriodoItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF087B8D) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF17324D),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoricoVazio extends StatelessWidget {
  const _HistoricoVazio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded,
                color: Color(0xFF2FA3B5), size: 48),
            const SizedBox(height: 10),
            Text(
              'Nenhum registro neste período',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: adaptive(context, const Color(0xFF073248),
                    AppDarkColors.textPrimary),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Altere o período ou registre um medicamento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: adaptive(context, const Color(0xFF607178),
                      AppDarkColors.textSecondary),
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoricoItem extends StatelessWidget {
  const _HistoricoItem({required this.entrada});

  final HistoricoMedicamentoEntrada entrada;

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor(entrada.badge.cor);
    final icone = switch (entrada.descricao) {
      'marcou como tomado' => Icons.check_circle_rounded,
      'atualizou dosagem' || 'atualizou medicamento' => Icons.edit_rounded,
      'reagendou horário' => Icons.schedule_rounded,
      _ => Icons.medication_rounded,
    };
    final iconColor = switch (entrada.descricao) {
      'marcou como tomado' => const Color(0xFF28A745),
      'atualizou dosagem' || 'atualizou medicamento' => const Color(0xFF2FA3B5),
      _ => const Color(0xFF148A9C),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(context, radius: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entrada.usuarioNome} ${entrada.descricao}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adaptive(
                        context, Colors.black, AppDarkColors.textPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entrada.medicamentoNome,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF808080),
                        AppDarkColors.textMuted),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(entrada.dataHora),
                style: TextStyle(
                    color: adaptive(context, const Color(0xFF9AA0A6),
                        AppDarkColors.textSecondary),
                    fontSize: 10),
              ),
              Text(
                _formatTime(entrada.dataHora),
                style: TextStyle(
                  color: adaptive(
                      context, Colors.black, AppDarkColors.textPrimary),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entrada.badge.texto,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetalheView extends StatelessWidget {
  const _DetalheView({
    required this.medicamento,
    required this.administracoes,
    required this.carregando,
    required this.saving,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
    required this.onRegistrarDose,
  });

  final MedicamentoResumo medicamento;
  final List<Map<String, dynamic>> administracoes;
  final bool carregando;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRegistrarDose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            onBack: onBack,
            title: medicamento.nome,
            trailing: PopupMenuButton<String>(
              icon:
                  const Icon(Icons.more_vert_rounded, color: Color(0xFF2A9CAE)),
              onSelected: (value) {
                if (value == 'editar') onEdit();
                if (value == 'remover') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(value: 'remover', child: Text('Remover')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                StaggeredEntry(
                  index: 0,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: _cardDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (medicamento.dosagem != null)
                          _DetailRow('Dosagem', medicamento.dosagem!),
                        if (medicamento.formato != null)
                          _DetailRow('Formato', medicamento.formato!),
                        _DetailRow(
                          'Estoque',
                          medicamento.quantidadeEstoque == null
                              ? 'Nao informado'
                              : '${_formatNumber(medicamento.quantidadeEstoque!)} ${medicamento.unidadeEstoque ?? ''}',
                        ),
                        if (medicamento.proximoHorario != null)
                          _DetailRow(
                            'Proximo horário',
                            medicamento.proximoHorario!,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                StaggeredEntry(
                  index: 1,
                  child: Text(
                    'Registrar dose agora',
                    style: TextStyle(
                      color: adaptive(
                          context, Colors.black, AppDarkColors.textPrimary),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                StaggeredEntry(
                  index: 2,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: saving ? null : onRegistrarDose,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Remédio dado'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF28A745),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Últimas doses',
                  style: TextStyle(
                    color: adaptive(
                        context, Colors.black, AppDarkColors.textPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (carregando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF2FA8B8)),
                    ),
                  )
                else if (administracoes.isEmpty)
                  Text(
                    'Nenhuma dose registrada ainda.',
                    style: TextStyle(
                        color: adaptive(context, const Color(0xFF8A8A8A),
                            AppDarkColors.textMuted),
                        fontSize: 12.5),
                  )
                else
                  for (var i = 0; i < administracoes.length; i++) ...[
                    StaggeredEntry(
                      index: i + 3,
                      child: _AdministracaoTile(dado: administracoes[i]),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                  color: adaptive(context, const Color(0xFF8A8A8A),
                      AppDarkColors.textMuted),
                  fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: adaptive(context, const Color(0xFF17324D),
                    AppDarkColors.textPrimary),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdministracaoTile extends StatelessWidget {
  const _AdministracaoTile({required this.dado});

  final Map<String, dynamic> dado;

  @override
  Widget build(BuildContext context) {
    final status = (dado['status'] ?? '').toString();
    final administradoEm = DateTime.tryParse(
      (dado['administrado_em'] ?? '').toString(),
    );
    final horarioPrevisto = DateTime.tryParse(
      (dado['horario_previsto'] ?? '').toString(),
    );
    final statusEfetivo =
        status == 'tomado' && administradoEm != null && horarioPrevisto != null
            ? _statusComAtraso(administradoEm, horarioPrevisto)
            : status;
    final info = _kStatusDose.firstWhere(
      (item) => item.$1 == statusEfetivo,
      orElse: () =>
          ('', status, Icons.medication_rounded, const Color(0xFF8A8A8A)),
    );
    final data = (administradoEm ?? horarioPrevisto)?.toLocal();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _cardDecoration(context, radius: 9),
      child: Row(
        children: [
          Icon(info.$3, color: info.$4, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              info.$2,
              style: TextStyle(
                color:
                    adaptive(context, Colors.black, AppDarkColors.textPrimary),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (data != null)
            Text(
              '${_formatDate(data)} ${_formatTime(data)}',
              style: TextStyle(
                  color: adaptive(context, const Color(0xFF8A8A8A),
                      AppDarkColors.textMuted),
                  fontSize: 11.5),
            ),
        ],
      ),
    );
  }
}

class _NoIdosoState extends StatelessWidget {
  const _NoIdosoState({required this.onGoBack});

  final VoidCallback onGoBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_search_rounded,
              color: Color(0xFF2FA3B5), size: 54),
          const SizedBox(height: 10),
          Text(
            'Escolha uma ficha',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adaptive(
                  context, const Color(0xFF073248), AppDarkColors.textPrimary),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Selecione uma pessoa idosa para gerenciar os medicamentos.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: adaptive(context, const Color(0xFF607178),
                    AppDarkColors.textSecondary),
                fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onGoBack,
            style: _primaryButtonStyle(),
            child: const Text('Selecionar ficha'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onBack, required this.onRetry});

  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(onBack: onBack, title: 'Medicações'),
          const Spacer(),
          const Icon(Icons.cloud_off_rounded,
              color: Color(0xFF2FA3B5), size: 54),
          const SizedBox(height: 10),
          Text(
            'Não foi possível carregar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adaptive(
                  context, const Color(0xFF073248), AppDarkColors.textPrimary),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confira a conexão com a API e tente novamente.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: adaptive(context, const Color(0xFF607178),
                    AppDarkColors.textSecondary),
                fontSize: 13),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onRetry,
            style: _primaryButtonStyle(),
            child: const Text('Tentar novamente'),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context, {double radius = 12}) {
  return BoxDecoration(
    color: adaptive(context, Colors.white, AppDarkColors.surface),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

ButtonStyle _primaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF3BA7B8),
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
  );
}

Color _badgeColor(String cor) {
  return switch (cor) {
    'normal' => const Color(0xFF28A745),
    'alerta' => const Color(0xFFE49A20),
    'atualizado' => const Color(0xFF7C5CD6),
    _ => const Color(0xFF5C7A8A),
  };
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

const _kToleranciaAtrasoMinutos = 30;

String _statusComAtraso(DateTime administradoEm, DateTime horarioPrevisto) {
  final atrasoMinutos = administradoEm.difference(horarioPrevisto).inMinutes;
  return atrasoMinutos > _kToleranciaAtrasoMinutos ? 'atrasado' : 'tomado';
}

bool _medicamentoOccursOnDay(
  MedicamentoHorario horario,
  DateTime day,
  DateTime reference,
) {
  switch (horario.frequenciaTipo.toLowerCase().trim()) {
    case 'semanal':
      if (horario.diasSemana.isEmpty) return true;
      return horario.diasSemana
          .map(_weekdayFromMedicationLabel)
          .whereType<int>()
          .contains(day.weekday);
    case 'alternado':
      final referenceDay = DateTime(
        reference.year,
        reference.month,
        reference.day,
      );
      final targetDay = DateTime(day.year, day.month, day.day);
      return targetDay.difference(referenceDay).inDays.isEven;
    default:
      return true;
  }
}

int? _weekdayFromMedicationLabel(String value) {
  final exactIndex = _kDiasSemana.indexOf(value);
  if (exactIndex >= 0) return exactIndex == 0 ? DateTime.sunday : exactIndex;

  final normalized = value.toLowerCase().trim();
  if (normalized.startsWith('dom')) return DateTime.sunday;
  if (normalized.startsWith('seg')) return DateTime.monday;
  if (normalized.startsWith('ter')) return DateTime.tuesday;
  if (normalized.startsWith('qua')) return DateTime.wednesday;
  if (normalized.startsWith('qui')) return DateTime.thursday;
  if (normalized.startsWith('sex')) return DateTime.friday;
  if (normalized.startsWith('sab') || normalized.startsWith('sÃ¡b')) {
    return DateTime.saturday;
  }
  return null;
}

String _isoDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

DateTime _horarioPrevistoParaAgora(String? proximoHorario, DateTime agora) {
  if (proximoHorario == null) return agora;
  final partes = proximoHorario.split(':');
  if (partes.length < 2) return agora;
  final hora = int.tryParse(partes[0]);
  final minuto = int.tryParse(partes[1]);
  if (hora == null || minuto == null) return agora;
  return DateTime(agora.year, agora.month, agora.day, hora, minuto);
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year.toString().padLeft(4, '0')}';
}

String _formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _toIsoDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
