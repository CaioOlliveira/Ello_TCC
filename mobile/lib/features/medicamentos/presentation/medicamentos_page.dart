import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
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
    _resumoFuture =
        ref.read(apiClientProvider).getResumoMedicamentos(idosoId: idosoId);
  }

  void _reloadResumo(String idosoId) {
    setState(() {
      _resumoLoadedIdosoId = idosoId;
      _resumoFuture =
          ref.read(apiClientProvider).getResumoMedicamentos(idosoId: idosoId);
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editando ? 'Medicamento atualizado.' : 'Medicamento registrado.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar o medicamento.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _registrarDose(String status) async {
    final idoso = ref.read(selectedIdosoProvider);
    final medicamento = _selecionado;
    if (idoso == null || medicamento == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).registrarAdministracaoMedicamento(
            medicamentoId: medicamento.id,
            idosoId: idoso.id,
            horarioPrevisto: DateTime.now(),
            status: status,
            registradoPorId: ref.read(authSessionProvider)?.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dose registrada.')),
      );
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
        const SnackBar(content: Text('Não foi possível registrar a dose.')),
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
      backgroundColor: const Color(0xFFFAFAFA),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
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
                    onBack: () => context.go('/monitoramento'),
                    onRetry: () => _reloadResumo(idoso.id),
                  );
                }

                final resumo =
                    snapshot.data ?? MedicamentosResumo.fromJson(const {});

                return _ResumoView(
                  resumo: resumo,
                  onBack: () => context.go('/monitoramento'),
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
                foregroundColor: const Color(0xFF245066),
                side: const BorderSide(color: Color(0xFF2FA3B5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Ver Histórico'),
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
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: Color(0xFF2A9CAE),
            size: 30,
          ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF073248),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(width: 40, child: trailing),
      ],
    );
  }
}

class _ProximoMedicamentoCard extends StatelessWidget {
  const _ProximoMedicamentoCard({required this.medicamento});

