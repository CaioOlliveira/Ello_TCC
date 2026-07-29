import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/staggered_entry.dart';

enum _OxigenacaoMode { resumo, registrar, historico }

enum _ChartPeriod { dia, semanal, mes }

class OxigenacaoPage extends ConsumerStatefulWidget {
  const OxigenacaoPage({super.key});

  @override
  ConsumerState<OxigenacaoPage> createState() => _OxigenacaoPageState();
}

class _OxigenacaoPageState extends ConsumerState<OxigenacaoPage> {
  final _formKey = GlobalKey<FormState>();
  final _saturacaoController = TextEditingController();
  final _pulsoController = TextEditingController();
  final _observacoesController = TextEditingController();

  Future<OxigenacaoResumo>? _resumoFuture;
  String? _loadedIdosoId;
  _ChartPeriod? _loadedPeriod;

  Future<List<OxigenacaoHistoricoEntrada>>? _historicoFuture;
  String? _historicoLoadedIdosoId;
  _ChartPeriod? _historicoLoadedPeriod;
  _ChartPeriod _historicoPeriod = _ChartPeriod.dia;

  _OxigenacaoMode _mode = _OxigenacaoMode.resumo;
  _ChartPeriod _period = _ChartPeriod.dia;
  DateTime _referenceDate = DateTime.now();
  DateTime _medicaoDate = DateTime.now();
  TimeOfDay _medicaoTime = TimeOfDay.now();
  bool _saving = false;

