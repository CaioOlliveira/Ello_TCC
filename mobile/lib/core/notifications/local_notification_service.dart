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
  bool _askedForExactAlarmPermission = false;

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
    final scheduleMode = await _getAndroidScheduleMode();
    for (final request in requests) {
      if (!request.scheduledAt.isAfter(now)) continue;
      await _schedule(request, scheduleMode: scheduleMode);
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

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await initialize();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'ello_messages',
        'Mensagens do Ello',
        channelDescription: 'Mensagens recebidas no Chat do Cuidado',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  Future<AndroidScheduleMode> _getAndroidScheduleMode() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return AndroidScheduleMode.exactAllowWhileIdle;

    final canScheduleExactly =
        await androidPlugin.canScheduleExactNotifications();
    if (canScheduleExactly != false) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    if (!_askedForExactAlarmPermission) {
      _askedForExactAlarmPermission = true;
      await androidPlugin.requestExactAlarmsPermission();
    }

    final grantedAfterRequest =
        await androidPlugin.canScheduleExactNotifications();
    return grantedAfterRequest == false
        ? AndroidScheduleMode.inexactAllowWhileIdle
        : AndroidScheduleMode.exactAllowWhileIdle;
  }

  Future<void> _schedule(
    LocalNotificationRequest request, {
    required AndroidScheduleMode scheduleMode,
  }) {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'ello_reminders',
        'Lembretes do Ello',
        channelDescription: 'Compromissos e horários de medicamentos',
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
      androidScheduleMode: scheduleMode,
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
