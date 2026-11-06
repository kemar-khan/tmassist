import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/services/ticket_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/cancelled_status.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_row.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/section_card.dart';
import '../../widgets/status_badge.dart';

class TicketDetailsScreen extends StatelessWidget {
  final String ticketId;

  const TicketDetailsScreen({super.key, required this.ticketId});

  Future<void> _confirmAndCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Ticket'),
        content: const Text('Cancel this ticket? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Ticket'),
          ),
          OutlinedButton(
            style: AppButtonStyles.destructive,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel Ticket'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await TicketService().cancelTicket(ticketId);
      if (!context.mounted) return;
      showAppSnack(context, 'Ticket cancelled', kind: SnackKind.success);
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      showAppSnack(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        kind: SnackKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket Details')),
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
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Text(
                  'Something went wrong:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.cancelledFg),
                ),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'Ticket not found.',
            );
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

          return SafeArea(
            // The bottom inset is added to the scroll padding below.
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s4,
                AppSpacing.s4,
                MediaQuery.paddingOf(context).bottom + AppSpacing.s6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusCard(context, status),
                  const SizedBox(height: AppSpacing.s4),
                  _buildInfoCard(
                    ticketId: ticketId,
                    title: title,
                    description: description,
                    category: category,
                    address: address,
                    createdAt: createdAt,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  if (technicianId != null) ...[
                    TechnicianInfoCard(technicianId: technicianId.toString()),
                    const SizedBox(height: AppSpacing.s4),
                  ],
                  _buildCustomerCard(
                    customerName: customerName,
                    customerEmail: customerEmail,
                    contactNumber: contactNumber,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  _buildActivityLogCard(
                    status: status,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    technicianName: technicianName?.toString(),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  _buildAttachmentsCard(attachmentUrl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, String currentStatus) {
    final canCancel = currentStatus == 'NEW' || currentStatus == 'ASSIGNED';

    return SectionCard(
      title: 'Ticket Status',
      trailing: StatusBadge(status: currentStatus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VerticalStatusTimeline(status: currentStatus),
          if (currentStatus == 'CLOSED') ...[
            const SizedBox(height: AppSpacing.s3),
            Text(
              'This ticket has been closed.',
              style: AppText.caption.copyWith(color: AppColors.inkMuted),
            ),
          ],
          if (currentStatus == CancelledStatus.value)
            Container(
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: AppColors.cancelledBg,
                borderRadius: AppRadius.brMd,
              ),
              child: Text(
                'This ticket was cancelled.',
                style: AppText.bodyStrong.copyWith(
                  color: AppColors.cancelledFg,
                ),
              ),
            ),
          if (canCancel) ...[
            const SizedBox(height: AppSpacing.s4),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.s4),
            OutlinedButton.icon(
              onPressed: () => _confirmAndCancel(context),
              style: AppButtonStyles.destructive,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Ticket'),
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
    return SectionCard(
      title: 'Ticket Info',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(label: 'Ticket ID', value: ticketId, showDivider: true),
          InfoRow(label: 'Category', value: category, showDivider: true),
          InfoRow(
            label: 'Date Submitted',
            value: _formatTimestamp(createdAt),
            showDivider: true,
          ),
          InfoRow(label: 'Address', value: address, showDivider: true),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Issue Description',
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  title,
                  style: AppText.heading.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  description,
                  style: AppText.body.copyWith(color: AppColors.inkMuted),
                ),
              ],
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
    return SectionCard(
      title: 'Customer Info',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(
            label: 'Customer Name',
            value: customerName,
            showDivider: true,
          ),
          InfoRow(
            label: 'Customer Email',
            value: customerEmail,
            showDivider: true,
          ),
          InfoRow(label: 'Contact Number', value: contactNumber),
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

    if (status == CancelledStatus.value) {
      logs.add({
        'title': CancelledStatus.label,
        'date': updatedAt?.toDate(),
        'desc': 'This ticket was cancelled.',
      });
    }

    final displayLogs = logs.reversed.toList();

    return SectionCard(
      title: 'Activity Log',
      child: Column(
        children: [
          for (var index = 0; index < displayLogs.length; index++)
            _ActivityEntry(
              title: displayLogs[index]['title'] as String,
              description: displayLogs[index]['desc'] as String,
              timestamp: _formatShortDate(
                displayLogs[index]['date'] as DateTime?,
              ),
              isLatest: index == 0,
              isLast: index == displayLogs.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard(String attachmentUrl) {
    if (attachmentUrl.trim().isEmpty) {
      return SectionCard(
        title: 'Attachments',
        child: Text(
          'No attachment uploaded',
          style: AppText.body.copyWith(color: AppColors.inkMuted),
        ),
      );
    }

    return SectionCard(
      title: 'Attachments',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: AppRadius.brMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Image.network(
          attachmentUrl,
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
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

class TechnicianInfoCard extends StatelessWidget {
  final String technicianId;

  const TechnicianInfoCard({super.key, required this.technicianId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(technicianId)
          .get(),
      builder: (context, snapshot) {
        String name = 'Loading...';
        String specialization = '';

        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            name = data['fullName']?.toString() ?? 'Unknown Technician';
            specialization = data['specialization']?.toString() ?? '';
          } else {
            name = 'Unknown Technician';
          }
        }

        return SectionCard(
          title: 'Technician Info',
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppText.heading.copyWith(color: AppColors.ink),
                    ),
                    if (specialization.isNotEmpty)
                      Text(
                        specialization,
                        style: AppText.caption.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    Text(
                      'Assigned Technician',
                      style: AppText.caption.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: AppSpacing.s1,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: AppRadius.brPill,
                ),
                child: Text(
                  'AUTO ASSIGNED',
                  style: AppText.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One line of the activity log: a dot joined to the next by a thin line, the
/// entry text, and its time underneath.
class _ActivityEntry extends StatelessWidget {
  final String title;
  final String description;
  final String timestamp;
  final bool isLatest;
  final bool isLast;

  const _ActivityEntry({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.isLatest,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isLatest ? AppColors.primary : AppColors.borderStrong;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 10,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s1),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1, color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.bodyStrong.copyWith(color: AppColors.ink),
                  ),
                  Text(
                    description,
                    style: AppText.body.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    timestamp,
                    style: AppText.caption.copyWith(color: AppColors.inkFaint),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
