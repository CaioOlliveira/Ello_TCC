import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/navigation/module_navigation.dart';
import '../../../shared/widgets/app_page_header.dart';

enum _AgendaHistoryPeriod { dia, semanal, mes }

class AgendaHistoryPage extends ConsumerStatefulWidget {
  const AgendaHistoryPage({super.key});

  @override
  ConsumerState<AgendaHistoryPage> createState() => _AgendaHistoryPageState();
}

class _AgendaHistoryPageState extends ConsumerState<AgendaHistoryPage> {
  var _period = _AgendaHistoryPeriod.dia;
  var _loading = true;
  List<_AgendaHistoryItem> _items = [];

  static const _accent = Color(0xFF34A4B7);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final data = await ref
          .read(apiClientProvider)
          .listarHistoricoAgenda(idosoId: idoso.id);
      if (!mounted) return;
      setState(() {
        _items = data.map(_AgendaHistoryItem.fromJson).toList();
      });
    } on ApiException {
      if (!mounted) return;
      _ignoreBottomMessage();
    } catch (_) {
      if (!mounted) return;
      _ignoreBottomMessage();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_AgendaHistoryItem> get _filteredItems {
    final now = DateTime.now();
    final filtered = _items.where((item) {
      final date = item.createdAt;
      switch (_period) {
        case _AgendaHistoryPeriod.dia:
          return _isWithin(date, now, const Duration(hours: 24));
        case _AgendaHistoryPeriod.semanal:
          return _isWithin(date, now, const Duration(days: 7));
        case _AgendaHistoryPeriod.mes:
          return _isWithin(date, now, const Duration(days: 30));
      }
    }).toList();
    return filtered..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);
    final filteredItems = _filteredItems;

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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Column(
                  children: [
                    AppPageHeader(
                      title: 'Histórico da agenda',
                      onBack: () => context
                          .go(routeWithCurrentOrigin(context, '/agenda')),
                    ),
                    const SizedBox(height: 12),
                    _HistorySwitch(
                      value: _period,
                      onChanged: (value) => setState(() => _period = value),
                    ),
                    const SizedBox(height: 22),
                    Expanded(
                      child: idoso == null
                          ? const _HistoryMessage(
                              icon: Icons.person_search_rounded,
                              title: 'Escolha uma ficha',
                              message:
                                  'Selecione uma ficha para ver o histórico.',
                            )
                          : _loading
                              ? const Center(
                                  child:
                                      CircularProgressIndicator(color: _accent),
                                )
                              : filteredItems.isEmpty
                                  ? const _HistoryMessage(
                                      icon: Icons.history_rounded,
                                      title: 'Sem histórico',
                                      message:
                                          'Nenhuma alteração encontrada neste período.',
                                    )
                                  : RefreshIndicator(
                                      color: _accent,
                                      onRefresh: _load,
                                      child: ListView.separated(
                                        padding: const EdgeInsets.fromLTRB(
                                          0,
                                          0,
                                          0,
                                          8,
                                        ),
                                        itemCount: filteredItems.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 20),
                                        itemBuilder: (context, index) {
                                          return _HistoryCard(
                                            item: filteredItems[index],
                                          );
                                        },
                                      ),
                                    ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistorySwitch extends StatelessWidget {
  const _HistorySwitch({required this.value, required this.onChanged});

  final _AgendaHistoryPeriod value;
  final ValueChanged<_AgendaHistoryPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF93CBD4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _HistorySwitchOption(
            label: 'Dia',
            selected: value == _AgendaHistoryPeriod.dia,
            onTap: () => onChanged(_AgendaHistoryPeriod.dia),
          ),
          _HistorySwitchOption(
            label: 'Semanal',
            selected: value == _AgendaHistoryPeriod.semanal,
            onTap: () => onChanged(_AgendaHistoryPeriod.semanal),
          ),
          _HistorySwitchOption(
            label: 'Mês',
            selected: value == _AgendaHistoryPeriod.mes,
            onTap: () => onChanged(_AgendaHistoryPeriod.mes),
          ),
        ],
      ),
    );
  }
}

class _HistorySwitchOption extends StatelessWidget {
  const _HistorySwitchOption({
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
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF007A86) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF073248),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final _AgendaHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showHistoryDetails(context, item),
      child: Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
        decoration: BoxDecoration(
          color: adaptive(context, Colors.white, AppDarkColors.surface),
          borderRadius: BorderRadius.circular(13),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFC9EEF3),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: const Color(0xFF007A86), size: 31),
            ),
            const SizedBox(width: 9),
            SizedBox(
              height: 58,
              child: VerticalDivider(
                color: adaptive(
                    context, const Color(0xFFBFBFBF), AppDarkColors.border),
                thickness: 1,
                width: 1,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adaptive(
                          context, Colors.black, AppDarkColors.textPrimary),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF8A8A8A),
                          AppDarkColors.textSecondary),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            SizedBox(
              height: 58,
              child: VerticalDivider(
                color: adaptive(
                    context, const Color(0xFFBFBFBF), AppDarkColors.border),
                thickness: 1,
                width: 1,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 74,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.dateLabel,
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF8A8A8A),
                          AppDarkColors.textMuted),
                      fontSize: 12,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.timeLabel,
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF073248),
                          AppDarkColors.textPrimary),
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.badgeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        item.badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: item.badgeTextColor,
                          fontSize: 11,
                          height: 1,
                        ),
                      ),
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

