import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sympli_ai_health/app/utils/logging.dart';

class AIPersistenceService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>?> loadReminderContext() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      logW("Cannot load reminder context: no user logged in", name: "AI");
      return null;
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data()?['currentReminderContext'] is Map) {
        final data = Map<String, dynamic>.from(doc['currentReminderContext']);
        logI("🧠 Loaded reminder context: ${jsonEncode(data)}", name: "AI");
        return data;
      }
    } catch (e, st) {
      logE("Failed to load reminder context", e, st, name: "AI");
    }
    return null;
  }

  Future<void> saveReminderContext(Map<String, dynamic> context) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      logW("Cannot save reminder context: no user logged in", name: "AI");
      return;
    }

    try {
      await _firestore.collection('users').doc(uid).set(
        {'currentReminderContext': context},
        SetOptions(merge: true),
      );
      logI("💾 Persisted reminder context", name: "AI");
    } catch (e, st) {
      logE("Error saving reminder context", e, st, name: "AI");
    }
  }

  Future<void> clearReminderContext() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .update({'currentReminderContext': FieldValue.delete()});
      logI("🧹 Cleared persisted reminder context", name: "AI");
    } catch (e, st) {
      logE("Failed to clear reminder context", e, st, name: "AI");
    }
  }

  Future<List<Map<String, String>>> loadChatHistory({int limit = 6}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      logW("Cannot load chat history: no user logged in", name: "AI");
      return [];
    }

    try {
      final userRef = _firestore.collection('users').doc(uid);
      final chatsRef = userRef.collection('chats');
      final recentChat = await chatsRef
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();

      if (recentChat.docs.isEmpty) return [];

      final chatId = recentChat.docs.first.id;
      final messagesRef = chatsRef.doc(chatId).collection('messages');
      final snapshot = await messagesRef
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final messages = snapshot.docs.reversed.map((doc) {
        final data = doc.data();
        final role = data['role'] == 'ai' ? 'assistant' : data['role'];
        return {
          'role': role as String,
          'content': (data['structured_data'] != null)
              ? jsonEncode(data['structured_data'])
              : (data['text'] ?? '') as String,
        };
      }).toList();

      logI("🧩 Loaded ${messages.length} chat history messages", name: "AI");
      return messages;
    } catch (e, st) {
      logE("Error loading chat history", e, st, name: "AI");
      return [];
    }
  }
}
