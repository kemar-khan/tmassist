import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:signature/signature.dart';
import '../../core/services/report_service.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/services/report_pdf_service.dart';

class ReportScreen extends StatefulWidget {
  final String ticketId;

  const ReportScreen({super.key, required this.ticketId});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ReportService _reportService = ReportService();
  final TextEditingController _techNotesController = TextEditingController();
  // Created once and disposed in dispose(); never rebuilt with the widget.
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isGenerating = false;
  bool _isSubmitting = false;
  bool _reportGenerated = false;
  bool _isLoading = true;

  String _issueSummary = '';
  String _stepsTaken = '';
  String _resolutionSummary = '';
  String _proofUrl = '';
  bool _isUploadingProof = false;

  Map<String, dynamic>? _ticketData;
  Map<String, dynamic>? _existingReport;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final ticketSnap = await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .get();

      final existingReport = await _reportService.getReport(widget.ticketId);
      final draft = await _reportService.getDraft(widget.ticketId);

      if (!mounted) return;

      final ticketData = ticketSnap.exists
          ? ticketSnap.data() as Map<String, dynamic>
          : null;

      setState(() {
        _ticketData = ticketData;

        if (existingReport != null) {
          _existingReport = existingReport;
          _issueSummary = existingReport['issueSummary'] ?? '';
          _stepsTaken = existingReport['stepsTaken'] ?? '';
          _resolutionSummary = existingReport['resolutionSummary'] ?? '';
          _techNotesController.text = existingReport['technicianNotes'] ?? '';
          _proofUrl = existingReport['proofUrl'] ?? '';
          _reportGenerated = true;
        } else if (draft != null) {
          _issueSummary = draft['issueSummary'] ?? '';
          _stepsTaken = draft['stepsTaken'] ?? '';
          _resolutionSummary = draft['resolutionSummary'] ?? '';
          _techNotesController.text = draft['technicianNotes'] ?? '';
          _proofUrl = draft['proofUrl'] ?? '';
          _reportGenerated = true;
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateReport(Map<String, dynamic> data) async {
    setState(() => _isGenerating = true);

    try {
      final description = data['description']?.toString() ?? '';

      final rawItems = data['checklistItems'];
      final checklistItems = rawItems == null
          ? <Map<String, dynamic>>[]
          : List<dynamic>.from(rawItems).map((e) {
              if (e is Map) {
                return Map<String, dynamic>.from(e);
              } else {
                return <String, dynamic>{'title': e.toString()};
              }
            }).toList();

      final rawDone = data['checklistDone'];
      final checklistDone = rawDone == null
          ? <bool>[]
          : List<dynamic>.from(rawDone).map((e) => e == true).toList();

      final allSteps = <String>[];
      for (int i = 0; i < checklistItems.length; i++) {
        final isDone = i < checklistDone.length ? checklistDone[i] : false;
        final title = checklistItems[i]['title']?.toString() ?? '';
        allSteps.add('${isDone ? '✓' : '✗'} $title');
      }

      final issueSummary = description;
      final stepsTaken = allSteps.join('\n');
      const resolutionSummary =
          'Issue has been resolved by the assigned technician. '
          'All critical checklist items have been completed successfully.';

      setState(() {
        _issueSummary = issueSummary;
        _stepsTaken = stepsTaken;
        _resolutionSummary = resolutionSummary;
        _reportGenerated = true;
        _ticketData = data;
      });

      _reportService.saveDraft(
        ticketId: widget.ticketId,
        draftData: {
          'issueSummary': issueSummary,
          'stepsTaken': stepsTaken,
          'resolutionSummary': resolutionSummary,
          'technicianNotes': _techNotesController.text.trim(),
          'proofUrl': _proofUrl,
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _uploadProof() async {
    setState(() => _isUploadingProof = true);
    try {
      final url = await CloudinaryService().uploadFile();
      if (!mounted) return;
      setState(() => _proofUrl = url);
      await _saveDraftNow();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingProof = false);
    }
  }

  Future<void> _removeProof() async {
    setState(() => _proofUrl = '');
    await _saveDraftNow();
  }

  // Keeps the draft in sync after the report has been generated
  Future<void> _saveDraftNow() async {
    if (!_reportGenerated) return;
    await _reportService.saveDraft(
      ticketId: widget.ticketId,
      draftData: {
        'issueSummary': _issueSummary,
        'stepsTaken': _stepsTaken,
        'resolutionSummary': _resolutionSummary,
        'technicianNotes': _techNotesController.text.trim(),
        'proofUrl': _proofUrl,
      },
    );
  }

  Future<void> _submitReport() async {
    if (!_reportGenerated) return;

    if (_sigController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign before submitting'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final signatureBytes = await _sigController.toPngBytes();
      if (signatureBytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read signature. Please sign again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final data = _ticketData!;

      await _reportService.saveReport(
        ticketId: widget.ticketId,
        reportData: {
          'ticketId': widget.ticketId,
          'ticketTitle': data['title']?.toString() ?? '',
          'category': data['category']?.toString() ?? '',
          'customerName': data['customerName']?.toString() ?? '',
          'technicianName': data['technicianName']?.toString() ?? '',
          'address': data['address']?.toString() ?? '',
          'createdAt': data['createdAt'],
          'issueSummary': _issueSummary,
          'stepsTaken': _stepsTaken,
          'resolutionSummary': _resolutionSummary,
          'technicianNotes': _techNotesController.text.trim(),
          'supervisorComments': '',
          'proofUrl': _proofUrl,
          'technicianSignature': base64Encode(signatureBytes),
          'technicianSignedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) return;

      await _reportService.deleteDraft(widget.ticketId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _exportPdf() async {
    if (!_reportGenerated && _existingReport == null) return;

    final data = _ticketData;
    final report =
        _existingReport ??
        {
          'category': data?['category'],
          'customerName': data?['customerName'],
          'technicianName': data?['technicianName'],
          'address': data?['address'],
          'createdAt': data?['createdAt'],
          'issueSummary': _issueSummary,
          'stepsTaken': _stepsTaken,
          'resolutionSummary': _resolutionSummary,
          'technicianNotes': _techNotesController.text.trim(),
          'proofUrl': _proofUrl,
        };

    await ReportPdfService.export(ticketId: widget.ticketId, report: report);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_ticketData == null) {
      return const Scaffold(body: Center(child: Text('Ticket not found')));
    }

    final data = _ticketData!;
    final isSubmitted = _existingReport != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF005CAB),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(50)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 24, 24),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Service Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isSubmitted)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Report submitted. View only mode.',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (isSubmitted) const SizedBox(height: 16),

                  _buildReportSection(
                    title: 'Issue Summary',
                    content: _issueSummary,
                    icon: Icons.description_outlined,
                  ),
                  const SizedBox(height: 12),

                  _buildReportSection(
                    title: 'Steps Taken',
                    content: _stepsTaken,
                    icon: Icons.checklist_rounded,
                  ),
                  const SizedBox(height: 12),

                  _buildReportSection(
                    title: 'Resolution Summary',
                    content: _resolutionSummary,
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(height: 12),

                  _buildEditableSection(
                    title: 'Technician Notes',
                    controller: _techNotesController,
                    hint:
                        'Add parts replaced, observations, or additional findings...',
                    isReadOnly: isSubmitted,
                    existingValue: isSubmitted
                        ? _existingReport!['technicianNotes'] ?? ''
                        : null,
                    icon: Icons.edit_note_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildProofSection(isSubmitted),
                  const SizedBox(height: 12),

                  // Technician sign-off: pad before submit, read-only after.
                  // Old reports without a signature show nothing.
                  if (isSubmitted
                      ? (_existingReport!['technicianSignature'] ?? '')
                            .toString()
                            .isNotEmpty
                      : _reportGenerated) ...[
                    _buildTechnicianSignatureCard(isSubmitted),
                    const SizedBox(height: 12),
                  ],

                  if (isSubmitted &&
                      (_existingReport!['supervisorComments'] ?? '')
                          .toString()
                          .isNotEmpty)
                    _buildReportSection(
                      title: 'Supervisor Comments',
                      content: _existingReport!['supervisorComments'] ?? '',
                      icon: Icons.supervisor_account_outlined,
                    ),

                  if (isSubmitted &&
                      (_existingReport!['supervisorSignature'] ?? '')
                          .toString()
                          .isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildReportSection(
                      title: 'Supervisor Sign-off',
                      content:
                          'Signed by ${_existingReport!['supervisorName'] ?? 'Supervisor'} on '
                          '${_formatTimestamp(_existingReport!['signedAt'] as Timestamp?)}',
                      icon: Icons.verified_outlined,
                    ),
                  ],

                  const SizedBox(height: 24),

                  if (!isSubmitted) ...[
                    if (!_reportGenerated) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isGenerating
                              ? null
                              : () => _generateReport(data),
                          icon: _isGenerating
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.summarize_rounded),
                          label: Text(
                            _isGenerating ? 'Generating...' : 'Generate Report',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF005CAB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  // Export and Submit sit side by side; Export fills the row
                  // on its own once the report has been submitted.
                  if (isSubmitted || _reportGenerated)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _exportPdf,
                            icon: const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: Color(0xFF005CAB),
                            ),
                            label: const Text(
                              'Export as PDF',
                              style: TextStyle(
                                color: Color(0xFF005CAB),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Color(0xFF005CAB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        if (!isSubmitted && _reportGenerated) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : _submitReport,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                              label: const Text(
                                'Submit Report',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6600),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF005CAB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content.isEmpty
              ? Text(
                  'Tap Generate Report to fill this section',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                  ),
                )
              : Text(
                  content,
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

  Widget _buildEditableSection({
    required String title,
    required TextEditingController controller,
    required String hint,
    required bool isReadOnly,
    String? existingValue,
    required IconData icon,
  }) {
    if (isReadOnly && existingValue != null) {
      return _buildReportSection(
        title: title,
        content: existingValue.isEmpty ? 'No additional notes.' : existingValue,
        icon: icon,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF005CAB)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              border: InputBorder.none,
            ),
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

  Uint8List? _decodeSignature(String b64) {
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  Widget _buildTechnicianSignatureCard(bool isSubmitted) {
    final storedSig = (_existingReport?['technicianSignature'] ?? '')
        .toString();
    final storedBytes = isSubmitted ? _decodeSignature(storedSig) : null;
    final signedAtRaw = _existingReport?['technicianSignedAt'];
    final signedAt = signedAtRaw is Timestamp ? signedAtRaw : null;
    final signerName = (_existingReport?['technicianName'] ?? 'Technician')
        .toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSubmitted ? Icons.verified_outlined : Icons.draw_outlined,
                size: 18,
                color: isSubmitted ? Colors.green : const Color(0xFF005CAB),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Technician Sign-off',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              if (!isSubmitted)
                Text(
                  'Required',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isSubmitted) ...[
            Container(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: storedBytes == null
                  ? const Center(child: Icon(Icons.broken_image, size: 36))
                  : Image.memory(storedBytes, fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            Text(
              'Signed by $signerName on ${_formatTimestamp(signedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ] else ...[
            Text(
              'Sign below to confirm this report before submitting.',
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isSubmitting ? null : () => _sigController.clear(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Clear'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProofSection(bool isSubmitted) {
    final hasProof = _proofUrl.isNotEmpty;
    final isPdf = _proofUrl.toLowerCase().endsWith('.pdf');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_camera_outlined,
                size: 18,
                color: Color(0xFF005CAB),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Proof of Completion',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              if (!isSubmitted)
                Text(
                  'Optional',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (hasProof) ...[
            GestureDetector(
              onTap: isPdf
                  ? null
                  : () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: Image.network(_proofUrl),
                        ),
                      ),
                    ),
              child: isPdf
                  ? Row(
                      children: [
                        const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red,
                          size: 36,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _proofUrl.split('/').last,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _proofUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : const SizedBox(
                                height: 200,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                        errorBuilder: (_, __, ___) => const SizedBox(
                          height: 200,
                          child: Center(
                            child: Icon(Icons.broken_image, size: 50),
                          ),
                        ),
                      ),
                    ),
            ),
            if (!isSubmitted) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _isUploadingProof ? null : _uploadProof,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Replace'),
                  ),
                  TextButton.icon(
                    onPressed: _removeProof,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ] else if (isSubmitted)
            Text(
              'No proof attached.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            )
          else
            InkWell(
              onTap: _isUploadingProof ? null : _uploadProof,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isUploadingProof
                          ? Icons.hourglass_top_rounded
                          : Icons.add_a_photo_outlined,
                      size: 30,
                      color: _isUploadingProof
                          ? Colors.orange
                          : Colors.grey[500],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isUploadingProof
                          ? 'Uploading...'
                          : 'Tap to attach a photo as proof',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _techNotesController.dispose();
    _sigController.dispose();
    super.dispose();
  }
}
