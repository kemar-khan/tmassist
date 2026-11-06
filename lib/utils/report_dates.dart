import 'package:cloud_firestore/cloud_firestore.dart';

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
