// lib/features/supervisor/technician_performance_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/cancelled_status.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import '../../widgets/status_style.dart';

/// Monday 00:00 of the week [now] falls in (the same week the supervisor Home
/// "This week" chart uses).
DateTime startOfCurrentWeek(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: now.weekday - 1));
}

/// Whether a ticket's report was submitted this week (Monday 00:00 up to
/// [now]). The report's `submittedAt` is the moment the technician marked the
/// ticket resolved.
bool resolvedThisWeek(Object? submittedAt, DateTime now) {
  if (submittedAt is! Timestamp) return false;
  final date = submittedAt.toDate();
  return !date.isBefore(startOfCurrentWeek(now)) && !date.isAfter(now);
}

/// The technician with the most tickets resolved this week (key
/// `resolvedThisWeek`), or null when nobody resolved one. Ties go to the
/// higher all-time total (resolved + closed), then to the name that comes
/// first alphabetically.
Map<String, dynamic>? pickTopPerformer(List<Map<String, dynamic>> technicians) {
  int weekly(Map<String, dynamic> t) => (t['resolvedThisWeek'] as int?) ?? 0;
  int allTime(Map<String, dynamic> t) =>
      ((t['resolved'] as int?) ?? 0) + ((t['closed'] as int?) ?? 0);

  Map<String, dynamic>? best;
  for (final tech in technicians) {
    if (weekly(tech) == 0) continue;
    if (best == null) {
      best = tech;
      continue;
    }
    final byWeek = weekly(tech).compareTo(weekly(best));
    final byTotal = allTime(tech).compareTo(allTime(best));
    final byName = best['name'].toString().toLowerCase().compareTo(
      tech['name'].toString().toLowerCase(),
    );
    if (byWeek > 0 ||
        (byWeek == 0 && (byTotal > 0 || (byTotal == 0 && byName > 0)))) {
      best = tech;
    }
  }
  return best;
}

class TechnicianPerformanceScreen extends StatefulWidget {
  /// The three data streams. Left null, they are the Firestore queries; they
  /// can be injected so the screen can be tested without Firebase.
  final Stream<QuerySnapshot>? usersStream;
  final Stream<QuerySnapshot>? ticketsStream;
  final Stream<QuerySnapshot>? reportsStream;

  const TechnicianPerformanceScreen({
    super.key,
    this.usersStream,
    this.ticketsStream,
    this.reportsStream,
  });

  @override
  State<TechnicianPerformanceScreen> createState() =>
      _TechnicianPerformanceScreenState();
}

