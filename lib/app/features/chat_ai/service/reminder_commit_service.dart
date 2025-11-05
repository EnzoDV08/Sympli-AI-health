import 'package:firebase_auth/firebase_auth.dart';
import 'package:sympli_ai_health/app/features/meds/services/med_reminder_service.dart';
import 'package:sympli_ai_health/app/utils/logging.dart';
import 'package:sympli_ai_health/app/utils/isolate_reminder.dart';

class ReminderCommitService {
  final _auth = FirebaseAuth.instance;
  final medReminderService = MedReminderService(notificationsPlugin);
  static const String _defaultTimezone = 'SAST';

  Future<void> commitMedicationProposal(Map<String, dynamic> p) async {
     logI("💾 commitMedicationProposal CALLED with payload: ${p.toString()}", name: "AI"); 
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      logW("Cannot commit medication: no logged-in user", name: "AI");
      return;
    }
  logI("🏁 commitMedicationProposal FINISHED for ${p['name']}", name: "AI");

    final String name = (p['name'] ?? '').toString().trim();
    final String dosage = (p['dosage'] ?? '').toString().trim();
    final String instructions = (p['instructions'] ?? '').toString().trim();

    if (name.isEmpty) {
      logW("Skipping save: empty 'name' in proposal", name: "AI");
      return;
    }

final schedRaw = p['schedule'];
if (schedRaw is Map) {
  final sched = Map<String, dynamic>.from(schedRaw);
  if (sched.containsKey('type') && !sched.containsKey('repeat')) {
    sched['repeat'] = sched['type'];
  }

  final repeatType = (sched['repeat'] ?? 'daily').toString();
  final tz = (sched['timezone'] ?? _defaultTimezone).toString();

  String adjustedTime;
  final now = DateTime.now();

  if (sched['time'] != null && sched['time'].toString().contains(':')) {
    adjustedTime = sched['time'].toString().trim();
    logI("✅ Using AI-specified time: $adjustedTime", name: "AI");
  } else {
    final roundedMinutes = (now.minute / 5).round() * 5;
    adjustedTime =
        "${now.hour.toString().padLeft(2, '0')}:${roundedMinutes.toString().padLeft(2, '0')}";
    logI("🕒 No valid time provided — using current time: $adjustedTime", name: "AI");
  }

  switch (repeatType) {
    case 'daily':
      await medReminderService.saveAiReminderAndUpdateUser(
        uid: uid,
        name: name,
        dosage: dosage,
        instructions: instructions,
        repeat: 'daily',
        time: adjustedTime,
        timezone: tz,
      );

      ReminderIsolate.runInBackground({
        'uid': uid,
        'name': name,
        'dosage': dosage,
        'instructions': instructions,
        'repeat': 'daily',
        'time': adjustedTime,
        'timezone': tz,
      });

      logI("✅ Saved AI reminder (daily at $adjustedTime) for $name", name: "AI");
      return;

    case 'weekly':
      final daysNames =
          (sched['days'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final days = medReminderService.parseWeekdays(daysNames);
      await medReminderService.saveAiReminderAndUpdateUser(
        uid: uid,
        name: name,
        dosage: dosage,
        instructions: instructions,
        repeat: 'weekly',
        time: adjustedTime,
        timezone: tz,
        days: days,
      );

      ReminderIsolate.runInBackground({
        'uid': uid,
        'name': name,
        'dosage': dosage,
        'instructions': instructions,
        'repeat': 'weekly',
        'time': adjustedTime,
        'timezone': tz,
        'days': days,
      });

      logI("✅ Saved AI reminder (weekly ${days.join(',')}) for $name", name: "AI");
      return;

    case 'everyN':
      final int? n = (sched['n'] is num)
          ? (sched['n'] as num).round()
          : int.tryParse((sched['n'] ?? '').toString());
      await medReminderService.saveAiReminderAndUpdateUser(
        uid: uid,
        name: name,
        dosage: dosage,
        instructions: instructions,
        repeat: (n != null && n > 0) ? 'everyN' : 'daily',
        time: adjustedTime,
        timezone: tz,
        n: n,
      );
      ReminderIsolate.runInBackground({
        'uid': uid,
        'name': name,
        'dosage': dosage,
        'instructions': instructions,
        'repeat': (n != null && n > 0) ? 'everyN' : 'daily',
        'time': adjustedTime,
        'timezone': tz,
        'n': n,
      });
      logI(
          "✅ Saved AI reminder (${n != null && n > 0 ? 'every $n days' : 'daily'} at $adjustedTime) for $name",
          name: "AI");
      return;

    case 'everyNHours':
      int? hours;
      final raw = sched['hours'];
      if (raw is num) hours = raw.round();
      if (raw is String) hours ??= int.tryParse(raw.trim());
      final repType = (hours != null && hours > 0) ? 'everyNHours' : 'daily';
      await medReminderService.saveAiReminderAndUpdateUser(
        uid: uid,
        name: name,
        dosage: dosage,
        instructions: instructions,
        repeat: repType,
        time: adjustedTime,
        timezone: tz,
        hours: hours,
      );
      ReminderIsolate.runInBackground({
        'uid': uid,
        'name': name,
        'dosage': dosage,
        'instructions': instructions,
        'repeat': repType,
        'time': adjustedTime,
        'timezone': tz,
        'hours': hours,
      });
      logI("✅ Saved AI reminder ($repType at $adjustedTime) for $name", name: "AI");
      return;

    default:
await medReminderService.saveAiReminderAndUpdateUser(
  uid: uid,
  name: name,
  dosage: dosage,
  instructions: instructions,
  repeat: 'daily',
  time: adjustedTime, 
  timezone: tz,
);
ReminderIsolate.runInBackground({
  'uid': uid,
  'name': name,
  'dosage': dosage,
  'instructions': instructions,
  'repeat': 'daily',
  'time': adjustedTime,
  'timezone': tz,
});
logW("Unknown schedule type; fell back to daily at $adjustedTime", name: "AI");
return;
  }
}



  }
}
