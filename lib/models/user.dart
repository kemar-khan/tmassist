// lib/models/user.dart

import '../utils/enums.dart';

class AppUser {
  final String id;
  final String name;
  final UserRole role;
  final String? email;
  final String? phone;
  final String? address;

  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.phone,
    this.address,
  });

  AppUser copyWith({
    String? id,
    String? name,
    UserRole? role,
    String? email,
    String? phone,
    String? address,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
    );
  }

  @override
  String toString() => 'AppUser(id: $id, name: $name, role: ${role.name}, email: $email)';
}
