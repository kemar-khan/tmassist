import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/service_areas.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/section_card.dart';
import '../../utils/report_dates.dart';
import 'coverage_areas_controller.dart';

class TechnicianProfileScreen extends StatefulWidget {
  const TechnicianProfileScreen({super.key});

  @override
  State<TechnicianProfileScreen> createState() =>
      _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> {
  // The profile is listened to once here (and again only on "Try Again"), so a
  // rebuild never re-subscribes or flashes the loading spinner.
  StreamSubscription<DocumentSnapshot>? _sub;
  Map<String, dynamic>? _data;
  bool _loaded = false;
  Object? _error;

  late final CoverageAreasController _coverage;

  @override
  void initState() {
    super.initState();
    _coverage = CoverageAreasController(_saveCoverage);
    _listen();
  }

  Future<void> _saveCoverage(List<String> areas) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid).update({
      'coverageAreas': areas,
    });
  }

  void _listen() {
    _sub?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            final data = snap.data();
            _coverage.syncFromServer(
              List<String>.from(data?['coverageAreas'] ?? []),
            );
            setState(() {
              _data = data;
              _loaded = true;
              _error = null;
            });
          },
          onError: (e) {
            if (!mounted) return;
            setState(() => _error = e);
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _coverage.dispose();
    super.dispose();
  }

  /// The value as trimmed text, or null when it is missing or empty.
  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<void> _toggleArea(String area) async {
    final ok = await _coverage.toggle(area);
    if (!ok && mounted) {
      showAppSnack(
        context,
        'Could not save your areas. Please try again.',
        kind: SnackKind.error,
      );
    }
  }

  Future<void> _logout() async {
    ReportDateCache.instance.clear();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    final Widget body;
    if (_error != null) {
      body = _ErrorState(
        onRetry: () => setState(() {
          _error = null;
          _loaded = false;
          _listen();
        }),
      );
    } else if (!_loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final data = _data;
      body = TechnicianProfileContent(
        name:
            _text(data?['fullName']) ??
            _text(firebaseUser.email) ??
            'Technician',
        staffId: _text(data?['staffId']) ?? _text(data?['employeeId']),
        email: _text(data?['email']) ?? _text(firebaseUser.email),
        specialization: _text(data?['specialization']),
        coverage: _coverage,
        onToggleArea: _toggleArea,
        onLogout: _logout,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: AppText.title.copyWith(color: AppColors.ink),
        ),
        automaticallyImplyLeading: false,
      ),
      body: body,
    );
  }
}

/// The profile page body. Separate from [TechnicianProfileScreen] so it can be
/// built without Firebase. Account rows that are null or empty are hidden;
/// nothing is invented in their place.
class TechnicianProfileContent extends StatelessWidget {
  final String name;
  final String? staffId;
  final String? email;
  final String? specialization;
  final CoverageAreasController coverage;
  final ValueChanged<String> onToggleArea;
  final VoidCallback onLogout;

  const TechnicianProfileContent({
    super.key,
    required this.name,
    required this.staffId,
    required this.email,
    required this.specialization,
    required this.coverage,
    required this.onToggleArea,
    required this.onLogout,
  });

  static bool _has(String? value) => value != null && value.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final rows = <_ProfileRow>[
      if (_has(staffId))
        _ProfileRow(Icons.badge_outlined, 'Staff ID', staffId!),
      if (_has(email)) _ProfileRow(Icons.mail_outline, 'Email', email!),
      if (_has(specialization))
        _ProfileRow(
          Icons.home_repair_service_outlined,
          'Specialization',
          specialization!,
        ),
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
            ListenableBuilder(
              listenable: coverage,
              builder: (context, _) => _CoverageCard(
                areas: coverage.areas,
                saving: coverage.saving,
                onToggle: onToggleArea,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
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

/// Centred avatar (the first letter of the name), the name and the role.
class _AccountBlock extends StatelessWidget {
  final String name;

  const _AccountBlock({required this.name});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? 'T'
        : trimmed.substring(0, 1).toUpperCase();

    return Semantics(
      container: true,
      label: '$name, Field Technician',
      excludeSemantics: true,
      child: Column(
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
                'assets/images/technician_icon.png',
                width: 64,
                height: 64,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                // A missing image falls back to the first letter of the name.
                errorBuilder: (context, error, stackTrace) => Text(
                  initial,
                  style: AppText.display.copyWith(
                    color: AppColors.primary,
                    fontSize: 32,
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
              'Field Technician',
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

class _CoverageCard extends StatelessWidget {
  final List<String> areas;
  final bool saving;
  final ValueChanged<String> onToggle;

  const _CoverageCard({
    required this.areas,
    required this.saving,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final choices = ServiceAreas.all.where((a) => a != 'Other').toList();
    final count = areas.length;

    // Two equal columns; a row grows with its tallest button.
    final rows = <Widget>[];
    for (var i = 0; i < choices.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: AppSpacing.s2));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _AreaToggle(
                  label: choices[i],
                  selected: areas.contains(choices[i]),
                  enabled: !saving,
                  onTap: () => onToggle(choices[i]),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              if (i + 1 < choices.length)
                Expanded(
                  child: _AreaToggle(
                    label: choices[i + 1],
                    selected: areas.contains(choices[i + 1]),
                    enabled: !saving,
                    onTap: () => onToggle(choices[i + 1]),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ),
      );
    }

    return SectionCard(
      title: 'Coverage Areas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            count == 0
                ? 'No areas assigned'
                : '$count area${count == 1 ? '' : 's'} assigned',
            style: AppText.body.copyWith(
              color: count == 0 ? AppColors.accentStrong : AppColors.inkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          // A brief faded state while a change is being saved.
          Opacity(
            opacity: saving ? 0.6 : 1,
            child: Column(children: rows),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            'Tap an area to add or remove it. New tickets in these areas are assigned to you first.',
            style: AppText.caption.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _AreaToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _AreaToggle({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: selected,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
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
          onTap: enabled ? onTap : null,
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
                      label,
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
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.cancelledBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: AppColors.cancelledFg,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Could not load your profile.',
              textAlign: TextAlign.center,
              style: AppText.heading.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.s2),
            TextButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