class _TechnicianPerformanceScreenState
    extends State<TechnicianPerformanceScreen> {
  final TextEditingController _searchController = TextEditingController();

  // The search text lives here, not in setState: typing only rebuilds the
  // search field and the ranking list, never the data pipeline above them.
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>("");

  // The streams are created once. Creating them inside build() would make
  // every rebuild subscribe again and flash the loading spinner.
  late Stream<QuerySnapshot> _usersStream;
  late Stream<QuerySnapshot> _ticketsStream;
  late Stream<QuerySnapshot> _reportsStream;

  @override
  void initState() {
    super.initState();
    _createStreams();
  }

  // Also used by Retry, which needs fresh subscriptions after an error.
  void _createStreams() {
    _usersStream =
        widget.usersStream ??
        FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'technician')
            .snapshots();
    _ticketsStream =
        widget.ticketsStream ??
        FirebaseFirestore.instance.collection('tickets').snapshots();
    _reportsStream =
        widget.reportsStream ??
        FirebaseFirestore.instance.collection('reports').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Performance Overview"),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return _buildErrorState(
              "Error loading technicians: ${userSnapshot.error}",
            );
          }
          // Only the first load shows the spinner; once data has arrived, a
          // rebuild keeps showing it.
          if (!userSnapshot.hasData &&
              userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
            return const EmptyState(
              icon: Icons.person_off_rounded,
              title: "No technicians found",
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _ticketsStream,
            builder: (context, ticketSnapshot) {
              if (ticketSnapshot.hasError) {
                return _buildErrorState(
                  "Error loading tickets: ${ticketSnapshot.error}",
                );
              }
              if (!ticketSnapshot.hasData &&
                  ticketSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot>(
                stream: _reportsStream,
                builder: (context, reportSnapshot) {
                  if (!reportSnapshot.hasData &&
                      reportSnapshot.connectionState ==
                          ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final reportDocs = reportSnapshot.data?.docs ?? [];
                  final submittedTicketIds = reportDocs
                      .map((doc) => doc.id)
                      .toSet();
                  // When each report was submitted, by ticket id.
                  final reportSubmittedAt = {
                    for (final doc in reportDocs)
                      doc.id:
                          (doc.data() as Map<String, dynamic>)['submittedAt'],
                  };

                  final techDocs = userSnapshot.data!.docs;
                  final ticketDocs = ticketSnapshot.data?.docs ?? [];

                  final now = DateTime.now();
                  List<Map<String, dynamic>> technicians = [];
                  int resolvedThisWeekTotal = 0;

                  for (var tech in techDocs) {
                    final data = tech.data() as Map<String, dynamic>;
                    final techId = tech.id;
                    final name = data['fullName'] ?? "Technician";
                    final specialization =
                        data['specialization'] ?? "Generalist";
                    final coverageAreas = List<String>.from(
                      data['coverageAreas'] ?? [],
                    );

                    int assigned = 0;
                    int inProgress = 0;
                    int resolved = 0;
                    int closed = 0;
                    int total = 0;
                    int totalReportsSubmitted = 0;
                    int totalResolvableTickets = 0;
                    int techResolvedThisWeek = 0;

                    for (var ticket in ticketDocs) {
                      final t = ticket.data() as Map<String, dynamic>;

                      if (t['technicianId'] == techId) {
                        final status = (t['status'] ?? '')
                            .toString()
                            .toUpperCase();

                        // Cancelled tickets don't count towards performance.
                        if (CancelledStatus.isCancelled(status)) continue;

                        total++;

                        if (status == 'ASSIGNED') assigned++;
                        if (status == 'IN_PROGRESS') inProgress++;
                        if (status == 'RESOLVED') resolved++;
                        if (status == 'CLOSED') closed++;

                        if (status == 'RESOLVED' || status == 'CLOSED') {
                          totalResolvableTickets++;
                          if (submittedTicketIds.contains(ticket.id)) {
                            totalReportsSubmitted++;
                          }
                          if (resolvedThisWeek(
                            reportSubmittedAt[ticket.id],
                            now,
                          )) {
                            resolvedThisWeekTotal++;
                            techResolvedThisWeek++;
                          }
                        }
                      }
                    }

                    final completionRate = total > 0
                        ? (resolved + closed) / total * 100
                        : 0.0;

                    technicians.add({
                      'id': techId,
                      'name': name,
                      'specialization': specialization,
                      'coverageAreas': coverageAreas,
                      'assigned': assigned,
                      'inProgress': inProgress,
                      'resolved': resolved,
                      'closed': closed,
                      'total': total,
                      'completionRate': completionRate,
                      'reportsSubmitted': totalReportsSubmitted,
                      'resolvableTickets': totalResolvableTickets,
                      'resolvedThisWeek': techResolvedThisWeek,
                    });
                  }

                  // Sort by completion rate descending
                  technicians.sort(
                    (a, b) =>
                        b['completionRate'].compareTo(a['completionRate']),
                  );

                  return TechnicianPerformanceContent(
                    technicians: technicians,
                    resolvedThisWeek: resolvedThisWeekTotal,
                    topPerformer: pickTopPerformer(technicians),
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: AppColors.cancelledFg,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              "Something went wrong",
              style: AppText.heading.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.s4),
            ElevatedButton(
              onPressed: () => setState(_createStreams),
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}

/// The analytics page body. Separate from [TechnicianPerformanceScreen] so it
/// can be built without Firebase; the screen computes every value.
class TechnicianPerformanceContent extends StatelessWidget {
  /// All technicians, already sorted by completion rate (best first).
  final List<Map<String, dynamic>> technicians;

  final int resolvedThisWeek;

  /// The technician who resolved the most tickets this week, or null when
  /// nobody resolved one.
  final Map<String, dynamic>? topPerformer;

  /// The search text. Only the search field and the ranking list listen to
  /// it, so typing does not rebuild the rest of the page.
  final TextEditingController searchController;
  final ValueNotifier<String> searchQuery;

  const TechnicianPerformanceContent({
    super.key,
    required this.technicians,
    required this.resolvedThisWeek,
    required this.topPerformer,
    required this.searchController,
    required this.searchQuery,
  });

  static int _resolvedOf(Map<String, dynamic> tech) =>
      ((tech['resolved'] as int?) ?? 0) + ((tech['closed'] as int?) ?? 0);

  @override
  Widget build(BuildContext context) {
    return ListView(
      // The floating nav bar sits over the bottom of the screen. Inside a
      // Scaffold with extendBody, the body's bottom padding already includes
      // the bar and the device's safe area, so only a gap is added here.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s4,
        AppSpacing.s4,
        MediaQuery.paddingOf(context).bottom + AppSpacing.s4,
      ),
      children: [
        // Both tiles take the height of the taller one.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SummaryTile(
                  icon: Icons.groups_outlined,
                  iconColor: AppColors.primary,
                  iconBackground: AppColors.primaryTint,
                  value: technicians.length,
                  label: 'Total Techs',
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: _SummaryTile(
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.resolvedFg,
                  iconBackground: AppColors.resolvedBg,
                  value: resolvedThisWeek,
                  label: 'Resolved this week',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        if (topPerformer != null)
          _TopPerformerCard(
            name: topPerformer!['name'].toString(),
            resolvedThisWeek: (topPerformer!['resolvedThisWeek'] as int?) ?? 0,
          )
        else
          const _EmptyActivityCard(),
        const SizedBox(height: AppSpacing.s6),
        _ResolvedChart(
          technicians: technicians,
          highlightId: topPerformer?['id'],
        ),
        const SizedBox(height: AppSpacing.s6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                "Technician Rankings",
                style: AppText.heading.copyWith(color: AppColors.ink),
              ),
            ),
            Text(
              '${technicians.length} technicians',
              style: AppText.caption.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        ValueListenableBuilder<String>(
          valueListenable: searchQuery,
          builder: (context, query, _) => AppTextField(
            label: '',
            controller: searchController,
            hint: "Search technician by name...",
            prefixIcon: Icons.search_rounded,
            onChanged: (val) => searchQuery.value = val,
            suffix: query.isNotEmpty
                ? IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.cancel_rounded),
                    onPressed: () {
                      searchController.clear();
                      searchQuery.value = "";
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        ValueListenableBuilder<String>(
          valueListenable: searchQuery,
          builder: (context, query, _) {
            final filtered = technicians.where((t) {
              final name = t['name'].toString().toLowerCase();
              return name.contains(query.toLowerCase());
            }).toList();

            if (filtered.isEmpty) {
              return const EmptyState(
                icon: Icons.search_off_rounded,
                title: "No technicians matching your search",
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < filtered.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.s3),
                  _RankingCard(
                    key: ValueKey(filtered[i]['id']),
                    tech: filtered[i],
                    // Rank in the full list, not in the filtered one.
                    rank: technicians.indexOf(filtered[i]) + 1,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Two-letter initials from a name (first letters of the first two words).
String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final letters = words.take(2).map((w) => w.substring(0, 1).toUpperCase());
  final result = letters.join();
  return result.isEmpty ? '?' : result;
}

BoxDecoration get _cardDecoration => BoxDecoration(
  color: AppColors.surfaceCard,
  borderRadius: AppRadius.brLg,
  boxShadow: AppShadows.card,
);

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final int value;
  final String label;

  const _SummaryTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: _cardDecoration,
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: AppRadius.brMd,
              ),
              child: Icon(icon, color: iconColor),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: AppText.display.copyWith(color: AppColors.ink),
                ),
                Text(
                  label,
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

class _TopPerformerCard extends StatelessWidget {
  final String name;
  final int resolvedThisWeek;

  const _TopPerformerCard({required this.name, required this.resolvedThisWeek});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.brLg,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials(name),
              style: AppText.heading.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TOP PERFORMER",
                  style: AppText.caption.copyWith(
                    color: AppColors.primaryTint,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title.copyWith(color: AppColors.onPrimary),
                ),
                Text(
                  '$resolvedThisWeek resolved this week',
                  style: AppText.body.copyWith(color: AppColors.primaryTint),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          const ExcludeSemantics(
            child: Icon(
              Icons.star_rounded,
              size: 32,
              color: AppColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyActivityCard extends StatelessWidget {
  const _EmptyActivityCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: AppRadius.brMd,
              ),
              child: const Icon(
                Icons.insights_rounded,
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
                  "No Activity This Week",
                  style: AppText.heading.copyWith(color: AppColors.ink),
                ),
                Text(
                  "Performance data will update as technicians complete tasks.",
                  style: AppText.body.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bar chart of resolved tickets per technician (fl_chart).
class _ResolvedChart extends StatelessWidget {
  final List<Map<String, dynamic>> technicians;

  /// Id of the technician whose bar is highlighted (the Top performer), or
  /// null for no highlight.
  final Object? highlightId;

  const _ResolvedChart({required this.technicians, required this.highlightId});

  @override
  Widget build(BuildContext context) {
    if (technicians.isEmpty) return const SizedBox.shrink();

    final values = [
      for (final t in technicians) TechnicianPerformanceContent._resolvedOf(t),
    ];
    final maxValue = values.fold<int>(0, (m, v) => v > m ? v : m);
    // The Top performer's bar is the highlighted one; -1 when there is none
    // or that technician is not among the bars.
    final topIndex = highlightId == null
        ? -1
        : technicians.indexWhere((t) => t['id'] == highlightId);
    final firstNames = [
      for (final t in technicians) t['name'].toString().split(' ').first,
    ];

    final summary =
        'Tickets resolved per technician: ${[for (var i = 0; i < technicians.length; i++) '${firstNames[i]} ${values[i]}'].join(', ')}';

    final bars = [
      for (var i = 0; i < technicians.length; i++)
        BarChartGroupData(
          x: i,
          showingTooltipIndicators: const [0],
          barRods: [
            BarChartRodData(
              toY: values[i].toDouble(),
              color: i == topIndex ? AppColors.primary : AppColors.chartMuted,
              width: 18,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.sm),
              ),
            ),
          ],
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Tickets per technician',
                  style: AppText.heading.copyWith(color: AppColors.ink),
                ),
              ),
              Text(
                'Resolved',
                style: AppText.caption.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Semantics(
            label: summary,
            excludeSemantics: true,
            child: SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxValue == 0 ? 1 : maxValue * 1.25,
                  barGroups: bars,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= firstNames.length) {
                            return const SizedBox.shrink();
                          }
                          final isTop = index == topIndex;
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.s2),
                            child: Text(
                              firstNames[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption.copyWith(
                                color: isTop
                                    ? AppColors.primary
                                    : AppColors.inkMuted,
                                fontWeight: isTop ? FontWeight.w700 : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Value labels above the bars: tooltips that are always
                  // shown, with no background.
                  barTouchData: BarTouchData(
                    enabled: false,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.transparent,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: AppSpacing.s1,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final isTop = group.x == topIndex;
                        return BarTooltipItem(
                          '${rod.toY.toInt()}',
                          AppText.caption.copyWith(
                            color: isTop
                                ? AppColors.primary
                                : AppColors.inkMuted,
                            fontWeight: isTop ? FontWeight.w700 : null,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  final Map<String, dynamic> tech;
  final int rank;

  const _RankingCard({super.key, required this.tech, required this.rank});

  @override
  Widget build(BuildContext context) {
    final completion = (tech['completionRate'] as num).toDouble();
    final resolved = TechnicianPerformanceContent._resolvedOf(tech);
    final reportsSubmitted = (tech['reportsSubmitted'] as int?) ?? 0;
    final coverageAreas = List<String>.from(tech['coverageAreas'] ?? []);
    final isFirst = rank == 1;

    final counts = [
      ('ASSIGNED', (tech['assigned'] as int?) ?? 0),
      ('IN_PROGRESS', (tech['inProgress'] as int?) ?? 0),
      ('RESOLVED', (tech['resolved'] as int?) ?? 0),
      ('CLOSED', (tech['closed'] as int?) ?? 0),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isFirst
                      ? AppColors.accentStrong
                      : AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: AppText.bodyStrong.copyWith(
                    color: isFirst ? AppColors.onPrimary : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tech['name'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heading.copyWith(color: AppColors.ink),
                    ),
                    Text(
                      tech['specialization'].toString(),
                      style: AppText.caption.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          if (coverageAreas.isEmpty)
            Text(
              'No coverage areas set',
              style: AppText.caption.copyWith(color: AppColors.cancelledFg),
            )
          else
            Wrap(
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s2,
              children: [for (final a in coverageAreas) _AreaChip(label: a)],
            ),
          const SizedBox(height: AppSpacing.s3),
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              for (final c in counts) _CountChip(status: c.$1, count: c.$2),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Completion rate',
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                ),
              ),
              Text(
                '${completion.toStringAsFixed(0)}%',
                style: AppText.bodyStrong.copyWith(color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Semantics(
            label: 'Completion rate ${completion.toStringAsFixed(0)} percent',
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: AppRadius.brPill,
              child: Container(
                height: 8,
                color: AppColors.border,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (completion / 100).clamp(0.0, 1.0),
                  child: Container(color: AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: _FooterStat(count: resolved, label: 'tickets resolved'),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _FooterStat(
                    count: reportsSubmitted,
                    label: 'reports submitted',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
        style: AppText.caption.copyWith(color: AppColors.inkMuted),
      ),
    );
  }
}

/// A "count status" pill (for example "3 Resolved") in the status colours.
class _CountChip extends StatelessWidget {
  final String status;
  final int count;

  const _CountChip({required this.status, required this.count});

  @override
  Widget build(BuildContext context) {
    final style = statusStyle(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        '$count ${style.label}',
        style: AppText.caption.copyWith(
          color: style.fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  final int count;
  final String label;

  const _FooterStat({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$count',
            style: AppText.bodyStrong.copyWith(color: AppColors.ink),
          ),
          TextSpan(
            text: ' $label',
            style: AppText.caption.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
