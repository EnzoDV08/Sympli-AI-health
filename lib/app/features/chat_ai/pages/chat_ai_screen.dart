// lib/app/features/chat_ai/pages/chat_ai_screen.dart
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:vibration/vibration.dart';
import 'package:sympli_ai_health/app/features/chat_ai/service/ai_chat_service.dart';
import 'package:sympli_ai_health/app/features/logs/pages/logs_screen.dart';
import 'package:sympli_ai_health/app/utils/logging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:sympli_ai_health/app/core/widgets/quick_ask_section.dart';
import 'package:sympli_ai_health/app/utils/isolate_reminder.dart';


class ChatAIScreen extends StatefulWidget {
  final String? followUpCondition;
  final String? existingChatId; 

  const ChatAIScreen({
    super.key,
    this.followUpCondition,
    this.existingChatId,
  });

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
  
}

class _ChatAIScreenState extends State<ChatAIScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIChatService _aiService = AIChatService();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  String? _chatId;
  late AnimationController _pulseController;

 @override
void initState() {
  super.initState();
  logI("ChatAIScreen.initState followUpCondition=${widget.followUpCondition}", name: "CHAT");
  _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

 if (widget.existingChatId != null) {
  // ✅ Case 1: Continue old chat
  _loadChatHistory(widget.existingChatId!);
  _chatId = widget.existingChatId;
} else if (widget.followUpCondition != null) {
  // ✅ Case 2: Quick Ask (from Home)
  _startNewChat().then((_) {
    // Slight delay ensures chatId is created before sending
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        final question = "I have a question about ${widget.followUpCondition}.";
        _controller.text = question;
        _sendMessage();
      }
    });
  });
} else {
  // ✅ Case 3: Fresh empty chat
  _startNewChat();
}
}


@override
void dispose() {
  _finalizeChat(); // ✅ save last message + title for Logs
  _controller.dispose();
  _scrollController.dispose();
  _pulseController.dispose();
  logI("ChatAIScreen.dispose()", name: "CHAT");
  super.dispose();
}

Future<void> _startNewChat() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  _chatId = await _aiService.startNewChatSession(uid);
  logI("🆕 Started new chat session: $_chatId", name: "CHAT");
}


Future<void> _sendMessage() async {
  final text = _controller.text.trim();
  if (text.isEmpty) return;
  logI("SEND: $text", name: "CHAT");

  setState(() {
    _messages.insert(0,{'sender': 'user', 'text': text, 'time': DateTime.now()});
    _controller.clear();
    _loading = true;
  });

  _scrollToBottom();
  if (!mounted) return;

  // 🔹 Delay showing typing bubble (non-blocking)
  Timer(const Duration(milliseconds: 400), () {
    if (_loading && mounted) {
      setState(() => _messages.insert(0,{'sender': 'typing', 'time': DateTime.now()}));
      _scrollToBottom();
    }
  });

  try {
    final aiResponse = await _aiService.sendMessage(
      text,
      chatId: _chatId,
    );

    logI("AI TEXT: ${aiResponse.text}", name: "CHAT");

    // 🔹 Safely update messages AFTER frame to avoid index conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m['sender'] == 'typing');

        _messages.insert(0,{
          'sender': 'ai',
          'text': aiResponse.text.isNotEmpty
              ? aiResponse.text
              : "🤖 (No response received)",
          'time': DateTime.now(),
        });

        // Remove any previous reminder bubble
        _messages.removeWhere((m) => m['sender'] == 'reminder_proposal');

final looksLikeFollowUp = aiResponse.text.trim().endsWith('?');
final proposal = aiResponse.medicationProposal;
final textLower = aiResponse.text.toLowerCase();

final shouldShowProposal = proposal != null &&
    proposal.isNotEmpty &&
    (textLower.contains("i’ll save") ||
     textLower.contains("i will save") ||
     textLower.contains("reminder for") ||
     textLower.contains("confirm reminder") ||
     textLower.contains("save a reminder"));

if (shouldShowProposal) {
  _messages.insert(0,{
    'sender': 'reminder_proposal',
    'data': proposal,
    'time': DateTime.now(),
  });
} else if (!looksLikeFollowUp) {
  _messages.insert(0,{
    'sender': 'system',
    'text':
        '💡 I didn’t detect a reminder plan. Try saying “Remind me to take Panado every 6 hours.”',
    'time': DateTime.now(),
  });
}


        _loading = false;
      });
    });

    // 🔹 Retrieve Firestore chat ID if new
    if (_chatId == null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final chats = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('chats')
            .orderBy('lastUpdated', descending: true)
            .limit(1)
            .get();
        if (mounted && chats.docs.isNotEmpty) {
          setState(() {
            _chatId = chats.docs.first.id;
          });
        }
      }
    }

    _scrollToBottom();

    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(duration: 50, amplitude: 80);
    }
  } catch (e) {
    logE("Chat send failed", e, StackTrace.current, name: "CHAT");
    if (mounted) {
      setState(() {
        _loading = false;
        _messages.removeWhere((m) => m['sender'] == 'typing');
        _messages.insert(0,{
          'sender': 'ai',
          'text': "⚠️ Sorry, something went wrong. Please try again.",
          'time': DateTime.now(),
        });
      });
    }
    _scrollToBottom();
  }
}


  Future<void> _loadChatHistory(String chatId) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final ref = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt', descending: false);

  final snapshot = await ref.get();
  final loaded = snapshot.docs.map((d) {
    final data = d.data();
    return {
      'sender': data['role'] == 'ai' ? 'ai' : 'user',
      'text': data['text'] ?? '',
      'time': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    };
  }).toList();

  setState(() {
    _messages.clear();
    _messages.addAll(loaded);
  });

  Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
}


