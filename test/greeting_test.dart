import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/greeting.dart';

void main() {
  test('timeOfDayGreeting boundaries', () {
    expect(timeOfDayGreeting(DateTime(2026, 11, 6, 0, 0)), 'Good morning');
    expect(timeOfDayGreeting(DateTime(2026, 11, 6, 11, 59)), 'Good morning');
    expect(timeOfDayGreeting(DateTime(2026, 11, 6, 12, 0)), 'Good afternoon');
    expect(timeOfDayGreeting(DateTime(2026, 11, 6, 16, 59)), 'Good afternoon');
    expect(timeOfDayGreeting(DateTime(2026, 11, 6, 17, 0)), 'Good evening');
    expect(timeOfDayGreeting(DateTime(2026, 11, 6, 23, 59)), 'Good evening');
  });
}
