// lib/features/auth/login_screen.dart

import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/technician_access.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/home_header.dart';
import '../../widgets/section_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// A registration card on the login screen. The whole card is tappable.
class _RegisterCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _RegisterCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brMd,
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: AppRadius.brMd,
                      ),
                      child: Icon(icon, size: 22, color: AppColors.primary),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.inkMuted,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  title,
                  style: AppText.bodyStrong.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  subtitle,
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginScreenState extends State<LoginScreen> {
  // How far the form card overlaps the blue header.
  static const double _cardOverlap = AppSpacing.s8 + AppSpacing.s4;
  static const double _logoSize = 64;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userData = await _authService.getCurrentUserProfile();

      if (!mounted) return;

      final role = userData?['role']?.toString();

      if (role == 'customer') {
        Navigator.pushReplacementNamed(context, '/customer');
      } else if (role == 'supervisor') {
        Navigator.pushReplacementNamed(context, '/supervisor');
      } else if (role == 'technician') {
        switch (technicianAccessState(userData!)) {
          case TechnicianAccess.rejected:
            Navigator.pushReplacementNamed(context, '/tech/rejected');
          case TechnicianAccess.pending:
            Navigator.pushReplacementNamed(context, '/tech/waiting');
          case TechnicianAccess.approved:
            Navigator.pushReplacementNamed(context, '/tech');
        }
      } else {
        setState(() {
          _error = 'User role not found.';
        });
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: SafeArea(
        top: false,
        // The page fills the screen when it is short, so the card sits near
        // the vertical middle, and scrolls when it is taller (small phones,
        // keyboard open).
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Blue header: logo mark, app name, tagline. It grows to
                    // push the card towards the middle of the screen.
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.s4,
                          topInset + AppSpacing.s4,
                          AppSpacing.s4,
                          AppSpacing.s4 + _cardOverlap,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadius.bottomXl,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: _logoSize,
                                height: _logoSize,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceCard,
                                  borderRadius: AppRadius.brLg,
                                ),
                                child: const Icon(
                                  Icons.confirmation_number_outlined,
                                  size: AppSpacing.s8 + AppSpacing.s1,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s4),
                              Text(
                                "TM Assist",
                                textAlign: TextAlign.center,
                                style: AppText.display.copyWith(
                                  color: AppColors.onPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s1),
                              Text(
                                "AI - Assisted Ticketing System",
                                textAlign: TextAlign.center,
                                style: AppText.body.copyWith(
                                  color: AppColors.primaryTint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Form card, pulled up over the header.
                    HeaderOverlap(
                      amount: _cardOverlap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s4,
                        ),
                        child: SectionCard(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  "Sign In",
                                  style: AppText.title.copyWith(
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s4),

                                AppTextField(
                                  label: "Email Address",
                                  hint: "example@email.com",
                                  prefixIcon: Icons.email_outlined,
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  enabled: !_isLoading,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: AppSpacing.s4),

                                AppTextField(
                                  label: "Password",
                                  hint: "Enter your password",
                                  prefixIcon: Icons.lock_outline,
                                  controller: _passwordController,
                                  obscure: true,
                                  enabled: !_isLoading,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            Navigator.pushNamed(
                                              context,
                                              '/forgot-password',
                                            );
                                          },
                                    child: const Text("Forgot Password?"),
                                  ),
                                ),

                                if (_error != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.s3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.cancelledBg,
                                      borderRadius: AppRadius.brMd,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          size: 20,
                                          color: AppColors.cancelledFg,
                                        ),
                                        const SizedBox(width: AppSpacing.s3),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: AppText.body.copyWith(
                                              color: AppColors.cancelledFg,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.s4),
                                ],

                                ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  // Keep the orange fill while loading so the white
                                  // spinner stays visible on a disabled button.
                                  style: _isLoading
                                      ? ElevatedButton.styleFrom(
                                          disabledBackgroundColor:
                                              AppColors.accentStrong,
                                          disabledForegroundColor:
                                              AppColors.onPrimary,
                                        )
                                      : null,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: AppColors.onPrimary,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text("LOG IN"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.s4),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "New to TMAssist?",
                            style: AppText.bodyStrong.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s3),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _RegisterCard(
                                    icon: Icons.person_outline,
                                    title: "Register as Customer",
                                    subtitle: "Report and track service issues",
                                    onTap: _isLoading
                                        ? null
                                        : () => Navigator.pushNamed(
                                            context,
                                            '/register',
                                          ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s3),
                                Expanded(
                                  child: _RegisterCard(
                                    icon: Icons.handyman_outlined,
                                    title: "Register as Technician",
                                    subtitle: "Needs supervisor approval",
                                    onTap: _isLoading
                                        ? null
                                        : () => Navigator.pushNamed(
                                            context,
                                            '/register-technician',
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Expanded(flex: 3, child: SizedBox.shrink()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
