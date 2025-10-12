import 'package:cloud_firestore/cloud_firestore.dart';

class DiagnosisLog {
  String id;
  String userId;
  String title;
  String description;
  String aiResponse;
  DateTime loggedAt;
  DateTime nextCheckIn;
  String severity;
  List<String> symptoms;
  String medication;
  String note;

  DiagnosisLog({
    this.id = '',
    required this.userId,
    required this.title,
    required this.description,
    required this.aiResponse,
    required this.loggedAt,
    required this.nextCheckIn,
    this.severity = 'Mild',
    this.symptoms = const [],
    this.medication = 'None specified',
    this.note = '',
  });

  /// ✅ Convert DiagnosisLog object to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'aiResponse': aiResponse,
      'loggedAt': Timestamp.fromDate(loggedAt),
      'nextCheckIn': Timestamp.fromDate(nextCheckIn),
      'severity': severity,
      'symptoms': symptoms,
      'medication': medication,
      'note': note,
    };
  }

  /// ✅ Build model from Firestore map
  factory DiagnosisLog.fromMap(String id, Map<String, dynamic> map) {
    return DiagnosisLog(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      aiResponse: map['aiResponse'] ?? '',
      loggedAt: (map['loggedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nextCheckIn: (map['nextCheckIn'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 2)),
      severity: map['severity'] ?? 'Mild',
      symptoms: List<String>.from(map['symptoms'] ?? []),
      medication: map['medication'] ?? 'None specified',
      note: map['note'] ?? '',
    );
  }

  /// ✅ Fallback when Firestore data is incomplete or parsing fails
  factory DiagnosisLog.empty() {
    return DiagnosisLog(
      id: '',
      userId: '',
      title: 'Unknown',
      description: '',
      aiResponse: '',
      loggedAt: DateTime.now(),
      nextCheckIn: DateTime.now().add(const Duration(days: 2)),
      severity: 'Mild',
      symptoms: const [],
      medication: 'None specified',
      note: '',
    );
  }
}
