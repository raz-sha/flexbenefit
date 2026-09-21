import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

/// Privileged user-management actions (create/delete/reset password) are
/// performed by the `admin-users` Supabase Edge Function, which is the only
/// place the service-role key is used. This app's anon key can never do
/// those operations directly, by design.
class AdminService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<AppUser>> listUsers() async {
    final rows = await _client
        .from('profiles')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => AppUser.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
  }) {
    return _invoke('create', {
      'username': username,
      'password': password,
      'full_name': fullName,
      'role': role,
    });
  }

  /// Updates non-sensitive profile fields directly through the RLS
  /// admin-only policy (no Edge Function round trip needed).
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? role,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (role != null) updates['role'] = role;
    if (updates.isEmpty) return;
    await _client.from('profiles').update(updates).eq('id', userId);
  }

  Future<void> resetPassword({
    required String userId,
    required String newPassword,
  }) {
    return _invoke('reset_password', {
      'user_id': userId,
      'new_password': newPassword,
    });
  }

  Future<void> deleteUser(String userId) {
    return _invoke('delete', {'user_id': userId});
  }

  Future<void> _invoke(String action, Map<String, dynamic> payload) async {
    try {
      await _client.functions.invoke(
        'admin-users',
        body: {'action': action, ...payload},
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final message = (details is Map && details['error'] != null)
          ? details['error'].toString()
          : (e.reasonPhrase ?? 'Request failed');
      throw Exception(message);
    }
  }
}
