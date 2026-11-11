import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import '../../core/services/report_service.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/image_picker_helper.dart';
import '../../utils/photo_check.dart';
import '../../core/services/report_pdf_service.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';

class ReportScreen extends StatefulWidget {
  final String ticketId;

  /// A proof photo that Android kept after killing the app (see
  /// recoverLostPhoto); it goes through the normal upload once data has loaded.
  final String? recoveredPhotoPath;

  const ReportScreen({
    super.key,
    required this.ticketId,
    this.recoveredPhotoPath,
  });

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
  bool _isExporting = false;
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
      _handleRecoveredPhoto();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // Runs the normal upload for a photo recovered after the app was killed.
  void _handleRecoveredPhoto() {
    final path = widget.recoveredPhotoPath;
    if (path == null || path.isEmpty) return;
    showAppSnack(
      context,
      'Your photo was recovered. Please sign again before submitting.',
    );
    _uploadProofFile(XFile(path));
  }

  /// The report can be generated only when every checklist item of the ticket
  /// is done: `checklistItems` is not empty and each of them has a true flag
  /// in `checklistDone`.
  bool _checklistComplete(Map<String, dynamic>? data) {
    final items = data?['checklistItems'];
    final done = data?['checklistDone'];
    if (items is! List || items.isEmpty) return false;
    if (done is! List || done.length < items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (done[i] != true) return false;
    }
    return true;
  }

  /// Builds the report text from the ticket and its checklist. Nothing is
  /// sent anywhere.
  ({String issueSummary, String stepsTaken, String resolutionSummary})
  _buildReportText(Map<String, dynamic> data) {
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

    return (
      issueSummary: description,
      stepsTaken: allSteps.join('\n'),
      resolutionSummary:
          'Issue has been resolved by the assigned technician. '
          'All critical checklist items have been completed successfully.',
    );
  }

  Future<void> _generateReport(Map<String, dynamic> data) async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      final result = await Future(
        () => _buildReportText(data),
      ).timeout(const Duration(seconds: 30));

      // Nothing usable: stay as we were.
      if (result.stepsTaken.trim().isEmpty) {
        if (mounted) _showGenerateError();
        return;
      }

      if (!mounted) return;
      setState(() {
        _issueSummary = result.issueSummary;
        _stepsTaken = result.stepsTaken;
        _resolutionSummary = result.resolutionSummary;
        _reportGenerated = true;
        _ticketData = data;
      });

      // The draft is a convenience; a failed save must not undo the report.
      _reportService
          .saveDraft(
            ticketId: widget.ticketId,
            draftData: {
              'issueSummary': result.issueSummary,
              'stepsTaken': result.stepsTaken,
              'resolutionSummary': result.resolutionSummary,
              'technicianNotes': _techNotesController.text.trim(),
              'proofUrl': _proofUrl,
            },
          )
          .catchError((_) {});

