class AppUser {
  final String id;
  final String username;
  final String fullName;
  final String role;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      username: map['username'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      role: map['role'] as String? ?? 'user',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }
}
