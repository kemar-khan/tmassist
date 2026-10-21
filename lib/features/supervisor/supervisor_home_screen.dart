import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/service_areas.dart';
import '../../utils/cancelled_status.dart';

class SupervisorHomeScreen extends StatefulWidget {
  const SupervisorHomeScreen({super.key});

  @override
  State<SupervisorHomeScreen> createState() => _SupervisorHomeScreenState();
}

class _SupervisorHomeScreenState extends State<SupervisorHomeScreen> {
  String? _selectedCategory;
  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    return StreamBuilder<DocumentSnapshot>(
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
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error: ${ticketSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
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
            ;
            final weeklyCounts = _getWeeklyTicketCounts(tickets);
            final maxWeeklyCount = weeklyCounts.values.isEmpty
                ? 0
                : weeklyCounts.values.reduce((a, b) => a > b ? a : b);

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

            return Scaffold(
              backgroundColor: const Color(0xFFF5F5F5),
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header + Notification Icon
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                      decoration: const BoxDecoration(
                        color: Color(0xFF005CAB),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Welcome back,",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                supervisorName + " | Supervisor",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.notifications_none_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                // Notifications
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2. KPI Summary
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Overview",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Top row of KPIs
                          Row(
                            children: [
                              Expanded(
                                child: _buildKPICard(
                                  "Total Tickets",
                                  totalTickets,
                                  Icons.confirmation_number_outlined,
                                  Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildKPICard(
                                  "New Complaints",
                                  newTickets,
                                  Icons.new_releases_outlined,
                                  Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Bottom row of KPIs
                          // Bottom row of KPIs
                          Row(
                            children: [
                              Expanded(
                                child: _buildKPICard(
                                  "Assigned",
                                  assignedTickets,
                                  Icons.pending_actions,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildKPICard(
                                  "In Progress",
                                  inProgressTickets,
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
                                  "Resolved",
                                  resolvedTickets,
                                  Icons.check_circle_outline,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildKPICard(
                                  "Closed",
                                  closedTickets,
                                  Icons.lock_outline,
                                  Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 3. Quick View Charts
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Quick Analytics",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Status Distribution (Horizontal Bar)
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
                                  "Status Distribution",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (totalTickets > 0)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Row(
                                      children: [
                                        if (newTickets > 0)
                                          Expanded(
                                            flex: newTickets,
                                            child: Container(
                                              height: 12,
                                              color: Colors.red,
                                            ),
                                          ),
                                        if (assignedTickets > 0)
                                          Expanded(
                                            flex: assignedTickets,
                                            child: Container(
                                              height: 12,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        if (inProgressTickets > 0)
                                          Expanded(
                                            flex: inProgressTickets,
                                            child: Container(
                                              height: 12,
                                              color: Colors.purple,
                                            ),
                                          ),
                                        if (resolvedTickets > 0)
                                          Expanded(
                                            flex: resolvedTickets,
                                            child: Container(
                                              height: 12,
                                              color: Colors.green,
                                            ),
                                          ),
                                        if (closedTickets > 0)
                                          Expanded(
                                            flex: closedTickets,
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
                                    _buildLegendItem("New", Colors.red),
                                    _buildLegendItem("Assigned", Colors.blue),
                                    _buildLegendItem(
                                      "In Progress",
                                      Colors.purple,
                                    ),
                                    _buildLegendItem("Resolved", Colors.green),
                                    _buildLegendItem("Closed", Colors.grey),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Ticket Trends (Mock Bar Chart)
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Weekly Ticket Volume",
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _buildTrendBar(
                                      "Mon",
                                      _getBarHeightFactor(
                                        weeklyCounts['Mon']!,
                                        maxWeeklyCount,
                                      ),
                                    ),
                                    _buildTrendBar(
                                      "Tue",
                                      _getBarHeightFactor(
                                        weeklyCounts['Tue']!,
                                        maxWeeklyCount,
                                      ),
                                    ),
                                    _buildTrendBar(
                                      "Wed",
                                      _getBarHeightFactor(
                                        weeklyCounts['Wed']!,
                                        maxWeeklyCount,
                                      ),
                                    ),
                                    _buildTrendBar(
                                      "Thu",
                                      _getBarHeightFactor(
                                        weeklyCounts['Thu']!,
                                        maxWeeklyCount,
                                      ),
                                    ),
                                    _buildTrendBar(
                                      "Fri",
                                      _getBarHeightFactor(
                                        weeklyCounts['Fri']!,
                                        maxWeeklyCount,
                                      ),
                                    ),
                                    _buildTrendBar(
                                      "Sat",
                                      _getBarHeightFactor(
                                        weeklyCounts['Sat']!,
                                        maxWeeklyCount,
                                      ),
                                    ),
                                    _buildTrendBar(
                                      "Sun",
                                      _getBarHeightFactor(
                                        weeklyCounts['Sun']!,
                                        maxWeeklyCount,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    // Tickets by Location
                    _buildCategoryOverview(categoryKeys, categoryTotals),
                    const SizedBox(height: 32),

                    // 4. Recent Tickets
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Recent Tickets",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  // View all functionality
                                },
                                child: const Text(
                                  "View All",
                                  style: TextStyle(color: Color(0xFF005CAB)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (isFiltering)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Showing: $_selectedCategory (${filteredTickets.length})',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _selectedCategory = null;
                                    }),
                                    child: const Text(
                                      'Clear',
                                      style: TextStyle(
                                        color: Color(0xFF005CAB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (filteredTickets.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text("No tickets found."),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 40),
                              itemCount:
                                  filteredTickets.length >
                                      (isFiltering ? 10 : 5)
                                  ? (isFiltering ? 10 : 5)
                                  : filteredTickets.length,
                              itemBuilder: (context, index) {
                                return _buildRecentTicketCard(
                                  context,
                                  filteredTickets[index],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _categoryOf(Map<String, dynamic> t) {
    final c = (t['category'] ?? '').toString();
    return const ['Network', 'Hardware', 'Software'].contains(c) ? c : 'Other';
  }

  Widget _buildCategoryOverview(
    List<String> categoryKeys,
    Map<String, int> categoryTotals,
  ) {
    const blue = Color(0xFF005CAB);
    const icons = {
      'Network': Icons.wifi_rounded,
      'Hardware': Icons.router_outlined,
      'Software': Icons.settings_applications_outlined,
      'Other': Icons.more_horiz_rounded,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tickets by Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a card to filter the ticket list below.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          Row(
            children: categoryKeys.map((cat) {
              final selected = _selectedCategory == cat;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: cat == categoryKeys.last ? 0 : 8,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(
                      () => _selectedCategory = selected ? null : cat,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected ? blue.withOpacity(0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? blue : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(icons[cat], color: blue, size: 22),
                          const SizedBox(height: 8),
                          Text(
                            '${categoryTotals[cat]}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cat,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  // --- Helper UI Methods ---

  Widget _buildKPICard(String title, int count, IconData icon, Color color) {
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
                count.toString(),
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

  Widget _buildRecentTicketCard(
    BuildContext context,
    Map<String, dynamic> ticket,
  ) {
    final assignedName = (ticket['technicianName'] ?? '').toString();
    final technicianId = ticket['technicianId'];
    final status = (ticket['status'] ?? 'NEW').toString().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/supervisor/ticket',
              arguments: ticket['id'],
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (ticket['title'] ?? '').toString(),
                        style: CancelledStatus.titleStyle(
                          const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                          status,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        assignedName.isNotEmpty
                            ? "Assigned: $assignedName"
                            : technicianId != null
                            ? "Assigned (ID: ${technicianId.toString().substring(0, 8)}...)"
                            : "Unassigned",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                    if (status == 'NEW')
                      SizedBox(
                        height: 30,
                        child: TextButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/supervisor/assign',
                            arguments: ticket['id'],
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6600),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: const Color(0xFFFF6600),
                          ),
                          child: const Text(
                            "Assign",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'NEW':
        color = Colors.red;
        label = 'New';
        break;
      case 'ASSIGNED':
        color = Colors.blue;
        label = 'Assigned';
        break;
      case 'IN_PROGRESS':
        color = Colors.purple;
        label = 'In Progress';
        break;
      case 'RESOLVED':
        color = Colors.green;
        label = 'Resolved';
        break;
      case 'CLOSED':
        color = Colors.grey;
        label = 'Closed';
        break;
      case 'CANCELLED':
        color = CancelledStatus.textColor;
        label = CancelledStatus.label;
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CancelledStatus.isCancelled(status)
            ? CancelledStatus.backgroundColor
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