      showAppSnack(
        context,
        'Report generated successfully!',
        kind: SnackKind.success,
      );
    } catch (_) {
      if (mounted) _showGenerateError();
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showGenerateError() {
    showAppSnack(
      context,
      'Could not generate the report. Please try again.',
      kind: SnackKind.error,
    );
  }

  Future<void> _uploadProof() async {
    if (_isUploadingProof) return;
    final picked = await pickImageWithChoice(
      context,
      purpose: 'report',
      ticketId: widget.ticketId,
    );
    if (!mounted) return;
    if (picked == null) {
      showAppSnack(context, 'No photo selected');
      return;
    }
    await _uploadProofFile(picked);
  }

  Future<void> _uploadProofFile(XFile picked) async {
    if (_isUploadingProof) return;
    setState(() => _isUploadingProof = true);
    try {
      final bytes = await picked.length();
      final name = picked.name.isNotEmpty ? picked.name : picked.path;
      if (!isAcceptableProofPhoto(fileName: name, bytes: bytes)) {
        if (!mounted) return;
        showAppSnack(
          context,
          'Please choose an image under 5 MB.',
          kind: SnackKind.error,
        );
        return;
      }
      final url = await CloudinaryService().uploadFromPath(picked.path);
      if (!mounted) return;
      setState(() => _proofUrl = url);
      await _saveDraftNow();
    } catch (e) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Could not upload the photo. Please try again.',
        kind: SnackKind.error,
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
    if (!_reportGenerated || _isSubmitting) return;

    if (_sigController.isEmpty) {
      showAppSnack(context, 'Please sign before submitting');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final signatureBytes = await _sigController.toPngBytes();
      if (signatureBytes == null) {
        if (!mounted) return;
        showAppSnack(
          context,
          'Could not read signature. Please sign again.',
          kind: SnackKind.error,
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

      if (!mounted) return;
      showAppSnack(
        context,
        'Report submitted successfully!',
        kind: SnackKind.success,
      );

      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'Could not submit the report. Please try again.',
          kind: SnackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    if (!_reportGenerated && _existingReport == null) return;

    setState(() => _isExporting = true);

    try {
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
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'Could not export the PDF. Please try again.',
          kind: SnackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Uint8List? _decodeSignature(Object? b64) {
    final text = (b64 ?? '').toString();
    if (text.isEmpty) return null;
    try {
      return base64Decode(text);
    } catch (_) {
      return null;
    }
  }

  DateTime? _time(Object? value) => value is Timestamp ? value.toDate() : null;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service Report')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_ticketData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service Report')),
        body: const EmptyState(
          icon: Icons.confirmation_number_outlined,
          title: 'Ticket not found',
        ),
      );
    }

    final data = _ticketData!;
    final report = _existingReport;
    final stage = report != null
        ? ReportStage.submitted
        : _reportGenerated
        ? ReportStage.generated
        : ReportStage.before;

    return ServiceReportView(
      stage: stage,
      issueSummary: _issueSummary,
      stepsTaken: _stepsTaken,
      resolutionSummary: _resolutionSummary,
      notesController: _techNotesController,
      savedNotes: (report?['technicianNotes'] ?? '').toString(),
      proofUrl: _proofUrl,
      canGenerate: _checklistComplete(data),
      isGenerating: _isGenerating,
      isSubmitting: _isSubmitting,
      isExporting: _isExporting,
      isUploadingProof: _isUploadingProof,
      signatureController: _sigController,
      technicianSignature: _decodeSignature(report?['technicianSignature']),
      technicianName: (report?['technicianName'] ?? '').toString(),
      technicianSignedAt: _time(report?['technicianSignedAt']),
      supervisorComments: (report?['supervisorComments'] ?? '').toString(),
      supervisorSignature: _decodeSignature(report?['supervisorSignature']),
      supervisorName: (report?['supervisorName'] ?? '').toString(),
      supervisorSignedAt: _time(report?['signedAt']),
      onGenerate: () => _generateReport(data),
      onUploadProof: _uploadProof,
      onRemoveProof: _removeProof,
      onSubmit: _submitReport,
      onExport: _exportPdf,
    );
  }

  @override
  void dispose() {
    _techNotesController.dispose();
    _sigController.dispose();
    super.dispose();
  }
}

/// Which of the three versions of the report page is shown.
enum ReportStage { before, generated, submitted }

/// The service report page. Separate from [ReportScreen] so it can be built
/// without Firebase; the screen loads, generates, uploads, submits and exports.
class ServiceReportView extends StatelessWidget {
  final ReportStage stage;
  final String issueSummary;

  /// One line per checklist step, starting with a tick or a cross.
  final String stepsTaken;
  final String resolutionSummary;

  /// The editable notes (before submitting) and the notes saved with a
  /// submitted report.
  final TextEditingController notesController;
  final String savedNotes;
  final String proofUrl;

  /// Whether every checklist item is done (the Generate Report gate).
  final bool canGenerate;
  final bool isGenerating;
  final bool isSubmitting;
  final bool isExporting;
  final bool isUploadingProof;

  final SignatureController signatureController;

  /// The saved technician signature, name and time (submitted reports).
  final Uint8List? technicianSignature;
  final String technicianName;
  final DateTime? technicianSignedAt;

  /// Supervisor part of a submitted report; hidden when empty.
  final String supervisorComments;
  final Uint8List? supervisorSignature;
  final String supervisorName;
  final DateTime? supervisorSignedAt;

  final VoidCallback onGenerate;
  final VoidCallback onUploadProof;
  final VoidCallback onRemoveProof;
  final VoidCallback onSubmit;
  final VoidCallback onExport;

  const ServiceReportView({
    super.key,
    required this.stage,
    required this.issueSummary,
    required this.stepsTaken,
    required this.resolutionSummary,
    required this.notesController,
    required this.savedNotes,
    required this.proofUrl,
    required this.canGenerate,
    required this.isGenerating,
    required this.isSubmitting,
    required this.isExporting,
    required this.isUploadingProof,
    required this.signatureController,
    required this.technicianSignature,
    required this.technicianName,
    required this.technicianSignedAt,
    required this.supervisorComments,
    required this.supervisorSignature,
    required this.supervisorName,
    required this.supervisorSignedAt,
    required this.onGenerate,
    required this.onUploadProof,
    required this.onRemoveProof,
    required this.onSubmit,
    required this.onExport,
  });

