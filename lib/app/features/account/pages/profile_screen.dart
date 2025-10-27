import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sympli_ai_health/app/features/account/services/profile_repository.dart';
import 'package:sympli_ai_health/app/utils/logging.dart' as log;
import 'package:sympli_ai_health/app/features/account/widgets/medication_reminder_list.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _repo = ProfileRepository();

  String get _uid => _auth.currentUser?.uid ?? '';

  Future<void> _pickNewTime(BuildContext ctx, MedicationReminder r) async {
    final parts = (r.time ?? '08:00').split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final picked = await showTimePicker(
      context: ctx,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;

    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    final newTime = '$hh:$mm';

    try {
      await _repo.updateTime(_uid, r.id, hhmm: newTime);
      log.logI('⏰ Reminder ${r.id} time updated → $newTime');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Time updated to $newTime')));
      }
    } catch (e, st) {
      log.logE('Failed to update time', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update time')),
        );
      }
    }
  }

  Future<void> _showAddReminderSheet(BuildContext context) async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController();
    final dosage = TextEditingController();
    final notes = TextEditingController();
    String repeat = 'daily';
    String timezone = 'SAST';
    TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);

    Future<void> pickTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: time,
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        ),
      );
      if (picked != null) {
        setState(() => time = picked);
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Add medication reminder',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Medication name',
                    prefixIcon: Icon(Icons.medication_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: dosage,
                  decoration: const InputDecoration(
                    labelText: 'Dosage (optional)',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'Instructions / notes (optional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: repeat,
                        items: const [
                          DropdownMenuItem(
                              value: 'daily', child: Text('Daily')),
                          DropdownMenuItem(
                              value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(
                              value: 'everyNHours',
                              child: Text('Every N Hours')),
                          DropdownMenuItem(
                              value: 'everyN', child: Text('Every N Days')),
                        ],
                        onChanged: (v) => repeat = v ?? 'daily',
                        decoration: const InputDecoration(
                          labelText: 'Repeat',
                          prefixIcon: Icon(Icons.repeat),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: pickTime,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            prefixIcon: Icon(Icons.schedule),
                          ),
                          child: Text(
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: timezone,
                  decoration: const InputDecoration(
                    labelText: 'Timezone',
                    prefixIcon: Icon(Icons.public),
                  ),
                  onChanged: (v) => timezone = v.trim().isEmpty ? 'SAST' : v,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save reminder'),
                  onPressed: () async {
                    if (!form.currentState!.validate()) return;
                    final hh =
                        time.hour.toString().padLeft(2, '0');
                    final mm =
                        time.minute.toString().padLeft(2, '0');
                    final hhmm = '$hh:$mm';
                    try {
                      await _repo.createReminderManual(
                        uid: _uid,
                        name: name.text.trim(),
                        dosage: dosage.text.trim().isEmpty
                            ? null
                            : dosage.text.trim(),
                        instructions: notes.text.trim().isEmpty
                            ? null
                            : notes.text.trim(),
                        repeat: repeat,
                        timeHHmm: hhmm,
                        timezone: timezone,
                        active: true,
                      );
                      if (mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Reminder added')),
                        );
                      }
                    } catch (e, st) {
                      log.logE('Create reminder failed', e, st);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Could not create reminder')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return const Center(child: Text('Not signed in'));
    }

    return Scaffold(

      body: StreamBuilder<SympliUser?>(
        stream: _repo.userStream(_uid),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = userSnap.data;
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          final age = (user.profile?['age'] as num?)?.toInt();
          final allergies =
              (user.profile?['allergies'] as List?)?.cast<String>() ?? const [];
          final conditions =
              (user.profile?['conditions'] as List?)?.cast<String>() ?? const [];
          final meds = user.medications?.cast<String>() ?? const [];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                child: Text(
                                  (user.username ?? 'U')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.username ?? '—',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(user.email ?? '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        _chip(context, 'UID', user.uid),
                                        if (age != null)
                                          _chip(context, 'Age', '$age'),
                                        _chip(
                                          context,
                                          'Onboarding',
                                          '${user.onboardingComplete ?? false}',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Health profile',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                              const SizedBox(height: 8),
                              if (allergies.isNotEmpty)
                                _kvRow('Allergies', allergies.join(', ')),
                              if (conditions.isNotEmpty)
                                _kvRow('Conditions', conditions.join(', ')),
                              if (meds.isNotEmpty)
                                _kvRow('Medications', meds.join(', ')),
                            ],
                          ),
                        ),
                      ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Reminder'),
                            onPressed: () => _showAddReminderSheet(context),
                          ),
                        ),
                        const SizedBox(height: 12),

                      const SizedBox(height: 16),
                      Text('Medication reminders',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      MedicationReminderList(
                        uid: _uid,
                        repo: _repo,
                        onEditTime: (r) => _pickNewTime(context, r),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(BuildContext context, String k, String v) {
    return Chip(
      label: Text('$k: $v'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _kvRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  Widget _scheduleList(BuildContext context, Map<String, dynamic> schedules) {
    final entries = schedules.entries.toList();
    if (entries.isEmpty) return const Text('—');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((e) {
        final m = (e.value as Map?) ?? {};
        final repeat = m['repeat'] ?? '—';
        final time = m['time'] ?? '—';
        final tz = m['timezone'] ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text('• ${e.key} → $repeat at $time $tz'),
        );
      }).toList(),
    );
  }
}
