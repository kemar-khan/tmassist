import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/cancelled_status.dart';
import '../../utils/category_icons.dart';
import '../../utils/week_utils.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/header_icon_badge.dart';
import '../../widgets/home_header.dart';
import '../../widgets/section_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/ticket_stub_pattern.dart';

/// A ticket as the technician Home shows it.
class TechTicketItem {
  final String id;
  final String title;

  /// The stored status in capitals, for example `IN_PROGRESS`.
  final String status;
  final String category;
  final String address;
  final String area;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Number of checklist items, and how many of them are ticked.
  final int checklistTotal;
  final int checklistDone;

  const TechTicketItem({
    required this.id,
    required this.title,
    required this.status,
    this.category = '',
    this.address = '',
    this.area = '',
    this.createdAt,
    this.updatedAt,
    this.checklistTotal = 0,
    this.checklistDone = 0,
  });
}

/// The active jobs (IN_PROGRESS or ASSIGNED only) in the order the Home shows
/// them: IN_PROGRESS first, newest update first; then ASSIGNED, oldest
/// creation first.
List<TechTicketItem> sortActiveTickets(Iterable<TechTicketItem> tickets) {
  final inProgress = tickets.where((t) => t.status == 'IN_PROGRESS').toList()
    ..sort((a, b) {
      // A missing update time is a write still in flight: treat it as newest.
      final au = a.updatedAt ?? DateTime.now();
      final bu = b.updatedAt ?? DateTime.now();
      return bu.compareTo(au);
    });
  final assigned = tickets.where((t) => t.status == 'ASSIGNED').toList()
    ..sort((a, b) {
      final ac = a.createdAt;
      final bc = b.createdAt;
      if (ac == null && bc == null) return 0;
      if (ac == null) return 1;
      if (bc == null) return -1;
      return ac.compareTo(bc);
    });
  return [...inProgress, ...assigned];
}

/// Tickets resolved per weekday this week (index 0 = Monday), from the dates
/// they were resolved on. Only dates from Monday 00:00 up to [now] count.
List<int> weeklyResolvedCounts(Iterable<DateTime> resolvedDates, DateTime now) {
  final counts = List<int>.filled(7, 0);
  final start = startOfCurrentWeek(now);
  for (final d in resolvedDates) {
    if (d.isBefore(start) || d.isAfter(now)) continue;
    counts[d.weekday - 1]++;
  }
  return counts;
}

class TechHomeScreen extends StatefulWidget {
  /// Opens the Tasks tab with a status filter ('All', 'ASSIGNED', ...).
  final ValueChanged<String>? onOpenTasksWithStatus;

  /// Opens the Profile tab.
  final VoidCallback? onOpenProfile;

  const TechHomeScreen({
    super.key,
    this.onOpenTasksWithStatus,
    this.onOpenProfile,
  });

  @override
  State<TechHomeScreen> createState() => _TechHomeScreenState();
}

class _TechHomeScreenState extends State<TechHomeScreen> {
  // The data streams are listened to once, here, so a rebuild never
  // re-subscribes or flashes the loading spinner.
  StreamSubscription<DocumentSnapshot>? _userSub;
  StreamSubscription<QuerySnapshot>? _ticketSub;

  String? _fullName;
  List<String>? _coverageAreas; // null until the user document has arrived
  List<QueryDocumentSnapshot> _docs = [];
  bool _ticketsLoaded = false;
  Object? _error;

