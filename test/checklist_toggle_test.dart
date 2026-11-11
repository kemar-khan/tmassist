import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/checklist_toggle.dart';

void main() {
  test('flips only the tapped item', () {
    expect(flipChecklistItem([false, true, false], 0), [true, true, false]);
    expect(flipChecklistItem([false, true, false], 1), [false, false, false]);
  });

  test('two quick taps on different items both survive when each is applied '
      'to the latest list (what the transaction does)', () {
    var stored = <dynamic>[false, false, false];
    stored = flipChecklistItem(stored, 0);
    stored = flipChecklistItem(stored, 2);
    expect(stored, [true, false, true]);
  });

  test('two taps on the same item flip it back', () {
    var stored = <dynamic>[false, false];
    stored = flipChecklistItem(stored, 1);
    stored = flipChecklistItem(stored, 1);
    expect(stored, [false, false]);
  });

  test('a short or non-bool list is padded and normalised', () {
    expect(flipChecklistItem([], 2), [false, false, true]);
    expect(flipChecklistItem(['x', null, true], 0), [true, false, true]);
  });
}
