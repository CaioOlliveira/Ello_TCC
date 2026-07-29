import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/staggered_entry.dart';

enum _TemperaturaMode { resumo, registrar, historico }

enum _ChartPeriod { dia, semanal, mes }

class TemperaturaPage extends ConsumerStatefulWidget {
  const TemperaturaPage({super.key});

  @override
  ConsumerState<TemperaturaPage> createState() => _TemperaturaPageState();
}

class _TemperaturaPageState extends ConsumerState<TemperaturaPage> {
  final _formKey = GlobalKey<FormState>();
  final _temperaturaController = TextEditingController();
  final _observacoesController = TextEditingController();

  Future<TemperaturaResumo>? _resumoFuture;
  String? _loadedIdosoId;
  _ChartPeriod? _loadedPeriod;

  Future<List<TemperaturaHistoricoEntrada>>? _historicoFuture;
  String? _historicoLoadedIdosoId;
  _ChartPeriod? _historicoLoadedPeriod;
  _ChartPeriod _historicoPeriod = _ChartPeriod.dia;

  _TemperaturaMode _mode = _TemperaturaMode.resumo;
  _ChartPeriod _period = _ChartPeriod.dia;
  DateTime _referenceDate = DateTime.now();
  DateTime _medicaoDate = DateTime.now();
  TimeOfDay _medicaoTime = TimeOfDay.now();
  bool _saving = false;

  @override
  void dispose() {
    _temperaturaController.dispose();
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
    _resumoFuture = ref.read(apiClientProvider).getResumoTemperatura(
          idosoId: idosoId,
          dataReferencia: _referenceDate,
          periodo: _period.apiValue,
        );
  }

