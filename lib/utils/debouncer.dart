import 'dart:async';

/// Runs the latest action once, [delay] after the last call to [run]. Calls
/// that arrive sooner replace the pending action. Used for autosave.
class Debouncer {
  Debouncer({required this.delay});

  final Duration delay;
  Timer? _timer;
  void Function()? _pending;

  /// Whether an action is waiting to run.
  bool get isPending => _pending != null;

  /// Schedules [action], replacing any pending one and restarting the wait.
  void run(void Function() action) {
    _timer?.cancel();
    _pending = action;
    _timer = Timer(delay, _fire);
  }

  /// Runs the pending action now, if there is one.
  void flush() {
    if (_pending == null) return;
    _timer?.cancel();
    _fire();
  }

  /// Drops the pending action without running it.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  void _fire() {
    final action = _pending;
    _pending = null;
    _timer = null;
    action?.call();
  }
}
