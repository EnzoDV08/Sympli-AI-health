import 'dart:isolate';
import 'package:sympli_ai_health/app/features/meds/services/med_reminder_service.dart';
import 'package:sympli_ai_health/app/utils/logging.dart';

class ReminderIsolate {
  static Future<void> runInBackground(Map<String, dynamic> params) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_execute, [receivePort.sendPort, params]);
  }

  static Future<void> _execute(List<dynamic> args) async {
    final SendPort sendPort = args[0];
    final Map<String, dynamic> params = args[1];

    try {
      final service = MedReminderService(notificationsPlugin);

      await service.scheduleLocalNotification(
        uid: params['uid'],
        name: params['name'],
        dosage: params['dosage'],
        instructions: params['instructions'],
        repeat: params['repeat'],
        time: params['time'],
        timezone: params['timezone'],
        days: params['days'],
        n: params['n'],
        hours: params['hours'],
      );

      logI(
        "📅 Reminder isolate scheduled '${params['name']}' (${params['repeat']}) at ${params['time']}",
        name: "REMINDER_ISOLATE",
      );

      sendPort.send(true);
    } catch (e, st) {
      logE("❌ Reminder isolate failed", e, st, name: "REMINDER_ISOLATE");
      sendPort.send(false);
    }
  }
}