  final MedicamentoResumo medicamento;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFD8F1F4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time_filled_rounded,
              color: Color(0xFF148A9C),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Próximo medicamento',
                  style: TextStyle(color: Color(0xFF727272), fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  medicamento.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (medicamento.dosagem != null)
                  Text(
                    'Dose: ${medicamento.dosagem}',
                    style: const TextStyle(
                      color: Color(0xFF607178),
                      fontSize: 12.5,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  medicamento.proximoHorario ?? '--:--',
                  style: const TextStyle(
                    color: Color(0xFF148A9C),
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
              color: const Color(0xFFF3E3C4),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Pendente',
              style: TextStyle(
                color: Color(0xFF8A6420),
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
      color: Colors.white,
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
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  color: Color(0xFF8A8A8A),
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  medicamento.proximoHorario == null
                                      ? 'Sem horário'
                                      : 'Próximo horário: ${medicamento.proximoHorario}',
                                  style: const TextStyle(
                                    color: Color(0xFF727272),
                                    fontSize: 11.5,
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
                                      : const Color(0xFF8A8A8A),
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  medicamento.quantidadeEstoque == null
                                      ? 'Estoque não informado'
                                      : 'Estoque: ${_formatNumber(medicamento.quantidadeEstoque!)} ${medicamento.unidadeEstoque ?? ''}',
                                  style: TextStyle(
                                    color: medicamento.estoqueBaixo
                                        ? const Color(0xFFD73A3A)
                                        : const Color(0xFF727272),
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
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF9AA0A6),
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
            decoration: const BoxDecoration(
              color: Color(0xFFD8F1F4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: Color(0xFF148A9C),
              size: 50,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhum medicamento cadastrado',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF073248),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Cadastre o primeiro medicamento para organizar os horários e o estoque.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF607178), fontSize: 13),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) =>
          const _OptionSheet(title: 'Formato', options: _kFormatos),
    );
    if (escolhido != null) onFormatoChanged(escolhido);
  }

  /// O que mostrar como chips no campo Frequência, de acordo com o tipo
  /// selecionado ('diaria' nao mostra chip, ja que e o padrao implicito).
  List<String> get _frequenciaChips {
    if (frequenciaTipo == 'alternado') return const [_kDiaAlternado];
    if (frequenciaTipo == 'semanal') return diasSemana;
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
    final diasEscolhidos =
        frequenciaTipo == 'semanal' ? diasSemana : const <String>[];
    final diasDisponiveis =
        _kDiasSemana.where((dia) => !diasEscolhidos.contains(dia)).toList();

    final escolha = await showModalBottomSheet<_FrequenciaEscolha>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => _FrequenciaSheet(diasDisponiveis: diasDisponiveis),
    );

    if (escolha == null) return;

    if (escolha.dia != null) {
      onFrequenciaChanged('semanal', [...diasEscolhidos, escolha.dia!]);
    } else {
      onFrequenciaChanged(escolha.tipo, const []);
    }
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
                    const _FieldLabel('Frequência'),
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
                      decoration: _cardDecoration(radius: 9),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_outlined,
                            color: Color(0xFF148A9C),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Ativar lembretes',
                              style: TextStyle(
                                color: Colors.black,
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
                          foregroundColor: const Color(0xFF245066),
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
        style: const TextStyle(
          color: Colors.black,
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
        hintStyle: const TextStyle(color: Color(0xFF9B9B9B), fontSize: 13.5),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFD7E0E3)),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFD7E0E3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? 'selecionar data' : _formatDate(value!),
                style: TextStyle(
                  color: value == null ? const Color(0xFF9B9B9B) : Colors.black,
                  fontSize: 13.5,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF8A8A8A),
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
            backgroundColor: const Color(0xFFD8F1F4),
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
              style: const TextStyle(
                color: Color(0xFF073248),
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
  const _FrequenciaEscolha.tipo(this.tipo) : dia = null;
  const _FrequenciaEscolha.dia(this.dia) : tipo = 'semanal';

  final String tipo;
  final String? dia;
}

class _FrequenciaSheet extends StatelessWidget {
  const _FrequenciaSheet({required this.diasDisponiveis});

  final List<String> diasDisponiveis;

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
            const Text(
              'Frequência',
              style: TextStyle(
                color: Color(0xFF073248),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.event_repeat_rounded,
                color: Color(0xFF2FA3B5),
              ),
              title: const Text(_kTodosOsDias),
              onTap: () => Navigator.of(context)
                  .pop(const _FrequenciaEscolha.tipo('diaria')),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.swap_horiz_rounded,
                color: Color(0xFF2FA3B5),
              ),
              title: const Text(_kDiaAlternado),
              onTap: () => Navigator.of(context)
                  .pop(const _FrequenciaEscolha.tipo('alternado')),
            ),
            if (diasDisponiveis.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Divider(height: 1),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 2),
                child: Text(
                  'Ou dias específicos',
                  style: TextStyle(
                    color: Color(0xFF8A8A8A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final dia in diasDisponiveis)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(dia),
                  onTap: () =>
                      Navigator.of(context).pop(_FrequenciaEscolha.dia(dia)),
                ),
            ],
          ],
        ),
      ),
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
          const Text(
            'Histórico de Remédios',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF073248),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, color: Color(0xFF2FA3B5), size: 48),
            SizedBox(height: 10),
            Text(
              'Nenhum registro neste período',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF073248),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Altere o período ou registre um medicamento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF607178), fontSize: 13),
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
      decoration: _cardDecoration(radius: 10),
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
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entrada.medicamentoNome,
                  style: const TextStyle(
                    color: Color(0xFF808080),
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
                style: const TextStyle(color: Color(0xFF9AA0A6), fontSize: 10),
              ),
              Text(
                _formatTime(entrada.dataHora),
                style: const TextStyle(
                  color: Colors.black,
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
  final ValueChanged<String> onRegistrarDose;

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
                    decoration: _cardDecoration(),
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
                              ? 'Não informado'
                              : '${_formatNumber(medicamento.quantidadeEstoque!)} ${medicamento.unidadeEstoque ?? ''}',
                        ),
                        if (medicamento.proximoHorario != null)
                          _DetailRow(
                            'Próximo horário',
                            medicamento.proximoHorario!,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const StaggeredEntry(
                  index: 1,
                  child: Text(
                    'Registrar dose agora',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                StaggeredEntry(
                  index: 2,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final status in _kStatusDose)
                        OutlinedButton.icon(
                          onPressed:
                              saving ? null : () => onRegistrarDose(status.$1),
                          icon: Icon(status.$3, color: status.$4, size: 17),
                          label: Text(status.$2),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: status.$4,
                            side: BorderSide(color: status.$4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Últimas doses',
                  style: TextStyle(
                    color: Colors.black,
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
                  const Text(
                    'Nenhuma dose registrada ainda.',
                    style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 12.5),
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
              style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF17324D),
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
    final info = _kStatusDose.firstWhere(
      (item) => item.$1 == status,
      orElse: () =>
          ('', status, Icons.medication_rounded, const Color(0xFF8A8A8A)),
    );
    final dataTexto =
        (dado['administrado_em'] ?? dado['horario_previsto'])?.toString();
    final data = dataTexto == null ? null : DateTime.tryParse(dataTexto);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _cardDecoration(radius: 9),
      child: Row(
        children: [
          Icon(info.$3, color: info.$4, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              info.$2,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (data != null)
            Text(
              '${_formatDate(data)} ${_formatTime(data)}',
              style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 11.5),
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
          const Text(
            'Escolha uma ficha',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF073248),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Selecione um idoso para gerenciar os medicamentos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF607178), fontSize: 13),
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
          const Text(
            'Não foi possível carregar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF073248),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Confira a conexão com a API e tente novamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF607178), fontSize: 13),
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

BoxDecoration _cardDecoration({double radius = 12}) {
  return BoxDecoration(
    color: Colors.white,
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
