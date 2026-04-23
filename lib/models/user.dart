// lib/models/user.dart

import '../utils/enums.dart';

class AppUser {
  final String id;
  final String name;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.role,
  });

  AppUser copyWith({
    String? id,
    String? name,
    UserRole? role,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }

  @override
  String toString() => 'AppUser(id: $id, name: $name, role: ${role.name})';
}