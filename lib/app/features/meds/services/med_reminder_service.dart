import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

class MedReminderService {
  MedReminderService(this._plugin);
  final FlutterLocalNotificationsPlugin _plugin;

  static const _android = AndroidNotificationDetails(
    'meds_channel_id',
    'Medication Reminders',
    channelDescription: 'Medication reminders',
    importance: Importance.max,
    priority: Priority.high,
  );

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay timeOfDay,
  }) async {
    final first = _nextAtTime(timeOfDay);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      first,
      const NotificationDetails(
        android: _android,
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleWeekly({
    required int baseId,
    required String title,
    required String body,
    required TimeOfDay timeOfDay,
    required Set<int> weekdays,
  }) async {
    for (final d in weekdays) {
      final when = _nextAtWeekday(timeOfDay, d);
      final id = baseId * 10 + d;
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        const NotificationDetails(
          android: _android,
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> scheduleEveryNDays({
    required int baseId,
    required String title,
    required String body,
    required TimeOfDay timeOfDay,
    required int n,
    int horizonDays = 180,
  }) async {
    final start = _nextAtTime(timeOfDay);
    final end = tz.TZDateTime.now(tz.local).add(Duration(days: horizonDays));

    var when = start;
    var idx = 0;
    while (!when.isAfter(end)) {
      final id = baseId * 1000 + idx;
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        const NotificationDetails(
          android: _android,
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      idx++;
      when = when.add(Duration(days: n));
    }
  }

  Future<void> cancelAllFor(int baseId) async {
    await _plugin.cancel(baseId);
    for (var d = DateTime.monday; d <= DateTime.sunday; d++) {
      await _plugin.cancel(baseId * 10 + d);
    }
    for (var i = 0; i < 365; i++) {
      await _plugin.cancel(baseId * 1000 + i);
    }
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
}

tz.TZDateTime _nextAtTime(TimeOfDay t) {
  final now = tz.TZDateTime.now(tz.local);
  var scheduled =
      tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
  if (!scheduled.isAfter(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}

tz.TZDateTime _nextAtWeekday(TimeOfDay t, int weekday) {
  final now = tz.TZDateTime.now(tz.local);
  var scheduled =
      tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
  while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}

final medReminderService = MedReminderService(notificationsPlugin);

