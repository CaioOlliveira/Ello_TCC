import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

enum _AlimentacaoView { lista, form }

class AlimentacaoPage extends ConsumerStatefulWidget {
  const AlimentacaoPage({super.key});

  @override
  ConsumerState<AlimentacaoPage> createState() => _AlimentacaoPageState();
}

class _AlimentacaoPageState extends ConsumerState<AlimentacaoPage> {
  _AlimentacaoView _view = _AlimentacaoView.lista;
  List<RefeicaoResumo> _refeicoes = const [];
  List<HidratacaoRegistro> _hidratacoes = const [];
  RefeicaoResumo? _editing;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null) {
      if (mounted) context.go('/idosos');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.listarRefeicoes(idosoId: idoso.id),
        api.listarHidratacoes(idosoId: idoso.id),
      ]);
      if (!mounted) return;
      setState(() {
        _refeicoes = results[0] as List<RefeicaoResumo>;
        _hidratacoes = results[1] as List<HidratacaoRegistro>;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível carregar as refeições.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _concluir(RefeicaoResumo refeicao) async {
    try {
      await ref.read(apiClientProvider).concluirRefeicao(
            id: refeicao.id,
            usuarioId: ref.read(authSessionProvider)?.id,
          );
      if (!mounted) return;
      _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _saveWeight(double pesoKg) async {
    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null) return;

    try {
      await ref.read(apiClientProvider).atualizarIdoso(
        id: idoso.id,
        data: {'pesoKg': pesoKg},
      );
      ref.read(selectedIdosoProvider.notifier).state =
          idoso.copyWith(pesoKg: pesoKg);
      if (!mounted) return;
      setState(() {});
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _addWater() async {
    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null) return;

    final now = DateTime.now();
    final last30 = _hidratacoes
        .where((item) =>
            now.difference(item.registradoEm.toLocal()).inMinutes <= 30)
        .fold<double>(0, (sum, item) => sum + item.quantidadeMl);

    if (last30 + 200 > 600) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Atenção'),
          content: const Text(
            'Tomar muita água de uma vez pode ser prejudicial ao idoso. Continue adicionando apenas se esse consumo realmente aconteceu.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    }

    try {
      await ref.read(apiClientProvider).criarHidratacao(
            idosoId: idoso.id,
            quantidadeMl: 200,
            registradoPorId: ref.read(authSessionProvider)?.id,
          );
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  void _showDetails(RefeicaoResumo refeicao) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              refeicao.tipoRefeicao,
              style: const TextStyle(
                color: Color(0xFF073248),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (final alimento in refeicao.alimentos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${alimento.nome} - ${_formatNumber(alimento.pesoGramas ?? 0)}g',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            const SizedBox(height: 10),
            Text('Consumo: ${_acceptanceLabel(refeicao.aceitacao)}'),
            if (refeicao.observacoes?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(refeicao.observacoes!),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmTwoHourWarning(DateTime scheduled) async {
    final last = _lastDateTime(_refeicoes);
    if (last == null) return true;
    final diffMinutes = scheduled.difference(last).inMinutes.abs();
    if (diffMinutes >= 120) return true;

    final hours = diffMinutes ~/ 60;
    final minutes = diffMinutes % 60;
    final label = hours > 0 ? '${hours}h ${minutes}min' : '${minutes}min';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar refeição?'),
        content: Text(
          'A última refeição foi cadastrada há $label. Deseja adicionar outra mesmo assim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: switch (_view) {
              _AlimentacaoView.lista => _AlimentacaoListView(
                  refeicoes: _refeicoes,
                  idoso: idoso,
                  hidratacoes: _hidratacoes,
                  loading: _loading,
                  error: _error,
                  onBack: () => context.go('/monitoramento'),
                  onRetry: _load,
                  onSaveWeight: _saveWeight,
                  onAddWater: _addWater,
                  onHistory: () => context.push('/historico/alimentacao'),
                  onAdd: () => setState(() {
                    _editing = null;
                    _view = _AlimentacaoView.form;
                  }),
                  onDetails: _showDetails,
                  onEdit: (refeicao) => setState(() {
                    _editing = refeicao;
                    _view = _AlimentacaoView.form;
                  }),
                  onConclude: _concluir,
                ),
              _AlimentacaoView.form => _RefeicaoFormView(
                  idosoId: idoso?.id ?? '',
                  usuarioId: ref.watch(authSessionProvider)?.id,
                  initial: _editing,
                  refeicoes: _refeicoes,
                  onCancel: () => setState(() {
                    _editing = null;
                    _view = _AlimentacaoView.lista;
                  }),
                  onSaved: () {
                    setState(() {
                      _editing = null;
                      _view = _AlimentacaoView.lista;
                    });
                    _load();
                  },
                  onConfirmTwoHourWarning: _confirmTwoHourWarning,
                ),
            },
          ),
        ),
      ),
    );
  }
}

class _AlimentacaoListView extends StatelessWidget {
  const _AlimentacaoListView({
    required this.refeicoes,
    required this.idoso,
    required this.hidratacoes,
    required this.loading,
    required this.onBack,
    required this.onRetry,
    required this.onSaveWeight,
    required this.onAddWater,
    required this.onHistory,
    required this.onAdd,
    required this.onDetails,
    required this.onEdit,
    required this.onConclude,
    this.error,
  });

  final List<RefeicaoResumo> refeicoes;
  final IdosoResumo? idoso;
  final List<HidratacaoRegistro> hidratacoes;
  final bool loading;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final ValueChanged<double> onSaveWeight;
  final VoidCallback onAddWater;
  final VoidCallback onHistory;
  final VoidCallback onAdd;
  final ValueChanged<RefeicaoResumo> onDetails;
  final ValueChanged<RefeicaoResumo> onEdit;
  final ValueChanged<RefeicaoResumo> onConclude;

  @override
  Widget build(BuildContext context) {
    final todayMeals = refeicoes.where(_isTodayMeal).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.chevron_left_rounded, size: 30),
                label: const Text('Voltar'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF073248),
                ),
              ),
              const Expanded(
                child: Text(
                  'Alimentacao',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF073248),
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 78),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => onRetry(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              children: [
                _WaterCard(
                  idoso: idoso,
                  hidratacoes: hidratacoes,
                  onSaveWeight: onSaveWeight,
                  onAddWater: onAddWater,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Refeicoes do dia',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (error != null)
                  _ErrorBox(message: error!, onRetry: onRetry)
                else if (todayMeals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 35),
                    child: Center(child: Text('Nenhuma refeição cadastrada.')),
                  )
                else
                  for (final refeicao in todayMeals)
                    _MealCard(
                      refeicao: refeicao,
                      onDetails: () => onDetails(refeicao),
                      onEdit: () => onEdit(refeicao),
                      onConclude: () => onConclude(refeicao),
                    ),
                const SizedBox(height: 88),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 27),
                  label: const Text('Adicionar refeição'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1897AA),
                    side:
                        const BorderSide(color: Color(0xFF1897AA), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 46,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onHistory,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF073248),
                    side:
                        const BorderSide(color: Color(0xFF1897AA), width: 1.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Ver histórico'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaterCard extends StatefulWidget {
  const _WaterCard({
    required this.idoso,
    required this.hidratacoes,
    required this.onSaveWeight,
    required this.onAddWater,
  });

  final IdosoResumo? idoso;
  final List<HidratacaoRegistro> hidratacoes;
  final ValueChanged<double> onSaveWeight;
  final VoidCallback onAddWater;

  @override
  State<_WaterCard> createState() => _WaterCardState();
}

class _WaterCardState extends State<_WaterCard> {
  final _pesoController = TextEditingController();

  @override
  void dispose() {
    _pesoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peso = widget.idoso?.pesoKg;
    final todayTotal = widget.hidratacoes
        .where((item) => _isToday(item.registradoEm.toLocal()))
        .fold<double>(0, (sum, item) => sum + item.quantidadeMl);

    if (peso == null || peso <= 0) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: _softCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Peso do idoso',
              style: TextStyle(
                color: Color(0xFF073248),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Informe o peso para calcular a meta diaria de agua.',
              style: TextStyle(color: Color(0xFF6E7C83), fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pesoController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'Ex: 67',
                      suffixText: 'kg',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFF2BA8BA)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFF2BA8BA)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () {
                    final value = double.tryParse(
                      _pesoController.text.trim().replaceAll(',', '.'),
                    );
                    if (value == null || value <= 0) return;
                    widget.onSaveWeight(value);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF37A3B4),
                  ),
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final target = (peso * 30).roundToDouble();
    final progress = target <= 0 ? 0.0 : (todayTotal / target).clamp(0.0, 1.0);
    final cupCount = (target / 200).ceil().clamp(1, 14);
    final filledCups = (todayTotal / 200).floor().clamp(0, cupCount);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Agua consumida',
            style: TextStyle(
              color: Color(0xFF073248),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.local_drink_outlined,
                color: Color(0xFF2BA8BA),
                size: 34,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${todayTotal.toInt()}ml / ${target.toInt()}ml',
                      style: const TextStyle(
                        color: Color(0xFF073248),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: progress,
                        backgroundColor: const Color(0xFFE0E0E0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF003B4F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Adicionar agua',
                  style: TextStyle(color: Color(0xFF777777), fontSize: 11),
                ),
              ),
              SizedBox(
                height: 34,
                width: 34,
                child: IconButton.filled(
                  onPressed: widget.onAddWater,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF37A3B4),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (var i = 0; i < cupCount; i++)
                InkWell(
                  onTap: widget.onAddWater,
                  borderRadius: BorderRadius.circular(8),
                  child: Icon(
                    i < filledCups
                        ? Icons.local_drink_rounded
                        : Icons.local_drink_outlined,
                    color: const Color(0xFF098CA1),
                    size: 32,
                  ),
                ),
            ],
          ),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Copo: 200ml',
              style: TextStyle(color: Color(0xFF777777), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.refeicao,
    required this.onDetails,
    required this.onEdit,
    required this.onConclude,
  });

  final RefeicaoResumo refeicao;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onConclude;

  @override
  Widget build(BuildContext context) {
    final filled = !refeicao.concluida;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFD5EEF3) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(_mealIcon(refeicao.tipoRefeicao),
              color: const Color(0xFF098CA1), size: 35),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        refeicao.tipoRefeicao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!refeicao.concluida)
                      const Text(
                        'Pendente',
                        style: TextStyle(
                          color: Color(0xFF073248),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                Text(
                  refeicao.horaConsumo ?? '--:--',
                  style:
                      const TextStyle(color: Color(0xFF777777), fontSize: 11),
                ),
                Text(
                  refeicao.alimentos.map((item) => item.nome).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xFF777777), fontSize: 11),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _TinyButton(label: 'Ver detalhes', onTap: onDetails),
                    const SizedBox(width: 6),
                    _TinyButton(label: 'Editar', onTap: onEdit),
                    const SizedBox(width: 6),
                    _TinyButton(
                      label: refeicao.concluida ? 'Concluida' : 'Concluir',
                      onTap: refeicao.concluida ? null : onConclude,
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

class _TinyButton extends StatelessWidget {
  const _TinyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 20,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8BCDD8),
            foregroundColor: const Color(0xFF073248),
            padding: EdgeInsets.zero,
            textStyle:
                const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: Text(label, maxLines: 1),
        ),
      ),
    );
  }
}

class _RefeicaoFormView extends ConsumerStatefulWidget {
  const _RefeicaoFormView({
    required this.idosoId,
    required this.refeicoes,
    required this.onCancel,
    required this.onSaved,
    required this.onConfirmTwoHourWarning,
    this.usuarioId,
    this.initial,
  });

  final String idosoId;
  final String? usuarioId;
  final RefeicaoResumo? initial;
  final List<RefeicaoResumo> refeicoes;
  final VoidCallback onCancel;
  final VoidCallback onSaved;
  final Future<bool> Function(DateTime scheduled) onConfirmTwoHourWarning;

  @override
  ConsumerState<_RefeicaoFormView> createState() => _RefeicaoFormViewState();
}

class _RefeicaoFormViewState extends ConsumerState<_RefeicaoFormView> {
  final _dataController = TextEditingController();
  final _horaController = TextEditingController();
  final _alimentoController = TextEditingController();
  final _pesoController = TextEditingController();
  final _observacoesController = TextEditingController();
  final List<AlimentoConsumido> _alimentos = [];

  String _tipo = 'Cafe da manha';
  String _aceitacao = 'comeu_tudo';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final now = DateTime.now();
    if (initial == null) {
      _dataController.text = _formatDate(now);
      _horaController.text = _formatTime(now);
      return;
    }

    _tipo = initial.tipoRefeicao;
    _aceitacao = initial.aceitacao;
    _dataController.text = initial.dataConsumo == null
        ? _formatDate(now)
        : _formatDate(initial.dataConsumo!);
    _horaController.text = initial.horaConsumo ?? _formatTime(now);
    _observacoesController.text = initial.observacoes ?? '';
    _alimentos.addAll(initial.alimentos);
  }

  @override
  void dispose() {
    _dataController.dispose();
    _horaController.dispose();
    _alimentoController.dispose();
    _pesoController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  void _addFood() {
    final nome = _alimentoController.text.trim();
    if (nome.isEmpty) return;
    final peso = double.tryParse(_pesoController.text.replaceAll(',', '.'));
    setState(() {
      _alimentos.add(
        AlimentoConsumido(
          nome: nome,
          pesoGramas: peso,
          calorias: 20,
        ),
      );
      _alimentoController.clear();
      _pesoController.clear();
      _error = null;
    });
  }

  void _editFood(AlimentoConsumido alimento) {
    setState(() {
      _alimentos.remove(alimento);
      _alimentoController.text = alimento.nome;
      _pesoController.text = alimento.pesoGramas == null
          ? ''
          : _formatNumber(alimento.pesoGramas!);
      _error = null;
    });
  }

  DateTime? _scheduledDateTime() {
    final date = _parseDate(_dataController.text);
    final time = _parseTime(_horaController.text);
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.$1, time.$2);
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final current = _parseDate(_dataController.text) ?? now;
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
      initialDate: current.isBefore(DateTime(now.year, now.month, now.day))
          ? now
          : current,
    );
    if (selected == null) return;
    _dataController.text = _formatDate(selected);
  }

  Future<void> _selectTime() async {
    final parsed = _parseTime(_horaController.text);
    final selected = await showTimePicker(
      context: context,
      initialTime: parsed == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: parsed.$1, minute: parsed.$2),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (selected == null) return;
    _horaController.text =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final scheduled = _scheduledDateTime();
    if (scheduled == null) {
      setState(() => _error = 'Informe data e hora válidas.');
      return;
    }
    final now = DateTime.now();
    final currentMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    if (scheduled.isBefore(currentMinute)) {
      setState(
          () => _error = 'A data e hora não podem ser anteriores a agora.');
      return;
    }
    if (_alimentos.isEmpty) {
      setState(() => _error = 'Informe ao menos um alimento.');
      return;
    }
    if (widget.initial == null &&
        !await widget.onConfirmTwoHourWarning(scheduled)) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final data = {
      'idosoId': widget.idosoId,
      'tipoRefeicao': _tipo,
      'dataConsumo': _toIsoDate(_dataController.text),
      'horaConsumo': _horaController.text,
      'alimentos': _alimentos.map((item) => item.toJson()).toList(),
      'aceitacao': _aceitacao,
      if (_observacoesController.text.trim().isNotEmpty)
        'observacoes': _observacoesController.text.trim(),
      if (widget.usuarioId != null && widget.usuarioId!.isNotEmpty)
        'registradoPorId': widget.usuarioId,
    };

    try {
      final api = ref.read(apiClientProvider);
      if (widget.initial == null) {
        await api.criarRefeicao(data: data);
      } else {
        await api.atualizarRefeicao(id: widget.initial!.id, data: data);
      }
      if (!mounted) return;
      widget.onSaved();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível salvar a refeição.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        16,
        58,
        16,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _tipo,
            decoration: const InputDecoration(border: InputBorder.none),
            style: const TextStyle(
              color: Color(0xFF073248),
              fontSize: 21,
              fontWeight: FontWeight.w500,
            ),
            items: const [
              DropdownMenuItem(
                  value: 'Cafe da manha', child: Text('Café da manhã')),
              DropdownMenuItem(value: 'Almoco', child: Text('Almoço')),
              DropdownMenuItem(
                  value: 'Cafe da tarde', child: Text('Café da tarde')),
              DropdownMenuItem(value: 'Janta', child: Text('Janta')),
            ],
            onChanged: (value) => setState(() => _tipo = value ?? _tipo),
          ),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Data',
                  controller: _dataController,
                  suffixIcon: Icons.calendar_month,
                  readOnly: true,
                  onTap: _selectDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LabeledField(
                  label: 'Hora',
                  controller: _horaController,
                  suffixIcon: Icons.access_time_rounded,
                  readOnly: true,
                  onTap: _selectTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Alimentos consumidos',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _PlainInput(
                  controller: _alimentoController,
                  hintText: 'Buscar alimento',
                  prefixIcon: Icons.search,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PlainInput(
                  controller: _pesoController,
                  hintText: 'g',
                  keyboardType: TextInputType.number,
                ),
              ),
              IconButton(
                onPressed: _addFood,
                icon: const Icon(Icons.add_circle, color: Color(0xFF098CA1)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final alimento in _alimentos)
            _FoodChip(
              alimento: alimento,
              onEdit: () => _editFood(alimento),
              onRemove: () => setState(() => _alimentos.remove(alimento)),
            ),
          const SizedBox(height: 16),
          const Text('Consumo', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final option in _acceptanceOptions)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: _AcceptanceButton(
                      option: option,
                      selected: _aceitacao == option.id,
                      onTap: () => setState(() => _aceitacao = option.id),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Observações',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          TextField(
            controller: _observacoesController,
            minLines: 4,
            maxLines: 5,
            decoration: _inputDecoration(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC0392B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 90),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF37A3B4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Salvar',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: _saving ? null : widget.onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF073248),
                side: const BorderSide(color: Color(0xFF1897AA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodChip extends StatelessWidget {
  const _FoodChip({
    required this.alimento,
    required this.onEdit,
    required this.onRemove,
  });

  final AlimentoConsumido alimento;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                alimento.nome,
                style: const TextStyle(color: Color(0xFF386073), fontSize: 14),
              ),
            ),
            Text(
              '${_formatNumber(alimento.calorias ?? 0)}kcal  ${_formatNumber(alimento.pesoGramas ?? 0)}g',
              style: const TextStyle(color: Color(0xFF386073), fontSize: 12),
            ),
            IconButton(
              tooltip: 'Remover alimento',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.cancel, color: Color(0xFF006F80)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptanceOption {
  const _AcceptanceOption(this.id, this.label, this.fraction);

  final String id;
  final String label;
  final double? fraction;
}

const _acceptanceOptions = [
  _AcceptanceOption('comeu_tudo', 'Comeu tudo', 1),
  _AcceptanceOption('comeu_bem', 'Comeu bem', .75),
  _AcceptanceOption('comeu_metade', 'Comeu metade', .5),
  _AcceptanceOption('comeu_pouco', 'Comeu pouco', .25),
  _AcceptanceOption('nao_comeu', 'Não comeu', null),
];

class _AcceptanceButton extends StatelessWidget {
  const _AcceptanceButton({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _AcceptanceOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE3F5F8) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2BA8BA)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AcceptanceIcon(option: option),
            const SizedBox(height: 5),
            Text(
              option.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                color: Color(0xFF2A99AB),
                fontSize: 10,
                height: 1.05,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptanceIcon extends StatelessWidget {
  const _AcceptanceIcon({required this.option});

  final _AcceptanceOption option;

  @override
  Widget build(BuildContext context) {
    if (option.fraction == null) {
      return const Icon(Icons.close, color: Color(0xFF2A99AB), size: 24);
    }

    return CustomPaint(
      size: const Size.square(21),
      painter: _AcceptanceIconPainter(option.fraction!),
    );
  }
}

class _AcceptanceIconPainter extends CustomPainter {
  const _AcceptanceIconPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFF2A99AB);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (fraction >= 1) {
      canvas.drawCircle(center, radius, paint);
      return;
    }

    canvas.drawArc(
      rect,
      -1.5708,
      6.28318 * fraction,
      true,
      paint,
    );

    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 1, outline);
  }

  @override
  bool shouldRepaint(covariant _AcceptanceIconPainter oldDelegate) {
    return oldDelegate.fraction != fraction;
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final IconData? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          decoration: _inputDecoration(suffixIcon: suffixIcon),
        ),
      ],
    );
  }
}

class _PlainInput extends StatelessWidget {
  const _PlainInput({
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        filled: true,
        fillColor: const Color(0xFFE9E9E9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

InputDecoration _inputDecoration({IconData? suffixIcon}) {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffixIcon == null
        ? null
        : Icon(suffixIcon, color: const Color(0xFF2BA8BA)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF2BA8BA)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF2BA8BA)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        OutlinedButton(
            onPressed: onRetry, child: const Text('Tentar novamente')),
      ],
    );
  }
}

bool _isTodayMeal(RefeicaoResumo refeicao) {
  final date = refeicao.dataConsumo;
  if (date == null) return false;
  return _isToday(date);
}

bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

BoxDecoration _softCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.16),
        blurRadius: 5,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