void _showHistoryDetails(BuildContext context, _AgendaHistoryItem item) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor:
        adaptive(context, Colors.white, AppDarkColors.surfaceElevated),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: adaptive(
                        context, const Color(0xFFD0D0D0), AppDarkColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                item.title,
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF073248),
                      AppDarkColors.textPrimary),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.subtitle,
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF4F4F4F),
                      AppDarkColors.textSecondary),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailPill(label: item.badge, item: item),
                  _DetailPill(label: item.dateLabel, item: item),
                  _DetailPill(label: item.timeLabel, item: item),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label, required this.item});

  final String label;
  final _AgendaHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: item.badgeColor.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: item.badgeTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF34A4B7), size: 46),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adaptive(
                  context, const Color(0xFF073248), AppDarkColors.textPrimary),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adaptive(context, const Color(0xFF666666),
                  AppDarkColors.textSecondary),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaHistoryItem {
  const _AgendaHistoryItem({
    required this.action,
    required this.createdAt,
    required this.userName,
    required this.eventTitle,
    required this.eventDate,
    required this.eventTime,
    required this.status,
    required this.previousStatus,
    required this.dateChanged,
    required this.timeChanged,
  });

  factory _AgendaHistoryItem.fromJson(Map<String, dynamic> json) {
    final oldData = _parseMap(json['dados_anteriores']);
    final newData = _parseMap(json['dados_novos']);
    final data = newData.isNotEmpty ? newData : oldData;
    final createdAt = _parseHistoryDate(json['criado_em'] ?? json['criadoEm']);

    return _AgendaHistoryItem(
      action: json['acao']?.toString() ?? 'atualizar',
      createdAt: createdAt,
      userName: _firstText([
        json['usuario_nome'],
        data['criado_por_nome'],
        data['criadoPorNome'],
      ]),
      eventTitle: _firstText([
        data['titulo'],
        oldData['titulo'],
      ]),
      eventDate: _firstText([
        data['data_compromisso'],
        data['dataCompromisso'],
        oldData['data_compromisso'],
        oldData['dataCompromisso'],
      ]),
      eventTime: _firstText([
        data['hora_compromisso'],
        data['horaCompromisso'],
        oldData['hora_compromisso'],
        oldData['horaCompromisso'],
      ]),
      status: _firstText([
        data['status'],
        data['ocorrencia_status'],
        data['ocorrenciaStatus'],
      ]),
      previousStatus: _firstText([
        oldData['status'],
        oldData['ocorrencia_status'],
        oldData['ocorrenciaStatus'],
      ]),
      dateChanged: _fieldChanged(
        oldData['data_compromisso'] ?? oldData['dataCompromisso'],
        newData['data_compromisso'] ?? newData['dataCompromisso'],
      ),
      timeChanged: _fieldChanged(
        oldData['hora_compromisso'] ?? oldData['horaCompromisso'],
        newData['hora_compromisso'] ?? newData['horaCompromisso'],
      ),
    );
  }

  final String action;
  final DateTime createdAt;
  final String? userName;
  final String? eventTitle;
  final String? eventDate;
  final String? eventTime;
  final String? status;
  final String? previousStatus;
  final bool dateChanged;
  final bool timeChanged;

  String get title {
    final who = userName?.isNotEmpty == true ? userName! : 'Usuário';
    return '$who ${_actionVerb(this)} compromisso';
  }

  String get subtitle {
    final name = eventTitle?.isNotEmpty == true ? eventTitle! : 'Compromisso';
    return _actionSubtitle(this, name);
  }

  IconData get icon {
    switch (badge) {
      case 'Adicionou':
        return Icons.add_circle_outline_rounded;
      case 'Removeu':
        return Icons.delete_outline_rounded;
      case 'Editou':
      case 'Atualizou':
        return Icons.edit_outlined;
      case 'Concluiu':
        return Icons.check_circle_outline_rounded;
      case 'Reabriu':
        return Icons.restart_alt_rounded;
      case 'Cancelou':
        return Icons.event_busy_rounded;
      case 'Remarcou':
        return Icons.update_rounded;
      default:
        return Icons.calendar_month_outlined;
    }
  }

  String get dateLabel {
    final parsed = eventDate == null ? null : DateTime.tryParse(eventDate!);
    final date = parsed ?? createdAt;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String get timeLabel {
    if (eventTime != null && eventTime!.length >= 5) {
      return eventTime!.substring(0, 5);
    }
    return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  String get badge {
    final normalizedStatus = _normalizeStatus(status);
    final normalizedPrevious = _normalizeStatus(previousStatus);

    switch (action) {
      case 'criar':
        return 'Adicionou';
      case 'remover':
        return 'Removeu';
      case 'atualizar_ocorrencia':
        return _badgeForStatus(normalizedStatus);
      case 'atualizar':
        if (normalizedStatus != null &&
            normalizedStatus != normalizedPrevious &&
            normalizedStatus != 'agendado') {
          return _badgeForStatus(normalizedStatus);
        }
        if (normalizedStatus == 'agendado' &&
            normalizedPrevious != null &&
            normalizedPrevious != 'agendado') {
          return 'Reabriu';
        }
        if (dateChanged || timeChanged) return 'Remarcou';
        return 'Editou';
      default:
        return 'Editou';
    }
  }

  Color get badgeColor {
    switch (badge) {
      case 'Adicionou':
        return const Color(0xFF82F29A);
      case 'Editou':
        return const Color(0xFFFFE3A3);
      case 'Concluiu':
        return const Color(0xFF9BE7C7);
      case 'Reabriu':
        return const Color(0xFFB7E3FF);
      case 'Remarcou':
        return const Color(0xFFDDBBFF);
      case 'Atualizou':
        return const Color(0xFFAED7FF);
      case 'Cancelou':
      case 'Removeu':
        return const Color(0xFFFF8AA9);
      default:
        return const Color(0xFFFFE3A3);
    }
  }

  Color get badgeTextColor {
    switch (badge) {
      case 'Adicionou':
        return const Color(0xFF14883A);
      case 'Editou':
        return const Color(0xFFFF9800);
      case 'Concluiu':
        return const Color(0xFF087A45);
      case 'Reabriu':
        return const Color(0xFF0277BD);
      case 'Remarcou':
        return const Color(0xFF8E24AA);
      case 'Atualizou':
        return const Color(0xFF1565C0);
      case 'Cancelou':
      case 'Removeu':
        return const Color(0xFFFF1744);
      default:
        return const Color(0xFFFF9800);
    }
  }
}

Map<String, dynamic> _parseMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } on FormatException {
      return const {};
    }
  }
  return const {};
}

