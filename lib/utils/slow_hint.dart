import 'dart:async';

/// Calls the callback once if [start] was called and [stop] has not been
/// called within [after]. Used for the "Still working…" hint.
class SlowHint {
  SlowHint({required this.after});

  final Duration after;
  Timer? _timer;

  void start(void Function() onSlow) {
    _timer?.cancel();
    _timer = Timer(after, onSlow);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
