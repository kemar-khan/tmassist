import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/services/report_service.dart';
import '../../core/services/report_pdf_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:signature/signature.dart';

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
  final ReportService _reportService = ReportService();
  final TextEditingController _commentController = TextEditingController();
  bool _isSavingComment = false;
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _isSigning = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOff() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a comment before signing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_sigController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in the box'),
          backgroundColor: Colors.orange,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report signed and ticket closed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-off failed: $e'),
          backgroundColor: Colors.red,
        ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save comment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingComment = false);
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
        final assignmentNote = (data['assignmentNote'] ?? '').toString();

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
                  _buildInfoStatusCard(
                    "Resolved. Review the report and sign off to close it.",
                    Icons.rate_review_outlined,
                    Colors.green,
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
                  if (assignmentNote.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6600).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Color(0xFFFF6600),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              assignmentNote,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFCC5200),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (status == 'ASSIGNED') ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/supervisor/assign',
                            arguments: widget.ticketId,
                          );
                        },
                        icon: const Icon(
                          Icons.swap_horiz_rounded,
                          color: Color(0xFF005CAB),
                        ),
                        label: const Text(
                          'Reassign Technician',
                          style: TextStyle(
                            color: Color(0xFF005CAB),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFF005CAB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
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

                // Report section
                FutureBuilder<Map<String, dynamic>?>(
                  future: _reportService.getReport(widget.ticketId),
                  builder: (context, reportSnapshot) {
                    if (reportSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final report = reportSnapshot.data;
                    if (report == null) return const SizedBox();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionTitle('Service Report'),
                        _buildReportViewCard(report),
                        const SizedBox(height: 12),
                        _buildSupervisorCommentCard(
                          report,
                          locked: (report['supervisorSignature'] ?? '')
                              .toString()
                              .isNotEmpty,
                        ),
                        const SizedBox(height: 12),
                        _buildSignatureCard(report, status),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await ReportPdfService.export(
                                ticketId: widget.ticketId,
                                report: report,
                              );
                            } catch (e, st) {
                              debugPrint('PDF export error: $e\n$st');
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('PDF export failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 20,
                          ),
                          label: const Text(
                            'Export Report as PDF',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6600),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
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
          // Show AUTO ASSIGNED badge
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tickets')
                .doc(widget.ticketId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final assignmentType = data?['assignmentType']?.toString() ?? '';
              if (assignmentType == 'AUTO') {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF005CAB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'AUTO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF005CAB),
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(
                  Icons.phone_outlined,
                  color: Color(0xFFFF6600),
                ),
                onPressed: () {},
              );
            },
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

  Widget _buildReportViewCard(Map<String, dynamic> report) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportRow(
            'Issue Summary',
            report['issueSummary'] ?? '-',
            isAi: false,
          ),
          _buildDivider(),

          _buildReportRow(
            'Steps Taken',
            report['stepsTaken'] ?? '-',
            isAi: false,
          ),
          _buildDivider(),
          _buildReportRow(
            'Resolution Summary',
            report['resolutionSummary'] ?? '-',
            isAi: false,
          ),
          _buildDivider(),
          _buildReportRow(
            'Technician Notes',
            (report['technicianNotes'] ?? '').toString().isEmpty
                ? 'No additional notes.'
                : report['technicianNotes'],
            isAi: false,
          ),
          if ((report['proofUrl'] ?? '').toString().isNotEmpty) ...[
            _buildDivider(),
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                'Proof of Completion',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(
                    child: Image.network(report['proofUrl'].toString()),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  report['proofUrl'].toString(),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 120,
                    child: Center(child: Icon(Icons.broken_image, size: 40)),
                  ),
                ),
              ),
            ),
          ],
          // Older reports have no technician signature: show nothing.
          if (_decodeSignature(
                (report['technicianSignature'] ?? '').toString(),
              ) !=
              null) ...[
            _buildDivider(),
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                'Technician Sign-off',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.memory(
                _decodeSignature(report['technicianSignature'].toString())!,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${report['technicianName'] ?? 'Technician'}  •  '
              '${_formatTimestamp(report['technicianSignedAt'] is Timestamp ? report['technicianSignedAt'] as Timestamp : null)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  /// Returns null for a missing or invalid base64 signature.
  Uint8List? _decodeSignature(String b64) {
    if (b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  Widget _buildReportRow(String label, String value, {required bool isAi}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isAi) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF005CAB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'AI',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF005CAB),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisorCommentCard(
    Map<String, dynamic> report, {
    bool locked = false,
  }) {
    final existingComment = (report['supervisorComments'] ?? '').toString();

    if (_commentController.text.isEmpty && existingComment.isNotEmpty) {
      _commentController.text = existingComment;
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.supervisor_account_outlined,
                color: Color(0xFF005CAB),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Supervisor Comments',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            readOnly: locked,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add your comments or feedback on this report...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF005CAB),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
          ),
          if (!locked) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSavingComment ? null : _handleSaveComment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005CAB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSavingComment
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Comment',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignatureCard(Map<String, dynamic> report, String ticketStatus) {
    final sigB64 = (report['supervisorSignature'] ?? '').toString();

    // Already signed: read-only
    if (sigB64.isNotEmpty) {
      final signedAt = report['signedAt'] as Timestamp?;
      return _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_outlined, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  'Supervisor Sign-off',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.memory(base64Decode(sigB64), fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            Text(
              '${report['supervisorName'] ?? 'Supervisor'}  •  ${_formatTimestamp(signedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Resolved and not yet signed: show the pad
    if (ticketStatus == 'RESOLVED') {
      return _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.draw_outlined, color: Color(0xFF005CAB), size: 20),
                SizedBox(width: 8),
                Text(
                  'Sign Off & Close',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Sign below to approve this report. The ticket will be closed.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            // The empty drag handlers stop the page scrolling while signing
            GestureDetector(
              onVerticalDragUpdate: (_) {},
              onHorizontalDragUpdate: (_) {},
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Signature(
                    controller: _sigController,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSigning ? null : () => _sigController.clear(),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSigning ? null : _handleSignOff,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6600),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSigning
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('SIGN OFF & CLOSE'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Closed before sign-off existed
    if (ticketStatus == 'CLOSED') {
      return _buildInfoStatusCard(
        'Closed without sign-off',
        Icons.info_outline,
        Colors.grey,
      );
    }
    return const SizedBox();
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