String? _firstText(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty && text != 'null') return text;
  }
  return null;
}

bool _fieldChanged(dynamic previous, dynamic current) {
  final oldText = previous?.toString().trim();
  final newText = current?.toString().trim();
  if (oldText == null || newText == null) return false;
  if (oldText.isEmpty || newText.isEmpty) return false;
  return oldText != newText;
}

DateTime _parseHistoryDate(dynamic value) {
  final parsed = value == null ? null : DateTime.tryParse(value.toString());
  return parsed?.toLocal() ?? DateTime.now();
}

bool _isWithin(DateTime date, DateTime now, Duration range) {
  final difference = now.difference(date);
  return !difference.isNegative && difference <= range;
}

String? _normalizeStatus(String? value) {
  final status = value?.toLowerCase().trim();
  if (status == null || status.isEmpty) return null;
  return status;
}

String _badgeForStatus(String? status) {
  switch (status) {
    case 'concluido':
    case 'concluida':
      return 'Concluiu';
    case 'cancelado':
    case 'cancelada':
      return 'Cancelou';
    case 'agendado':
    case 'agendada':
      return 'Reabriu';
    case 'remarcado':
    case 'remarcada':
      return 'Remarcou';
    default:
      return 'Atualizou';
  }
}

String _actionVerb(_AgendaHistoryItem item) {
  switch (item.badge) {
    case 'Adicionou':
      return 'adicionou';
    case 'Removeu':
      return 'removeu';
    case 'Concluiu':
      return 'concluiu';
    case 'Cancelou':
      return 'cancelou';
    case 'Reabriu':
      return 'reabriu';
    case 'Remarcou':
      return 'remarcou';
    case 'Atualizou':
      return 'atualizou';
  }

  switch (item.action) {
    case 'criar':
      return 'adicionou';
    case 'atualizar':
      return 'editou';
    case 'remover':
      return 'removeu';
    case 'atualizar_ocorrencia':
      return 'editou';
    default:
      return 'editou';
  }
}

String _actionSubtitle(_AgendaHistoryItem item, String title) {
  switch (item.badge) {
    case 'Concluiu':
      return 'Compromisso concluido: $title';
    case 'Cancelou':
      return 'Compromisso cancelado: $title';
    case 'Reabriu':
      return 'Compromisso reaberto: $title';
    case 'Remarcou':
      return 'Novo horário de $title';
    case 'Atualizou':
      return 'Compromisso atualizado: $title';
  }

  switch (item.action) {
    case 'criar':
      return title;
    case 'atualizar':
      return title;
    case 'remover':
      return title;
    case 'atualizar_ocorrencia':
      return 'Status de $title';
    default:
      return title;
  }
}

void _ignoreBottomMessage() {}
