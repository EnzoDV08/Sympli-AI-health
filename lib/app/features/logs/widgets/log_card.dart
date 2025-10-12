import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sympli_ai_health/app/features/chat_ai/model/diagnosis_log.dart';

class LogCard extends StatelessWidget {
  final DiagnosisLog log;
  final VoidCallback? onViewDetails;
  final VoidCallback? onUploadMedicine;
  final Color? color;

  const LogCard({
    super.key,
    required this.log,
    this.onViewDetails,
    this.onUploadMedicine,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? const Color(0xFF37B7A5);
    final timeLeft = log.nextCheckIn.difference(DateTime.now());
    final formattedTime =
        timeLeft.isNegative ? "Due now" : _formatDuration(timeLeft);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFEAF9F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.1),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🩺 Title + Severity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.health_and_safety_rounded,
                  color: themeColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  log.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _severityColor(log.severity),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  log.severity.isNotEmpty ? log.severity : "Normal",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            "Logged: ${DateFormat('MMM d, yyyy • h:mm a').format(log.loggedAt)}",
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          Text(
            "Next Check-In: ${DateFormat('MMM d, yyyy • h:mm a').format(log.nextCheckIn)}",
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 12),

          // 🧩 SYMPTOMS
          if (log.symptoms.isNotEmpty) ...[
            const Text(
              "Symptoms:",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: log.symptoms
                  .map(
                    (s) => Chip(
                      label: Text(s),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      backgroundColor: themeColor.withOpacity(0.85),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],

          // 💬 USER MESSAGE (DESCRIPTION)
          if (log.description.isNotEmpty) ...[
            const Text(
              "User Report:",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              log.description,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 🤖 AI RESPONSE
          if (log.aiResponse.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                log.aiResponse,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF333333),
                  height: 1.5,
                ),
              ),
            ),

          const SizedBox(height: 14),

          // 💊 MEDICATION
          if (log.medication.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x11000000),
                      blurRadius: 8,
                      offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.medication_rounded, color: themeColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      log.medication,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  Text(
                    formattedTime,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: timeLeft.isNegative
                          ? Colors.redAccent
                          : const Color(0xFF3B5FFF),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // ⚙️ ACTION BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _glassButton(
                icon: Icons.visibility_rounded,
                label: "View Details",
                color: themeColor,
                onPressed: onViewDetails,
              ),
              _glassButton(
                icon: Icons.upload_rounded,
                label: "Upload",
                color: const Color(0xFF3B5FFF),
                onPressed: onUploadMedicine,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _glassButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'severe':
        return Colors.redAccent;
      case 'moderate':
        return Colors.orangeAccent;
      case 'mild':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours >= 1) {
      final h = duration.inHours;
      final m = duration.inMinutes.remainder(60);
      return "${h}H ${m}M";
    } else {
      return "${duration.inMinutes}M";
    }
  }
}
