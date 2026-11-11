import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/cancelled_status.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/header_icon_badge.dart';
import '../../widgets/home_header.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/ticket_stub_pattern.dart';
import 'incoming_tickets_screen.dart';
import '../../widgets/stream_error.dart';

class SupervisorHomeScreen extends StatefulWidget {
  /// Called by "View All" to switch to the Tickets tab. When null (the screen
  /// is used outside the tab bar) it opens the Incoming Tickets screen instead.
  final VoidCallback? onViewAllTickets;

  /// Called with a Tickets tab status value ('All', 'NEW', 'RESOLVED', ...)
  /// to open the Tickets tab with that filter selected. When null, the rows
  /// fall back to [onViewAllTickets] (no filter).
  final ValueChanged<String>? onOpenTicketsWithStatus;

  const SupervisorHomeScreen({
    super.key,
    this.onViewAllTickets,
    this.onOpenTicketsWithStatus,
  });

  @override
  State<SupervisorHomeScreen> createState() => _SupervisorHomeScreenState();
}

class _SupervisorHomeScreenState extends State<SupervisorHomeScreen> {
  String? _selectedCategory;

  void _openTickets(String status) {
    final openWithStatus = widget.onOpenTicketsWithStatus;
    if (openWithStatus != null) {
      openWithStatus(status);
    } else {
      _goToTickets();
    }
  }

