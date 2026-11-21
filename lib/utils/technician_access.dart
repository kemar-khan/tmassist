/// Whether a technician may use the app yet.
enum TechnicianAccess { approved, pending, rejected }

/// Reads a user document and says what a technician may do.
///
/// - `rejected == true` always wins, even when `approved` is also true.
/// - `approved == false` means the request is waiting for a supervisor.
/// - A missing `approved` field (every account made before approval existed)
///   means approved, so existing technicians keep working unchanged.
TechnicianAccess technicianAccessState(Map<String, dynamic> data) {
  if (data['rejected'] == true) return TechnicianAccess.rejected;
  if (data['approved'] == false) return TechnicianAccess.pending;
  return TechnicianAccess.approved;
}
