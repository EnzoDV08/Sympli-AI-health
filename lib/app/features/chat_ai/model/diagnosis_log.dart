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
    this.severity = 'Unknown',
    this.symptoms = const [],
    this.medication = 'None',
    this.note = '',
  });

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

  factory DiagnosisLog.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseTimestamp(dynamic value, {Duration? fallbackOffset}) {
      if (value is Timestamp) {
        return value.toDate();
      }
      return DateTime.now().add(fallbackOffset ?? Duration.zero);
    }

    return DiagnosisLog(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? 'No Title',
      description: map['description'] ?? '',
      aiResponse: map['aiResponse'] ?? '',
      loggedAt: parseTimestamp(map['loggedAt']),
      nextCheckIn: parseTimestamp(map['nextCheckIn'], fallbackOffset: const Duration(days: 1)),
      severity: map['severity'] ?? 'Unknown',
      symptoms: List<String>.from(map['symptoms'] ?? []),
      medication: map['medication'] ?? 'None',
      note: map['note'] ?? '',
    );
  }

  factory DiagnosisLog.empty() {
    return DiagnosisLog(
      id: '',
      userId: '',
      title: 'Empty Log',
      description: '',
      aiResponse: '',
      loggedAt: DateTime.now(),
      nextCheckIn: DateTime.now().add(const Duration(days: 1)),
    );
  }
}