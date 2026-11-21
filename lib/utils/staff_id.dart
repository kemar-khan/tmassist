final RegExp _staffIdPattern = RegExp(r'^TM\d+$');

/// The staff ID in its saved form (upper case, no spaces), or null when it is
/// not "TM" followed by digits. "tm571", "TM571" and "TM 571" all give "TM571".
String? normalizeStaffId(String? raw) {
  final text = (raw ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
  return _staffIdPattern.hasMatch(text) ? text : null;
}

/// A form validator for the staff ID field: null when valid, else a message.
String? validateStaffId(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'Enter your staff ID';
  if (normalizeStaffId(raw) == null) {
    return 'Use TM followed by digits, for example TM571';
  }
  return null;
}
