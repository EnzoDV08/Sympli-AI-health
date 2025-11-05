import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sympli_ai_health/app/utils/logging.dart';
import 'package:sympli_ai_health/app/features/chat_ai/service/ai_persistence_service.dart';
import 'package:sympli_ai_health/app/features/chat_ai/service/reminder_commit_service.dart';

  class AIResponse {
    final String text;
    final Map<String, dynamic>? medicationProposal;

    AIResponse({required this.text, this.medicationProposal});
  }

  class AIChatService {
    final String apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    final _firestore = FirebaseFirestore.instance;
    final _auth = FirebaseAuth.instance;
    final ReminderCommitService _reminderCommitService = ReminderCommitService();
    final AIPersistenceService _persistenceService = AIPersistenceService();

    Map<String, dynamic>? _activeReminderContext;

    static const String _openAiUrl = 'https://api.openai.com/v1/chat/completions';

    Future<AIResponse> sendMessage(String text, {String? chatId}) async {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        logW("sendMessage aborted: user not logged in", name: "AI");
        return AIResponse(text: "User not logged in.", medicationProposal: null);
      }
      if (apiKey.isEmpty) {
        logW("sendMessage aborted: OPENAI_API_KEY missing", name: "AI");
        return AIResponse(
          text: "Server not configured.",
          medicationProposal: null,
        );
      }
      _activeReminderContext = await _persistenceService.loadReminderContext();

      final normalizedMsg = _normalizeScheduleWords(text);
      logI("➡️ sendMessage(uid=$uid): $normalizedMsg", name: "AI");

      final expandedMsg = normalizedMsg.toLowerCase().trim();
      String contextualMsg = normalizedMsg;
      if (RegExp(r'^\d+\s*(pills?|tabs?|mg|ml)?$').hasMatch(expandedMsg)) {
        contextualMsg = "The dosage is $normalizedMsg.";
      }

      await _saveMessage(uid, "user", contextualMsg);

      final history = (await _getChatHistory(uid)).take(6).toList();
      final lastAiMessage = await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();

      Map<String, dynamic>? memory;
      if (lastAiMessage.docs.isNotEmpty) {
        final lastChatId = lastAiMessage.docs.first.id;
        final messagesSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('chats')
            .doc(lastChatId)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (messagesSnap.docs.isNotEmpty) {
          final data = messagesSnap.docs.first.data();
          if (data['structured_data'] is Map) {
            memory = Map<String, dynamic>.from(data['structured_data']);
            logI(
              "🧠 Loaded structured context: ${jsonEncode(memory)}",
              name: "AI",
            );
          }
        }
      }

      logD("Fetched ${history.length} history messages", name: "AI");

      final systemPrompt = '''
        You are Sympli — a caring, precise AI nurse assistant that helps users manage medications, answer questions, and save reminders safely.

        ---

        ## 🔹 YOUR PERSONALITY & GOALS

        You act like a friendly digital nurse: calm, warm, and reassuring.  
        When users describe pain, illness, or symptoms, you respond with empathy — show care first, then ask helpful follow-up questions. 
        You understand everyday language — even when users talk casually or out of order.  
        You always:
        - Help users create or manage medication reminders.
        - Ask for missing details one at a time, without repeating yourself.
        - Remember what has already been said (using structured data from previous messages).
        - Stay polite and short.
        - Use simple, human language (grade 8–10).

        If a user says something unrelated (e.g., “How are you?” or “Tell me a joke”), you can respond naturally but then gently guide back to your purpose.

        Example:  
        > "Haha, I’m not great with jokes 😄 — but I can help you set or understand your medication reminders!"

        ---

        ## 🔹 THINKING RULES (HOW YOU PROCESS CONTEXT)

        1. Treat every conversation as a continuing session — always reuse previously known data (from structured messages).
        2. If a field (like name, dosage, or time) already exists in structured_data, do **not** ask for it again.
        3. Ask for **only one missing field at a time**.
        4. If something is ambiguous, politely clarify — e.g. “4 pills” means dosage = “4 pills”.
        5. Once all required data is known, finalize a reminder exactly once (do not re-propose unless user edits).
        6. When the user mentions a new medication name, start a new reminder conversation.
        7. Respond naturally if the user thanks you or makes small talk.

        ---

        ## 🔹 WHAT YOU NEED TO COLLECT

        For every medication reminder:
        - **name** (string) – medicine name  
        - **dosage** (string) – e.g. “500 mg”, “2 tablets”  
        - **instructions** (string) – e.g. “with food”, or “None”  
        - **schedule** (object):  
          - `{ "type": "daily", "time": "HH:mm", "timezone": "SAST" }`  
          - `{ "type": "weekly", "time": "HH:mm", "days": ["Mon","Wed"], "timezone": "SAST" }`  
          - `{ "type": "everyN", "time": "HH:mm", "n": 2, "timezone": "SAST" }`  
          - `{ "type": "everyNHours", "hours": 6, "timezone": "SAST" }`  

        ---

        ## 🔹 JSON RESPONSE FORMAT

        You must always respond with clean JSON only (no extra text).  
        Format:

        {
          "action": "GREET_USER" | "ANSWER_GENERAL_QUESTION" | "CONTINUE_CONVERSATION" | "PROPOSE_REMINDER" | "SMALL_TALK" | "SAFETY_REDIRECT" | "ASSESS_SYMPTOMS",
          "response_text": "friendly natural reply for the user",
          "medication_proposal": {
            "name": "string or null",
            "dosage": "string or null",
            "instructions": "string or null",
            "schedule": {
              "type": "daily" | "weekly" | "everyN" | "everyNHours" | null,
              "time": "HH:mm or null",
              "timezone": "SAST",
              "days": ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"],
              "n": 2,
              "hours": 6
            }
          }
        }

        ---

        ## 🔹 BEHAVIOR LOGIC (FOR EACH ACTION)

        ### 🟢 GREET_USER  
        Triggered by greetings like “hi”, “hello”, “good morning”.  
        Friendly and short:
        > “Hi there 👋 I’m Sympli, your health assistant. How can I help today?”

        ---

        ### 💬 SMALL_TALK  
        Triggered by: thanks, jokes, emotional replies, or short talk.  
        > “You’re very welcome 💛! Need help managing your medication today?”

        ---

        ### 🩺 ANSWER_GENERAL_QUESTION  
        Triggered by health-related or medication questions.  
        > “Paracetamol helps relieve mild pain or fever. Always follow your doctor’s instructions.”

        ---

        ### 🤒 ASSESS_SYMPTOMS  
        Triggered when the user describes not feeling well or mentions symptoms (e.g., headache, fever, cough, dizziness, nausea, sore throat, stomach pain, tiredness, chest tightness, etc.).

        You must:
        1. **Ask smart follow-up questions** based on the symptoms described — one question at a time.  
          - Example: “Do you also have a fever?” / “How long have you felt this way?”
        2. Use empathy and reassurance — sound like a nurse who cares.  
          - Example: “I’m sorry you’re not feeling great 💛. Let’s figure out what’s going on.”
        3. **Give gentle self-care tips** where safe — hydration, rest, warm soup, over-the-counter care.  
        4. **Never diagnose**.  
        5. **Always remind** to seek a doctor or clinic if symptoms are serious, persistent, or unclear.

        ---

        ### ⚕️ Example flows

        **User:** “I have a headache and fever.”  
        →  
        {
          "action": "ASSESS_SYMPTOMS",
          "response_text": "That sounds uncomfortable 😔. Do you also have body aches or a sore throat?",
          "medication_proposal": null
        }

        **User:** “Yes, my throat is sore.”  
        →  
        {
          "action": "ASSESS_SYMPTOMS",
          "response_text": "That might be a mild infection or cold. Drink warm fluids and rest your voice. If your fever continues, please see a doctor soon.",
          "medication_proposal": null
        }

        **User:** “I feel dizzy.”  
        →  
        {
          "action": "ASSESS_SYMPTOMS",
          "response_text": "I’m sorry you’re feeling dizzy 😔. Have you been eating and drinking normally today?",
          "medication_proposal": null
        }

        ---

        ### 🔁 CONTINUE_CONVERSATION  
        Triggered when more info is needed to complete reminder setup.  
        Ask for **only the next missing item**.  
        > “Got it! What time should I remind you to take it?”

        ---

        ### 💊 PROPOSE_REMINDER  
        Triggered once all required fields are complete.  
        > “Perfect! I’ll prepare a reminder for Mypaid 20mg every morning at 08:00.”

        ---

        ### ⚠️ SAFETY_REDIRECT  
        Triggered by potentially unsafe questions.  
        > “That sounds serious — please contact a doctor or pharmacist immediately.”

        ---

        ## 🔹 SPECIAL RULES

        - Do not repeat questions for fields you already know.
        - Always reuse known info from previous assistant messages.
        - Be context-aware: interpret user intent even if phrased differently.
        - Respond naturally, clearly, and politely.
        - When user says something incomplete, infer as much as possible but still ask precisely what’s missing.
        - Always guide the user back to finishing a valid reminder.

        ---

        ## 🔹 EXAMPLES

        **User:** “Can you remind me to take my medicine?”  
        →  
        {
          "action": "CONTINUE_CONVERSATION",
          "response_text": "Of course 😊 What’s the name of your medicine?",
          "medication_proposal": null
        }

        **User:** “It’s called Mypaid.”  
        →  
        {
          "action": "CONTINUE_CONVERSATION",
          "response_text": "Got it! What dosage of Mypaid do you take?",
          "medication_proposal": { "name": "Mypaid" }
        }

        **User:** “4 pills.”  
        →  
        {
          "action": "CONTINUE_CONVERSATION",
          "response_text": "Thanks! When should I remind you to take your 4 pills of Mypaid?",
          "medication_proposal": { "name": "Mypaid", "dosage": "4 pills" }
        }

        **User:** “At 8am.”  
        →  
        {
          "action": "PROPOSE_REMINDER",
          "response_text": "Perfect! I’ll save a reminder for Mypaid — 4 pills at 08:00 daily.",
          "medication_proposal": {
            "name": "Mypaid",
            "dosage": "4 pills",
            "instructions": "None",
            "schedule": { "type": "daily", "time": "08:00", "timezone": "SAST" }
          }
        }
        ''';

      final contextReminder = _activeReminderContext != null
          ? "Current known reminder details: ${jsonEncode(_activeReminderContext)}"
          : (memory != null
                ? "Current known reminder details: ${jsonEncode(memory)}"
                : "No previous reminder data stored yet.");

      final messages = [
        {"role": "system", "content": "$systemPrompt\n\n$contextReminder"},
        ...history,
        {"role": "user", "content": normalizedMsg},
      ];

      final requestMap = {
        "model": "gpt-4o-mini",
        "messages": messages,
        "temperature": text.length < 20 ? 0.4 : 0.2,
        "response_format": {"type": "json_object"},
      };

      final body = jsonEncode(requestMap);
      logD("POST $_openAiUrl (bytes=${body.length})", name: "AI");

      try {
        final sw = Stopwatch()..start();
        final response = await http.post(
          Uri.parse(_openAiUrl),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $apiKey",
          },
          body: body,
        );
        sw.stop();
        logI(
          "OpenAI status=${response.statusCode} in ${sw.elapsedMilliseconds}ms",
          name: "AI",
        );

        if (response.statusCode != 200) {
          logW("OpenAI error body: ${response.body}", name: "AI");
          return AIResponse(
            text: "AI Error: ${response.statusCode}",
            medicationProposal: null,
          );
        }

        final data = jsonDecode(response.body);
        final content =
            (data['choices'][0]['message']['content'] ?? '') as String;
        final preview = content.substring(0, math.min(400, content.length));
        logD("OpenAI content[0..400]: $preview", name: "AI");

        final extracted = _extractJson(content);
        logD("extracted json raw: ${jsonEncode(extracted)}", name: "AI");
        logD("extracted json: ${extracted ?? 'null'}", name: "AI");

        if (extracted?['medication_proposal'] is Map &&
            (extracted!['medication_proposal'] as Map).isNotEmpty) {
          _activeReminderContext = {
            ...?_activeReminderContext,
            ...Map<String, dynamic>.from(extracted['medication_proposal']),
          };
          logI(
            "🧠 Updated reminder context: ${jsonEncode(_activeReminderContext)}",
            name: "AI",
          );
        }

if (extracted?['action'] == 'CONTINUE_CONVERSATION' &&
    extracted?['medication_proposal'] is Map &&
    (extracted!['medication_proposal'] as Map).isNotEmpty) {
  try {
    final proposal = Map<String, dynamic>.from(extracted['medication_proposal']);

    if (proposal['schedule'] is Map) {
      final sched = Map<String, dynamic>.from(proposal['schedule']);
      if (sched['time'] == null || sched['time'].toString().isEmpty) {
        final now = DateTime.now();
        final hour = now.hour.toString().padLeft(2, '0');
        final minute = now.minute.toString().padLeft(2, '0');
        sched['time'] = "$hour:$minute";
        logI("🕒 Injected time before commit: ${sched['time']}", name: "AI");
      } else {
        logI("✅ AI-specified time found before commit: ${sched['time']}", name: "AI");
      }
      sched['timezone'] = sched['timezone'] ?? "SAST";
      proposal['schedule'] = sched;
    }

    await _reminderCommitService.commitMedicationProposal(proposal);
    logI("🧠 Partial reminder progress saved (with time).", name: "AI");
  } catch (e) {
    logW("Failed to save partial reminder: $e", name: "AI");
  }
}

if (extracted?['action'] == 'PROPOSE_REMINDER' &&
    extracted?['medication_proposal'] is Map &&
    (extracted!['medication_proposal'] as Map).isNotEmpty) {
  try {
    final proposal = Map<String, dynamic>.from(extracted['medication_proposal']);

    if (proposal['schedule'] is Map) {
      final sched = Map<String, dynamic>.from(proposal['schedule']);

      if (sched['time'] == null || sched['time'].toString().trim().isEmpty) {
        final now = DateTime.now();
        sched['time'] =
            "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
        logI("🕒 Injected fallback time: ${sched['time']}", name: "AI");
      } else {
        logI("✅ AI provided time: ${sched['time']}", name: "AI");
      }

      sched['timezone'] ??= "SAST";
      proposal['schedule'] = sched;
    } else {
      logW("⚠️ Missing schedule map in proposal", name: "AI");
    }

    await _reminderCommitService.commitMedicationProposal(proposal);
    logI("💾 Final reminder saved to Firestore (PROPOSE_REMINDER).", name: "AI");
  } catch (e, st) {
    logE("❌ Failed to save final reminder", e, st, name: "AI");
  }
}

        final aiReply =
            extracted?['response_text'] ??
            "Sorry, I had a problem processing that.";

        await _saveMessage(uid, "ai", aiReply, aiData: extracted);

        final act = (extracted?['action'] as String? ?? '');
        if (act == 'ASSESS_SYMPTOMS') {
          logI("🤒 AI entered symptom-assessment mode", name: "AI");

          final reply =
              extracted?['response_text'] ??
              "I’m sorry you’re not feeling well 😔. Can you describe what symptoms you have?";

          await _saveMessage(uid, "ai", reply, aiData: extracted);

          return AIResponse(text: reply, medicationProposal: null);
        }
        final hasProposalMap =
            extracted?['medication_proposal'] is Map &&
            (extracted!['medication_proposal'] as Map).isNotEmpty;

        logI("Action=$act hasProposalMap=$hasProposalMap", name: "AI");

        Map<String, dynamic>? proposal;
        if (hasProposalMap) {
          proposal = Map<String, dynamic>.from(
            extracted['medication_proposal'] as Map,
          );
        }
if (proposal != null && proposal['schedule'] is Map) {
  final sched = Map<String, dynamic>.from(proposal['schedule']);

  // if no valid time, default to NOW (local)
  if (sched['time'] == null || sched['time'].toString().isEmpty) {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    sched['time'] = "$hour:$minute";
    logI("🕒 Injected local time: ${sched['time']}", name: "AI");
  } else {
    logI("✅ AI-specified time found: ${sched['time']}", name: "AI");
  }

  // ensure timezone always exists
  sched['timezone'] = sched['timezone'] ?? "SAST";

  // update proposal back
  proposal['schedule'] = sched;
}

        return AIResponse(text: aiReply, medicationProposal: proposal);
      } catch (e, st) {
        logE("❌ Error in sendMessage", e, st, name: "AI");
        return AIResponse(
          text: "Sorry, an error occurred.",
          medicationProposal: null,
        );
      }
    }

    Future<List<Map<String, String>>> _getChatHistory(String uid) async {
      try {
        logD("load history uid=$uid", name: "AI");
        final userRef = _firestore.collection('users').doc(uid);
        final chatsRef = userRef.collection('chats');
        final recentChat = await chatsRef
            .orderBy('lastUpdated', descending: true)
            .limit(1)
            .get();

        if (recentChat.docs.isEmpty) return [];

        final chatId = recentChat.docs.first.id;
        final messagesRef = chatsRef.doc(chatId).collection('messages');

        final querySnapshot = await messagesRef
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();

        logD("history docs=${querySnapshot.docs.length}", name: "AI");

        final messages = querySnapshot.docs.reversed.map((doc) {
          final data = doc.data();
          final role = data['role'] == 'ai' ? 'assistant' : data['role'];
          return {
            'role': role as String,
            'content': (data['structured_data'] != null)
                ? jsonEncode(data['structured_data'])
                : (data['text'] ?? '') as String,
          };
        }).toList();

        return messages;
      } catch (e, st) {
        logE("⚠️ Error fetching chat history", e, st, name: "AI");
        return [];
      }
    }

    Map<String, dynamic>? _extractJson(String text) {
      String t = text.trim();
      if (t.startsWith('```')) {
        t = t.substring(3);
        if (t.startsWith('json')) {
          t = t.substring(4);
        }
        if (t.endsWith('```')) {
          t = t.substring(0, t.length - 3);
        }
        t = t.trim();
      }

      try {
        return jsonDecode(t);
      } catch (_) {
        final start = t.indexOf('{');
        final end = t.lastIndexOf('}');
        if (start != -1 && end != -1) {
          final jsonString = t.substring(start, end + 1);
          try {
            return jsonDecode(jsonString);
          } catch (_) {}
        }
      }
      return null;
    }

    Future<List<Map<String, dynamic>>> getChatMessages(
      String uid,
      String chatId,
    ) async {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt')
          .get();

      return snap.docs.map((d) => d.data()).toList();
    }

    Future<String> _ensureChatSession(
      String uid, {
      String? providedChatId,
    }) async {
      final chatsRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('chats');

      if (providedChatId != null) {
        return providedChatId;
      }

      final existing = await chatsRef
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id;
      }

      final newChat = chatsRef.doc();
      await newChat.set({
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'chatTitle': 'New Chat',
        'lastMessage': '',
      });
      return newChat.id;
    }

    Future<String> startNewChatSession(String uid) async {
      final chatDoc = _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc();

      await chatDoc.set({
        'chatTitle': 'New Chat',
        'lastMessage': '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return chatDoc.id;
    }

    Future<void> finalizeChatSession(
      String uid,
      String chatId,
      String title,
      String lastMessage,
    ) async {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(chatId)
          .update({
            'chatTitle': title,
            'lastMessage': lastMessage,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    }

    Future<void> _saveMessage(
      String uid,
      String role,
      String text, {
      Map<String, dynamic>? aiData,
      String? chatId,
    }) async {
      try {
        final String chatSessionId = await _ensureChatSession(
          uid,
          providedChatId: chatId,
        );

        final msgRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('chats')
            .doc(chatSessionId)
            .collection('messages')
            .doc();

        await msgRef.set({
          'role': role,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
          if (aiData != null) 'structured_data': aiData,
        });
        if (aiData != null && aiData['medication_proposal'] != null) {
          await _persistenceService.saveReminderContext(
            Map<String, dynamic>.from(aiData['medication_proposal']),
          );
        }
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('chats')
            .doc(chatSessionId)
            .set({
              'lastMessage': text,
              'lastUpdated': FieldValue.serverTimestamp(),
              'chatTitle': text.length > 25
                  ? '${text.substring(0, 25)}...'
                  : text,
            }, SetOptions(merge: true));

        logI("✅ saved chat message ($role)", name: "AI");
      } catch (e, st) {
        logE("⚠️ Error saving message", e, st, name: "AI");
      }
    }

    String _normalizeScheduleWords(String s) {
      final low = s.toLowerCase();
      if (low.contains('every morning')) return 'daily at 08:00';
      if (low.contains('every afternoon')) return 'daily at 15:00';
      if (low.contains('every evening') || low.contains('every night')) {
        return 'daily at 20:00';
      }
      return s;
    }

    Future<void> clearContext() async {
      _activeReminderContext = null;
      await _persistenceService.clearReminderContext();
      logI("🧹 Cleared AI reminder memory.", name: "AI");
    }
}
