// lib/features/auth/register_technician_screen.dart

import 'package:flutter/material.dart';
import '../../core/constants/service_areas.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/contact_validation.dart';
import '../../utils/friendly_error.dart';
import '../../utils/staff_id.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/picker_sheet.dart';
import '../../widgets/section_card.dart';

class RegisterTechnicianScreen extends StatefulWidget {
  const RegisterTechnicianScreen({super.key});

  @override
  State<RegisterTechnicianScreen> createState() =>
      _RegisterTechnicianScreenState();
}

class _RegisterTechnicianScreenState extends State<RegisterTechnicianScreen> {
  /// The same options the ticket categories (and so auto-assignment) use.
  static const List<String> _specializations = [
    'Network',
    'Hardware',
    'Software',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _staffIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();

  String? _specialization;
  final Set<String> _areas = {};
  bool _showAreaError = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _staffIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final formOk = _formKey.currentState!.validate();
    if (_areas.isEmpty) setState(() => _showAreaError = true);
    if (!formOk || _areas.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _authService.registerTechnician(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        staffId: normalizeStaffId(_staffIdController.text)!,
        specialization: _specialization!,
        // Keep the order of the master list.
        coverageAreas: ServiceAreas.coverageChoices
            .where(_areas.contains)
            .toList(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/tech/waiting',
        (route) => false,
      );
    } catch (e, st) {
      if (!mounted) return;

      showAppSnack(
        context,
        e is AuthException
            ? e.message
            : friendlyError(
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

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.s1),
    child: Text(
      text,
      style: AppText.caption.copyWith(color: AppColors.inkMuted),
    ),
  );

  Widget _specializationField() {
    return FormField<String>(
      validator: (_) =>
          _specialization == null ? 'Select your specialization' : null,
      builder: (state) => AppPickerField(
        label: 'Specialization',
        value: _specialization,
        hint: 'Select specialization',
        prefixIcon: Icons.home_repair_service_outlined,
        errorText: state.errorText,
        onTap: () async {
          final picked = await showPickerSheet<String>(
            context,
            title: 'Specialization',
            options: _specializations,
            selected: _specialization,
          );
          if (picked == null) return;
          setState(() => _specialization = picked);
          state.didChange(picked);
        },
      ),
    );
  }

  Widget _coverageField() {
    final choices = ServiceAreas.coverageChoices;
    final rows = <Widget>[];
    for (var i = 0; i < choices.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: AppSpacing.s2));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _areaChip(choices[i])),
              const SizedBox(width: AppSpacing.s2),
              if (i + 1 < choices.length)
                Expanded(child: _areaChip(choices[i + 1]))
              else
                const Spacer(),
            ],
          ),
        ),
      );
    }

    final error = _showAreaError && _areas.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coverage Areas',
          style: AppText.caption.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.s1),
        Column(children: rows),
        const SizedBox(height: AppSpacing.s1),
        Text(
          'Select at least one area',
          style: AppText.caption.copyWith(
            color: error ? AppColors.cancelledFg : AppColors.inkMuted,
          ),
        ),
      ],
    );
  }

  Widget _areaChip(String area) {
    final selected = _areas.contains(area);
    return Semantics(
      toggled: selected,
      label: area,
      excludeSemantics: true,
      onTap: _isLoading ? null : () => _toggleArea(area),
      child: Material(
        color: selected ? AppColors.primary : AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brMd,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.borderStrong,
            width: selected ? 2 : 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _isLoading ? null : () => _toggleArea(area),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s2,
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    size: 18,
                    color: selected ? AppColors.onPrimary : AppColors.inkMuted,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      area,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(
                        color: selected ? AppColors.onPrimary : AppColors.ink,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleArea(String area) {
    setState(() {
      if (!_areas.remove(area)) _areas.add(area);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Technician Registration',
          style: AppText.heading.copyWith(color: AppColors.ink),
        ),
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
                'Request Technician Access',
                style: AppText.title.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                'Fill in your staff details to join TMAssist.',
                style: AppText.body.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.s4),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s3),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: AppRadius.brMd,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Text(
                        'Your account will be reviewed by a supervisor '
                        'before you can start receiving tickets.',
                        style: AppText.body.copyWith(color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
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
                        label: 'Full Name',
                        hint: 'Your full name',
                        prefixIcon: Icons.person_outline,
                        enabled: !_isLoading,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Enter your name'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        controller: _staffIdController,
                        label: 'TM Staff ID',
                        hint: 'e.g. TM571',
                        prefixIcon: Icons.badge_outlined,
                        enabled: !_isLoading,
                        validator: validateStaffId,
                      ),
                      _hint('TM followed by digits'),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'you@example.com',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        validator: validateEmail,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        hint: 'e.g. 0123456789',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        enabled: !_isLoading,
                        validator: validatePhone,
                      ),
                      _hint('10 to 15 digits'),
                      const SizedBox(height: AppSpacing.s4),
                      _specializationField(),
                      const SizedBox(height: AppSpacing.s4),
                      _coverageField(),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Create a password',
                        prefixIcon: Icons.lock_outline,
                        obscure: true,
                        enabled: !_isLoading,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Enter your password';
                          }
                          if (val.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        hint: 'Repeat your password',
                        prefixIcon: Icons.lock_outline,
                        obscure: true,
                        enabled: !_isLoading,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Confirm your password';
                          }
                          if (val != _passwordController.text) {
                            return 'Passwords do not match';
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
                            : const Text('Request Access'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Already registered?',
                      style: AppText.body.copyWith(color: AppColors.inkMuted),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/login',
                              (route) => false,
                            ),
                      child: const Text('Log In'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
