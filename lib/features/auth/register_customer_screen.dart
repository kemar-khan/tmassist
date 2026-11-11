// lib/features/auth/register_customer_screen.dart

import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/section_card.dart';
import '../../utils/friendly_error.dart';

class RegisterCustomerScreen extends StatefulWidget {
  const RegisterCustomerScreen({super.key});

  @override
  State<RegisterCustomerScreen> createState() => _RegisterCustomerScreenState();
}

class _RegisterCustomerScreenState extends State<RegisterCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential = await _authService.registerCustomer(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      showAppSnack(
        context,
        "Registration successful! Welcome.",
        kind: SnackKind.success,
      );

      Navigator.pushNamedAndRemoveUntil(context, '/customer', (route) => false);
    } catch (e, st) {
      if (!mounted) return;

      showAppSnack(
        context,
        friendlyError(
          e,
          fallback: 'Registration failed. Please try again.',
          stackTrace: st,
        ),
        kind: SnackKind.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Join Us",
                style: AppText.title.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                "Create your account to get started.",
                style: AppText.body.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.s4),
              SectionCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _nameController,
                        label: "Full Name",
                        hint: "Robert Kwok",
                        prefixIcon: Icons.person_outline,
                        validator: (val) => val == null || val.isEmpty
                            ? "Enter your name"
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        controller: _emailController,
                        label: "Email Address",
                        hint: "youremail@gmail.com",
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return "Enter your email";
                          }
                          if (!val.contains("@")) {
                            return "Enter a valid email";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        controller: _phoneController,
                        label: "Phone Number",
                        hint: "0123456789",
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Enter your phone number";
                          }
                          // Ignore spaces, dashes and brackets, then require
                          // 10 to 15 digits with an optional leading +.
                          final digitsOnly = val.trim().replaceAll(
                            RegExp(r'[\s\-()]'),
                            '',
                          );
                          if (!RegExp(
                            r'^\+?[0-9]{10,15}$',
                          ).hasMatch(digitsOnly)) {
                            return "Enter a valid phone number";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        controller: _addressController,
                        label: "Home Address",
                        prefixIcon: Icons.location_on_outlined,
                        maxLines: 3,
                        validator: (val) => val == null || val.isEmpty
                            ? "Enter your address"
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        controller: _passwordController,
                        label: "Password",
                        prefixIcon: Icons.lock_outline,
                        obscure: true,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return "Enter your password";
                          }
                          if (val.length < 6) {
                            return "Password must be at least 6 characters";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        controller: _confirmPasswordController,
                        label: "Confirm Password",
                        prefixIcon: Icons.lock_outline,
                        obscure: true,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return "Confirm your password";
                          }
                          if (val != _passwordController.text) {
                            return "Passwords do not match";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        // Keep the orange fill while loading so the white
                        // spinner stays visible on a disabled button.
                        style: _isLoading
                            ? ElevatedButton.styleFrom(
                                disabledBackgroundColor: AppColors.accentStrong,
                                disabledForegroundColor: AppColors.onPrimary,
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
                            : const Text("REGISTER"),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
