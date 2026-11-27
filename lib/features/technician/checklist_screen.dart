import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/services/checklist_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/checklist_toggle.dart';
import '../../utils/report_draft.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stream_error.dart';
import '../../core/config/timeouts.dart';
import '../../utils/slow_hint.dart';
import '../../widgets/slow_hint_text.dart';
import '../../utils/subcategory_labels.dart';

/// A snack bar to show when a generate run ends.
typedef ChecklistMessage = ({String text, SnackKind kind});

const ChecklistMessage checklistGenerated = (
  text: 'Checklist generated successfully!',
  kind: SnackKind.success,
);
const ChecklistMessage checklistFromKnowledgeBase = (
  text: 'AI was unavailable. The checklist uses the knowledge base steps.',
  kind: SnackKind.info,
);
const ChecklistMessage checklistKeptAiUnavailable = (
  text: 'AI unavailable. Your current checklist was kept. Please try again.',
  kind: SnackKind.error,
);
const ChecklistMessage checklistKeptTooSlow = (
  text: 'Taking too long. Your current checklist was kept. Please try again.',
  kind: SnackKind.error,
);
const ChecklistMessage checklistFailed = (
  text: 'Could not generate the checklist. Please try again.',
  kind: SnackKind.error,
);

/// One generate run, without any Firebase or Gemini of its own: [generate]
/// asks for the items, [usedFallback] says whether they came from the no-AI
/// fallback, and [save] writes them. Returns the message to show.
///
/// When a checklist already exists ([hasExisting]), [save] is called only for
/// a real AI result: a fallback, an empty result, an error or a timeout keeps
/// the current checklist. A first-time run saves the fallback too.
Future<ChecklistMessage> runChecklistGeneration({
  required bool hasExisting,
  required Future<List<Map<String, String>>> Function() generate,
  required bool Function() usedFallback,
  required Future<void> Function(List<Map<String, String>> items) save,
}) async {
  final List<Map<String, String>> items;
  try {
    items = await generate();
  } on TimeoutException {
    return hasExisting ? checklistKeptTooSlow : checklistFailed;
  } catch (_) {
    return hasExisting ? checklistKeptAiUnavailable : checklistFailed;
  }

  final fallback = usedFallback();
  if (hasExisting && (fallback || items.isEmpty)) {
    return checklistKeptAiUnavailable;
  }
  // Nothing usable came back: write nothing.
  if (items.isEmpty) return checklistFailed;

  try {
    await save(items);
  } catch (_) {
    return checklistFailed;
  }
  return fallback ? checklistFromKnowledgeBase : checklistGenerated;
}

