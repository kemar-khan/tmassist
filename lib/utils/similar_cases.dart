/// A technician note needs at least this many characters ...
const minNoteChars = 20;

/// ... and at least this many words, so "gud" or "ok" do not count.
const minNoteWords = 4;

/// Whether [note] is a real, human-written technician note.
bool isMeaningfulNote(String? note) {
  final text = (note ?? '').trim();
  if (text.length < minNoteChars) return false;
  return text.split(RegExp(r'\s+')).length >= minNoteWords;
}

/// A past resolved ticket that may be shown to the AI as a similar case.
class SimilarCandidate {
  const SimilarCandidate({
    required this.id,
    required this.subcategory,
    required this.notes,
  });

  final String id;

  /// The ticket's saved `detectedSubcategory`; null for older tickets.
  final String? subcategory;

  /// The technician notes of its report (the only part of a past case that is
  /// sent to the AI).
  final String? notes;

  /// Usable only when the notes are meaningful ([isMeaningfulNote]).
  bool get usable => isMeaningfulNote(notes);
}

/// The cases picked for the prompt.
class SimilarSelection {
  const SimilarSelection(this.chosen);

  /// Past tickets with the same subcategory as the current one; empty when
  /// none qualify (the prompt then has no past-cases section).
  final List<SimilarCandidate> chosen;
}

/// Picks at most [max] similar cases: only past tickets whose saved
/// subcategory equals [currentSubcategory] and whose report is usable. There
/// is no fill-in from the rest of the category. The current ticket is never
/// chosen, and the input order is kept.
SimilarSelection chooseSimilarCases(
  List<SimilarCandidate> candidates, {
  required String currentSubcategory,
  required String currentTicketId,
  int max = 3,
}) {
  final same = [
    for (final c in candidates)
      if (c.id != currentTicketId &&
          c.usable &&
          c.subcategory == currentSubcategory)
        c,
  ];
  return SimilarSelection(same.take(max).toList());
}
