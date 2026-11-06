import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Stored statuses behind the three steps, in order. Used to look up the
/// timestamps passed to [VerticalStatusTimeline].
const List<String> _stepStatuses = ['ASSIGNED', 'IN_PROGRESS', 'RESOLVED'];

enum _StepState { done, current, pending }

/// The five steps of the full lifecycle (supervisor view) and the stored
/// status behind each, for looking up timestamps.
const List<String> _lifecycleStatuses = [
  'NEW',
  'ASSIGNED',
  'IN_PROGRESS',
  'RESOLVED',
  'CLOSED',
];
const List<String> _lifecycleLabels = [
  'New',
  'Assigned',
  'In Progress',
  'Resolved',
  'Closed',
];

/// The four steps of the technician view: Assigned, In Progress, Resolved,
/// Closed.
const List<String> _closedStatuses = [
  'ASSIGNED',
  'IN_PROGRESS',
  'RESOLVED',
  'CLOSED',
];
const List<String> _closedLabels = [
  'Assigned',
  'In Progress',
  'Resolved',
  'Closed',
];

/// How each of the four steps looks for a stored status. CANCELLED returns
/// null (no timeline). RESOLVED has the first three steps done and Closed
/// still pending (no step is current); CLOSED has all four done; NEW and
/// unknown values leave every step pending.
List<_StepState>? _closedStates(String status) {
  final value = status.trim().toUpperCase();
  if (value == 'CANCELLED') return null;

  final current = _closedStatuses.indexOf(value);
  return List.generate(_closedStatuses.length, (i) {
    if (current < 0) return _StepState.pending;
    if (value == 'CLOSED') return _StepState.done;
    if (value == 'RESOLVED') {
      return i <= current ? _StepState.done : _StepState.pending;
    }
    if (i < current) return _StepState.done;
    if (i == current) return _StepState.current;
    return _StepState.pending;
  });
}

/// How each of the five lifecycle steps looks for a stored status. CANCELLED
/// returns null (no timeline). RESOLVED has the first four steps done and
/// Closed still pending (no step is current); CLOSED has all five done;
/// unknown values leave every step pending.
List<_StepState>? _lifecycleStates(String status) {
  final value = status.trim().toUpperCase();
  if (value == 'CANCELLED') return null;

  final current = _lifecycleStatuses.indexOf(value);
  return List.generate(_lifecycleStatuses.length, (i) {
    if (current < 0) return _StepState.pending;
    if (value == 'CLOSED') return _StepState.done;
    if (value == 'RESOLVED') {
      return i <= current ? _StepState.done : _StepState.pending;
    }
    if (i < current) return _StepState.done;
    if (i == current) return _StepState.current;
    return _StepState.pending;
  });
}

/// The three steps shared by the horizontal stepper and the vertical timeline.
const List<String> _horizontalLabels = ['Assigned', 'In Progress', 'Resolved'];

/// How each of the three steps looks for a stored status.
/// Returns null for CANCELLED, which shows no stepper. NEW and unknown values
/// leave every step pending.
List<_StepState>? _horizontalStates(String status) {
  switch (status.trim().toUpperCase()) {
    case 'CANCELLED':
      return null;
    case 'ASSIGNED':
      return const [_StepState.current, _StepState.pending, _StepState.pending];
    case 'IN_PROGRESS':
      return const [_StepState.done, _StepState.current, _StepState.pending];
    case 'RESOLVED':
    case 'CLOSED':
      return const [_StepState.done, _StepState.done, _StepState.done];
    default:
      return const [_StepState.pending, _StepState.pending, _StepState.pending];
  }
}

Widget _stepCircle(_StepState state) {
  switch (state) {
    case _StepState.done:
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 16, color: AppColors.onPrimary),
      );
    case _StepState.current:
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 3),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    case _StepState.pending:
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderStrong, width: 2),
        ),
      );
  }
}

TextStyle _labelStyle(_StepState state) {
  switch (state) {
    case _StepState.done:
      return AppText.caption.copyWith(color: AppColors.ink);
    case _StepState.current:
      return AppText.caption.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      );
    case _StepState.pending:
      return AppText.caption.copyWith(color: AppColors.inkFaint);
  }
}

