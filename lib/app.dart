// lib/app.dart

import 'package:flutter/material.dart';
import 'package:tmassist/features/auth/login_screen.dart';
import 'core/theme/app_theme.dart';
import 'router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TMAssist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
