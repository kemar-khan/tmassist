import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/report_dates.dart';

void main() {
  test('each report is read once, shared by every caller', () async {
    final reads = <List<String>>[];
    final cache = ReportDateCache.forTest((ids) async {
      reads.add(List.of(ids));
      return {for (final id in ids) id: DateTime(2026, 11, 5)};
    });
    var notified = 0;
    cache.addListener(() => notified++);

    await cache.ensure({'a': 'RESOLVED', 'b': 'CLOSED'});
    await cache.ensure({'a': 'RESOLVED', 'b': 'CLOSED', 'c': 'RESOLVED'});
    await cache.ensure({'a': 'RESOLVED'});

    expect(reads, [
      ['a', 'b'],
      ['c'],
    ]);
    expect(cache['a'], DateTime(2026, 11, 5));
    expect(cache.dates.length, 3);
    expect(notified, 2);
  });

  test(
    'a ticket with no report is asked again only when its status changes',
    () async {
      var reads = 0;
      final cache = ReportDateCache.forTest((ids) async {
        reads++;
        return {}; // no report yet
      });

      await cache.ensure({'a': 'RESOLVED'});
      await cache.ensure({'a': 'RESOLVED'});
      expect(reads, 1);
      await cache.ensure({'a': 'CLOSED'});
      expect(reads, 2);
    },
  );

  test('a failed read is retried on the next call', () async {
    var reads = 0;
    final cache = ReportDateCache.forTest((ids) async {
      reads++;
      if (reads == 1) throw Exception('offline');
      return {'a': DateTime(2026, 11, 5)};
    });

    await cache.ensure({'a': 'RESOLVED'});
    expect(cache['a'], isNull);
    await cache.ensure({'a': 'RESOLVED'});
    expect(cache['a'], DateTime(2026, 11, 5));
  });

  test('clear forgets everything', () async {
    final cache = ReportDateCache.forTest(
      (ids) async => {for (final id in ids) id: DateTime(2026, 11, 5)},
    );
    await cache.ensure({'a': 'RESOLVED'});
    cache.clear();
    expect(cache['a'], isNull);
  });
}
