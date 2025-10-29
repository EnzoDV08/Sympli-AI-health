import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sympli_ai_health/app/features/account/services/profile_repository.dart';
import 'package:sympli_ai_health/app/features/account/widgets/medication_reminder_list.dart';
import 'package:sympli_ai_health/app/utils/logging.dart' as log;
import 'package:sympli_ai_health/app/features/account/widgets/edit_profile_modal.dart';


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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Time updated to $newTime')));
      }
    } catch (e, st) {
      log.logE('Failed to update time', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not update time')));
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
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) setState(() => time = picked);
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white.withOpacity(0.95),
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom;
      final safePadding = MediaQuery.of(ctx).padding.bottom; 

      return Padding(

        padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + safePadding + 100),
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add Medication Reminder',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Medication name',
                  prefixIcon: Icon(Icons.medication_outlined),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
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
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Instructions / notes',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: repeat,
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(
                            value: 'everyNHours', child: Text('Every N Hours')),
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
              const SizedBox(height: 20),

              FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save reminder'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF37B7A5),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () async {
                  if (!form.currentState!.validate()) return;
                  final hh = time.hour.toString().padLeft(2, '0');
                  final mm = time.minute.toString().padLeft(2, '0');
                  final hhmm = '$hh:$mm';

                  try {
                    await _repo.createReminderManual(
                      uid: _uid,
                      name: name.text.trim(),
                      dosage:
                          dosage.text.trim().isEmpty ? null : dosage.text.trim(),
                      instructions:
                          notes.text.trim().isEmpty ? null : notes.text.trim(),
                      repeat: repeat,
                      timeHHmm: hhmm,
                      timezone: timezone,
                      active: true,
                    );
                    if (mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reminder added')),
                    );
                  } catch (e, st) {
                    log.logE('Create reminder failed', e, st);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Could not create reminder')),
                    );
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
    extendBodyBehindAppBar: true,
    backgroundColor: Colors.transparent,
    body: Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFE8FDFB),
                Color(0xFFFDFEFF),
                Color(0xFFE3F7FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
          child: Container(color: Colors.white.withOpacity(0.15)),
        ),

        SafeArea(
          child: StreamBuilder<SympliUser?>(
            stream: _repo.userStream(_uid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final user = snap.data;
              if (user == null) {
                return const Center(child: Text('User not found'));
              }

              final age = (user.profile?['age'] as num?)?.toInt();
              final gender = user.profile?['gender']?.toString();
              final conditions =
                  (user.profile?['conditions'] as List?)?.cast<String>() ?? [];

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _glassCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: const Color(0xFF37B7A5),
                            backgroundImage: user.profileImage != null &&
                                    user.profileImage!.isNotEmpty
                                ? NetworkImage(user.profileImage!)
                                : null,
                            child: (user.profileImage == null ||
                                    user.profileImage!.isEmpty)
                                ? Text(
                                    (user.username ?? 'U')
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 26, color: Colors.white),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.username ?? '—',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email ?? '',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (gender != null && gender.isNotEmpty)
                                      _chip('Gender', gender),
                                    if (age != null) _chip('Age', '$age'),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                if (conditions.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  const Text(
                                    "Health Conditions",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: conditions.map((c) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF3B82F6).withOpacity(0.15),
                                              const Color(0xFF37B7A5).withOpacity(0.15),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(color: const Color(0xFF37B7A5).withOpacity(0.4)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF37B7A5).withOpacity(0.1),
                                              blurRadius: 6,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.health_and_safety_rounded,
                                                color: Color(0xFF37B7A5), size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                              c,
                                              style: const TextStyle(
                                                color: Color(0xFF0F172A),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],

                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF37B7A5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        onPressed: () async {
                          final updated = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => const EditProfileModal(),
                          );

                          if (updated == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('✅ Profile updated successfully')),
                            );
                            setState(() {});
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Medication Reminders',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Reminder'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF37B7A5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => _showAddReminderSheet(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  MedicationReminderList(
                    uid: _uid,
                    repo: _repo,
                    onEditTime: (r) => _pickNewTime(context, r),
                  ),

                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.45),
                Colors.white.withOpacity(0.25),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.2),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1CB5E0).withOpacity(0.15),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _chip(String k, String v) {
    return Chip(
      label: Text('$k: $v',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.5)),
      backgroundColor: Colors.white.withOpacity(0.6),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}