/// Asks before an existing checklist is replaced. False for "Cancel" and for a
/// tap outside the dialog.
Future<bool> confirmRegenerate(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Regenerate checklist?'),
      content: const Text(
        'This replaces the current checklist and clears all ticks.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.cancelledFg),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class ChecklistScreen extends StatefulWidget {
  final String ticketId;

  const ChecklistScreen({super.key, required this.ticketId});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  bool _isGenerating = false;

  // Created once: a stream made inside build() would re-subscribe (and flash
  // a loading screen) on every setState, such as when generation starts.
  late Stream<DocumentSnapshot> _ticketStream;

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
        .snapshots()
        .map((snap) {
          final Object? data = snap.data();
          _serverDone = _flags(data is Map ? data['checklistDone'] : null);
          _overlay.observe(_serverDone);
          return snap;
        });
  }

  // Taps not yet confirmed by the server, shown at once (see ChecklistOverlay).
  final ChecklistOverlay _overlay = ChecklistOverlay();
  List<bool> _serverDone = const [];
  // Writes run one after another so taps reach the server in order.
  Future<void> _writes = Future.value();

  List<bool> _flags(Object? raw) =>
      raw is List ? [for (final e in raw) e == true] : <bool>[];

  Map<String, dynamic> _asMap(Object? e) {
    if (e is Map<String, dynamic>) return e;
    if (e is Map) {
      return Map<String, dynamic>.from(
        e.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return <String, dynamic>{};
  }

  Future<void> _handleGenerate(Map<String, dynamic> ticketData) async {
    final checklistItems = List<Map<String, dynamic>>.from(
      (ticketData['checklistItems'] ?? []).map(_asMap),
    );
    final hasExisting = checklistItems.isNotEmpty;

    // Replacing a checklist (and its ticks) needs a confirmation first.
    if (hasExisting && !await confirmRegenerate(context)) return;

    await _generate(ticketData, hasExisting: hasExisting);
  }

  Future<void> _generate(
    Map<String, dynamic> ticketData, {
    required bool hasExisting,
  }) async {
    setState(() => _isGenerating = true);
    _slowHint.start(() {
      if (mounted) setState(() => _showSlowHint = true);
    });

    // A new service for every run: its fallback flag and detection belong to
    // this run only, even if an earlier, timed-out run finishes late.
    final service = ChecklistService();

    try {
      final message = await runChecklistGeneration(
        hasExisting: hasExisting,
        generate: () => service
            .generateChecklist(
              ticketId: widget.ticketId,
              category: ticketData['category']?.toString() ?? 'Other',
              title: ticketData['title']?.toString() ?? '',
              description: ticketData['description']?.toString() ?? '',
            )
            .timeout(Timeouts.checklistGeneration),
        usedFallback: () => service.lastUsedFallback,
        save: (items) => _saveChecklist(items, service),
      );

      if (mounted) {
        showAppSnack(context, message.text, kind: message.kind);
      }
    } finally {
      _slowHint.stop();
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _showSlowHint = false;
        });
      }
    }
  }

  /// Saves a new checklist in place of the old one, with every item unticked.
  Future<void> _saveChecklist(
    List<Map<String, String>> items,
    ChecklistService service,
  ) async {
    final donelist = List.filled(items.length, false);

    // The ticket and the report draft change in ONE batch: the draft's
    // generated part (built from the old checklist) is cleared in the same
    // write, while the technician's notes and photo stay. The draft is read
    // first, so a failure leaves everything as it was. A submitted report
    // (reports/{id}) is final and is never touched.
    final db = FirebaseFirestore.instance;
    final draftRef = db.collection('drafts').doc(widget.ticketId);
    final draftSnap = await draftRef.get();
    final batch = db.batch();
    // The detected issue type is saved with the checklist, for the "Based
    // on" label and for finding similar cases later.
    final detection = service.lastDetection;
    batch.update(db.collection('tickets').doc(widget.ticketId), {
      'checklistItems': items,
      'checklistDone': donelist,
      if (detection != null) ...{
        'detectedSubcategory': detection.subcategory,
        'detectedConfidence': detection.confidence,
      },
      // Tells the screen to show the "AI unavailable" note.
      'checklistSource': service.lastUsedFallback ? 'knowledge_base' : 'ai',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (draftSnap.exists) {
      batch.update(draftRef, {
        ...staleDraftFields,
        'checklistSignature': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// The screen updates at once from the overlay; the write then runs in a
  /// queue. Inside the transaction the list is read from Firestore and only
  /// the tapped index is set, so quick taps cannot overwrite each other.
  void _handleToggle(int index) {
    final value = _overlay.toggle(_serverDone, index);
    setState(() {});
    _writes = _writes.then((_) => _write(index, value));
  }

  // "Still working…" shows when generation takes longer than 10 seconds.
  final SlowHint _slowHint = SlowHint(after: Timeouts.slowHint);
  bool _showSlowHint = false;

  @override
  void dispose() {
    _slowHint.stop();
    super.dispose();
  }

  bool _isOpeningReport = false;
  int _failedWrites = 0;

  /// "Ticket Ready for Report": waits until every tap is saved so the report
  /// screen sees the finished checklist, then opens it. Extra taps while
  /// waiting are ignored.
  Future<void> _openReport() async {
    if (_isOpeningReport) return;
    setState(() => _isOpeningReport = true);
    final failedBefore = _failedWrites;
    final result = await drainWrites(
      _writes,
      hadFailure: () => _failedWrites != failedBefore,
    );
    if (!mounted) return;
    setState(() => _isOpeningReport = false);
    if (result != DrainResult.saved) {
      showAppSnack(
        context,
        'Could not save your checklist. Please try again.',
        kind: SnackKind.error,
      );
      return;
    }
    Navigator.pushNamed(context, '/tech/report', arguments: widget.ticketId);
  }

  Future<void> _write(int index, bool value) async {
    final ref = FirebaseFirestore.instance
        .collection('tickets')
        .doc(widget.ticketId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final current = snap.data()?['checklistDone'];
        tx.update(ref, {
          'checklistDone': setChecklistItem(
            current is List ? current : const [],
            index,
            value,
          ),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      _overlay.succeeded(index);
      if (mounted) setState(() {});
    } catch (_) {
      _failedWrites++;
      _overlay.failed(index);
      if (mounted) {
        setState(() {});
        showAppSnack(
          context,
          'Could not update the checklist. Please try again.',
          kind: SnackKind.error,
        );
      }
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
            'Checklist Generation',
            const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _messageScaffold(
            'Error',
            StreamError(
              error: snapshot.error,
              onRetry: () => setState(_createStream),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _messageScaffold(
            'Error',
            const EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'Ticket not found',
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final checklistItems = List.from(
          data['checklistItems'] ?? [],
        ).map(_asMap).toList();
        final checklistDone = List.from(
          data['checklistDone'] ?? [],
        ).map((e) => e == true).toList();

        return ChecklistView(
          ticketTitle: (data['title'] ?? '').toString(),
          category: (data['category'] ?? '').toString(),
          items: checklistItems,
          done: _overlay.apply(checklistDone),
          isGenerating: _isGenerating,
          showSlowHint: _showSlowHint,
          detectedSubcategory: (data['detectedSubcategory'] ?? '').toString(),
          detectedConfidence: (data['detectedConfidence'] ?? '').toString(),
          fromKnowledgeBase: data['checklistSource'] == 'knowledge_base',
          safetyNotes: (data['detectedSubcategory'] ?? '').toString().isEmpty
              ? const []
              : ChecklistService.safetyNotesFor(
                  data['detectedSubcategory'].toString(),
                ),
          onToggle: (index, value) => _handleToggle(index),
          onGenerate: () => _handleGenerate(data),
          onReady: _openReport,
          isOpeningReport: _isOpeningReport,
        );
      },
    );
  }
}

/// The checklist page. Separate from [ChecklistScreen] so it can be built
/// without Firebase; the screen loads the data, generates and saves.
class ChecklistView extends StatelessWidget {
  final String ticketTitle;

  /// Empty when the ticket has no category (the pill is then hidden).
  final String category;

  /// Each item has `title`, `detail`, `priority` and `estimatedTime`.
  final List<Map<String, dynamic>> items;
  final List<bool> done;
  final bool isGenerating;

  /// True when generation has been running for a while: a small "Still
  /// working…" line shows under the generate or regenerate button.
  final bool showSlowHint;

  /// What the checklist was based on (saved when it was generated); both are
  /// empty for older tickets, which show no "Based on" label.
  final String detectedSubcategory;
  final String detectedConfidence;

  /// True when the checklist was built from the knowledge base because the AI
  /// was unavailable; a note says so.
  final bool fromKnowledgeBase;

  /// The safety notes of the detected knowledge-base entry (none for older
  /// tickets), shown exactly as written there.
  final List<String> safetyNotes;
  final void Function(int index, bool value) onToggle;
  final VoidCallback onGenerate;

  /// Opens the service report ("Ticket Ready for Report").
  final VoidCallback onReady;

  /// True while the screen waits for the last taps to be saved: the button
  /// shows a spinner and ignores taps.
  final bool isOpeningReport;

  const ChecklistView({
    super.key,
    required this.ticketTitle,
    required this.category,
    required this.items,
    required this.done,
    required this.isGenerating,
    this.showSlowHint = false,
    this.detectedSubcategory = '',
    this.detectedConfidence = '',
    this.fromKnowledgeBase = false,
    this.safetyNotes = const [],
    required this.onToggle,
    required this.onGenerate,
    required this.onReady,
    this.isOpeningReport = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final doneCount = done.where((d) => d).length;
    final allDone = total > 0 && doneCount == total;

    final basedOn = basedOnInfo(detectedSubcategory, detectedConfidence);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        title: const Text('Checklist Generation'),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s3,
            AppSpacing.s4,
            AppSpacing.s3,
            // With a checklist, the bottom bar sits below the list and covers
            // the safe area; without one, the list has to clear it itself.
            total == 0
                ? MediaQuery.paddingOf(context).bottom + AppSpacing.s4
                : AppSpacing.s3,
          ),
          children: [
            _ProgressCard(
              title: ticketTitle,
              category: category,
              done: doneCount,
              total: total,
            ),
            const SizedBox(height: AppSpacing.s4),
            if (total == 0)
              _EmptyChecklistCard(
                isGenerating: isGenerating,
                showSlowHint: showSlowHint,
                onGenerate: onGenerate,
              )
            else ...[
              if (basedOn != null) ...[
                _BasedOnCard(info: basedOn),
                const SizedBox(height: AppSpacing.s4),
                if (fromKnowledgeBase) ...[
                  const _NoteStrip(
                    text:
                        'Generated from the TM knowledge base (AI unavailable)',
                  ),
                  const SizedBox(height: AppSpacing.s4),
                ],
                if (safetyNotes.isNotEmpty) ...[
                  _SafetyNotesBox(notes: safetyNotes),
                  const SizedBox(height: AppSpacing.s4),
                ],
              ],
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.s3),
                _ChecklistItemCard(
                  key: ValueKey('checklist-item-$i'),
                  title: items[i]['title']?.toString() ?? '',
                  detail: items[i]['detail']?.toString() ?? '',
                  priority: items[i]['priority']?.toString() ?? 'Medium',
                  estimatedTime:
                      items[i]['estimatedTime']?.toString() ?? '10 mins',
                  isDone: i < done.length ? done[i] : false,
                  onToggle: () =>
                      onToggle(i, !(i < done.length ? done[i] : false)),
                ),
              ],
            ],
          ],
        ),
      ),
      bottomNavigationBar: total == 0
          ? null
          : _BottomBar(
              allDone: allDone,
              isOpeningReport: isOpeningReport,
              isGenerating: isGenerating,
              showSlowHint: showSlowHint,
              onReady: onReady,
              onRegenerate: onGenerate,
            ),
    );
  }
}

/// The actions pinned under the checklist: "Ticket Ready for Report" (once
/// every item is ticked) above "Regenerate Checklist".
class _BottomBar extends StatelessWidget {
  final bool allDone;
  final bool isOpeningReport;
  final bool isGenerating;
  final bool showSlowHint;
  final VoidCallback onReady;
  final VoidCallback onRegenerate;

  const _BottomBar({
    required this.allDone,
    required this.isOpeningReport,
    required this.isGenerating,
    required this.showSlowHint,
    required this.onReady,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceBg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s3,
            AppSpacing.s1,
            AppSpacing.s3,
            AppSpacing.s3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (allDone) ...[
                ElevatedButton(
                  onPressed: isOpeningReport ? () {} : onReady,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.resolvedFg,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: isOpeningReport
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check),
                            SizedBox(width: AppSpacing.s2),
                            // Wraps instead of overflowing with large text.
                            Flexible(child: Text('Ticket Ready for Report')),
                          ],
                        ),
                ),
                const SizedBox(height: AppSpacing.s2),
              ],
              OutlinedButton.icon(
                onPressed: isGenerating ? null : onRegenerate,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.surfaceCard,
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  textStyle: AppText.bodyStrong,
                ),
                icon: isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(
                  isGenerating ? 'Generating...' : 'Regenerate Checklist',
                ),
              ),
              if (isGenerating && showSlowHint) const SlowHintText(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title;
  final String category;
  final int done;
  final int total;

  const _ProgressCard({
    required this.title,
    required this.category,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final complete = total > 0 && done == total;
    final fraction = total == 0 ? 0.0 : done / total;
    final summary = total == 0
        ? '0 of 0'
        : '$done of $total (${(fraction * 100).round()}%)';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppText.heading.copyWith(color: AppColors.ink),
                ),
              ),
              if (category.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.s2),
                _Pill(
                  label: category,
                  foreground: AppColors.primary,
                  background: AppColors.primaryTint,
                  vertical: AppSpacing.s1,
                  horizontal: AppSpacing.s3,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Progress',
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                ),
              ),
              Text(
                summary,
                style: AppText.caption.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Semantics(
            label: 'Checklist $done of $total done',
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: AppRadius.brPill,
              child: Container(
                height: 8,
                color: AppColors.border,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    color: complete ? AppColors.resolvedFg : AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;
  final double vertical;
  final double horizontal;

  const _Pill({
    required this.label,
    required this.foreground,
    required this.background,
    required this.vertical,
    required this.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: vertical, horizontal: horizontal),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChecklistItemCard extends StatelessWidget {
  final String title;
  final String detail;
  final String priority;
  final String estimatedTime;
  final bool isDone;
  final VoidCallback onToggle;

  const _ChecklistItemCard({
    super.key,
    required this.title,
    required this.detail,
    required this.priority,
    required this.estimatedTime,
    required this.isDone,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final Color priorityFg;
    final Color priorityBg;
    switch (priority.toLowerCase()) {
      case 'high':
        priorityFg = AppColors.cancelledFg;
        priorityBg = AppColors.cancelledBg;
      case 'medium':
        priorityFg = AppColors.newFg;
        priorityBg = AppColors.newBg;
      default:
        priorityFg = AppColors.resolvedFg;
        priorityBg = AppColors.resolvedBg;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s1,
        AppSpacing.s2,
        AppSpacing.s4,
        AppSpacing.s3,
      ),
      // A ticked item keeps the same card; its title and detail are muted.
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            checked: isDone,
            label: title,
            excludeSemantics: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onToggle,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDone ? AppColors.primary : AppColors.surfaceCard,
                      borderRadius: AppRadius.brSm,
                      border: isDone
                          ? null
                          : Border.all(
                              color: AppColors.borderStrong,
                              width: 1.5,
                            ),
                    ),
                    child: isDone
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: AppColors.onPrimary,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppText.bodyStrong.copyWith(
                            color: isDone ? AppColors.inkFaint : AppColors.ink,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      _Pill(
                        label: priority,
                        foreground: priorityFg,
                        background: priorityBg,
                        vertical: 2,
                        horizontal: AppSpacing.s2,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    detail,
                    style: AppText.body.copyWith(
                      color: isDone ? AppColors.inkFaint : AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Row(
                    children: [
                      const ExcludeSemantics(
                        child: Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s1),
                      Expanded(
                        child: Text(
                          estimatedTime,
                          style: AppText.caption.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
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

/// What the checklist was based on: the issue type and how sure the app is.
class _BasedOnCard extends StatelessWidget {
  final BasedOnInfo info;

  const _BasedOnCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final level = info.level;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: AppRadius.brMd,
              ),
              child: const Icon(
                Icons.info_outline,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Based on',
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                ),
                Text(
                  info.title,
                  style: AppText.heading.copyWith(color: AppColors.ink),
                ),
                if (level != null) ...[
                  const SizedBox(height: AppSpacing.s2),
                  _Confidence(level: level),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Confidence", a three-part bar (High 3, Medium 2, Low 1) and the word, so
/// the level never depends on colour alone.
class _Confidence extends StatelessWidget {
  final String level;

  const _Confidence({required this.level});

  @override
  Widget build(BuildContext context) {
    final (filled, bar) = switch (level) {
      'High' => (3, AppColors.resolvedFg),
      'Medium' => (2, AppColors.chartNew),
      _ => (1, AppColors.closedFg),
    };

    return Semantics(
      container: true,
      label: 'Confidence: $level',
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.s2,
        runSpacing: AppSpacing.s1,
        children: [
          Text(
            'Confidence',
            style: AppText.caption.copyWith(color: AppColors.inkMuted),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.s1),
                Container(
                  key: ValueKey(
                    'confidence-segment-$i-${i < filled ? 'on' : 'off'}',
                  ),
                  width: 20,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < filled ? bar : AppColors.border,
                    borderRadius: AppRadius.brPill,
                  ),
                ),
              ],
            ],
          ),
          Text(level, style: AppText.caption.copyWith(color: AppColors.ink)),
        ],
      ),
    );
  }
}

/// A blue note strip, used for the "AI unavailable" note.
class _NoteStrip extends StatelessWidget {
  final String text;

  const _NoteStrip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.info_outline, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              text,
              style: AppText.body.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// The safety notes of the knowledge-base entry, straight from its text.
class _SafetyNotesBox extends StatelessWidget {
  final List<String> notes;

  const _SafetyNotesBox({required this.notes});

  @override
  Widget build(BuildContext context) {
    // The same plain white card as the checklist items.
    return Container(
      key: const ValueKey('safety-notes-card'),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AppColors.accentStrong,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  'Safety Notes',
                  style: AppText.bodyStrong.copyWith(color: AppColors.ink),
                ),
              ),
            ],
          ),
          for (final note in notes) ...[
            const SizedBox(height: AppSpacing.s2),
            // The bullet sits in its own column, so wrapped lines line up.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '\u2022',
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: AppColors.ink),
                  ),
                ),
                Expanded(
                  child: Text(
                    note,
                    style: AppText.body.copyWith(color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyChecklistCard extends StatelessWidget {
  final bool isGenerating;
  final bool showSlowHint;
  final VoidCallback onGenerate;

  const _EmptyChecklistCard({
    required this.isGenerating,
    required this.showSlowHint,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s8,
        AppSpacing.s4,
        AppSpacing.s6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.checklist_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'No checklist yet',
            textAlign: TextAlign.center,
            style: AppText.heading.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: AppSpacing.s2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              'Tap below to generate an AI-powered checklist customized for this specific issue.',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: AppColors.inkMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          ElevatedButton.icon(
            onPressed: isGenerating ? null : onGenerate,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Icon(Icons.checklist_rounded, size: 20),
            label: Text(
              isGenerating ? 'Generating...' : 'Generate AI Checklist',
            ),
          ),
          if (isGenerating && showSlowHint) const SlowHintText(),
        ],
      ),
    );
  }
}