  @override
  void dispose() {
    _saturacaoController.dispose();
    _pulsoController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  void _ensureResumo(String idosoId) {
    if (_loadedIdosoId == idosoId &&
        _loadedPeriod == _period &&
        _resumoFuture != null) {
      return;
    }
    _loadedIdosoId = idosoId;
    _loadedPeriod = _period;
    _resumoFuture = ref.read(apiClientProvider).getResumoOxigenacao(
          idosoId: idosoId,
          dataReferencia: _referenceDate,
          periodo: _period.apiValue,
        );
  }

  void _reloadResumo(String idosoId) {
    setState(() {
      _loadedIdosoId = idosoId;
      _loadedPeriod = _period;
      _resumoFuture = ref.read(apiClientProvider).getResumoOxigenacao(
            idosoId: idosoId,
            dataReferencia: _referenceDate,
            periodo: _period.apiValue,
          );
    });
  }

  void _ensureHistorico(String idosoId) {
    if (_historicoLoadedIdosoId == idosoId &&
        _historicoLoadedPeriod == _historicoPeriod &&
        _historicoFuture != null) {
      return;
    }
    _historicoLoadedIdosoId = idosoId;
    _historicoLoadedPeriod = _historicoPeriod;
    _historicoFuture = ref.read(apiClientProvider).getHistoricoOxigenacao(
          idosoId: idosoId,
          dataReferencia: _referenceDate,
          periodo: _historicoPeriod.apiValue,
        );
  }

  void _reloadHistorico(String idosoId) {
    setState(() {
      _historicoLoadedIdosoId = idosoId;
      _historicoLoadedPeriod = _historicoPeriod;
      _historicoFuture = ref.read(apiClientProvider).getHistoricoOxigenacao(
            idosoId: idosoId,
            dataReferencia: _referenceDate,
            periodo: _historicoPeriod.apiValue,
          );
    });
  }

  Future<void> _openCalendar(String idosoId) async {
    final selected = await showDatePicker(
      context: _pickerContext,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _referenceDate,
    );

    if (selected == null) return;
    setState(() => _referenceDate = selected);
    _reloadResumo(idosoId);
    _reloadHistorico(idosoId);
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: _pickerContext,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _medicaoDate,
    );
    if (selected != null) setState(() => _medicaoDate = selected);
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: _pickerContext,
      initialTime: _medicaoTime,
    );
    if (selected != null) setState(() => _medicaoTime = selected);
  }

  BuildContext get _pickerContext {
    return Navigator.of(context, rootNavigator: true).context;
  }

  Future<void> _salvar(IdosoResumo idoso) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final saturacao = int.parse(_saturacaoController.text.trim());
      final pulsoTexto = _pulsoController.text.trim();
      final medidoEm = _combine(_medicaoDate, _medicaoTime);
      await ref.read(apiClientProvider).criarOxigenacao(
            idosoId: idoso.id,
            saturacao: saturacao,
            medidoEm: medidoEm,
            pulso: pulsoTexto.isEmpty ? null : int.parse(pulsoTexto),
            observacoes: _observacoesController.text.trim(),
            registradoPorId: ref.read(authSessionProvider)?.id,
          );

      if (!mounted) return;
      _saturacaoController.clear();
      _pulsoController.clear();
      _observacoesController.clear();
      setState(() => _mode = _OxigenacaoMode.resumo);
      _reloadResumo(idoso.id);
      _reloadHistorico(idoso.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oxigenação registrada.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível registrar oxigenação.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
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
    final feelingHint = idoso.elderText.howFeeling();

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
          _OxigenacaoMode.registrar => _RegistrarOxigenacaoView(
              formKey: _formKey,
              saturacaoController: _saturacaoController,
              pulsoController: _pulsoController,
              observacoesController: _observacoesController,
              selectedDate: _medicaoDate,
              selectedTime: _medicaoTime,
              observationHint: feelingHint,
              saving: _saving,
              onSelectDate: _selectDate,
              onSelectTime: _selectTime,
              onSave: () => _salvar(idoso),
              onCancel: () => setState(() => _mode = _OxigenacaoMode.resumo),
            ),
          _OxigenacaoMode.historico =>
            FutureBuilder<List<OxigenacaoHistoricoEntrada>>(
              future: _historicoFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2FA8B8)),
                  );
                }

                if (snapshot.hasError) {
                  return _ErrorState(
                    onBack: () =>
                        setState(() => _mode = _OxigenacaoMode.resumo),
                    onRetry: () => _reloadHistorico(idoso.id),
                  );
                }

                return _HistoricoOxigenacaoView(
                  entradas: snapshot.data ?? const [],
                  period: _historicoPeriod,
                  onBack: () => setState(() => _mode = _OxigenacaoMode.resumo),
                  onPeriodChanged: (period) {
                    setState(() => _historicoPeriod = period);
                    _reloadHistorico(idoso.id);
                  },
                );
              },
            ),
          _OxigenacaoMode.resumo => FutureBuilder<OxigenacaoResumo>(
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
                    snapshot.data ?? OxigenacaoResumo.fromJson(const {});

                return _ResumoOxigenacaoView(
                  idoso: idoso,
                  resumo: resumo,
                  period: _period,
                  onBack: () => context.go('/monitoramento'),
                  onRegistrar: () {
                    setState(() => _mode = _OxigenacaoMode.registrar);
                  },
                  onViewHistorico: () {
                    setState(() => _mode = _OxigenacaoMode.historico);
                  },
                  onCalendar: () => _openCalendar(idoso.id),
                  onPeriodChanged: (period) {
                    setState(() => _period = period);
                    _reloadResumo(idoso.id);
                  },
                );
              },
            ),
        },
      ),
    );
  }
}

extension _ChartPeriodApi on _ChartPeriod {
  String get apiValue {
    return switch (this) {
      _ChartPeriod.dia => 'dia',
      _ChartPeriod.semanal => 'semanal',
      _ChartPeriod.mes => 'mes',
    };
  }
}

class _ResumoOxigenacaoView extends StatelessWidget {
  const _ResumoOxigenacaoView({
    required this.idoso,
    required this.resumo,
    required this.period,
    required this.onBack,
    required this.onRegistrar,
    required this.onViewHistorico,
    required this.onCalendar,
    required this.onPeriodChanged,
  });

