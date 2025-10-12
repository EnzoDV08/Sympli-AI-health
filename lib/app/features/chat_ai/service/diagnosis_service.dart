import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sympli_ai_health/app/features/chat_ai/model/diagnosis_log.dart';
import 'package:sympli_ai_health/app/features/meds/services/med_reminder_service.dart';

String _extractSeverity(String aiReply) {
  final lower = aiReply.toLowerCase();
  if (lower.contains('mild')) return 'Mild';
  if (lower.contains('moderate')) return 'Moderate';
  if (lower.contains('severe') || lower.contains('serious')) return 'Severe';
  return 'Unknown';
}

List<String> _extractSymptoms(String userMessage) {
  final text = userMessage.toLowerCase();
  final possible = [
    'cough', 'fever', 'headache', 'pain', 'nausea', 'sore throat',
    'fatigue', 'dizziness', 'rash', 'shortness of breath'
  ];
  return possible.where((s) => text.contains(s)).toList();
}

class DiagnosisService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _reminderService = medReminderService;

  Future<void> saveDiagnosis({
    required String title,
    required String description,
    required String aiResponse,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      final logData = {
        'userId': user.uid,
        'title': title,
        'description': description,
        'aiResponse': aiResponse,
        'severity': _extractSeverity(aiResponse),
        'symptoms': _extractSymptoms(description),
        'medication': '',
        'note': '',
        'loggedAt': FieldValue.serverTimestamp(),
        'nextCheckIn': DateTime.now().add(const Duration(days: 1)),
        'reminderSuggested': aiResponse.toLowerCase().contains('remind') ||
                            aiResponse.toLowerCase().contains('check in'),
      };


      final docRef = await _firestore.collection('diagnosis_logs').add(logData);

      final log = DiagnosisLog.fromMap(docRef.id, {
        ...logData,
        'loggedAt': Timestamp.now(),
        'nextCheckIn': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 1)),
        ),
      });


      try {
        await _reminderService.scheduleCheckIn(log);
      } catch (e) {
        print("⚠️ Reminder scheduling failed: $e");
      }

      print("✅ Diagnosis log saved successfully for ${user.email}");
    } catch (e, stack) {
      print("⚠️ Error saving diagnosis: $e");
      print(stack);
      rethrow;
    }
  }

  Stream<List<DiagnosisLog>> getUserLogs() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    try {
      return _firestore
          .collection('diagnosis_logs')
          .where('userId', isEqualTo: uid)
          .orderBy('loggedAt', descending: true)
          .snapshots()
          .map((snapshot) {
        final logs = snapshot.docs.map((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            return DiagnosisLog.fromMap(doc.id, data);
          } catch (e) {
            print("⚠️ Error parsing diagnosis log: $e");
            return DiagnosisLog.empty();
          }
        }).toList();

        print("📊 Loaded ${logs.length} logs for user $uid");
        return logs;
      });
    } catch (e) {
      print("⚠️ Firestore stream error: $e");
      return const Stream.empty();
    }
  }

  Future<void> deleteLog(String logId) async {
    try {
      await _firestore.collection('diagnosis_logs').doc(logId).delete();
      print("🗑️ Log deleted: $logId");
    } catch (e) {
      print("⚠️ Failed to delete log: $e");
    }
  }
}
