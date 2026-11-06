/// The greeting for the time of day: "Good morning" before 12:00, "Good
/// afternoon" from 12:00 to 16:59, "Good evening" from 17:00.
String timeOfDayGreeting(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}
