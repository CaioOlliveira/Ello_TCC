import '../../../core/notifications/local_notification_service.dart';
import 'agenda_models.dart';
import 'agenda_utils.dart';

/// Agenda os lembretes dos próximos dias diretamente no sistema operacional.
///
/// Assim, eles continuam chegando mesmo com o aplicativo fechado e são
/// recalculados sempre que a agenda é carregada ou alterada.
class AgendaReminderScheduler {
  static const _lookaheadDays = 14;

  static String groupFor(String idosoId) => 'agenda:$idosoId';

  static Future<void> sync({
    required String idosoId,
    required Iterable<AgendaCompromisso> compromissos,
  }) async {
    if (idosoId.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final requests = <LocalNotificationRequest>[];

    for (final compromisso in compromissos) {
      if (compromisso.id.isEmpty || !compromisso.ativarLembrete) continue;

      for (var offset = 0; offset <= _lookaheadDays; offset++) {
        final day = today.add(Duration(days: offset));
        if (!agendaItemOccursOnDay(
              start: compromisso.dataHora,
              frequencia: compromisso.frequencia,
              status: compromisso.status,
              day: day,
            ) ||
            compromisso.statusNoDia(day) != 'agendado') {
          continue;
        }

        final startsAt = DateTime(
          day.year,
          day.month,
          day.day,
          compromisso.dataHora.hour,
          compromisso.dataHora.minute,
        );
        final scheduledAt = startsAt.subtract(
          Duration(minutes: compromisso.antecedenciaLembreteMinutos),
        );
        if (!scheduledAt.isAfter(now)) continue;

        requests.add(
          LocalNotificationRequest(
            id: stableNotificationId(
              'agenda:$idosoId:${compromisso.id}:${startsAt.toIso8601String()}',
            ),
            scheduledAt: scheduledAt,
            title: 'Lembrete: ${compromisso.titulo}',
            body: 'Compromisso às ${formatAgendaTime(startsAt)}.',
            payload: 'agenda:${compromisso.id}',
          ),
        );
      }
    }

    await LocalNotificationService.instance.replaceGroup(
      groupFor(idosoId),
      requests,
    );
  }
}
