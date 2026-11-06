import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/area_grouping.dart';

void main() {
  test('areaOfTicket uses the area field, then the address, then Other', () {
    expect(areaOfTicket(area: 'Klang', address: 'Puchong'), 'Klang');
    expect(
      areaOfTicket(area: '', address: 'No 8, jalan SS 15/4, SUBANG JAYA'),
      'Subang Jaya',
    );
    expect(areaOfTicket(area: null, address: 'Somewhere else'), 'Other');
    expect(areaOfTicket(), 'Other');
  });

  test('groupByArea counts, sorts, breaks ties alphabetically', () {
    final r = groupByArea([
      'Klang',
      'Puchong',
      'Puchong',
      'Shah Alam',
      'Klang',
    ]);
    expect(r.map((e) => '${e.key}:${e.value}'), [
      'Klang:2',
      'Puchong:2',
      'Shah Alam:1',
    ]);
  });

  test('unmatched goes to Other, which is sorted like the rest', () {
    final r = groupByArea(['Other', 'Other', 'Other', 'Klang']);
    expect(r.map((e) => '${e.key}:${e.value}'), ['Other:3', 'Klang:1']);
  });

  test('at most six columns, the rest merged into Other', () {
    final areas = [
      for (final a in ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']) ...[a, a],
      'A',
    ];
    final r = groupByArea(areas);
    expect(r.length, 6);
    expect(r.first.key, 'Other'); // 6 tickets merged, the most of any column
    expect(r[1].key, 'A');
    expect(r[1].value, 3);
    // Kept: A, B, C, D, E (5); F, G, H (2 each) are merged into Other.
    expect(r.firstWhere((e) => e.key == 'Other').value, 6);
    expect(r.fold<int>(0, (s, e) => s + e.value), areas.length);
  });

  test('exactly six named areas and no Other stay as they are', () {
    final r = groupByArea(['A', 'B', 'C', 'D', 'E', 'F']);
    expect(r.length, 6);
    expect(r.any((e) => e.key == 'Other'), isFalse);
  });

  test('empty input', () {
    expect(groupByArea(const []), isEmpty);
  });
}
