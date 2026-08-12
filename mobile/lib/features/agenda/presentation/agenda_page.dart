import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/staggered_entry.dart';
import 'agenda_form_page.dart';
import 'agenda_models.dart';
import 'agenda_utils.dart';

enum _AgendaView { dia, mes }

class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  final List<String> _customTags = [];
  var _view = _AgendaView.dia;
  var _selectedDay = DateTime.now();
  var _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  var _loading = true;
  var _saving = false;
  List<AgendaCompromisso> _items = [];

  static const _accent = Color(0xFF34A4B7);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final data = await ref
          .read(apiClientProvider)
          .listarCompromissos(idosoId: idoso.id);
      if (!mounted) return;
      final items = data.map(AgendaCompromisso.fromJson).toList();
      setState(() {
        _items = items;
        for (final item in items) {
          if (!agendaBaseTags.contains(item.tag) &&
              !_customTags.contains(item.tag)) {
            _customTags.add(item.tag);
          }
        }
      });
      ref
          .read(apiClientProvider)
          .listarHistoricoAgenda(idosoId: idoso.id)
          .catchError((_) => const <Map<String, dynamic>>[]);
    } on ApiException {
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({AgendaCompromisso? item}) async {
    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null) {
      context.go('/idosos');
      return;
    }

    final result = await Navigator.of(context).push<AgendaFormResult>(
      MaterialPageRoute(
        builder: (_) => AgendaFormPage(
          initial: item,
          selectedDay: _selectedDay,
          tags: [...agendaBaseTags, ..._customTags],
        ),
      ),
    );

    if (result == null) return;
    for (final tag in result.tags) {
      if (!agendaBaseTags.contains(tag) && !_customTags.contains(tag)) {
        _customTags.add(tag);
      }
    }
    setState(() {
      _selectedDay = result.data.dataHora;
      _visibleMonth = DateTime(
        result.data.dataHora.year,
        result.data.dataHora.month,
      );
    });
    await _save(result.data, item: item);
  }

  Future<void> _save(
    AgendaCompromissoFormData data, {
    AgendaCompromisso? item,
  }) async {
    final idoso = ref.read(selectedIdosoProvider);
    final usuario = ref.read(authSessionProvider);
    if (idoso == null) return;

    final previousItems = List<AgendaCompromisso>.from(_items);
    final localId =
        item?.id ?? 'local-${DateTime.now().microsecondsSinceEpoch}';
    final localItem = _itemFromFormData(
      data,
      id: localId,
      criadoPorId: usuario?.id,
      criadoPorNome: usuario?.nome,
    );
    final payload = data.toPayload(
      idosoId: idoso.id,
      criadoPorId: usuario?.id,
    );

    setState(() {
      _saving = true;
      _upsertItem(localItem, replaceId: item?.id);
    });

    try {
      Map<String, dynamic> response;
      if (item == null) {
        response =
            await ref.read(apiClientProvider).criarCompromisso(data: payload);
      } else {
        response = await ref
            .read(apiClientProvider)
            .atualizarCompromisso(id: item.id, data: payload);
      }
      if (!mounted) return;
      final serverItem = _itemFromResponse(response, fallback: localItem);
      if (serverItem != null) {
        setState(() => _upsertItem(serverItem, replaceId: localId));
      }
    } on ApiException {
      if (!mounted) return;
      setState(() => _items = previousItems);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previousItems);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(AgendaCompromisso item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir compromisso'),
        content: Text(
          'Deseja excluir "${item.titulo}"? Se for recorrente, todos os proximos dias tambem serao removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final previousItems = List<AgendaCompromisso>.from(_items);
    setState(() {
      _saving = true;
      _items = _items.where((current) => current.id != item.id).toList();
    });
    try {
      await ref.read(apiClientProvider).removerCompromisso(id: item.id);
      if (!mounted) return;
    } on ApiException {
      if (!mounted) return;
      setState(() => _items = previousItems);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previousItems);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleStatus(AgendaCompromisso item) async {
    final nextStatus = item.status == 'concluido' ? 'agendado' : 'concluido';
    final occurrenceDate = item.dataOcorrencia ?? _selectedDay;
    final occurrenceKey = formatAgendaIsoDate(occurrenceDate);
    final sourceItem = _items.firstWhere(
      (current) => current.id == item.id,
      orElse: () => item,
    );
    final previousItems = List<AgendaCompromisso>.from(_items);
    final optimisticStatuses = Map<String, String>.from(
      sourceItem.ocorrenciasStatus,
    );
    if (nextStatus == 'agendado') {
      optimisticStatuses.remove(occurrenceKey);
    } else {
      optimisticStatuses[occurrenceKey] = nextStatus;
    }

    setState(() {
      _saving = true;
      _upsertItem(sourceItem.copyWith(ocorrenciasStatus: optimisticStatuses));
    });

    try {
      final response =
          await ref.read(apiClientProvider).atualizarOcorrenciaCompromisso(
                id: item.id,
                dataOcorrencia: occurrenceKey,
                status: nextStatus,
              );
      if (!mounted) return;
      final serverItem = _itemFromResponse(
        response,
        fallback: sourceItem.copyWith(ocorrenciasStatus: optimisticStatuses),
      );
      if (serverItem != null) {
        setState(() => _upsertItem(serverItem));
      }
    } on ApiException {
      if (!mounted) return;
      setState(() => _items = previousItems);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previousItems);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel(AgendaCompromisso item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar compromisso'),
        content: Text(
          'Deseja cancelar "${item.titulo}"? Se for recorrente, ele deixara de aparecer nos proximos dias.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar compromisso'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateStatus(item, 'cancelado');
    }
  }

  Future<void> _updateStatus(AgendaCompromisso item, String nextStatus) async {
    final previousItems = List<AgendaCompromisso>.from(_items);
    setState(() {
      _saving = true;
      _upsertItem(item.copyWith(status: nextStatus));
    });
    try {
      final response = await ref.read(apiClientProvider).atualizarCompromisso(
        id: item.id,
        data: {'status': nextStatus},
      );
      if (!mounted) return;
      final serverItem = _itemFromResponse(
        response,
        fallback: item.copyWith(status: nextStatus),
      );
      if (serverItem != null) {
        setState(() => _upsertItem(serverItem));
      }
    } on ApiException {
      if (!mounted) return;
      setState(() => _items = previousItems);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previousItems);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  AgendaCompromisso _itemFromFormData(
    AgendaCompromissoFormData data, {
    required String id,
    String? criadoPorId,
    String? criadoPorNome,
  }) {
    return AgendaCompromisso(
      id: id,
      titulo: data.titulo,
      tag: data.tag,
      dataHora: data.dataHora,
      local: data.local,
      frequencia: data.frequencia,
      observacoes: data.observacoes,
      ativarLembrete: data.ativarLembrete,
      antecedenciaLembreteMinutos: data.antecedenciaLembreteMinutos ?? 30,
      status: data.status,
      criadoPorId: criadoPorId,
      criadoPorNome: criadoPorNome,
    );
  }

  AgendaCompromisso? _itemFromResponse(
    Map<String, dynamic> response, {
    AgendaCompromisso? fallback,
  }) {
    final data = response['dados'] ?? response;
    if (data is Map<String, dynamic>) {
      final item = AgendaCompromisso.fromJson(data);
      final hasTag = data['tags'] != null ||
          data['tipo_evento'] != null ||
          data['tipoEvento'] != null;
      if (!hasTag && fallback != null) {
        return item.copyWith(tag: fallback.tag);
      }
      return item;
    }
    return null;
  }

  void _upsertItem(AgendaCompromisso item, {String? replaceId}) {
    final index = _items.indexWhere(
      (current) => current.id == (replaceId ?? item.id),
    );
    if (index == -1) {
      _items = [..._items, item]..sort(_compareAgendaItems);
      return;
    }

    final updated = [..._items];
    updated[index] = item;
    _items = updated..sort(_compareAgendaItems);
  }

  int _compareAgendaItems(AgendaCompromisso a, AgendaCompromisso b) {
    return a.dataHora.compareTo(b.dataHora);
  }

  List<AgendaCompromisso> get _itemsForSelectedDay {
    final items = _items
        .where(
          (item) => agendaItemOccursOnDay(
            start: item.dataHora,
            frequencia: item.frequencia,
            status: item.status,
            day: _selectedDay,
          ),
        )
        .map(
          (item) => item.copyWith(
            status: item.statusNoDia(_selectedDay),
            dataOcorrencia: _selectedDay,
          ),
        );
    return items.toList()..sort(_compareAgendaTimes);
  }

  int _compareAgendaTimes(AgendaCompromisso a, AgendaCompromisso b) {
    final aMinutes = (a.dataHora.hour * 60) + a.dataHora.minute;
    final bMinutes = (b.dataHora.hour * 60) + b.dataHora.minute;
    return aMinutes.compareTo(bMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);

    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFAFAFA), AppDarkColors.bg),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: idoso == null
          ? null
          : FloatingActionButton(
              heroTag: 'agenda_add',
              onPressed: _saving ? null : () => _openForm(),
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_rounded, size: 36),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton(
                  onPressed: () => context.go('/agenda/historico'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: adaptive(context, const Color(0xFF222222),
                        AppDarkColors.textPrimary),
                    side: const BorderSide(
                      color: Color(0xFF1696AA),
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Ver Historico'),
                ),
              ),
            ),
          ),
        ),
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDarkMode(context)
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  children: [
                    _Header(onBack: () => context.go('/monitoramento')),
                    const SizedBox(height: 14),
                    _ViewSwitch(
                      value: _view,
                      onChanged: (value) => setState(() => _view = value),
                    ),
                    const SizedBox(height: 12),
                    if (idoso == null)
                      const Expanded(
                        child: _AgendaMessage(
                          icon: Icons.person_search_rounded,
                          title: 'Escolha uma ficha',
                          message: 'Selecione uma ficha para abrir a agenda.',
                        ),
                      )
                    else if (_loading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(color: _accent),
                        ),
                      )
                    else
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.03),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: _view == _AgendaView.dia
                              ? _DayView(
                                  selectedDay: _selectedDay,
                                  items: _itemsForSelectedDay,
                                  onDaySelected: (day) {
                                    setState(() {
                                      _selectedDay = day;
                                      _visibleMonth =
                                          DateTime(day.year, day.month);
                                    });
                                  },
                                  onEdit: (item) => _openForm(item: item),
                                  onDelete: _delete,
                                  onStatusChanged: _toggleStatus,
                                  onCancel: _cancel,
                                )
                              : _MonthView(
                                  month: _visibleMonth,
                                  selectedDay: _selectedDay,
                                  items: _items,
                                  onPrevious: () => setState(() {
                                    _visibleMonth = DateTime(
                                      _visibleMonth.year,
                                      _visibleMonth.month - 1,
                                    );
                                  }),
                                  onNext: () => setState(() {
                                    _visibleMonth = DateTime(
                                      _visibleMonth.year,
                                      _visibleMonth.month + 1,
                                    );
                                  }),
                                  onDaySelected: (day) => setState(() {
                                    _selectedDay = day;
                                    _view = _AgendaView.dia;
                                  }),
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

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(title: 'Agenda', onBack: onBack);
  }
}

