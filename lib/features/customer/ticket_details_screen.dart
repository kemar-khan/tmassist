// lib/features/customer/ticket_details_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/in_memory_store.dart';
import '../../models/ticket.dart';
import '../../utils/enums.dart';

class TicketDetailsScreen extends StatelessWidget {
  final String ticketId;

  const TicketDetailsScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<InMemoryStore>();

    // Find ticket or use a dummy if not found
    final Ticket ticket = store.tickets.firstWhere(
      (t) => t.id == ticketId,
      orElse: () => Ticket(
        id: ticketId,
        title: 'Unknown Ticket',
        description: 'Details not found.',
        status: TicketStatus.newTicket,
        createdBy: 'system',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Mocked data for fields not in the Ticket model yet
    const mockCategory = 'Hardware Issue';
    const mockAddress = '123 Tech Lane, Block B, Floor 4';
    const mockPriority = 'High';
    const mockTechName = 'Mike Ross';
    const mockTechPhone = '+1 234 567 8900';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Theme background
      appBar: AppBar(
        title: const Text(
          'Ticket Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF005CAB), // Primary Blue
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Ticket Status & Progress Timeline
            _buildSectionTitle('Ticket Status'),
            _buildStatusCard(ticket.status),
            const SizedBox(height: 24),

            // 2. Ticket Info
            _buildSectionTitle('Ticket Info'),
            _buildInfoCard(ticket, mockCategory, mockAddress, mockPriority),
            const SizedBox(height: 24),

            // 3. Technician Info (Show only if assigned or further)
            if (ticket.status != TicketStatus.newTicket) ...[
              _buildSectionTitle('Technician Info'),
              _buildTechnicianCard(mockTechName, mockTechPhone),
              const SizedBox(height: 24),
            ],

            // 4. Updates / Activity Log
            _buildSectionTitle('Activity Log'),
            _buildActivityLogCard(ticket),
            const SizedBox(height: 24),

            // 5. Attachments
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

  // --- 1. Status Card with Timeline ---
  Widget _buildStatusCard(TicketStatus currentStatus) {
    // Define the timeline steps
    final steps = [
      {'title': 'Assigned', 'status': TicketStatus.assigned},
      {'title': 'In Progress', 'status': TicketStatus.inProgress},
      {'title': 'Completed', 'status': TicketStatus.resolved},
    ];

    // Determine current step index based on status
    int currentStepIndex = 0;
    switch (currentStatus) {
      case TicketStatus.newTicket:
        currentStepIndex = 0;
        break;
      case TicketStatus.assigned:
        currentStepIndex = 2;
        break;
      case TicketStatus.inProgress:
        currentStepIndex = 3;
        break;
      case TicketStatus.resolved:
      case TicketStatus.closed:
        currentStepIndex = 4;
        break;
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Current Status',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildStatusBadge(currentStatus),
            ],
          ),
          const SizedBox(height: 24),
          // Vertical Timeline
          ...List.generate(steps.length, (index) {
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
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? const Color(0xFF005CAB)
                            : Colors.grey[200],
                        border: isCurrent
                            ? Border.all(
                                color: const Color(0xFFFF6600),
                                width: 2,
                              )
                            : null,
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 30,
                        color: isCompleted
                            ? const Color(0xFF005CAB)
                            : Colors.grey[200],
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      step['title'] as String,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : (isCompleted
                                  ? FontWeight.w600
                                  : FontWeight.normal),
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
        ],
      ),
    );
  }

  // --- 2. Ticket Info Card ---
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
          _buildInfoRow('Ticket ID', ticket.id),
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
            'Date Submitted',
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? const Color(0xFF333333),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey[200], height: 16);
  }

  // --- 3. Technician Info Card ---
  Widget _buildTechnicianCard(String name, String phone) {
    return _buildCard(
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFF005CAB), // Primary Blue
            child: Icon(Icons.person, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const Text(
                  'Assigned Technician',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFF6600).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.phone, color: Color(0xFFFF6600)),
              onPressed: () {
                // Handle call
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Activity Log Card ---
  Widget _buildActivityLogCard(Ticket ticket) {
    // Mock logs
    final logs = [
      {
        'title': 'Ticket Submitted',
        'date': ticket.createdAt,
        'desc': 'Ticket was successfully created by customer.',
      },
      if (ticket.status != TicketStatus.newTicket)
        {
          'title': 'Technician Assigned',
          'date': ticket.updatedAt.subtract(const Duration(hours: 2)),
          'desc': 'Mike Ross assigned to ticket.',
        },
      if (ticket.status == TicketStatus.inProgress ||
          ticket.status == TicketStatus.resolved)
        {
          'title': 'In Progress',
          'date': ticket.updatedAt.subtract(const Duration(minutes: 30)),
          'desc': 'Technician is en route / working on the issue.',
        },
      if (ticket.status == TicketStatus.resolved ||
          ticket.status == TicketStatus.closed)
        {
          'title': 'Resolved',
          'date': ticket.updatedAt,
          'desc': 'Issue resolved. Awaiting customer confirmation.',
        },
    ].reversed.toList(); // Latest first

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
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Icon(
                      isFirst
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: isFirst ? const Color(0xFF005CAB) : Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isFirst
                                  ? const Color(0xFF333333)
                                  : Colors.grey[700],
                            ),
                          ),
                          Text(
                            '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log['desc'] as String,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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

  // --- 5. Attachments Card ---
  Widget _buildAttachmentsCard() {
    return _buildCard(
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Icon(
              Icons.image_outlined,
              size: 32,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'router_error.jpg',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF333333),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '1.2 MB',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Color(0xFF005CAB)),
            onPressed: () {
              // Handle download
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TicketStatus status) {
    Color color;
    switch (status) {
      case TicketStatus.newTicket:
        color = Colors.orange;
        break;
      case TicketStatus.assigned:
        color = Colors.blue;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
