import 'package:flutter/foundation.dart';

/// The technician's coverage areas while they are being edited: a tap changes
/// the list at once, the new list is saved, and a failed save puts the old
/// list back. Only one save runs at a time; taps while a save is in flight are
/// ignored.
class CoverageAreasController extends ChangeNotifier {
  CoverageAreasController(this._save);

  final Future<void> Function(List<String> areas) _save;

  List<String> _areas = [];
  List<String>? _serverWhileSaving;
  bool _saving = false;

  List<String> get areas => List.unmodifiable(_areas);
  bool get saving => _saving;

  /// Takes the list stored on the server. While a save is running the value is
  /// held back and applied when it finishes, so it cannot undo the tap.
  void syncFromServer(List<String> serverAreas) {
    if (_saving) {
      _serverWhileSaving = List.of(serverAreas);
      return;
    }
    _areas = List.of(serverAreas);
    notifyListeners();
  }

  /// Adds [area] when it is missing, removes it otherwise, and saves. Returns
  /// false when the save failed (the list is then back to what it was), true
  /// otherwise, including when the tap was ignored.
  Future<bool> toggle(String area) async {
    if (_saving) return true;

    final previous = List<String>.of(_areas);
    final updated = previous.contains(area)
        ? (List<String>.of(previous)..remove(area))
        : [...previous, area];

    _areas = updated;
    _saving = true;
    notifyListeners();

    var ok = true;
    try {
      await _save(updated);
    } catch (_) {
      _areas = previous;
      ok = false;
    }

    _saving = false;
    final server = _serverWhileSaving;
    _serverWhileSaving = null;
    if (server != null) _areas = server;
    notifyListeners();
    return ok;
  }
}
