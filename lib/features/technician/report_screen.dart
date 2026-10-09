import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/services/report_service.dart';

class ReportScreen extends StatefulWidget {
  final String ticketId;

  const ReportScreen({super.key, required this.ticketId});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ReportService _reportService = ReportService();
  final TextEditingController _techNotesController = TextEditingController();

  bool _isGenerating = false;
  bool _isSubmitting = false;
  bool _reportGenerated = false;
  bool _isLoading = true;

  String _issueSummary = '';
  String _rootCause = '';
  String _stepsTaken = '';
  String _resolutionSummary = '';

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

      print('DEBUG: existingReport = $existingReport');
      print('DEBUG: draft = $draft');

      if (!mounted) return;

      final ticketData = ticketSnap.exists
          ? ticketSnap.data() as Map<String, dynamic>
          : null;

      setState(() {
        _ticketData = ticketData;

        if (existingReport != null) {
          _existingReport = existingReport;
          _issueSummary = existingReport['issueSummary'] ?? '';
          _rootCause = existingReport['rootCause'] ?? '';
          _stepsTaken = existingReport['stepsTaken'] ?? '';
          _resolutionSummary = existingReport['resolutionSummary'] ?? '';
          _techNotesController.text = existingReport['technicianNotes'] ?? '';
          _reportGenerated = true;
        } else if (draft != null) {
          _issueSummary = draft['issueSummary'] ?? '';
          _rootCause = draft['rootCause'] ?? '';
          _stepsTaken = draft['stepsTaken'] ?? '';
          _resolutionSummary = draft['resolutionSummary'] ?? '';
          _techNotesController.text = draft['technicianNotes'] ?? '';
          _reportGenerated = true;
        }

        _isLoading = false;
      });
    } catch (e) {
      print('DEBUG: _loadData error = $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateReport(Map<String, dynamic> data) async {
    setState(() => _isGenerating = true);

    try {
      final category = data['category']?.toString() ?? 'General';
      final title = data['title']?.toString() ?? '';
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

      final completedSteps = <String>[];
      for (int i = 0; i < checklistItems.length; i++) {
        final isDone = i < checklistDone.length ? checklistDone[i] : false;
        if (isDone) {
          completedSteps.add(checklistItems[i]['title']?.toString() ?? '');
        }
      }

      final allSteps = <String>[];
      for (int i = 0; i < checklistItems.length; i++) {
        final isDone = i < checklistDone.length ? checklistDone[i] : false;
        final title2 = checklistItems[i]['title']?.toString() ?? '';
        allSteps.add('${isDone ? '✓' : '✗'} $title2');
      }

      final aiSections = await _reportService.generateAiSections(
        category: category,
        title: title,
        description: description,
        completedSteps: completedSteps,
      );

      setState(() {
        _issueSummary = description;
        _rootCause = aiSections['rootCause'] ?? '';
        _stepsTaken = allSteps.join('\n');
        _resolutionSummary =
            'Issue has been resolved by the assigned technician. '
            'All critical checklist items have been completed successfully.';
        _reportGenerated = true;
        _ticketData = data;
      });

      _reportService.saveDraft(
        ticketId: widget.ticketId,
        draftData: {
          'issueSummary': description,
          'rootCause': aiSections['rootCause'] ?? '',
          'stepsTaken': allSteps.join('\n'),
          'resolutionSummary':
              'Issue has been resolved by the assigned technician. '
              'All critical checklist items have been completed successfully.',
          'technicianNotes': _techNotesController.text.trim(),
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

  Future<void> _submitReport() async {
    if (!_reportGenerated) return;

    setState(() => _isSubmitting = true);

    try {
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
          'rootCause': _rootCause,
          'stepsTaken': _stepsTaken,
          'resolutionSummary': _resolutionSummary,
          'technicianNotes': _techNotesController.text.trim(),
          'supervisorComments': '',
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);

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
    final report = _existingReport;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('005CAB'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TM ASSIST',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Service Report',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          _pdfSectionTitle('TICKET INFORMATION'),
          pw.SizedBox(height: 8),
          _pdfInfoRow('Ticket ID', widget.ticketId),
          _pdfInfoRow(
            'Category',
            report?['category'] ?? data?['category'] ?? '-',
          ),
          _pdfInfoRow(
            'Customer Name',
            report?['customerName'] ?? data?['customerName'] ?? '-',
          ),
          _pdfInfoRow(
            'Technician',
            report?['technicianName'] ?? data?['technicianName'] ?? '-',
          ),
          _pdfInfoRow('Address', report?['address'] ?? data?['address'] ?? '-'),
          _pdfInfoRow(
            'Date Submitted',
            _formatTimestamp(data?['createdAt'] as Timestamp?),
          ),
          pw.SizedBox(height: 20),
          _pdfSectionTitle('ISSUE SUMMARY'),
          pw.SizedBox(height: 8),
          _pdfBodyText(report?['issueSummary'] ?? _issueSummary),
          pw.SizedBox(height: 20),
          _pdfSectionTitle('ROOT CAUSE ANALYSIS'),
          pw.SizedBox(height: 8),
          _pdfBodyText(report?['rootCause'] ?? _rootCause),
          pw.SizedBox(height: 20),
          _pdfSectionTitle('STEPS TAKEN'),
          pw.SizedBox(height: 8),
          _pdfBodyText(report?['stepsTaken'] ?? _stepsTaken),
          pw.SizedBox(height: 20),
          _pdfSectionTitle('RESOLUTION SUMMARY'),
          pw.SizedBox(height: 8),
          _pdfBodyText(report?['resolutionSummary'] ?? _resolutionSummary),
          pw.SizedBox(height: 20),
          _pdfSectionTitle('TECHNICIAN NOTES'),
          pw.SizedBox(height: 8),
          _pdfBodyText(
            report?['technicianNotes'] ??
                    _techNotesController.text.trim().isEmpty
                ? 'No additional notes.'
                : _techNotesController.text.trim(),
          ),
          pw.SizedBox(height: 20),
          if ((report?['supervisorComments'] ?? '').toString().isNotEmpty) ...[
            _pdfSectionTitle('SUPERVISOR COMMENTS'),
            pw.SizedBox(height: 8),
            _pdfBodyText(report?['supervisorComments'] ?? ''),
            pw.SizedBox(height: 20),
          ],
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated by TM Assist — ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
            style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('005CAB'),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 11)),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfBodyText(String text) {
    return pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
    );
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'AI POWERED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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
                  // Status banner
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
                    isAi: false,
                  ),
                  const SizedBox(height: 12),

                  _buildReportSection(
                    title: 'Root Cause Analysis',
                    content: _rootCause,
                    icon: Icons.search,
                    isAi: true,
                  ),
                  const SizedBox(height: 12),

                  _buildReportSection(
                    title: 'Steps Taken',
                    content: _stepsTaken,
                    icon: Icons.checklist_rounded,
                    isAi: false,
                  ),
                  const SizedBox(height: 12),

                  _buildReportSection(
                    title: 'Resolution Summary',
                    content: _resolutionSummary,
                    icon: Icons.check_circle_outline,
                    isAi: false,
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

                  if (isSubmitted &&
                      (_existingReport!['supervisorComments'] ?? '')
                          .toString()
                          .isNotEmpty)
                    _buildReportSection(
                      title: 'Supervisor Comments',
                      content: _existingReport!['supervisorComments'] ?? '',
                      icon: Icons.supervisor_account_outlined,
                      isAi: false,
                    ),

                  const SizedBox(height: 24),

                  // Buttons
                  if (!isSubmitted) ...[
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
                            : const Icon(Icons.auto_awesome),
                        label: Text(
                          _isGenerating
                              ? 'Generating...'
                              : _reportGenerated
                              ? 'Regenerate Report'
                              : 'Generate Report',
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
                    const SizedBox(height: 12),

                    if (_reportGenerated)
                      SizedBox(
                        width: double.infinity,
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],

                  if (isSubmitted || _reportGenerated)
                    SizedBox(
                      width: double.infinity,
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
    required bool isAi,
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
              if (isAi)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF005CAB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'AI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF005CAB),
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
        isAi: false,
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _techNotesController.dispose();
    super.dispose();
  }
}