  final IdosoResumo idoso;
  final OxigenacaoResumo resumo;
  final _ChartPeriod period;
  final VoidCallback onBack;
  final VoidCallback onRegistrar;
  final VoidCallback onViewHistorico;
  final VoidCallback onCalendar;
  final ValueChanged<_ChartPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OxigenacaoHeader(
            onBack: onBack,
            trailing: IconButton(
              onPressed: onCalendar,
              icon: const Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFF2A9CAE),
              ),
              tooltip: 'Selecionar data',
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: resumo.totalRegistros == 0
                ? _PrimeiraMedicaoState(
                    idosoNome: idoso.nome,
                    onRegistrar: onRegistrar,
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      StaggeredEntry(
                        index: 0,
                        child: _MediaOxigenacaoCard(resumo: resumo),
                      ),
                      const SizedBox(height: 14),
                      StaggeredEntry(
                        index: 1,
                        child: _ChartCard(
                          period: period,
                          series: resumo.serie,
                          onChanged: onPeriodChanged,
                        ),
                      ),
                      const SizedBox(height: 14),
                      StaggeredEntry(
                        index: 2,
                        child: _AnalysisCard(resumo: resumo),
                      ),
                      const SizedBox(height: 16),
                      StaggeredEntry(
                        index: 3,
                        child: _NavRow(
                          icon: Icons.air_rounded,
                          iconColor: const Color(0xFF148A9C),
                          title: 'Registrar oxigenação',
                          onTap: onRegistrar,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StaggeredEntry(
                        index: 4,
                        child: _NavRow(
                          icon: Icons.history_rounded,
                          iconColor: const Color(0xFF25A1B2),
                          title: 'Ver histórico de oxigenação',
                          onTap: onViewHistorico,
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

class _OxigenacaoHeader extends StatelessWidget {
  const _OxigenacaoHeader({
    required this.onBack,
    this.title = 'Resumo da oxigenação',
    this.showWordmark = false,
    this.trailing,
  });

  final VoidCallback onBack;
  final String title;
  final bool showWordmark;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(12),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chevron_left_rounded,
                      color: Color(0xFF2A9CAE),
                      size: 30,
                    ),
                    SizedBox(width: 1),
                    Text(
                      'Voltar',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (showWordmark) ...[
          const SizedBox(height: 2),
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
        ],
        const SizedBox(height: 2),
        Text(
          title,
          textAlign: showWordmark ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 23,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(11),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
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
    );
  }
}

class _PrimeiraMedicaoState extends StatelessWidget {
  const _PrimeiraMedicaoState({
    required this.idosoNome,
    required this.onRegistrar,
  });

  final String idosoNome;
  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
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
                  Icons.air_rounded,
                  color: Color(0xFF148A9C),
                  size: 58,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Faça a primeira medição',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF073248),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ainda não há registros de oxigenação para $idosoNome. Comece registrando a medição atual.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF607178),
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: onRegistrar,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Registrar primeira oxigenação'),
                  style: _primaryButtonStyle(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedOxigenacaoValue extends StatelessWidget {
  const _AnimatedOxigenacaoValue({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value ?? 0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        final text = value == null ? '--' : animatedValue.round().toString();
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w400,
            ),
            children: [
              TextSpan(
                  text: text, style: const TextStyle(fontSize: 39, height: 1)),
              const TextSpan(text: '%SpO₂', style: TextStyle(fontSize: 25)),
            ],
          ),
        );
      },
    );
  }
}

class _MediaOxigenacaoCard extends StatelessWidget {
  const _MediaOxigenacaoCard({required this.resumo});

  final OxigenacaoResumo resumo;

  @override
  Widget build(BuildContext context) {
    final media = resumo.mediaSaturacaoDia ?? resumo.analise.mediaUltimos7Dias;
    final mediaPulso =
        resumo.mediaPulsoDia ?? resumo.analise.mediaPulsoUltimos7Dias;
    final ultima = resumo.ultima;
    final alertColor = _alertColor(resumo.alerta.cor);

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 11),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Média da saturação',
                  style: TextStyle(
                    color: Color(0xFF727272),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                _AnimatedOxigenacaoValue(value: media),
                const SizedBox(height: 4),
                Text(
                  mediaPulso == null
                      ? 'Sem pulso registrado'
                      : 'Pulso médio: ${mediaPulso.round()} bpm',
                  style: const TextStyle(
                    color: Color(0xFF808080),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: alertColor.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        resumo.alerta.cor == 'ok'
                            ? Icons.check_circle_rounded
                            : Icons.warning_rounded,
                        color: alertColor,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          resumo.alerta.mensagem,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: alertColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              const Icon(
                Icons.air_rounded,
                color: Color(0xFF148A9C),
                size: 44,
              ),
              if (ultima?.pulso != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${ultima!.pulso} bpm',
                  style: const TextStyle(
                    color: Color(0xFF148A9C),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.period,
    required this.series,
    required this.onChanged,
  });

  final _ChartPeriod period;
  final List<OxigenacaoSeriePonto> series;
  final ValueChanged<_ChartPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 13),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _PeriodSelector(period: period, onChanged: onChanged),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            key: ValueKey(series.length),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, child) {
              return SizedBox(
                height: 174,
                child: CustomPaint(
                  painter: _OxigenacaoChartPainter(series, animatedValue),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final point in series)
                          Expanded(
                            child: Text(
                              point.rotulo,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: point.valor == null
                                    ? const Color(0xFFADB3BB)
                                    : const Color(0xFF8E95A1),
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onChanged});

  final _ChartPeriod period;
  final ValueChanged<_ChartPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF9BD1DA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _PeriodItem(
            label: 'Dia',
            selected: period == _ChartPeriod.dia,
            onTap: () => onChanged(_ChartPeriod.dia),
          ),
          _PeriodItem(
            label: 'Semanal',
            selected: period == _ChartPeriod.semanal,
            onTap: () => onChanged(_ChartPeriod.semanal),
          ),
          _PeriodItem(
            label: 'Mês',
            selected: period == _ChartPeriod.mes,
            onTap: () => onChanged(_ChartPeriod.mes),
          ),
        ],
      ),
    );
  }
}

class _PeriodItem extends StatelessWidget {
  const _PeriodItem({
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
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _OxigenacaoChartPainter extends CustomPainter {
  const _OxigenacaoChartPainter(this.series, [this.progress = 1]);

  final List<OxigenacaoSeriePonto> series;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      for (var i = 0; i < series.length; i++)
        if (series[i].valor != null) MapEntry(i, series[i].valor!),
    ];

    final graphHeight = size.height - 24;
    final graphWidth = size.width;
    final bottom = graphHeight;
    final topPadding = 8.0;
    final minValue = values.isEmpty
        ? 90.0
        : values.map((entry) => entry.value).reduce(math.min) - 5;
    final maxValue = values.isEmpty
        ? 100.0
        : values.map((entry) => entry.value).reduce(math.max) + 3;
    final range = math.max(1.0, maxValue - minValue);

    Offset pointFor(MapEntry<int, double> entry) {
      final x = series.length <= 1
          ? graphWidth / 2
          : (entry.key / (series.length - 1)) * graphWidth;
      final y = topPadding +
          (1 - ((entry.value - minValue) / range)) * (graphHeight - 18);
      return Offset(x, bottom - (bottom - y) * progress);
    }

    final fillPaint = Paint()
      ..color = const Color(0xFFBEEBF1).withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = const Color(0xFF2FA3B5)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final areaPath = Path();
    final linePath = Path();

    if (values.length >= 2) {
      final first = pointFor(values.first);
      areaPath.moveTo(first.dx, bottom);
      areaPath.lineTo(first.dx, first.dy);
      linePath.moveTo(first.dx, first.dy);

      for (var i = 1; i < values.length; i++) {
        final previous = pointFor(values[i - 1]);
        final current = pointFor(values[i]);
        final controlX = (previous.dx + current.dx) / 2;
        linePath.cubicTo(
          controlX,
          previous.dy,
          controlX,
          current.dy,
          current.dx,
          current.dy,
        );
        areaPath.cubicTo(
          controlX,
          previous.dy,
          controlX,
          current.dy,
          current.dx,
          current.dy,
        );
      }

      final last = pointFor(values.last);
      areaPath.lineTo(last.dx, bottom);
      areaPath.close();
      canvas.drawPath(areaPath, fillPaint);
      canvas.drawPath(linePath, linePaint);

      final point = pointFor(values.length > 4 ? values[4] : values.last);
      canvas.drawCircle(point, 9, Paint()..color = Colors.white);
      canvas.drawCircle(point, 6, Paint()..color = const Color(0xFF087B8D));
    } else if (values.length == 1) {
      final point = pointFor(values.first);
      canvas.drawCircle(point, 10, Paint()..color = const Color(0xFFBEEBF1));
      canvas.drawCircle(point, 6, Paint()..color = const Color(0xFF087B8D));
    }
  }

  @override
  bool shouldRepaint(covariant _OxigenacaoChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.progress != progress;
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.resumo});

  final OxigenacaoResumo resumo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFC9E7ED),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A análise detalhada por IA ainda está em treinamento.',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 9, 11, 9),
          child: Row(
            children: [
              Container(
                width: 53,
                height: 53,
                decoration: const BoxDecoration(
                  color: Color(0xFF25A1B2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.air_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Análise da oxigenação',
                      style: TextStyle(
                        color: Color(0xFF2F4853),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      resumo.analise.texto,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2F4853),
                        fontSize: 10,
                        height: 1.08,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF073248),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoricoOxigenacaoView extends StatelessWidget {
  const _HistoricoOxigenacaoView({
    required this.entradas,
    required this.period,
    required this.onBack,
    required this.onPeriodChanged,
  });

  final List<OxigenacaoHistoricoEntrada> entradas;
  final _ChartPeriod period;
  final VoidCallback onBack;
  final ValueChanged<_ChartPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OxigenacaoHeader(
            onBack: onBack,
            title: 'Histórico da oxigenação',
            showWordmark: true,
          ),
          const SizedBox(height: 12),
          _PeriodSelector(period: period, onChanged: onPeriodChanged),
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
                      child: _HistoricoItemCard(entrada: entradas[index]),
                    ),
                  ),
          ),
        ],
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
            Icon(
              Icons.history_rounded,
              color: Color(0xFF2FA3B5),
              size: 48,
            ),
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
              'Altere o período ou registre uma nova medição.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF607178), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoricoItemCard extends StatelessWidget {
  const _HistoricoItemCard({required this.entrada});

  final OxigenacaoHistoricoEntrada entrada;

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor(entrada.badge.cor);
    final isEdicao = entrada.descricao == 'editou observação';
    final icon = isEdicao ? Icons.edit_rounded : Icons.air_rounded;
    final iconColor =
        isEdicao ? const Color(0xFF2FA3B5) : const Color(0xFF148A9C);

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
            child: Icon(icon, color: iconColor, size: 21),
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
                  entrada.saturacao != null
                      ? '${entrada.saturacao}% SpO₂${entrada.pulso != null ? ' · ${entrada.pulso} bpm' : ''}'
                      : 'Sem valor registrado',
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
                style: const TextStyle(
                  color: Color(0xFF9AA0A6),
                  fontSize: 10,
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
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

class _RegistrarOxigenacaoView extends StatelessWidget {
  const _RegistrarOxigenacaoView({
    required this.formKey,
    required this.saturacaoController,
    required this.pulsoController,
    required this.observacoesController,
    required this.selectedDate,
    required this.selectedTime,
    required this.observationHint,
    required this.saving,
    required this.onSelectDate,
    required this.onSelectTime,
    required this.onSave,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController saturacaoController;
  final TextEditingController pulsoController;
  final TextEditingController observacoesController;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final String observationHint;
  final bool saving;
  final VoidCallback onSelectDate;
  final VoidCallback onSelectTime;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Registrar oxigenação',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SaturacaoInput(controller: saturacaoController),
            const SizedBox(height: 12),
            _PickerCard(
              icon: Icons.calendar_month_rounded,
              title: 'Data',
              value: _formatDate(selectedDate),
              onTap: saving ? null : onSelectDate,
            ),
            const SizedBox(height: 12),
            _PickerCard(
              icon: Icons.access_time_rounded,
              title: 'Horário',
              value: selectedTime.format(context),
              onTap: saving ? null : onSelectTime,
            ),
            const SizedBox(height: 12),
            _PulsoInput(controller: pulsoController),
            const SizedBox(height: 12),
            _ObservationCard(
              controller: observacoesController,
              title: 'Observações',
              hintText: observationHint,
            ),
            const SizedBox(height: 22),
            _SaveCancelButtons(
              saving: saving,
              onSave: onSave,
              onCancel: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _SaturacaoInput extends StatelessWidget {
  const _SaturacaoInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _NumericValueCard(
      icon: Icons.air_rounded,
      iconColor: const Color(0xFF148A9C),
      label: 'Saturação',
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: const [],
      digitsOnly: true,
      hintText: '000',
      suffixText: 'SpO₂',
      validator: _validateSaturacao,
    );
  }
}

class _PulsoInput extends StatelessWidget {
  const _PulsoInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _NumericValueCard(
      icon: Icons.monitor_heart_rounded,
      iconColor: const Color(0xFFFF4657),
      label: 'Pulso (opcional)',
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: const [],
      digitsOnly: true,
      hintText: '00',
      suffixText: 'bpm',
      validator: _validatePulso,
    );
  }
}

class _NumericValueCard extends StatelessWidget {
  const _NumericValueCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.controller,
    required this.keyboardType,
    required this.inputFormatters,
    required this.hintText,
    required this.suffixText,
    required this.validator,
    this.digitsOnly = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final String hintText;
  final String suffixText;
  final FormFieldValidator<String> validator;
  final bool digitsOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF6F636B),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2FBFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF2FA3B5),
                      width: 1.4,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          keyboardType: keyboardType,
                          inputFormatters: digitsOnly
                              ? [FilteringTextInputFormatter.digitsOnly]
                              : inputFormatters,
                          validator: validator,
                          maxLines: 1,
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: const TextStyle(
                              color: Color(0xFFBFCBCE),
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            errorStyle: const TextStyle(
                              fontSize: 11,
                              height: 0.9,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        suffixText,
                        style: const TextStyle(
                          color: Color(0xFF087B8D),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              const SizedBox(width: 18),
              Icon(icon, color: const Color(0xFF087B8D), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF8D8D8D),
                        fontSize: 12,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObservationCard extends StatelessWidget {
  const _ObservationCard({
    required this.controller,
    required this.title,
    required this.hintText,
  });

  final TextEditingController controller;
  final String title;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 10),
      decoration: _cardDecoration(radius: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF087B8D),
                size: 21,
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            minLines: 3,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Color(0xFF8D8D8D)),
              contentPadding: const EdgeInsets.all(9),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: Color(0xFF2FA3B5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: Color(0xFF2FA3B5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveCancelButtons extends StatelessWidget {
  const _SaveCancelButtons({
    required this.saving,
    required this.onSave,
    required this.onCancel,
  });

  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                : const Text('Salvar'),
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
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Cancelar'),
          ),
        ),
      ],
    );
  }
}

class _FormScaffold extends StatelessWidget {
  const _FormScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 24, 10, 14),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF2FA3B5),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 12),
              child: child,
            ),
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
          const Icon(
            Icons.person_search_rounded,
            color: Color(0xFF2FA3B5),
            size: 54,
          ),
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
            'Selecione uma pessoa idosa para registrar a oxigenação.',
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
          _OxigenacaoHeader(onBack: onBack),
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

BoxDecoration _cardDecoration({double radius = 9}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.18),
        blurRadius: 5,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

ButtonStyle _primaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF3BA7B8),
    foregroundColor: Colors.white,
    padding: EdgeInsets.zero,
    minimumSize: const Size.fromHeight(48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
    ),
  );
}

Color _alertColor(String cor) {
  return switch (cor) {
    'ok' => const Color(0xFF28A745),
    'atencao' => const Color(0xFFE49A20),
    'critico' => const Color(0xFFD73A3A),
    'alerta' => const Color(0xFFD73A3A),
    _ => const Color(0xFF607178),
  };
}

Color _badgeColor(String cor) {
  return switch (cor) {
    'normal' => const Color(0xFF28A745),
    'alerta' => const Color(0xFFE49A20),
    'atualizado' => const Color(0xFF7C5CD6),
    _ => const Color(0xFF607178),
  };
}

String? _validateSaturacao(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  if (parsed == null) return 'Informe o valor.';
  if (parsed < 0 || parsed > 100) return 'Use um valor entre 0 e 100.';
  return null;
}

String? _validatePulso(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  final parsed = int.tryParse(trimmed);
  if (parsed == null) return 'Valor inválido.';
  if (parsed < 20 || parsed > 250) return 'Use um valor entre 20 e 250.';
  return null;
}

DateTime _combine(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
