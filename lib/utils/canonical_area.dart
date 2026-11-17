import '../core/constants/service_areas.dart';

/// The spelling from [ServiceAreas.all] that [name] stands for, ignoring case
/// and surrounding whitespace, or null when it matches none (or is null or
/// empty). Stored areas must always use this canonical spelling, because
/// auto-assignment compares exact strings.
String? canonicalArea(String? name) {
  final wanted = (name ?? '').trim().toLowerCase();
  if (wanted.isEmpty) return null;
  for (final area in ServiceAreas.all) {
    if (area.toLowerCase() == wanted) return area;
  }
  return null;
}
