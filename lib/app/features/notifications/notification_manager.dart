import 'dart:async';
import 'package:sympli_ai_health/app/utils/logging.dart';

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final List<Map<String, dynamic>> _notifications = [];
  final Set<String> _triggeredIds = {}; 
  final _controller = StreamController<List<Map<String, dynamic>>>.broadcast();

  Stream<List<Map<String, dynamic>>> get stream => _controller.stream;

  void addNotification(String title, String body, {String? uniqueId}) {
    final id = uniqueId ?? title; 
    if (_triggeredIds.contains(id)) {
      logI("⚠️ Skipped duplicate notification: $id");
      return; 
    }

    _triggeredIds.add(id); 

    final item = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'uniqueId': id,
      'title': title,
      'body': body,
      'timestamp': DateTime.now(),
      'read': false,
    };

    _notifications.insert(0, item);
    _controller.add(List.from(_notifications));
    logI('🔔 New in-app notification added: $title');
  }

  void markAllAsRead() {
    for (final n in _notifications) {
      n['read'] = true;
    }
    _controller.add(List.from(_notifications));
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n['id'] == id);
    if (index != -1) {
      _notifications[index]['read'] = true;
      _controller.add(List<Map<String, dynamic>>.from(_notifications));
    }
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n['id'] == id);
    _controller.add(List<Map<String, dynamic>>.from(_notifications));
  }

  void clearAll() {
    _notifications.clear();
    _triggeredIds.clear();
    _controller.add(List.from(_notifications));
  }

  int get unreadCount => _notifications.where((n) => !n['read']).length;
  List<Map<String, dynamic>> get all => List.unmodifiable(_notifications);

  void resetTrigger(String uniqueId) {
    _triggeredIds.remove(uniqueId);
  }
}

final notificationManager = NotificationManager();
