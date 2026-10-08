import 'package:flutter_test/flutter_test.dart';

import 'package:ello_mobile/core/notifications/local_notification_service.dart';

void main() {
  test('identifica lembretes de fichas que não existem mais', () {
    final stale = staleReminderGroups(
      [
        'agenda:ficha-antiga',
        'medicamentos:ficha-antiga',
        'agenda:ficha-atual',
        'outro-grupo',
      ],
      ['ficha-atual'],
    );

    expect(stale, {
      'agenda:ficha-antiga',
      'medicamentos:ficha-antiga',
    });
  });

  test('marca todos os lembretes como antigos quando não há fichas', () {
    final stale = staleReminderGroups(
      ['agenda:ficha-1', 'medicamentos:ficha-2'],
      const [],
    );

    expect(stale, {'agenda:ficha-1', 'medicamentos:ficha-2'});
  });
}
