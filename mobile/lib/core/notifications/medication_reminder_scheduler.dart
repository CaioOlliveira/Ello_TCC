import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import 'local_notification_service.dart';

/// Mantém os lembretes de medicamentos no agendador do sistema operacional.
///
/// O agendamento é recalculado sempre que os dados do idoso são carregados,
/// para que ele não dependa de a pessoa abrir a tela de medicamentos.
class MedicationReminderScheduler {
  static const _disabledKey = 'ello_disabled_medication_reminders';
  static const _leadMinutesPrefix = 'ello_medication_reminder_lead_minutes';
  static const _lookaheadDays = 14;
  static const _defaultLeadMinutes = 5;
  static const _weekdays = [
    'Domingo',
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
  ];

  static String groupFor(String idosoId) => 'medicamentos:$idosoId';

  static Future<bool> isEnabled(String medicamentoId) async {
    if (medicamentoId.isEmpty) return false;
    return !(await _disabledIds()).contains(medicamentoId);
  }

  static Future<void> setEnabled(String medicamentoId, bool enabled) async {
    if (medicamentoId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final disabled = await _disabledIds();
    if (enabled) {
      disabled.remove(medicamentoId);
    } else {
      disabled.add(medicamentoId);
    }

    final ordered = disabled.toList()..sort();
    await prefs.setStringList(_disabledKey, ordered);
  }

  static Future<int> getLeadMinutes(String medicamentoId) async {
    if (medicamentoId.isEmpty) return _defaultLeadMinutes;

    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_leadMinutesKey(medicamentoId));
    return _normalizeLeadMinutes(value);
  }

  static Future<void> setLeadMinutes(
    String medicamentoId,
    int minutes,
  ) async {
    if (medicamentoId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeLeadMinutes(minutes);
    await prefs.setInt(_leadMinutesKey(medicamentoId), normalized);
  }

  static Future<void> sync({
    required String idosoId,
    required MedicamentosResumo resumo,
  }) async {
    if (idosoId.isEmpty) return;

    final disabled = await _disabledIds();
    final requests = <LocalNotificationRequest>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final medicamento in resumo.medicamentos) {
      if (medicamento.id.isEmpty || disabled.contains(medicamento.id)) {
        continue;
      }

      final leadMinutes = await getLeadMinutes(medicamento.id);
      final lead = Duration(minutes: leadMinutes);
      for (final horario in medicamento.horarios) {
        for (var offset = 0; offset <= _lookaheadDays; offset++) {
          final date = today.add(Duration(days: offset));
          if (!_isActiveOn(medicamento, date) ||
              !_timeAppliesOn(horario, medicamento, date)) {
            continue;
          }

          final doseAt = _atTimeOnDate(horario.horario, date);
          if (doseAt == null) continue;

          final scheduledAt = doseAt.subtract(lead);
          if (!scheduledAt.isAfter(now)) continue;

          requests.add(
            LocalNotificationRequest(
              id: stableNotificationId(
                'med:$idosoId:${medicamento.id}:${doseAt.toIso8601String()}',
              ),
              scheduledAt: scheduledAt,
              title: 'Remédio em ${_leadLabel(leadMinutes)}',
              body: '${medicamento.nome} às ${horario.horario}',
              payload: 'medicamento:${medicamento.id}',
            ),
          );
        }
      }
    }

    await LocalNotificationService.instance.replaceGroup(
      groupFor(idosoId),
      requests,
    );
  }

  static Future<Set<String>> _disabledIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_disabledKey) ?? const <String>[])
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static String _leadMinutesKey(String medicamentoId) {
    return '$_leadMinutesPrefix:$medicamentoId';
  }

  static int _normalizeLeadMinutes(int? minutes) {
    return switch (minutes) {
      5 || 10 || 30 || 60 || 120 || 1440 => minutes!,
      _ => _defaultLeadMinutes,
    };
  }

  static String _leadLabel(int minutes) {
    return switch (minutes) {
      60 => '1 hora',
      120 => '2 horas',
      1440 => '1 dia',
      _ => '$minutes minutos',
    };
  }

  static bool _isActiveOn(MedicamentoResumo medicamento, DateTime date) {
    final day = _dateOnly(date)!;
    final start = _dateOnly(medicamento.dataInicio);
    final end = _dateOnly(medicamento.dataFim);
    if (start != null && day.isBefore(start)) return false;
    if (end != null && day.isAfter(end)) return false;
    return true;
  }

  static bool _timeAppliesOn(
    MedicamentoHorario horario,
    MedicamentoResumo medicamento,
    DateTime date,
  ) {
    if (horario.frequenciaTipo == 'semanal' && horario.diasSemana.isNotEmpty) {
      final weekday = _weekdays[date.weekday % 7].toLowerCase();
      return horario.diasSemana
          .any((item) => item.trim().toLowerCase() == weekday);
    }

    if (horario.frequenciaTipo == 'alternado') {
      final start = _dateOnly(medicamento.dataInicio);
      if (start == null) return true;
      final difference = _dateOnly(date)!.difference(start).inDays;
      return difference >= 0 && difference.isEven;
    }

    return true;
  }

  static DateTime? _atTimeOnDate(String horario, DateTime date) {
    final parts = horario.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static DateTime? _dateOnly(DateTime? date) {
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day);
  }
}
