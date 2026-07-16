import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class DashboardIdosoPage extends ConsumerStatefulWidget {
  const DashboardIdosoPage({super.key});

  @override
  ConsumerState<DashboardIdosoPage> createState() => _DashboardIdosoPageState();
}

class _DashboardIdosoPageState extends ConsumerState<DashboardIdosoPage> {
  var _loading = false;
  _DashboardResumo _resumo = const _DashboardResumo();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait<dynamic>([
        api.listarCompromissos(idosoId: idoso.id),
        api.listarHumores(idosoId: idoso.id),
        api.listarRefeicoes(idosoId: idoso.id),
        api.getResumoGlicemia(idosoId: idoso.id),
        api.buscarDicaDashboard(idosoId: idoso.id),
      ]);

      if (!mounted) return;
      setState(() {
        _resumo = _DashboardResumo.fromData(
          compromissos: results[0] as List<Map<String, dynamic>>,
          humores: results[1] as List<Map<String, dynamic>>,
          refeicoes: results[2] as List<RefeicaoResumo>,
          glicemia: results[3] as GlicemiaResumo,
          dica: results[4] as String,
        );
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel carregar o resumo.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: RefreshIndicator(
              color: const Color(0xFF38AFC0),
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 88),
                children: [
                  _DashboardHeader(onProfile: () => context.go('/perfil')),
                  const SizedBox(height: 10),
                  _Greeting(idoso: idoso),
                  const SizedBox(height: 10),
                  _IdosoHeroCard(
                    nome: idoso?.nome ?? 'Selecione uma ficha',
                    idade: idoso?.idade,
                    foto: idoso?.urlFoto,
                    onEdit: idoso == null
                        ? null
                        : () => context.go('/idosos/editar?from=dashboard'),
                  ),
                  const SizedBox(height: 14),
                  _MedicationAlert(
                    label: _resumo.proximoMedicamentoLabel,
                    time: _resumo.proximoMedicamentoHora,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Resumo do Dia',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  _SummaryCard(
                    icon: Icons.medication_outlined,
                    title: 'Medicamentos:',
                    value: _resumo.medicamentosLabel,
                    valueColor: const Color(0xFFFF8A00),
                    onTap: () => context.go('/medicamentos'),
                  ),
                  _SummaryCard(
                    icon: Icons.sentiment_satisfied_alt_rounded,
                    title: 'Humor:',
                    value: _resumo.humorLabel,
                    valueColor: const Color(0xFF168FA1),
                    onTap: () => context.go('/humor'),
                  ),
                  _SummaryCard(
                    icon: Icons.restaurant_rounded,
                    title: 'Ultima refeicao:',
                    value: _resumo.ultimaRefeicaoLabel,
                    valueColor: const Color(0xFF168FA1),
                    onTap: () => context.go('/alimentacao'),
                  ),
                  _SummaryCard(
                    icon: Icons.vaccines_outlined,
                    title: 'Insulina:',
                    value: _resumo.insulinaLabel,
                    valueColor: const Color(0xFF168FA1),
                    onTap: () => context.go('/glicemia'),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Proximo compromisso',
                    style: TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _NextAppointmentCard(
                    title: _resumo.proximoCompromissoTitulo,
                    details: _resumo.proximoCompromissoDetalhes,
                    onTap: () => context.go('/agenda'),
                  ),
                  const SizedBox(height: 10),
                  _TipCard(text: _resumo.dica),
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
    return Stack(
      alignment: Alignment.center,
      children: [
        const Text(
          'ello',
          style: TextStyle(
            color: Color(0xFF0E6F7E),
            fontSize: 42,
            fontWeight: FontWeight.w300,
            letterSpacing: 0,
            height: 1,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(99),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFD1F2F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF238FA1),
                size: 27,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.idoso});

  final IdosoResumo? idoso;

  @override
  Widget build(BuildContext context) {
    final name = idoso?.nome.split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greetingText(),
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 21,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          name == null
              ? 'Selecione uma ficha para comecar'
              : 'cuidando de $name hoje',
          style: const TextStyle(
            color: Color(0xFF333333),
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
    this.onEdit,
  });

  final String nome;
  final int? idade;
  final String? foto;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataImageBytes(foto);

    return Container(
      height: 126,
      padding: const EdgeInsets.fromLTRB(24, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xFF3CAAB6),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 3),
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
              padding: const EdgeInsets.only(right: 6),
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
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
              tooltip: 'Editar ficha',
              icon: const Icon(
                Icons.edit_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationAlert extends StatelessWidget {
  const _MedicationAlert({required this.label, required this.time});

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: _dashboardCardDecoration(color: const Color(0xFFFFF1F1)),
      child: Row(
        children: [
          const Icon(Icons.notifications_none_rounded,
              color: Color(0xFFE47A00), size: 31),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Proximo medicamento',
                  style: TextStyle(
                    color: Color(0xFFE47A00),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xFF555555), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              time,
              style: const TextStyle(
                color: Color(0xFFE47A00),
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
        color: Colors.white,
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
                      style: const TextStyle(
                        color: Color(0xFF444444),
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
      color: Colors.white,
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
                      style: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111111),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFCBEFF3),
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
                const Text(
                  'Dica do dia',
                  style: TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 12,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF073248)),
        ],
      ),
    );
  }
}

class _DashboardResumo {
  const _DashboardResumo({
    this.medicamentosLabel = 'em breve',
    this.proximoMedicamentoLabel = 'Cadastre medicamentos',
    this.proximoMedicamentoHora = '--:--',
    this.humorLabel = 'Sem registro',
    this.ultimaRefeicaoLabel = 'Sem registro',
    this.insulinaLabel = 'Sem registro',
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
    required String dica,
  }) {
    final nextAppointment = _nextAppointment(compromissos);
    final latestMeal = _latestMeal(refeicoes);
    final latestMood = _latestMood(humores);

    return _DashboardResumo(
      medicamentosLabel: '0 pendentes',
      proximoMedicamentoLabel: 'Nenhum pendente',
      proximoMedicamentoHora: '--:--',
      humorLabel: latestMood ?? 'Sem registro',
      ultimaRefeicaoLabel: latestMeal == null
          ? 'Sem registro'
          : 'Ha ${_timeAgo(_mealDateTime(latestMeal))}',
      insulinaLabel: glicemia.insulinaRecente == null
          ? 'Sem registro'
          : '${glicemia.insulinaRecente!.tipoInsulina} normal',
      proximoCompromissoTitulo: nextAppointment?.title ?? 'Nenhum compromisso',
      proximoCompromissoDetalhes:
          nextAppointment?.details ?? 'Agenda livre por enquanto',
      dica: dica,
    );
  }

  final String medicamentosLabel;
  final String proximoMedicamentoLabel;
  final String proximoMedicamentoHora;
  final String humorLabel;
  final String ultimaRefeicaoLabel;
  final String insulinaLabel;
  final String proximoCompromissoTitulo;
  final String proximoCompromissoDetalhes;
  final String dica;
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
        : 'Local nao informado',
  );
}

String? _latestMood(List<Map<String, dynamic>> humores) {
  if (humores.isEmpty) return null;
  final sorted = [...humores]..sort((a, b) {
      final aDate = _parseMoodDate(a);
      final bDate = _parseMoodDate(b);
      return bDate.compareTo(aDate);
    });
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

RefeicaoResumo? _latestMeal(List<RefeicaoResumo> refeicoes) {
  if (refeicoes.isEmpty) return null;
  final sorted = [...refeicoes]..sort((a, b) {
      final aDate = _mealDateTime(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = _mealDateTime(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
  return sorted.first;
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
