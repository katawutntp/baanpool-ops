import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// LINE Messaging API push notification service.
///
/// Supports:
/// - Notify technician when assigned a work order
/// - Notify caretaker & manager when PM schedule is due soon / overdue
/// - Notify caretaker & manager when work order status changes
class LineNotifyService {
  static final LineNotifyService _instance = LineNotifyService._();
  factory LineNotifyService() => _instance;
  LineNotifyService._();

  final _client = Supabase.instance.client;

  String get _token => dotenv.env['LINE_MESSAGING_TOKEN'] ?? '';
  bool get _enabled => _token.isNotEmpty;

  // ─── Core: Push message via LINE Messaging API ─────────

  /// Send a text push message to a LINE user.
  Future<bool> _push(String lineUserId, String message) async {
    if (!_enabled || lineUserId.isEmpty) {
      debugPrint(
        'LINE push skipped: enabled=$_enabled, lineUserId=$lineUserId',
      );
      return false;
    }
    try {
      final res = await http.post(
        Uri.parse('https://api.line.me/v2/bot/message/push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'to': lineUserId,
          'messages': [
            {'type': 'text', 'text': message},
          ],
        }),
      );
      debugPrint('LINE push → ${res.statusCode} ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('LINE push error: $e');
      return false;
    }
  }

  /// Send a Flex Message (rich card) to a LINE user.
  Future<bool> _pushFlex(
    String lineUserId,
    String altText,
    Map<String, dynamic> flexContent,
  ) async {
    if (!_enabled || lineUserId.isEmpty) {
      debugPrint(
        'LINE flex push skipped: enabled=$_enabled, lineUserId=$lineUserId',
      );
      return false;
    }
    try {
      final res = await http.post(
        Uri.parse('https://api.line.me/v2/bot/message/push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'to': lineUserId,
          'messages': [
            {'type': 'flex', 'altText': altText, 'contents': flexContent},
          ],
        }),
      );
      debugPrint('LINE flex push → ${res.statusCode} ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('LINE flex push error: $e');
      return false;
    }
  }

  // ─── Helper: resolve line_user_id from users table ─────

