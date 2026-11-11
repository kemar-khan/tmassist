import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// When each report was submitted (`reports/{ticketId}.submittedAt`), read by
/// document id in batches of 30. Tickets without a report, or without a
/// submit time, are left out.
Future<Map<String, DateTime>> fetchReportSubmittedDates(
  List<String> ticketIds,
) async {
  final result = <String, DateTime>{};
  for (var i = 0; i < ticketIds.length; i += 30) {
    final end = i + 30 > ticketIds.length ? ticketIds.length : i + 30;
    final chunk = ticketIds.sublist(i, end);
    final snap = await FirebaseFirestore.instance
        .collection('reports')
        .where(FieldPath.documentId, whereIn: chunk)
        .get();
    for (final doc in snap.docs) {
      final value = doc.data()['submittedAt'];
      if (value is Timestamp) result[doc.id] = value.toDate();
    }
  }
  return result;
}

/// One shared, session-long store of report submit times, so the technician
/// Home and Analytics tabs read each report only once between them.
///
/// A ticket is read when it has not been asked for yet, or when it was asked
/// for under another status and no report time was found (for example it has
/// just become RESOLVED or CLOSED). Listeners are told when new times arrive.
class ReportDateCache extends ChangeNotifier {
  ReportDateCache._();

  static final ReportDateCache instance = ReportDateCache._();

  /// For tests: a cache with its own reader.
  @visibleForTesting
  ReportDateCache.forTest(this._fetch);

  Future<Map<String, DateTime>> Function(List<String> ids) _fetch =
      fetchReportSubmittedDates;

  final Map<String, DateTime> _dates = {};
  // Ticket id -> the status it had when its report was last asked for.
  final Map<String, String> _askedAs = {};

  /// Submit time by ticket id, for every report read so far.
  Map<String, DateTime> get dates => Map.unmodifiable(_dates);

  DateTime? operator [](String ticketId) => _dates[ticketId];

  /// Reads the reports of the given tickets ([ticketId] -> stored status)
  /// that are not already known. Safe to call often and from several places.
  Future<void> ensure(Map<String, String> statusByTicketId) async {
    final toRead = <String>[];
    statusByTicketId.forEach((id, status) {
      final askedAs = _askedAs[id];
      if (askedAs == null || (!_dates.containsKey(id) && askedAs != status)) {
        _askedAs[id] = status;
        toRead.add(id);
      }
    });
    if (toRead.isEmpty) return;

    try {
      final found = await _fetch(toRead);
      if (found.isNotEmpty) {
        _dates.addAll(found);
        notifyListeners();
      }
    } catch (_) {
      // Let a later call try these again.
      for (final id in toRead) {
        _askedAs.remove(id);
      }
    }
  }

  /// Forgets everything (on log out).
  void clear() {
    _dates.clear();
    _askedAs.clear();
    notifyListeners();
  }
}
