import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/navigation/module_navigation.dart';
import '../../../shared/widgets/module_header.dart';

enum _AlimentacaoView { lista, tipo, form, galeria }

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
  String _draftTipo = 'Café da manhã';
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
    final personText = idoso.elderText;

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
          content: Text(
            'Tomar muita água de uma vez pode ser prejudicial ${personText.to}. Continue adicionando apenas se esse consumo realmente aconteceu.',
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
              style: TextStyle(
                color: adaptive(context, const Color(0xFF073248),
                    AppDarkColors.textPrimary),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (_imageProvider(refeicao.recordatorio) != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(
                  image: _imageProvider(refeicao.recordatorio)!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
            ],
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
      backgroundColor:
          adaptive(context, const Color(0xFFFAFAFA), AppDarkColors.bg),
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
                  onBack: () => context.go(moduleBackRoute(context)),
                  onRetry: _load,
                  onSaveWeight: _saveWeight,
                  onAddWater: _addWater,
                  onGallery: () =>
                      setState(() => _view = _AlimentacaoView.galeria),
                  onHistory: () => context.push(
                    routeWithCurrentOrigin(context, '/historico/alimentacao'),
                  ),
                  onAdd: () => setState(() {
                    _editing = null;
                    _draftTipo = 'Café da manhã';
                    _view = _AlimentacaoView.tipo;
                  }),
                  onDetails: _showDetails,
                  onEdit: (refeicao) => setState(() {
                    _editing = refeicao;
                    _draftTipo = _normalizeMealType(refeicao.tipoRefeicao);
                    _view = _AlimentacaoView.form;
                  }),
                  onConclude: _concluir,
                ),
              _AlimentacaoView.tipo => _MealTypePickerView(
                  selected: _draftTipo,
                  onBack: () => setState(() => _view = _AlimentacaoView.lista),
                  onSelected: (tipo) => setState(() {
                    _draftTipo = tipo;
                    _view = _AlimentacaoView.form;
                  }),
                ),
              _AlimentacaoView.form => _RefeicaoFormView(
                  idosoId: idoso?.id ?? '',
                  usuarioId: ref.watch(authSessionProvider)?.id,
                  initialTipo: _draftTipo,
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
              _AlimentacaoView.galeria => _RecordatorioGalleryView(
                  refeicoes: _refeicoes,
                  onBack: () => setState(() => _view = _AlimentacaoView.lista),
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
    required this.onGallery,
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
  final VoidCallback onGallery;
  final VoidCallback onHistory;
  final VoidCallback onAdd;
  final ValueChanged<RefeicaoResumo> onDetails;
  final ValueChanged<RefeicaoResumo> onEdit;
  final ValueChanged<RefeicaoResumo> onConclude;

  @override
  Widget build(BuildContext context) {
    final todayMeals = refeicoes.where(_isTodayMeal).toList();
    final recordatorios = refeicoes
        .where((item) => _imageProvider(item.recordatorio) != null)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Row(
            children: [
              ModuleBackButton(onPressed: onBack),
              Expanded(
                child: Text(
                  'Alimentação',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: adaptive(context, ModuleHeader.titleColor,
                        AppDarkColors.textPrimary),
                    fontSize: ModuleHeader.titleStyle.fontSize,
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
                const SizedBox(height: 18),
                if (recordatorios.isNotEmpty) ...[
                  _RecordatorioStrip(
                    refeicoes: recordatorios,
                    onOpen: onGallery,
                  ),
                  const SizedBox(height: 22),
                ],
                Text(
                  'Refeições do dia',
                  style: TextStyle(
                    color: adaptive(
                        context, Colors.black, AppDarkColors.textPrimary),
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
                height: 56,
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
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onHistory,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: adaptive(context, const Color(0xFF073248),
                        AppDarkColors.textPrimary),
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
        decoration: _softCardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Peso ${widget.idoso?.elderText.of ?? 'da pessoa idosa'}',
              style: TextStyle(
                color: adaptive(context, const Color(0xFF073248),
                    AppDarkColors.textPrimary),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Informe o peso para calcular a meta diária de água.',
              style: TextStyle(
                  color: adaptive(context, const Color(0xFF6E7C83),
                      AppDarkColors.textSecondary),
                  fontSize: 12),
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
                      fillColor: adaptive(
                          context, Colors.white, AppDarkColors.surface),
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
      decoration: _softCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Água consumida',
            style: TextStyle(
              color: adaptive(
                  context, const Color(0xFF073248), AppDarkColors.textPrimary),
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
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF073248),
                            AppDarkColors.textPrimary),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: value,
                          backgroundColor: adaptive(
                              context,
                              const Color(0xFFE0E0E0),
                              AppDarkColors.surfaceAlt),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF003B4F),
                          ),
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
              Expanded(
                child: Text(
                  'Adicionar água',
                  style: TextStyle(
                      color: adaptive(context, const Color(0xFF777777),
                          AppDarkColors.textSecondary),
                      fontSize: 11),
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
                _WaterCup(
                  filled: i < filledCups,
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Copo: 200ml',
              style: TextStyle(
                  color: adaptive(context, const Color(0xFF777777),
                      AppDarkColors.textSecondary),
                  fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterCup extends StatelessWidget {
  const _WaterCup({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: filled ? 1.0 : 0.86,
      duration: const Duration(milliseconds: 360),
      curve: Curves.elasticOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          filled ? Icons.local_drink_rounded : Icons.local_drink_outlined,
          key: ValueKey(filled),
          color: const Color(0xFF098CA1),
          size: 36,
        ),
      ),
    );
  }
}

class _RecordatorioStrip extends StatelessWidget {
  const _RecordatorioStrip({
    required this.refeicoes,
    required this.onOpen,
  });

  final List<RefeicaoResumo> refeicoes;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final preview = refeicoes.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recordatório alimentar',
                style: TextStyle(
                  color: adaptive(
                    context,
                    const Color(0xFF073248),
                    AppDarkColors.textPrimary,
                  ),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: onOpen,
              child: const Text('Ver tudo'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: preview.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final refeicao = preview[index];
              return InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image(
                    image: _imageProvider(refeicao.recordatorio)!,
                    width: 78,
                    height: 78,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecordatorioGalleryView extends StatelessWidget {
  const _RecordatorioGalleryView({
    required this.refeicoes,
    required this.onBack,
  });

  final List<RefeicaoResumo> refeicoes;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final groups = _groupRecordatoriosByDate(refeicoes);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: Row(
            children: [
              ModuleBackButton(onPressed: onBack),
              Expanded(
                child: Text(
                  'Recordatório',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: adaptive(
                      context,
                      ModuleHeader.titleColor,
                      AppDarkColors.textPrimary,
                    ),
                    fontSize: ModuleHeader.titleStyle.fontSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 78),
            ],
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('Nenhuma foto registrada.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: [
                    for (final group in groups.entries) ...[
                      Text(
                        group.key,
                        style: TextStyle(
                          color: adaptive(
                            context,
                            const Color(0xFF073248),
                            AppDarkColors.textPrimary,
                          ),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: group.value.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                        itemBuilder: (context, index) {
                          final refeicao = group.value[index];
                          return InkWell(
                            onTap: () => _showRecordatorioPhoto(
                              context,
                              refeicao,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image(
                                image: _imageProvider(refeicao.recordatorio)!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _MealTypePickerView extends StatelessWidget {
  const _MealTypePickerView({
    required this.selected,
    required this.onBack,
    required this.onSelected,
  });

  final String selected;
  final VoidCallback onBack;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ModuleBackButton(onPressed: onBack),
          ),
          const SizedBox(height: 46),
          Text(
            'Qual refeição será registrada?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adaptive(
                context,
                const Color(0xFF073248),
                AppDarkColors.textPrimary,
              ),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          for (final tipo in _mealTypeOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MealTypeOption(
                label: tipo,
                selected: selected == tipo,
                onTap: () => onSelected(tipo),
              ),
            ),
        ],
      ),
    );
  }
}

class _MealTypeOption extends StatelessWidget {
  const _MealTypeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? adaptive(context, const Color(0xFFE1F6F8), AppDarkColors.tintedInfo)
          : adaptive(context, Colors.white, AppDarkColors.surface),
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(_mealIcon(label), color: const Color(0xFF098CA1), size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: adaptive(
                      context,
                      const Color(0xFF073248),
                      AppDarkColors.textPrimary,
                    ),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF098CA1),
              ),
            ],
          ),
        ),
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
        color: filled
            ? adaptive(
                context, const Color(0xFFD5EEF3), AppDarkColors.tintedInfo)
            : adaptive(context, Colors.white, AppDarkColors.surface),
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
          Icon(_mealIcon(_normalizeMealType(refeicao.tipoRefeicao)),
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
                        _normalizeMealType(refeicao.tipoRefeicao),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adaptive(
                              context, Colors.black, AppDarkColors.textPrimary),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!refeicao.concluida)
                      Text(
                        'Pendente',
                        style: TextStyle(
                          color: adaptive(context, const Color(0xFF073248),
                              AppDarkColors.textPrimary),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                Text(
                  refeicao.horaConsumo ?? '--:--',
                  style: TextStyle(
                      color: adaptive(context, const Color(0xFF777777),
                          AppDarkColors.textSecondary),
                      fontSize: 11),
                ),
                Text(
                  refeicao.alimentos.map((item) => item.nome).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: adaptive(context, const Color(0xFF777777),
                          AppDarkColors.textSecondary),
                      fontSize: 11),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _TinyButton(label: 'Ver detalhes', onTap: onDetails),
                    const SizedBox(width: 6),
                    _TinyButton(label: 'Editar', onTap: onEdit),
                    const SizedBox(width: 6),
                    _TinyButton(
                      label: refeicao.concluida ? 'Concluída' : 'Concluir',
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
            foregroundColor: adaptive(
                context, const Color(0xFF073248), AppDarkColors.textPrimary),
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
    required this.initialTipo,
    required this.onCancel,
    required this.onSaved,
    required this.onConfirmTwoHourWarning,
    this.usuarioId,
    this.initial,
  });

  final String idosoId;
  final String? usuarioId;
  final RefeicaoResumo? initial;
  final String initialTipo;
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
  final _picker = ImagePicker();

  String _tipo = 'Café da manhã';
  String _aceitacao = 'comeu_tudo';
  String? _recordatorio;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final now = DateTime.now();
    if (initial == null) {
      _tipo = widget.initialTipo;
      _dataController.text = _formatDate(now);
      _horaController.text = _formatTime(now);
      return;
    }

    _tipo = _normalizeMealType(initial.tipoRefeicao);
    _aceitacao = initial.aceitacao;
    _dataController.text = initial.dataConsumo == null
        ? _formatDate(now)
        : _formatDate(initial.dataConsumo!);
    _horaController.text = initial.horaConsumo ?? _formatTime(now);
    _recordatorio = initial.recordatorio;
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

  Future<void> _takePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 72,
        maxWidth: 1280,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final extension = _imageExtension(image.name);
      setState(() {
        _recordatorio = 'data:image/$extension;base64,${base64Encode(bytes)}';
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível abrir a câmera.');
    }
  }

  Future<void> _showMealTypeEditSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tipo de refeição',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final tipo in _mealTypeOptions)
              ListTile(
                leading: Icon(_mealIcon(tipo), color: const Color(0xFF098CA1)),
                title: Text(tipo),
                trailing: _tipo == tipo
                    ? const Icon(Icons.check_rounded, color: Color(0xFF098CA1))
                    : null,
                onTap: () => Navigator.of(context).pop(tipo),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _tipo = selected);
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
      'recordatorio': _recordatorio ?? '',
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
          Row(
            children: [
              Expanded(
                child: Text(
                  _tipo,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF073248),
                        AppDarkColors.textPrimary),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.initial != null)
                TextButton.icon(
                  onPressed: () => _showMealTypeEditSheet(context),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Trocar'),
                ),
            ],
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
          const SizedBox(height: 18),
          _FoodPhotoPicker(
            recordatorio: _recordatorio,
            onTakePhoto: _takePhoto,
            onRemove: () => setState(() => _recordatorio = null),
          ),
          const SizedBox(height: 18),
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
            decoration: _inputDecoration(context),
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
                foregroundColor: adaptive(context, const Color(0xFF073248),
                    AppDarkColors.textPrimary),
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
          color: adaptive(
              context, const Color(0xFFEFEFEF), AppDarkColors.surfaceAlt),
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
                style: TextStyle(
                    color: adaptive(context, const Color(0xFF386073),
                        AppDarkColors.textPrimary),
                    fontSize: 14),
              ),
            ),
            Text(
              '${_formatNumber(alimento.calorias ?? 0)}kcal  ${_formatNumber(alimento.pesoGramas ?? 0)}g',
              style: TextStyle(
                  color: adaptive(context, const Color(0xFF386073),
                      AppDarkColors.textPrimary),
                  fontSize: 12),
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

class _FoodPhotoPicker extends StatelessWidget {
  const _FoodPhotoPicker({
    required this.recordatorio,
    required this.onTakePhoto,
    required this.onRemove,
  });

  final String? recordatorio;
  final VoidCallback onTakePhoto;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final provider = _imageProvider(recordatorio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto da refeição',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Material(
          color: adaptive(context, Colors.white, AppDarkColors.surface),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTakePhoto,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: provider == null ? 62 : 172,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2BA8BA)),
                image: provider == null
                    ? null
                    : DecorationImage(image: provider, fit: BoxFit.cover),
              ),
              child: provider == null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.photo_camera_outlined,
                          color: Color(0xFF098CA1),
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Tirar foto da comida',
                          style: TextStyle(
                            color: adaptive(context, const Color(0xFF073248),
                                AppDarkColors.textPrimary),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  : Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: IconButton.filled(
                          onPressed: onRemove,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFC0392B),
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
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

const _mealTypeOptions = [
  'Café da manhã',
  'Almoço',
  'Café da tarde',
  'Jantar',
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
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? adaptive(
                  context, const Color(0xFFE3F5F8), AppDarkColors.tintedInfo)
              : adaptive(context, Colors.white, AppDarkColors.surface),
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
                fontSize: 11,
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
      return const Icon(Icons.close, color: Color(0xFF2A99AB), size: 28);
    }

    return CustomPaint(
      size: const Size.square(25),
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
          decoration: _inputDecoration(context, suffixIcon: suffixIcon),
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
        fillColor: adaptive(
            context, const Color(0xFFE9E9E9), AppDarkColors.surfaceAlt),
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

InputDecoration _inputDecoration(BuildContext context, {IconData? suffixIcon}) {
  return InputDecoration(
    filled: true,
    fillColor: adaptive(context, Colors.white, AppDarkColors.surface),
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

BoxDecoration _softCardDecoration(BuildContext context) {
  return BoxDecoration(
    color: adaptive(context, Colors.white, AppDarkColors.surface),
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

String _normalizeMealType(String value) {
  final lower = value.trim().toLowerCase();
  return switch (lower) {
    'cafe da manha' || 'café da manhã' => 'Café da manhã',
    'lanche da manha' || 'lanche da manhã' => 'Lanche da manhã',
    'almoco' || 'almoço' => 'Almoço',
    'cafe da tarde' || 'café da tarde' || 'lanche da tarde' => 'Café da tarde',
    'janta' || 'jantar' => 'Jantar',
    'ceia' => 'Ceia',
    _ => value,
  };
}

IconData _mealIcon(String value) {
  final lower = value.toLowerCase();
  if (lower.contains('almo')) return Icons.lunch_dining_outlined;
  if (lower.contains('janta') || lower.contains('jantar')) {
    return Icons.dinner_dining_outlined;
  }
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

ImageProvider? _imageProvider(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('data:image')) {
    final comma = value.indexOf(',');
    if (comma == -1) return null;
    try {
      return MemoryImage(base64Decode(value.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    return NetworkImage(value);
  }
  return null;
}

String _imageExtension(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'png';
  if (lower.endsWith('.webp')) return 'webp';
  return 'jpeg';
}

Map<String, List<RefeicaoResumo>> _groupRecordatoriosByDate(
  List<RefeicaoResumo> refeicoes,
) {
  final withImages = refeicoes
      .where((item) => _imageProvider(item.recordatorio) != null)
      .toList()
    ..sort((a, b) {
      final ad = _mealDateTime(a) ?? DateTime(1900);
      final bd = _mealDateTime(b) ?? DateTime(1900);
      return bd.compareTo(ad);
    });

  final grouped = <String, List<RefeicaoResumo>>{};
  for (final refeicao in withImages) {
    final date = refeicao.dataConsumo ?? DateTime.now();
    grouped.putIfAbsent(_formatDate(date), () => []).add(refeicao);
  }
  return grouped;
}

void _showRecordatorioPhoto(BuildContext context, RefeicaoResumo refeicao) {
  final provider = _imageProvider(refeicao.recordatorio);
  if (provider == null) return;

  showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image(image: provider, fit: BoxFit.contain),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  '${_normalizeMealType(refeicao.tipoRefeicao)} • '
                  '${refeicao.horaConsumo ?? '--:--'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
