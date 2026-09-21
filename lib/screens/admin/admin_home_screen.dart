import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import 'admin_user_form_sheet.dart';

class AdminHomeScreen extends StatefulWidget {
  final AppUser currentUser;

  const AdminHomeScreen({super.key, required this.currentUser});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _adminService = AdminService();
  late Future<List<AppUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _adminService.listUsers();
  }

  void _reload() {
    setState(() {
      _usersFuture = _adminService.listUsers();
    });
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AdminUserFormSheet(),
    );
    if (created == true) _reload();
  }

  Future<void> _openEditSheet(AppUser user) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AdminUserFormSheet(existingUser: user),
    );
    if (changed == true) _reload();
  }

  Future<void> _confirmDelete(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user'),
        content: Text('Delete "${user.username}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _adminService.deleteUser(user.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.person_add),
        label: const Text('Add user'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<AppUser>>(
          future: _usersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final users = snapshot.data ?? [];
            if (users.isEmpty) {
              return const Center(child: Text('No users yet'));
            }
            return ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      user.username.isNotEmpty
                          ? user.username[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(
                    user.fullName.isNotEmpty ? user.fullName : user.username,
                  ),
                  subtitle: Text('@${user.username} · ${user.role}'),
                  onTap: () => _openEditSheet(user),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: user.id == widget.currentUser.id
                        ? null
                        : () => _confirmDelete(user),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
