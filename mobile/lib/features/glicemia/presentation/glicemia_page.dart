import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/navigation/module_navigation.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/staggered_entry.dart';

enum _GlicemiaMode { resumo, registrarGlicemia, registrarInsulina, historico }

enum _ChartPeriod { dia, semanal, mes }

const _kInsulinas = [
  'Insulina Glargina',
  'Insulina Regular',
  'Insulina NPH',
  'Insulina Lispro',
  'Insulina Asparte',
  'Insulina Detemir',
  'Insulina Degludeca',
  'Outra',
];

const _kLocaisAplicacao = ['Abdômen', 'Braço', 'Coxa', 'Glúteo', 'Outro'];

class GlicemiaPage extends ConsumerStatefulWidget {
  const GlicemiaPage({super.key});

  @override
  ConsumerState<GlicemiaPage> createState() => _GlicemiaPageState();
}

class _GlicemiaPageState extends ConsumerState<GlicemiaPage> {
  final _glicemiaFormKey = GlobalKey<FormState>();
  final _insulinaFormKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _doseController = TextEditingController();
  final _observacoesInsulinaController = TextEditingController();

  Future<GlicemiaResumo>? _resumoFuture;
  String? _loadedIdosoId;
  _ChartPeriod? _loadedPeriod;

  Future<List<GlicemiaHistoricoEntrada>>? _historicoFuture;
  String? _historicoLoadedIdosoId;
  _ChartPeriod? _historicoLoadedPeriod;
  _ChartPeriod _historicoPeriod = _ChartPeriod.dia;

  _GlicemiaMode _mode = _GlicemiaMode.resumo;
  _ChartPeriod _period = _ChartPeriod.semanal;
  DateTime _referenceDate = DateTime.now();
  DateTime _glicemiaDate = DateTime.now();
  TimeOfDay _glicemiaTime = TimeOfDay.now();
  DateTime _insulinaDate = DateTime.now();
  TimeOfDay _insulinaTime = TimeOfDay.now();
  String _contexto = 'Jejum';
  String _nomeInsulina = _kInsulinas.first;
  String _tipoInsulina = 'Basal';
  String _localAplicacao = _kLocaisAplicacao.first;
  bool _saving = false;

  @override
  void dispose() {
    _valorController.dispose();
    _observacoesController.dispose();
    _doseController.dispose();
    _observacoesInsulinaController.dispose();
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
    _resumoFuture = ref.read(apiClientProvider).getResumoGlicemia(
          idosoId: idosoId,
          dataReferencia: _referenceDate,
          periodo: _period.summaryApiValue,
        );
  }

