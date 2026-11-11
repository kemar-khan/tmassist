import 'dart:async';

/// The checklist flags with the item at [index] flipped. The list is padded
/// with `false` first when it is shorter than [index] + 1, so a ticket whose
/// `checklistDone` is missing or short still works. Every other flag keeps its
/// value, which is what makes it safe to apply to the list read inside a
/// transaction.
List<bool> flipChecklistItem(List<dynamic> current, int index) {
  final flags = [for (final e in current) e == true];
  while (flags.length <= index) {
    flags.add(false);
  }
  flags[index] = !flags[index];
  return flags;
}

/// The checklist flags with the item at [index] set to [value] (padded like
/// [flipChecklistItem]). Used inside the write transaction so a queued tap
/// always ends in the state the user saw.
List<bool> setChecklistItem(List<dynamic> current, int index, bool value) {
  final flags = [for (final e in current) e == true];
  while (flags.length <= index) {
    flags.add(false);
  }
  flags[index] = value;
  return flags;
}

/// Taps that have not reached the server yet, laid over the server's flags so
/// the screen can update at once.
///
/// - [toggle] records the new value for an item and counts the write.
/// - [apply] gives the flags to show: the server's, with pending items
///   replaced by their recorded value.
/// - [succeeded] / [failed] report the end of one write. A failed item goes
///   back to the server value at once. A successful one stays covered until a
///   snapshot shows the new value (or two later snapshots have passed, so a
///   change made elsewhere is not hidden for ever); this keeps a snapshot
///   from before the write from flipping the box back for a moment.
/// - [observe] is fed every snapshot.
class ChecklistOverlay {
  final Map<int, bool> _desired = {};
  final Map<int, int> _inFlight = {};
  // Snapshots seen since the item's last write finished.
  final Map<int, int> _settled = {};

  bool get isEmpty => _desired.isEmpty;

  /// The flag to show for [index].
  bool effective(List<bool> server, int index) =>
      _desired[index] ?? (index < server.length ? server[index] : false);

  List<bool> apply(List<bool> server) {
    if (_desired.isEmpty) return server;
    final out = List<bool>.of(server);
    _desired.forEach((i, v) {
      while (out.length <= i) {
        out.add(false);
      }
      out[i] = v;
    });
    return out;
  }

  /// Flips what the user currently sees for [index]; returns the new value.
  bool toggle(List<bool> server, int index) {
    final value = !effective(server, index);
    _desired[index] = value;
    _inFlight[index] = (_inFlight[index] ?? 0) + 1;
    _settled.remove(index);
    return value;
  }

  void succeeded(int index) {
    final left = (_inFlight[index] ?? 1) - 1;
    if (left > 0) {
      _inFlight[index] = left;
    } else {
      _inFlight.remove(index);
      _settled[index] = 0;
    }
  }

  void failed(int index) {
    final left = (_inFlight[index] ?? 1) - 1;
    if (left > 0) {
      _inFlight[index] = left;
    } else {
      _inFlight.remove(index);
      _settled.remove(index);
      _desired.remove(index);
    }
  }

  void observe(List<bool> server) {
    for (final i in _settled.keys.toList()) {
      final shown = i < server.length ? server[i] : false;
      final seen = _settled[i]! + 1;
      if (shown == _desired[i] || seen >= 2) {
        _settled.remove(i);
        _desired.remove(i);
      } else {
        _settled[i] = seen;
      }
    }
  }
}

/// Whether the Service Report may be generated: `checklistItems` is not empty
/// and each item has a true flag in `checklistDone`.
bool checklistComplete(Map<String, dynamic>? data) {
  final items = data?['checklistItems'];
  final done = data?['checklistDone'];
  if (items is! List || items.isEmpty) return false;
  if (done is! List || done.length < items.length) return false;
  for (var i = 0; i < items.length; i++) {
    if (done[i] != true) return false;
  }
  return true;
}

enum DrainResult { saved, failed, timedOut }

/// Waits for the checklist write queue before the report opens. [hadFailure]
/// is read after the queue ends; a wait longer than [timeout] gives up so a
/// button can never stay stuck.
Future<DrainResult> drainWrites(
  Future<void> queue, {
  required bool Function() hadFailure,
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    await queue.timeout(timeout);
  } on TimeoutException {
    return DrainResult.timedOut;
  } catch (_) {
    return DrainResult.failed;
  }
  return hadFailure() ? DrainResult.failed : DrainResult.saved;
}
