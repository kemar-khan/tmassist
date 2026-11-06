/// A short text for a duration: "45m" under an hour, "4h 20m" under a day,
/// otherwise "2d 3h". Negative durations count as zero.
String formatDuration(Duration duration) {
  final d = duration.isNegative ? Duration.zero : duration;
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;

  if (days > 0) return '${days}d ${hours}h';
  if (d.inHours > 0) return '${d.inHours}h ${minutes}m';
  return '${d.inMinutes}m';
}
