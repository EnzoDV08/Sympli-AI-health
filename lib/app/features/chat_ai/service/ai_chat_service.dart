import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sympli_ai_health/app/features/meds/services/med_reminder_service.dart';
import 'package:sympli_ai_health/app/features/chat_ai/service/diagnosis_service.dart';

class AIChatService {
  final String apiKey = dotenv.env['OPENAI_API_KEY']!;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final double inputCostPerMillion = 0.25;
  final double outputCostPerMillion = 2.00;
  final DiagnosisService _diagnosisService = DiagnosisService();

  // 🔍 Detects if user message requests a reminder
  bool _isReminderRequest(String msg) =>
      msg.toLowerCase().contains('remind me') ||
      (msg.toLowerCase().contains('take') && msg.toLowerCase().contains('hour'));

  // 🧠 Extract medication name, interval, and time context
  Map<String, dynamic> _extractMedInfo(String message) {
    final medRegex = RegExp(r"(take|use|drink)\s+([A-Za-z0-9]+)");
    final match = medRegex.firstMatch(message.toLowerCase());
    final medName = match != null ? match.group(2)!.capitalize() : "Medication";

    final intervalRegex = RegExp(r"(\d+)\s*(hour|hours|hrs)");
    final intervalMatch = intervalRegex.firstMatch(message.toLowerCase());
    final intervalHours =
        intervalMatch != null ? int.tryParse(intervalMatch.group(1)!) ?? 6 : 6;

    final lower = message.toLowerCase();
    String? timeContext;
    if (lower.contains("morning")) timeContext = "morning";
    if (lower.contains("afternoon")) timeContext = "afternoon";
    if (lower.contains("evening")) timeContext = "evening";
    if (lower.contains("before bed") || lower.contains("night"))
      timeContext = "night";

    return {"name": medName, "interval": intervalHours, "context": timeContext};
  }

  // 💊 Adds a medication to Firestore & schedules reminders
  Future<void> _addMedicationFromChat(
      String medName, int intervalHours, String? timeContext) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userDoc = _firestore.collection('users').doc(uid);
    final snap = await userDoc.get();
    final data = snap.data() ?? {};

    final profile = Map<String, dynamic>.from(data['profile'] ?? {});
    final List<String> meds = List<String>.from(profile['medications'] ?? []);
    final Map<String, dynamic> schedules =
        Map<String, dynamic>.from(profile['medicationSchedules'] ?? {});

    if (!meds.contains(medName)) meds.add(medName);

    // 🕐 Handle time context (morning, evening, etc.)
    TimeOfDay defaultTime = const TimeOfDay(hour: 8, minute: 0);
    if (timeContext == "morning") defaultTime = const TimeOfDay(hour: 8, minute: 0);
    if (timeContext == "afternoon") defaultTime = const TimeOfDay(hour: 14, minute: 0);
    if (timeContext == "evening") defaultTime = const TimeOfDay(hour: 18, minute: 0);
    if (timeContext == "night" || timeContext == "before bed") {
      defaultTime = const TimeOfDay(hour: 21, minute: 0);
    }

    schedules[medName] = {
      'repeat': intervalHours < 24 ? 'everyNHours' : 'everyN',
      'n': intervalHours,
      'time': '${defaultTime.hour}:${defaultTime.minute.toString().padLeft(2, '0')}',
      'days': [DateTime.now().weekday],
      'timezone': DateTime.now().timeZoneName,
    };

