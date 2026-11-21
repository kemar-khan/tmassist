import 'technician_access.dart';

/// True for a technician whose request still waits for a supervisor:
/// role "technician", approved false, and not rejected. Other roles, approved
/// technicians and accounts with no `approved` field (older accounts) are not
/// pending.
bool isPendingTechnician(Map<String, dynamic> data) {
  return data['role'] == 'technician' &&
      technicianAccessState(data) == TechnicianAccess.pending;
}

/// True when a technician may be given tickets: approved, or no `approved`
/// field at all. Pending and rejected technicians are not assignable.
bool isAssignableTechnician(Map<String, dynamic> data) {
  return technicianAccessState(data) == TechnicianAccess.approved;
}

/// Keeps only the items whose user data is assignable, in the same order.
List<T> assignableOnly<T>(
  Iterable<T> items,
  Map<String, dynamic> Function(T item) dataOf,
) {
  return [
    for (final item in items)
      if (isAssignableTechnician(dataOf(item))) item,
  ];
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "21 Nov 2026".
String formatRequestedDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';
