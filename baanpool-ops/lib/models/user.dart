/// User model — maps to `users` table in Supabase
class AppUser {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? phone;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: UserRole.fromString(json['role'] as String),
      phone: json['phone'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'role': role.name,
    'phone': phone,
    'created_at': createdAt.toIso8601String(),
  };
}

enum UserRole {
  owner,
  manager,
  technician;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserRole.technician,
    );
  }
}
