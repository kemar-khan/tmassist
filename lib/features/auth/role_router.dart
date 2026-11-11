import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/stream_error.dart';
import '../customer/customer_main_screen.dart';
import '../supervisor/supervisor_main_screen.dart';
import '../technician/technician_main_screen.dart';

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  final AuthService _authService = AuthService();

  // Created once; "Try Again" replaces it with a new request.
  late Future<Map<String, dynamic>?> _profile;

  @override
  void initState() {
    super.initState();
    _profile = _authService.getCurrentUserProfile();
  }

  void _retry() {
    setState(() => _profile = _authService.getCurrentUserProfile());
  }

  // The auth gate shows the login screen once the user is signed out.
  void _logOut() => FirebaseAuth.instance.signOut();

  Widget _problem({Object? error, String? message}) {
    return Scaffold(
      body: StreamError(
        error: error,
        message: message,
        onRetry: _retry,
        onLogOut: _logOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profile,
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Error
        if (snapshot.hasError) {
          return _problem(error: snapshot.error);
        }

        final userData = snapshot.data;

        // No profile
        if (userData == null) {
          return _problem(
            message: 'We could not find your profile. Please try again.',
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

        return _problem(
          message: 'Your account has no valid role. Please contact support.',
        );
      },
    );
  }
}
