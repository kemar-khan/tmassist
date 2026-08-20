// lib/features/supervisor/technician_performance_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';

class TechnicianPerformanceScreen extends StatefulWidget {
  const TechnicianPerformanceScreen({super.key});

  @override
  State<TechnicianPerformanceScreen> createState() =>
      _TechnicianPerformanceScreenState();
}

class _TechnicianPerformanceScreenState
    extends State<TechnicianPerformanceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  Timer? _searchDebounce;

  final Color _primaryBlue = const Color(0xFF005CAB);
  final Color _accentOrange = const Color(0xFFFF6600);
  final Color _backgroundColor = const Color(0xFFF5F5F5);

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  DateTime _startOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Performance Overview",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "This Week",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'technician')
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return _buildErrorState(
              "Error loading technicians: ${userSnapshot.error}",
            );
          }
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
            return _buildEmptyState(
              "No technicians found",
              Icons.person_off_rounded,
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tickets')
                .snapshots(),
            builder: (context, ticketSnapshot) {
              if (ticketSnapshot.hasError) {
                return _buildErrorState(
                  "Error loading tickets: ${ticketSnapshot.error}",
                );
              }
              if (ticketSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reports')
                    .snapshots(),
                builder: (context, reportSnapshot) {
                  if (reportSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final reportDocs = reportSnapshot.data?.docs ?? [];
                  final submittedTicketIds = reportDocs
                      .map((doc) => doc.id)
                      .toSet();

                  final techDocs = userSnapshot.data!.docs;
                  final ticketDocs = ticketSnapshot.data?.docs ?? [];

                  final startOfWeek = _startOfWeek(DateTime.now());
                  Map<String, int> weeklyActivity = {};
                  List<Map<String, dynamic>> technicians = [];

                  for (var tech in techDocs) {
                    final data = tech.data() as Map<String, dynamic>;
                    final techId = tech.id;
                    final name = data['fullName'] ?? "Technician";
                    final specialization =
                        data['specialization'] ?? "Generalist";

                    int assigned = 0;
                    int inProgress = 0;
                    int resolved = 0;
                    int closed = 0;
                    int total = 0;
                    int totalReportsSubmitted = 0;
                    int totalResolvableTickets = 0;
                    double totalResolutionHours = 0;
                    int resolutionCount = 0;

                    for (var ticket in ticketDocs) {
                      final t = ticket.data() as Map<String, dynamic>;

                      if (t['technicianId'] == techId) {
                        total++;
                        final status = (t['status'] ?? '')
                            .toString()
                            .toUpperCase();

                        if (status == 'ASSIGNED') assigned++;
                        if (status == 'IN_PROGRESS') inProgress++;
                        if (status == 'RESOLVED') resolved++;
                        if (status == 'CLOSED') closed++;

                        // Calculate resolution time
                        if (status == 'RESOLVED' || status == 'CLOSED') {
                          final createdAt = t['createdAt'];
                          final updatedAt = t['updatedAt'];

                          if (createdAt is Timestamp &&
                              updatedAt is Timestamp) {
                            final created = createdAt.toDate();
                            final updated = updatedAt.toDate();
                            final diff = updated.difference(created).inMinutes;
                            if (diff > 0) {
                              totalResolutionHours += diff / 60;
                              resolutionCount++;
                            }
                          }

                          // Check report submission
                          totalResolvableTickets++;
                          if (submittedTicketIds.contains(ticket.id)) {
                            totalReportsSubmitted++;
                          }
                        }

                        final updatedAt = t['updatedAt'];
                        if (updatedAt is Timestamp) {
                          final date = updatedAt.toDate();
                          if (date.isAfter(startOfWeek)) {
                            weeklyActivity[techId] =
                                (weeklyActivity[techId] ?? 0) + 1;
                          }
                        }
                      }
                    }

                    final completionRate = total > 0
                        ? (resolved + closed) / total * 100
                        : 0.0;

                    final avgResolutionHours = resolutionCount > 0
                        ? totalResolutionHours / resolutionCount
                        : 0.0;

                    technicians.add({
                      'id': techId,
                      'name': name,
                      'specialization': specialization,
                      'assigned': assigned,
                      'inProgress': inProgress,
                      'resolved': resolved,
                      'closed': closed,
                      'total': total,
                      'completionRate': completionRate,
                      'avgResolutionHours': avgResolutionHours,
                      'reportsSubmitted': totalReportsSubmitted,
                      'resolvableTickets': totalResolvableTickets,
                    });
                  }

                  // Sort by completion rate descending
                  technicians.sort(
                    (a, b) =>
                        b['completionRate'].compareTo(a['completionRate']),
                  );

                  String? mostActiveId;
                  int maxActivity = 0;

                  weeklyActivity.forEach((key, value) {
                    if (value > maxActivity) {
                      maxActivity = value;
                      mostActiveId = key;
                    }
                  });

                  final mostActiveTech = mostActiveId != null
                      ? technicians.firstWhere(
                          (t) => t['id'] == mostActiveId,
                          orElse: () => <String, dynamic>{},
                        )
                      : <String, dynamic>{};

                  final filtered = technicians.where((t) {
                    final name = t['name'].toString().toLowerCase();
                    return name.contains(_searchQuery.toLowerCase());
                  }).toList();

                  return Column(
                    children: [
                      // Dashboard Stats Header
                      _buildKpiHeader(technicians, weeklyActivity),

                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          children: [
                            // Top Performer Highlight
                            if (mostActiveTech.isNotEmpty)
                              _buildTopPerformerCard(
                                mostActiveTech,
                                maxActivity,
                              )
                            else
                              _buildEmptyActivityCard(),

                            const SizedBox(height: 20),

                            // Bar Chart
                            _buildBarChart(technicians),

                            // Search Bar
                            _buildSearchBar(),

                            const SizedBox(height: 24),

                            // Rankings Title
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 16,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: _accentOrange,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Technician Rankings",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (filtered.isEmpty)
                              _buildEmptyState(
                                "No technicians matching your search",
                                Icons.search_off_rounded,
                              )
                            else
                              ...filtered.asMap().entries.map((entry) {
                                int index = entry.key;
                                var tech = entry.value;
                                return _buildTechnicianCard(tech, index);
                              }),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildKpiHeader(
    List<Map<String, dynamic>> technicians,
    Map<String, int> weeklyActivity,
  ) {
    int totalResolved = technicians.fold<int>(
      0,
      (sum, t) => sum + (t['resolved'] as int),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      decoration: BoxDecoration(
        color: _primaryBlue,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _kpiItem("Total Techs", technicians.length.toString()),
          _verticalDivider(),
          _kpiItem("Active Now", weeklyActivity.length.toString()),
          _verticalDivider(),
          _kpiItem("Resolved", totalResolved.toString()),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _kpiItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformerCard(Map<String, dynamic> tech, int activityCount) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 🔶 Icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _accentOrange.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: _accentOrange,
              size: 28,
            ),
          ),

          const SizedBox(width: 16),

          // 🔤 Text Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _accentOrange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "TOP PERFORMER",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Name
                Text(
                  tech['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),

                const SizedBox(height: 2),

                // Activity text
                Text(
                  "$activityCount activities this week",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insights_rounded,
              color: Colors.grey[400],
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "No Activity This Week",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Performance data will update as technicians complete tasks.",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> technicians) {
    if (technicians.isEmpty) return const SizedBox.shrink();

    final maxTotal = technicians
        .map((t) => (t['total'] as int))
        .fold(0, (a, b) => a > b ? a : b)
        .toDouble();

    final bars = technicians.asMap().entries.map((entry) {
      final tech = entry.value;
      final total = (tech['total'] as int).toDouble();
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: total,
            color: _primaryBlue,
            width: 18,
            borderRadius: BorderRadius.circular(6),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxTotal == 0 ? 1 : maxTotal,
              color: Colors.grey[100],
            ),
          ),
        ],
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: _primaryBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Ticket Volume by Technician",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxTotal == 0 ? 1 : maxTotal * 1.2,
                barGroups: bars,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxTotal == 0
                      ? 1
                      : (maxTotal / 4).ceilToDouble(),
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: maxTotal == 0
                          ? 1
                          : (maxTotal / 4).ceilToDouble(),
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= technicians.length) {
                          return const SizedBox.shrink();
                        }
                        final name = technicians[index]['name'] as String;
                        final short = name.split(' ').first;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            short,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final name = technicians[group.x]['name'] as String;
                      return BarTooltipItem(
                        '$name\n${rod.toY.toInt()} tickets',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() => _searchQuery = val);
            }
          });
        },
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: "Search technician by name...",
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: _primaryBlue, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.cancel_rounded,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildTechnicianCard(Map<String, dynamic> tech, int index) {
    double completion = tech['completionRate'];
    Color progressColor = completion > 80
        ? Colors.green
        : (completion > 50 ? _accentOrange : Colors.redAccent);

    final avgHours = (tech['avgResolutionHours'] as double?) ?? 0.0;
    final reportsSubmitted = (tech['reportsSubmitted'] as int?) ?? 0;
    final resolvableTickets = (tech['resolvableTickets'] as int?) ?? 0;
    final closed = (tech['closed'] as int?) ?? 0;

    String avgTimeLabel;
    if (avgHours == 0) {
      avgTimeLabel = 'N/A';
    } else if (avgHours < 1) {
      avgTimeLabel = '${(avgHours * 60).toStringAsFixed(0)} mins';
    } else {
      avgTimeLabel = '${avgHours.toStringAsFixed(1)} hrs';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Rank Number
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: index < 3
                      ? LinearGradient(
                          colors: [_primaryBlue, _primaryBlue.withOpacity(0.7)],
                        )
                      : null,
                  color: index >= 3 ? Colors.grey[100] : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: index < 3
                      ? [
                          BoxShadow(
                            color: _primaryBlue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  "${index + 1}",
                  style: TextStyle(
                    color: index < 3 ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name & Specialization
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tech['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tech['specialization'],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Percentage
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${completion.toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: progressColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    "Success",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[400],
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completion / 100,
              minHeight: 10,
              backgroundColor: Colors.grey[100],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 16),

          // Status chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(
                "Assigned",
                tech['assigned'],
                Colors.blue[50]!,
                Colors.blue[700]!,
              ),
              _statusChip(
                "In Progress",
                tech['inProgress'],
                Colors.orange[50]!,
                Colors.orange[800]!,
              ),
              _statusChip(
                "Resolved",
                tech['resolved'],
                Colors.green[50]!,
                Colors.green[700]!,
              ),
              _statusChip(
                "Closed",
                closed,
                Colors.grey[100]!,
                Colors.grey[700]!,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Divider
          Divider(color: Colors.grey[100], height: 1),
          const SizedBox(height: 16),

          // New metrics row
          Row(
            children: [
              // Avg Resolution Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Avg Resolution',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      avgTimeLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: avgHours == 0
                            ? Colors.grey
                            : avgHours <= 4
                            ? Colors.green
                            : avgHours <= 8
                            ? _accentOrange
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),

              // Vertical divider
              Container(height: 40, width: 1, color: Colors.grey[200]),

              const SizedBox(width: 16),

              // Report Submission Rate
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Reports Submitted',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resolvableTickets == 0
                          ? 'N/A'
                          : '$reportsSubmitted / $resolvableTickets',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: resolvableTickets == 0
                            ? Colors.grey
                            : reportsSubmitted == resolvableTickets
                            ? Colors.green
                            : _accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, int count, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$count",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: textColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 60, color: Colors.grey[300]),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              "Something went wrong",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
