import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/area_grouping.dart';
import '../../utils/cancelled_status.dart';
import '../../utils/duration_format.dart';
import '../../utils/report_dates.dart';

class TechAnalyticsScreen extends StatefulWidget {
  const TechAnalyticsScreen({super.key});

  @override
  State<TechAnalyticsScreen> createState() => _TechAnalyticsScreenState();
}

class _TechAnalyticsScreenState extends State<TechAnalyticsScreen> {
  // The tickets are listened to once here (and again only on "Try Again"), so
  // a rebuild never re-subscribes or flashes the loading spinner.
  StreamSubscription<QuerySnapshot>? _sub;
  List<QueryDocumentSnapshot> _docs = [];
  bool _loaded = false;
  Object? _error;

  // When each resolved ticket's report was submitted. Shared with the Home
  // tab, so every report is read once between them.
  final ReportDateCache _reports = ReportDateCache.instance;

  @override
  void initState() {
    super.initState();
    _reports.addListener(_onReportDates);
    _listen();
  }

  void _listen() {
    _sub?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _sub = FirebaseFirestore.instance
        .collection('tickets')
        .where('technicianId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            setState(() {
              _docs = snap.docs;
              _loaded = true;
              _error = null;
            });
            _requestReports();
          },
          onError: (e) {
            if (!mounted) return;
            setState(() => _error = e);
          },
        );
  }

  @override
  void dispose() {
    _reports.removeListener(_onReportDates);
    _sub?.cancel();
    super.dispose();
  }

  static const _resolvedStatuses = {'RESOLVED', 'CLOSED'};

  void _onReportDates() {
    if (mounted) setState(() {});
  }

  /// Asks the shared cache for the reports of the resolved tickets, for the
  /// average resolution time.
  void _requestReports() {
    final wanted = <String, String>{};
    for (final doc in _docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString().toUpperCase();
      if (_resolvedStatuses.contains(status)) wanted[doc.id] = status;
    }
    _reports.ensure(wanted);
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
      body = _buildContent();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Analytics',
          style: AppText.title.copyWith(color: AppColors.ink),
        ),
        automaticallyImplyLeading: false,
      ),
      body: body,
    );
  }

  Widget _buildContent() {
    // Cancelled tickets are excluded from the technician's stats.
    final docs = _docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return !CancelledStatus.isCancelled(data['status']);
    }).toList();

    // --- KPI counts ---
    var inProgress = 0;
    var resolved = 0;
    for (final doc in docs) {
      final status = ((doc.data() as Map<String, dynamic>)['status'] ?? '')
          .toString()
          .toUpperCase();
      if (status == 'IN_PROGRESS') inProgress++;
      // A CLOSED ticket was RESOLVED first, so both count as resolved work.
      if (_resolvedStatuses.contains(status)) resolved++;
    }
    final total = docs.length;
    final resolutionRate = total > 0
        ? ((resolved / total) * 100).toStringAsFixed(0)
        : '0';

    // --- Checklist completion rate ---
    double totalCompletionRate = 0;
    int ticketsWithChecklist = 0;
    for (final doc in docs) {
      final raw = (doc.data() as Map<String, dynamic>)['checklistDone'];
      if (raw == null) continue;
      final done = List<bool>.from((raw as List).map((e) => e == true));
      if (done.isEmpty) continue;
      final completed = done.where((d) => d).length;
      totalCompletionRate += completed / done.length;
      ticketsWithChecklist++;
    }
    final avgChecklist = ticketsWithChecklist > 0
        ? totalCompletionRate / ticketsWithChecklist
        : 0.0;

    // --- Average resolution time: report submitted minus ticket created ---
    final durations = <Duration>[];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString().toUpperCase();
      if (!_resolvedStatuses.contains(status)) continue;
      final submitted = _reports[doc.id];
      final createdAt = data['createdAt'];
      if (submitted == null || createdAt is! Timestamp) continue;
      final taken = submitted.difference(createdAt.toDate());
      if (taken.isNegative) continue;
      durations.add(taken);
    }
    final avgResolution = durations.isEmpty
        ? null
        : Duration(
            microseconds:
                durations.fold<int>(0, (s, d) => s + d.inMicroseconds) ~/
                durations.length,
          );

    // --- Tickets by area ---
    final areas = groupByArea([
      for (final doc in docs)
        areaOfTicket(
          area: (doc.data() as Map<String, dynamic>)['area']?.toString(),
          address: (doc.data() as Map<String, dynamic>)['address']?.toString(),
        ),
    ]);

    return TechAnalyticsContent(
      total: total,
      inProgress: inProgress,
      resolved: resolved,
      resolutionRate: resolutionRate,
      checklistFraction: avgChecklist,
      ticketsWithChecklist: ticketsWithChecklist,
      avgResolution: avgResolution,
      areaCounts: areas,
    );
  }
}

/// The analytics page body. Separate from [TechAnalyticsScreen] so it can be
/// built without Firebase; the screen computes every value.
class TechAnalyticsContent extends StatelessWidget {
  final int total;
  final int inProgress;
  final int resolved;

  /// Whole percent as text, for example "64".
  final String resolutionRate;

  /// Average checklist completion (0 to 1) over [ticketsWithChecklist].
  final double checklistFraction;
  final int ticketsWithChecklist;

  /// Null when no resolved ticket has a usable report time.
  final Duration? avgResolution;

  /// Tickets per area, highest first, at most six entries.
  final List<MapEntry<String, int>> areaCounts;

