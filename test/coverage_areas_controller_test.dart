import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/features/technician/coverage_areas_controller.dart';

void main() {
  test('a tap updates at once and saves the new list', () async {
    final saved = <List<String>>[];
    final c = CoverageAreasController((a) async => saved.add(a))
      ..syncFromServer(['Puchong']);

    final future = c.toggle('Klang');
    expect(c.areas, ['Puchong', 'Klang']); // updated before the save finishes
    expect(c.saving, isTrue);
    expect(await future, isTrue);
    expect(c.saving, isFalse);
    expect(saved.single, ['Puchong', 'Klang']);

    await c.toggle('Puchong');
    expect(c.areas, ['Klang']);
  });

  test('a failed save puts the old list back', () async {
    final c = CoverageAreasController((_) async => throw Exception('offline'))
      ..syncFromServer(['Puchong', 'Klang']);

    expect(await c.toggle('Klang'), isFalse);
    expect(c.areas, ['Puchong', 'Klang']); // reverted
    expect(c.saving, isFalse);

    expect(await c.toggle('Shah Alam'), isFalse);
    expect(c.areas, ['Puchong', 'Klang']);
  });

  test('taps during a save are ignored, and a server value waits', () async {
    var calls = 0;
    final c = CoverageAreasController((_) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    })..syncFromServer([]);

    final first = c.toggle('Klang');
    expect(await c.toggle('Puchong'), isTrue); // ignored
    c.syncFromServer(['Klang']); // arrives mid-save, applied after it
    await first;

    expect(calls, 1);
    expect(c.areas, ['Klang']);
  });
}
