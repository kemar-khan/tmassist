import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/services/report_service.dart';
import '../../core/services/report_pdf_service.dart';
import '../../core/theme/app_tokens.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:signature/signature.dart';
import '../../utils/cancelled_status.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_row.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/section_card.dart';
import '../../widgets/status_style.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/stream_error.dart';

class SupervisorTicketDetailScreen extends StatefulWidget {
  final String ticketId;

  const SupervisorTicketDetailScreen({super.key, required this.ticketId});

  @override
  State<SupervisorTicketDetailScreen> createState() =>
      _SupervisorTicketDetailScreenState();
}

class _SupervisorTicketDetailScreenState
    extends State<SupervisorTicketDetailScreen> {
  final ReportService _reportService = ReportService();
  final TextEditingController _commentController = TextEditingController();
  bool _isSavingComment = false;
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _isSigning = false;

  // Created once: a stream made inside build() would re-subscribe (and flash
  // the spinner) on every setState.
  late Stream<DocumentSnapshot> _ticketStream;

  // The last report that loaded, shown while a refresh is in flight.
  Map<String, dynamic>? _lastReport;

  @override
  void initState() {
    super.initState();
    _createStream();
  }

  // Also used by "Try Again", which needs a fresh subscription.
  void _createStream() {
    _ticketStream = FirebaseFirestore.instance
        .collection('tickets')
        .doc(widget.ticketId)
        .snapshots();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _sigController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOff() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      showAppSnack(context, 'Add a comment before signing');
      return;
    }
    if (_sigController.isEmpty) {
      showAppSnack(context, 'Please sign in the box');
      return;
    }

    setState(() => _isSigning = true);
    try {
      final bytes = await _sigController.toPngBytes();
      if (bytes == null) throw Exception('Could not read signature');

      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      var name = 'Supervisor';
      if (uid != null) {
        final u = await db.collection('users').doc(uid).get();
        name = (u.data()?['fullName'] ?? name).toString();
      }

      final batch = db.batch();
      batch.update(db.collection('reports').doc(widget.ticketId), {
        'supervisorComments': comment,
        'supervisorSignature': base64Encode(bytes),
        'supervisorName': name,
        'signedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(db.collection('tickets').doc(widget.ticketId), {
        'status': 'CLOSED',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      if (!mounted) return;
      showAppSnack(
        context,
        'Report signed and ticket closed',
        kind: SnackKind.success,
      );
    } catch (e, st) {
      if (!mounted) return;
      showAppSnack(
        context,
        friendlyError(
          e,
          fallback: 'Could not sign off the report. Please try again.',
          stackTrace: st,
        ),
        kind: SnackKind.error,
      );
    } finally {
      if (mounted) setState(() => _isSigning = false);
    }
  }

  Future<void> _handleSaveComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSavingComment = true);

    try {
      await _reportService.addSupervisorComment(
        ticketId: widget.ticketId,
        comment: _commentController.text.trim(),
      );

      if (!mounted) return;

      showAppSnack(
        context,
        'Comment saved successfully',
        kind: SnackKind.success,
      );
    } catch (e, st) {
      if (!mounted) return;
      showAppSnack(
        context,
        friendlyError(
          e,
          fallback: 'Could not save the comment. Please try again.',
          stackTrace: st,
        ),
        kind: SnackKind.error,
      );
    } finally {
      if (mounted) setState(() => _isSavingComment = false);
    }
  }

  Future<void> _exportPdf(Map<String, dynamic> report) async {
    try {
      await ReportPdfService.export(ticketId: widget.ticketId, report: report);
    } catch (e, st) {
      if (!mounted) return;
      showAppSnack(
        context,
        friendlyError(
          e,
          fallback: 'Could not export the PDF. Please try again.',
          stackTrace: st,
        ),
        kind: SnackKind.error,
      );
    }
  }

  Widget _messageScaffold(String title, Widget body) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ticketStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return _messageScaffold(
            'Supervisor View',
            const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _messageScaffold(
            "Error",
            StreamError(
              error: snapshot.error,
              onRetry: () => setState(_createStream),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _messageScaffold(
            "Error",
            const EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: "Ticket not found",
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        final status = (data['status'] ?? 'NEW').toString().toUpperCase();
        final createdAt = data['createdAt'] as Timestamp?;
        final updatedAt = data['updatedAt'] as Timestamp?;

        // Report section: loaded once per rebuild, as before.
        return FutureBuilder<Map<String, dynamic>?>(
          future: _reportService.getReport(widget.ticketId),
          builder: (context, reportSnapshot) {
            final waiting =
                reportSnapshot.connectionState == ConnectionState.waiting;
            if (!waiting) _lastReport = reportSnapshot.data;
            final report = waiting ? _lastReport : reportSnapshot.data;

            return SupervisorTicketDetailView(
              ticketId: widget.ticketId,
              status: status,
              title: (data['title'] ?? 'No Title').toString(),
              description: (data['description'] ?? '').toString(),
              category: (data['category'] ?? '-').toString(),
              address: (data['address'] ?? '-').toString(),
              customerName: (data['customerName'] ?? '-').toString(),
              technicianName: (data['technicianName'] ?? '').toString(),
              technicianId: (data['technicianId'] ?? '').toString(),
              assignmentType: (data['assignmentType'] ?? '').toString(),
              assignmentNote: (data['assignmentNote'] ?? '').toString(),
              createdAt: createdAt?.toDate(),
              updatedAt: updatedAt?.toDate(),
              report: report,
              reportLoading: waiting && _lastReport == null,
              commentController: _commentController,
              signatureController: _sigController,
              isSigning: _isSigning,
              isSavingComment: _isSavingComment,
              onAssign: () {
                Navigator.pushNamed(
                  context,
                  '/supervisor/assign',
                  arguments: widget.ticketId,
                );
              },
              onSaveComment: _handleSaveComment,
              onSignOff: _handleSignOff,
              onExport: () {
                if (report != null) _exportPdf(report);
              },
            );
          },
        );
      },
    );
  }
}

