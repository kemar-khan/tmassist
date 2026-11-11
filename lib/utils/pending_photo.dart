import 'dart:convert';

/// A note kept locally while the camera or gallery is open, so the photo can
/// be matched to its screen if Android kills the app in the meantime.
class PendingPhoto {
  const PendingPhoto({
    required this.purpose,
    required this.timestamp,
    this.ticketId,
  });

  /// 'report' (technician proof photo) or 'ticket' (customer attachment).
  final String purpose;
  final String? ticketId;
  final DateTime timestamp;

  /// Records older than this are ignored.
  static const maxAge = Duration(minutes: 30);

  /// Whether the record is recent enough to trust. A timestamp in the future
  /// (clock change) counts as stale.
  bool isFresh(DateTime now) {
    final age = now.difference(timestamp);
    return !age.isNegative && age <= maxAge;
  }

  String encode() => jsonEncode({
    'purpose': purpose,
    'ticketId': ticketId,
    'timestamp': timestamp.millisecondsSinceEpoch,
  });

  /// Reads a stored record; null for missing or damaged data.
  static PendingPhoto? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final purpose = map['purpose'];
      final ts = map['timestamp'];
      if (purpose is! String || ts is! int) return null;
      if (purpose != 'report' && purpose != 'ticket') return null;
      final id = map['ticketId'];
      if (purpose == 'report' && (id is! String || id.isEmpty)) return null;
      return PendingPhoto(
        purpose: purpose,
        ticketId: id is String ? id : null,
        timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
      );
    } catch (_) {
      return null;
    }
  }
}

/// A photo that Android handed back after the app was killed, with the note
/// that says which screen it was for.
class RecoveredPhoto {
  const RecoveredPhoto({
    required this.path,
    required this.purpose,
    this.ticketId,
  });

  final String path;
  final String purpose;
  final String? ticketId;
}