RefeicaoResumo? _lastMeal(List<RefeicaoResumo> refeicoes) {
  if (refeicoes.isEmpty) return null;
  final sorted = [...refeicoes]..sort((a, b) {
      final ad = _mealDateTime(a) ?? DateTime(1900);
      final bd = _mealDateTime(b) ?? DateTime(1900);
      return bd.compareTo(ad);
    });
  return sorted.first;
}

DateTime? _lastDateTime(List<RefeicaoResumo> refeicoes) {
  final last = _lastMeal(refeicoes);
  return last == null ? null : _mealDateTime(last);
}

DateTime? _mealDateTime(RefeicaoResumo refeicao) {
  final date = refeicao.dataConsumo;
  final time = _parseTime(refeicao.horaConsumo ?? '');
  if (date == null || time == null) return null;
  return DateTime(date.year, date.month, date.day, time.$1, time.$2);
}

String _acceptanceLabel(String value) {
  return switch (value) {
    'comeu_tudo' => 'Comeu tudo',
    'comeu_bem' => 'Comeu bem',
    'comeu_metade' => 'Comeu metade',
    'comeu_pouco' => 'Comeu pouco',
    'nao_comeu' => 'Não comeu',
    _ => value,
  };
}

IconData _mealIcon(String value) {
  final lower = value.toLowerCase();
  if (lower.contains('almoco')) return Icons.lunch_dining_outlined;
  if (lower.contains('janta')) return Icons.dinner_dining_outlined;
  return Icons.bakery_dining_outlined;
}

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

String _formatTime(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.hour)}:${two(date.minute)}';
}

DateTime? _parseDate(String value) {
  final parts = value.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

(int, int)? _parseTime(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour > 23 || minute > 59) return null;
  return (hour, minute);
}

String? _toIsoDate(String value) {
  final parsed = _parseDate(value);
  if (parsed == null) return null;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)}';
}

String _formatNumber(double value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}
