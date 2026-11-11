import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/area_grouping.dart';

String show(List<MapEntry<String, int>> r) =>
    r.map((e) => '${e.key}:${e.value}').join(',');

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
    expect(show(r), 'Klang:2,Puchong:2,Shah Alam:1');
  });

  test('unmatched goes to Other, which is sorted like the rest', () {
    final r = groupByArea(['Other', 'Other', 'Other', 'Klang']);
    expect(show(r), 'Other:3,Klang:1');
  });

  test('exactly five named areas and no Other stay as they are', () {
    final r = groupByArea(['A', 'B', 'C', 'D', 'E']);
    expect(r.length, 5);
    expect(r.any((e) => e.key == 'Other'), isFalse);
  });

  test('at most five columns: the top four plus Other', () {
    // A:5 B:4 C:3 D:2 E:1 F:1 G:1, plus 2 already in Other.
    final areas = [
      for (final e in {
        'A': 5,
        'B': 4,
        'C': 3,
        'D': 2,
        'E': 1,
        'F': 1,
        'G': 1,
      }.entries)
        for (var i = 0; i < e.value; i++) e.key,
      'Other',
      'Other',
    ];
    final r = groupByArea(areas);
    expect(r.length, 5);
    // Top four kept; E, F, G (1 each) and the 2 Other merge into Other:5.
    expect(show(r), 'A:5,Other:5,B:4,C:3,D:2');
    expect(r.fold<int>(0, (s, e) => s + e.value), areas.length);
  });

  test('six named areas and no Other: the sixth merges into Other', () {
    final r = groupByArea(['A', 'A', 'B', 'B', 'C', 'C', 'D', 'D', 'E', 'F']);
    expect(r.length, 5);
    expect(show(r), 'A:2,B:2,C:2,D:2,Other:2');
  });

  test('ties among the kept areas are alphabetical', () {
    final r = groupByArea(['Z', 'M', 'A', 'M', 'Z', 'A']);
    expect(show(r), 'A:2,M:2,Z:2');
  });

  test('empty input', () {
    expect(groupByArea(const []), isEmpty);
  });
}