  bool get _submitted => stage == ReportStage.submitted;
  bool get _generated => stage != ReportStage.before;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Report')),
      body: SafeArea(
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
              if (_submitted) ...[
                const _SubmittedBanner(),
                const SizedBox(height: AppSpacing.s4),
              ],
              _textCard('Issue Summary', issueSummary),
              const SizedBox(height: AppSpacing.s4),
              _stepsCard(),
              const SizedBox(height: AppSpacing.s4),
              _textCard('Resolution Summary', resolutionSummary),
              const SizedBox(height: AppSpacing.s4),
              _notesCard(),
              const SizedBox(height: AppSpacing.s4),
              _proofCard(),
              if (_signatureCardVisible) ...[
                const SizedBox(height: AppSpacing.s4),
                _signatureCard(),
              ],
              if (_submitted && supervisorComments.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s4),
                _textCard('Supervisor Comments', supervisorComments),
              ],
              if (_submitted && supervisorSignature != null) ...[
                const SizedBox(height: AppSpacing.s4),
                SectionCard(
                  title: 'Supervisor Sign-off',
                  child: _signedImage(
                    supervisorSignature!,
                    _signedCaption(supervisorName, supervisorSignedAt),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s6),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- cards

  bool get _signatureCardVisible =>
      _submitted ? technicianSignature != null : _generated;

  Widget _textCard(String title, String content) {
    return SectionCard(
      title: title,
      child: content.isEmpty
          ? Text(
              'Tap Generate Report to fill this section',
              style: AppText.body.copyWith(
                color: AppColors.inkFaint,
                fontStyle: FontStyle.italic,
              ),
            )
          : Text(
              content,
              style: AppText.body.copyWith(color: AppColors.inkMuted),
            ),
    );
  }

  Widget _stepsCard() {
    final lines = stepsTaken
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) return _textCard('Steps Taken', '');

    return SectionCard(
      title: 'Steps Taken',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.s2),
            _StepLine(line: lines[i]),
          ],
        ],
      ),
    );
  }

  Widget _notesCard() {
    if (_submitted) {
      return SectionCard(
        title: 'Technician Notes',
        child: Text(
          savedNotes.isEmpty ? 'No additional notes.' : savedNotes,
          style: AppText.body.copyWith(color: AppColors.inkMuted),
        ),
      );
    }

    return SectionCard(
      title: 'Technician Notes',
      child: Semantics(
        textField: true,
        label: 'Technician Notes',
        child: TextField(
          controller: notesController,
          minLines: 4,
          maxLines: null,
          style: AppText.body.copyWith(color: AppColors.ink),
          decoration: const InputDecoration(
            hintText:
                'Add parts replaced, observations, or additional findings...',
          ),
        ),
      ),
    );
  }

  Widget _proofCard() {
    final hasProof = proofUrl.isNotEmpty;
    final isPdf = proofUrl.toLowerCase().endsWith('.pdf');

    final Widget body;
    if (hasProof) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Builder(
            builder: (context) => GestureDetector(
              onTap: isPdf
                  ? null
                  : () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: Image.network(proofUrl),
                        ),
                      ),
                    ),
              child: isPdf
                  ? Row(
                      children: [
                        const ExcludeSemantics(
                          child: Icon(
                            Icons.picture_as_pdf,
                            color: AppColors.cancelledFg,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s3),
                        Expanded(
                          child: Text(
                            proofUrl.split('/').last,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body.copyWith(color: AppColors.ink),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      height: 200,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(borderRadius: AppRadius.brMd),
                      child: Image.network(
                        proofUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: AppColors.inkFaint,
                              ),
                            ),
                      ),
                    ),
            ),
          ),
          if (!_submitted) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                TextButton.icon(
                  onPressed: isUploadingProof ? null : onUploadProof,
                  icon: isUploadingProof
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Replace'),
                ),
                TextButton.icon(
                  onPressed: isUploadingProof ? null : onRemoveProof,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.cancelledFg,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                ),
              ],
            ),
          ],
        ],
      );
    } else if (_submitted) {
      body = Text(
        'No proof attached.',
        style: AppText.body.copyWith(color: AppColors.inkMuted),
      );
    } else {
      body = Semantics(
        button: true,
        label: 'Attach a photo as proof',
        excludeSemantics: true,
        child: DashedBorderBox(
          backgroundColor: AppColors.surfaceBg,
          child: InkWell(
            onTap: isUploadingProof ? null : onUploadProof,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 112),
              child: Center(
                child: isUploadingProof
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(height: AppSpacing.s2),
                          Text(
                            'Uploading...',
                            style: AppText.body.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(AppSpacing.s4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_a_photo_outlined,
                              size: 28,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: AppSpacing.s2),
                            Text(
                              'Tap to attach a photo as proof',
                              textAlign: TextAlign.center,
                              style: AppText.body.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    }

    return SectionCard(
      title: 'Proof of Completion',
      trailing: _submitted
          ? null
          : Text(
              'Optional',
              style: AppText.caption.copyWith(color: AppColors.inkMuted),
            ),
      child: body,
    );
  }

  Widget _signatureCard() {
    if (_submitted) {
      return SectionCard(
        title: 'Technician Sign-off',
        child: _signedImage(
          technicianSignature!,
          _signedCaption(technicianName, technicianSignedAt),
        ),
      );
    }

    return SectionCard(
      title: 'Technician Sign-off',
      trailing: Text(
        'Required',
        style: AppText.caption.copyWith(color: AppColors.inkMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign below to confirm this report before submitting.',
            style: AppText.body.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.s3),
          // The empty drag handlers stop the page scrolling while signing
          GestureDetector(
            onVerticalDragUpdate: (_) {},
            onHorizontalDragUpdate: (_) {},
            child: DashedBorderBox(
              child: SizedBox(
                height: 160,
                child: Stack(
                  children: [
                    Signature(
                      controller: signatureController,
                      backgroundColor: AppColors.surfaceCard,
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ListenableBuilder(
                          listenable: signatureController,
                          builder: (context, _) => Center(
                            child: signatureController.isEmpty
                                ? Text(
                                    'Sign here',
                                    style: AppText.bodyStrong.copyWith(
                                      color: AppColors.inkFaint,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
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
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              button: true,
              label: 'Clear signature',
              excludeSemantics: true,
              child: TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => signatureController.clear(),
                child: const Text('Clear'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signedImage(Uint8List bytes, String caption) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 100,
          padding: const EdgeInsets.all(AppSpacing.s2),
          decoration: BoxDecoration(
            color: AppColors.surfaceBg,
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          caption,
          style: AppText.caption.copyWith(
            color: AppColors.inkMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// A caption like `Signed by Aisyah on 5/11/2026`, leaving out a part that
  /// is missing.
  String _signedCaption(String name, DateTime? date) {
    final buffer = StringBuffer('Signed');
    if (name.isNotEmpty) {
      buffer.write(' by $name');
    }
    if (date != null) {
      buffer.write(' on ${date.day}/${date.month}/${date.year}');
    }
    return buffer.toString();
  }

  // --------------------------------------------------------------- buttons

  Widget _buildActions() {
    if (_submitted) {
      return ElevatedButton.icon(
        onPressed: isExporting ? null : onExport,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
        ),
        icon: _spinnerOr(isExporting, Icons.download_rounded),
        label: Text(isExporting ? 'Exporting...' : 'Export as PDF'),
      );
    }

    if (!_generated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!canGenerate) ...[
            Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    'Complete all checklist items to generate the report.',
                    style: AppText.body.copyWith(color: AppColors.inkMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
          ElevatedButton.icon(
            onPressed: canGenerate && !isGenerating ? onGenerate : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: _spinnerOr(isGenerating, Icons.description_outlined),
            label: Text(isGenerating ? 'Generating...' : 'Generate Report'),
          ),
        ],
      );
    }

    return ListenableBuilder(
      listenable: signatureController,
      builder: (context, _) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isExporting || isSubmitting ? null : onExport,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 2),
                textStyle: AppText.heading,
              ),
              icon: isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Export as PDF'),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isSubmitting || signatureController.isEmpty
                  ? null
                  : onSubmit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _spinnerOr(isSubmitting, Icons.send_rounded),
              label: const Text('Submit Report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spinnerOr(bool loading, IconData icon) {
    if (!loading) return Icon(icon);
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.onPrimary,
      ),
    );
  }
}

class _SubmittedBanner extends StatelessWidget {
  const _SubmittedBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: AppColors.resolvedBg,
          borderRadius: AppRadius.brMd,
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.check_circle_outline,
                color: AppColors.resolvedFg,
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                'Report submitted. View only mode.',
                style: AppText.bodyStrong.copyWith(color: AppColors.resolvedFg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One step of "Steps Taken": a green tick or a red cross, then the title.
class _StepLine extends StatelessWidget {
  final String line;

  const _StepLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final trimmed = line.trim();
    final isDone = trimmed.startsWith('✓');
    final isNotDone = trimmed.startsWith('✗');
    final text = (isDone || isNotDone) ? trimmed.substring(1).trim() : trimmed;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isDone || isNotDone) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s1),
            child: Icon(
              isDone ? Icons.check_circle : Icons.cancel,
              size: 16,
              color: isDone ? AppColors.resolvedFg : AppColors.cancelledFg,
              semanticLabel: isDone ? 'Done' : 'Not done',
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
        ],
        Expanded(
          child: Text(
            text,
            style: AppText.body.copyWith(color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }
}
