import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/navigation/module_navigation.dart';
import '../../../shared/widgets/action_icon_button.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/staggered_entry.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class DashboardIdosoPage extends ConsumerStatefulWidget {
  const DashboardIdosoPage({super.key});

  @override
  ConsumerState<DashboardIdosoPage> createState() => _DashboardIdosoPageState();
}

class _DashboardIdosoPageState extends ConsumerState<DashboardIdosoPage> {
  static final Map<String, _DashboardCacheEntry> _cache = {};

  var _loading = false;
  _DashboardResumo _resumo = const _DashboardResumo();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null) return;

    final cached = _cache[idoso.id];

    if (cached != null && mounted) {
      setState(() => _resumo = cached.resumo);
    }

    setState(() => _loading = cached == null);
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait<dynamic>([
        api.listarCompromissos(idosoId: idoso.id),
        api.listarHumores(idosoId: idoso.id),
        api.listarRefeicoes(idosoId: idoso.id),
        api.getResumoGlicemia(idosoId: idoso.id),
        api.getResumoMedicamentosConsolidado(idosoId: idoso.id),
      ]);

      if (!mounted) return;
      final resumo = _DashboardResumo.fromData(
        compromissos: results[0] as List<Map<String, dynamic>>,
        humores: results[1] as List<Map<String, dynamic>>,
        refeicoes: results[2] as List<RefeicaoResumo>,
        glicemia: results[3] as GlicemiaResumo,
        medicamentos: results[4] as MedicamentosResumo,
        dica: cached?.resumo.dica ?? _resumo.dica,
      );

      setState(() {
        _resumo = resumo;
      });
      _cache[idoso.id] = _DashboardCacheEntry(
        resumo: resumo,
        updatedAt: DateTime.now(),
      );

      _loadTip(api, idoso.id);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar o resumo.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTip(ApiClient api, String idosoId) async {
    try {
      final dica = await api.buscarDicaDashboard(idosoId: idosoId);
      if (!mounted || ref.read(selectedIdosoProvider)?.id != idosoId) return;

      final resumo = _resumo.copyWith(dica: dica);
      setState(() => _resumo = resumo);
      _cache[idosoId] = _DashboardCacheEntry(
        resumo: resumo,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      // A dica da IA não deve atrasar o carregamento do resumo principal.
    }
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);

    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFCFCFC), AppDarkColors.bg),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: RefreshIndicator(
              color: const Color(0xFF38AFC0),
              onRefresh: () => _load(force: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 88),
                children: [
                  StaggeredEntry(
                    index: 0,
                    child: _DashboardHeader(
                        onProfile: () => context.go('/perfil')),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntry(
                    index: 1,
                    child: _Greeting(idoso: idoso),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntry(
                    index: 2,
                    child: _IdosoHeroCard(
                      nome: idoso?.nome ?? 'Selecione uma ficha',
                      idade: idoso?.idade,
                      foto: idoso?.urlFoto,
                    ),
                  ),
                  const SizedBox(height: 14),
                  StaggeredEntry(
                    index: 3,
                    child: _MedicationAlert(
                      title: _resumo.proximoMedicamentoTitulo,
                      label: _resumo.proximoMedicamentoLabel,
                      time: _resumo.proximoMedicamentoHora,
                      tone: _resumo.proximoMedicamentoTom,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Resumo do Dia',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF333333),
                          AppDarkColors.textPrimary),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  StaggeredEntry(
                    index: 4,
                    child: _SummaryCard(
                      icon: Icons.medication_outlined,
                      title: 'Medicamentos:',
                      value: _resumo.medicamentosLabel,
                      valueColor: const Color(0xFFFF8A00),
                      onTap: () => context.go(
                        routeWithOrigin('/medicamentos', 'dashboard'),
                      ),
                    ),
                  ),
                  StaggeredEntry(
                    index: 5,
                    child: _SummaryCard(
                      icon: Icons.sentiment_satisfied_alt_rounded,
                      title: 'Humor:',
                      value: _resumo.humorLabel,
                      valueColor: const Color(0xFF168FA1),
                      onTap: () => context.go(
                        routeWithOrigin('/humor', 'dashboard'),
                      ),
                    ),
                  ),
                  StaggeredEntry(
                    index: 6,
                    child: _SummaryCard(
                      icon: Icons.restaurant_rounded,
                      title: 'Última refeição:',
                      value: _resumo.ultimaRefeicaoLabel,
                      valueColor: const Color(0xFF168FA1),
                      onTap: () => context.go(
                        routeWithOrigin('/alimentacao', 'dashboard'),
                      ),
                    ),
                  ),
                  StaggeredEntry(
                    index: 7,
                    child: _SummaryCard(
                      icon: Icons.vaccines_outlined,
                      title: 'Insulina:',
                      value: _resumo.insulinaLabel,
                      valueColor: const Color(0xFF168FA1),
                      onTap: () => context.go(
                        routeWithOrigin('/glicemia', 'dashboard'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Próximo compromisso',
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF333333),
                          AppDarkColors.textPrimary),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  StaggeredEntry(
                    index: 8,
                    child: _NextAppointmentCard(
                      title: _resumo.proximoCompromissoTitulo,
                      details: _resumo.proximoCompromissoDetalhes,
                      onTap: () => context.go(
                        routeWithOrigin('/agenda', 'dashboard'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  StaggeredEntry(
                    index: 9,
                    child: _TipCard(text: _resumo.dica),
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Color(0xFF38AFC0),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onProfile});

  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(
      title: 'Início',
      trailing: ActionIconButton(
        tooltip: 'Perfil do cuidador',
        icon: Icons.person_rounded,
        onTap: onProfile,
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.idoso});

  final IdosoResumo? idoso;

  @override
  Widget build(BuildContext context) {
    final name = idoso?.nome.split(' ').first;
    final textColor =
        adaptive(context, const Color(0xFF333333), AppDarkColors.textPrimary);
    final personText = idoso?.elderText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greetingText(),
          style: TextStyle(
            color: textColor,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          name == null
              ? 'Selecione uma ficha para comecar'
              : 'cuidando ${personText!.of} $name hoje',
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _IdosoHeroCard extends StatelessWidget {
  const _IdosoHeroCard({
    required this.nome,
    this.idade,
    this.foto,
  });

  final String nome;
  final int? idade;
  final String? foto;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataImageBytes(foto);

    return Container(
      height: 126,
      padding: const EdgeInsets.fromLTRB(24, 13, 20, 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2BA8BA), Color(0xFF0E6F7E)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E6F7E).withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 43,
            backgroundColor: const Color(0xFFD1F2F6),
            backgroundImage: bytes != null
                ? MemoryImage(bytes)
                : foto != null && foto!.startsWith('http')
                    ? NetworkImage(foto!) as ImageProvider
                    : null,
            child: bytes == null && (foto == null || !foto!.startsWith('http'))
                ? const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF238FA1),
                    size: 52,
                  )
                : null,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.08,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(width: 108, height: 1.5, color: Colors.white),
                  const SizedBox(height: 8),
                  if (idade != null && idade! > 0)
                    Row(
                      children: [
                        const Icon(
                          Icons.cake_outlined,
                          color: Colors.white,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$idade anos',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

enum _MedicationAlertTone { late, soon, later, done, empty }

class _MedicationAlertColors {
  const _MedicationAlertColors({
    required this.background,
    required this.badgeBackground,
    required this.accent,
    required this.icon,
  });

  final Color background;
  final Color badgeBackground;
  final Color accent;
  final IconData icon;
}

_MedicationAlertColors _medicationAlertColors(
  BuildContext context,
  _MedicationAlertTone tone,
) {
  return switch (tone) {
    _MedicationAlertTone.late => _MedicationAlertColors(
        background: adaptive(
            context, const Color(0xFFFFF1F1), AppDarkColors.tintedWarn),
        badgeBackground: adaptive(
            context, const Color(0xFFFFF1F1), AppDarkColors.tintedWarn),
        accent: const Color(0xFFD73A3A),
        icon: Icons.warning_amber_rounded,
      ),
    _MedicationAlertTone.soon => _MedicationAlertColors(
        background: adaptive(
            context, const Color(0xFFFFF3E3), AppDarkColors.tintedWarn),
        badgeBackground: adaptive(
            context, const Color(0xFFFFF3E3), AppDarkColors.tintedWarn),
        accent: const Color(0xFFE47A00),
        icon: Icons.notifications_active_rounded,
      ),
    _MedicationAlertTone.later => _MedicationAlertColors(
        background: adaptive(
            context, const Color(0xFFE8F8FA), AppDarkColors.tintedInfo),
        badgeBackground: adaptive(
            context, const Color(0xFFE8F8FA), AppDarkColors.tintedInfo),
        accent: const Color(0xFF168FA1),
        icon: Icons.notifications_none_rounded,
      ),
    _MedicationAlertTone.done => _MedicationAlertColors(
        background: adaptive(
            context, const Color(0xFFEAF8EF), AppDarkColors.surfaceAlt),
        badgeBackground: adaptive(
            context, const Color(0xFFEAF8EF), AppDarkColors.surfaceAlt),
        accent: const Color(0xFF28A745),
        icon: Icons.check_circle_outline_rounded,
      ),
    _MedicationAlertTone.empty => _MedicationAlertColors(
        background: adaptive(
            context, const Color(0xFFF3F8F9), AppDarkColors.surfaceAlt),
        badgeBackground: adaptive(
            context, const Color(0xFFF3F8F9), AppDarkColors.surfaceAlt),
        accent: const Color(0xFF168FA1),
        icon: Icons.medication_outlined,
      ),
  };
}

class _MedicationAlert extends StatelessWidget {
  const _MedicationAlert({
    required this.title,
    required this.label,
    required this.time,
    required this.tone,
  });

  final String title;
  final String label;
  final String time;
  final _MedicationAlertTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _medicationAlertColors(context, tone);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: _dashboardCardDecoration(color: colors.background),
      child: Row(
        children: [
          Icon(colors.icon, color: colors.accent, size: 31),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF555555),
                        AppDarkColors.textSecondary),
                    fontSize: 12,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: colors.badgeBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              time,
              style: TextStyle(
                color: colors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.valueColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color valueColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        borderRadius: BorderRadius.circular(8),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.fromLTRB(17, 10, 14, 10),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF2298AA), size: 31),
                const SizedBox(width: 13),
                Expanded(
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF444444),
                            AppDarkColors.textPrimary),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        TextSpan(text: '$title '),
                        TextSpan(
                          text: value,
                          style: TextStyle(
                            color: valueColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({
    required this.title,
    required this.details,
    required this.onTap,
  });

  final String title;
  final String details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: adaptive(context, Colors.white, AppDarkColors.surface),
      borderRadius: BorderRadius.circular(8),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF38AFC0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF333333),
                            AppDarkColors.textPrimary),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF111111),
                            AppDarkColors.textSecondary),
                        fontSize: 13,
                        height: 1.15,
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

class _TipCard extends StatelessWidget {
  const _TipCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final textColor =
        adaptive(context, const Color(0xFF333333), AppDarkColors.textPrimary);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
      decoration: BoxDecoration(
        color: adaptive(
            context, const Color(0xFFCBEFF3), AppDarkColors.tintedInfo),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF38AFC0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lightbulb_outline_rounded,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dica do dia',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    height: 1.15,
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

class _MedicamentosDashboardInfo {
  const _MedicamentosDashboardInfo({
    required this.resumoLabel,
    required this.proximoTitulo,
    required this.proximoLabel,
    required this.proximoHorario,
    required this.proximoTom,
  });

  final String resumoLabel;
  final String proximoTitulo;
  final String proximoLabel;
  final String proximoHorario;
  final _MedicationAlertTone proximoTom;
}

_MedicamentosDashboardInfo _medicamentosDashboardInfo(
  MedicamentosResumo resumo,
) {
  if (resumo.totalMedicamentos == 0) {
    return const _MedicamentosDashboardInfo(
      resumoLabel: 'nenhum cadastrado',
      proximoTitulo: 'Medicamentos',
      proximoLabel: 'Cadastre medicamentos',
      proximoHorario: '--:--',
      proximoTom: _MedicationAlertTone.empty,
    );
  }

  final pendentes = resumo.medicamentos
      .where(_medicamentoTemDosePendente)
      .toList()
    ..sort(_compareMedicamentosPendentes);

  if (pendentes.isEmpty) {
    return const _MedicamentosDashboardInfo(
      resumoLabel: 'sem pendências',
      proximoTitulo: 'Tudo em dia',
      proximoLabel: 'Todos os remédios de hoje foram tomados.',
      proximoHorario: 'OK',
      proximoTom: _MedicationAlertTone.done,
    );
  }

  final atrasados = pendentes.where(_medicamentoAtrasado).length;
  final proximo = pendentes.first;
  final dosagem = proximo.dosagem?.trim();
  final minutosAteDose =
      proximo.proximoHorarioPrevisto?.difference(DateTime.now()).inMinutes;
  final tom = _medicamentoAtrasado(proximo)
      ? _MedicationAlertTone.late
      : minutosAteDose != null && minutosAteDose <= 30
          ? _MedicationAlertTone.soon
          : _MedicationAlertTone.later;

  return _MedicamentosDashboardInfo(
    resumoLabel: atrasados > 0
        ? '$atrasados ${atrasados == 1 ? 'atrasado' : 'atrasados'}'
        : '${pendentes.length} ${pendentes.length == 1 ? 'pendente' : 'pendentes'}',
    proximoTitulo: _medicamentoAtrasado(proximo)
        ? 'Medicamento atrasado'
        : 'Próximo medicamento',
    proximoLabel: dosagem == null || dosagem.isEmpty
        ? proximo.nome
        : '${proximo.nome} - $dosagem',
    proximoHorario: proximo.proximoHorario ?? '--:--',
    proximoTom: tom,
  );
}

bool _medicamentoComTodasDosesDadas(MedicamentoResumo? medicamento) {
  if (medicamento == null) return false;
  if (medicamento.statusHoje == 'dado') return true;
  return medicamento.totalHorarios > 0 &&
      medicamento.dosesAdministradasHoje >= medicamento.totalHorarios;
}

bool _medicamentoTemDosePendente(MedicamentoResumo? medicamento) {
  if (medicamento == null) return false;
  return medicamento.proximoHorario != null &&
      !_medicamentoComTodasDosesDadas(medicamento);
}

bool _medicamentoAtrasado(MedicamentoResumo medicamento) {
  return medicamento.proximoAtrasado || medicamento.statusHoje == 'atrasado';
}

int _compareMedicamentosPendentes(
  MedicamentoResumo left,
  MedicamentoResumo right,
) {
  final leftAtrasado = _medicamentoAtrasado(left);
  final rightAtrasado = _medicamentoAtrasado(right);
  if (leftAtrasado != rightAtrasado) return leftAtrasado ? -1 : 1;

  final leftDate = left.proximoHorarioPrevisto;
  final rightDate = right.proximoHorarioPrevisto;
  if (leftDate != null && rightDate != null) {
    return leftDate.compareTo(rightDate);
  }

  return (left.proximoHorario ?? '').compareTo(right.proximoHorario ?? '');
}

class _DashboardResumo {
  const _DashboardResumo({
    this.medicamentosLabel = 'em breve',
    this.proximoMedicamentoTitulo = 'Medicamentos',
    this.proximoMedicamentoLabel = 'Cadastre medicamentos',
    this.proximoMedicamentoHora = '--:--',
    this.proximoMedicamentoTom = _MedicationAlertTone.empty,
    this.humorLabel = 'não registrado ainda',
    this.ultimaRefeicaoLabel = 'não registrado ainda',
    this.insulinaLabel = 'não registrado ainda',
    this.proximoCompromissoTitulo = 'Nenhum compromisso',
    this.proximoCompromissoDetalhes = 'Agenda livre por enquanto',
    this.dica =
        'Incentive pequenas pausas, hidratação e movimento ao longo do dia.',
  });

  factory _DashboardResumo.fromData({
    required List<Map<String, dynamic>> compromissos,
    required List<Map<String, dynamic>> humores,
    required List<RefeicaoResumo> refeicoes,
    required GlicemiaResumo glicemia,
    required MedicamentosResumo medicamentos,
    required String dica,
  }) {
    final nextAppointment = _nextAppointment(compromissos);
    final latestMeal = _latestMealToday(refeicoes);
    final latestMood = _latestMoodToday(humores);
    final latestInsulin = glicemia.insulinaRecente;
    final hasInsulinToday =
        latestInsulin != null && _isSameLocalDay(latestInsulin.aplicadoEm);
    final medicamentosInfo = _medicamentosDashboardInfo(medicamentos);

    return _DashboardResumo(
      medicamentosLabel: medicamentosInfo.resumoLabel,
      proximoMedicamentoTitulo: medicamentosInfo.proximoTitulo,
      proximoMedicamentoLabel: medicamentosInfo.proximoLabel,
      proximoMedicamentoHora: medicamentosInfo.proximoHorario,
      proximoMedicamentoTom: medicamentosInfo.proximoTom,
      humorLabel: latestMood ?? 'não registrado ainda',
      ultimaRefeicaoLabel: latestMeal == null
          ? 'não registrado ainda'
          : 'Ha ${_timeAgo(_mealDateTime(latestMeal))}',
      insulinaLabel: hasInsulinToday
          ? '${latestInsulin.tipoInsulina} normal'
          : 'não registrado ainda',
      proximoCompromissoTitulo: nextAppointment?.title ?? 'Nenhum compromisso',
      proximoCompromissoDetalhes:
          nextAppointment?.details ?? 'Agenda livre por enquanto',
      dica: dica,
    );
  }

  final String medicamentosLabel;
  final String proximoMedicamentoTitulo;
  final String proximoMedicamentoLabel;
  final String proximoMedicamentoHora;
  final _MedicationAlertTone proximoMedicamentoTom;
  final String humorLabel;
  final String ultimaRefeicaoLabel;
  final String insulinaLabel;
  final String proximoCompromissoTitulo;
  final String proximoCompromissoDetalhes;
  final String dica;

  _DashboardResumo copyWith({
    String? medicamentosLabel,
    String? proximoMedicamentoTitulo,
    String? proximoMedicamentoLabel,
    String? proximoMedicamentoHora,
    _MedicationAlertTone? proximoMedicamentoTom,
    String? humorLabel,
    String? ultimaRefeicaoLabel,
    String? insulinaLabel,
    String? proximoCompromissoTitulo,
    String? proximoCompromissoDetalhes,
    String? dica,
  }) {
    return _DashboardResumo(
      medicamentosLabel: medicamentosLabel ?? this.medicamentosLabel,
      proximoMedicamentoTitulo:
          proximoMedicamentoTitulo ?? this.proximoMedicamentoTitulo,
      proximoMedicamentoLabel:
          proximoMedicamentoLabel ?? this.proximoMedicamentoLabel,
      proximoMedicamentoHora:
          proximoMedicamentoHora ?? this.proximoMedicamentoHora,
      proximoMedicamentoTom:
          proximoMedicamentoTom ?? this.proximoMedicamentoTom,
      humorLabel: humorLabel ?? this.humorLabel,
      ultimaRefeicaoLabel: ultimaRefeicaoLabel ?? this.ultimaRefeicaoLabel,
      insulinaLabel: insulinaLabel ?? this.insulinaLabel,
      proximoCompromissoTitulo:
          proximoCompromissoTitulo ?? this.proximoCompromissoTitulo,
      proximoCompromissoDetalhes:
          proximoCompromissoDetalhes ?? this.proximoCompromissoDetalhes,
      dica: dica ?? this.dica,
    );
  }
}

class _DashboardCacheEntry {
  const _DashboardCacheEntry({required this.resumo, required this.updatedAt});

  final _DashboardResumo resumo;
  final DateTime updatedAt;
}

class _AppointmentSummary {
  const _AppointmentSummary({required this.title, required this.details});

  final String title;
  final String details;
}

_AppointmentSummary? _nextAppointment(List<Map<String, dynamic>> items) {
  final now = DateTime.now();
  final parsed = items
      .map(_appointmentFromJson)
      .whereType<_ParsedAppointment>()
      .where((item) => item.dateTime.isAfter(now))
      .toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final next = parsed.isEmpty ? null : parsed.first;
  if (next == null) return null;
  return _AppointmentSummary(
    title: next.title,
    details:
        '${_formatDate(next.dateTime)} as ${_formatTime(next.dateTime)}\n${next.local}',
  );
}

class _ParsedAppointment {
  const _ParsedAppointment({
    required this.title,
    required this.dateTime,
    required this.local,
  });

  final String title;
  final DateTime dateTime;
  final String local;
}

_ParsedAppointment? _appointmentFromJson(Map<String, dynamic> json) {
  final date =
      (json['data_compromisso'] ?? json['dataCompromisso'])?.toString().trim();
  final time =
      (json['hora_compromisso'] ?? json['horaCompromisso'])?.toString().trim();
  DateTime? dateTime;
  if (date != null && date.length >= 10) {
    dateTime = DateTime.tryParse(
        '${date.substring(0, 10)}T${(time ?? '00:00').substring(0, 5)}');
  }
  dateTime ??= DateTime.tryParse(
    (json['inicio_em'] ?? json['inicioEm'])?.toString() ?? '',
  )?.toLocal();
  if (dateTime == null) return null;
  return _ParsedAppointment(
    title: json['titulo']?.toString() ?? 'Compromisso',
    dateTime: dateTime,
    local: json['local']?.toString().isNotEmpty == true
        ? json['local'].toString()
        : 'Local não informado',
  );
}

String? _latestMoodToday(List<Map<String, dynamic>> humores) {
  if (humores.isEmpty) return null;
  final sorted = humores.where((item) {
    return _isSameLocalDay(_parseMoodDate(item));
  }).toList()
    ..sort((a, b) {
      final aDate = _parseMoodDate(a);
      final bDate = _parseMoodDate(b);
      return bDate.compareTo(aDate);
    });
  if (sorted.isEmpty) return null;
  final value = sorted.first['humor']?.toString();
  if (value == null || value.isEmpty) return null;
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

DateTime _parseMoodDate(Map<String, dynamic> item) {
  final date = (item['dataHumor'] ?? item['data_humor'])?.toString() ?? '';
  final time = (item['horarioRegi'] ?? item['horario_regi'])?.toString() ?? '';
  return DateTime.tryParse(
          '${date.substring(0, date.length >= 10 ? 10 : date.length)}T${time.length >= 5 ? time.substring(0, 5) : '00:00'}') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

RefeicaoResumo? _latestMealToday(List<RefeicaoResumo> refeicoes) {
  if (refeicoes.isEmpty) return null;
  final sorted = refeicoes.where((item) {
    final dateTime = _mealDateTime(item);
    return dateTime != null && _isSameLocalDay(dateTime);
  }).toList()
    ..sort((a, b) {
      final aDate = _mealDateTime(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = _mealDateTime(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
  if (sorted.isEmpty) return null;
  return sorted.first;
}

bool _isSameLocalDay(DateTime date, [DateTime? reference]) {
  final localDate = date.toLocal();
  final localReference = (reference ?? DateTime.now()).toLocal();
  return localDate.year == localReference.year &&
      localDate.month == localReference.month &&
      localDate.day == localReference.day;
}

DateTime? _mealDateTime(RefeicaoResumo refeicao) {
  final date = refeicao.dataConsumo;
  if (date == null) return null;
  final time = refeicao.horaConsumo;
  final hour = time != null && time.length >= 2
      ? int.tryParse(time.substring(0, 2)) ?? 0
      : 0;
  final minute = time != null && time.length >= 5
      ? int.tryParse(time.substring(3, 5)) ?? 0
      : 0;
  return DateTime(date.year, date.month, date.day, hour, minute);
}

String _timeAgo(DateTime? date) {
  if (date == null) return 'pouco tempo';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} min';
  if (diff.inHours < 24) return '${diff.inHours} horas';
  return '${diff.inDays} dias';
}

String _greetingText() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Bom dia';
  if (hour < 18) return 'Boa tarde';
  return 'Boa noite';
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

BoxDecoration _dashboardCardDecoration({Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.18),
        blurRadius: 7,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

Uint8List? _dataImageBytes(String? value) {
  if (value == null || !value.startsWith('data:image')) return null;
  final commaIndex = value.indexOf(',');
  if (commaIndex == -1) return null;
  try {
    return base64Decode(value.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}
