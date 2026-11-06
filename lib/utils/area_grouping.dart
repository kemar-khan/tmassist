import '../core/constants/service_areas.dart';

/// The area a ticket belongs to: its `area` value when it has one, otherwise
/// the first service area named in its address (case-insensitive), otherwise
/// "Other".
String areaOfTicket({String? area, String? address}) {
  final given = (area ?? '').trim();
  if (given.isNotEmpty) return given;

  final text = (address ?? '').toLowerCase();
  for (final candidate in ServiceAreas.all) {
    if (candidate == 'Other') continue;
    if (text.contains(candidate.toLowerCase())) return candidate;
  }
  return 'Other';
}

/// Counts tickets per area and returns at most [maxColumns] entries, highest
/// count first (ties in alphabetical order). Areas that do not fit, and the
/// tickets already in "Other", are merged into a single "Other" entry.
List<MapEntry<String, int>> groupByArea(
  Iterable<String> areas, {
  int maxColumns = 6,
}) {
  final counts = <String, int>{};
  for (final a in areas) {
    counts[a] = (counts[a] ?? 0) + 1;
  }

  int other = counts.remove('Other') ?? 0;
  final named = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });

  // Keep one column free for "Other" when something has to be merged into it.
  final needsOther = other > 0 || named.length > maxColumns;
  final keep = needsOther ? maxColumns - 1 : maxColumns;
  final kept = named.take(keep).toList();
  for (final e in named.skip(keep)) {
    other += e.value;
  }

  final result = [...kept, if (other > 0) MapEntry('Other', other)]
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return result;
}
