import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/staggered_entry.dart';

enum _PressaoMode { resumo, registrar, historico }

enum _ChartPeriod { dia, semanal, mes }

class PressaoPage extends ConsumerStatefulWidget {
  const PressaoPage({super.key});

  @override
  ConsumerState<PressaoPage> createState() => _PressaoPageState();
}

class _PressaoPageState extends ConsumerState<PressaoPage> {
  final _formKey = GlobalKey<FormState>();
  final _sistolicaController = TextEditingController();
  final _diastolicaController = TextEditingController();
  final _batimentosController = TextEditingController();
  final _observacoesController = TextEditingController();

  Future<PressaoResumo>? _resumoFuture;
  String? _loadedIdosoId;
  _ChartPeriod? _loadedPeriod;

  Future<List<PressaoHistoricoEntrada>>? _historicoFuture;
  String? _historicoLoadedIdosoId;
  _ChartPeriod? _historicoLoadedPeriod;
  _ChartPeriod _historicoPeriod = _ChartPeriod.dia;

  _PressaoMode _mode = _PressaoMode.resumo;
  _ChartPeriod _period = _ChartPeriod.semanal;
  DateTime _referenceDate = DateTime.now();
  DateTime _medicaoDate = DateTime.now();
  TimeOfDay _medicaoTime = TimeOfDay.now();
  bool _saving = false;

  @override
  void dispose() {
    _sistolicaController.dispose();
    _diastolicaController.dispose();
    _batimentosController.dispose();
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
    _resumoFuture = ref.read(apiClientProvider).getResumoPressao(
          idosoId: idosoId,
          dataReferencia: _referenceDate,
          periodo: _period.summaryApiValue,
        );
  }

  void _reloadResumo(String idosoId) {
    setState(() {
      _loadedIdosoId = idosoId;
      _loadedPeriod = _period;
      _resumoFuture = ref.read(apiClientProvider).getResumoPressao(
            idosoId: idosoId,
            dataReferencia: _referenceDate,
            periodo: _period.summaryApiValue,
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
    _historicoFuture = ref.read(apiClientProvider).getHistoricoPressao(
          idosoId: idosoId,
          dataReferencia: _referenceDate,
          periodo: _historicoPeriod.apiValue,
        );
  }

  void _reloadHistorico(String idosoId) {
    setState(() {
      _historicoLoadedIdosoId = idosoId;
      _historicoLoadedPeriod = _historicoPeriod;
      _historicoFuture = ref.read(apiClientProvider).getHistoricoPressao(
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

  void _showNoEditPermission() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Você não tem permissão para editar este registro.'),
      ),
    );
  }

  Future<void> _salvar(IdosoResumo idoso) async {
    FocusScope.of(context).unfocus();
    if (!idoso.podeEditarModulo('Pressao')) {
      _showNoEditPermission();
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final sistolica = int.parse(_sistolicaController.text.trim());
      final diastolica = int.parse(_diastolicaController.text.trim());
      final batimentosTexto = _batimentosController.text.trim();
      final medidoEm = _combine(_medicaoDate, _medicaoTime);
      await ref.read(apiClientProvider).criarPressao(
            idosoId: idoso.id,
            sistolica: sistolica,
            diastolica: diastolica,
            medidoEm: medidoEm,
            batimentos:
                batimentosTexto.isEmpty ? null : int.parse(batimentosTexto),
            observacoes: _observacoesController.text.trim(),
            registradoPorId: ref.read(authSessionProvider)?.id,
          );

      if (!mounted) return;
      _sistolicaController.clear();
      _diastolicaController.clear();
      _batimentosController.clear();
      _observacoesController.clear();
      setState(() => _mode = _PressaoMode.resumo);
      _reloadResumo(idoso.id);
      _reloadHistorico(idoso.id);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível registrar pressão.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);

    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFF7F7F7), AppDarkColors.bg),
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
          _PressaoMode.registrar => _RegistrarPressaoView(
              formKey: _formKey,
              sistolicaController: _sistolicaController,
              diastolicaController: _diastolicaController,
              batimentosController: _batimentosController,
              observacoesController: _observacoesController,
              selectedDate: _medicaoDate,
              selectedTime: _medicaoTime,
              observationHint: feelingHint,
              saving: _saving,
              onSelectDate: _selectDate,
              onSelectTime: _selectTime,
              onSave: () => _salvar(idoso),
              onCancel: () => setState(() => _mode = _PressaoMode.resumo),
            ),
          _PressaoMode.historico =>
            FutureBuilder<List<PressaoHistoricoEntrada>>(
              future: _historicoFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2FA8B8)),
                  );
                }

