import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sympli_ai_health/app/features/chat_ai/service/diagnosis_service.dart';
import 'package:sympli_ai_health/app/features/chat_ai/model/diagnosis_log.dart';
import 'package:sympli_ai_health/app/features/logs/widgets/log_card.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  Color _severityColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'high':
      case 'critical':
        return Colors.redAccent;
      case 'medium':
        return Colors.orangeAccent;
      case 'low':
        return Colors.greenAccent;
      default:
        return const Color(0xFF37B7A5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = DiagnosisService();

    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF37B7A5),
        icon: const Icon(Icons.share_rounded, color: Colors.white),
        label: const Text("Export Logs"),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("📤 Export feature coming soon!"),
              backgroundColor: Color(0xFF37B7A5),
            ),
          );
        },
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F9F7), Color(0xFFF6F8FB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<DiagnosisLog>>(
            stream: service.getUserLogs(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF37B7A5)),
                );
              }

              final logs = snapshot.data!;
              if (logs.isEmpty) {
                return _emptyState(context);
              }

              final latest = logs.first;
              final totalLogs = logs.length;
              final upcoming = logs
                  .where((l) => l.nextCheckIn.isAfter(DateTime.now()))
                  .length;

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding:
                          const EdgeInsets.only(left: 20, bottom: 16, right: 20),
                      title: const Text(
                        "Health Logs",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.filter_list_rounded,
                            color: Colors.black87),
                        onPressed: () {},
                      ),
                    ],
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _summaryHeader(
                          latest, totalLogs, upcoming, _severityColor),
                    ),
                  ),

                  SliverList.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return AnimatedOpacity(
                        opacity: 1,
                        duration: Duration(milliseconds: 200 + (index * 80)),
                        child: LogCard(
                          log: log,
                          color: _severityColor(log.severity),
                          onViewDetails: () => _showLogDetails(context, log),
                          onUploadMedicine: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "💊 Upload medicine photo feature coming soon!"),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _summaryHeader(DiagnosisLog latest, int total, int upcoming,
      Color Function(String?) severityColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF37B7A5).withOpacity(0.9),
                const Color(0xFF29A89C).withOpacity(0.7)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 4))
            ],
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Your Health Overview",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _summaryBox(Icons.analytics, "$total Logs", "Saved Records"),
                  const SizedBox(width: 12),
                  _summaryBox(Icons.alarm, "$upcoming", "Upcoming Check-ins"),
                  const SizedBox(width: 12),
                  _summaryBox(Icons.favorite,
                      latest.severity ?? "Good", "Current Status",
                      color: severityColor(latest.severity)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryBox(IconData icon, String title, String subtitle,
      {Color color = Colors.white}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              subtitle,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medical_information_rounded,
                size: 90, color: Color(0xFF37B7A5)),
            const SizedBox(height: 20),
            const Text(
              "No diagnosis logs yet 🩶",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87),
            ),
            const SizedBox(height: 10),
            const Text(
              "Start a chat with Sympli AI to log your first check-in and get personalized insights.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/chat-ai'),
              icon: const Icon(Icons.chat_rounded),
              label: const Text("Open Sympli Chat"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF37B7A5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogDetails(BuildContext context, DiagnosisLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.monitor_heart_rounded,
                      color: _severityColor(log.severity), size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      log.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Severity: ${log.severity}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Divider(height: 24),
              const Text("Symptoms:",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: log.symptoms
                    .map((s) => Chip(
                          label: Text(s),
                          backgroundColor:
                              const Color(0xFF37B7A5).withOpacity(0.2),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              Text(
                "Medication: ${log.medication.isNotEmpty ? log.medication : "Not specified"}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                "Notes: ${log.note.isNotEmpty ? log.note : "No notes provided"}",
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.timer_rounded,
                      size: 18, color: Color(0xFF37B7A5)),
                  const SizedBox(width: 6),
                  Text(
                    "Next Check-In: ${DateFormat('MMM d, hh:mm a').format(log.nextCheckIn)}",
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF37B7A5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded,
                      color: Colors.white),
                  label: const Text(
                    "Check-In Now",
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/chat-ai');
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
