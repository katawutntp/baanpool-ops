import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-app notification service with realtime subscription.
/// Listens to the `notifications` table for the current user.
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _client = Supabase.instance.client;
  RealtimeChannel? _channel;

  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _initialized = false;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

  /// Initialize: load existing notifications + subscribe to realtime
  Future<void> init() async {
    if (_initialized) return;
    final user = _client.auth.currentUser;
    if (user == null) return;

    _initialized = true;
    await _loadNotifications();
    _subscribeRealtime(user.id);
  }

  /// Load existing notifications from DB
  Future<void> _loadNotifications() async {
    try {
      final data = await _client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      _notifications = List<Map<String, dynamic>>.from(data);
      _unreadCount = _notifications.where((n) => n['is_read'] != true).length;
      notifyListeners();
    } catch (e) {
      debugPrint('Load notifications error: $e');
    }
  }

  /// Subscribe to realtime inserts on notifications table
  void _subscribeRealtime(String userId) {
    _channel?.unsubscribe();
    _channel = _client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newNoti = payload.newRecord;
            _notifications.insert(0, newNoti);
            _unreadCount++;
            notifyListeners();
          },
        )
        .subscribe();
  }

  /// Reload notifications
  Future<void> refresh() async {
    await _loadNotifications();
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      final idx = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (idx >= 0 && _notifications[idx]['is_read'] != true) {
        _notifications[idx] = {..._notifications[idx], 'is_read': true};
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Mark as read error: $e');
    }
  }

  /// Mark all as read
  Future<void> markAllAsRead() async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('is_read', false);

      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = {..._notifications[i], 'is_read': true};
      }
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Mark all as read error: $e');
    }
  }

  /// Dispose realtime channel
  void dispose2() {
    _channel?.unsubscribe();
    _channel = null;
    _initialized = false;
  }
}