                if (snapshot.hasError) {
                  return _ErrorState(
                    onBack: () => setState(() => _mode = _PressaoMode.resumo),
                    onRetry: () => _reloadHistorico(idoso.id),
                  );
                }

                return _HistoricoPressaoView(
                  entradas: snapshot.data ?? const [],
                  period: _historicoPeriod,
                  onBack: () => setState(() => _mode = _PressaoMode.resumo),
                  onPeriodChanged: (period) {
                    setState(() => _historicoPeriod = period);
                    _reloadHistorico(idoso.id);
                  },
                );
              },
            ),
          _PressaoMode.resumo => FutureBuilder<PressaoResumo>(
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
                    snapshot.data ?? PressaoResumo.fromJson(const {});

                return _ResumoPressaoView(
                  idoso: idoso,
                  resumo: resumo,
                  period: _period,
                  onBack: () => context.go('/monitoramento'),
                  onRegistrar: () {
                    if (!idoso.podeEditarModulo('Pressao')) {
                      _showNoEditPermission();
                      return;
                    }
                    setState(() => _mode = _PressaoMode.registrar);
                  },
                  onViewHistorico: () {
                    setState(() => _mode = _PressaoMode.historico);
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

  String get summaryApiValue {
    return switch (this) {
      _ChartPeriod.mes => 'mes',
      _ChartPeriod.dia || _ChartPeriod.semanal => 'dia',
    };
  }
}

class _ResumoPressaoView extends StatelessWidget {
  const _ResumoPressaoView({
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
  final PressaoResumo resumo;
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
          _PressaoHeader(
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
                    hasPreviousRecords: resumo.totalRegistrosGeral > 0,
                    onRegistrar: onRegistrar,
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      StaggeredEntry(
                        index: 0,
                        child: _MediaPressaoCard(resumo: resumo),
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
                          icon: Icons.favorite_rounded,
                          iconColor: const Color(0xFFFF4657),
                          title: 'Registrar pressão',
                          onTap: onRegistrar,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StaggeredEntry(
                        index: 4,
                        child: _NavRow(
                          icon: Icons.history_rounded,
                          iconColor: const Color(0xFF25A1B2),
                          title: 'Ver histórico de pressão',
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

class _PressaoHeader extends StatelessWidget {
  const _PressaoHeader({
    required this.onBack,
    this.title = 'Resumo da pressão',
    this.showWordmark = false,
    this.trailing,
  });

  final VoidCallback onBack;
  final String title;
  final bool showWordmark;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(
      title: title,
      onBack: onBack,
      trailing: trailing,
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
                    color: adaptive(
                        context, Colors.black, AppDarkColors.textPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: adaptive(
                    context, const Color(0xFF9AA0A6), AppDarkColors.textMuted),
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
    required this.hasPreviousRecords,
    required this.onRegistrar,
  });

  final String idosoNome;
  final bool hasPreviousRecords;
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
                  color: adaptive(context, const Color(0xFFD8F1F4),
                      AppDarkColors.tintedInfo),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFFF4657),
                  size: 58,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                hasPreviousRecords
                    ? 'Faça a medição do dia'
                    : 'Faça a primeira medição',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF073248),
                      AppDarkColors.textPrimary),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasPreviousRecords
                    ? 'Ainda não há registros de pressão hoje para $idosoNome. Registre a medição do dia e mantenha o acompanhamento atualizado.'
                    : 'Ainda não há registros de pressão para $idosoNome. Comece registrando a medição atual.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF607178),
                      AppDarkColors.textSecondary),
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
                  label: Text(
                    hasPreviousRecords
                        ? 'Registrar pressão'
                        : 'Registrar primeira pressão',
                  ),
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

class _AnimatedPressaoValue extends StatelessWidget {
  const _AnimatedPressaoValue(
      {required this.sistolica, required this.diastolica});

  final double? sistolica;
  final double? diastolica;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: sistolica ?? 0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedSistolica, child) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: diastolica ?? 0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, animatedDiastolica, child) {
            final text = sistolica == null || diastolica == null
                ? '--/--'
                : '${animatedSistolica.round()}/${animatedDiastolica.round()}';
            return RichText(
              text: TextSpan(
                style: TextStyle(
                  color: adaptive(
                      context, Colors.black, AppDarkColors.textPrimary),
                  fontWeight: FontWeight.w400,
                ),
                children: [
                  TextSpan(
                      text: text,
                      style: const TextStyle(fontSize: 39, height: 1)),
                  const TextSpan(text: 'mmHg', style: TextStyle(fontSize: 25)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MediaPressaoCard extends StatelessWidget {
  const _MediaPressaoCard({required this.resumo});

  final PressaoResumo resumo;

  @override
  Widget build(BuildContext context) {
    final mediaSistolica =
        resumo.mediaSistolicaDia ?? resumo.analise.mediaUltimos7Dias;
    final mediaDiastolica =
        resumo.mediaDiastolicaDia ?? resumo.analise.mediaDiastolicaUltimos7Dias;
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
                  'Média da pressão',
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF727272),
                        AppDarkColors.textSecondary),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                _AnimatedPressaoValue(
                  sistolica: mediaSistolica,
                  diastolica: mediaDiastolica,
                ),
                const SizedBox(height: 4),
                Text(
                  ultima == null
                      ? 'Sem medição'
                      : 'Última medição: ${_formatTime(ultima.medidoEm)} · ${ultima.sistolica}/${ultima.diastolica} mmHg',
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF808080),
                        AppDarkColors.textMuted),
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
          const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFFF4657),
            size: 50,
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
  final List<PressaoSeriePonto> series;
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
                  painter: _PressaoChartPainter(series, animatedValue),
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
                                    ? adaptive(context, const Color(0xFFADB3BB),
                                        AppDarkColors.textMuted)
                                    : adaptive(context, const Color(0xFF8E95A1),
                                        AppDarkColors.textSecondary),
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
  const _PeriodSelector({
    required this.period,
    required this.onChanged,
    this.showDay = false,
  });

  final _ChartPeriod period;
  final ValueChanged<_ChartPeriod> onChanged;
  final bool showDay;

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
          if (showDay)
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

class _PressaoChartPainter extends CustomPainter {
  const _PressaoChartPainter(this.series, [this.progress = 1]);

  final List<PressaoSeriePonto> series;
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
        : values.map((entry) => entry.value).reduce(math.min) - 20;
    final maxValue = values.isEmpty
        ? 130.0
        : values.map((entry) => entry.value).reduce(math.max) + 20;
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
  bool shouldRepaint(covariant _PressaoChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.progress != progress;
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.resumo});

  final PressaoResumo resumo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          adaptive(context, const Color(0xFFC9E7ED), AppDarkColors.tintedInfo),
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
                  Icons.monitor_heart_outlined,
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
                      'Análise da pressão',
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF2F4853),
                            AppDarkColors.textPrimary),
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
                        color: adaptive(context, const Color(0xFF2F4853),
                            AppDarkColors.textPrimary),
                        fontSize: 10,
                        height: 1.08,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: adaptive(context, const Color(0xFF073248),
                    AppDarkColors.textPrimary),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoricoPressaoView extends StatelessWidget {
  const _HistoricoPressaoView({
    required this.entradas,
    required this.period,
    required this.onBack,
    required this.onPeriodChanged,
  });

  final List<PressaoHistoricoEntrada> entradas;
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
          _PressaoHeader(
            onBack: onBack,
            title: 'Histórico da pressão',
            showWordmark: true,
          ),
          const SizedBox(height: 12),
          _PeriodSelector(
            period: period,
            onChanged: onPeriodChanged,
            showDay: true,
          ),
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
                color: adaptive(context, const Color(0xFF073248),
                    AppDarkColors.textPrimary),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Altere o período ou registre uma nova medição.',
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

class _HistoricoItemCard extends StatelessWidget {
  const _HistoricoItemCard({required this.entrada});

  final PressaoHistoricoEntrada entrada;

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor(entrada.badge.cor);
    final isEdicao = entrada.descricao == 'editou observação';
    final icon = isEdicao ? Icons.edit_rounded : Icons.favorite_rounded;
    final iconColor =
        isEdicao ? const Color(0xFF2FA3B5) : const Color(0xFFFF4657);

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
                    color: adaptive(
                        context, Colors.black, AppDarkColors.textPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entrada.sistolica != null && entrada.diastolica != null
                      ? '${entrada.sistolica}/${entrada.diastolica} mmHg'
                      : 'Sem valor registrado',
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
                      AppDarkColors.textMuted),
                  fontSize: 10,
                ),
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

class _RegistrarPressaoView extends StatelessWidget {
  const _RegistrarPressaoView({
    required this.formKey,
    required this.sistolicaController,
    required this.diastolicaController,
    required this.batimentosController,
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
  final TextEditingController sistolicaController;
  final TextEditingController diastolicaController;
  final TextEditingController batimentosController;
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
      title: 'Registrar pressão',
      onBack: onCancel,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PressaoValueInput(
              sistolicaController: sistolicaController,
              diastolicaController: diastolicaController,
            ),
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
            _BatimentosInput(controller: batimentosController),
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

class _PressaoValueInput extends StatelessWidget {
  const _PressaoValueInput({
    required this.sistolicaController,
    required this.diastolicaController,
  });

  final TextEditingController sistolicaController;
  final TextEditingController diastolicaController;

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
              color: const Color(0xFFFF4657).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFFF4657),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _PressaoValueField(
                    label: 'Sistólica',
                    controller: sistolicaController,
                    validator: _validateSistolica,
                  ),
                ),
                Container(
                  width: 1,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: adaptive(
                      context, const Color(0xFFE1E6E8), AppDarkColors.border),
                ),
                Expanded(
                  child: _PressaoValueField(
                    label: 'Diastólica',
                    controller: diastolicaController,
                    validator: _validateDiastolica,
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

class _PressaoValueField extends StatelessWidget {
  const _PressaoValueField({
    required this.label,
    required this.controller,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: adaptive(
                context, const Color(0xFF6F636B), AppDarkColors.textSecondary),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 46,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: validator,
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(
                  color: adaptive(
                      context, Colors.black, AppDarkColors.textPrimary),
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                decoration: InputDecoration(
                  hintText: '000',
                  hintStyle: TextStyle(
                    color: adaptive(context, const Color(0xFFBFCBCE),
                        AppDarkColors.textMuted),
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  errorStyle: const TextStyle(fontSize: 10, height: 0.7),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'mmHg',
                style: TextStyle(
                  color: Color(0xFF087B8D),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BatimentosInput extends StatelessWidget {
  const _BatimentosInput({required this.controller});

  final TextEditingController controller;

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
              color: const Color(0xFF2FA3B5).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.monitor_heart_rounded,
              color: Color(0xFF2FA3B5),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batimentos (opcional)',
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF6F636B),
                        AppDarkColors.textSecondary),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: adaptive(context, const Color(0xFFF2FBFC),
                        AppDarkColors.tintedInfo),
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
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: _validateBatimentos,
                          maxLines: 1,
                          textAlignVertical: TextAlignVertical.center,
                          style: TextStyle(
                            color: adaptive(context, Colors.black,
                                AppDarkColors.textPrimary),
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                          decoration: InputDecoration(
                            hintText: '00',
                            hintStyle: TextStyle(
                              color: adaptive(context, const Color(0xFFBFCBCE),
                                  AppDarkColors.textMuted),
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                            errorStyle:
                                const TextStyle(fontSize: 11, height: 0.9),
                          ),
                        ),
                      ),
                      const Text(
                        'bpm',
                        style: TextStyle(
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
                        color: adaptive(
                            context, Colors.black, AppDarkColors.textPrimary),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF8D8D8D),
                            AppDarkColors.textMuted),
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
                  color: adaptive(
                      context, Colors.black, AppDarkColors.textPrimary),
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
              hintStyle: TextStyle(
                  color: adaptive(context, const Color(0xFF8D8D8D),
                      AppDarkColors.textMuted)),
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
  const _FormScaffold({
    required this.title,
    required this.onBack,
    required this.child,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 24, 10, 14),
      child: Column(
        children: [
          AppPageHeader(title: title, onBack: onBack),
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
              color: adaptive(
                  context, const Color(0xFF073248), AppDarkColors.textPrimary),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Selecione uma pessoa idosa para registrar a pressão arterial.',
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
          _PressaoHeader(onBack: onBack),
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

String? _validateSistolica(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  if (parsed == null) return 'Obrigatório';
  if (parsed < 40 || parsed > 300) return 'Use 40-300';
  return null;
}

String? _validateDiastolica(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  if (parsed == null) return 'Obrigatório';
  if (parsed < 20 || parsed > 200) return 'Use 20-200';
  return null;
}

String? _validateBatimentos(String? value) {
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