Future<void> _finalizeChat() async {
  if (_chatId == null) return;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  // 🔎 Check Firestore message count
  final messagesSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('chats')
      .doc(_chatId!)
      .collection('messages')
      .limit(1)
      .get();

  // 🧹 Delete empty chats (no messages ever sent)
  if (messagesSnap.docs.isEmpty) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(_chatId!)
        .delete();
    logI("🗑️ Deleted empty chat session ($_chatId)", name: "CHAT");
    return;
  }

  final firstMsg = _messages.firstWhere(
    (m) => m['sender'] == 'user',
    orElse: () => {'text': 'New Chat'},
  )['text'] as String;

  final lastMsg = _messages.last['text'] ?? '';
  final title =
      firstMsg.length > 25 ? '${firstMsg.substring(0, 25)}...' : firstMsg;

  await _aiService.finalizeChatSession(uid, _chatId!, title, lastMsg);
  logI("✅ Chat finalized successfully", name: "CHAT");
}



void _scrollToBottom() {
  Future.delayed(const Duration(milliseconds: 150), () {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // scroll to top since reversed: true
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });
}


Future<void> _applyReminder({
  required Map<String, dynamic> data,
  required int indexToReplace,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("💾 Saving reminder..."),
      backgroundColor: Colors.black54,
      duration: Duration(seconds: 1),
    ),
  );

  try {
    final name = (data['name'] ?? '').toString().trim();
    final dosage = (data['dosage'] ?? '').toString();
    final instructions = (data['instructions'] ?? '').toString();
    final schedule = data['schedule'] ?? {};

    // ✅ Run heavy work (Firestore + notifications) in a background isolate
    unawaited(ReminderIsolate.runInBackground({
      'uid': uid,
      'name': name,
      'dosage': dosage,
      'instructions': instructions,
      'repeat': schedule['type'] ?? 'daily',
      'time': (schedule['time'] ?? '08:00').toString(),
      'timezone': (schedule['timezone'] ?? 'SAST').toString(),
      'days': (schedule['days'] as List?)
          ?.map((e) => int.tryParse(e.toString()) ?? 0)
          .where((v) => v > 0)
          .toList(),
      'n': schedule['n'],
      'hours': schedule['hours'],
    }));

    // ✅ Give the isolate a moment to start so UI feels responsive
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;
    setState(() {
      _messages[indexToReplace] = {
        'sender': 'system',
        'text': '✅ Reminder successfully saved and activated!',
        'time': DateTime.now(),
      };
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Reminder saved & scheduled"),
        backgroundColor: Color(0xFF37B7A5),
        duration: Duration(seconds: 2),
      ),
    );

    _aiService.clearContext();
  } catch (e, st) {
    logE("❌ _applyReminder failed", e, st, name: "CHAT");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Failed to save: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}




