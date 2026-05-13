// lib/features/supervisor/technician_performance_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';

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

              final techDocs = userSnapshot.data!.docs;
              final ticketDocs = ticketSnapshot.data?.docs ?? [];

              final startOfWeek = _startOfWeek(DateTime.now());
              Map<String, int> weeklyActivity = {};
              List<Map<String, dynamic>> technicians = [];

              for (var tech in techDocs) {
                final data = tech.data() as Map<String, dynamic>;
                final techId = tech.id;
                final name = data['fullName'] ?? "Technician";
                final specialization = data['specialization'] ?? "Generalist";

                int assigned = 0;
                int inProgress = 0;
                int resolved = 0;
                int total = 0;

                for (var ticket in ticketDocs) {
                  final t = ticket.data() as Map<String, dynamic>;

                  if (t['technicianId'] == techId) {
                    total++;
                    final status = (t['status'] ?? '').toString().toUpperCase();

                    if (status == 'ASSIGNED') assigned++;
                    if (status == 'IN_PROGRESS') inProgress++;
                    if (status == 'RESOLVED' || status == 'CLOSED') resolved++;

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
                    ? (resolved / total * 100)
                    : 0.0;

                technicians.add({
                  'id': techId,
                  'name': name,
                  'specialization': specialization,
                  'assigned': assigned,
                  'inProgress': inProgress,
                  'resolved': resolved,
                  'total': total,
                  'completionRate': completionRate,
                });
              }

              // Sort by completion rate descending
              technicians.sort(
                (a, b) => b['completionRate'].compareTo(a['completionRate']),
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
                  // 🔵 Dashboard Stats Header
                  _buildKpiHeader(technicians, weeklyActivity),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      children: [
                        // 🏆 Top Performer Highlight
                        if (mostActiveTech.isNotEmpty)
                          _buildTopPerformerCard(mostActiveTech, maxActivity)
                        else
                          _buildEmptyActivityCard(),

                        const SizedBox(height: 20),

                        // 🔍 Search Bar
                        _buildSearchBar(),

                        const SizedBox(height: 24),

                        // 📊 Rankings Title
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 16),
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
                          }).toList(),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
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
          const SizedBox(height: 20),
          // Progress Bar with spacing
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: completion / 100,
                  minHeight: 10,
                  backgroundColor: Colors.grey[100],
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Counts - Responsive Wrap
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
