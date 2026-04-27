import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../customer/customer_main_screen.dart';
import '../supervisor/supervisor_main_screen.dart';
import '../technician/technician_main_screen.dart';

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return FutureBuilder<Map<String, dynamic>?>(
      future: authService.getCurrentUserProfile(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Error
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final userData = snapshot.data;

        // No profile
        if (userData == null) {
          return const Scaffold(
            body: Center(child: Text('User profile not found')),
          );
        }

        final role = userData['role']?.toString();

        // Route
        if (role == 'customer') {
          return const CustomerMainScreen();
        } else if (role == 'supervisor') {
          return const SupervisorMainScreen();
        } else if (role == 'technician') {
          return const TechnicianMainScreen();
        }

        return const Scaffold(body: Center(child: Text('Invalid role')));
      },
    );
  }
}