/// The supervisor's ticket page. Separate from
/// [SupervisorTicketDetailScreen] so it can be built without Firebase; the
/// screen loads the data and does the saving.
class SupervisorTicketDetailView extends StatelessWidget {
  final String ticketId;
  final String status;
  final String title;
  final String description;
  final String category;
  final String address;
  final String customerName;
  final String technicianName;
  final String technicianId;

  /// 'AUTO' for an automatic assignment.
  final String assignmentType;
  final String assignmentNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The technician's service report, or null when there is none (yet).
  final Map<String, dynamic>? report;
  final bool reportLoading;

  final TextEditingController commentController;
  final SignatureController signatureController;
  final bool isSigning;
  final bool isSavingComment;

  /// Opens the assign screen (NEW: assign; ASSIGNED: reassign).
  final VoidCallback onAssign;
  final VoidCallback onSaveComment;
  final VoidCallback onSignOff;
  final VoidCallback onExport;

  const SupervisorTicketDetailView({
    super.key,
    required this.ticketId,
    required this.status,
    required this.title,
    required this.description,
    required this.category,
    required this.address,
    required this.customerName,
    required this.technicianName,
    required this.technicianId,
    required this.assignmentType,
    required this.assignmentNote,
    required this.createdAt,
    required this.updatedAt,
    required this.report,
    required this.reportLoading,
    required this.commentController,
    required this.signatureController,
    required this.isSigning,
    required this.isSavingComment,
    required this.onAssign,
    required this.onSaveComment,
    required this.onSignOff,
    required this.onExport,
  });

  bool get _hasTechnician =>
      technicianId.trim().isNotEmpty || technicianName.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final report = this.report;

