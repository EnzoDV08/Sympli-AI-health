import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sympli_ai_health/app/features/chat_ai/model/diagnosis_log.dart';
import 'package:sympli_ai_health/app/utils/logging.dart';

class DiagnosisService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> saveMedicationReminder({
    required Map<String, dynamic> medicationData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      logW("saveMedicationReminder aborted: user not logged in", name: "DIAG");
      throw Exception("User not logged in");
    }

    try {
      final int frequencyHours = (medicationData['frequency_hours'] is num)
          ? (medicationData['frequency_hours'] as num).toInt()
          : int.tryParse(medicationData['frequency_hours'].toString()) ?? 0;

      final clean = <String, dynamic>{
        'name': (medicationData['name'] ?? '').toString(),
        'dosage': (medicationData['dosage'] ?? '').toString(),
        'frequency_hours': frequencyHours,
        'instructions': (medicationData['instructions'] ?? '').toString(),
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'active': true,
      };

      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('medication_reminders')
          .doc(); 

      clean['reminderId'] = docRef.id;

      logI(
        "Writing reminder → users/${user.uid}/medication_reminders/${docRef.id}",
        name: "DIAG",
      );
      logD("data: $clean", name: "DIAG");

      await docRef.set(clean);

      logI("✅ reminder saved id=${docRef.id}", name: "DIAG");
      return docRef.id;
    } catch (e, st) {
      logE("saveMedicationReminder failed", e, st, name: "DIAG");
      rethrow;
    }
  }

  Future<void> saveDiagnosis({
    required String title,
    required String description,
    required String aiResponse,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      logW("saveDiagnosis aborted: user not logged in", name: "DIAG");
      throw Exception("User not logged in");
    }

    try {
      final logData = {
        'userId': user.uid,
        'title': title,
        'description': description,
        'aiResponse': aiResponse,
        'loggedAt': FieldValue.serverTimestamp(),
      };

      logD("saveDiagnosis → users/${user.uid}/diagnosis_logs", name: "DIAG");
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('diagnosis_logs')
          .add(logData);

      logI("✅ diagnosis log saved", name: "DIAG");
    } catch (e, st) {
      logE("saveDiagnosis failed", e, st, name: "DIAG");
      rethrow;
    }
  }

  Stream<List<DiagnosisLog>> getUserLogs() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      logW("getUserLogs: no auth user; returning empty stream", name: "DIAG");
      return const Stream.empty();
    }

    logD("getUserLogs → users/$uid/diagnosis_logs (live stream)", name: "DIAG");

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('diagnosis_logs')
        .orderBy('loggedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      logD("diagnosis_logs snapshot: ${snapshot.docs.length} docs", name: "DIAG");
      return snapshot.docs.map((doc) {
        try {
          return DiagnosisLog.fromMap(doc.id, doc.data());
        } catch (e, st) {
          logE("parse DiagnosisLog failed (doc=${doc.id})", e, st, name: "DIAG");
          return DiagnosisLog.empty();
        }
      }).toList();
    });
  }

  Future<void> deleteLog(String logId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      logW("deleteLog aborted: no auth user", name: "DIAG");
      return;
    }

    try {
      logD("deleteLog → users/$uid/diagnosis_logs/$logId", name: "DIAG");
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('diagnosis_logs')
          .doc(logId)
          .delete();
      logI("🗑️ Log deleted: $logId", name: "DIAG");
    } catch (e, st) {
      logE("Failed to delete log: $logId", e, st, name: "DIAG");
    }
  }
}
