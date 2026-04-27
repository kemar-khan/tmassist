import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  Future<void> _handleCloseTicket() async {
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .update({
            'status': 'CLOSED',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ticket closed successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to close ticket: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: Center(child: Text("Error: ${snapshot.error}")),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: const Center(child: Text("Ticket not found")),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        final status = (data['status'] ?? 'NEW').toString().toUpperCase();
        final title = (data['title'] ?? 'No Title').toString();
        final description = (data['description'] ?? '').toString();
        final category = (data['category'] ?? '-').toString();
        final address = (data['address'] ?? '-').toString();
        final customerName = (data['customerName'] ?? '-').toString();
        final technicianName = (data['technicianName'] ?? '').toString();
        final technicianId = (data['technicianId'] ?? '').toString();
        final createdAt = data['createdAt'] as Timestamp?;
        final updatedAt = data['updatedAt'] as Timestamp?;

        final hasTechnician =
            technicianId.trim().isNotEmpty || technicianName.trim().isNotEmpty;

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
                if (status == 'NEW')
                  _buildActionCard(
                    title: "Ticket is Unassigned",
                    buttonLabel: "ASSIGN TECHNICIAN",
                    icon: Icons.person_add_alt_1_rounded,
                    color: const Color(0xFFFF6600),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/supervisor/assign',
                        arguments: widget.ticketId,
                      );
                    },
                  )
                else if (status == 'RESOLVED')
                  _buildActionCard(
                    title: "Ticket Resolved by Technician",
                    buttonLabel: "CLOSE TICKET",
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                    onPressed: _isUpdating ? null : _handleCloseTicket,
                  )
                else if (status == 'CLOSED')
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

                _buildSectionTitle('Ticket Progress'),
                _buildStatusTimelineCard(status),
                const SizedBox(height: 24),

                if (hasTechnician) ...[
                  _buildSectionTitle('Assigned Technician'),
                  _buildTechnicianCard(
                    technicianName.isNotEmpty ? technicianName : technicianId,
                  ),
                  const SizedBox(height: 24),
                ],

                _buildSectionTitle('Ticket Info'),
                _buildInfoCard(
                  ticketId: widget.ticketId,
                  customerName: customerName,
                  category: category,
                  address: address,
                  createdAt: createdAt,
                  title: title,
                  description: description,
                ),
                const SizedBox(height: 24),

                _buildSectionTitle('Activity Log'),
                _buildActivityLogCard(
                  status: status,
                  createdAt: createdAt,
                  updatedAt: updatedAt,
                  technicianName: technicianName,
                  hasTechnician: hasTechnician,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
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
              child: _isUpdating && buttonLabel == "CLOSE TICKET"
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : Text(
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

  Widget _buildStatusTimelineCard(String currentStatus) {
    final steps = [
      {'title': 'New', 'status': 'NEW'},
      {'title': 'Assigned', 'status': 'ASSIGNED'},
      {'title': 'In Progress', 'status': 'IN_PROGRESS'},
      {'title': 'Resolved', 'status': 'RESOLVED'},
    ];

    int currentStepIndex = 0;
    switch (currentStatus) {
      case 'NEW':
        currentStepIndex = 0;
        break;
      case 'ASSIGNED':
        currentStepIndex = 1;
        break;
      case 'IN_PROGRESS':
        currentStepIndex = 2;
        break;
      case 'RESOLVED':
        currentStepIndex = 3;
        break;
      case 'CLOSED':
        currentStepIndex = 4;
        break;
      default:
        currentStepIndex = 0;
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

  Widget _buildInfoCard({
    required String ticketId,
    required String customerName,
    required String category,
    required String address,
    required Timestamp? createdAt,
    required String title,
    required String description,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Customer Name', customerName),
          _buildDivider(),
          _buildInfoRow('Ticket ID', '#${ticketId.toUpperCase()}'),
          _buildDivider(),
          _buildInfoRow('Category', category),
          _buildDivider(),
          _buildInfoRow('Submitted', _formatTimestamp(createdAt)),
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
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
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
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? const Color(0xFF333333),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Divider(color: Colors.grey[100], height: 16);

  Widget _buildActivityLogCard({
    required String status,
    required Timestamp? createdAt,
    required Timestamp? updatedAt,
    required String technicianName,
    required bool hasTechnician,
  }) {
    final createdDate = createdAt?.toDate();
    final updatedDate = updatedAt?.toDate();

    final logs = [
      {
        'title': 'Ticket Created',
        'date': createdDate,
        'desc': 'Logged in system.',
      },
      if (hasTechnician)
        {
          'title': 'Assigned',
          'date': updatedDate,
          'desc': technicianName.trim().isNotEmpty
              ? 'Assigned to $technicianName.'
              : 'Assigned to technician.',
        },
      if (status == 'IN_PROGRESS' || status == 'RESOLVED' || status == 'CLOSED')
        {
          'title': 'Work Started',
          'date': updatedDate,
          'desc': 'Technician is on site.',
        },
      if (status == 'RESOLVED' || status == 'CLOSED')
        {
          'title': 'Resolved',
          'date': updatedDate,
          'desc': 'Technician marked as resolved.',
        },
      if (status == 'CLOSED')
        {
          'title': 'Closed',
          'date': updatedDate,
          'desc': 'Supervisor closed the ticket.',
        },
    ].reversed.toList();

    return _buildCard(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final isFirst = index == 0;
          final logDate = logs[index]['date'] as DateTime?;

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
                          Expanded(
                            child: Text(
                              logs[index]['title'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isFirst
                                    ? const Color(0xFF333333)
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatShortDate(logDate),
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatShortDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}';
  }
}