  const TechAnalyticsContent({
    super.key,
    required this.total,
    required this.inProgress,
    required this.resolved,
    required this.resolutionRate,
    required this.checklistFraction,
    required this.ticketsWithChecklist,
    required this.avgResolution,
    required this.areaCounts,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // The floating nav bar sits over the bottom of the screen. Inside a
      // Scaffold with extendBody, the body's bottom padding already includes
      // the bar and the device's safe area, so only a gap is added here.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s4,
        AppSpacing.s4,
        MediaQuery.paddingOf(context).bottom + AppSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.confirmation_number_outlined,
                    foreground: AppColors.assignedFg,
                    background: AppColors.assignedBg,
                    value: '$total',
                    label: 'Total Assigned',
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.schedule,
                    foreground: AppColors.progressFg,
                    background: AppColors.progressBg,
                    value: '$inProgress',
                    label: 'In Progress',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.check_circle_outline,
                    foreground: AppColors.resolvedFg,
                    background: AppColors.resolvedBg,
                    value: '$resolved',
                    label: 'Resolved',
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.bar_chart_rounded,
                    foreground: AppColors.accentStrong,
                    background: AppColors.accentTint,
                    value: '$resolutionRate%',
                    label: 'Resolution Rate',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          _buildChecklistCard(),
          const SizedBox(height: AppSpacing.s4),
          _buildResolutionTimeCard(),
          const SizedBox(height: AppSpacing.s4),
          _AreaCard(counts: areaCounts),
        ],
      ),
    );
  }

  Widget _buildChecklistCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Checklist Performance',
            style: AppText.heading.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: AppSpacing.s3),
          if (ticketsWithChecklist == 0)
            Text(
              'No checklist data yet. Generate a checklist on a job to see your completion here.',
              style: AppText.body.copyWith(color: AppColors.inkMuted),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Avg. Checklist Completion',
                    style: AppText.body.copyWith(color: AppColors.inkMuted),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  '${(checklistFraction * 100).toStringAsFixed(0)}%',
                  style: AppText.title.copyWith(color: AppColors.ink),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            Semantics(
              label:
                  'Average checklist completion ${(checklistFraction * 100).toStringAsFixed(0)} percent',
              excludeSemantics: true,
              child: ClipRRect(
                borderRadius: AppRadius.brPill,
                child: Container(
                  height: 8,
                  color: AppColors.border,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: checklistFraction.clamp(0.0, 1.0),
                    child: Container(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              'Based on $ticketsWithChecklist ticket${ticketsWithChecklist == 1 ? '' : 's'} with checklist data',
              style: AppText.caption.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResolutionTimeCard() {
    final hasData = avgResolution != null;

    return _Card(
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_outlined, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Avg. Resolution Time',
                  style: AppText.body.copyWith(color: AppColors.inkMuted),
                ),
                Text(
                  hasData ? formatDuration(avgResolution!) : '–',
                  style: AppText.title.copyWith(
                    color: AppColors.ink,
                    fontSize: 24,
                  ),
                ),
                Text(
                  hasData
                      ? 'from ticket created to report submitted'
                      : 'No resolved tickets yet',
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White card with the standard radius, shadow and padding.
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color foreground;
  final Color background;
  final String value;
  final String label;

  const _SummaryCard({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: foreground),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Semantics(
              label: '$label, $value',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      value,
                      style: AppText.title.copyWith(
                        color: foreground,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    textAlign: TextAlign.right,
                    style: AppText.caption.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical bars of tickets per area; the highest area is highlighted.
class _AreaCard extends StatelessWidget {
  final List<MapEntry<String, int>> counts;

  const _AreaCard({required this.counts});

  static const double _plotHeight = 150;
  static const double _maxBarWidth = 44;
  static const double _minBarHeight = 4;

  @override
  Widget build(BuildContext context) {
    final totalTickets = counts.fold<int>(0, (s, e) => s + e.value);
    final label =
        'Tickets by area: ${counts.map((e) => '${e.key} ${e.value}').join(', ')}';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tickets by Area',
                  style: AppText.heading.copyWith(color: AppColors.ink),
                ),
              ),
              Text(
                '$totalTickets ticket${totalTickets == 1 ? '' : 's'}',
                style: AppText.caption.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          if (counts.isEmpty)
            Text(
              'No tickets yet.',
              style: AppText.body.copyWith(color: AppColors.inkMuted),
            )
          else
            Semantics(
              label: label,
              excludeSemantics: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // At most five columns share the card width equally; the
                  // area names wrap to two lines under them.
                  const gap = AppSpacing.s3;
                  final n = counts.length;
                  final slot = (constraints.maxWidth - gap * (n - 1)) / n;
                  return Center(child: _chart(slot, gap));
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _chart(double slot, double gap) {
    final maxCount = counts.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    // The plot holds the count above each bar, so the tallest bar leaves room
    // for it.
    final maxBar = _plotHeight - 40;
    final barWidth = math.min(_maxBarWidth, slot);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: _plotHeight,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < counts.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                SizedBox(
                  width: slot,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${counts[i].value}',
                        style: AppText.bodyStrong.copyWith(
                          color: i == 0 ? AppColors.primary : AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s1),
                      Container(
                        width: barWidth,
                        height: math.max(
                          _minBarHeight,
                          maxBar * counts[i].value / maxCount,
                        ),
                        decoration: BoxDecoration(
                          color: i == 0
                              ? AppColors.primary
                              : AppColors.chartMuted,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(AppRadius.sm),
                            topRight: Radius.circular(AppRadius.sm),
                            bottomLeft: const Radius.circular(2),
                            bottomRight: const Radius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < counts.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              SizedBox(
                width: slot,
                child: Text(
                  counts[i].key,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    color: i == 0 ? AppColors.primary : AppColors.inkMuted,
                    fontWeight: i == 0 ? FontWeight.w700 : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
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
              'Could not load your analytics.',
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
