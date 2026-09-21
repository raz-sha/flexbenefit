import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'admin/admin_home_screen.dart';
import 'login_screen.dart';
import 'user/user_home_screen.dart';

/// Routes between the login screen and the correct role-based home screen,
/// reacting to Supabase auth state changes.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        final session = _authService.currentAuthUser;
        if (session == null) {
          return const LoginScreen();
        }
        return FutureBuilder<AppUser?>(
          future: _authService.fetchCurrentProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final profile = profileSnapshot.data;
            if (profile == null) {
              // Signed in but no profile row (e.g. account was deleted by
              // an admin from under them). Sign out and show login again.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _authService.signOut();
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return profile.isAdmin
                ? AdminHomeScreen(currentUser: profile)
                : UserHomeScreen(currentUser: profile);
          },
        );
      },
    );
  }
}
