import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:sympli_ai_health/app/features/chat_ai/model/diagnosis_log.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/services.dart';
import 'package:sympli_ai_health/app/utils/logging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sympli_ai_health/app/features/notifications/notification_manager.dart';



final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();
class ManualPlan {
  final String repeat;      
  final String time;        
  final int? n;             
  final List<int>? days;   
  final int? hours;         
  final String timezone;   

  ManualPlan({
    required this.repeat,
    required this.time,
    this.n,
    this.days,
    this.hours,
    required this.timezone,
  });

  Map<String, dynamic> toMap() => {
        'repeat': repeat,
        'time': time,
        if (n != null) 'n': n,
        if (days != null) 'days': days,
        if (hours != null) 'hours': hours,
        'timezone': timezone,
      };
}

String _stableReminderIdForMed(String name) {
  final n = _canonicalMedName(name).toLowerCase();
  final slug = n.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return 'med_$slug';
}


String _canonicalMedName(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1).toLowerCase();
}

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

    logI("scheduleCheckIn start id=$safeId when=$scheduled title=${log.title}", name: "REM");

    try {
      await _plugin.zonedSchedule(
        safeId,
        "Sympli AI Check-In",
        "How are you feeling after your ${log.title}? Tap to check in.",
        scheduled,
        const NotificationDetails(android: _android, iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: '/chat-ai',
      );
      logI("✅ Check-in scheduled (id=$safeId) → $scheduled", name: "REM");
    } on PlatformException catch (e, st) {
      if (e.code == 'exact_alarms_not_permitted') {
        logW("Exact alarm not permitted on this device", name: "REM");
        if (context != null) _showAlarmPermissionDialog(context);
      } else {
        logE("Reminder scheduling failed (PlatformException)", e, st, name: "REM");
      }
    } catch (e, st) {
      logE("Reminder scheduling failed (unknown)", e, st, name: "REM");
    }
  }

  void _showAlarmPermissionDialog(BuildContext context) {
    logI("Showing exact alarm permission dialog", name: "REM");
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

  Future<void> scheduleLocalNotification({
    required String uid,
    required String name,
    String? dosage,
    String? instructions,
    required String repeat,
    required String time,
    required String timezone,
    List<int>? days,
    int? n,
    int? hours,
  }) async {
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      const androidDetails = AndroidNotificationDetails(
        'medication_channel',
        'Medication Reminders',
        channelDescription: 'Reminders to take your medication on time',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      final now = DateTime.now();
      final scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      ).add(const Duration(seconds: 5)); 

      switch (repeat) {
        case 'daily':
          await notificationsPlugin.zonedSchedule(
            name.hashCode,
            'Time to take $name',
            (dosage?.isNotEmpty ?? false)
                ? 'Dosage: $dosage'
                : 'Take your $name medication.',
            _nextInstanceOf(scheduledTime),
            notificationDetails,
            androidAllowWhileIdle: true,
            matchDateTimeComponents: DateTimeComponents.time,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          break;

        case 'weekly':
          if (days != null && days.isNotEmpty) {
            for (final d in days) {
              await notificationsPlugin.zonedSchedule(
                name.hashCode + d,
                'Time to take $name',
                (dosage?.isNotEmpty ?? false)
                    ? 'Dosage: $dosage'
                    : 'Take your $name medication.',
                _nextInstanceOfWeekday(scheduledTime, d),
                notificationDetails,
                androidAllowWhileIdle: true,
                matchDateTimeComponents:
                    DateTimeComponents.dayOfWeekAndTime,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
              );
            }
          }
          break;

        case 'everyN':
          await notificationsPlugin.periodicallyShow(
            name.hashCode,
            'Time to take $name',
            (dosage?.isNotEmpty ?? false)
                ? 'Dosage: $dosage'
                : 'Take your $name medication.',
            RepeatInterval.daily,
            notificationDetails,
            androidAllowWhileIdle: true,
          );
          break;

        case 'everyNHours':
          await notificationsPlugin.periodicallyShow(
            name.hashCode,
            'Time to take $name',
            (dosage?.isNotEmpty ?? false)
                ? 'Dosage: $dosage'
                : 'Take your $name medication.',
            RepeatInterval.hourly,
            notificationDetails,
            androidAllowWhileIdle: true,
          );
          break;

        default:
          await notificationsPlugin.zonedSchedule(
            name.hashCode,
            'Time to take $name',
            'Take your $name medication.',
            _nextInstanceOf(scheduledTime),
            notificationDetails,
            androidAllowWhileIdle: true,
            matchDateTimeComponents: DateTimeComponents.time,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
      }

      notificationManager.addNotification(
        'Time to take $name',
        (dosage?.isNotEmpty ?? false)
            ? 'Dosage: $dosage'
            : 'Take your $name medication.',
      );
      logI("🔔 Local notification scheduled for $name ($repeat at $time)",
          name: "MedReminderService");
    } catch (e, st) {
      logE("❌ scheduleLocalNotification failed", e, st,
          name: "MedReminderService");
    }
  }

  tz.TZDateTime _nextInstanceOf(DateTime time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfWeekday(DateTime time, int weekday) {
    var scheduled = _nextInstanceOf(time);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }


  Future<void> _openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    logI("Launching exact alarm settings intent", name: "REM");
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
    logI("scheduleDaily start id=$safeId time=$first title=$title", name: "REM");

    try {
      await _plugin.zonedSchedule(
        safeId,
        title,
        body,
        first,
        const NotificationDetails(android: _android, iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      logI("✅ Daily reminder scheduled (id=$safeId) → $first", name: "REM");
    } catch (e, st) {
      logE("scheduleDaily failed", e, st, name: "REM");
    }
  }


  Future<void> scheduleWeekly({
    required int baseId,
    required String title,
    required String body,
    required TimeOfDay timeOfDay,
    required Set<int> weekdays,
  }) async {
    logI("scheduleWeekly start baseId=$baseId days=$weekdays timeOfDay=$timeOfDay", name: "REM");

    for (final d in weekdays) {
      try {
        final when = _nextAtWeekday(timeOfDay, d);
        final id = (baseId * 10 + d) % 2147483647;
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          const NotificationDetails(android: _android, iOS: DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        logI("✅ Weekly reminder (id=$id) → weekday=$d at $when", name: "REM");
      } catch (e, st) {
        logE("scheduleWeekly failed for weekday=$d", e, st, name: "REM");
      }
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

    logI("scheduleEveryNDays start baseId=$baseId n=$n start=$start end=$end", name: "REM");

    try {
      while (!when.isAfter(end)) {
        final id = (baseId * 1000 + idx) % 2147483647;
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          const NotificationDetails(android: _android, iOS: DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        logD("Every-$n-day reminder (id=$id) → $when", name: "REM");
        idx++;
        when = when.add(Duration(days: n));
      }
      logI("✅ Scheduled every $n days for ~$horizonDays days (count=$idx)", name: "REM");
    } catch (e, st) {
      logE("scheduleEveryNDays failed", e, st, name: "REM");
    }
  }

  Future<void> scheduleEveryNHours({
    required int baseId,
    required String title,
    required String body,
    required int hours,
    int horizonDays = 3, 
  }) async {
    logI("scheduleEveryNHours start baseId=$baseId hours=$hours horizonDays=$horizonDays", name: "REM");

    if (hours <= 0) {
      logW("Refusing to schedule: hours must be > 0 (got $hours)", name: "REM");
      return;
    }

    await cancelAllFor(baseId);

    final now = tz.TZDateTime.now(tz.local);
    final end = now.add(Duration(days: horizonDays));
    var when = now.add(Duration(hours: hours));
    var idx = 0;

    try {
      while (!when.isAfter(end)) {
        final id = (baseId * 100 + idx) % 2147483647;
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          const NotificationDetails(android: _android, iOS: DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        logD("Every-$hours-hour reminder (id=$id) → $when", name: "REM");
        idx++;
        when = when.add(Duration(hours: hours));
      }
      logI("✅ Scheduled every $hours hours for next $horizonDays days (≈ $idx alarms)", name: "REM");
    } on PlatformException catch (e, st) {
      if (e.code == 'exact_alarms_not_permitted') {
        logW("Exact alarms not permitted during scheduleEveryNHours", name: "REM");
      } else {
        logE("scheduleEveryNHours PlatformException", e, st, name: "REM");
      }
    } catch (e, st) {
      logE("scheduleEveryNHours failed", e, st, name: "REM");
    }
  }

Future<String> createOrUpdateManualReminder({
  required String uid,
  required String medName,
  required ManualPlan plan,
  String? dosage,            
  String? instructions,      
  bool active = true,
  bool alsoScheduleLocally = true,
  String? reminderIdOverride, 
}) async {
  final db = FirebaseFirestore.instance;
  final userRef = db.collection('users').doc(uid);
  final reminders = userRef.collection('medication_reminders');

  DocumentReference<Map<String, dynamic>> docRef;
  if (reminderIdOverride != null && reminderIdOverride.isNotEmpty) {
    docRef = reminders.doc(reminderIdOverride);
  } else {
    final existing = await reminders.where('name', isEqualTo: medName).limit(1).get();
    docRef = existing.docs.isNotEmpty ? existing.docs.first.reference : reminders.doc();
  }
  final reminderId = docRef.id;

logI("🕒 Final plan before Firestore save: repeat=${plan.repeat}, time=${plan.time}, tz=${plan.timezone}", name: "MedReminderService");

final record = <String, dynamic>{
  'reminderId': reminderId,
  'userId': uid,
  'name': medName,
  'dosage': dosage ?? '',
  'instructions': instructions ?? '',
  'active': active,
  'createdAt': FieldValue.serverTimestamp(),
  'plan': {
    'repeat': plan.repeat,
    'time': plan.time,
    'timezone': plan.timezone,
    if (plan.n != null) 'n': plan.n,
    if (plan.days != null && plan.days!.isNotEmpty) 'days': plan.days,
    if (plan.hours != null) 'hours': plan.hours,
  },
};

final batch = db.batch();
batch.set(docRef, record, SetOptions(merge: true));
batch.set(
  userRef,
  {
    'profile': {
      'medications': FieldValue.arrayUnion([medName]),
    },
    'updatedAt': FieldValue.serverTimestamp(),
  },
  SetOptions(merge: true),
);

try {
  await batch.commit();
  logI("✅ Firestore batch committed successfully for $reminderId", name: "MedReminderService");
} catch (e, st) {
  logE("❌ Firestore batch commit FAILED for $reminderId", e, st, name: "MedReminderService");
  rethrow;
}

  if (alsoScheduleLocally) {
    final baseId = reminderId.hashCode & 0x7FFFFFFF;
    await cancelAllFor(baseId);

    final title = 'Take $medName';
    const body = 'Don’t forget your medication.';

    if (plan.repeat == 'daily') {
      final tod = _parseTime(plan.time);
      await scheduleDaily(id: baseId, title: title, body: body, timeOfDay: tod);
    } else if (plan.repeat == 'weekly') {
      final tod = _parseTime(plan.time);
      await scheduleWeekly(
        baseId: baseId,
        title: title,
        body: body,
        timeOfDay: tod,
        weekdays: (plan.days ?? const <int>[]).toSet(),
      );
    } else if (plan.repeat == 'everyN') {
      final tod = _parseTime(plan.time);
      await scheduleEveryNDays(
        baseId: baseId,
        title: title,
        body: body,
        timeOfDay: tod,
        n: plan.n ?? 2,
      );
    } else if (plan.repeat == 'everyNHours') {
      await scheduleEveryNHours(
        baseId: baseId,
        title: title,
        body: body,
        hours: plan.hours ?? 6,
      );
    }
  }

  return reminderId;
}

Future<String> saveAiReminderAndUpdateUser({
  required String uid,
  required String name,          
  String? dosage,
  String? instructions,
  bool active = true,

  String repeat = 'daily',
  required String time,            
  String timezone = 'SAST',
  int? n,
  List<int>? days,
  int? hours,

  String? reminderId,
  bool alsoScheduleLocally = true,
}) async {
  final medName = _canonicalMedName(name);

  final plan = ManualPlan(
    repeat: repeat,
    time: time,
    n: n,
    days: days,
    hours: hours,
    timezone: timezone,
  );

  final id = reminderId?.isNotEmpty == true ? reminderId : _stableReminderIdForMed(medName);

  return createOrUpdateManualReminder(
    uid: uid,
    medName: medName,
    plan: plan,
    dosage: dosage,
    instructions: instructions,
    active: active,
    alsoScheduleLocally: alsoScheduleLocally,
    reminderIdOverride: id, 
  );
}

List<int> parseWeekdays(List<String> names) {
  int toNum(String s) {
    final n = s.trim().toLowerCase();
    if (n.startsWith('mon')) return DateTime.monday;
    if (n.startsWith('tue')) return DateTime.tuesday;
    if (n.startsWith('wed')) return DateTime.wednesday;
    if (n.startsWith('thu')) return DateTime.thursday;
    if (n.startsWith('fri')) return DateTime.friday;
    if (n.startsWith('sat')) return DateTime.saturday;
    if (n.startsWith('sun')) return DateTime.sunday;
    return DateTime.monday;
  }
  return names.map(toNum).toSet().toList()..sort();
}


  Future<void> cancelAllFor(int baseId) async {
    logI("cancelAllFor baseId=$baseId", name: "REM");
    try {
      await _plugin.cancel(baseId % 2147483647);
      for (var d = DateTime.monday; d <= DateTime.sunday; d++) {
        await _plugin.cancel((baseId * 10 + d) % 2147483647);
      }
      for (var i = 0; i < 365; i++) {
        await _plugin.cancel((baseId * 1000 + i) % 2147483647);
      }
      logI("🧹 Cancelled all reminders for baseId $baseId", name: "REM");
    } catch (e, st) {
      logE("cancelAllFor failed", e, st, name: "REM");
    }
  }

  Future<void> migrateAndDedupeReminders(String uid) async {
  final db = FirebaseFirestore.instance;
  final col = db.collection('users').doc(uid).collection('medication_reminders');
  final snap = await col.get();

  final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> byName = {};
  for (final d in snap.docs) {
    final n = _canonicalMedName((d['name'] ?? '').toString());
    if (n.isEmpty) continue;
    byName.putIfAbsent(n, () => []).add(d);
  }

  final batch = db.batch();

  for (final entry in byName.entries) {
    final med = entry.key;
    final docs = entry.value;
    final targetId = _stableReminderIdForMed(med);
    final targetRef = col.doc(targetId);

    QueryDocumentSnapshot<Map<String, dynamic>>? best = docs.first;
    for (final d in docs) {
      final hasPlan = (d.data()['plan'] as Map?) != null;
      if (hasPlan) { best = d; break; }
    }

    final data = Map<String, dynamic>.from(best!.data());
    final int? freqHours = (data['frequency_hours'] is num)
        ? (data['frequency_hours'] as num).round()
        : int.tryParse((data['frequency_hours'] ?? '').toString());
    final bool hasPlan = data['plan'] is Map;

    if (!hasPlan) {
      final plan = <String, dynamic>{
        'repeat': (freqHours != null && freqHours > 0) ? 'everyNHours' : 'daily',
        'time': '08:00',
        'timezone': 'SAST',
        if (freqHours != null && freqHours > 0) 'hours': freqHours,
      };
      data['plan'] = plan;
      data['repeat'] = plan['repeat'];
      data['time'] = '08:00';
      data['timezone'] = 'SAST';
      if (freqHours != null && freqHours > 0) data['hours'] = freqHours;
      data.remove('frequency_hours');
    }

    data['name'] = med; 
    data['reminderId'] = targetId;

    batch.set(targetRef, data, SetOptions(merge: true));
    for (final d in docs) {
      if (d.id != targetId) batch.delete(d.reference);
    }
  }

  await batch.commit();
}

  Future<void> cancel(int id) async {
    final safe = id % 2147483647;
    logI("cancel id=$safe", name: "REM");
    try {
      await _plugin.cancel(safe);
      logI("✅ cancel ok id=$safe", name: "REM");
    } catch (e, st) {
      logE("cancel failed id=$safe", e, st, name: "REM");
    }
  }

    TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }
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

