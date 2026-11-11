// lib/features/customer/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import 'speed_test_screen.dart';
import '../../widgets/stream_error.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile'), actions: []),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return StreamError(error: snapshot.error);
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'User profile not found',
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final name = data['fullName'] ?? 'User';
          final email = data['email'] ?? firebaseUser.email ?? '-';
          final phone = data['phone'] ?? '-';
          final address = data['address'] ?? '-';

          return ProfileContent(
            name: name.toString(),
            email: email.toString(),
            phone: phone.toString(),
            address: address.toString(),
            onOpenSpeedTest: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SpeedTestScreen(),
                ),
              );
            },
            onLogout: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          );
        },
      ),
    );
  }
}

/// The profile page body: account card, contact details, speed test entry and
/// log out. Separate from [ProfileScreen] so it needs no Firebase to build.
class ProfileContent extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final String address;
  final VoidCallback onOpenSpeedTest;
  final VoidCallback onLogout;

  const ProfileContent({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.onOpenSpeedTest,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // The bottom inset (floating nav bar and safe area) is added to the
      // scroll padding below.
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s4,
          AppSpacing.s4,
          AppSpacing.s4,
          MediaQuery.paddingOf(context).bottom + AppSpacing.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              // SectionCard aligns its content to the start, so the column
              // takes the full card width to centre its children.
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 72,
                        height: 72,
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryTint,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/customer_icon.png',
                            width: 56,
                            height: 56,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                            // A missing image falls back to the plain icon.
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.person,
                                  size: 36,
                                  color: AppColors.primary,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: AppText.title.copyWith(color: AppColors.ink),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            SectionCard(
              title: 'Contact Information',
              child: Column(
                children: [
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    value: phone,
                    showDivider: true,
                  ),
                  _ContactRow(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: address,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            _SpeedTestTile(onTap: onOpenSpeedTest),
            const SizedBox(height: AppSpacing.s2),
            OutlinedButton.icon(
              onPressed: onLogout,
              style: AppButtonStyles.destructive,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A contact detail: icon circle, label above the value.
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                ),
                Text(
                  value,
                  style: AppText.body.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedTestTile extends StatelessWidget {
  final VoidCallback onTap;

  const _SpeedTestTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.speed,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Internet Speed Test',
                          style: AppText.bodyStrong.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Check your internet connection speed',
                          style: AppText.caption.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.inkFaint),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
