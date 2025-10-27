import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:sympli_ai_health/app/features/logs/widgets/log_card.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text("⚠️ You must be logged in to view chat logs."),
        ),
      );
    }

    final chatsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chats')
        .orderBy('lastUpdated', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Logs"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: chatsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final chats = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final chatId = chat.id;
              final chatTitle = chat['chatTitle'] ?? 'Untitled Chat';
              final lastMessage = chat['lastMessage'] ?? 'No message yet.';
              final Timestamp? lastUpdatedTs = chat['lastUpdated'];
              final lastUpdated = lastUpdatedTs?.toDate();

              final formattedDate = lastUpdated != null
                  ? DateFormat('MMM d, yyyy').format(lastUpdated)
                  : 'Unknown date';

              return LogCard(
                title: chatTitle,
                description: lastMessage,
                date: formattedDate,
                chatId: chatId, 
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/empty_state.json',
              width: 240,
              height: 240,
              repeat: true,
            ),
            const SizedBox(height: 16),
            const Text(
              "No chats yet 🗨️",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Start your first conversation with Sympli AI Health.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: () {
                GoRouter.of(context).pushNamed('chat-ai');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              label: const Text(
                "Start Chat",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
