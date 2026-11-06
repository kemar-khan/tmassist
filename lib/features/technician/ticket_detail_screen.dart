import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/cancelled_status.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_row.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/section_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/status_style.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;

  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  bool _isUpdating = false;

  // Created once: a stream made inside build() would re-subscribe (and flash
  // the loading screen) every time START JOB calls setState.
  late final Stream<DocumentSnapshot> _ticketStream;

  @override
  void initState() {
    super.initState();
    _ticketStream = FirebaseFirestore.instance
        .collection('tickets')
        .doc(widget.ticketId)
        .snapshots();
  }

  /// ASSIGNED -> IN_PROGRESS. Resolving a ticket is done only by submitting a
  /// report (ReportService.saveReport), never from this screen.
  Future<void> _startJob() async {
    if (_isUpdating) return;

    const newStatus = 'IN_PROGRESS';

    setState(() => _isUpdating = true);

    try {
      final ref = FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId);

      // A customer may have cancelled while this screen was open; never
      // overwrite CANCELLED with IN_PROGRESS.
      final current = await ref.get();
      final currentStatus = (current.data()?['status'] ?? '')
          .toString()
          .toUpperCase();
      if (currentStatus != 'ASSIGNED') {
        if (mounted) {
          setState(() => _isUpdating = false);
          showAppSnack(
            context,
            CancelledStatus.isCancelled(currentStatus)
                ? 'This ticket was cancelled by the customer.'
                : 'This ticket can no longer be started.',
          );
        }
        return;
      }

      await ref.update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isUpdating = false);
        showAppSnack(
          context,
          'Status updated to In Progress',
          kind: SnackKind.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        showAppSnack(
          context,
          'Failed to update status: $e',
          kind: SnackKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ticketStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Job Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: EmptyState(
              icon: Icons.error_outline_rounded,
              title: "Error: ${snapshot.error}",
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: const EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: "Ticket not found",
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        DateTime? time(Object? value) =>
            value is Timestamp ? value.toDate() : null;

        return TechJobDetailView(
          ticketId: widget.ticketId,
          status: (data['status'] ?? 'ASSIGNED').toString().toUpperCase(),
          title: (data['title'] ?? '').toString(),
          description: (data['description'] ?? '').toString(),
          category: (data['category'] ?? '').toString(),
          address: (data['address'] ?? '').toString(),
          customerName: (data['customerName'] ?? '').toString(),
          attachmentUrl: (data['attachmentUrl'] ?? '').toString(),
          createdAt: time(data['createdAt']),
          updatedAt: time(data['updatedAt']),
          assignedAt: time(data['assignedAt']),
          checklistDone: List<bool>.from(
            (data['checklistDone'] ?? []).map((e) => e == true),
          ),
          isUpdating: _isUpdating,
          onStartJob: _startJob,
          onOpenChecklist: () => Navigator.pushNamed(
            context,
            '/tech/checklist',
            arguments: widget.ticketId,
          ),
          onOpenReport: () => Navigator.pushNamed(
            context,
            '/tech/report',
            arguments: widget.ticketId,
          ),
        );
      },
    );
  }
}

/// The technician's job page. Separate from [TicketDetailScreen] so it can be
/// built without Firebase; the screen loads the data and starts the job.
class TechJobDetailView extends StatelessWidget {
  final String ticketId;

  /// The stored status in capitals, for example `IN_PROGRESS`.
  final String status;
  final String title;
  final String description;

  /// Empty when the ticket has none; the matching row is then hidden.
  final String category;
  final String address;
  final String customerName;
  final String attachmentUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// When the ticket was assigned, if the ticket records it.
  final DateTime? assignedAt;
  final List<bool> checklistDone;

  /// True while START JOB is running: the button shows a spinner and ignores
  /// taps, and the content stays on screen.
  final bool isUpdating;
  final VoidCallback onStartJob;
  final VoidCallback onOpenChecklist;
  final VoidCallback onOpenReport;

