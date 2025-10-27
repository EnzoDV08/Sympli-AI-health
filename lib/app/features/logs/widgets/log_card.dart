import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class LogCard extends StatelessWidget {
  final String title;
  final String description;
  final String date;
  final String chatId; 

  const LogCard({
    super.key,
    required this.title,
    required this.description,
    required this.date,
    required this.chatId, // ✅
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = _tryFormatDate(date);

    return GestureDetector(
      onTap: () => _openChat(context),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.deepPurple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openChat(context), 
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    label: const Text(
                      "Continue",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChat(BuildContext context) {
    GoRouter.of(context).pushNamed(
      'chat-ai', 
      extra: chatId,
    );
  }

  String _tryFormatDate(String raw) {
    try {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return DateFormat('MMM d, yyyy').format(parsed);
      }
    } catch (_) {}
    return raw;
  }
}
