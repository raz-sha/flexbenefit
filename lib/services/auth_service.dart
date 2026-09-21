import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

/// Supabase Auth only accepts email-shaped identifiers, so a username is
/// mapped to a stable pseudo-email under a non-routable internal domain.
/// No real email is ever sent to or stored for the user beyond this.
class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  static const _pseudoEmailDomain = 'app.internal';

  static String usernameToEmail(String username) {
    return '${username.trim().toLowerCase()}@$_pseudoEmailDomain';
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentAuthUser => _client.auth.currentUser;

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: usernameToEmail(username),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<AppUser?> fetchCurrentProfile() async {
    final uid = currentAuthUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return null;
    return AppUser.fromMap(row);
  }
}