@override
Widget build(BuildContext context) {
  final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

  return Scaffold(
    resizeToAvoidBottomInset: false, // ✅ Let the AskBar move up
    extendBodyBehindAppBar: false,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          const Text(
            'Sympli AI',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          FadeTransition(
            opacity: _pulseController,
            child: const Icon(Icons.circle, color: Colors.greenAccent, size: 10),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded, color: Colors.black87),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LogsScreen()),
          ),
        ),
      ],
    ),

body: Stack(
  children: [
    // 🌈 Background
    Positioned.fill(
      child: Container(
        color: const Color(0xFFF7F9FB),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(color: Colors.white.withOpacity(0.05)),
        ),
      ),
    ),

    // 💬 Main chat area
   Padding(
  padding: const EdgeInsets.only(bottom: 90),
  child: Column(
    children: [
      const SizedBox(height: kToolbarHeight + -50), // ✅ smaller, cleaner spacing
      Expanded(
        child: _messages.isEmpty
                ? _buildEmptyState()
                    : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      MediaQuery.of(context).viewInsets.bottom + 120,
                    ),

                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final sender = msg['sender'];
                      if (sender == 'typing') return const _TypingBubble();
                      if (sender == 'reminder_proposal') {
                        return ReminderConfirmationBubble(
                          proposalData: msg['data'],
                          onConfirm: (data) async =>
                              await _applyReminder(data: data, indexToReplace: index),
                          onCancel: () {
                            if (!mounted) return;
                            setState(() {
                              _messages[index] = {
                                'sender': 'system',
                                'text': 'Reminder cancelled.',
                                'time': DateTime.now(),
                              };
                            });
                          },
                        );
                      }
                      return _buildFancyBubble(msg);
                    },
                  ),
          ),

          if (!keyboardVisible)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: QuickAskSection(
                onSelect: (label) {
                  _controller.text = "I have a question about $label.";
                  _sendMessage();
                },
              ),
            ),
        ],
      ),
    ),

    // 🚀 Floating AskBar — now works properly!
  AnimatedPositioned(
  duration: const Duration(milliseconds: 250),
  curve: Curves.easeOutCubic,
  left: 0,
  right: 0,
  bottom: MediaQuery.of(context).viewInsets.bottom > 0
      ? MediaQuery.of(context).viewInsets.bottom
      : -17, // slightly lower so it clears Quick Ask
  child: SafeArea(
    top: false,
    child: Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 1.32, // ✅ perfect width
        child: _buildAskBar(),
      ),
    ),
  ),
),
  ],
),
  );
}



Widget _buildAskBar() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: const Color(0xFF37B7A5).withOpacity(0.4),
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(35),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF37B7A5), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(
                        color: Colors.black87, fontSize: 16, height: 1.4),
                    decoration: const InputDecoration(
                      hintText: "Ask Sympli AI anything...",
                      hintStyle: TextStyle(
                        color: Colors.black45,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _loading
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF37B7A5),
                          ),
                        )
                      : GestureDetector(
                          onTap: _sendMessage,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF37B7A5),
                                  Color(0xFF1CB5E0),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1CB5E0)
                                      .withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                // onTap: () async {
                                //   final speechService = SpeechService();
                                //   await speechService.init();
                                //   final transcript = await speechService.recordAndTranscribe();
                                //   if (transcript != null && transcript.isNotEmpty) {
                                //     setState(() => _controller.text = transcript);
                                //   }
                                // },
                                child: const Icon(Icons.mic_rounded,
                                    color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 22),
                            ],
                          ),

                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildFancyBubble(Map<String, dynamic> msg) {
  final sender = msg['sender'];
  final isUser = sender == 'user';
  final text = msg['text'] ?? '';

if (sender == 'system') {
  return Center(
    child: AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 400),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF37B7A5).withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF37B7A5).withOpacity(0.3),
            width: 1.0,
          ),
        ),
        child: Text(
          msg['text'] ?? '',
          style: const TextStyle(
            color: Color(0xFF11695F),
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ),
    ),
  );
}

  const aiOrbAnimation = 'assets/animations/ai_glow.json';
  const aiProfileIcon = 'assets/images/ai_avatar.png'; 

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isUser)
          SizedBox(
            width: 45,
            height: 45,
            child: Lottie.asset(
              aiOrbAnimation,
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),

        if (!isUser) const SizedBox(width: 8),

        Flexible(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 6),
                      bottomRight: Radius.circular(isUser ? 6 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 30,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: isUser
                            ? const Color(0xFF37B7A5).withOpacity(0.25)
                            : const Color(0xFFFFA3A3).withOpacity(0.25),
                        blurRadius: 50,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
              ),

              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 18),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isUser
                            ? [
                                const Color(0xAAE0F7FA),
                                const Color(0x55B2EBF2),
                              ]
                            : [
                                Colors.white.withOpacity(0.35),
                                Colors.white.withOpacity(0.25),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        color: isUser
                            ? Colors.black.withOpacity(0.85)
                            : Colors.black.withOpacity(0.9),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isUser) ...[
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundImage: const AssetImage(aiProfileIcon),
            backgroundColor: Colors.transparent,
          ),
        ],
      ],
    ),
  );
}


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty_chat.json',
            width: 220,
            height: 220,
            repeat: true,
          ),
          const SizedBox(height: 20),
          const Text(
            "Start a conversation with Sympli AI 💬",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Ask about your symptoms, medication, or reminders.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}


