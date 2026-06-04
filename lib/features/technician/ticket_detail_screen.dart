import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;

  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  bool _isUpdating = false;

  Future<void> _handleStatusChange(String? newStatus) async {
    if (newStatus == null) return;

    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .update({
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Status updated to ${_displayStatus(newStatus)}"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update status: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            body: const Center(child: CircularProgressIndicator()),
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

        final title = (data['title'] ?? '').toString();
        final description = (data['description'] ?? '').toString();
        final category = (data['category'] ?? 'Hardware Issue').toString();
        final address = (data['address'] ?? '123 Tech Lane, Block B, Floor 4')
            .toString();
        final priority = (data['priority'] ?? 'High').toString();
        final customerName = (data['customerName'] ?? 'Azka').toString();
        final status = (data['status'] ?? 'ASSIGNED').toString().toUpperCase();
        final attachmentUrl = (data['attachmentUrl'] ?? '').toString();
        final createdAt = data['createdAt'] as Timestamp?;
        final updatedAt = data['updatedAt'] as Timestamp?;

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
                _buildUpdateStatusCard(status),
                const SizedBox(height: 24),

                // 2. Action Buttons (Technician Specific)
                _buildSectionTitle('Actions'),
                _buildActionButtons(),
                const SizedBox(height: 24),

                // 3. Ticket Status & Progress Timeline
                _buildSectionTitle('Progress Timeline'),
                _buildStatusTimelineCard(status),
                const SizedBox(height: 24),

                // 4. Ticket Info
                _buildSectionTitle('Ticket Info'),
                _buildInfoCard(
                  ticketId: widget.ticketId,
                  customerName: customerName,
                  category: category,
                  address: address,
                  priority: priority,
                  createdAt: createdAt,
                  title: title,
                  description: description,
                ),
                const SizedBox(height: 24),

                // 5. Activity Log
                _buildSectionTitle('Activity Log'),
                _buildActivityLogCard(
                  status: status,
                  createdAt: createdAt,
                  updatedAt: updatedAt,
                ),
                const SizedBox(height: 24),

                // 6. Attachments
                _buildSectionTitle('Attachments'),
                _buildAttachmentsCard(attachmentUrl),
                const SizedBox(height: 32),
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

  // --- 1. Update Status Card ---
  Widget _buildUpdateStatusCard(String currentStatus) {
    Color statusColor;
    IconData statusIcon;

    switch (currentStatus) {
      case 'ASSIGNED':
        statusColor = Colors.blue;
        statusIcon = Icons.assignment_ind_rounded;
        break;
      case 'IN_PROGRESS':
        statusColor = Colors.purple;
        statusIcon = Icons.engineering_rounded;
        break;
      case 'RESOLVED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'CLOSED':
        statusColor = Colors.grey;
        statusIcon = Icons.lock_rounded;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.info_rounded;
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Current Job Status",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isUpdating)
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // status badge / label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  _displayStatus(currentStatus).toUpperCase(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (currentStatus == 'ASSIGNED')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdating
                    ? null
                    : () => _handleStatusChange('IN_PROGRESS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6600),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'START JOB',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            )
          else if (currentStatus == 'IN_PROGRESS')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdating
                    ? null
                    : () => _handleStatusChange('RESOLVED'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005CAB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'MARK AS RESOLVED',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            )
          else if (currentStatus == 'RESOLVED')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Job completed. Waiting for supervisor to close the ticket.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (currentStatus == 'CLOSED')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This ticket has been closed.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Colors.orange,
                minHeight: 2,
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
  Widget _buildStatusTimelineCard(String currentStatus) {
    final steps = [
      {'title': 'Assigned', 'status': 'ASSIGNED'},
      {'title': 'In Progress', 'status': 'IN_PROGRESS'},
      {'title': 'Completed', 'status': 'RESOLVED'},
    ];

    int currentStepIndex = 0;

    switch (currentStatus) {
      case 'ASSIGNED':
        currentStepIndex = 0;
        break;
      case 'IN_PROGRESS':
        currentStepIndex = 1;
        break;
      case 'RESOLVED':
      case 'CLOSED':
        currentStepIndex = 2;
        break;
      default:
        currentStepIndex = -1; // NEW or unknown
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
  Widget _buildInfoCard({
    required String ticketId,
    required String customerName,
    required String category,
    required String address,
    required String priority,
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
          _buildInfoRow(
            'Priority',
            priority,
            valueColor: const Color(0xFFFF6600),
          ),
          _buildDivider(),
          _buildInfoRow('Submitted', _formatFullDate(createdAt)),
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

  Widget _buildDivider() {
    return Divider(color: Colors.grey[100], height: 16);
  }

  // --- 5. Activity Log Card ---
  Widget _buildActivityLogCard({
    required String status,
    required Timestamp? createdAt,
    required Timestamp? updatedAt,
  }) {
    final createdDate = createdAt?.toDate();
    final updatedDate = updatedAt?.toDate();

    final logs = [
      {
        'title': 'Ticket Created',
        'date': createdDate,
        'desc': 'System logged ticket.',
      },
      if (status != 'NEW')
        {
          'title': 'Assigned',
          'date': updatedDate != null
              ? updatedDate.subtract(const Duration(hours: 1))
              : null,
          'desc': 'Assigned to your queue.',
        },
      if (status == 'IN_PROGRESS' || status == 'RESOLVED' || status == 'CLOSED')
        {
          'title': 'In Progress',
          'date': updatedDate != null
              ? updatedDate.subtract(const Duration(minutes: 15))
              : null,
          'desc': 'You started working.',
        },
      if (status == 'RESOLVED' || status == 'CLOSED')
        {
          'title': 'Resolved',
          'date': updatedDate,
          'desc': 'You marked the job as resolved.',
        },
    ].reversed.toList();

    return _buildCard(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          final date = log['date'] as DateTime?;
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
                          Expanded(
                            child: Text(
                              log['title'] as String,
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
                            _formatLogDate(date),
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

  List<String> _allowedStatuses() {
    return ['ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];
  }

  String _displayStatus(String status) {
    switch (status) {
      case 'ASSIGNED':
        return 'Assigned';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'RESOLVED':
        return 'Resolved';
      case 'CLOSED':
        return 'Closed';
      case 'NEW':
        return 'New';
      default:
        return status;
    }
  }

  String _formatFullDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatLogDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