  void _reloadResumo(String idosoId) {
    setState(() {
      _loadedIdosoId = idosoId;
      _loadedPeriod = _period;
      _resumoFuture = ref.read(apiClientProvider).getResumoGlicemia(
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
    _historicoFuture = ref.read(apiClientProvider).getHistoricoGlicemia(
          idosoId: idosoId,
          dataReferencia: _referenceDate,
          periodo: _historicoPeriod.apiValue,
        );
  }

  void _reloadHistorico(String idosoId) {
    setState(() {
      _historicoLoadedIdosoId = idosoId;
      _historicoLoadedPeriod = _historicoPeriod;
      _historicoFuture = ref.read(apiClientProvider).getHistoricoGlicemia(
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

  Future<void> _selectGlicemiaDate() async {
    final selected = await _pickDate(_glicemiaDate);
    if (selected != null) setState(() => _glicemiaDate = selected);
  }

  Future<void> _selectGlicemiaTime() async {
    final selected = await _pickTime(_glicemiaTime);
    if (selected != null) setState(() => _glicemiaTime = selected);
  }

  Future<void> _selectInsulinaDate() async {
    final selected = await _pickDate(_insulinaDate);
    if (selected != null) setState(() => _insulinaDate = selected);
  }

  Future<void> _selectInsulinaTime() async {
    final selected = await _pickTime(_insulinaTime);
    if (selected != null) setState(() => _insulinaTime = selected);
  }

  Future<DateTime?> _pickDate(DateTime initialDate) {
    return showDatePicker(
      context: _pickerContext,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: initialDate,
    );
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initialTime) {
    return showTimePicker(
      context: _pickerContext,
      initialTime: initialTime,
    );
  }

  BuildContext get _pickerContext {
    return Navigator.of(context, rootNavigator: true).context;
  }

  Future<bool> _handleSystemBack() async {
    if (_mode != _GlicemiaMode.resumo) {
      setState(() => _mode = _GlicemiaMode.resumo);
      return false;
    }
    return true;
  }

  void _showNoEditPermission() {
    showEditPermissionDenied(context);
  }

  Future<void> _saveGlicemia(IdosoResumo idoso) async {
    FocusScope.of(context).unfocus();
    if (!idoso.podeEditarModulo('Glicemia')) {
      _showNoEditPermission();
      return;
    }
    if (!(_glicemiaFormKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final valor = int.parse(_valorController.text.trim());
      final medidoEm = _combine(_glicemiaDate, _glicemiaTime);
      await ref.read(apiClientProvider).criarGlicemia(
            idosoId: idoso.id,
            valor: valor,
            contexto: _contexto,
            medidoEm: medidoEm,
            observacoes: _observacoesController.text.trim(),
            registradoPorId: ref.read(authSessionProvider)?.id,
          );

      if (!mounted) return;
      _valorController.clear();
      _observacoesController.clear();
      setState(() => _mode = _GlicemiaMode.resumo);
      _reloadResumo(idoso.id);
      _reloadHistorico(idoso.id);
    } on ApiException {
      if (!mounted) return;
      _ignoreBottomMessage();
    } catch (_) {
      if (!mounted) return;
      _ignoreBottomMessage();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveInsulina(IdosoResumo idoso) async {
    FocusScope.of(context).unfocus();
    if (!idoso.podeEditarModulo('Glicemia')) {
      _showNoEditPermission();
      return;
    }
    if (!(_insulinaFormKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final dose = double.parse(
        _doseController.text.trim().replaceAll(',', '.'),
      );
      final aplicadoEm = _combine(_insulinaDate, _insulinaTime);
      await ref.read(apiClientProvider).criarRegistroInsulina(
            idosoId: idoso.id,
            nomeInsulina: _nomeInsulina,
            tipoInsulina: _tipoInsulina,
            doseUnidades: dose,
            aplicadoEm: aplicadoEm,
            localAplicacao: _localAplicacao,
            observacoes: _observacoesInsulinaController.text.trim(),
            registradoPorId: ref.read(authSessionProvider)?.id,
          );

      if (!mounted) return;
      _doseController.clear();
      _observacoesInsulinaController.clear();
      setState(() => _mode = _GlicemiaMode.resumo);
      _reloadResumo(idoso.id);
    } on ApiException {
      if (!mounted) return;
      _ignoreBottomMessage();
    } catch (_) {
      if (!mounted) return;
      _ignoreBottomMessage();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);

    return PopScope(
      canPop: _mode == _GlicemiaMode.resumo,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack();
      },
      child: Scaffold(
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
          _GlicemiaMode.registrarGlicemia => _RegistrarGlicemiaView(
              formKey: _glicemiaFormKey,
              valorController: _valorController,
              observacoesController: _observacoesController,
              selectedDate: _glicemiaDate,
              selectedTime: _glicemiaTime,
              contexto: _contexto,
              observationHint: feelingHint,
              saving: _saving,
              onContextoChanged: (value) {
                if (value != null) setState(() => _contexto = value);
              },
              onSelectDate: _selectGlicemiaDate,
              onSelectTime: _selectGlicemiaTime,
              onSave: () => _saveGlicemia(idoso),
              onCancel: () => setState(() => _mode = _GlicemiaMode.resumo),
            ),
          _GlicemiaMode.registrarInsulina => _RegistrarInsulinaView(
              formKey: _insulinaFormKey,
              doseController: _doseController,
              observacoesController: _observacoesInsulinaController,
              selectedDate: _insulinaDate,
              selectedTime: _insulinaTime,
              nomeInsulina: _nomeInsulina,
              tipoInsulina: _tipoInsulina,
              localAplicacao: _localAplicacao,
              observationHint: feelingHint,
              saving: _saving,
              onNomeChanged: (value) {
                if (value != null) setState(() => _nomeInsulina = value);
              },
              onTipoChanged: (value) => setState(() => _tipoInsulina = value),
              onLocalChanged: (value) {
                if (value != null) setState(() => _localAplicacao = value);
              },
              onSelectDate: _selectInsulinaDate,
              onSelectTime: _selectInsulinaTime,
              onSave: () => _saveInsulina(idoso),
              onCancel: () => setState(() => _mode = _GlicemiaMode.resumo),
            ),
          _GlicemiaMode.historico =>
            FutureBuilder<List<GlicemiaHistoricoEntrada>>(
              future: _historicoFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2FA8B8)),
                  );
                }

                if (snapshot.hasError) {
                  return _ErrorState(
                    onBack: () => setState(() => _mode = _GlicemiaMode.resumo),
                    onRetry: () => _reloadHistorico(idoso.id),
                  );
                }

                return _HistoricoGlicemiaView(
                  entradas: snapshot.data ?? const [],
                  period: _historicoPeriod,
                  onBack: () => setState(() => _mode = _GlicemiaMode.resumo),
                  onPeriodChanged: (period) {
                    setState(() => _historicoPeriod = period);
                    _reloadHistorico(idoso.id);
                  },
                );
              },
            ),
          _GlicemiaMode.resumo => FutureBuilder<GlicemiaResumo>(
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
                    snapshot.data ?? GlicemiaResumo.fromJson(const {});

                return _ResumoGlicemiaView(
                  idoso: idoso,
                  resumo: resumo,
                  period: _period,
                  referenceDate: _referenceDate,
                  onBack: () => context.go(moduleBackRoute(context)),
                  onRegisterGlicemia: () {
                    if (!idoso.podeEditarModulo('Glicemia')) {
                      _showNoEditPermission();
                      return;
                    }
                    setState(() => _mode = _GlicemiaMode.registrarGlicemia);
                  },
                  onRegisterInsulina: () {
                    if (!idoso.podeEditarModulo('Glicemia')) {
                      _showNoEditPermission();
                      return;
                    }
                    setState(() => _mode = _GlicemiaMode.registrarInsulina);
                  },
                  onViewHistorico: () {
                    setState(() => _mode = _GlicemiaMode.historico);
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

class _ResumoGlicemiaView extends StatelessWidget {
  const _ResumoGlicemiaView({
    required this.idoso,
    required this.resumo,
    required this.period,
    required this.referenceDate,
    required this.onBack,
    required this.onRegisterGlicemia,
    required this.onRegisterInsulina,
    required this.onViewHistorico,
    required this.onCalendar,
    required this.onPeriodChanged,
  });

  final IdosoResumo idoso;
  final GlicemiaResumo resumo;
  final _ChartPeriod period;
  final DateTime referenceDate;
  final VoidCallback onBack;
  final VoidCallback onRegisterGlicemia;
  final VoidCallback onRegisterInsulina;
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
          _GlicemiaHeader(
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
            child: resumo.totalRegistrosGeral == 0
                ? _PrimeiraMedicaoState(
                    idosoNome: idoso.nome,
                    hasPreviousRecords: resumo.totalRegistrosGeral > 0,
                    onRegisterGlicemia: onRegisterGlicemia,
                    onRegisterInsulina: onRegisterInsulina,
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      StaggeredEntry(
                        index: 0,
                        child: _MediaGlicemiaCard(resumo: resumo),
                      ),
                      const SizedBox(height: 14),
                      StaggeredEntry(
                        index: 1,
                        child: _MetricCard(
                          icon: Icons.trending_up_rounded,
                          label: 'Média 7 dias',
                          value: resumo.analise.mediaUltimos7Dias == null
                              ? '--'
                              : resumo.analise.mediaUltimos7Dias!
                                  .round()
                                  .toString(),
                          suffix: 'mg/dl',
                        ),
                      ),
                      const SizedBox(height: 16),
                      StaggeredEntry(
                        index: 2,
                        child: _ChartCard(
                          period: period,
                          series: resumo.serie,
                          onChanged: onPeriodChanged,
                        ),
                      ),
                      const SizedBox(height: 14),
                      StaggeredEntry(
                        index: 3,
                        child: _AnalysisCard(resumo: resumo),
                      ),
                      const SizedBox(height: 16),
                      StaggeredEntry(
                        index: 4,
                        child: _NavRow(
                          icon: Icons.water_drop_rounded,
                          iconColor: const Color(0xFFFF4657),
                          title: 'Registrar glicemia',
                          onTap: onRegisterGlicemia,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StaggeredEntry(
                        index: 5,
                        child: _NavRow(
                          icon: Icons.medication_liquid_rounded,
                          iconColor: const Color(0xFF087B8D),
                          title: 'Registrar uso de insulina',
                          onTap: onRegisterInsulina,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StaggeredEntry(
                        index: 6,
                        child: _NavRow(
                          icon: Icons.history_rounded,
                          iconColor: const Color(0xFF25A1B2),
                          title: 'Ver histórico de glicemia',
                          onTap: onViewHistorico,
                        ),
                      ),
                      if (resumo.insulinaRecente != null) ...[
                        const SizedBox(height: 12),
                        StaggeredEntry(
                          index: 7,
                          child: _InsulinaResumoCard(
                            insulina: resumo.insulinaRecente!,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _GlicemiaHeader extends StatelessWidget {
  const _GlicemiaHeader({
    required this.onBack,
    this.title = 'Resumo da glicemia',
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
    required this.onRegisterGlicemia,
    required this.onRegisterInsulina,
  });

  final String idosoNome;
  final bool hasPreviousRecords;
  final VoidCallback onRegisterGlicemia;
  final VoidCallback onRegisterInsulina;

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
                  Icons.water_drop_rounded,
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
                    ? 'Ainda não há registros de glicemia hoje para $idosoNome. Registre a medição do dia e mantenha o acompanhamento atualizado.'
                    : 'Ainda não há registros de glicemia para $idosoNome. Comece registrando a medição atual e, se houver orientação médica, o uso de insulina.',
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
                  onPressed: onRegisterGlicemia,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Registrar glicemia'),
                  style: _primaryButtonStyle(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: onRegisterInsulina,
                  icon: const Icon(Icons.medication_liquid_rounded),
                  label: const Text('Registrar uso de insulina'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF245066),
                    side: const BorderSide(color: Color(0xFF2FA3B5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
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

class _AnimatedGlicemiaValue extends StatelessWidget {
  const _AnimatedGlicemiaValue({required this.value});

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
            style: TextStyle(
              color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
              fontWeight: FontWeight.w400,
            ),
            children: [
              TextSpan(
                  text: text, style: const TextStyle(fontSize: 39, height: 1)),
              const TextSpan(text: ' mg/dL', style: TextStyle(fontSize: 25)),
            ],
          ),
        );
      },
    );
  }
}

class _MediaGlicemiaCard extends StatelessWidget {
  const _MediaGlicemiaCard({required this.resumo});

  final GlicemiaResumo resumo;

  @override
  Widget build(BuildContext context) {
    final media = resumo.mediaDia ?? resumo.analise.mediaUltimos7Dias;

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
                  'Média da glicemia',
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF727272),
                        AppDarkColors.textSecondary),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                _AnimatedGlicemiaValue(value: media),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.water_drop_rounded,
            color: Color(0xFFFF4657),
            size: 50,
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.suffix,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 81,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
      decoration: _cardDecoration(context, radius: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  color: adaptive(context, const Color(0xFFBFE7EC),
                      AppDarkColors.surfaceAlt),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF148A9C), size: 14),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adaptive(
                        context, Colors.black, AppDarkColors.textPrimary),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Color(0xFF087B8D)),
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w400,
                      height: 1,
                    ),
                  ),
                  if (suffix != null)
                    TextSpan(
                      text: suffix,
                      style: const TextStyle(fontSize: 19),
                    ),
                ],
              ),
            ),
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
  final List<GlicemiaSeriePonto> series;
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
                  painter: _GlicemiaChartPainter(series, animatedValue),
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

class _GlicemiaChartPainter extends CustomPainter {
  const _GlicemiaChartPainter(this.series, [this.progress = 1]);

  final List<GlicemiaSeriePonto> series;
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
        ? 70.0
        : values.map((entry) => entry.value).reduce(math.min) - 20;
    final maxValue = values.isEmpty
        ? 180.0
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
  bool shouldRepaint(covariant _GlicemiaChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.progress != progress;
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.resumo});

  final GlicemiaResumo resumo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          adaptive(context, const Color(0xFFC9E7ED), AppDarkColors.tintedInfo),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 11, 12, 11),
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
                Icons.water_drop_outlined,
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
                    'Análise de glicemia',
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF2F4853),
                          AppDarkColors.textPrimary),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    resumo.analise.texto,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF2F4853),
                          AppDarkColors.textPrimary),
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsulinaResumoCard extends StatelessWidget {
  const _InsulinaResumoCard({required this.insulina});

  final InsulinaRegistro insulina;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(context, radius: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: adaptive(
                  context, const Color(0xFFD8F1F4), AppDarkColors.tintedInfo),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medication_liquid_rounded,
              color: Color(0xFF087B8D),
              size: 23,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Última insulina registrada',
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF2F4853),
                        AppDarkColors.textPrimary),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${insulina.tipoInsulina} • ${_formatDose(insulina.doseUnidades)} un • ${_formatTime(insulina.aplicadoEm)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF607178),
                        AppDarkColors.textSecondary),
                    fontSize: 11,
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

class _HistoricoGlicemiaView extends StatelessWidget {
  const _HistoricoGlicemiaView({
    required this.entradas,
    required this.period,
    required this.onBack,
    required this.onPeriodChanged,
  });

  final List<GlicemiaHistoricoEntrada> entradas;
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
          _GlicemiaHeader(
            onBack: onBack,
            title: 'Histórico da glicemia',
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

  final GlicemiaHistoricoEntrada entrada;

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor(entrada.badge.cor);
    final isEdicao = entrada.descricao == 'editou observação';
    final icon = isEdicao ? Icons.edit_rounded : Icons.water_drop_rounded;
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
                  entrada.valor != null
                      ? '${entrada.valor} mg/dL'
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

class _RegistrarGlicemiaView extends StatelessWidget {
  const _RegistrarGlicemiaView({
    required this.formKey,
    required this.valorController,
    required this.observacoesController,
    required this.selectedDate,
    required this.selectedTime,
    required this.contexto,
    required this.observationHint,
    required this.saving,
    required this.onContextoChanged,
    required this.onSelectDate,
    required this.onSelectTime,
    required this.onSave,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController valorController;
  final TextEditingController observacoesController;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final String contexto;
  final String observationHint;
  final bool saving;
  final ValueChanged<String?> onContextoChanged;
  final VoidCallback onSelectDate;
  final VoidCallback onSelectTime;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Registrar glicemia',
      onBack: onCancel,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GlicemiaValueInput(controller: valorController),
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
            _DropdownCard(
              title: 'Momento da medição',
              value: contexto,
              options: const [
                'Jejum',
                'Antes da refeição',
                'Após refeição',
                'Ao deitar',
                'Sintomas',
                'Outro',
              ],
              onChanged: saving ? null : onContextoChanged,
            ),
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

class _RegistrarInsulinaView extends StatelessWidget {
  const _RegistrarInsulinaView({
    required this.formKey,
    required this.doseController,
    required this.observacoesController,
    required this.selectedDate,
    required this.selectedTime,
    required this.nomeInsulina,
    required this.tipoInsulina,
    required this.localAplicacao,
    required this.observationHint,
    required this.saving,
    required this.onNomeChanged,
    required this.onTipoChanged,
    required this.onLocalChanged,
    required this.onSelectDate,
    required this.onSelectTime,
    required this.onSave,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController doseController;
  final TextEditingController observacoesController;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final String nomeInsulina;
  final String tipoInsulina;
  final String localAplicacao;
  final String observationHint;
  final bool saving;
  final ValueChanged<String?> onNomeChanged;
  final ValueChanged<String> onTipoChanged;
  final ValueChanged<String?> onLocalChanged;
  final VoidCallback onSelectDate;
  final VoidCallback onSelectTime;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Registrar insulina',
      onBack: onCancel,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DropdownCard(
              title: 'Insulina',
              value: nomeInsulina,
              options: _kInsulinas,
              onChanged: saving ? null : onNomeChanged,
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
            _TipoInsulinaSelector(
              value: tipoInsulina,
              onChanged: saving ? (_) {} : onTipoChanged,
            ),
            const SizedBox(height: 12),
            _DoseInput(controller: doseController),
            const SizedBox(height: 12),
            _DropdownCard(
              title: 'Local de aplicação',
              value: localAplicacao,
              options: _kLocaisAplicacao,
              onChanged: saving ? null : onLocalChanged,
            ),
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

class _TipoInsulinaSelector extends StatelessWidget {
  const _TipoInsulinaSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 11),
      decoration: _cardDecoration(context, radius: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipo de insulina',
            style: TextStyle(
              color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TipoInsulinaOption(
                  label: 'Basal\n(longa ação)',
                  selected: value == 'Basal',
                  onTap: () => onChanged('Basal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TipoInsulinaOption(
                  label: 'Rápida\n(bolus)',
                  selected: value == 'Rápida',
                  onTap: () => onChanged('Rápida'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TipoInsulinaOption extends StatelessWidget {
  const _TipoInsulinaOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2FA3B5) : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: const Color(0xFF2FA3B5),
            width: selected ? 0 : 1.2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF17324D),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
      ),
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

class _GlicemiaValueInput extends StatelessWidget {
  const _GlicemiaValueInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _NumericValueCard(
      icon: Icons.water_drop_rounded,
      iconColor: const Color(0xFFFF4657),
      label: 'Valor da glicemia',
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: const [],
      digitsOnly: true,
      hintText: '000',
      suffixText: 'mg/dL',
      validator: _validateGlicemia,
    );
  }
}

class _DoseInput extends StatelessWidget {
  const _DoseInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _NumericValueCard(
      icon: Icons.medication_liquid_rounded,
      iconColor: const Color(0xFF2FA3B5),
      label: 'Dose aplicada',
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}([,.]\d{0,2})?$')),
      ],
      hintText: '0,0',
      suffixText: 'UI',
      captionBelow: 'Unidades Internacionais',
      validator: _validateDose,
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
    this.captionBelow,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final String hintText;
  final String suffixText;
  final String? captionBelow;
  final FormFieldValidator<String> validator;
  final bool digitsOnly;

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
                          keyboardType: keyboardType,
                          inputFormatters: digitsOnly
                              ? [FilteringTextInputFormatter.digitsOnly]
                              : inputFormatters,
                          validator: validator,
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
                            hintText: hintText,
                            hintStyle: TextStyle(
                              color: adaptive(context, const Color(0xFFBFCBCE),
                                  AppDarkColors.textMuted),
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
                if (captionBelow != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    captionBelow!,
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF8D8D8D),
                          AppDarkColors.textMuted),
                      fontSize: 12,
                    ),
                  ),
                ],
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

class _DropdownCard extends StatelessWidget {
  const _DropdownCard({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 12),
      decoration: _cardDecoration(context, radius: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: value,
            onChanged: onChanged,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: adaptive(
                  context, const Color(0xFF8A8A8A), AppDarkColors.textMuted),
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: Color(0xFF2FA3B5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: Color(0xFF2FA3B5)),
              ),
            ),
            items: [
              for (final option in options)
                DropdownMenuItem(value: option, child: Text(option)),
            ],
          ),
        ],
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
            'Selecione uma pessoa idosa para registrar glicemia e uso de insulina.',
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
          _GlicemiaHeader(onBack: onBack),
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

Color _badgeColor(String cor) {
  return switch (cor) {
    'normal' => const Color(0xFF28A745),
    'alerta' => const Color(0xFFE49A20),
    'atualizado' => const Color(0xFF7C5CD6),
    _ => const Color(0xFF607178),
  };
}

String? _validateGlicemia(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  if (parsed == null) return 'Informe o valor.';
  if (parsed < 20 || parsed > 600) return 'Use um valor entre 20 e 600.';
  return null;
}

String? _validateDose(String? value) {
  final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
  if (parsed == null) return 'Informe a dose.';
  if (parsed <= 0 || parsed > 200) return 'Use uma dose entre 0 e 200.';
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

String _formatDose(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

void _ignoreBottomMessage() {}
