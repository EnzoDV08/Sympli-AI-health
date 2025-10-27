import 'package:firebase_auth/firebase_auth.dart';
import 'package:sympli_ai_health/app/features/meds/services/med_reminder_service.dart';
import 'package:sympli_ai_health/app/utils/logging.dart';
import 'package:sympli_ai_health/app/utils/isolate_reminder.dart';

class ReminderCommitService {
  final _auth = FirebaseAuth.instance;
  final medReminderService = MedReminderService(notificationsPlugin);

  static const String _defaultTime = '08:00';
  static const String _defaultTimezone = 'SAST';

  Future<void> commitMedicationProposal(Map<String, dynamic> p) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      logW("Cannot commit medication: no logged-in user", name: "AI");
      return;
    }

    final String name = (p['name'] ?? '').toString().trim();
    final String dosage = (p['dosage'] ?? '').toString().trim();
    final String instructions = (p['instructions'] ?? '').toString().trim();

    if (name.isEmpty) {
      logW("Skipping save: empty 'name' in proposal", name: "AI");
      return;
    }

    String safeTime(dynamic v) {
      final s = (v ?? '').toString();
      final reg = RegExp(r'^\d{2}:\d{2}$');
      if (!reg.hasMatch(s)) return _defaultTime;
      final parts = s.split(':');
      final h = int.tryParse(parts[0]) ?? -1;
      final m = int.tryParse(parts[1]) ?? -1;
      return (h >= 0 && h < 24 && m >= 0 && m < 60) ? s : _defaultTime;
    }

    final sched = p['schedule'];
    if (sched is Map) {
      final type = (sched['type'] ?? '').toString();
      final tz = (sched['timezone'] ?? _defaultTimezone).toString();

      switch (type) {
        case 'daily':
          {
            final time = safeTime(sched['time']);
            await medReminderService.saveAiReminderAndUpdateUser(
              uid: uid,
              name: name,
              dosage: dosage,
              instructions: instructions,
              repeat: 'daily',
              time: time,
              timezone: tz,
            );

            ReminderIsolate.runInBackground({
              'uid': uid,
              'name': name,
              'dosage': dosage,
              'instructions': instructions,
              'repeat': 'daily',
              'time': time,
              'timezone': tz,
            });

            logI("✅ Saved AI reminder (daily at $time) for $name", name: "AI");
            return;
          }

        case 'weekly':
          {
            final time = safeTime(sched['time']);
            final daysNames =
                (sched['days'] as List?)?.map((e) => e.toString()).toList() ?? [];
            final days = medReminderService.parseWeekdays(daysNames);

            await medReminderService.saveAiReminderAndUpdateUser(
              uid: uid,
              name: name,
              dosage: dosage,
              instructions: instructions,
              repeat: 'weekly',
              time: time,
              timezone: tz,
              days: days,
            );

            ReminderIsolate.runInBackground({
              'uid': uid,
              'name': name,
              'dosage': dosage,
              'instructions': instructions,
              'repeat': 'weekly',
              'time': time,
              'timezone': tz,
              'days': days,
            });

            logI("✅ Saved AI reminder (weekly ${days.join(',')}) for $name",
                name: "AI");
            return;
          }

        case 'everyN':
          {
            final time = safeTime(sched['time']);
            final int? n = (sched['n'] is num)
                ? (sched['n'] as num).round()
                : int.tryParse((sched['n'] ?? '').toString());

            await medReminderService.saveAiReminderAndUpdateUser(
              uid: uid,
              name: name,
              dosage: dosage,
              instructions: instructions,
              repeat: (n != null && n > 0) ? 'everyN' : 'daily',
              time: time,
              timezone: tz,
              n: n,
            );

            ReminderIsolate.runInBackground({
              'uid': uid,
              'name': name,
              'dosage': dosage,
              'instructions': instructions,
              'repeat': (n != null && n > 0) ? 'everyN' : 'daily',
              'time': time,
              'timezone': tz,
              'n': n,
            });

            logI(
                "✅ Saved AI reminder (${n != null && n > 0 ? 'every $n days' : 'daily'} at $time) for $name",
                name: "AI");
            return;
          }

        case 'everyNHours':
          {
            int? hours;
            final raw = sched['hours'];
            if (raw is num) hours = raw.round();
            if (raw is String) hours ??= int.tryParse(raw.trim());

            final repeatType =
                (hours != null && hours > 0) ? 'everyNHours' : 'daily';

            await medReminderService.saveAiReminderAndUpdateUser(
              uid: uid,
              name: name,
              dosage: dosage,
              instructions: instructions,
              repeat: repeatType,
              time: _defaultTime,
              timezone: tz,
              hours: hours,
            );

            ReminderIsolate.runInBackground({
              'uid': uid,
              'name': name,
              'dosage': dosage,
              'instructions': instructions,
              'repeat': repeatType,
              'time': _defaultTime,
              'timezone': tz,
              'hours': hours,
            });

            logI(
                "✅ Saved AI reminder (${repeatType == 'everyNHours' ? 'every $hours hours' : 'daily'}) for $name",
                name: "AI");
            return;
          }

        default:
          {
            await medReminderService.saveAiReminderAndUpdateUser(
              uid: uid,
              name: name,
              dosage: dosage,
              instructions: instructions,
              repeat: 'daily',
              time: _defaultTime,
              timezone: _defaultTimezone,
            );

            ReminderIsolate.runInBackground({
              'uid': uid,
              'name': name,
              'dosage': dosage,
              'instructions': instructions,
              'repeat': 'daily',
              'time': _defaultTime,
              'timezone': _defaultTimezone,
            });

            logW("Unknown schedule type; fell back to daily", name: "AI");
            return;
          }
      }
    }

    int? hours;
    final freqRaw = p['frequency_hours'];
    if (freqRaw is num) hours = freqRaw.round();
    if (freqRaw is String) hours ??= int.tryParse(freqRaw.trim());

    final repeatType = (hours != null && hours > 0) ? 'everyNHours' : 'daily';

    await medReminderService.saveAiReminderAndUpdateUser(
      uid: uid,
      name: name,
      dosage: dosage,
      instructions: instructions,
      repeat: repeatType,
      time: _defaultTime,
      timezone: _defaultTimezone,
      hours: hours,
    );

    ReminderIsolate.runInBackground({
      'uid': uid,
      'name': name,
      'dosage': dosage,
      'instructions': instructions,
      'repeat': repeatType,
      'time': _defaultTime,
      'timezone': _defaultTimezone,
      'hours': hours,
    });

    logI("✅ Saved AI reminder ($repeatType) for $name", name: "AI");
  }
}