  Future<String?> _getLineUserId(String userId) async {
    try {
      final user = await _client
          .from('users')
          .select('line_user_id')
          .eq('id', userId)
          .maybeSingle();
      return user?['line_user_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Get all managers and admins (+ optional caretaker of property)
  Future<List<Map<String, dynamic>>> _getManagersAndAdmins() async {
    try {
      return await _client
          .from('users')
          .select('id, full_name, line_user_id, role')
          .inFilter('role', ['admin', 'owner', 'manager']);
    } catch (_) {
      return [];
    }
  }

  /// Get the caretaker for a property
  Future<Map<String, dynamic>?> _getPropertyCaretaker(String propertyId) async {
    try {
      final prop = await _client
          .from('properties')
          .select('caretaker_id')
          .eq('id', propertyId)
          .maybeSingle();
      if (prop == null || prop['caretaker_id'] == null) return null;
      return await _client
          .from('users')
          .select('id, full_name, line_user_id')
          .eq('id', prop['caretaker_id'] as String)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  // ─── 1. Notify technician: assigned a new work order ───

  /// Called when a work order is created or reassigned.
  /// Returns a result string describing what happened.
  Future<String> notifyTechnicianAssigned({
    required String technicianUserId,
    required String workOrderTitle,
    required String propertyName,
    String priority = 'medium',
  }) async {
    if (!_enabled) {
      debugPrint('LINE notify disabled: LINE_MESSAGING_TOKEN is empty');
      return 'LINE_TOKEN_MISSING';
    }

    final lineId = await _getLineUserId(technicianUserId);
    debugPrint(
      'LINE notify: technicianUserId=$technicianUserId → lineId=$lineId',
    );
    if (lineId == null || lineId.isEmpty) {
      return 'NO_LINE_ID';
    }

    final priorityEmoji = _priorityEmoji(priority);

    final ok = await _pushFlex(
      lineId,
      '📢 งานใหม่: $workOrderTitle',
      _workOrderCard(
        title: '📢 คุณได้รับมอบหมายงานใหม่!',
        workOrderTitle: workOrderTitle,
        propertyName: propertyName,
        priority: priority,
        priorityEmoji: priorityEmoji,
        color: '#1DB446',
      ),
    );
    return ok ? 'SENT' : 'SEND_FAILED';
  }

  // ─── 2. Notify caretaker + managers: PM due soon ───────

  /// Called when PM schedule is due within 7 days or overdue.
  /// Notifies the property caretaker + all managers/admins.
  Future<void> notifyPmDueSoon({
    required String propertyId,
    required String propertyName,
    required String pmTitle,
    required String assetName,
    required DateTime nextDueDate,
    required int daysUntilDue,
  }) async {
    final isOverdue = daysUntilDue < 0;
    final statusText = isOverdue
        ? '⚠️ เกินกำหนด ${-daysUntilDue} วัน'
        : '⏰ อีก $daysUntilDue วัน';
    final dateStr =
        '${nextDueDate.day}/${nextDueDate.month}/${nextDueDate.year}';

    final message =
        '${isOverdue ? "🔴" : "🟡"} แจ้งเตือน PM\n'
        '📋 $pmTitle\n'
        '🏠 บ้าน: $propertyName\n'
        '🔧 อุปกรณ์: $assetName\n'
        '📅 กำหนด: $dateStr\n'
        '$statusText';

    // Collect recipients: caretaker + managers/admins
    final recipients = <String>{};

    // Caretaker of this property
    final caretaker = await _getPropertyCaretaker(propertyId);
    if (caretaker != null) {
      final lid = caretaker['line_user_id'] as String?;
      if (lid != null && lid.isNotEmpty) recipients.add(lid);
    }

    // All managers/admins
    final managers = await _getManagersAndAdmins();
    for (final m in managers) {
      final lid = m['line_user_id'] as String?;
      if (lid != null && lid.isNotEmpty) recipients.add(lid);
    }

    // Send to all unique recipients
    for (final lineId in recipients) {
      await _push(lineId, message);
    }
  }

  // ─── 3. Notify caretaker + managers: work order status change ──

  /// Called when a work order status is updated (e.g. completed).
  Future<void> notifyWorkOrderStatusChanged({
    required String workOrderTitle,
    required String propertyId,
    required String propertyName,
    required String oldStatus,
    required String newStatus,
    String? technicianName,
  }) async {
    final emoji = _statusEmoji(newStatus);
    final statusText = _statusDisplayName(newStatus);

    final message =
        '$emoji ใบงานอัปเดตสถานะ\n'
        '📝 $workOrderTitle\n'
        '🏠 บ้าน: $propertyName\n'
        '📊 สถานะ: $statusText\n'
        '${technicianName != null ? "👷 ช่าง: $technicianName\n" : ""}'
        'เข้าไปดูรายละเอียดที่แอป BaanPool Ops';

    final recipients = <String>{};

    // Caretaker
    final caretaker = await _getPropertyCaretaker(propertyId);
    if (caretaker != null) {
      final lid = caretaker['line_user_id'] as String?;
      if (lid != null && lid.isNotEmpty) recipients.add(lid);
    }

    // Managers/admins
    final managers = await _getManagersAndAdmins();
    for (final m in managers) {
      final lid = m['line_user_id'] as String?;
      if (lid != null && lid.isNotEmpty) recipients.add(lid);
    }

    for (final lineId in recipients) {
      await _push(lineId, message);
    }
  }

  // ─── 4. Batch check: send PM reminders for all due schedules ───

  /// Call this from the dashboard to check all PM schedules and
  /// send notifications for those due within 7 days or overdue.
  /// Returns count of notifications sent.
  Future<int> checkAndNotifyPmDueSchedules() async {
    if (!_enabled) return 0;

    int sent = 0;
    try {
      // Get PM schedules due within 7 days
      final weekFromNow = DateTime.now().add(const Duration(days: 7));

      List<Map<String, dynamic>> duePms;
      try {
        duePms = await _client
            .from('pm_schedules')
            .select('*, asset:asset_id(name, property_id)')
            .eq('is_active', true)
            .lte('next_due_date', weekFromNow.toIso8601String());
      } catch (_) {
        duePms = await _client
            .from('pm_schedules')
            .select()
            .eq('is_active', true)
            .lte('next_due_date', weekFromNow.toIso8601String());
      }

      if (duePms.isEmpty) return 0;

      // Load all properties for name lookup
      final properties = await _client.from('properties').select('id, name');
      final propNames = <String, String>{
        for (final p in properties) p['id'] as String: p['name'] as String,
      };

      for (final pm in duePms) {
        final nextDue = DateTime.parse(pm['next_due_date'] as String);
        final daysUntilDue = nextDue.difference(DateTime.now()).inDays;

        // Resolve asset & property info
        String assetName = 'ไม่ระบุ';
        String propertyId = pm['property_id'] as String;

        if (pm['asset'] is Map) {
          assetName = pm['asset']['name'] as String? ?? 'ไม่ระบุ';
        }

        final propertyName = propNames[propertyId] ?? 'ไม่ทราบบ้าน';

        await notifyPmDueSoon(
          propertyId: propertyId,
          propertyName: propertyName,
          pmTitle: pm['title'] as String,
          assetName: assetName,
          nextDueDate: nextDue,
          daysUntilDue: daysUntilDue,
        );
        sent++;
      }
    } catch (e) {
      debugPrint('PM notification check error: $e');
    }
    return sent;
  }

  // ─── Helpers ───────────────────────────────────────────

  String _priorityEmoji(String priority) {
    switch (priority) {
      case 'urgent':
        return '🔴';
      case 'high':
        return '🟠';
      case 'medium':
        return '🔵';
      case 'low':
        return '⚪';
      default:
        return '🔵';
    }
  }

  String _statusEmoji(String status) {
    switch (status) {
      case 'open':
        return '🆕';
      case 'in_progress':
        return '🔄';
      case 'completed':
        return '✅';
      case 'cancelled':
        return '❌';
      default:
        return '📋';
    }
  }

  String _statusDisplayName(String status) {
    switch (status) {
      case 'open':
        return 'เปิด';
      case 'in_progress':
        return 'กำลังดำเนินการ';
      case 'completed':
        return 'เสร็จแล้ว';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return status;
    }
  }

  /// Build a Flex Message card for work order assignment.
  Map<String, dynamic> _workOrderCard({
    required String title,
    required String workOrderTitle,
    required String propertyName,
    required String priority,
    required String priorityEmoji,
    required String color,
  }) {
    return {
      'type': 'bubble',
      'header': {
        'type': 'box',
        'layout': 'vertical',
        'backgroundColor': color,
        'contents': [
          {
            'type': 'text',
            'text': title,
            'color': '#FFFFFF',
            'weight': 'bold',
            'size': 'md',
          },
        ],
      },
      'body': {
        'type': 'box',
        'layout': 'vertical',
        'spacing': 'md',
        'contents': [
          {
            'type': 'text',
            'text': '📝 $workOrderTitle',
            'weight': 'bold',
            'size': 'lg',
            'wrap': true,
          },
          {'type': 'separator'},
          {
            'type': 'box',
            'layout': 'vertical',
            'spacing': 'sm',
            'contents': [
              _flexRow('🏠 บ้าน', propertyName),
              _flexRow('$priorityEmoji ความสำคัญ', _priorityLabel(priority)),
            ],
          },
        ],
      },
      'footer': {
        'type': 'box',
        'layout': 'vertical',
        'contents': [
          {
            'type': 'text',
            'text': 'เข้าดูรายละเอียดที่แอป BaanPool Ops',
            'size': 'xs',
            'color': '#AAAAAA',
            'align': 'center',
          },
        ],
      },
    };
  }

  Map<String, dynamic> _flexRow(String label, String value) {
    return {
      'type': 'box',
      'layout': 'horizontal',
      'contents': [
        {
          'type': 'text',
          'text': label,
          'size': 'sm',
          'color': '#555555',
          'flex': 0,
        },
        {
          'type': 'text',
          'text': value,
          'size': 'sm',
          'color': '#111111',
          'align': 'end',
          'weight': 'bold',
        },
      ],
    };
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'urgent':
        return 'เร่งด่วน';
      case 'high':
        return 'สูง';
      case 'medium':
        return 'ปานกลาง';
      case 'low':
        return 'ต่ำ';
      default:
        return priority;
    }
  }
}
