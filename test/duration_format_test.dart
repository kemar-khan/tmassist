import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/duration_format.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(Duration.zero), '0m');
    expect(formatDuration(const Duration(minutes: 45)), '45m');
    expect(formatDuration(const Duration(hours: 1)), '1h 0m');
    expect(formatDuration(const Duration(hours: 4, minutes: 20)), '4h 20m');
    expect(
      formatDuration(const Duration(days: 2, hours: 3, minutes: 59)),
      '2d 3h',
    );
    expect(formatDuration(const Duration(minutes: -5)), '0m');
  });
}
