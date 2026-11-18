import 'dart:convert';

const _priorities = {'high': 'High', 'medium': 'Medium', 'low': 'Low'};

/// The checklist items in Gemini's answer, validated. Code fences are
/// stripped and the text is read with `jsonDecode`; when that fails the old
/// regex reader is the backup. Garbage gives an empty list.
///
/// Each item needs a title and a detail (anything else is skipped). A priority
/// that is not High, Medium or Low (any case) becomes Medium, and a missing
/// estimatedTime becomes "10 mins".
List<Map<String, String>> parseChecklistResponse(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'```[a-zA-Z]*'), '')
      .replaceAll('```', '')
      .trim();

  final decoded = _tryDecode(cleaned);
  if (decoded != null) return _validate(decoded);

  final start = cleaned.indexOf('[');
  final end = cleaned.lastIndexOf(']');
  if (start != -1 && end > start) {
    final sliceDecoded = _tryDecode(cleaned.substring(start, end + 1));
    if (sliceDecoded != null) return _validate(sliceDecoded);
  }

  // The backup does not need the brackets: it looks for the objects.
  return _validate(_regexItems(cleaned));
}

Object? _tryDecode(String text) {
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}

List<Map<String, String>> _validate(Object decoded) {
  // A model sometimes wraps the list: {"items": [...]}.
  final list = decoded is List
      ? decoded
      : (decoded is Map && decoded['items'] is List
            ? decoded['items'] as List
            : const []);

  final items = <Map<String, String>>[];
  for (final entry in list) {
    if (entry is! Map) continue;
    String text(String key) => (entry[key] ?? '').toString().trim();

    final title = text('title');
    final detail = text('detail');
    if (title.isEmpty || detail.isEmpty) continue;

    final time = text('estimatedTime');
    items.add({
      'title': title,
      'detail': detail,
      'priority': _priorities[text('priority').toLowerCase()] ?? 'Medium',
      'estimatedTime': time.isEmpty ? '10 mins' : time,
    });
  }
  return items;
}

/// The backup reader: finds `{ "title" ... "estimatedTime" ... }` objects with
/// a pattern. It cannot handle braces inside a value.
List<Map<String, String>> _regexItems(String json) {
  final items = <Map<String, String>>[];
  final pattern = RegExp(
    r'\{[^{}]*"title"[^{}]*"detail"[^{}]*"priority"[^{}]*"estimatedTime"[^{}]*\}',
    dotAll: true,
  );
  String field(String obj, String name) {
    final m = RegExp('"$name"\\s*:\\s*"(.*?)"', dotAll: true).firstMatch(obj);
    return m?.group(1)?.trim() ?? '';
  }

  for (final match in pattern.allMatches(json)) {
    final obj = match.group(0) ?? '';
    items.add({
      'title': field(obj, 'title'),
      'detail': field(obj, 'detail'),
      'priority': field(obj, 'priority'),
      'estimatedTime': field(obj, 'estimatedTime'),
    });
  }
  return items;
}