  void _goToTickets() {
    final goToTickets = widget.onViewAllTickets;
    if (goToTickets != null) {
      goToTickets();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IncomingTicketsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    // Solid brand-blue status bar with light icons, so it reads as part of the
    // header. Only this tab changes the style; the others keep the theme's.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.statusBarOnPrimary,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
          final supervisorName =
              (userData?['fullName'] ?? firebaseUser.email ?? 'Supervisor')
                  .toString();

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tickets')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, ticketSnapshot) {
              if (ticketSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (ticketSnapshot.hasError) {
                // The streams are built inline, so a rebuild subscribes again.
                return Scaffold(
                  body: StreamError(
                    error: ticketSnapshot.error,
                    onRetry: () => setState(() {}),
                  ),
                );
              }

              // CANCELLED tickets are left out of the totals, category cards,
              // weekly chart and recent list (they stay visible in the Tickets tab).
              final docs = (ticketSnapshot.data?.docs ?? []).where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return !CancelledStatus.isCancelled(data['status']);
              });

              final tickets = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {
                  'id': doc.id,
                  'title': (data['title'] ?? '').toString(),
                  'status': (data['status'] ?? 'NEW').toString().toUpperCase(),
                  'technicianId': data['technicianId'],
                  'technicianName': (data['technicianName'] ?? '').toString(),
                  'createdAt': data['createdAt'],
                  'area': (data['area'] ?? '').toString(),
                  'category': (data['category'] ?? '').toString(),
                };
              }).toList();

              final totalTickets = tickets.length;
              final newTickets = tickets
                  .where((t) => t['status'] == 'NEW')
                  .length;
              final assignedTickets = tickets
                  .where((t) => t['status'] == 'ASSIGNED')
                  .length;
              final inProgressTickets = tickets
                  .where((t) => t['status'] == 'IN_PROGRESS')
                  .length;
              final resolvedTickets = tickets
                  .where((t) => t['status'] == 'RESOLVED')
                  .length;
              final closedTickets = tickets
                  .where((t) => t['status'] == 'CLOSED')
                  .length;
              final weeklyCounts = _getWeeklyTicketCounts(tickets);
              final maxWeeklyCount = weeklyCounts.values.isEmpty
                  ? 0
                  : weeklyCounts.values.reduce((a, b) => a > b ? a : b);
              final weeklyFactors = {
                for (final e in weeklyCounts.entries)
                  e.key: _getBarHeightFactor(e.value, maxWeeklyCount),
              };

              const categoryKeys = ['Network', 'Hardware', 'Software', 'Other'];

              final categoryTotals = {
                for (final c in categoryKeys)
                  c: tickets.where((t) => _categoryOf(t) == c).length,
              };

              final filteredTickets = _selectedCategory == null
                  ? tickets
                  : tickets
                        .where((t) => _categoryOf(t) == _selectedCategory)
                        .toList();
              final isFiltering = _selectedCategory != null;
              final shownLimit = isFiltering ? 10 : 3;

              return Scaffold(
                body: SupervisorHomeContent(
                  supervisorName: supervisorName,
                  totalTickets: totalTickets,
                  newTickets: newTickets,
                  assignedTickets: assignedTickets,
                  inProgressTickets: inProgressTickets,
                  resolvedTickets: resolvedTickets,
                  closedTickets: closedTickets,
                  weeklyCounts: weeklyCounts,
                  weeklyFactors: weeklyFactors,
                  categoryKeys: categoryKeys,
                  categoryTotals: categoryTotals,
                  selectedCategory: _selectedCategory,
                  filteredCount: filteredTickets.length,
                  recentTickets: filteredTickets.length > shownLimit
                      ? filteredTickets.sublist(0, shownLimit)
                      : filteredTickets,
                  onViewAll: () => _openTickets('All'),
                  onOpenNew: () => _openTickets('NEW'),
                  onOpenAwaitingSignOff: () => _openTickets('RESOLVED'),
                  onCategoryTap: (cat) => setState(
                    () => _selectedCategory = _selectedCategory == cat
                        ? null
                        : cat,
                  ),
                  onClearFilter: () => setState(() {
                    _selectedCategory = null;
                  }),
                  onOpenTicket: (ticketId) => Navigator.pushNamed(
                    context,
                    '/supervisor/ticket',
                    arguments: ticketId,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _categoryOf(Map<String, dynamic> t) {
    final c = (t['category'] ?? '').toString();
    return const ['Network', 'Hardware', 'Software'].contains(c) ? c : 'Other';
  }

  Map<String, int> _getWeeklyTicketCounts(List<Map<String, dynamic>> tickets) {
    final counts = {
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0,
    };

    for (final ticket in tickets) {
      final createdAt = ticket['createdAt'];
      if (createdAt is! Timestamp) continue;

      final date = createdAt.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfWeek = today.subtract(
        Duration(days: now.weekday - 1),
      ); // this Monday
      if (date.isBefore(startOfWeek)) continue;

      switch (date.weekday) {
        case DateTime.monday:
          counts['Mon'] = counts['Mon']! + 1;
          break;
        case DateTime.tuesday:
          counts['Tue'] = counts['Tue']! + 1;
          break;
        case DateTime.wednesday:
          counts['Wed'] = counts['Wed']! + 1;
          break;
        case DateTime.thursday:
          counts['Thu'] = counts['Thu']! + 1;
          break;
        case DateTime.friday:
          counts['Fri'] = counts['Fri']! + 1;
          break;
        case DateTime.saturday:
          counts['Sat'] = counts['Sat']! + 1;
          break;
        case DateTime.sunday:
          counts['Sun'] = counts['Sun']! + 1;
          break;
      }
    }

    return counts;
  }

  double _getBarHeightFactor(int count, int maxCount) {
    if (maxCount == 0) return 0.1;
    return count / maxCount < 0.1 ? 0.1 : count / maxCount;
  }
}

/// The dashboard body. Separate from [SupervisorHomeScreen] so it can be built
/// without Firebase; the screen computes every value and passes it in.
class SupervisorHomeContent extends StatelessWidget {
  final String supervisorName;
  final int totalTickets;
  final int newTickets;
  final int assignedTickets;
  final int inProgressTickets;
  final int resolvedTickets;
  final int closedTickets;

  /// Tickets created this week per day (keys Mon to Sun), and the bar height
  /// factor (0 to 1) for each.
  final Map<String, int> weeklyCounts;
  final Map<String, double> weeklyFactors;

  final List<String> categoryKeys;
  final Map<String, int> categoryTotals;
  final String? selectedCategory;

  /// Number of tickets matching the filter (for the "Showing" line), and the
  /// rows actually listed.
  final int filteredCount;
  final List<Map<String, dynamic>> recentTickets;

  final VoidCallback onViewAll;
  final VoidCallback onOpenNew;
  final VoidCallback onOpenAwaitingSignOff;
  final ValueChanged<String> onCategoryTap;
  final VoidCallback onClearFilter;
  final ValueChanged<String> onOpenTicket;

  const SupervisorHomeContent({
    super.key,
    required this.supervisorName,
    required this.totalTickets,
    required this.newTickets,
    required this.assignedTickets,
    required this.inProgressTickets,
    required this.resolvedTickets,
    required this.closedTickets,
    required this.weeklyCounts,
    required this.weeklyFactors,
    required this.categoryKeys,
    required this.categoryTotals,
    required this.selectedCategory,
    required this.filteredCount,
    required this.recentTickets,
    required this.onViewAll,
    required this.onOpenNew,
    required this.onOpenAwaitingSignOff,
    required this.onCategoryTap,
    required this.onClearFilter,
    required this.onOpenTicket,
  });

  static const _categoryIcons = {
    'Network': Icons.wifi_rounded,
    'Hardware': Icons.memory,
    'Software': Icons.desktop_windows_outlined,
    'Other': Icons.more_horiz_rounded,
  };

  @override
  Widget build(BuildContext context) {
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
            title: 'Welcome back,',
            subtitle: '$supervisorName | Supervisor',
            bottomOverlap: AppSpacing.s8 * 2,
            background: const TicketStubPattern(),
            trailing: const HeaderIconBadge(
              asset: 'assets/images/supervisor_icon.png',
            ),
            overlapChild: _AttentionCard(
              newCount: newTickets,
              resolvedCount: resolvedTickets,
              onOpenNew: onOpenNew,
              onOpenAwaitingSignOff: onOpenAwaitingSignOff,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.s6),
                _buildOverview(),
                const SizedBox(height: AppSpacing.s6),
                _buildThisWeek(),
                const SizedBox(height: AppSpacing.s6),
                _buildCategories(),
                const SizedBox(height: AppSpacing.s6),
                _buildRecent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {String? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppText.heading.copyWith(color: AppColors.ink),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.s2),
          Text(
            trailing,
            style: AppText.caption.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ],
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: AppColors.surfaceCard,
    borderRadius: AppRadius.brLg,
    boxShadow: AppShadows.card,
  );

  Widget _buildOverview() {
    final rows = [
      _OverviewData('New', newTickets, AppColors.chartNew),
      _OverviewData('Assigned', assignedTickets, AppColors.chartAssigned),
      _OverviewData('In Progress', inProgressTickets, AppColors.chartProgress),
      _OverviewData('Resolved', resolvedTickets, AppColors.chartResolved),
      _OverviewData('Closed', closedTickets, AppColors.chartClosed),
    ];
    final largest = rows.fold<int>(0, (m, r) => r.count > m ? r.count : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('Overview', trailing: '$totalTickets tickets in total'),
        const SizedBox(height: AppSpacing.s3),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s1,
          ),
          decoration: _cardDecoration,
          child: Column(
            children: [
              for (final row in rows) _OverviewRow(data: row, largest: largest),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThisWeek() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekTotal = weeklyCounts.values.fold<int>(0, (a, b) => a + b);
    final maxCount = weeklyCounts.values.fold<int>(0, (m, v) => v > m ? v : m);
    // First day with the highest count; nothing is highlighted on an empty
    // week.
    final busiest = maxCount == 0
        ? null
        : days.firstWhere((d) => (weeklyCounts[d] ?? 0) == maxCount);

    final label =
        'Tickets created this week: ${[for (final d in days) '$d ${weeklyCounts[d] ?? 0}'].join(', ')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('This week', trailing: '$weekTotal tickets created'),
        const SizedBox(height: AppSpacing.s3),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: _cardDecoration,
          child: Semantics(
            label: label,
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: _WeekBar(
                      day: days[i],
                      count: weeklyCounts[days[i]] ?? 0,
                      factor: weeklyFactors[days[i]] ?? 0,
                      highlighted: days[i] == busiest,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategories() {
    Widget tile(String cat) => Expanded(
      child: _CategoryTile(
        icon: _categoryIcons[cat] ?? Icons.more_horiz_rounded,
        name: cat,
        count: categoryTotals[cat] ?? 0,
        selected: selectedCategory == cat,
        onTap: () => onCategoryTap(cat),
      ),
    );

    final rows = <Widget>[];
    for (var i = 0; i < categoryKeys.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: AppSpacing.s3));
      rows.add(
        Row(
          children: [
            tile(categoryKeys[i]),
            const SizedBox(width: AppSpacing.s3),
            if (i + 1 < categoryKeys.length)
              tile(categoryKeys[i + 1])
            else
              const Spacer(),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tickets by Category',
          style: AppText.heading.copyWith(color: AppColors.ink),
        ),
        Text(
          'Tap a card to filter the ticket list below.',
          style: AppText.caption.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.s3),
        ...rows,
      ],
    );
  }

  Widget _buildRecent() {
    final isFiltering = selectedCategory != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent Tickets',
                style: AppText.heading.copyWith(color: AppColors.ink),
              ),
            ),
            TextButton(onPressed: onViewAll, child: const Text('View All')),
          ],
        ),
        if (isFiltering)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Showing: $selectedCategory ($filteredCount)',
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                ),
              ),
              TextButton(onPressed: onClearFilter, child: const Text('Clear')),
            ],
          ),
        if (recentTickets.isEmpty)
          const EmptyState(
            icon: Icons.confirmation_number_outlined,
            title: 'No tickets found.',
          )
        else
          Container(
            decoration: _cardDecoration,
            child: ClipRRect(
              borderRadius: AppRadius.brLg,
              child: Column(
                children: [
                  for (var i = 0; i < recentTickets.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.border),
                    _RecentRow(
                      ticket: recentTickets[i],
                      onTap: () =>
                          onOpenTicket(recentTickets[i]['id'].toString()),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The card over the header: tickets waiting to be assigned and tickets
/// waiting for sign-off. Both rows open the ticket list.
class _AttentionCard extends StatelessWidget {
  final int newCount;
  final int resolvedCount;
  final VoidCallback onOpenNew;
  final VoidCallback onOpenAwaitingSignOff;

  const _AttentionCard({
    required this.newCount,
    required this.resolvedCount,
    required this.onOpenNew,
    required this.onOpenAwaitingSignOff,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brLg,
        child: Column(
          children: [
            _AttentionRow(
              count: newCount,
              title: 'New tickets',
              subtitle: 'Waiting to be assigned',
              fg: AppColors.newFg,
              bg: AppColors.newBg,
              onTap: onOpenNew,
            ),
            const Divider(
              height: 1,
              indent: AppSpacing.s4,
              endIndent: AppSpacing.s4,
              color: AppColors.border,
            ),
            _AttentionRow(
              count: resolvedCount,
              title: 'Awaiting sign-off',
              subtitle: 'Resolved, review and close',
              fg: AppColors.resolvedFg,
              bg: AppColors.resolvedBg,
              onTap: onOpenAwaitingSignOff,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final int count;
  final String title;
  final String subtitle;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;

  const _AttentionRow({
    required this.count,
    required this.title,
    required this.subtitle,
    required this.fg,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $count, open ticket list',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4,
                vertical: AppSpacing.s3,
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: AppRadius.brMd,
                    ),
                    child: FittedBox(
                      child: Text(
                        '$count',
                        style: AppText.display.copyWith(color: fg),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppText.heading.copyWith(color: AppColors.ink),
                        ),
                        Text(
                          subtitle,
                          style: AppText.body.copyWith(
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

class _OverviewData {
  final String label;
  final int count;
  final Color color;

  const _OverviewData(this.label, this.count, this.color);
}

/// Label, a bar sized against the largest count, and the count.
class _OverviewRow extends StatelessWidget {
  final _OverviewData data;
  final int largest;

  const _OverviewRow({required this.data, required this.largest});

  @override
  Widget build(BuildContext context) {
    final fraction = largest == 0 ? 0.0 : data.count / largest;

    return Semantics(
      label: '${data.label}, ${data.count}',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(color: AppColors.inkMuted),
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadius.brPill,
                child: Container(
                  height: 8,
                  color: AppColors.border,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(color: data.color),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            SizedBox(
              width: 28,
              child: Text(
                '${data.count}',
                textAlign: TextAlign.right,
                style: AppText.bodyStrong.copyWith(color: AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One day of the weekly chart: count, bar, day name.
class _WeekBar extends StatelessWidget {
  final String day;
  final int count;
  final double factor;
  final bool highlighted;

  const _WeekBar({
    required this.day,
    required this.count,
    required this.factor,
    required this.highlighted,
  });

  static const double _maxBarHeight = 96;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: AppText.caption.copyWith(
            color: highlighted ? AppColors.primary : AppColors.inkMuted,
            fontWeight: highlighted ? FontWeight.w700 : null,
          ),
        ),
        const SizedBox(height: AppSpacing.s1),
        Container(
          height: _maxBarHeight * factor,
          decoration: BoxDecoration(
            color: highlighted ? AppColors.primary : AppColors.chartMuted,
            borderRadius: AppRadius.brSm,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          day,
          maxLines: 1,
          style: AppText.caption.copyWith(
            color: highlighted ? AppColors.primary : AppColors.inkMuted,
            fontWeight: highlighted ? FontWeight.w700 : null,
          ),
        ),
      ],
    );
  }
}

/// Selectable category count; tapping it filters the recent list.
class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.icon,
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$name, $count',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : AppColors.surfaceCard,
          borderRadius: AppRadius.brLg,
          // Same width in both states so the tile does not change size.
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.brLg,
          child: InkWell(
            borderRadius: AppRadius.brLg,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: AppSpacing.s2,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        // White on the selected tile, so the circle stays
                        // visible against the tint.
                        color: selected
                            ? AppColors.surfaceCard
                            : AppColors.primaryTint,
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
                            '$count',
                            style: AppText.title.copyWith(color: AppColors.ink),
                          ),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// One line of the recent tickets card.
class _RecentRow extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;

  const _RecentRow({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final assignedName = (ticket['technicianName'] ?? '').toString();
    final technicianId = ticket['technicianId'];
    final status = (ticket['status'] ?? 'NEW').toString().toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (ticket['title'] ?? '').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heading.copyWith(color: AppColors.ink),
                    ),
                    Text(
                      assignedName.isNotEmpty
                          ? "Assigned: $assignedName"
                          : technicianId != null
                          ? "Assigned (ID: ${technicianId.toString().substring(0, 8)}...)"
                          : "Unassigned",
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
              StatusBadge(status: status),
            ],
          ),
        ),
      ),
    );
  }
}
