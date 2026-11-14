// lib/app.dart

import 'package:flutter/material.dart';
import 'package:tmassist/features/auth/login_screen.dart';
import 'features/auth/role_router.dart';
import 'core/theme/app_theme.dart';
import 'router.dart';

class App extends StatelessWidget {
  /// True when a user was already signed in at startup (see main.dart).
  final bool signedIn;

  const App({super.key, this.signedIn = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TMAssist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: signedIn ? const RoleRouter() : const LoginScreen(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
