import 'package:sympli_ai_health/app/features/notifications/notification_manager.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sympli_ai_health/app/features/account/services/profile_repository.dart';

class MedicationReminderWidget extends StatefulWidget {
  const MedicationReminderWidget({super.key});

  @override
  State<MedicationReminderWidget> createState() =>
      _MedicationReminderWidgetState();
}

class _MedicationReminderWidgetState extends State<MedicationReminderWidget> {
  final _auth = FirebaseAuth.instance;
  final _repo = ProfileRepository();

  String get _uid => _auth.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "Please log in to view your medication reminders.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return StreamBuilder<List<dynamic>>(
      stream: _repo.remindersStream(_uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text("Error loading reminders",
                style: TextStyle(color: Colors.redAccent)),
          );
        }

        final allReminders = snapshot.data ?? [];
        final reminders = allReminders.where((r) => r.active == true).toList();

        if (reminders.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "No active medication reminders right now.",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          );
        }

        return SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: reminders.length,
            itemBuilder: (context, i) =>
                _PremiumReminderCard(reminder: reminders[i]),
          ),
        );
      },
    );
  }
}

class _PremiumReminderCard extends StatefulWidget {
  final dynamic reminder;
  const _PremiumReminderCard({required this.reminder});

  @override
  State<_PremiumReminderCard> createState() => _PremiumReminderCardState();
}

class _PremiumReminderCardState extends State<_PremiumReminderCard>
    with TickerProviderStateMixin {
  Duration? remaining;
  Timer? timer;
  bool timeReached = false;
  late AnimationController glowCtrl;
  final _repo = ProfileRepository();
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _updateRemaining();
    timer =
        Timer.periodic(const Duration(seconds: 5), (_) => _updateRemaining());
  }

void _updateRemaining() {
  try {
    final time = widget.reminder.time;
    if (time == null || time.isEmpty) return;

    final now = DateTime.now();
    final parts = time.split(':');
    var next = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    final diff = next.difference(now);

    if (!timeReached && diff.inSeconds.abs() < 30) {
      setState(() {
        timeReached = true;
      });
      _triggerReminderNotification();
    } else if (diff.inSeconds > 30 && timeReached) {
      setState(() => timeReached = false);
    } else {
      setState(() => remaining = diff);
    }
  } catch (_) {}
}


void _triggerReminderNotification() {
  final r = widget.reminder;
  final uniqueId = "${r.id}_${DateTime.now().day}"; 

  notificationManager.addNotification(
    "Time to take ${r.name ?? 'your medication'} 💊",
    "${r.dosage ?? ''} — ${r.instructions ?? 'Please follow your schedule.'}",
    uniqueId: uniqueId, 
  );
}

  void _remindAgain() {
    final r = widget.reminder;
    final uniqueId = "${r.id}_${DateTime.now().day}";
    notificationManager.resetTrigger(uniqueId);

    final snoozeTime = DateTime.now().add(const Duration(minutes: 10));
    setState(() {
      remaining = snoozeTime.difference(DateTime.now());
      timeReached = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🔔 Will remind again in 10 minutes."),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _removeReminder() async {
    final r = widget.reminder;
    try {
      final uid = _auth.currentUser?.uid ?? '';
      if (uid.isNotEmpty && r.id != null) {
        await _repo.deleteReminder(uid, r.id);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🗑 Removed ${r.name ?? 'reminder'}"),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error removing reminder: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    glowCtrl.dispose();
    timer?.cancel();
    super.dispose();
  }

  String _formatRemaining(Duration? d) {
    if (d == null) return "—";
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return "$h hr ${m.toString().padLeft(2, '0')} min";
    return "$m min";
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reminder;
    final name = r.name ?? "Medication";
    final dosage = r.dosage ?? "—";
    final notes = r.instructions ?? "";
    final time = r.time ?? "";
    final repeat = r.repeat ?? "once";
    final active = (r.active ?? true);
    if (!active) return const SizedBox.shrink();

    final gradient = _getAdaptiveGradient(time);
    final progress = remaining == null
        ? 0.0
        : (1 - remaining!.inMinutes / (24 * 60)).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: glowCtrl,
      builder: (context, _) {
        return Container(
          width: 320,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withOpacity(0.25), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.medication_rounded,
                              color: Colors.white, size: 26),
                          const SizedBox(width: 10),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        active
                            ? Icons.check_circle_rounded
                            : Icons.pause_circle_filled_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "$dosage ${notes.isNotEmpty ? '• $notes' : ''}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const Spacer(),

                  if (timeReached)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "💊 It’s time to take your medication!",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _remindAgain,
                              icon: const Icon(Icons.alarm_add_rounded,
                                  color: Colors.white),
                              label: const Text("Remind Again"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _removeReminder,
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.white),
                              label: const Text("Remove"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              "$time • $repeat",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.timer_rounded,
                                color: Colors.white70, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              _formatRemaining(remaining),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  LinearGradient _getAdaptiveGradient(String? time) {
    final hour = int.tryParse(time?.split(':').first ?? '12') ?? 12;
    if (hour >= 5 && hour < 11) {
      return const LinearGradient(
        colors: [Color(0xFFFFC371), Color(0xFFFF5F6D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (hour >= 11 && hour < 17) {
      return const LinearGradient(
        colors: [Color(0xFF3B5FFF), Color(0xFF52E3C2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (hour >= 17 && hour < 21) {
      return const LinearGradient(
        colors: [Color(0xFFFF758C), Color(0xFFFF7EB3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return const LinearGradient(
        colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }
}
