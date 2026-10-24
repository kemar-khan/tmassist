import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/cancelled_status.dart';

class TechAnalyticsScreen extends StatelessWidget {
  const TechAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    final uid = firebaseUser.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tickets')
          .where('technicianId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F5F5),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5F5),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        // Cancelled tickets are excluded from the technician's stats.
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return !CancelledStatus.isCancelled(data['status']);
        });

        final tickets = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'status': (data['status'] ?? '').toString().toUpperCase(),
            'category': (data['category'] ?? 'Other').toString(),
            'createdAt': data['createdAt'],
            'checklistDone': data['checklistDone'],
          };
        }).toList();

        // --- KPI Counts ---
        final total = tickets.length;
        final inProgress = tickets
            .where((t) => t['status'] == 'IN_PROGRESS')
            .length;
        // A CLOSED ticket was RESOLVED first, so both count as resolved work.
        const resolvedStatuses = {'RESOLVED', 'CLOSED'};
        final resolved = tickets
            .where((t) => resolvedStatuses.contains(t['status']))
            .length;
        final assigned = tickets.where((t) => t['status'] == 'ASSIGNED').length;
        final resolutionRate = total > 0
            ? ((resolved / total) * 100).toStringAsFixed(0)
            : '0';

        // --- Category Breakdown ---
        final categoryCount = <String, int>{
          'Network': 0,
          'Hardware': 0,
          'Software': 0,
          'Other': 0,
        };
        for (final t in tickets) {
          final cat = t['category'].toString();
          if (categoryCount.containsKey(cat)) {
            categoryCount[cat] = categoryCount[cat]! + 1;
          } else {
            categoryCount['Other'] = categoryCount['Other']! + 1;
          }
        }

        // --- Weekly Resolved Bar Chart ---
        final weeklyCounts = <String, int>{
          'Mon': 0,
          'Tue': 0,
          'Wed': 0,
          'Thu': 0,
          'Fri': 0,
          'Sat': 0,
          'Sun': 0,
        };
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        for (final t in tickets) {
          if (!resolvedStatuses.contains(t['status'])) continue;
          final createdAt = t['createdAt'];
          if (createdAt is! Timestamp) continue;
          final date = createdAt.toDate();
          if (date.isBefore(startOfWeek)) continue;
          switch (date.weekday) {
            case DateTime.monday:
              weeklyCounts['Mon'] = weeklyCounts['Mon']! + 1;
              break;
            case DateTime.tuesday:
              weeklyCounts['Tue'] = weeklyCounts['Tue']! + 1;
              break;
            case DateTime.wednesday:
              weeklyCounts['Wed'] = weeklyCounts['Wed']! + 1;
              break;
            case DateTime.thursday:
              weeklyCounts['Thu'] = weeklyCounts['Thu']! + 1;
              break;
            case DateTime.friday:
              weeklyCounts['Fri'] = weeklyCounts['Fri']! + 1;
              break;
            case DateTime.saturday:
              weeklyCounts['Sat'] = weeklyCounts['Sat']! + 1;
              break;
            case DateTime.sunday:
              weeklyCounts['Sun'] = weeklyCounts['Sun']! + 1;
              break;
          }
        }
        final maxWeekly = weeklyCounts.values.isEmpty
            ? 0
            : weeklyCounts.values.reduce((a, b) => a > b ? a : b);

        // --- Checklist Completion Rate ---
        double totalCompletionRate = 0;
        int ticketsWithChecklist = 0;
        for (final t in tickets) {
          final raw = t['checklistDone'];
          if (raw == null) continue;
          final done = List<bool>.from((raw as List).map((e) => e == true));
          if (done.isEmpty) continue;
          final completed = done.where((d) => d).length;
          totalCompletionRate += completed / done.length;
          ticketsWithChecklist++;
        }
        final avgChecklist = ticketsWithChecklist > 0
            ? ((totalCompletionRate / ticketsWithChecklist) * 100)
                  .toStringAsFixed(0)
            : '0';

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                  decoration: const BoxDecoration(
                    color: Color(0xFF005CAB),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Analytics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your personal performance overview',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Section 1 — KPI Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Performance Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildKPICard(
                              'Total Assigned',
                              total,
                              Icons.confirmation_number_outlined,
                              Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildKPICard(
                              'In Progress',
                              inProgress,
                              Icons.engineering_outlined,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildKPICard(
                              'Resolved',
                              resolved,
                              Icons.check_circle_outline,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildKPICard(
                              'Resolution Rate',
                              null,
                              Icons.trending_up_rounded,
                              Colors.orange,
                              label: '$resolutionRate%',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Section 2 — Checklist Performance
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Checklist Performance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Avg. Checklist Completion',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '$avgChecklist%',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF005CAB),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: ticketsWithChecklist > 0
                                    ? totalCompletionRate / ticketsWithChecklist
                                    : 0,
                                minHeight: 12,
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF005CAB),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Based on $ticketsWithChecklist ticket(s) with checklist data',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Section 3 — Weekly Resolved Chart
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Analytics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Weekly bar chart
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Resolved This Week',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                Icon(
                                  Icons.bar_chart_rounded,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: weeklyCounts.entries.map((e) {
                                final factor = maxWeekly == 0
                                    ? 0.1
                                    : (e.value / maxWeekly) < 0.1
                                    ? 0.1
                                    : e.value / maxWeekly;
                                return _buildTrendBar(e.key, factor.toDouble());
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Category breakdown
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tickets by Category',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (total > 0)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  children: [
                                    if ((categoryCount['Network'] ?? 0) > 0)
                                      Expanded(
                                        flex: categoryCount['Network']!,
                                        child: Container(
                                          height: 12,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    if ((categoryCount['Hardware'] ?? 0) > 0)
                                      Expanded(
                                        flex: categoryCount['Hardware']!,
                                        child: Container(
                                          height: 12,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    if ((categoryCount['Software'] ?? 0) > 0)
                                      Expanded(
                                        flex: categoryCount['Software']!,
                                        child: Container(
                                          height: 12,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    if ((categoryCount['Other'] ?? 0) > 0)
                                      Expanded(
                                        flex: categoryCount['Other']!,
                                        child: Container(
                                          height: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _buildLegendItem(
                                  'Network (${categoryCount['Network']})',
                                  Colors.blue,
                                ),
                                _buildLegendItem(
                                  'Hardware (${categoryCount['Hardware']})',
                                  Colors.orange,
                                ),
                                _buildLegendItem(
                                  'Software (${categoryCount['Software']})',
                                  Colors.purple,
                                ),
                                _buildLegendItem(
                                  'Other (${categoryCount['Other']})',
                                  Colors.grey,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Helper Widgets ---

  Widget _buildKPICard(
    String title,
    int? count,
    IconData icon,
    Color color, {
    String? label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(bottom: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                label ?? count.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBar(String day, double heightFactor) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 100 * heightFactor,
          decoration: BoxDecoration(
            color: const Color(
              0xFF005CAB,
            ).withOpacity(heightFactor < 0.5 ? 0.3 : 0.8),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
        ),
      ],
    );
  }
}
