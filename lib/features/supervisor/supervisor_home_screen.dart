import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/in_memory_store.dart';
import '../../models/ticket.dart';
import '../../models/user.dart';
import '../../utils/enums.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<InMemoryStore>();
    final currentUser = store.currentUser;
    final tickets = store.visibleTickets;

    // Calculate KPIs
    final totalTickets = tickets.length;
    final newTickets = tickets
        .where((t) => t.status == TicketStatus.newTicket)
        .length;
    final pendingTickets = tickets
        .where((t) => t.status == TicketStatus.assigned)
        .length;
    final inProgressTickets = tickets
        .where((t) => t.status == TicketStatus.inProgress)
        .length;
    final resolvedTickets = tickets
        .where(
          (t) =>
              t.status == TicketStatus.resolved ||
              t.status == TicketStatus.closed,
        )
        .length;

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
                        currentUser?.name ?? "Supervisor",
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
                          Colors.blue,
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
                  Row(
                    children: [
                      Expanded(
                        child: _buildKPICard(
                          "Pending",
                          pendingTickets,
                          Icons.pending_actions,
                          Colors.orange,
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKPICard(
                          "Resolved",
                          resolvedTickets,
                          Icons.check_circle_outline,
                          Colors.green,
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
                        // Visual mock of a stacked bar chart
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
                                if (pendingTickets > 0)
                                  Expanded(
                                    flex: pendingTickets,
                                    child: Container(
                                      height: 12,
                                      color: Colors.orange,
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
                        // Legend
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildLegendItem("New", Colors.red),
                            _buildLegendItem("Pending", Colors.orange),
                            _buildLegendItem("In Progress", Colors.purple),
                            _buildLegendItem("Resolved", Colors.green),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        // Visual mock of a vertical bar chart
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildTrendBar("Mon", 0.4),
                            _buildTrendBar("Tue", 0.7),
                            _buildTrendBar("Wed", 0.5),
                            _buildTrendBar("Thu", 0.9), // peak
                            _buildTrendBar("Fri", 0.6),
                            _buildTrendBar("Sat", 0.2),
                            _buildTrendBar("Sun", 0.1),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

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

                  // Ticket List
                  if (tickets.isEmpty)
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
                      itemCount: tickets.length > 5
                          ? 5
                          : tickets.length, // Show up to 5
                      itemBuilder: (context, index) {
                        return _buildRecentTicketCard(
                          context,
                          store,
                          tickets[index],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Floating Action Button to create a ticket (moved from inline to standard FAB)
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
    InMemoryStore store,
    Ticket ticket,
  ) {
    // Look up technician name if assigned
    String? assignedName;
    if (ticket.assignedTo != null) {
      final tech = store.technicians.firstWhere(
        (u) => u.id == ticket.assignedTo,
        orElse: () => store.users.firstWhere(
          (u) => u.id == ticket.assignedTo,
          orElse: () =>
              AppUser(id: '', name: 'Unknown', role: UserRole.technician),
        ),
      );
      assignedName = tech.name;
    }

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
              '/admin/ticket',
              arguments: ticket.id,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        ticket.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(ticket.status),
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
                        ticket.assignedTo != null
                            ? "Assigned: $assignedName"
                            : "Unassigned",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                    if (ticket.status == TicketStatus.newTicket)
                      SizedBox(
                        height: 30,
                        child: TextButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/admin/assign',
                            arguments: ticket.id,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6600),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: const Color(
                              0xFFFF6600,
                            ).withOpacity(0.1),
                          ),
                          child: const Text(
                            "Assign",
                            style: TextStyle(
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

  Widget _buildStatusBadge(TicketStatus status) {
    Color color;
    switch (status) {
      case TicketStatus.newTicket:
        color = Colors.red;
        break;
      case TicketStatus.assigned:
        color = Colors.orange;
        break;
      case TicketStatus.inProgress:
        color = Colors.purple;
        break;
      case TicketStatus.resolved:
        color = Colors.green;
        break;
      case TicketStatus.closed:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
