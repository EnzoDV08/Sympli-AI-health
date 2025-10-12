import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:sympli_ai_health/app/features/chat_ai/model/diagnosis_log.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/services.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

class MedReminderService {
  MedReminderService(this._plugin);
  final FlutterLocalNotificationsPlugin _plugin;

  static const _android = AndroidNotificationDetails(
    'meds_channel_id',
    'Medication Reminders',
    channelDescription: 'Medication and check-in reminders',
    importance: Importance.max,
    priority: Priority.high,
  );

  Future<void> scheduleCheckIn(DiagnosisLog log, {BuildContext? context}) async {
    final scheduled = tz.TZDateTime.from(log.nextCheckIn, tz.local);
    final safeId = log.hashCode.abs() % 2147483647;

    try {
      await _plugin.zonedSchedule(
        safeId,
        "Sympli AI Check-In",
        "How are you feeling after your ${log.title}? Tap to check in.",
        scheduled,
        const NotificationDetails(android: _android, iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '/chat-ai',
      );
      print("✅ Scheduled AI check-in (ID $safeId) → $scheduled");
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        print("⚠️ Exact alarm not permitted");
        if (context != null) _showAlarmPermissionDialog(context);
      } else {
        print("⚠️ Reminder scheduling failed: $e");
      }
    } catch (e) {
      print("⚠️ Reminder scheduling failed (unknown): $e");
    }
  }

  void _showAlarmPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permission Needed"),
        content: const Text(
          "Sympli AI Health needs permission to schedule exact medication reminders. "
          "Would you like to open Settings to enable it?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openExactAlarmSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  Future<void> _openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    const intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay timeOfDay,
  }) async {
    final first = _nextAtTime(timeOfDay);
    final safeId = id % 2147483647;
    await _plugin.zonedSchedule(
      safeId,
      title,
      body,
      first,
      const NotificationDetails(android: _android, iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    print("✅ Daily reminder ($safeId) → $first");
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
      final id = (baseId * 10 + d) % 2147483647;
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        const NotificationDetails(android: _android, iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      print("✅ Weekly reminder (ID $id) → weekday $d at $when");
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
      final id = (baseId * 1000 + idx) % 2147483647;
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        const NotificationDetails(android: _android, iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print("✅ Every-$n-day reminder (ID $id) → $when");
      idx++;
      when = when.add(Duration(days: n));
    }
  }

  Future<void> scheduleEveryNHours({
    required int baseId,
    required String title,
    required String body,
    required int hours,
    int horizonDays = 30,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var when = now.add(Duration(hours: hours));
    final end = now.add(Duration(days: horizonDays));
    var idx = 0;

    while (!when.isAfter(end)) {
      final id = (baseId * 10000 + idx) % 2147483647;
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        const NotificationDetails(android: _android, iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print("✅ Every-$hours-hour reminder (ID $id) → $when");
      idx++;
      when = when.add(Duration(hours: hours));
    }
  }

  Future<void> cancelAllFor(int baseId) async {
    await _plugin.cancel(baseId % 2147483647);
    for (var d = DateTime.monday; d <= DateTime.sunday; d++) {
      await _plugin.cancel((baseId * 10 + d) % 2147483647);
    }
    for (var i = 0; i < 365; i++) {
      await _plugin.cancel((baseId * 1000 + i) % 2147483647);
    }
    print("🧹 Cancelled all reminders for baseId $baseId");
  }

  Future<void> cancel(int id) => _plugin.cancel(id % 2147483647);
}

tz.TZDateTime _nextAtTime(TimeOfDay t) {
  final now = tz.TZDateTime.now(tz.local);
  var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
  if (!scheduled.isAfter(now)) scheduled = scheduled.add(const Duration(days: 1));
  return scheduled;
}

tz.TZDateTime _nextAtWeekday(TimeOfDay t, int weekday) {
  final now = tz.TZDateTime.now(tz.local);
  var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
  while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}

final medReminderService = MedReminderService(notificationsPlugin);
