// Helpers that read a knowledge-base entry (the plain text of one subcategory)
// without any AI: its safety notes and its numbered field procedures.

/// The lines under "Safety Notes:" in [kb], without the leading "- ". The
/// section ends at the next blank line, at a "Source:" line or at any line that
/// is not a "- " bullet. An entry without a Safety Notes section gives [].
List<String> safetyNotesFromKb(String kb) {
  final lines = kb.split('\n');
  final start = lines.indexWhere((l) => l.trim() == 'Safety Notes:');
  if (start == -1) return const [];

  final notes = <String>[];
  for (var i = start + 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('Source:')) break;
    if (!line.startsWith('- ')) break;
    notes.add(line.substring(2).trim());
  }
  return notes;
}

final _numbered = RegExp(r'^\s*\d+\.\s+(.+)$');

/// The text of each numbered line under "Field Procedures:" in [kb], in order,
/// without the number. Stops at the first blank line or at "Safety Notes:" or
/// "Source:". When there is no such heading, every numbered line counts.
List<String> fieldProceduresFromKb(String kb) {
  final lines = kb.split('\n');
  final start = lines.indexWhere((l) => l.trim() == 'Field Procedures:');
  final steps = <String>[];

  if (start == -1) {
    for (final l in lines) {
      final m = _numbered.firstMatch(l);
      if (m != null) steps.add(m.group(1)!.trim());
    }
    return steps;
  }

  for (var i = start + 1; i < lines.length; i++) {
    final line = lines[i];
    final t = line.trim();
    if (t.isEmpty || t == 'Safety Notes:' || t.startsWith('Source:')) break;
    final m = _numbered.firstMatch(line);
    if (m != null) steps.add(m.group(1)!.trim());
  }
  return steps;
}

// Punctuation after which a procedure line explains the action (a dash, colon,
// semicolon, comma or bracket) ...
final _punctuationBreak = RegExp(r'\s+[—–-]\s+|[:;]\s|,\s|\s\(');

// ... and linking words that start a second clause.
final _linkBreak = RegExp(r'\s+(?:and|because|so that|then|until|when|if)\s');

// Lines that start with a condition ("If it is a fault, inspect ...").
final _conditionOpener = RegExp(r'^(?:if|for|when)\s', caseSensitive: false);

// Words a title must not end on.
const _dangling = {
  'the',
  'a',
  'an',
  'to',
  'of',
  'in',
  'on',
  'at',
  'for',
  'with',
  'from',
  'by',
  'and',
  'or',
  'is',
  'are',
  'that',
  'it',
  'its',
  'as',
  'be',
  'if',
  'when',
};

int _wordCount(String s) => s.trim().split(RegExp(r'\s+')).length;

/// A short action phrase (at most 8 words) from a procedure line: the part
/// before the first dash, colon, semicolon, comma or bracket (when that part
/// has at least 3 words), else before the first linking word (at least 5
/// words), else the first 8 words. A line that starts with a condition is not
/// cut at a comma. The title never ends on a small word such as "the" or "to".
String shortActionTitle(String line) {
  var text = line.trim();

  var cut = -1;
  if (!_conditionOpener.hasMatch(text)) {
    for (final m in _punctuationBreak.allMatches(text)) {
      if (m.start > 0 && _wordCount(text.substring(0, m.start)) >= 3) {
        cut = m.start;
        break;
      }
    }
  }
  if (cut == -1) {
    for (final m in _linkBreak.allMatches(text)) {
      if (m.start > 0 && _wordCount(text.substring(0, m.start)) >= 5) {
        cut = m.start;
        break;
      }
    }
  }
  if (cut != -1) text = text.substring(0, cut);

  var words = text.replaceAll(RegExp(r'[\s.:;,]+$'), '').split(RegExp(r'\s+'));
  if (words.length > 8) words = words.take(8).toList();
  while (words.length > 2 &&
      _dangling.contains(words.last.toLowerCase().replaceAll(',', ''))) {
    words.removeLast();
  }
  var title = words.join(' ').replaceAll(RegExp(r'[\s.:;,]+$'), '');
  if (title.isEmpty) return title;
  return title[0].toUpperCase() + title.substring(1);
}

/// A checklist built straight from the numbered Field Procedures of [kb], with
/// no AI: one item per numbered line (at most [max]). The title is a short
/// action phrase, the detail is the line exactly as written, the priority
/// follows the position (first 3 High, next 3 Medium, the rest Low) and the
/// time is "5 mins". It does not decide which steps apply to a ticket.
List<Map<String, String>> fallbackChecklistFromKb(String kb, {int max = 8}) {
  final steps = fieldProceduresFromKb(kb).take(max).toList();
  return [
    for (var i = 0; i < steps.length; i++)
      {
        'title': shortActionTitle(steps[i]),
        'detail': steps[i],
        'priority': i < 3 ? 'High' : (i < 6 ? 'Medium' : 'Low'),
        'estimatedTime': '5 mins',
      },
  ];
}
