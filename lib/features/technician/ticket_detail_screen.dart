import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/in_memory_store.dart';
import '../../models/ticket.dart';
import '../../utils/enums.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;

  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  bool _isUpdating = false;

  void _handleStatusChange(TicketStatus? newStatus, InMemoryStore store) {
    if (newStatus == null) return;

    setState(() => _isUpdating = true);

    // Simulate minor delay for premium feel
    Future.delayed(const Duration(milliseconds: 500), () {
      store.updateTicketStatus(ticketId: widget.ticketId, status: newStatus);
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Status updated to ${newStatus.displayName}"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Job Details',
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
            // 1. Status Update Section (Technician Specific)
            _buildSectionTitle('Update Job Status'),
            _buildUpdateStatusCard(ticket, store),
            const SizedBox(height: 24),

            // 2. Action Buttons (Technician Specific)
            _buildSectionTitle('Actions'),
            _buildActionButtons(),
            const SizedBox(height: 24),

            // 3. Ticket Status & Progress Timeline
            _buildSectionTitle('Progress Timeline'),
            _buildStatusTimelineCard(ticket.status),
            const SizedBox(height: 24),

            // 4. Ticket Info
            _buildSectionTitle('Ticket Info'),
            _buildInfoCard(ticket, mockCategory, mockAddress, mockPriority),
            const SizedBox(height: 24),

            // 5. Activity Log
            _buildSectionTitle('Activity Log'),
            _buildActivityLogCard(ticket),
            const SizedBox(height: 24),

            // 6. Attachments
            _buildSectionTitle('Attachments'),
            _buildAttachmentsCard(),
            const SizedBox(height: 32),
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

  // --- 1. Update Status Card ---
  Widget _buildUpdateStatusCard(Ticket ticket, InMemoryStore store) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select Current Status",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TicketStatus>(
            initialValue: ticket.status,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.sync_rounded, color: Colors.orange),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            items:
                [
                  TicketStatus.assigned,
                  TicketStatus.inProgress,
                  TicketStatus.resolved,
                  TicketStatus.closed,
                ].map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status.displayName),
                  );
                }).toList(),
            onChanged: _isUpdating
                ? null
                : (val) => _handleStatusChange(val, store),
          ),
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Center(
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: Colors.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- 2. Action Buttons Card ---
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.checklist_rtl_rounded,
            label: "CHECKLIST",
            color: const Color(0xFFFF6600),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/tech/checklist',
                arguments: widget.ticketId,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.summarize_rounded,
            label: "REPORT",
            color: const Color(0xFF005CAB),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/tech/report',
                arguments: widget.ticketId,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // --- 3. Status Timeline Card ---
  Widget _buildStatusTimelineCard(TicketStatus currentStatus) {
    final steps = [
      {'title': 'Assigned', 'status': TicketStatus.assigned},
      {'title': 'In Progress', 'status': TicketStatus.inProgress},
      {'title': 'Completed', 'status': TicketStatus.resolved},
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
      case TicketStatus.closed:
        currentStepIndex = 3;
        break;
    }

    return _buildCard(
      child: Column(
        children: List.generate(steps.length, (index) {
          final step = steps[index];
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
                    step['title'] as String,
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

  // --- 4. Ticket Info Card ---
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

  Widget _buildDivider() {
    return Divider(color: Colors.grey[100], height: 16);
  }

  // --- 5. Activity Log Card ---
  Widget _buildActivityLogCard(Ticket ticket) {
    final logs = [
      {
        'title': 'Ticket Created',
        'date': ticket.createdAt,
        'desc': 'System logged ticket.',
      },
      if (ticket.status != TicketStatus.newTicket)
        {
          'title': 'Assigned',
          'date': ticket.updatedAt.subtract(const Duration(hours: 1)),
          'desc': 'Assigned to your queue.',
        },
      if (ticket.status == TicketStatus.inProgress ||
          ticket.status == TicketStatus.resolved)
        {
          'title': 'In Progress',
          'date': ticket.updatedAt.subtract(const Duration(minutes: 15)),
          'desc': 'You started working.',
        },
    ].reversed.toList();

    return _buildCard(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          final date = log['date'] as DateTime;
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
                            log['title'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isFirst
                                  ? const Color(0xFF333333)
                                  : Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        log['desc'] as String,
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

  // --- 6. Attachments Card ---
  Widget _buildAttachmentsCard() {
    return _buildCard(
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.image_outlined, color: Colors.grey[400]),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'router_photo.jpg',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '850 KB',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.remove_red_eye_outlined,
            color: Color(0xFF005CAB),
            size: 20,
          ),
        ],
      ),
    );
  }
}
