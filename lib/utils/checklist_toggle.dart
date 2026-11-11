/// The checklist flags with the item at [index] flipped. The list is padded
/// with `false` first when it is shorter than [index] + 1, so a ticket whose
/// `checklistDone` is missing or short still works. Every other flag keeps its
/// value, which is what makes it safe to apply to the list read inside a
/// transaction.
List<bool> flipChecklistItem(List<dynamic> current, int index) {
  final flags = [for (final e in current) e == true];
  while (flags.length <= index) {
    flags.add(false);
  }
  flags[index] = !flags[index];
  return flags;
}
