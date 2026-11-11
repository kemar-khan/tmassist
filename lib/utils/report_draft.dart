/// A text that identifies a checklist: the item titles, in order. A report
/// draft stores it, so a draft built from an older checklist can be told apart
/// from one that matches the ticket today.
String checklistSignature(Object? items) {
  if (items is! List) return '';
  return items
      .map((e) => e is Map ? (e['title'] ?? '').toString().trim() : '')
      .join('\n');
}

/// What a report draft contributes to the screen when it opens.
class RestoredDraft {
  const RestoredDraft({
    required this.generated,
    this.issueSummary = '',
    this.stepsTaken = '',
    this.resolutionSummary = '',
    this.notes = '',
    this.proofUrl = '',
  });

  /// True only when the generated sections belong to the current checklist.
  final bool generated;
  final String issueSummary;
  final String stepsTaken;
  final String resolutionSummary;

  /// The technician's own input; kept even when the generated part is not.
  final String notes;
  final String proofUrl;
}

/// Reads [draft] against the ticket's current [checklistItems]. The generated
/// sections (issue summary, steps, resolution) are used only when the draft
/// has steps and its stored `checklistSignature` equals the current checklist's.
/// Otherwise the screen opens in the "before Generate" state, still with the
/// notes and the photo.
RestoredDraft restoreDraft(
  Map<String, dynamic>? draft,
  Object? checklistItems,
) {
  if (draft == null) return const RestoredDraft(generated: false);

  String text(String key) => (draft[key] ?? '').toString();

  final notes = text('technicianNotes');
  final proof = text('proofUrl');
  final steps = text('stepsTaken');
  final matches =
      steps.trim().isNotEmpty &&
      draft['checklistSignature'] is String &&
      draft['checklistSignature'] == checklistSignature(checklistItems);

  if (!matches) {
    return RestoredDraft(generated: false, notes: notes, proofUrl: proof);
  }
  return RestoredDraft(
    generated: true,
    issueSummary: text('issueSummary'),
    stepsTaken: steps,
    resolutionSummary: text('resolutionSummary'),
    notes: notes,
    proofUrl: proof,
  );
}

/// The draft fields cleared when the checklist changes. `technicianNotes` and
/// `proofUrl` are deliberately not in this list, and `checklistSignature` is
/// removed by the caller (with a delete marker).
const staleDraftFields = <String, Object?>{
  'issueSummary': '',
  'stepsTaken': '',
  'resolutionSummary': '',
};
