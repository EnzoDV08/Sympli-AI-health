import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:vibration/vibration.dart';
import 'package:sympli_ai_health/app/features/chat_ai/service/ai_chat_service.dart';
import 'package:sympli_ai_health/app/features/chat_ai/service/diagnosis_service.dart';
import 'package:sympli_ai_health/app/features/meds/services/med_reminder_service.dart';
import 'package:sympli_ai_health/app/features/logs/pages/logs_screen.dart';
import 'package:sympli_ai_health/app/core/widgets/reminder_saved_card.dart';


class ChatAIScreen extends StatefulWidget {
  final String? followUpCondition;
  const ChatAIScreen({super.key, this.followUpCondition});

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIChatService _aiService = AIChatService();
  final DiagnosisService _diagnosisService = DiagnosisService();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  bool _showSuccessAnim = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    if (widget.followUpCondition != null) {
      _messages.add({
        'sender': 'ai',
        'text':
            'How are you feeling today after your ${widget.followUpCondition}? 🩺',
        'time': DateTime.now(),
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

Future<void> _sendMessage() async {
  final text = _controller.text.trim();
  if (text.isEmpty) return;

  debugPrint("📤 SEND BUTTON CLICKED: $text");

  // Add user message instantly
  setState(() {
    _messages.add({
      'sender': 'user',
      'text': text,
      'time': DateTime.now(),
    });
    _controller.clear();
    _loading = true;
  });

  _scrollToBottom();

  // Show temporary "typing" placeholder
  Timer(const Duration(milliseconds: 400), () {
    if (_loading) {
      setState(() {
        _messages.add({'sender': 'ai', 'text': 'typing...', 'isTyping': true});
      });
      _scrollToBottom();
    }
  });

  try {
    final recentMessages = _messages.take(6).map((m) {
      return {
        'role': m['sender'] == 'user' ? 'user' : 'assistant',
        'content': m['text'].toString(),
      };
    }).toList();

    final reply = await _aiService.sendMessageWithContext(text, recentMessages);
    debugPrint("🧠 AI REPLY: $reply");

    if (reply.contains("✅ I've saved this as")) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      _showReminderSavedEffect(tomorrow);
    }

    setState(() {
      _messages.removeWhere((m) => m['isTyping'] == true);
      _messages.add({
        'sender': 'ai',
        'text': reply.isNotEmpty
            ? reply
            : "🤖 (No response received — please try again.)",
        'time': DateTime.now(),
      });
      _loading = false;
    });

    _scrollToBottom();

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50, amplitude: 80);
    }

    if (text.toLowerCase().contains("remind me")) {
      await _parseAndScheduleReminder(text);
    }

    await _diagnosisService.saveDiagnosis(
      title: "AI Chat Analysis",
      description: text,
      aiResponse: reply,
    );
  } catch (e) {
    debugPrint("❌ Chat error: $e");
    setState(() {
      _loading = false;
      _messages.removeWhere((m) => m['isTyping'] == true);
      _messages.add({
        'sender': 'ai',
        'text':
            "⚠️ Sorry, something went wrong while processing your request. Please try again.",
        'time': DateTime.now(),
      });
    });
    _scrollToBottom();
  }
}



  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

Future<void> _parseAndScheduleReminder(String message) async {
  try {
    final lower = message.toLowerCase();
    String? medName;
    int intervalHours = 4;

    final regexMed = RegExp(r"(take|drink|use)\s+([a-zA-Z0-9]+)");
    final match = regexMed.firstMatch(lower);
    if (match != null) medName = match.group(2);

    final regexInterval = RegExp(r"(\d+)\s*(hour|hours|hrs)");
    final matchInterval = regexInterval.firstMatch(lower);
    if (matchInterval != null) {
      intervalHours = int.tryParse(matchInterval.group(1)!) ?? 4;
    }

    if (medName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ I couldn't detect a medication name."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final now = TimeOfDay.now();
    await medReminderService.scheduleEveryNDays(
      baseId: medName.hashCode.abs() % 100000,
      title: "Medication Reminder",
      body: "💊 Time to take your $medName every $intervalHours hours.",
      timeOfDay: now,
      n: (intervalHours ~/ 24) == 0 ? 1 : intervalHours ~/ 24,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text("✅ Reminder set to take $medName every $intervalHours hours."),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    debugPrint("⚠️ Reminder parse failed: $e");
  }
}


  void _showReminderSavedEffect(DateTime scheduledDate) async {
    final formattedDate = DateFormat('EEE, MMM d • hh:mm a').format(scheduledDate);

    setState(() {
      _messages.add({
        'sender': 'system',
        'text': "✅ I've saved this as a follow-up reminder. "
            "You'll get a check-in on $formattedDate 💚",
        'time': DateTime.now(),
      });
      _messages.add({
        'sender': 'reminder_card',
        'time': DateTime.now(),
        'scheduled': scheduledDate,
      });
    });

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100, amplitude: 120);
    }

    Future.delayed(const Duration(milliseconds: 600), _scrollToBottom);
  }


