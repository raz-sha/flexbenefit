import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/admin_service.dart';

/// Bottom sheet used both to create a new user and to edit an existing one.
/// When [existingUser] is null this is "create" mode (username/password
/// required); otherwise it edits profile fields and offers a password reset.
class AdminUserFormSheet extends StatefulWidget {
  final AppUser? existingUser;

  const AdminUserFormSheet({super.key, this.existingUser});

  bool get isEditing => existingUser != null;

  @override
  State<AdminUserFormSheet> createState() => _AdminUserFormSheetState();
}

class _AdminUserFormSheetState extends State<AdminUserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _adminService = AdminService();

  late final _usernameController = TextEditingController(
    text: widget.existingUser?.username ?? '',
  );
  late final _fullNameController = TextEditingController(
    text: widget.existingUser?.fullName ?? '',
  );
  final _passwordController = TextEditingController();
  late String _role = widget.existingUser?.role ?? 'user';

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      if (widget.isEditing) {
        await _adminService.updateProfile(
          userId: widget.existingUser!.id,
          fullName: _fullNameController.text.trim(),
          role: _role,
        );
        if (_passwordController.text.isNotEmpty) {
          await _adminService.resetPassword(
            userId: widget.existingUser!.id,
            newPassword: _passwordController.text,
          );
        }
      } else {
        await _adminService.createUser(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          role: _role,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isEditing ? 'Edit user' : 'Add user',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              enabled: !widget.isEditing,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(v)) {
                  return '3-20 chars: lowercase letters, numbers, _';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: widget.isEditing ? 'New password (optional)' : 'Password',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (widget.isEditing && (value == null || value.isEmpty)) {
                  return null;
                }
                if ((value?.length ?? 0) < 6) {
                  return 'At least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'user', child: Text('User')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (value) => setState(() => _role = value ?? 'user'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEditing ? 'Save changes' : 'Create user'),
            ),
          ],
        ),
      ),
    );
  }
}