  // When each resolved ticket's report was submitted (reports/{ticketId}
  // `submittedAt`), fetched once per ticket and kept.
  final Map<String, Object?> _submittedAt = {};
  final Set<String> _requestedReports = {};

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
          final data = snap.data();
          if (!mounted) return;
          setState(() {
            _fullName = data?['fullName']?.toString();
            _coverageAreas = List<String>.from(data?['coverageAreas'] ?? []);
          });
        }, onError: (_) {});

    _ticketSub = FirebaseFirestore.instance
        .collection('tickets')
        .where('technicianId', isEqualTo: user.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            setState(() {
              _docs = snap.docs;
              _ticketsLoaded = true;
              _error = null;
            });
            _fetchReports();
          },
          onError: (e) {
            if (!mounted) return;
            setState(() => _error = e);
          },
        );
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _ticketSub?.cancel();
    super.dispose();
  }

  /// Reads the reports of tickets that may have been resolved this week.
  /// A resolved ticket's `updatedAt` is never earlier than its report's
  /// `submittedAt`, so tickets last updated before this week are skipped.
  /// Each report is fetched once, in batches by document id.
  Future<void> _fetchReports() async {
    final weekStart = startOfCurrentWeek(DateTime.now());
    final ids = <String>[];
    for (final doc in _docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString().toUpperCase();
      if (status != 'RESOLVED' && status != 'CLOSED') continue;
      final updatedAt = data['updatedAt'];
      if (updatedAt is Timestamp && updatedAt.toDate().isBefore(weekStart)) {
        continue;
      }
      if (_requestedReports.add(doc.id)) ids.add(doc.id);
    }
    if (ids.isEmpty) return;

    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      try {
        final snap = await FirebaseFirestore.instance
            .collection('reports')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        if (!mounted) return;
        setState(() {
          for (final doc in snap.docs) {
            _submittedAt[doc.id] = doc.data()['submittedAt'];
          }
        });
      } catch (_) {
        // Let a later update try these again.
        _requestedReports.removeAll(chunk);
      }
    }
  }

  TechTicketItem _toItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final items = data['checklistItems'];
    final done = data['checklistDone'];
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    return TechTicketItem(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      status: (data['status'] ?? 'ASSIGNED').toString().toUpperCase(),
      category: (data['category'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      area: (data['area'] ?? '').toString(),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
      checklistTotal: items is List ? items.length : 0,
      checklistDone: done is List ? done.where((e) => e == true).length : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    // Solid brand-blue status bar with light icons, so it reads as part of the
    // header. Only this tab changes the style; the others keep the theme's.
    Widget child;
    if (_error != null) {
      child = EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Error: $_error',
      );
    } else if (!_ticketsLoaded) {
      child = const Center(child: CircularProgressIndicator());
    } else {
      final now = DateTime.now();

      // Cancelled tickets are no longer active work for the technician.
      final tickets = [
        for (final doc in _docs)
          if (!CancelledStatus.isCancelled(
            (doc.data() as Map<String, dynamic>)['status'],
          ))
            _toItem(doc),
      ];

      final resolvedDates = <DateTime>[
        for (final t in tickets)
          if (t.status == 'RESOLVED' || t.status == 'CLOSED')
            if (_submittedAt[t.id] is Timestamp &&
                resolvedThisWeek(_submittedAt[t.id], now))
              (_submittedAt[t.id]! as Timestamp).toDate(),
      ];

      child = TechHomeContent(
        name: _fullName ?? firebaseUser.email?.split('@').first ?? 'Technician',
        today: now,
        coverageAreas: _coverageAreas,
        tickets: tickets,
        weeklyCounts: weeklyResolvedCounts(resolvedDates, now),
        onOpenTicket: (id) =>
            Navigator.pushNamed(context, '/tech/ticket', arguments: id),
        onOpenTasksWithStatus: (status) =>
            widget.onOpenTasksWithStatus?.call(status),
        onOpenProfile: () => widget.onOpenProfile?.call(),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.statusBarOnPrimary,
      child: child,
    );
  }
}

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The technician Home body. Separate from [TechHomeScreen] so it can be built
/// without Firebase.
class TechHomeContent extends StatelessWidget {
  /// Name used in the greeting (the first word is shown).
  final String name;
  final DateTime today;

  /// The technician's coverage areas, or null while they are still loading
  /// (the notice and the card are hidden then).
  final List<String>? coverageAreas;

  /// All of the technician's tickets that are not cancelled, in the order they
  /// were loaded (latest update first).
  final List<TechTicketItem> tickets;

  /// Tickets resolved on each weekday this week (index 0 = Monday).
  final List<int> weeklyCounts;

  final ValueChanged<String> onOpenTicket;
  final ValueChanged<String> onOpenTasksWithStatus;
  final VoidCallback onOpenProfile;

  const TechHomeContent({
    super.key,
    required this.name,
    required this.today,
    required this.coverageAreas,
    required this.tickets,
    required this.weeklyCounts,
    required this.onOpenTicket,
    required this.onOpenTasksWithStatus,
    required this.onOpenProfile,
  });

  int _count(String status) => tickets.where((t) => t.status == status).length;

  @override
  Widget build(BuildContext context) {
    final active = sortActiveTickets(tickets);
    final upNext = active.isEmpty ? null : active.first;
    final recent = [
      for (final t in tickets)
        if (t.id != upNext?.id) t,
    ].take(3).toList();
    final areas = coverageAreas;
    final weekTotal = weeklyCounts.fold<int>(0, (a, b) => a + b);

    final subtitle =
        'Technician Portal · ${_weekdayNames[today.weekday - 1]} '
        '${today.day} ${_monthNames[today.month - 1]}';

    return SingleChildScrollView(
      // The floating nav bar sits over the bottom of the screen. Inside a
      // Scaffold with extendBody, the body's bottom padding already includes
      // the bar and the device's safe area, so only a gap is added here.
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeHeader(
            title: 'Hi, ${name.trim().split(' ').first}',
            subtitle: subtitle,
            background: const TicketStubPattern(),
            trailing: const HeaderIconBadge(
              asset: 'assets/images/technician_icon.png',
            ),
            overlapChild: _CountersCard(
              counters: [
                _Counter('Assigned', _count('ASSIGNED'), AppColors.assignedFg),
                _Counter(
                  'In Progress',
                  _count('IN_PROGRESS'),
                  AppColors.progressFg,
                ),
                _Counter('Resolved', _count('RESOLVED'), AppColors.resolvedFg),
                _Counter('Closed', _count('CLOSED'), AppColors.closedFg),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.s4),
                if (areas != null && areas.isEmpty) ...[
                  _CoverageNotice(onSetAreas: onOpenProfile),
                  const SizedBox(height: AppSpacing.s6),
                ],
                if (upNext != null)
                  _UpNextCard(ticket: upNext, onOpen: onOpenTicket)
                else
                  const _NoActiveJobs(),
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s6),
                  _sectionHeader(
                    'Recent Tickets',
                    action: TextButton(
                      onPressed: () => onOpenTasksWithStatus('All'),
                      child: const Text('View All'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  _RecentCard(tickets: recent, onOpen: onOpenTicket),
                ],
                const SizedBox(height: AppSpacing.s6),
                _sectionHeader('This week', caption: '$weekTotal resolved'),
                const SizedBox(height: AppSpacing.s3),
                _WeekChart(counts: weeklyCounts, todayIndex: today.weekday - 1),
                if (areas != null && areas.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s6),
                  SectionCard(
                    title: 'Your Coverage Areas',
                    trailing: TextButton(
                      onPressed: onOpenProfile,
                      child: const Text('Edit'),
                    ),
                    child: Wrap(
                      spacing: AppSpacing.s2,
                      runSpacing: AppSpacing.s2,
                      children: [for (final a in areas) _AreaChip(label: a)],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {String? caption, Widget? action}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppText.heading.copyWith(color: AppColors.ink),
          ),
        ),
        if (caption != null)
          Text(
            caption,
            style: AppText.caption.copyWith(color: AppColors.inkMuted),
          ),
        if (action != null) action,
      ],
    );
  }
}

class _Counter {
  final String label;
  final int count;
  final Color color;

  const _Counter(this.label, this.count, this.color);
}

/// White card with the ticket counters in equal columns split by hairlines.
class _CountersCard extends StatelessWidget {
  final List<_Counter> counters;

  const _CountersCard({required this.counters});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < counters.length; i++) ...[
              if (i > 0)
                const VerticalDivider(width: 1, color: AppColors.border),
              Expanded(
                child: Semantics(
                  label: '${counters[i].label}, ${counters[i].count}',
                  excludeSemantics: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${counters[i].count}',
                        style: AppText.display.copyWith(
                          color: counters[i].color,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s1,
                        ),
                        child: Text(
                          counters[i].label,
                          textAlign: TextAlign.center,
                          style: AppText.caption.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CoverageNotice extends StatelessWidget {
  final VoidCallback onSetAreas;

  const _CoverageNotice({required this.onSetAreas});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.newBg,
        borderRadius: AppRadius.brLg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: AppColors.newFg,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No coverage areas set',
                  style: AppText.heading.copyWith(color: AppColors.newFg),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  'New tickets in your areas are assigned to you first. '
                  'Add your areas in your profile.',
                  style: AppText.body.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: AppSpacing.s2),
                TextButton(
                  onPressed: onSetAreas,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text('Set Coverage Areas')),
                      Icon(Icons.chevron_right, size: 20),
                    ],
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

/// The first active job, with a button that only opens its details.
class _UpNextCard extends StatelessWidget {
  final TechTicketItem ticket;
  final ValueChanged<String> onOpen;

  const _UpNextCard({required this.ticket, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final inProgress = ticket.status == 'IN_PROGRESS';
    final hasChecklist = ticket.checklistTotal > 0;
    final progress = hasChecklist
        ? (ticket.checklistDone / ticket.checklistTotal).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.brLg,
        child: InkWell(
          borderRadius: AppRadius.brLg,
          onTap: () => onOpen(ticket.id),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'UP NEXT',
                        style: AppText.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    StatusBadge(status: ticket.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: AppRadius.brMd,
                        ),
                        child: Icon(
                          categoryIcon(ticket.category),
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.heading.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                          if (ticket.address.isNotEmpty)
                            Row(
                              children: [
                                const ExcludeSemantics(
                                  child: Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: AppColors.accentStrong,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s1),
                                Expanded(
                                  child: Text(
                                    ticket.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.caption.copyWith(
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasChecklist) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Semantics(
                    label:
                        'Checklist ${ticket.checklistDone} of ${ticket.checklistTotal} done',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Checklist',
                                style: AppText.caption.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ),
                            Text(
                              '${ticket.checklistDone} of ${ticket.checklistTotal}',
                              style: AppText.caption.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        ClipRRect(
                          borderRadius: AppRadius.brPill,
                          child: Container(
                            height: 8,
                            color: AppColors.border,
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s4),
                // Only opens the job; starting it happens in Job Details.
                ElevatedButton(
                  onPressed: () => onOpen(ticket.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: inProgress
                        ? AppColors.primary
                        : AppColors.accentStrong,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          inProgress ? 'Continue Job' : 'Open Job',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (inProgress) const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoActiveJobs extends StatelessWidget {
  const _NoActiveJobs();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_turned_in_outlined,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            'No active jobs',
            textAlign: TextAlign.center,
            style: AppText.heading.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            'New jobs will appear here when a ticket is assigned to you.',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  final List<TechTicketItem> tickets;
  final ValueChanged<String> onOpen;

  const _RecentCard({required this.tickets, required this.onOpen});

  String _subtitle(TechTicketItem t) {
    final date = t.createdAt == null
        ? null
        : '${t.createdAt!.day}/${t.createdAt!.month}/${t.createdAt!.year}';
    final place = t.area.isNotEmpty ? t.area : t.address;
    return [if (place.isNotEmpty) place, if (date != null) date].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brLg,
        child: Column(
          children: [
            for (var i = 0; i < tickets.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.border),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onOpen(tickets[i].id),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 72),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s4,
                        vertical: AppSpacing.s3,
                      ),
                      child: Row(
                        children: [
                          ExcludeSemantics(
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primaryTint,
                                borderRadius: AppRadius.brMd,
                              ),
                              child: Icon(
                                categoryIcon(tickets[i].category),
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tickets[i].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.bodyStrong.copyWith(
                                    color: AppColors.ink,
                                  ),
                                ),
                                Text(
                                  _subtitle(tickets[i]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.caption.copyWith(
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s2),
                          StatusBadge(status: tickets[i].status),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Seven bars, Monday to Sunday: tickets resolved on each day this week.
class _WeekChart extends StatelessWidget {
  final List<int> counts;
  final int todayIndex;

  const _WeekChart({required this.counts, required this.todayIndex});

  static const _initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const double _maxBarHeight = 72;
  static const double _minBarHeight = 4;

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.fold<int>(0, (m, v) => v > m ? v : m);
    final label =
        'Tickets resolved this week: ${[for (var i = 0; i < 7; i++) '${_weekdayNames[i]} ${counts[i]}'].join(', ')}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: _bar(
                  initial: _initials[i],
                  count: counts[i],
                  height: maxCount == 0
                      ? _minBarHeight
                      : _minBarHeight +
                            (_maxBarHeight - _minBarHeight) *
                                (counts[i] / maxCount),
                  isToday: i == todayIndex,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bar({
    required String initial,
    required int count,
    required double height,
    required bool isToday,
  }) {
    final textColor = isToday ? AppColors.primary : AppColors.inkMuted;
    final weight = isToday ? FontWeight.w700 : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: AppText.caption.copyWith(color: textColor, fontWeight: weight),
        ),
        const SizedBox(height: AppSpacing.s1),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: isToday ? AppColors.primary : AppColors.chartMuted,
            borderRadius: AppRadius.brSm,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          initial,
          style: AppText.caption.copyWith(color: textColor, fontWeight: weight),
        ),
      ],
    );
  }
}

class _AreaChip extends StatelessWidget {
  final String label;

  const _AreaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          color: AppColors.inkMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