    return Scaffold(
      appBar: AppBar(title: const Text('Supervisor View')),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s4,
            AppSpacing.s4,
            MediaQuery.paddingOf(context).bottom + AppSpacing.s8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StateCard(status: status, onAssign: onAssign),
              if (status != CancelledStatus.value) ...[
                const SizedBox(height: AppSpacing.s4),
                SectionCard(
                  title: 'Ticket Progress',
                  child: VerticalStatusTimeline(
                    status: status,
                    fullLifecycle: true,
                  ),
                ),
              ],
              if (_hasTechnician) ...[
                const SizedBox(height: AppSpacing.s4),
                _buildTechnicianCard(),
              ],
              const SizedBox(height: AppSpacing.s4),
              _buildInfoCard(),
              const SizedBox(height: AppSpacing.s4),
              _buildActivityLogCard(),
              if (reportLoading) ...[
                const SizedBox(height: AppSpacing.s4),
                const Center(child: CircularProgressIndicator()),
              ] else if (report != null) ...[
                const SizedBox(height: AppSpacing.s4),
                _buildReportCard(context, report),
                const SizedBox(height: AppSpacing.s4),
                ..._buildSignOff(context, report),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- cards

  Widget _buildTechnicianCard() {
    return SectionCard(
      title: 'Assigned Technician',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.engineering,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  technicianName.isNotEmpty ? technicianName : technicianId,
                  style: AppText.heading.copyWith(color: AppColors.ink),
                ),
              ),
              if (assignmentType == 'AUTO') ...[
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
                    'AUTO',
                    style: AppText.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (assignmentNote.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s3),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: AppColors.surfaceBg,
                borderRadius: AppRadius.brMd,
              ),
              child: Text(
                assignmentNote,
                style: AppText.body.copyWith(color: AppColors.inkMuted),
              ),
            ),
          ],
          if (status == 'ASSIGNED') ...[
            const SizedBox(height: AppSpacing.s3),
            OutlinedButton.icon(
              onPressed: onAssign,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Reassign Technician'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return SectionCard(
      title: 'Ticket Info',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(
            label: 'Customer Name',
            value: customerName,
            showDivider: true,
          ),
          InfoRow(
            label: 'Ticket ID',
            value: '#${ticketId.toUpperCase()}',
            showDivider: true,
          ),
          InfoRow(label: 'Category', value: category, showDivider: true),
          InfoRow(
            label: 'Submitted',
            value: _formatDate(createdAt),
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
                  style: AppText.bodyStrong.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: AppSpacing.s1),
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

  Widget _buildActivityLogCard() {
    final logs = [
      {
        'title': 'Ticket Created',
        'date': createdAt,
        'desc': 'Logged in system.',
      },
      if (_hasTechnician)
        {
          'title': 'Assigned',
          'date': updatedAt,
          'desc': technicianName.trim().isNotEmpty
              ? 'Assigned to $technicianName.'
              : 'Assigned to technician.',
        },
      if (status == 'IN_PROGRESS' || status == 'RESOLVED' || status == 'CLOSED')
        {
          'title': 'Work Started',
          'date': updatedAt,
          'desc': 'Technician is on site.',
        },
      if (status == 'RESOLVED' || status == 'CLOSED')
        {
          'title': 'Resolved',
          'date': updatedAt,
          'desc': 'Technician marked as resolved.',
        },
      if (status == 'CLOSED')
        {
          'title': 'Closed',
          'date': updatedAt,
          'desc': 'Supervisor closed the ticket.',
        },
      if (status == CancelledStatus.value)
        {
          'title': CancelledStatus.label,
          'date': updatedAt,
          'desc': 'The customer cancelled this ticket.',
        },
    ].reversed.toList();

    return SectionCard(
      title: 'Activity Log',
      child: Column(
        children: [
          for (var i = 0; i < logs.length; i++)
            _LogEntry(
              title: logs[i]['title'] as String,
              description: logs[i]['desc'] as String,
              timestamp: _formatShortDate(logs[i]['date'] as DateTime?),
              isLatest: i == 0,
              isLast: i == logs.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> report) {
    final proofUrl = (report['proofUrl'] ?? '').toString();
    final techSignature = _decodeSignature(
      (report['technicianSignature'] ?? '').toString(),
    );

    return SectionCard(
      title: 'Service Report',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReportText(label: 'Issue Summary', value: report['issueSummary']),
          _ReportText(label: 'Steps Taken', value: report['stepsTaken']),
          _ReportText(
            label: 'Resolution Summary',
            value: report['resolutionSummary'],
          ),
          _ReportText(
            label: 'Technician Notes',
            value: (report['technicianNotes'] ?? '').toString().isEmpty
                ? 'No additional notes.'
                : report['technicianNotes'],
            isLast: proofUrl.isEmpty && techSignature == null,
          ),
          if (proofUrl.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.s3),
            Text(
              'Proof of Completion',
              style: AppText.bodyStrong.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.s2),
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(child: Image.network(proofUrl)),
                ),
              ),
              child: Container(
                height: 200,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.brMd,
                  border: Border.all(color: AppColors.border),
                ),
                child: Image.network(
                  proofUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image, color: AppColors.inkFaint),
                  ),
                ),
              ),
            ),
            SizedBox(height: techSignature == null ? 0 : AppSpacing.s4),
          ],
          // Older reports have no technician signature: show nothing.
          if (techSignature != null) ...[
            if (proofUrl.isEmpty)
              const Divider(height: 1, color: AppColors.border),
            if (proofUrl.isEmpty) const SizedBox(height: AppSpacing.s3),
            Text(
              'Technician Sign-off',
              style: AppText.bodyStrong.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.s2),
            _SignatureImage(bytes: techSignature),
            const SizedBox(height: AppSpacing.s2),
            Text(
              '${report['technicianName'] ?? 'Technician'}  •  '
              '${_formatDate(report['technicianSignedAt'] is Timestamp ? (report['technicianSignedAt'] as Timestamp).toDate() : null)}',
              style: AppText.caption.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// Cards for the supervisor's part of the report: comments, sign-off pad
  /// or the signed result, and the PDF export.
  List<Widget> _buildSignOff(
    BuildContext context,
    Map<String, dynamic> report,
  ) {
    final sigB64 = (report['supervisorSignature'] ?? '').toString();
    final signed = sigB64.isNotEmpty;
    final canSign = !signed && status == 'RESOLVED';

    final exportButton = canSign
        ? OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Export Report as PDF'),
          )
        : ElevatedButton.icon(
            onPressed: onExport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Export Report as PDF'),
          );

    if (signed) {
      final signedAt = report['signedAt'] as Timestamp?;
      return [
        SectionCard(
          title: 'Supervisor Sign-off',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _commentSection(report, locked: true),
              const SizedBox(height: AppSpacing.s4),
              _SignatureImage(bytes: base64Decode(sigB64)),
              const SizedBox(height: AppSpacing.s2),
              Text(
                '${report['supervisorName'] ?? 'Supervisor'}  •  ${_formatDate(signedAt?.toDate())}',
                style: AppText.caption.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        exportButton,
      ];
    }

    if (canSign) {
      return [
        SectionCard(
          title: 'Sign Off & Close',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sign below to approve this report. The ticket will be closed.',
                style: AppText.body.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.s4),
              _commentSection(report, locked: false),
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Supervisor Signature',
                      style: AppText.bodyStrong.copyWith(color: AppColors.ink),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Clear signature',
                    excludeSemantics: true,
                    child: TextButton(
                      onPressed: isSigning
                          ? null
                          : () => signatureController.clear(),
                      child: const Text('Clear'),
                    ),
                  ),
                ],
              ),
              _SignaturePad(controller: signatureController),
              const SizedBox(height: AppSpacing.s4),
              ElevatedButton.icon(
                onPressed: isSigning ? null : onSignOff,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: isSigning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.check),
                label: const Text('Sign Off & Close'),
              ),
              const SizedBox(height: AppSpacing.s3),
              exportButton,
            ],
          ),
        ),
      ];
    }

    // Not signed and not waiting for sign-off: the comments, then (when the
    // ticket was closed before sign-off existed) the note, then the export.
    return [
      SectionCard(
        title: 'Supervisor Comments',
        child: _commentSection(report, locked: false, showLabel: false),
      ),
      if (status == 'CLOSED') ...[
        const SizedBox(height: AppSpacing.s4),
        SectionCard(
          child: Row(
            children: [
              const ExcludeSemantics(
                child: Icon(Icons.info_outline, color: AppColors.inkFaint),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  'Closed without sign-off',
                  style: AppText.bodyStrong.copyWith(color: AppColors.ink),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.s4),
      exportButton,
    ];
  }

  Widget _commentSection(
    Map<String, dynamic> report, {
    required bool locked,
    bool showLabel = true,
  }) {
    final existingComment = (report['supervisorComments'] ?? '').toString();

    if (commentController.text.isEmpty && existingComment.isNotEmpty) {
      commentController.text = existingComment;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLabel) ...[
          Text(
            'Supervisor Comments',
            style: AppText.bodyStrong.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: AppSpacing.s2),
        ],
        TextField(
          controller: commentController,
          readOnly: locked,
          maxLines: 4,
          style: AppText.body.copyWith(color: AppColors.ink),
          decoration: const InputDecoration(
            hintText: 'Add your comments or feedback on this report...',
          ),
        ),
        if (!locked) ...[
          const SizedBox(height: AppSpacing.s3),
          OutlinedButton(
            onPressed: isSavingComment ? null : onSaveComment,
            child: isSavingComment
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Comment'),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------- helpers

  /// Returns null for a missing or invalid base64 signature.
  static Uint8List? _decodeSignature(String b64) {
    if (b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }

  static String _formatShortDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}';
  }
}

/// The first card: what state the ticket is in. NEW is a white card with the
/// Assign Technician button; every other state is a card in its status colours.
class _StateCard extends StatelessWidget {
  final String status;
  final VoidCallback onAssign;

  const _StateCard({required this.status, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    final style = statusStyle(status);

    final String helper;
    final IconData icon;
    switch (status) {
      case 'NEW':
        helper = 'Ticket is Unassigned';
        icon = Icons.schedule;
      case 'RESOLVED':
        helper = 'Resolved. Review the report and sign off to close it.';
        icon = Icons.check_circle_outline;
      case 'CLOSED':
        helper = 'This ticket is Closed';
        icon = Icons.lock_outline;
      case 'CANCELLED':
        helper = 'This ticket was cancelled by the customer';
        icon = Icons.cancel_outlined;
      default:
        helper = 'Technician is currently working on this';
        icon = Icons.engineering_outlined;
    }

    final isNew = status == 'NEW';

    final header = Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isNew ? style.bg : AppColors.surfaceCard,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: style.fg),
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                style.label,
                style: AppText.heading.copyWith(
                  color: isNew ? AppColors.ink : style.fg,
                ),
              ),
              Text(
                helper,
                style: AppText.body.copyWith(
                  color: isNew ? AppColors.inkMuted : style.fg,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: isNew ? AppColors.surfaceCard : style.bg,
        borderRadius: AppRadius.brLg,
        boxShadow: isNew ? AppShadows.card : null,
      ),
      child: isNew
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: AppSpacing.s4),
                ElevatedButton.icon(
                  onPressed: onAssign,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Assign Technician'),
                ),
              ],
            )
          : header,
    );
  }
}