class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Transform.scale(
          scale: 2.0, 
          child: SizedBox(
            width: 60, 
            height: 30,
            child: Lottie.asset(
              'assets/animations/typing.json',
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }
}


class ReminderConfirmationBubble extends StatefulWidget {
  final Map<String, dynamic> proposalData;
  final Function(Map<String, dynamic>) onConfirm;
  final VoidCallback onCancel;

  const ReminderConfirmationBubble({
    super.key,
    required this.proposalData,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<ReminderConfirmationBubble> createState() =>
      _ReminderConfirmationBubbleState();
}

class _ReminderConfirmationBubbleState
    extends State<ReminderConfirmationBubble> with TickerProviderStateMixin {

  late AnimationController _pulseController;
  late AnimationController _fadeInController;

@override
void initState() {
  super.initState();

  
  _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  _fadeInController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();
}


@override
void dispose() {
  _pulseController.dispose();
  _fadeInController.dispose();
  super.dispose();
}

  String _formatSchedule(Map<String, dynamic> data) {
    final sched = data['schedule'];
    if (sched is Map) {
      final type = (sched['type'] ?? '').toString();
      switch (type) {
        case 'daily':
          final time = (sched['time'] ?? '08:00').toString();
          return 'Daily at $time';
        case 'weekly':
          final days = (sched['days'] as List?)?.join(', ') ?? '—';
          final time2 = (sched['time'] ?? '08:00').toString();
          return 'Weekly on $days at $time2';
        case 'everyN':
          final n = (sched['n'] ?? '?').toString();
          final t = (sched['time'] ?? '08:00').toString();
          return 'Every $n days at $t';
        case 'everyNHours':
          final h = (sched['hours'] ?? '?').toString();
          return 'Every $h hours';
      }
    }
    return 'Daily at 08:00';  }

  @override
  Widget build(BuildContext context) {
    final data = widget.proposalData;
    final name = (data['name'] ?? 'N/A').toString();
    final dosage = (data['dosage'] ?? 'N/A').toString();
    final instructions = (data['instructions'] ?? 'None').toString();
    final schedule = data['schedule'] != null
    ? _formatSchedule(data)
    : 'Daily at 08:00';


    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final glow = Color.lerp(
          const Color(0xFF37B7A5),
          const Color(0xFF1CB5E0),
          _pulseController.value,
        )!;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.92),
                      Colors.white.withOpacity(0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: glow.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: glow.withOpacity(0.25),
                      blurRadius: 25,
                      spreadRadius: 3,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications_active_rounded, color: glow, size: 24),
                        const SizedBox(width: 8),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF37B7A5), Color(0xFF1CB5E0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'Confirm Reminder Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _infoRow('💊 Medication', name),
                    _infoRow('💧 Dosage', dosage),
                    _infoRow('⏰ Schedule', schedule),
                    _infoRow('📋 Instructions', instructions),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.withOpacity(0.4)),
                          ),
                          child: TextButton(
                            onPressed: widget.onCancel,
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => widget.onConfirm(data),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 26, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [glow, const Color(0xFF1CB5E0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: glow.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Confirm',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 15.5,
              color: Colors.black87,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      ),
    );
  }
}