  Future<void> _saveToLogs(String userMessage, String aiMessage) async {
    final existingLogs = await _diagnosisService.getUserLogs().first;
    final alreadyExists = existingLogs.any((log) =>
        log.description == userMessage &&
        log.aiResponse == aiMessage);

        if (alreadyExists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ This conversation is already saved in Logs."),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return;
        }


    await _diagnosisService.saveDiagnosis(
      title: "Symptom Log",
      description: userMessage,
      aiResponse: aiMessage,
    );

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 200);
    }

    setState(() => _showSuccessAnim = true);
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _showSuccessAnim = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Sympli AI Chat',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 10 + 3 * _pulseController.value,
                  height: 10 + 3 * _pulseController.value,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(
                            0.4 + 0.3 * _pulseController.value),
                        blurRadius: 8,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFF37B7A5)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LogsScreen()),
            ),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          _buildChatBody(),
          if (_showSuccessAnim)
            Center(
              child: Lottie.asset(
                'assets/animations/save_success.json',
                repeat: false,
                width: 180,
              ),
            ),
        ],
      ),
    );
  }

Widget _buildChatBody() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFE8F9F7), Color(0xFFF6F8FB)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 90),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isUser = msg['sender'] == 'user';
              final isTyping = msg['isTyping'] == true;
              if (isTyping) {
                return const Align(
                  alignment: Alignment.centerLeft,
                  child: _TypingBubble(),
                );
              }
              if (msg['sender'] == 'reminder_card' && msg['scheduled'] != null) {
                return CheckInPreviewCard(checkInDate: msg['scheduled']);
              }
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFFDCF8C6)
                        : Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg['text'] ?? '',
                        softWrap: true,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('hh:mm a')
                                .format(msg['time'] ?? DateTime.now()),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          if (!isUser) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _saveToLogs(
                                _messages
                                    .lastWhere(
                                        (m) => m['sender'] == 'user')['text']
                                    .toString(),
                                msg['text'],
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.save_alt_rounded,
                                      color: Color(0xFF37B7A5), size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    "Save",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF37B7A5),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _buildAskBar(),
      ],
    ),
  );
}



  Widget _buildAskBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Hero(
        tag: 'ask-bar',
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: "Ask Sympli AI anything...",
                    border: InputBorder.none,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF37B7A5),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send_rounded,
                            color: Color(0xFF37B7A5)),
                        onPressed: _sendMessage,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final delay = i * 0.2;
              final scale = (value - delay).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Transform.scale(
                  scale: Curves.easeInOut.transform(scale),
                  child: const CircleAvatar(
                    radius: 4,
                    backgroundColor: Color(0xFF37B7A5),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class CheckInPreviewCard extends StatelessWidget {
  final DateTime checkInDate;
  const CheckInPreviewCard({super.key, required this.checkInDate});

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('EEE, MMM d • hh:mm a').format(checkInDate);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const LogsScreen(),
                transitionsBuilder: (_, animation, __, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD5F5E3), Color(0xFFE8F9F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/animations/save_success.json',
                  width: 38,
                  height: 38,
                  repeat: false,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Follow-up reminder created 💚",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      "Check-in scheduled for $formatted",
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Tap to view in Logs →",
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
  }
}

