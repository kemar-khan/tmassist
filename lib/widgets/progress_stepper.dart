import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

const List<String> _stepStatuses = [
  'NEW',
  'ASSIGNED',
  'IN_PROGRESS',
  'RESOLVED',
];
const List<String> _stepLabels = ['New', 'Assigned', 'In Progress', 'Resolved'];

enum _StepState { done, current, pending }

/// Works out how each of the four steps looks for a stored status.
/// Returns null for CANCELLED, which shows no stepper.
List<_StepState>? _stepStates(String status) {
  final value = status.trim().toUpperCase();
  if (value == 'CANCELLED') return null;

  // CLOSED means the work is finished, so every step is done.
  if (value == 'CLOSED') {
    return List.filled(_stepStatuses.length, _StepState.done);
  }

  final current = _stepStatuses.indexOf(value);
  return List.generate(_stepStatuses.length, (i) {
    if (current < 0) return _StepState.pending;
    if (i < current) return _StepState.done;
    if (i == current) return _StepState.current;
    return _StepState.pending;
  });
}

/// The three steps of the horizontal stepper (the vertical timeline keeps
/// its own four).
const List<String> _horizontalLabels = ['Assigned', 'In Progress', 'Resolved'];

/// How each of the three horizontal steps looks for a stored status.
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

/// The same four steps stacked vertically, with an optional timestamp under
/// each step that has been reached. [timestamps] is keyed by the stored status
/// (`NEW`, `ASSIGNED`, `IN_PROGRESS`, `RESOLVED`). Shows nothing for a
/// CANCELLED ticket.
class VerticalStatusTimeline extends StatelessWidget {
  final String status;
  final Map<String, String> timestamps;

  const VerticalStatusTimeline({
    super.key,
    required this.status,
    this.timestamps = const {},
  });

  @override
  Widget build(BuildContext context) {
    final states = _stepStates(status);
    if (states == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _stepLabels.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      _stepCircle(states[i]),
                      if (i < _stepLabels.length - 1)
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
                      bottom: i < _stepLabels.length - 1 ? AppSpacing.s4 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s1),
                          child: Text(
                            _stepLabels[i],
                            style: _labelStyle(states[i]).copyWith(
                              fontSize: AppText.body.fontSize,
                              height: AppText.body.height,
                            ),
                          ),
                        ),
                        if (states[i] != _StepState.pending &&
                            timestamps[_stepStatuses[i]] != null)
                          Text(
                            timestamps[_stepStatuses[i]]!,
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
          ),
      ],
    );
  }
}
