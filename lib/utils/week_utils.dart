import 'package:cloud_firestore/cloud_firestore.dart';

/// Monday 00:00 of the week [now] falls in (the same week the supervisor Home
/// "This week" chart uses).
DateTime startOfCurrentWeek(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: now.weekday - 1));
}

/// Whether a ticket's report was submitted this week (Monday 00:00 up to
/// [now]). The report's `submittedAt` is the moment the technician marked the
/// ticket resolved.
bool resolvedThisWeek(Object? submittedAt, DateTime now) {
  final DateTime date;
  if (submittedAt is Timestamp) {
    date = submittedAt.toDate();
  } else if (submittedAt is DateTime) {
    date = submittedAt;
  } else {
    return false;
  }
  return !date.isBefore(startOfCurrentWeek(now)) && !date.isAfter(now);
}
