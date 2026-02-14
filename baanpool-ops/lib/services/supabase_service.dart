import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service layer for all Supabase operations
class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  // ─── Auth ──────────────────────────────────────────────

  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  User? get currentUser => _client.auth.currentUser;

  // ─── Properties ────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProperties() async {
    return await _client
        .from('properties')
        .select('*, caretaker:caretaker_id(full_name)')
        .order('name', ascending: true);
  }

  Future<Map<String, dynamic>> getProperty(String id) async {
    return await _client.from('properties').select().eq('id', id).single();
  }

  Future<void> createProperty(Map<String, dynamic> data) async {
    await _client.from('properties').insert(data);
  }

  Future<void> updateProperty(String id, Map<String, dynamic> data) async {
    await _client.from('properties').update(data).eq('id', id);
  }

  Future<void> deleteProperty(String id) async {
    await _client.from('properties').delete().eq('id', id);
  }

  // ─── Assets ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAssets({String? propertyId}) async {
    var query = _client.from('assets').select();
    if (propertyId != null) query = query.eq('property_id', propertyId);
    return await query.order('name', ascending: true);
  }

  Future<Map<String, dynamic>> getAsset(String id) async {
    return await _client.from('assets').select().eq('id', id).single();
  }

  Future<void> createAsset(Map<String, dynamic> data) async {
    await _client.from('assets').insert(data);
  }

  Future<void> updateAsset(String id, Map<String, dynamic> data) async {
    await _client.from('assets').update(data).eq('id', id);
  }

  Future<void> deleteAsset(String id) async {
    await _client.from('assets').delete().eq('id', id);
  }

  // ─── Work Orders ──────────────────────────────────────

  Future<List<Map<String, dynamic>>> getWorkOrders({
    String? status,
    String? propertyId,
    String? assignedTo,
  }) async {
    var query = _client.from('work_orders').select();
    if (status != null) query = query.eq('status', status);
    if (propertyId != null) query = query.eq('property_id', propertyId);
    if (assignedTo != null) query = query.eq('assigned_to', assignedTo);
    return await query.order('created_at', ascending: false);
  }

  Future<void> createWorkOrder(Map<String, dynamic> data) async {
    await _client.from('work_orders').insert(data);
  }

  Future<void> updateWorkOrderStatus(String id, String status) async {
    await _client.from('work_orders').update({'status': status}).eq('id', id);
  }

  // ─── Expenses ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getExpenses({
    String? workOrderId,
    String? propertyId,
  }) async {
    var query = _client.from('expenses').select();
    if (workOrderId != null) query = query.eq('work_order_id', workOrderId);
    if (propertyId != null) query = query.eq('property_id', propertyId);
    return await query.order('expense_date', ascending: false);
  }

  Future<void> createExpense(Map<String, dynamic> data) async {
    await _client.from('expenses').insert(data);
  }

  // ─── PM Schedules ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPmSchedules({
    bool? dueSoon,
    String? assetId,
    String? assignedTo,
  }) async {
    try {
      var query = _client
          .from('pm_schedules')
          .select('*, users:assigned_to(full_name)')
          .eq('is_active', true);
      if (assetId != null) query = query.eq('asset_id', assetId);
      if (assignedTo != null) query = query.eq('assigned_to', assignedTo);
      if (dueSoon == true) {
        final weekFromNow = DateTime.now().add(const Duration(days: 7));
        query = query.lte('next_due_date', weekFromNow.toIso8601String());
      }
      return await query.order('next_due_date', ascending: true);
    } catch (_) {
      // Fallback: query without join (assigned_to column may not exist yet)
      var query = _client
          .from('pm_schedules')
          .select()
          .eq('is_active', true);
      if (assetId != null) query = query.eq('asset_id', assetId);
      if (dueSoon == true) {
        final weekFromNow = DateTime.now().add(const Duration(days: 7));
        query = query.lte('next_due_date', weekFromNow.toIso8601String());
      }
      return await query.order('next_due_date', ascending: true);
    }
  }

  Future<void> createPmSchedule(Map<String, dynamic> data) async {
    await _client.from('pm_schedules').insert(data);
  }

  Future<void> updatePmSchedule(String id, Map<String, dynamic> data) async {
    await _client.from('pm_schedules').update(data).eq('id', id);
  }

  Future<void> deletePmSchedule(String id) async {
    await _client.from('pm_schedules').delete().eq('id', id);
  }

  // ─── Storage ──────────────────────────────────────────

  Future<String> uploadFile(String bucket, String path, Uint8List bytes) async {
    await _client.storage.from(bucket).uploadBinary(path, bytes);
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  // ─── Dashboard Stats ─────────────────────────────────

  Future<int> getUrgentJobsCount() async {
    final data = await _client
        .from('work_orders')
        .select('id')
        .eq('priority', 'urgent')
        .neq('status', 'completed');
    return data.length;
  }

  Future<int> getTodayJobsCount() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    final data = await _client
        .from('work_orders')
        .select('id')
        .gte('created_at', start.toIso8601String())
        .lt('created_at', end.toIso8601String());
    return data.length;
  }

  // ─── User Management ─────────────────────────────────

  /// Get all users (for admin roles management)
  Future<List<Map<String, dynamic>>> getUsers() async {
    return await _client
        .from('users')
        .select()
        .order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> getTechnicians() async {
    return await _client
        .from('users')
        .select()
        .eq('role', 'technician')
        .order('full_name', ascending: true);
  }

  /// Get all users with 'caretaker' role
  Future<List<Map<String, dynamic>>> getCaretakers() async {
    return await _client
        .from('users')
        .select()
        .eq('role', 'caretaker')
        .order('full_name', ascending: true);
  }

  /// Get a single user by ID
  Future<Map<String, dynamic>?> getUser(String id) async {
    return await _client.from('users').select().eq('id', id).maybeSingle();
  }

  /// Update a user's role
  Future<void> updateUserRole(String userId, String role) async {
    await _client.from('users').update({'role': role}).eq('id', userId);
  }

  /// Update user profile
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _client.from('users').update(data).eq('id', userId);
  }

  /// Create a new user entry in the users table directly.
  /// The user can log in later via LINE or email signup.
  /// This avoids Supabase Auth signUp rate limiting (429).
  Future<void> createUser({
    required String fullName,
    required String email,
    required String role,
    String? phone,
  }) async {
    await _client.from('users').insert({
      'email': email,
      'full_name': fullName,
      'role': role,
      'phone': phone,
    });
  }

  // ─── LINE Notification ────────────────────────────────

  /// Send a LINE push message to a user (requires line_user_id)
  Future<void> sendLineNotification({
    required String lineUserId,
    required String message,
  }) async {
    final token = dotenv.env['LINE_MESSAGING_TOKEN'];
    if (token == null || token.isEmpty) return;

    await http.post(
      Uri.parse('https://api.line.me/v2/bot/message/push'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'to': lineUserId,
        'messages': [
          {'type': 'text', 'text': message},
        ],
      }),
    );
  }

  /// Notify assigned technician about a new work order via LINE
  Future<void> notifyWorkOrderAssigned({
    required String assignedToUserId,
    required String workOrderTitle,
    required String propertyName,
  }) async {
    try {
      final user = await getUser(assignedToUserId);
      if (user == null) return;
      final lineUserId = user['line_user_id'] as String?;
      if (lineUserId == null || lineUserId.isEmpty) return;

      await sendLineNotification(
        lineUserId: lineUserId,
        message:
            '📢 คุณได้รับมอบหมายงานใหม่!\n'
            '📝 $workOrderTitle\n'
            '🏠 บ้าน: $propertyName\n'
            'เข้าไปดูรายละเอียดได้ที่แอป BaanPool Ops',
      );
    } catch (_) {
      // Silent fail — notification is optional
    }
  }
}
