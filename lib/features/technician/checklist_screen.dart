import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/services/checklist_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';

class ChecklistScreen extends StatefulWidget {
  final String ticketId;

  const ChecklistScreen({super.key, required this.ticketId});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  bool _isGenerating = false;
  final ChecklistService _checklistService = ChecklistService();

  // Created once: a stream made inside build() would re-subscribe (and flash
  // a loading screen) on every setState, such as when generation starts.
  late final Stream<DocumentSnapshot> _ticketStream;

  @override
  void initState() {
    super.initState();
    _ticketStream = FirebaseFirestore.instance
        .collection('tickets')
        .doc(widget.ticketId)
        .snapshots();
  }

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

    // If existing checklist, show options dialog
    if (hasExisting) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Regenerate Checklist'),
          content: const Text(
            'What would you like to do with the current checklist?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'replace'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.cancelledFg,
              ),
              child: const Text('Replace All'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Add New Items'),
            ),
          ],
        ),
      );

      if (choice == null) return;
      await _generate(ticketData, addToExisting: choice == 'add');
    } else {
      await _generate(ticketData, addToExisting: false);
    }
  }

  Future<void> _generate(
    Map<String, dynamic> ticketData, {
    required bool addToExisting,
  }) async {
    setState(() => _isGenerating = true);

    try {
      final category = ticketData['category']?.toString() ?? 'Other';
      final title = ticketData['title']?.toString() ?? '';
      final description = ticketData['description']?.toString() ?? '';

      // Get existing items if adding
      List<Map<String, String>>? existingItems;
      if (addToExisting) {
        final raw = List<Map<String, dynamic>>.from(
          (ticketData['checklistItems'] ?? []).map(_asMap),
        );
        existingItems = raw
            .map(
              (e) => {
                'title': e['title']?.toString() ?? '',
                'detail': e['detail']?.toString() ?? '',
                'priority': e['priority']?.toString() ?? 'Medium',
                'estimatedTime': e['estimatedTime']?.toString() ?? '10 mins',
              },
            )
            .toList();
      }

      final newItems = await _checklistService
          .generateChecklist(
            ticketId: widget.ticketId,
            category: category,
            title: title,
            description: description,
            existingItems: existingItems,
            addToExisting: addToExisting,
          )
          .timeout(const Duration(seconds: 30));

      // Nothing usable came back: keep the current checklist as it is.
      if (newItems.isEmpty) {
        if (mounted) _showGenerateError();
        return;
      }

      // Combine or replace
      final finalItems = addToExisting && existingItems != null
          ? [...existingItems, ...newItems]
          : newItems;

      // Build done list
      List<bool> donelist;
      if (addToExisting && existingItems != null) {
        final existingDone = List<bool>.from(ticketData['checklistDone'] ?? []);
        donelist = [...existingDone, ...List.filled(newItems.length, false)];
      } else {
        donelist = List.filled(finalItems.length, false);
      }

      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .update({
            'checklistItems': finalItems,
            'checklistDone': donelist,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        showAppSnack(
          context,
          'Checklist generated successfully!',
          kind: SnackKind.success,
        );
      }
    } catch (_) {
      // Timeout, network or AI errors: the checklist is left untouched.
      if (mounted) _showGenerateError();
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showGenerateError() {
    showAppSnack(
      context,
      'Could not generate the checklist. Please try again.',
      kind: SnackKind.error,
    );
  }

  Future<void> _handleToggle(
    List<bool> checklistDone,
    int index,
    bool value,
  ) async {
    try {
      final updated = List<bool>.from(checklistDone);
      updated[index] = value;

      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .update({
            'checklistDone': updated,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'Failed to update: $e', kind: SnackKind.error);
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
            EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Error: ${snapshot.error}',
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
          done: checklistDone,
          isGenerating: _isGenerating,
          onToggle: (index, value) =>
              _handleToggle(checklistDone, index, value),
          onGenerate: () => _handleGenerate(data),
          onReady: () => Navigator.pushNamed(
            context,
            '/tech/report',
            arguments: widget.ticketId,
          ),
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
  final void Function(int index, bool value) onToggle;
  final VoidCallback onGenerate;

  /// Opens the service report ("Ticket Ready for Report").
  final VoidCallback onReady;

  const ChecklistView({
    super.key,
    required this.ticketTitle,
    required this.category,
    required this.items,
    required this.done,
    required this.isGenerating,
    required this.onToggle,
    required this.onGenerate,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final doneCount = done.where((d) => d).length;
    final allDone = total > 0 && doneCount == total;

    return Scaffold(
      appBar: AppBar(title: const Text('Checklist Generation')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s4,
            AppSpacing.s4,
            MediaQuery.paddingOf(context).bottom + AppSpacing.s4,
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
                onGenerate: onGenerate,
              )
            else ...[
              for (var i = 0; i < total; i++) ...[
                _ChecklistItemCard(
                  title: items[i]['title']?.toString() ?? '',
                  detail: items[i]['detail']?.toString() ?? '',
                  priority: items[i]['priority']?.toString() ?? 'Medium',
                  estimatedTime:
                      items[i]['estimatedTime']?.toString() ?? '10 mins',
                  isDone: i < done.length ? done[i] : false,
                  onToggle: () =>
                      onToggle(i, !(i < done.length ? done[i] : false)),
                ),
                const SizedBox(height: AppSpacing.s4),
              ],
              OutlinedButton.icon(
                onPressed: isGenerating ? null : onGenerate,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 2),
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
            ],
          ],
        ),
      ),
      bottomNavigationBar: allDone
          ? DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s4,
                    AppSpacing.s3,
                    AppSpacing.s4,
                    AppSpacing.s4,
                  ),
                  child: ElevatedButton.icon(
                    onPressed: onReady,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.resolvedFg,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Ticket Ready for Report'),
                  ),
                ),
              ),
            )
          : null,
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
        AppSpacing.s4,
      ),
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
                          : Border.all(color: AppColors.borderStrong, width: 2),
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

class _EmptyChecklistCard extends StatelessWidget {
  final bool isGenerating;
  final VoidCallback onGenerate;

  const _EmptyChecklistCard({
    required this.isGenerating,
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
        ],
      ),
    );
  }
}
