import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationRequest {
  const LocalNotificationRequest({
    required this.id,
    required this.scheduledAt,
    required this.title,
    required this.body,
    this.payload,
  });

  final int id;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final String? payload;
}

class LocalNotificationService {
  LocalNotificationService._();

  static final instance = LocalNotificationService._();
  static const _idsKey = 'ello_scheduled_notification_ids';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: darwin);

    await _plugin.initialize(settings: settings);
    _initialized = true;

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> replaceGroup(
    String group,
    Iterable<LocalNotificationRequest> requests,
  ) async {
    if (kIsWeb) return;
    await initialize();

    final prefs = await SharedPreferences.getInstance();
    final groups = _readGroups(prefs);
    final previousIds = groups[group] ?? const <int>[];
    for (final id in previousIds) {
      await _plugin.cancel(id: id);
    }

    final now = DateTime.now();
    final scheduledIds = <int>[];
    for (final request in requests) {
      if (!request.scheduledAt.isAfter(now)) continue;
      await _schedule(request);
      scheduledIds.add(request.id);
    }

    if (scheduledIds.isEmpty) {
      groups.remove(group);
    } else {
      groups[group] = scheduledIds;
    }
    await prefs.setString(_idsKey, jsonEncode(groups));
  }

  Future<void> cancelGroup(String group) async {
    if (kIsWeb) return;
    await initialize();

    final prefs = await SharedPreferences.getInstance();
    final groups = _readGroups(prefs);
    final ids = groups.remove(group) ?? const <int>[];
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
    await prefs.setString(_idsKey, jsonEncode(groups));
  }

  Future<void> _schedule(LocalNotificationRequest request) {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'ello_reminders',
        'Lembretes do Ello',
        channelDescription: 'Compromissos e horarios de medicamentos',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    return _plugin.zonedSchedule(
      id: request.id,
      title: request.title,
      body: request.body,
      scheduledDate: tz.TZDateTime.from(request.scheduledAt, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: request.payload,
    );
  }

  Map<String, List<int>> _readGroups(SharedPreferences prefs) {
    final raw = prefs.getString(_idsKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          entry.key.toString(): [
            if (entry.value is List)
              for (final id in entry.value)
                if (id is int) id,
          ],
      };
    } catch (_) {
      return {};
    }
  }
}

int stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
