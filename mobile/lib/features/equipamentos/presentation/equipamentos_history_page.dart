import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_exception.dart';

enum _EquipamentosHistoryPeriod { dia, semanal, mes }

class EquipamentosHistoryPage extends ConsumerStatefulWidget {
  const EquipamentosHistoryPage({super.key});

  @override
  ConsumerState<EquipamentosHistoryPage> createState() =>
      _EquipamentosHistoryPageState();
}

class _EquipamentosHistoryPageState
    extends ConsumerState<EquipamentosHistoryPage> {
  var _period = _EquipamentosHistoryPeriod.dia;
  var _loading = true;
  List<_EquipmentHistoryItem> _items = [];

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
          .listarHistoricoEquipamentos(idosoId: idoso.id);
      if (!mounted) return;
      setState(() {
        _items = data.map(_EquipmentHistoryItem.fromJson).toList();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel carregar o historico.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_EquipmentHistoryItem> get _filteredItems {
    final now = DateTime.now();
    final filtered = _items.where((item) {
      final date = item.createdAt;
      switch (_period) {
        case _EquipamentosHistoryPeriod.dia:
          return _isWithin(date, now, const Duration(hours: 24));
        case _EquipamentosHistoryPeriod.semanal:
          return _isWithin(date, now, const Duration(days: 7));
        case _EquipamentosHistoryPeriod.mes:
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
      backgroundColor: const Color(0xFFFAFAFA),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Column(
                  children: [
                    _HistoryBackButton(
                      onBack: () => context.go('/equipamentos'),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'ello',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF0E6F7E),
                        fontSize: 42,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 19),
                    const Text(
                      'Historico dos equipamentos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF073248),
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
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
                                  'Selecione uma ficha para ver o historico.',
                            )
                          : _loading
                              ? const Center(
                                  child:
                                      CircularProgressIndicator(color: _accent),
                                )
                              : filteredItems.isEmpty
                                  ? const _HistoryMessage(
                                      icon: Icons.history_rounded,
                                      title: 'Sem historico',
                                      message:
                                          'Nenhuma alteracao encontrada neste periodo.',
                                    )
                                  : RefreshIndicator(
                                      color: _accent,
                                      onRefresh: _load,
                                      child: ListView.separated(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        itemCount: filteredItems.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 20),
                                        itemBuilder: (context, index) =>
                                            _HistoryCard(
                                          item: filteredItems[index],
                                        ),
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

class _HistoryBackButton extends StatelessWidget {
  const _HistoryBackButton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onBack,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_left_rounded, color: Color(0xFF1995A8)),
              Text('Voltar', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistorySwitch extends StatelessWidget {
  const _HistorySwitch({required this.value, required this.onChanged});

  final _EquipamentosHistoryPeriod value;
  final ValueChanged<_EquipamentosHistoryPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF93CBD4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _HistorySwitchOption(
            label: 'Dia',
            selected: value == _EquipamentosHistoryPeriod.dia,
            onTap: () => onChanged(_EquipamentosHistoryPeriod.dia),
          ),
          _HistorySwitchOption(
            label: 'Semanal',
            selected: value == _EquipamentosHistoryPeriod.semanal,
            onTap: () => onChanged(_EquipamentosHistoryPeriod.semanal),
          ),
          _HistorySwitchOption(
            label: 'Mes',
            selected: value == _EquipamentosHistoryPeriod.mes,
            onTap: () => onChanged(_EquipamentosHistoryPeriod.mes),
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

  final _EquipmentHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showHistoryDetails(context, item),
      child: Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
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
            const SizedBox(
              height: 58,
              child: VerticalDivider(
                color: Color(0xFFBFBFBF),
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
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            const SizedBox(
              height: 58,
              child: VerticalDivider(
                color: Color(0xFFBFBFBF),
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
                    style: const TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 12,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.timeLabel,
                    style: const TextStyle(
                      color: Color(0xFF073248),
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

void _showHistoryDetails(BuildContext context, _EquipmentHistoryItem item) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
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
                    color: const Color(0xFFD0D0D0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                item.title,
                style: const TextStyle(
                  color: Color(0xFF073248),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.subtitle,
                style: const TextStyle(
                  color: Color(0xFF4F4F4F),
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
  final _EquipmentHistoryItem item;

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
            style: const TextStyle(
              color: Color(0xFF073248),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EquipmentHistoryItem {
  const _EquipmentHistoryItem({
    required this.action,
    required this.entityType,
    required this.createdAt,
    required this.userName,
    required this.equipmentName,
  });

  factory _EquipmentHistoryItem.fromJson(Map<String, dynamic> json) {
    final oldData = _parseMap(json['dados_anteriores']);
    final newData = _parseMap(json['dados_novos']);
    final data = newData.isNotEmpty ? newData : oldData;
    final createdAt = _parseHistoryDate(json['criado_em'] ?? json['criadoEm']);

    return _EquipmentHistoryItem(
      action: json['acao']?.toString() ?? 'atualizar',
      entityType: json['tipo_entidade']?.toString() ?? 'equipamentos',
      createdAt: createdAt,
      userName: _firstText([
        json['usuario_nome'],
        data['registrado_por_nome'],
        data['criado_por_nome'],
      ]),
      equipmentName: _firstText([
        json['equipamento_nome'],
        data['nome'],
        oldData['nome'],
        data['equipamento_nome'],
        oldData['equipamento_nome'],
        data['descricao_servico'],
        data['descricaoServico'],
      ]),
    );
  }

  final String action;
  final String entityType;
  final DateTime createdAt;
  final String? userName;
  final String? equipmentName;

  String get title {
    final who = userName?.isNotEmpty == true ? userName! : 'Usuario';
    return '$who ${_verb(action, entityType)}';
  }

  String get subtitle {
    if (equipmentName?.isNotEmpty == true) return equipmentName!;
    return entityType == 'manutencoes_equipamentos'
        ? 'Manutencao registrada'
        : 'Equipamento';
  }

  IconData get icon {
    switch (badge) {
      case 'Removeu':
        return Icons.delete_outline_rounded;
      case 'Editou':
      case 'Atualizou':
        return Icons.edit_outlined;
      case 'Registrou':
        return Icons.build_circle_outlined;
      case 'Verificou':
        return Icons.verified_outlined;
      default:
        return Icons.accessible_rounded;
    }
  }

  String get dateLabel {
    return '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
  }

  String get timeLabel {
    return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  String get badge {
    if (entityType == 'manutencoes_equipamentos') {
      if (action == 'remover') return 'Removeu';
      if (action == 'criar' || action == 'registrar_manutencao') {
        return 'Registrou';
      }
      return 'Atualizou';
    }
    if (action == 'remover') return 'Removeu';
    if (action == 'criar') return 'Adicionou';
    if (_normalizeText(action).contains('verific')) return 'Verificou';
    return 'Editou';
  }

  Color get badgeColor {
    switch (badge) {
      case 'Adicionou':
        return const Color(0xFF82F29A);
      case 'Editou':
      case 'Atualizou':
        return const Color(0xFFDDBBFF);
      case 'Registrou':
        return const Color(0xFFAED7FF);
      case 'Verificou':
        return const Color(0xFF9BE7C7);
      case 'Removeu':
        return const Color(0xFFFF8AA9);
      default:
        return const Color(0xFFDDBBFF);
    }
  }

  Color get badgeTextColor {
    switch (badge) {
      case 'Adicionou':
        return const Color(0xFF14883A);
      case 'Editou':
      case 'Atualizou':
        return const Color(0xFF8E24AA);
      case 'Registrou':
        return const Color(0xFF1565C0);
      case 'Verificou':
        return const Color(0xFF087A45);
      case 'Removeu':
        return const Color(0xFFFF1744);
      default:
        return const Color(0xFF8E24AA);
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

DateTime _parseHistoryDate(dynamic value) {
  final parsed = value == null ? null : DateTime.tryParse(value.toString());
  return parsed?.toLocal() ?? DateTime.now();
}

String _verb(String action, String entityType) {
  final normalizedAction = _normalizeText(action);
  switch (action) {
    case 'criar':
    case 'registrar_manutencao':
      return entityType == 'manutencoes_equipamentos'
          ? 'registrou manutencao'
          : 'adicionou equipamento';
    case 'remover':
      return entityType == 'manutencoes_equipamentos'
          ? 'removeu manutencao'
          : 'removeu equipamento';
    default:
      if (normalizedAction.contains('verific')) return 'verificou equipamento';
      return entityType == 'manutencoes_equipamentos'
          ? 'atualizou manutencao'
          : 'editou equipamento';
  }
}

String _normalizeText(String value) {
  return value.toLowerCase().trim();
}

bool _isWithin(DateTime date, DateTime now, Duration range) {
  final difference = now.difference(date);
  return !difference.isNegative && difference <= range;
}
