/// Whether [area] means "any area": missing, empty or "Other". Such a ticket
/// is never outside anyone's coverage.
bool isAnyArea(String? area) => area == null || area.isEmpty || area == 'Other';

/// Whether a technician with [coverageAreas] covers a ticket in [area]. A
/// missing, empty or "Other" area is covered by everyone; any other area must
/// appear in [coverageAreas] exactly (same case and spelling). A null list
/// counts as empty.
bool coversArea(List<String>? coverageAreas, String? area) {
  if (isAnyArea(area)) return true;
  return (coverageAreas ?? const <String>[]).contains(area);
}

/// The opposite of [coversArea].
bool isOutsideCoverage(List<String>? coverageAreas, String? area) =>
    !coversArea(coverageAreas, area);
