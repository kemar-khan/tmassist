// lib/features/auth/technician_access_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// Shown to a technician who cannot use the app yet: either the request is
/// waiting for a supervisor, or it was not approved. Log Out signs out and
/// returns to the login screen.
class TechnicianAccessScreen extends StatelessWidget {
  final bool rejected;

  const TechnicianAccessScreen({super.key, required this.rejected});

  Future<void> _logOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final title = rejected
        ? 'Request Not Approved'
        : 'Waiting for Supervisor Approval';
    final message = rejected
        ? 'Please contact your supervisor.'
        : 'A supervisor will review your request. '
              'You can log in again later to check.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ExcludeSemantics(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: rejected
                            ? AppColors.cancelledBg
                            : AppColors.newBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        rejected
                            ? Icons.block_rounded
                            : Icons.hourglass_empty_rounded,
                        size: 44,
                        color: rejected
                            ? AppColors.cancelledFg
                            : AppColors.newFg,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppText.title.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.s6),
                OutlinedButton(
                  onPressed: () => _logOut(context),
                  child: const Text('Log Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