/// Three steps in a row (Assigned, In Progress, Resolved), spread evenly and
/// joined by a line. CLOSED shows every step done; NEW shows every step
/// pending. Shows nothing for a CANCELLED ticket.
class HorizontalStatusStepper extends StatelessWidget {
  /// The stored status, for example `ASSIGNED`.
  final String status;

  const HorizontalStatusStepper({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final states = _horizontalStates(status);
    if (states == null) return const SizedBox.shrink();

    final currentIndex = states.indexWhere((s) => s == _StepState.current);
    final progressLabel = currentIndex >= 0
        ? 'Step ${currentIndex + 1} of ${_horizontalLabels.length}: ${_horizontalLabels[currentIndex]}'
        : states.every((s) => s == _StepState.done)
        ? 'All steps complete'
        : 'Not started';

    return Semantics(
      label: 'Ticket progress. $progressLabel',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _horizontalLabels.length; i++)
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 24,
                    child: Row(
                      children: [
                        Expanded(
                          child: i == 0
                              ? const SizedBox.shrink()
                              : _connector(
                                  done: states[i - 1] == _StepState.done,
                                ),
                        ),
                        _stepCircle(states[i]),
                        Expanded(
                          child: i == _horizontalLabels.length - 1
                              ? const SizedBox.shrink()
                              : _connector(done: states[i] == _StepState.done),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    _horizontalLabels[i],
                    textAlign: TextAlign.center,
                    style: _labelStyle(states[i]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _connector({required bool done}) =>
      Container(height: 2, color: done ? AppColors.primary : AppColors.border);
}

/// The same three steps stacked vertically (Assigned, In Progress, Resolved),
/// with an optional timestamp under each step that has been reached.
/// [timestamps] is keyed by the stored status (`ASSIGNED`, `IN_PROGRESS`,
/// `RESOLVED`). CLOSED shows every step done; NEW shows every step pending.
/// Shows nothing for a CANCELLED ticket.
///
/// With [fullLifecycle] it shows five steps instead (New, Assigned,
/// In Progress, Resolved, Closed), keyed in [timestamps] by the same stored
/// statuses (`NEW` and `CLOSED` included).
class VerticalStatusTimeline extends StatelessWidget {
  final String status;
  final Map<String, String> timestamps;
  final bool fullLifecycle;

  /// Four steps instead of three: Assigned, In Progress, Resolved, Closed
  /// (timestamps keyed by `ASSIGNED`, `IN_PROGRESS`, `RESOLVED`, `CLOSED`).
  final bool withClosed;

  const VerticalStatusTimeline({
    super.key,
    required this.status,
    this.timestamps = const {},
    this.fullLifecycle = false,
    this.withClosed = false,
  });

  @override
  Widget build(BuildContext context) {
    final states = fullLifecycle
        ? _lifecycleStates(status)
        : withClosed
        ? _closedStates(status)
        : _horizontalStates(status);
    if (states == null) return const SizedBox.shrink();
    final labels = fullLifecycle
        ? _lifecycleLabels
        : withClosed
        ? _closedLabels
        : _horizontalLabels;
    final statuses = fullLifecycle
        ? _lifecycleStatuses
        : withClosed
        ? _closedStatuses
        : _stepStatuses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Semantics(
            container: true,
            excludeSemantics: true,
            label: _stepSemantics(i, labels, states, timestamps[statuses[i]]),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        _stepCircle(states[i]),
                        if (i < labels.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: states[i] == _StepState.done
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i < labels.length - 1 ? AppSpacing.s4 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.s1),
                            child: Text(
                              labels[i],
                              style: states[i] == _StepState.pending
                                  ? AppText.bodyStrong.copyWith(
                                      color: AppColors.inkFaint,
                                    )
                                  : AppText.bodyStrong.copyWith(
                                      color: AppColors.ink,
                                    ),
                            ),
                          ),
                          if (states[i] != _StepState.pending &&
                              timestamps[statuses[i]] != null)
                            Text(
                              timestamps[statuses[i]]!,
                              style: AppText.caption.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _stepSemantics(
  int index,
  List<String> labels,
  List<_StepState> states,
  String? timestamp,
) {
  final state = switch (states[index]) {
    _StepState.done => 'completed',
    _StepState.current => 'current step',
    _StepState.pending => 'not reached',
  };
  final time = timestamp != null && states[index] != _StepState.pending
      ? ', $timestamp'
      : '';
  return 'Step ${index + 1} of ${labels.length}: ${labels[index]}, $state$time';
}
