import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';

class SupervisorProfileScreen extends StatelessWidget {
  const SupervisorProfileScreen({super.key});

  // Shown when the user document has no Staff ID / Department of its own.
  static const String _defaultStaffId = 'TM-10482';
  static const String _defaultDepartment = 'Field Operation Supervisor';

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Profile'),
        automaticallyImplyLeading: false,
      ),
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
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Error: ${snapshot.error}',
            );
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;

          // A real value is shown when there is one; Staff ID and Department
          // otherwise use the fixed defaults below.
          final name = _text(data?['fullName']) ?? 'Supervisor';
          final email = _text(data?['email']) ?? _text(firebaseUser.email);
          final staffId =
              _text(data?['staffId']) ??
              _text(data?['employeeId']) ??
              _defaultStaffId;
          final department = _text(data?['department']) ?? _defaultDepartment;

          return SupervisorProfileContent(
            name: name,
            email: email,
            staffId: staffId,
            department: department,
            onLogout: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
          );
        },
      ),
    );
  }

  /// The value as trimmed text, or null when it is missing or empty.
  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

/// The profile page body. Separate from [SupervisorProfileScreen] so it can
/// be built without Firebase. Optional fields that are null or empty are
/// hidden; nothing is invented in their place.
class SupervisorProfileContent extends StatelessWidget {
  final String name;
  final String? email;
  final String? staffId;
  final String? department;
  final VoidCallback onLogout;

  const SupervisorProfileContent({
    super.key,
    required this.name,
    required this.email,
    required this.staffId,
    required this.department,
    required this.onLogout,
  });

  static bool _has(String? value) => value != null && value.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final rows = <_ProfileRow>[
      if (_has(email)) _ProfileRow(Icons.mail_outline, 'Email Address', email!),
      if (_has(staffId))
        _ProfileRow(Icons.badge_outlined, 'Staff ID', staffId!),
      if (_has(department))
        _ProfileRow(Icons.apartment_outlined, 'Department', department!),
    ];

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
            _AccountBlock(name: name),
            const SizedBox(height: AppSpacing.s4),
            if (rows.isNotEmpty) ...[
              SectionCard(
                title: 'Account Information',
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      _InfoLine(row: rows[i], showDivider: i < rows.length - 1),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
            ],
            OutlinedButton.icon(
              onPressed: onLogout,
              style: AppButtonStyles.destructive,
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centred avatar, the name and the role.
class _AccountBlock extends StatelessWidget {
  final String name;

  const _AccountBlock({required this.name});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$name, Supervisor',
      excludeSemantics: true,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80,
                height: 80,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/supervisor_icon.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    // A missing image falls back to the plain icon.
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.person_outline,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    // A ring in the page colour, so the badge reads as cut
                    // out of the avatar.
                    border: Border.all(color: AppColors.surfaceBg, width: 3),
                  ),
                  child: const Icon(
                    Icons.verified_user,
                    size: 14,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            name,
            textAlign: TextAlign.center,
            style: AppText.title.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: AppSpacing.s2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s1,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: AppRadius.brPill,
            ),
            child: Text(
              'Supervisor',
              style: AppText.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow(this.icon, this.label, this.value);
}

/// An account detail: icon circle, label above the value. The value wraps.
class _InfoLine extends StatelessWidget {
  final _ProfileRow row;
  final bool showDivider;

  const _InfoLine({required this.row, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: Icon(row.icon, size: 20, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                ),
                Text(
                  row.value,
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