  const TechJobDetailView({
    super.key,
    required this.ticketId,
    required this.status,
    required this.title,
    required this.description,
    required this.category,
    required this.address,
    required this.customerName,
    required this.attachmentUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.assignedAt,
    required this.checklistDone,
    required this.isUpdating,
    required this.onStartJob,
    required this.onOpenChecklist,
    required this.onOpenReport,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s4,
            AppSpacing.s4,
            MediaQuery.paddingOf(context).bottom + AppSpacing.s4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(),
              if (status != CancelledStatus.value) ...[
                const SizedBox(height: AppSpacing.s4),
                _buildActionsCard(),
                const SizedBox(height: AppSpacing.s4),
                SectionCard(
                  title: 'Progress Timeline',
                  child: VerticalStatusTimeline(
                    status: status,
                    timestamps: _timelineTimes(),
                    withClosed: true,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s4),
              _buildInfoCard(),
              const SizedBox(height: AppSpacing.s4),
              _buildActivityLogCard(),
              const SizedBox(height: AppSpacing.s4),
              _buildAttachmentsCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ status card

  Widget _buildStatusCard() {
    final style = statusStyle(status);

    final String? hint;
    final IconData hintIcon;
    switch (status) {
      case 'IN_PROGRESS':
        hint =
            'Complete the checklist, then submit your report to resolve this ticket.';
        hintIcon = Icons.info_outline;
      case 'RESOLVED':
        hint = 'Job completed. Waiting for supervisor to close the ticket.';
        hintIcon = Icons.check_circle_outline;
      case 'CLOSED':
        hint = 'This ticket has been closed.';
        hintIcon = Icons.lock_outline;
      case CancelledStatus.value:
        hint =
            'This ticket was cancelled by the customer. No further action is needed.';
        hintIcon = Icons.cancel_outlined;
      default:
        hint = null;
        hintIcon = Icons.info_outline;
    }

    return SectionCard(
      title: 'Update Job Status',
      trailing: StatusBadge(status: status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Current Job Status',
            style: AppText.body.copyWith(color: AppColors.inkMuted),
          ),
          if (status == 'ASSIGNED') ...[
            const SizedBox(height: AppSpacing.s4),
            ElevatedButton.icon(
              // Taps are ignored while the update runs; the button keeps its
              // look so the spinner stays readable.
              onPressed: () {
                if (!isUpdating) onStartJob();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Job'),
            ),
          ] else if (hint != null) ...[
            const SizedBox(height: AppSpacing.s3),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: style.bg,
                borderRadius: AppRadius.brMd,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(hintIcon, color: style.fg, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Text(
                      hint,
                      style: AppText.body.copyWith(
                        color: style.fg,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ----------------------------------------------------------- actions card

  Widget _buildActionsCard() {
    final lower = status.toLowerCase();
    final isInProgress = lower == 'in_progress';
    final isResolved = lower == 'resolved';
    final isClosed = lower == 'closed';
    final isChecklistDone =
        checklistDone.isNotEmpty && checklistDone.every((d) => d);

    final checklistEnabled = isInProgress;
    final reportEnabled =
        isInProgress && isChecklistDone || isResolved || isClosed;

    final String? helper;
    if (status == 'ASSIGNED') {
      helper = 'Start the job to unlock the checklist and the report.';
    } else if (isInProgress && !reportEnabled) {
      helper = 'Complete the checklist to unlock the report.';
    } else {
      helper = null;
    }

    final disabledBackground = AppColors.border;

    return SectionCard(
      title: 'Actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: checklistEnabled ? onOpenChecklist : null,
                  style:
                      OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: AppColors.surfaceCard,
                        foregroundColor: AppColors.primary,
                        disabledBackgroundColor: disabledBackground,
                        disabledForegroundColor: AppColors.inkMuted,
                        textStyle: AppText.bodyStrong,
                      ).copyWith(
                        side: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.disabled)
                              ? BorderSide.none
                              : const BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                        ),
                      ),
                  icon: const Icon(Icons.checklist_rtl_rounded, size: 20),
                  label: const Text('Checklist'),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: reportEnabled ? onOpenReport : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    disabledBackgroundColor: disabledBackground,
                    disabledForegroundColor: AppColors.inkMuted,
                    textStyle: AppText.bodyStrong,
                  ),
                  icon: const Icon(Icons.description_outlined, size: 20),
                  label: const Text('Report'),
                ),
              ),
            ],
          ),
          if (helper != null) ...[
            const SizedBox(height: AppSpacing.s3),
            Text(
              helper,
              style: AppText.caption.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------- info card

  Widget _buildInfoCard() {
    final rows = <Widget>[
      if (customerName.isNotEmpty)
        InfoRow(label: 'Customer Name', value: customerName, showDivider: true),
      InfoRow(
        label: 'Ticket ID',
        value: '#${ticketId.toUpperCase()}',
        showDivider: true,
      ),
      if (category.isNotEmpty)
        InfoRow(label: 'Category', value: category, showDivider: true),
      if (createdAt != null)
        InfoRow(
          label: 'Submitted',
          value: _formatDate(createdAt),
          showDivider: true,
        ),
      if (address.isNotEmpty)
        InfoRow(label: 'Address', value: address, showDivider: true),
    ];

    return SectionCard(
      title: 'Ticket Info',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...rows,
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
                  style: AppText.bodyStrong.copyWith(color: AppColors.ink),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    description,
                    style: AppText.body.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- activity log

  /// The time a step was reached, only where the ticket really records it:
  /// the assignment time when stored, and the last update for the step the
  /// ticket is on now.
  DateTime? _assignedTime() =>
      assignedAt ?? (status == 'ASSIGNED' ? updatedAt : null);

  DateTime? _inProgressTime() => status == 'IN_PROGRESS' ? updatedAt : null;

  DateTime? _resolvedTime() => status == 'RESOLVED' ? updatedAt : null;

  Map<String, String> _timelineTimes() {
    final times = <String, DateTime?>{
      'ASSIGNED': _assignedTime(),
      'IN_PROGRESS': _inProgressTime(),
      'RESOLVED': _resolvedTime(),
      'CLOSED': status == 'CLOSED' ? updatedAt : null,
    };
    return {
      for (final e in times.entries)
        if (e.value != null) e.key: _formatLogDate(e.value),
    };
  }

  Widget _buildActivityLogCard() {
    final logs = <({String title, String desc, DateTime? date})>[
      (title: 'Ticket Created', desc: 'System logged ticket.', date: createdAt),
      if (status != 'NEW')
        (
          title: 'Assigned',
          desc: 'Assigned to your queue.',
          date: _assignedTime(),
        ),
      if (status == 'IN_PROGRESS' || status == 'RESOLVED' || status == 'CLOSED')
        (
          title: 'In Progress',
          desc: 'You started working.',
          date: _inProgressTime(),
        ),
      if (status == 'RESOLVED' || status == 'CLOSED')
        (
          title: 'Resolved',
          desc: 'You marked the job as resolved.',
          date: _resolvedTime(),
        ),
      if (status == CancelledStatus.value)
        (
          title: CancelledStatus.label,
          desc: 'The customer cancelled this ticket.',
          date: updatedAt,
        ),
    ].reversed.toList();

    return SectionCard(
      title: 'Activity Log',
      child: Column(
        children: [
          for (var i = 0; i < logs.length; i++)
            _LogEntry(
              title: logs[i].title,
              description: logs[i].desc,
              time: logs[i].date == null ? null : _formatLogDate(logs[i].date),
              isLatest: i == 0,
              isLast: i == logs.length - 1,
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ attachments

  Widget _buildAttachmentsCard() {
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
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const SizedBox(
                  height: 250,
                  child: Center(child: CircularProgressIndicator()),
                ),
          errorBuilder: (context, error, stackTrace) => const SizedBox(
            height: 250,
            child: Center(
              child: Icon(Icons.broken_image, color: AppColors.inkFaint),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }

  static String _formatLogDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// One line of the activity log: a small dot joined to the next by a thin
/// line, the entry text, its description and, when known, the time.
class _LogEntry extends StatelessWidget {
  final String title;
  final String description;
  final String? time;
  final bool isLatest;
  final bool isLast;

  const _LogEntry({
    required this.title,
    required this.description,
    required this.time,
    required this.isLatest,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 8,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s2),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isLatest
                          ? AppColors.primary
                          : AppColors.borderStrong,
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
                  if (time != null)
                    Text(
                      time!,
                      style: AppText.caption.copyWith(
                        color: AppColors.inkFaint,
                      ),
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
