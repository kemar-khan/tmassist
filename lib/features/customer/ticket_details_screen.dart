import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TicketDetailsScreen extends StatelessWidget {
  final String ticketId;

  const TicketDetailsScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Ticket Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF005CAB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .doc(ticketId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Something went wrong:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Ticket not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final title = (data['title'] ?? 'No Title').toString();
          final description = (data['description'] ?? 'No description')
              .toString();
          final category = (data['category'] ?? 'Unknown').toString();
          final address = (data['address'] ?? '-').toString();
          final contactNumber = (data['contactNumber'] ?? '-').toString();
          final customerName = (data['customerName'] ?? '-').toString();
          final customerEmail = (data['customerEmail'] ?? '-').toString();
          final status = (data['status'] ?? 'NEW').toString().toUpperCase();
          final attachmentUrl = (data['attachmentUrl'] ?? '').toString();
          final technicianId = data['technicianId'];
          final technicianName = data['technicianName'];
          final createdAt = data['createdAt'] as Timestamp?;
          final updatedAt = data['updatedAt'] as Timestamp?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle('Ticket Status'),
                _buildStatusCard(status),
                const SizedBox(height: 24),

                _buildSectionTitle('Ticket Info'),
                _buildInfoCard(
                  ticketId: ticketId,
                  title: title,
                  description: description,
                  category: category,
                  address: address,
                  createdAt: createdAt,
                ),
                const SizedBox(height: 24),

                if (technicianId != null) ...[
                  _buildSectionTitle('Technician Info'),
                  _buildTechnicianCard(technicianName.toString()),
                  const SizedBox(height: 24),
                ],

                _buildSectionTitle('Customer Info'),
                _buildCustomerCard(
                  customerName: customerName,
                  customerEmail: customerEmail,
                  contactNumber: contactNumber,
                ),
                const SizedBox(height: 24),

                _buildSectionTitle('Activity Log'),
                _buildActivityLogCard(
                  status: status,
                  createdAt: createdAt,
                  updatedAt: updatedAt,
                  technicianName: technicianName?.toString(),
                ),
                const SizedBox(height: 24),

                _buildSectionTitle('Attachments'),
                _buildAttachmentsCard(attachmentUrl),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
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

  Widget _buildStatusCard(String currentStatus) {
    final steps = ['NEW', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED'];
    final currentIndex = steps.indexOf(currentStatus);

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
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final isCompleted = currentIndex >= index;
            final isCurrent = currentIndex == index;
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
                      _statusLabel(step),
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
          if (currentStatus == 'CLOSED') ...[
            const SizedBox(height: 12),
            Text(
              'This ticket has been closed.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String ticketId,
    required String title,
    required String description,
    required String category,
    required String address,
    required Timestamp? createdAt,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Ticket ID', ticketId),
          _buildDivider(),
          _buildInfoRow('Category', category),
          _buildDivider(),
          _buildInfoRow('Date Submitted', _formatTimestamp(createdAt)),
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

  Widget _buildCustomerCard({
    required String customerName,
    required String customerEmail,
    required String contactNumber,
  }) {
    return _buildCard(
      child: Column(
        children: [
          _buildInfoRow('Customer Name', customerName),
          _buildDivider(),
          _buildInfoRow('Customer Email', customerEmail),
          _buildDivider(),
          _buildInfoRow('Contact Number', contactNumber),
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

  Widget _buildTechnicianCard(String technicianId) {
    return _buildCard(
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFF005CAB),
            child: Icon(Icons.person, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  technicianId,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const Text(
                  'Assigned Technician ID',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLogCard({
    required String status,
    required Timestamp? createdAt,
    required Timestamp? updatedAt,
    String? technicianName,
  }) {
    final List<Map<String, dynamic>> logs = [
      {
        'title': 'Ticket Submitted',
        'date': createdAt?.toDate(),
        'desc': 'Ticket was successfully created by customer.',
      },
    ];

    if (technicianName != null) {
      logs.add({
        'title': 'Technician Assigned',
        'date': updatedAt?.toDate(),
        'desc': 'A technician has been assigned to this ticket.',
      });
    }

    if (status == 'IN_PROGRESS' || status == 'RESOLVED' || status == 'CLOSED') {
      logs.add({
        'title': 'In Progress',
        'date': updatedAt?.toDate(),
        'desc': 'Work on this issue is currently in progress.',
      });
    }

    if (status == 'RESOLVED' || status == 'CLOSED') {
      logs.add({
        'title': 'Resolved',
        'date': updatedAt?.toDate(),
        'desc': 'Issue has been marked as resolved.',
      });
    }

    if (status == 'CLOSED') {
      logs.add({
        'title': 'Closed',
        'date': updatedAt?.toDate(),
        'desc': 'Ticket has been closed.',
      });
    }

    final displayLogs = logs.reversed.toList();

    return _buildCard(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: displayLogs.length,
        itemBuilder: (context, index) {
          final log = displayLogs[index];
          final date = log['date'] as DateTime?;
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
                          Expanded(
                            child: Text(
                              log['title'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isFirst
                                    ? const Color(0xFF333333)
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatShortDate(date),
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

  Widget _buildAttachmentsCard(String attachmentUrl) {
    if (attachmentUrl.trim().isEmpty) {
      return _buildCard(child: const Text('No attachment uploaded'));
    }

    return _buildCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          attachmentUrl,
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'NEW':
        color = Colors.orange;
        break;
      case 'ASSIGNED':
        color = Colors.blue;
        break;
      case 'IN_PROGRESS':
        color = Colors.purple;
        break;
      case 'RESOLVED':
        color = Colors.green;
        break;
      case 'CLOSED':
        color = Colors.grey;
        break;
      default:
        color = Colors.black54;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        _statusLabel(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'NEW':
        return 'New';
      case 'ASSIGNED':
        return 'Assigned';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'RESOLVED':
        return 'Resolved';
      case 'CLOSED':
        return 'Closed';
      default:
        return status;
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';

    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  String _formatShortDate(DateTime? date) {
    if (date == null) return '-';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month $hour:$minute';
  }
}