/// One line of the activity log: a small dot joined to the next by a thin
/// line, the entry text and its date.
class _LogEntry extends StatelessWidget {
  final String title;
  final String description;
  final String timestamp;
  final bool isLatest;
  final bool isLast;

  const _LogEntry({
    required this.title,
    required this.description,
    required this.timestamp,
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

/// A report field: its name in semibold, its text below in muted body style.
class _ReportText extends StatelessWidget {
  final String label;
  final Object? value;
  final bool isLast;

  const _ReportText({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.bodyStrong.copyWith(color: AppColors.ink)),
          Text(
            (value ?? '-').toString(),
            style: AppText.body.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// A saved signature image in a rounded, bordered box.
class _SignatureImage extends StatelessWidget {
  final Uint8List bytes;

  const _SignatureImage({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(AppSpacing.s2),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Image.memory(bytes, fit: BoxFit.contain),
    );
  }
}

/// The drawing pad with a dashed frame and a faint baseline. Only the frame
/// is styled; the [Signature] widget and its controller are unchanged.
class _SignaturePad extends StatelessWidget {
  final SignatureController controller;

  const _SignaturePad({required this.controller});

  @override
  Widget build(BuildContext context) {
    // The empty drag handlers stop the page scrolling while signing
    return GestureDetector(
      onVerticalDragUpdate: (_) {},
      onHorizontalDragUpdate: (_) {},
      child: CustomPaint(
        foregroundPainter: _DashedBorderPainter(),
        child: SizedBox(
          height: 140,
          child: ClipRRect(
            borderRadius: AppRadius.brMd,
            child: Stack(
              children: [
                Signature(
                  controller: controller,
                  backgroundColor: AppColors.surfaceCard,
                ),
                // A faint line to sign on.
                const Positioned(
                  left: AppSpacing.s4,
                  right: AppSpacing.s4,
                  bottom: AppSpacing.s8,
                  child: IgnorePointer(
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final outline = Path()
      ..addRRect(
        AppRadius.brMd.toRRect(
          Rect.fromLTWH(0, 0, size.width, size.height).deflate(0.75),
        ),
      );

    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
