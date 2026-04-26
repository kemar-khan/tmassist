import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/in_memory_store.dart';
import '../../models/ticket.dart';
import '../../models/user.dart';
import '../../utils/enums.dart';

class SupervisorTicketDetailScreen extends StatefulWidget {
  final String ticketId;

  const SupervisorTicketDetailScreen({super.key, required this.ticketId});

  @override
  State<SupervisorTicketDetailScreen> createState() =>
      _SupervisorTicketDetailScreenState();
}

class _SupervisorTicketDetailScreenState
    extends State<SupervisorTicketDetailScreen> {
  bool _isUpdating = false;

  void _handleCloseTicket(InMemoryStore store) {
    setState(() => _isUpdating = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      store.updateTicketStatus(
        ticketId: widget.ticketId,
        status: TicketStatus.closed,
      );
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ticket closed successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<InMemoryStore>();
    final ticket = store.getTicketById(widget.ticketId);

    if (ticket == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("Ticket not found")),
      );
    }

    // Mocked data for fields not in the Ticket model yet
    const mockCategory = 'Hardware Issue';
    const mockAddress = '123 Tech Lane, Block B, Floor 4';
    const mockPriority = 'High';

    // Find assigned technician name
    String? assignedTechName;
    if (ticket.assignedTo != null) {
      final tech = store.users.firstWhere(
        (u) => u.id == ticket.assignedTo,
        orElse: () => const AppUser(
          id: '',
          name: 'Unknown Technician',
          role: UserRole.technician,
        ),
      );
      assignedTechName = tech.name;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Supervisor View',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF005CAB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Primary Action (Assign or Close)
            if (ticket.status == TicketStatus.newTicket)
              _buildActionCard(
                title: "Ticket is Unassigned",
                buttonLabel: "ASSIGN TECHNICIAN",
                icon: Icons.person_add_alt_1_rounded,
                color: const Color(0xFFFF6600),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/admin/assign',
                    arguments: ticket.id,
                  );
                },
              )
            else if (ticket.status == TicketStatus.resolved)
              _buildActionCard(
                title: "Ticket Resolved by Technician",
                buttonLabel: "CLOSE TICKET",
                icon: Icons.check_circle_outline,
                color: Colors.green,
                onPressed: _isUpdating ? null : () => _handleCloseTicket(store),
              )
            else if (ticket.status == TicketStatus.closed)
              _buildInfoStatusCard(
                "This ticket is Closed",
                Icons.lock_outline,
                Colors.grey,
              )
            else
              _buildInfoStatusCard(
                "Technician is currently working on this",
                Icons.engineering_outlined,
                Colors.purple,
              ),

            const SizedBox(height: 24),

            // 2. Ticket Status & Progress Timeline
            _buildSectionTitle('Ticket Progress'),
            _buildStatusTimelineCard(ticket.status),
            const SizedBox(height: 24),

            // 3. Technician Info (if assigned)
            if (ticket.assignedTo != null) ...[
              _buildSectionTitle('Assigned Technician'),
              _buildTechnicianCard(assignedTechName ?? "Unknown"),
              const SizedBox(height: 24),
            ],

            // 4. Ticket Info
            _buildSectionTitle('Ticket Info'),
            _buildInfoCard(ticket, mockCategory, mockAddress, mockPriority),
            const SizedBox(height: 24),

            // 5. Activity Log
            _buildSectionTitle('Activity Log'),
            _buildActivityLogCard(ticket, assignedTechName),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildActionCard({
    required String title,
    required String buttonLabel,
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return _buildCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStatusCard(String text, IconData icon, Color color) {
    return _buildCard(
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimelineCard(TicketStatus currentStatus) {
    final steps = [
      {'title': 'Assigned', 'status': TicketStatus.assigned},
      {'title': 'In Progress', 'status': TicketStatus.inProgress},
      {'title': 'Resolved', 'status': TicketStatus.resolved},
    ];

    int currentStepIndex = 0;
    switch (currentStatus) {
      case TicketStatus.newTicket:
        currentStepIndex = 0;
        break;
      case TicketStatus.assigned:
        currentStepIndex = 1;
        break;
      case TicketStatus.inProgress:
        currentStepIndex = 2;
        break;
      case TicketStatus.resolved:
        currentStepIndex = 3;
        break;
      case TicketStatus.closed:
        currentStepIndex = 4;
        break;
    }

    return _buildCard(
      child: Column(
        children: List.generate(steps.length, (index) {
          final isCompleted = index <= currentStepIndex;
          final isCurrent = index == currentStepIndex;
          final isLast = index == steps.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? const Color(0xFF005CAB)
                          : Colors.grey[200],
                      border: isCurrent
                          ? Border.all(color: const Color(0xFFFF6600), width: 2)
                          : null,
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 25,
                      color: isCompleted
                          ? const Color(0xFF005CAB)
                          : Colors.grey[200],
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    steps[index]['title'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : (isCompleted ? FontWeight.w600 : FontWeight.normal),
                      color: isCompleted
                          ? const Color(0xFF333333)
                          : Colors.grey[500],
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTechnicianCard(String name) {
    return _buildCard(
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFF005CAB),
            child: Icon(Icons.engineering, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Assigned Technician',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: Color(0xFFFF6600)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    Ticket ticket,
    String category,
    String address,
    String priority,
  ) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Customer Name', 'Azka'),
          _buildDivider(),
          _buildInfoRow('Ticket ID', '#${ticket.id.toUpperCase()}'),
          _buildDivider(),
          _buildInfoRow('Category', category),
          _buildDivider(),
          _buildInfoRow(
            'Priority',
            priority,
            valueColor: const Color(0xFFFF6600),
          ),
          _buildDivider(),
          _buildInfoRow(
            'Submitted',
            '${ticket.createdAt.day}/${ticket.createdAt.month}/${ticket.createdAt.year}',
          ),
          _buildDivider(),
          _buildInfoRow('Address', address),
          _buildDivider(),
          const Text(
            'Issue Description',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ticket.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ticket.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? const Color(0xFF333333),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Divider(color: Colors.grey[100], height: 16);

  Widget _buildActivityLogCard(Ticket ticket, String? techName) {
    final logs = [
      {
        'title': 'Ticket Created',
        'date': ticket.createdAt,
        'desc': 'Logged in system.',
      },
      if (ticket.assignedTo != null)
        {
          'title': 'Assigned',
          'date': ticket.updatedAt.subtract(const Duration(hours: 2)),
          'desc': 'Assigned to $techName.',
        },
      if (ticket.status == TicketStatus.inProgress ||
          ticket.status == TicketStatus.resolved ||
          ticket.status == TicketStatus.closed)
        {
          'title': 'Work Started',
          'date': ticket.updatedAt.subtract(const Duration(hours: 1)),
          'desc': 'Technician is on site.',
        },
      if (ticket.status == TicketStatus.resolved ||
          ticket.status == TicketStatus.closed)
        {
          'title': 'Resolved',
          'date': ticket.updatedAt,
          'desc': 'Technician marked as resolved.',
        },
    ].reversed.toList();

    return _buildCard(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final isFirst = index == 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isFirst
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 14,
                  color: isFirst ? const Color(0xFF005CAB) : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            logs[index]['title'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isFirst
                                  ? const Color(0xFF333333)
                                  : Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${(logs[index]['date'] as DateTime).day}/${(logs[index]['date'] as DateTime).month}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        logs[index]['desc'] as String,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