  void _reloadResumo(String idosoId) {
    setState(() {
      _loadedIdosoId = idosoId;
      _loadedPeriod = _period;
      _resumoFuture = ref.read(apiClientProvider).getResumoTemperatura(
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
    _historicoFuture = ref.read(apiClientProvider).getHistoricoTemperatura(
          idosoId: idosoId,
          dataReferencia: _referenceDate,
          periodo: _historicoPeriod.apiValue,
        );
  }

  void _reloadHistorico(String idosoId) {
    setState(() {
      _historicoLoadedIdosoId = idosoId;
      _historicoLoadedPeriod = _historicoPeriod;
      _historicoFuture = ref.read(apiClientProvider).getHistoricoTemperatura(
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
      lastDate: DateTime.now().add(const Duration(days: 1)),
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
      lastDate: DateTime.now().add(const Duration(days: 1)),
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
      final temperatura = double.parse(
        _temperaturaController.text.trim().replaceAll(',', '.'),
      );
      final medidoEm = _combine(_medicaoDate, _medicaoTime);
      await ref.read(apiClientProvider).criarTemperatura(
            idosoId: idoso.id,
            temperatura: temperatura,
            medidoEm: medidoEm,
            observacoes: _observacoesController.text.trim(),
            registradoPorId: ref.read(authSessionProvider)?.id,
          );

      if (!mounted) return;
      _temperaturaController.clear();
      _observacoesController.clear();
      setState(() => _mode = _TemperaturaMode.resumo);
      _reloadResumo(idoso.id);
      _reloadHistorico(idoso.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temperatura registrada.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível registrar a temperatura.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);

    return Scaffold(
      backgroundColor: adaptive(context, const Color(0xFFF7F7F7), AppDarkColors.bg),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDarkMode(context) ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
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
          _TemperaturaMode.registrar => _RegistrarTemperaturaView(
              formKey: _formKey,
              temperaturaController: _temperaturaController,
              observacoesController: _observacoesController,
              selectedDate: _medicaoDate,
              selectedTime: _medicaoTime,
              saving: _saving,
              onSelectDate: _selectDate,
              onSelectTime: _selectTime,
              onSave: () => _salvar(idoso),
              onCancel: () => setState(() => _mode = _TemperaturaMode.resumo),
            ),
          _TemperaturaMode.historico =>
            FutureBuilder<List<TemperaturaHistoricoEntrada>>(
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
                        setState(() => _mode = _TemperaturaMode.resumo),
                    onRetry: () => _reloadHistorico(idoso.id),
                  );
                }

                return _HistoricoTemperaturaView(
                  entradas: snapshot.data ?? const [],
                  period: _historicoPeriod,
                  onBack: () => setState(() => _mode = _TemperaturaMode.resumo),
                  onPeriodChanged: (period) {
                    setState(() => _historicoPeriod = period);
                    _reloadHistorico(idoso.id);
                  },
                );
              },
            ),
          _TemperaturaMode.resumo => FutureBuilder<TemperaturaResumo>(
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
                    snapshot.data ?? TemperaturaResumo.fromJson(const {});

                return _ResumoTemperaturaView(
                  idoso: idoso,
                  resumo: resumo,
                  period: _period,
                  onBack: () => context.go('/monitoramento'),
                  onRegistrar: () {
                    setState(() => _mode = _TemperaturaMode.registrar);
                  },
                  onViewHistorico: () {
                    setState(() => _mode = _TemperaturaMode.historico);
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

class _ResumoTemperaturaView extends StatelessWidget {
  const _ResumoTemperaturaView({
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
  final TemperaturaResumo resumo;
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
          _TemperaturaHeader(
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
                        child: _MediaTemperaturaCard(resumo: resumo),
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
                          icon: Icons.thermostat_rounded,
                          iconColor: const Color(0xFF148A9C),
                          title: 'Registrar temperatura',
                          onTap: onRegistrar,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StaggeredEntry(
                        index: 4,
                        child: _NavRow(
                          icon: Icons.history_rounded,
                          iconColor: const Color(0xFF25A1B2),
                          title: 'Ver histórico de temperatura',
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

class _TemperaturaHeader extends StatelessWidget {
  const _TemperaturaHeader({
    required this.onBack,
    this.title = 'Resumo da temperatura',
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chevron_left_rounded,
                      color: Color(0xFF2A9CAE),
                      size: 30,
                    ),
                    const SizedBox(width: 1),
                    Text(
                      'Voltar',
                      style: TextStyle(
                        color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
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
          style: TextStyle(
            color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
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
      color: adaptive(context, Colors.white, AppDarkColors.surface),
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
                  style: TextStyle(
                    color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: adaptive(context, const Color(0xFF9AA0A6), AppDarkColors.textMuted),
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
                decoration: BoxDecoration(
                  color: adaptive(context, const Color(0xFFD8F1F4), AppDarkColors.tintedInfo),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.thermostat_rounded,
                  color: Color(0xFF148A9C),
                  size: 58,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Faça a primeira medição',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ainda não há registros de temperatura para $idosoNome. Comece registrando a medição atual.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF607178), AppDarkColors.textSecondary),
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
                  label: const Text('Registrar primeira temperatura'),
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

class _AnimatedTemperaturaValue extends StatelessWidget {
  const _AnimatedTemperaturaValue({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value ?? 0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        final text = value == null ? '--' : _formatTemperatura(animatedValue);
        return RichText(
          text: TextSpan(
            style: TextStyle(
              color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
              fontWeight: FontWeight.w400,
            ),
            children: [
              TextSpan(
                  text: text, style: const TextStyle(fontSize: 39, height: 1)),
              const TextSpan(text: '°C', style: TextStyle(fontSize: 25)),
            ],
          ),
        );
      },
    );
  }
}

class _MediaTemperaturaCard extends StatelessWidget {
  const _MediaTemperaturaCard({required this.resumo});

  final TemperaturaResumo resumo;

  @override
  Widget build(BuildContext context) {
    final media =
        resumo.mediaTemperaturaDia ?? resumo.analise.mediaUltimos7Dias;
    final ultima = resumo.ultima;
    final alertColor = _alertColor(resumo.alerta.cor);

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 11),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Média da temperatura',
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF727272), AppDarkColors.textSecondary),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                _AnimatedTemperaturaValue(value: media),
                const SizedBox(height: 8),
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
                          maxLines: 2,
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
                Icons.thermostat_rounded,
                color: Color(0xFF148A9C),
                size: 44,
              ),
              if (ultima != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatTime(ultima.medidoEm),
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
  final List<TemperaturaSeriePonto> series;
  final ValueChanged<_ChartPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 13),
      decoration: _cardDecoration(context),
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
                  painter: _TemperaturaChartPainter(series, animatedValue),
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
                                    ? adaptive(context, const Color(0xFFADB3BB), AppDarkColors.textMuted)
                                    : adaptive(context, const Color(0xFF8E95A1), AppDarkColors.textSecondary),
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

class _TemperaturaChartPainter extends CustomPainter {
  const _TemperaturaChartPainter(this.series, [this.progress = 1]);

  final List<TemperaturaSeriePonto> series;
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
        ? 35.5
        : values.map((entry) => entry.value).reduce(math.min) - 1;
    final maxValue = values.isEmpty
        ? 38.5
        : values.map((entry) => entry.value).reduce(math.max) + 1;
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
  bool shouldRepaint(covariant _TemperaturaChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.progress != progress;
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.resumo});

  final TemperaturaResumo resumo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: adaptive(context, const Color(0xFFC9E7ED), AppDarkColors.tintedInfo),
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
                  Icons.thermostat_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Análise de temperatura',
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF2F4853), AppDarkColors.textPrimary),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      resumo.analise.texto,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF2F4853), AppDarkColors.textPrimary),
                        fontSize: 10,
                        height: 1.08,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoricoTemperaturaView extends StatelessWidget {
  const _HistoricoTemperaturaView({
    required this.entradas,
    required this.period,
    required this.onBack,
    required this.onPeriodChanged,
  });

  final List<TemperaturaHistoricoEntrada> entradas;
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
          _TemperaturaHeader(
            onBack: onBack,
            title: 'Histórico da temperatura',
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history_rounded,
              color: Color(0xFF2FA3B5),
              size: 48,
            ),
            const SizedBox(height: 10),
            Text(
              'Nenhum registro neste período',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Altere o período ou registre uma nova medição.',
              textAlign: TextAlign.center,
              style: TextStyle(color: adaptive(context, const Color(0xFF607178), AppDarkColors.textSecondary), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoricoItemCard extends StatelessWidget {
  const _HistoricoItemCard({required this.entrada});

  final TemperaturaHistoricoEntrada entrada;

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor(entrada.badge.cor);
    final isEdicao = entrada.descricao == 'editou observação';
    final icon = isEdicao ? Icons.edit_rounded : Icons.thermostat_rounded;
    final iconColor =
        isEdicao ? const Color(0xFF2FA3B5) : const Color(0xFF148A9C);

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
                  style: TextStyle(
                    color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entrada.temperatura != null
                      ? '${_formatTemperatura(entrada.temperatura!)}°C'
                      : 'Sem valor registrado',
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF808080), AppDarkColors.textMuted),
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
                  color: adaptive(context, const Color(0xFF9AA0A6), AppDarkColors.textMuted),
                  fontSize: 10,
                ),
              ),
              Text(
                _formatTime(entrada.dataHora),
                style: TextStyle(
                  color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
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

class _RegistrarTemperaturaView extends StatelessWidget {
  const _RegistrarTemperaturaView({
    required this.formKey,
    required this.temperaturaController,
    required this.observacoesController,
    required this.selectedDate,
    required this.selectedTime,
    required this.saving,
    required this.onSelectDate,
    required this.onSelectTime,
    required this.onSave,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController temperaturaController;
  final TextEditingController observacoesController;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final bool saving;
  final VoidCallback onSelectDate;
  final VoidCallback onSelectTime;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Registrar temperatura',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TemperaturaInput(controller: temperaturaController),
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
            _ObservationCard(
              controller: observacoesController,
              title: 'Observações',
              hintText: 'Como o idoso está se sentindo?',
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

class _TemperaturaInput extends StatelessWidget {
  const _TemperaturaInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _NumericValueCard(
      icon: Icons.thermostat_rounded,
      iconColor: const Color(0xFF148A9C),
      label: 'Temperatura',
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      hintText: '36,0',
      suffixText: '°C',
      validator: _validateTemperatura,
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
    required this.hintText,
    required this.suffixText,
    required this.validator,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String hintText;
  final String suffixText;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _cardDecoration(context),
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
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF6F636B), AppDarkColors.textSecondary),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: adaptive(context, const Color(0xFFF2FBFC), AppDarkColors.tintedInfo),
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
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9,.]'),
                            ),
                          ],
                          validator: validator,
                          maxLines: 1,
                          textAlignVertical: TextAlignVertical.center,
                          style: TextStyle(
                            color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: TextStyle(
                              color: adaptive(context, const Color(0xFFBFCBCE), AppDarkColors.textMuted),
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
      color: adaptive(context, Colors.white, AppDarkColors.surface),
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
                      style: TextStyle(
                        color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF8D8D8D), AppDarkColors.textMuted),
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
      decoration: _cardDecoration(context, radius: 9),
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
                style: TextStyle(
                  color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
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
              hintStyle: TextStyle(color: adaptive(context, const Color(0xFF8D8D8D), AppDarkColors.textMuted)),
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
          Text(
            'Escolha uma ficha',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Selecione um idoso para registrar a temperatura.',
            textAlign: TextAlign.center,
            style: TextStyle(color: adaptive(context, const Color(0xFF607178), AppDarkColors.textSecondary), fontSize: 13),
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
          _TemperaturaHeader(onBack: onBack),
          const Spacer(),
          const Icon(Icons.cloud_off_rounded,
              color: Color(0xFF2FA3B5), size: 54),
          const SizedBox(height: 10),
          Text(
            'Não foi possível carregar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confira a conexão com a API e tente novamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: adaptive(context, const Color(0xFF607178), AppDarkColors.textSecondary), fontSize: 13),
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

BoxDecoration _cardDecoration(BuildContext context, {double radius = 9}) {
  return BoxDecoration(
    color: adaptive(context, Colors.white, AppDarkColors.surface),
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

String? _validateTemperatura(String? value) {
  final parsed = double.tryParse((value?.trim() ?? '').replaceAll(',', '.'));
  if (parsed == null) return 'Informe o valor.';
  if (parsed < 25 || parsed > 45) return 'Use um valor entre 25 e 45°C.';
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

String _formatTemperatura(double value) {
  return value.toStringAsFixed(1).replaceAll('.', ',');
}
