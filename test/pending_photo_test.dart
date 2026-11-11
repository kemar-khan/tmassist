import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/pending_photo.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12);

  test('round trip keeps purpose, ticket and time', () {
    final p = PendingPhoto(purpose: 'report', ticketId: 'T1', timestamp: now);
    final back = PendingPhoto.tryParse(p.encode())!;
    expect(back.purpose, 'report');
    expect(back.ticketId, 'T1');
    expect(back.timestamp, now);
  });

  test('fresh within 30 minutes, stale after', () {
    PendingPhoto at(Duration ago) =>
        PendingPhoto(purpose: 'ticket', timestamp: now.subtract(ago));
    expect(at(Duration.zero).isFresh(now), isTrue);
    expect(at(const Duration(minutes: 30)).isFresh(now), isTrue);
    expect(at(const Duration(minutes: 30, seconds: 1)).isFresh(now), isFalse);
    expect(at(const Duration(hours: 5)).isFresh(now), isFalse);
  });

  test('a timestamp in the future is stale', () {
    final p = PendingPhoto(
      purpose: 'ticket',
      timestamp: now.add(const Duration(minutes: 5)),
    );
    expect(p.isFresh(now), isFalse);
  });

  test('damaged or incomplete data is ignored', () {
    expect(PendingPhoto.tryParse(null), isNull);
    expect(PendingPhoto.tryParse(''), isNull);
    expect(PendingPhoto.tryParse('not json'), isNull);
    expect(PendingPhoto.tryParse('[1,2]'), isNull);
    expect(PendingPhoto.tryParse('{"purpose":"x","timestamp":1}'), isNull);
    expect(PendingPhoto.tryParse('{"purpose":"ticket"}'), isNull);
    // A report record must name its ticket.
    expect(PendingPhoto.tryParse('{"purpose":"report","timestamp":1}'), isNull);
  });
}