    await userDoc.set({
      'profile': {
        'medications': meds,
        'medicationSchedules': schedules,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 🔔 Schedule the reminder
    final baseId = medName.hashCode.abs() % 2147483647;
    await medReminderService.cancelAllFor(baseId);

    if (intervalHours < 24) {
      await medReminderService.scheduleEveryNHours(
        baseId: baseId,
        title: 'Take $medName 💊',
        body: 'It’s time to take your $medName dose.',
        hours: intervalHours,
      );
      print("✅ Scheduled $medName every $intervalHours hours");
    } else {
      await medReminderService.scheduleEveryNDays(
        baseId: baseId,
        title: 'Take $medName 💊',
        body: 'It’s time for your $medName dose.',
        timeOfDay: defaultTime,
        n: (intervalHours / 24).ceil().clamp(1, 30),
        horizonDays: 90,
      );
      print("✅ Scheduled $medName daily at ${defaultTime.hour}:${defaultTime.minute}");
    }
  }

  // 🩺 Logs symptoms to Firestore profile
  Future<void> _logSymptomFromChat(String message) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final symptoms = _extractSymptoms(message);
    if (symptoms.isEmpty) return;

    await _firestore.collection('users').doc(uid).update({
      'profile.conditions': FieldValue.arrayUnion(symptoms),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    print("🩺 Logged symptoms: $symptoms");
  }

  // 💬 Core AI + reminder + diagnosis logic
  Future<String> sendMessageWithContext(
      String userMessage, List<Map<String, dynamic>> history) async {
    const apiUrl = 'https://api.openai.com/v1/chat/completions';

    try {
      // 💊 1️⃣ Reminder creation
      if (_isReminderRequest(userMessage)) {
        final info = _extractMedInfo(userMessage);
        final medName = info['name'];
        final interval = info['interval'];
        final context = info['context'];

        await _addMedicationFromChat(medName, interval, context);

        final readableTime =
            context != null ? "in the $context" : "every $interval hour(s)";
        final aiResponse =
            "✅ I've added *$medName* to your plan and scheduled reminders $readableTime. "
            "You’ll be notified automatically 💊";

        await _diagnosisService.saveDiagnosis(
          title: "Medication Reminder",
          description: "User requested reminder for $medName $readableTime.",
          aiResponse: aiResponse,
        );
        return aiResponse;
      }

      // 🤒 2️⃣ Symptom detection
      if (_extractSymptoms(userMessage).isNotEmpty) {
        await _logSymptomFromChat(userMessage);
        await _diagnosisService.saveDiagnosis(
          title: "Symptom Report",
          description: userMessage,
          aiResponse:
              "I've logged your reported symptoms and will check in again tomorrow 💚",
        );
      }

      // 🧠 3️⃣ Normal AI conversation
      final userId = _auth.currentUser?.uid;
      Map<String, dynamic>? profileData;
      if (userId != null) {
        final doc = await _firestore.collection('users').doc(userId).get();
        profileData = doc.data()?['profile'];
      }

      final conditions = (profileData?['conditions'] ?? []).join(', ');
      final allergies = (profileData?['allergies'] ?? []).join(', ');
      final meds = (profileData?['medications'] ?? []).join(', ');

      final profileSummary = """
      User health summary:
      • Conditions: $conditions
      • Allergies: $allergies
      • Medications: $meds
      """;

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "temperature": 0.65,
          "max_tokens": 400,
          "messages": [
            {
              "role": "system",
              "content": """
              You are Dr Sympli — a compassionate digital nurse.
              Use the following profile context to personalize advice:
              $profileSummary

              Guidelines:
              - Speak warmly and clearly.
              - If user mentions pain or sickness, give short, safe tips (3–6 sentences).
              - Never create reminders here; they are handled internally.
              - End kindly, e.g. “I’ll check in soon to see how you’re doing 💚.”
              """
            },
            ...history,
            {"role": "user", "content": userMessage},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiReply = data['choices'][0]['message']['content'].trim();

        // 🧾 Log the chat
        await _logChatToFirestore(userMessage, aiReply, data);

        // 🩺 Create a check-in entry
        await _diagnosisService.saveDiagnosis(
          title: "AI Health Check-In",
          description: userMessage,
          aiResponse: aiReply,
        );

        return aiReply;
      } else {
        print('❌ API error: ${response.statusCode} – ${response.body}');
        return '⚠️ Something went wrong (code ${response.statusCode}).';
      }
    } catch (e) {
      print('🚫 Exception in sendMessageWithContext: $e');
      return '🚫 Connection error. Please check your network.';
    }
  }

  // 🧾 Store AI chat with cost tracking
  Future<void> _logChatToFirestore(
      String userMessage, String aiReply, Map<String, dynamic> data) async {
    try {
      final userId = _auth.currentUser?.uid ?? 'anonymous';
      final totalTokens = data['usage']?['total_tokens'] ?? 0;
      final inputTokens = data['usage']?['prompt_tokens'] ?? 0;
      final outputTokens = data['usage']?['completion_tokens'] ?? 0;
      final inputCost = (inputTokens / 1e6) * inputCostPerMillion;
      final outputCost = (outputTokens / 1e6) * outputCostPerMillion;
      final totalCostUSD = inputCost + outputCost;
      final totalCostZAR = totalCostUSD * 18.5;

      await _firestore.collection('chatMessages').add({
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'userMessage': userMessage,
        'aiReply': aiReply,
        'tokensUsed': totalTokens,
        'costUSD': totalCostUSD,
        'costZAR': totalCostZAR,
      });
    } catch (e) {
      print('⚠️ Failed to log chat: $e');
    }
  }
}

extension StringCasing on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

List<String> _extractSymptoms(String userMessage) {
  final text = userMessage.toLowerCase();
  final possible = [
    'cough',
    'fever',
    'headache',
    'pain',
    'nausea',
    'sore throat',
    'fatigue',
    'dizziness',
    'rash',
    'shortness of breath'
  ];
  return possible.where((s) => text.contains(s)).toList();
}
