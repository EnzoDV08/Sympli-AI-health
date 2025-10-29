import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sympli_ai_health/app/features/account/services/profile_repository.dart';
import 'package:sympli_ai_health/app/utils/logging.dart' as log;

class MedicationReminderList extends StatelessWidget {
  final String uid;
  final ProfileRepository repo;
  final Function(MedicationReminder)? onEditTime;

  const MedicationReminderList({
    super.key,
    required this.uid,
    required this.repo,
    this.onEditTime,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MedicationReminder>>(
      stream: repo.remindersStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF37B7A5)));
        }

        final reminders = snapshot.data ?? const [];
        log.logI('📥 Loaded ${reminders.length} reminders for user $uid');

        if (reminders.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No medication reminders yet.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: reminders.length,
          itemBuilder: (context, i) {
            final r = reminders[i];
            return ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        r.active
                            ? Colors.white.withOpacity(0.45)
                            : Colors.white.withOpacity(0.25),
                        r.active
                            ? Colors.white.withOpacity(0.25)
                            : Colors.white.withOpacity(0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: r.active
                          ? Colors.white.withOpacity(0.4)
                          : Colors.white.withOpacity(0.2),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: r.active
                            ? const Color(0xFF1CB5E0).withOpacity(0.15)
                            : Colors.black12,
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF37B7A5), Color(0xFF1CB5E0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF37B7A5).withOpacity(0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.medication_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              r.name.isNotEmpty ? r.name : 'Unnamed Reminder',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: r.active ? Colors.black87 : Colors.black38,
                              ),
                            ),
                          ),

                            Switch(
                              value: r.active,
                              activeThumbColor: const Color(0xFF37B7A5),
                              onChanged: (val) async {
                                try {
                                  await repo.setActive(uid, r.id, val);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          val
                                              ? '✅ Reminder "${r.name}" activated'
                                              : '⏸️ Reminder "${r.name}" paused',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } catch (e, st) {
                                  log.logE('Toggle failed', e, st);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('❌ Could not toggle reminder'),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),

                        ],
                      ),

                      const SizedBox(height: 10),

                      if (r.dosage != null && r.dosage!.isNotEmpty)
                        Text('Dosage: ${r.dosage}',
                            style: const TextStyle(fontSize: 14, color: Colors.black87)),
                      if (r.instructions != null && r.instructions!.isNotEmpty)
                        Text('Notes: ${r.instructions}',
                            style: const TextStyle(fontSize: 14, color: Colors.black54)),
                      const SizedBox(height: 6),

                      Text(
                        'Repeat: ${r.repeat ?? '—'} • Time: ${r.time ?? '—'} • ${r.timezone ?? ''}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _footerButton(
                            context,
                            icon: Icons.access_time,
                            label: 'Change Time',
                            onPressed: () => onEditTime?.call(r),
                            color1: const Color(0xFF37B7A5),
                            color2: const Color(0xFF1CB5E0),
                          ),
                          _footerButton(
                            context,
                            icon: Icons.edit_rounded,
                            label: 'Edit',
                            onPressed: () => _editReminder(context, r),
                            color1: const Color(0xFF4F46E5),
                            color2: const Color(0xFF7C3AED),
                          ),
                          _footerButton(
                            context,
                            icon: Icons.delete_outline_rounded,
                            label: 'Remove',
                            onPressed: () => _confirmDelete(context, r),
                            color1: Colors.redAccent,
                            color2: Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _footerButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color1,
    required Color color2,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color1.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _editReminder(BuildContext context, MedicationReminder r) async {
    final nameController = TextEditingController(text: r.name);
    final dosageController = TextEditingController(text: r.dosage ?? '');
    final notesController = TextEditingController(text: r.instructions ?? '');
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Edit Reminder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: dosageController,
                      decoration: const InputDecoration(labelText: 'Dosage'),
                    ),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() => saving = true);
                          try {
                            await repo.updateReminder(uid, r.id, {
                              'name': nameController.text.trim(),
                              'dosage': dosageController.text.trim(),
                              'instructions': notesController.text.trim(),
                            });

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Reminder updated')),
                              );
                            }
                          } catch (e, st) {
                            log.logE('Failed to update reminder', e, st);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Could not update reminder. Try again.')),
                              );
                            }
                          } finally {
                            if (ctx.mounted) setState(() => saving = false);
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, MedicationReminder r) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: Text('Delete "${r.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                await repo.deleteReminder(uid, r.id);
                if (ctx.mounted) Navigator.pop(ctx, true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reminder deleted')),
                  );
                }
              } catch (e, st) {
                log.logE('Delete failed', e, st);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not delete reminder. Try again.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
