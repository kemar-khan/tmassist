/// How many checklist items are done, and how many there are, from a ticket
/// map (`checklistItems` and `checklistDone`). Missing data counts as zero.
({int done, int total}) checklistCounts(Map<String, dynamic>? data) {
  final items = data?['checklistItems'];
  final flags = data?['checklistDone'];
  final total = items is List ? items.length : 0;
  var done = 0;
  if (flags is List) {
    for (var i = 0; i < total && i < flags.length; i++) {
      if (flags[i] == true) done++;
    }
  }
  return (done: done, total: total);
}

/// The counts saved with a submitted report (`checklistCompletedCount` and
/// `checklistTotalCount`), or null for an old report that lacks either one.
({int done, int total})? savedChecklistCounts(Map<String, dynamic>? report) {
  final done = report?['checklistCompletedCount'];
  final total = report?['checklistTotalCount'];
  if (done is! num || total is! num) return null;
  return (done: done.toInt(), total: total.toInt());
}

/// "Checklist: X of Y Completed".
String checklistSummaryLine(int done, int total) =>
    'Checklist: $done of $total Completed';
