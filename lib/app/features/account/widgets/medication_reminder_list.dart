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
          return const Center(child: CircularProgressIndicator());
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
          itemCount: reminders.length,
          itemBuilder: (context, i) {
            final r = reminders[i];

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        r.name.isNotEmpty ? r.name : 'Unnamed reminder',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (r.dosage != null && r.dosage!.isNotEmpty)
                            Text('Dosage: ${r.dosage}',
                                style: const TextStyle(fontSize: 13)),
                          if (r.instructions != null &&
                              r.instructions!.isNotEmpty)
                            Text('Notes: ${r.instructions}',
                                style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            'Repeat: ${r.repeat ?? '—'}  •  Time: ${r.time ?? '—'}  •  ${r.timezone ?? ''}',
                            style: const TextStyle(fontSize: 12, height: 1.2),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Switch(
                            value: r.active,
                            onChanged: (val) async {
                              try {
                                await repo.setActive(uid, r.id, val);
                              } catch (e, st) {
                                log.logE('Toggle failed', e, st);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Could not toggle reminder'),
                                  ),
                                );
                              }
                            },
                          ),
                          Text(
                            r.active ? 'Active' : 'Paused',
                            style: TextStyle(
                              fontSize: 11,
                              color: r.active ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding:
                          const EdgeInsets.only(left: 16, right: 8, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () => onEditTime?.call(r),
                            icon: const Icon(Icons.access_time, size: 18),
                            label: const Text('Change Time'),
                          ),
                          TextButton.icon(
                            onPressed: () => _editReminder(context, r),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit'),
                          ),
                          TextButton.icon(
                            onPressed: () => _confirmDelete(context, r),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remove'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
                                const SnackBar(
                                  content: Text('Reminder updated'),
                                ),
                              );
                            }
                          } catch (e, st) {
                            log.logE('Failed to update reminder', e, st);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not update reminder. Try again.',
                                  ),
                                ),
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