class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.value, required this.onChanged});

  final _AgendaView value;
  final ValueChanged<_AgendaView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      decoration: BoxDecoration(
        color: const Color(0xFF34A4B7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _SwitchOption(
            label: 'Dia',
            selected: value == _AgendaView.dia,
            onTap: () => onChanged(_AgendaView.dia),
          ),
          _SwitchOption(
            label: 'Mes',
            selected: value == _AgendaView.mes,
            onTap: () => onChanged(_AgendaView.mes),
          ),
        ],
      ),
    );
  }
}

class _SwitchOption extends StatelessWidget {
  const _SwitchOption({
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
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF003B4F) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({
    required this.selectedDay,
    required this.items,
    required this.onDaySelected,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
    required this.onCancel,
  });

  final DateTime selectedDay;
  final List<AgendaCompromisso> items;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<AgendaCompromisso> onEdit;
  final ValueChanged<AgendaCompromisso> onDelete;
  final ValueChanged<AgendaCompromisso> onStatusChanged;
  final ValueChanged<AgendaCompromisso> onCancel;

  @override
  Widget build(BuildContext context) {
    final start = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final days = List.generate(5, (index) => start.add(Duration(days: index)));

    return Column(
      children: [
        SizedBox(
          height: 50,
          child: Row(
            children: [
              _DayNavigationButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => onDaySelected(
                  selectedDay.subtract(const Duration(days: 1)),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final day in days)
                      _DayChip(
                        day: day,
                        selected: sameAgendaDay(day, selectedDay),
                        onTap: () => onDaySelected(day),
                      ),
                  ],
                ),
              ),
              _DayNavigationButton(
                icon: Icons.chevron_right_rounded,
                onTap: () =>
                    onDaySelected(selectedDay.add(const Duration(days: 1))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? const _AgendaMessage(
                  icon: Icons.event_available_rounded,
                  title: 'Dia livre',
                  message: 'Adicione um compromisso pelo botao +.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(6, 0, 0, 78),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 11),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return StaggeredEntry(
                      index: index,
                      child: _TimelineItem(
                        item: item,
                        onEdit: () => onEdit(item),
                        onDelete: () => onDelete(item),
                        onStatusChanged: () => onStatusChanged(item),
                        onCancel: () => onCancel(item),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DayNavigationButton extends StatelessWidget {
  const _DayNavigationButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 42,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        splashRadius: 20,
        icon: Icon(icon, color: const Color(0xFF34A4B7), size: 28),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 42,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF34A4B7) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '${day.day}'.padLeft(2, '0'),
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF34A4B7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              agendaWeekdayShort(day.weekday),
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF34A4B7),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
    required this.onCancel,
  });

  final AgendaCompromisso item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStatusChanged;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final done = item.status == 'concluido';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  formatAgendaTime(item.dataHora),
                  style: const TextStyle(
                    color: Color(0xFF008CAA),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                const Expanded(
                  child: VerticalDivider(
                    color: Color(0xFF79C8D6),
                    thickness: 1.5,
                    width: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.fromLTRB(9, 7, 7, 7),
              decoration: BoxDecoration(
                color: adaptive(context, Colors.white, AppDarkColors.surface),
                border: Border.all(color: const Color(0xFF4DB6C8)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: Checkbox(
                          value: done,
                          onChanged: (_) => onStatusChanged(),
                          activeColor: const Color(0xFF34A4B7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: adaptive(context, Colors.black,
                                AppDarkColors.textPrimary),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 0.95,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      _TagPill(label: item.tag),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert_rounded, size: 20),
                        onSelected: (value) {
                          if (value == 'editar') onEdit();
                          if (value == 'status') onStatusChanged();
                          if (value == 'cancelar') onCancel();
                          if (value == 'excluir') onDelete();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'editar',
                            child: Text('Editar'),
                          ),
                          PopupMenuItem(
                            value: 'status',
                            child: Text(
                              done ? 'Reabrir' : 'Concluir',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'cancelar',
                            child: Text('Cancelar'),
                          ),
                          const PopupMenuItem(
                            value: 'excluir',
                            child: Text('Excluir'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.local.isEmpty ? 'Local nao informado' : item.local,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF666666),
                          AppDarkColors.textSecondary),
                      fontSize: 10,
                    ),
                  ),
                  if (item.observacoes.isNotEmpty) ...[
                    const SizedBox(height: 13),
                    Text(
                      item.observacoes,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF073248),
                            AppDarkColors.textPrimary),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF1995A8),
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.criadoPorNome?.isNotEmpty == true
                              ? 'Adicionado por ${item.criadoPorNome}'
                              : 'Cuidador nao informado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: adaptive(context, const Color(0xFF4F6B72),
                                AppDarkColors.textSecondary),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
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

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = agendaTagColor(label);
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFF6C3B16), fontSize: 9),
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.month,
    required this.selectedDay,
    required this.items,
    required this.onPrevious,
    required this.onNext,
    required this.onDaySelected,
  });

  final DateTime month;
  final DateTime selectedDay;
  final List<AgendaCompromisso> items;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final leading = first.weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return ListView(
      padding: const EdgeInsets.fromLTRB(7, 12, 7, 78),
      children: [
        Row(
          children: [
            Text(
              agendaMonthName(month.month),
              style: TextStyle(
                color:
                    adaptive(context, Colors.black, AppDarkColors.textPrimary),
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${month.year}',
              style: TextStyle(
                color: adaptive(context, const Color(0xFF555555),
                    AppDarkColors.textSecondary),
                fontSize: 21,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            _CalendarWeekday('Dom'),
            _CalendarWeekday('Seg'),
            _CalendarWeekday('Ter'),
            _CalendarWeekday('Qua'),
            _CalendarWeekday('Qui'),
            _CalendarWeekday('Sex'),
            _CalendarWeekday('Sab'),
          ],
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < rows; row++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: _CalendarCell(
                    dayNumber:
                        dayForCalendarCell(row, column, leading, daysInMonth),
                    month: month,
                    selectedDay: selectedDay,
                    items: items,
                    onDaySelected: onDaySelected,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _CalendarWeekday extends StatelessWidget {
  const _CalendarWeekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: adaptive(
              context, const Color(0xFF4F4F4F), AppDarkColors.textSecondary),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.dayNumber,
    required this.month,
    required this.selectedDay,
    required this.items,
    required this.onDaySelected,
  });

  final int? dayNumber;
  final DateTime month;
  final DateTime selectedDay;
  final List<AgendaCompromisso> items;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    if (dayNumber == null) {
      return const SizedBox(height: 106);
    }

    final day = DateTime(month.year, month.month, dayNumber!);
    final dayItems = items
        .where(
          (item) => agendaItemOccursOnDay(
            start: item.dataHora,
            frequencia: item.frequencia,
            status: item.status,
            day: day,
          ),
        )
        .take(2)
        .toList();
    final selected = sameAgendaDay(day, selectedDay);
    final totalItems = items
        .where(
          (item) => agendaItemOccursOnDay(
            start: item.dataHora,
            frequencia: item.frequencia,
            status: item.status,
            day: day,
          ),
        )
        .length;

    return InkWell(
      onTap: () => onDaySelected(day),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 106,
        padding: const EdgeInsets.fromLTRB(2, 5, 2, 3),
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF003B4F) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$dayNumber',
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : adaptive(
                          context, Colors.black, AppDarkColors.textPrimary),
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (final item in dayItems)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: agendaTagColor(item.tag),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  item.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF073248),
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (totalItems > 2)
              Text(
                '+${totalItems - 2} mais',
                style: const TextStyle(
                  color: Color(0xFF1696AA),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AgendaMessage extends StatelessWidget {
  const _AgendaMessage({
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
