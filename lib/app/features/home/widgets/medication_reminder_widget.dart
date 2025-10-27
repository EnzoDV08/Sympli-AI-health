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
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text("Error loading reminders", style: TextStyle(color: Colors.redAccent)),
          );
        }

        final reminders = snapshot.data ?? [];
        if (reminders.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "No medication reminders yet.",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          );
        }

        return SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: reminders.length,
            itemBuilder: (context, i) => _PremiumReminderCard(reminder: reminders[i]),
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

class _PremiumReminderCardState extends State<_PremiumReminderCard> with TickerProviderStateMixin {
  Duration? remaining;
  Timer? timer;
  late AnimationController glowCtrl;

  @override
  void initState() {
    super.initState();
    glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _updateRemaining();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    try {
      final time = widget.reminder.time;
      if (time == null || time.isEmpty) return;
      final now = DateTime.now();
      final parts = time.split(':');
      var next = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      if (next.isBefore(now)) next = next.add(const Duration(days: 1));
      setState(() => remaining = next.difference(now));
    } catch (_) {}
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
    final active = r.active ?? true;

    final gradient = _getAdaptiveGradient(time);
    final progress = remaining == null ? 0.0 : (1 - remaining!.inMinutes / (24 * 60)).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: glowCtrl,
      builder: (context, _) {
        return Container(
          width: 340,
          margin: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.last.withValues(alpha: 0.3 + 0.2 * glowCtrl.value),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.medication_liquid_rounded, color: Colors.white, size: 30),
                            const SizedBox(width: 8),
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          active ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.medication_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dosage,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (notes.isNotEmpty)
                                Text(
                                  notes,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time_filled, color: Colors.white, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              "$time • $repeat",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.timer_rounded, color: Colors.white70, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              _formatRemaining(remaining),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation(
                          Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ],
                ),
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
