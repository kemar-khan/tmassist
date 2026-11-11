import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/checklist_toggle.dart';

void main() {
  gateTests();
  overlayTests();

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

void overlayTests() {
  group('ChecklistOverlay', () {
    test('apply lays pending values over the server list', () {
      final o = ChecklistOverlay();
      expect(o.toggle([false, false, false], 1), isTrue);
      expect(o.apply([false, false, false]), [false, true, false]);
    });

    test('rapid taps on two items both show', () {
      final o = ChecklistOverlay();
      final server = [false, false];
      o.toggle(server, 0);
      o.toggle(server, 1);
      expect(o.apply(server), [true, true]);
    });

    test('same item tapped twice ends in the last tap', () {
      final o = ChecklistOverlay();
      final server = [false];
      expect(o.toggle(server, 0), isTrue);
      expect(o.toggle(server, 0), isFalse);
      expect(o.apply(server), [false]);
      o.succeeded(0); // first write done, second still in flight
      expect(o.apply(server), [false]);
      o.succeeded(0);
      o.observe([false]);
      expect(o.isEmpty, isTrue);
    });

    test('failure removes the overlay at once', () {
      final o = ChecklistOverlay();
      o.toggle([false, false], 1);
      o.failed(1);
      expect(o.apply([false, false]), [false, false]);
      expect(o.isEmpty, isTrue);
    });

    test('a failure of one item leaves the others alone', () {
      final o = ChecklistOverlay();
      o.toggle([false, false], 0);
      o.toggle([false, false], 1);
      o.failed(0);
      expect(o.apply([false, false]), [false, true]);
    });

    test(
      'completion removes the overlay once the snapshot shows the value',
      () {
        final o = ChecklistOverlay();
        o.toggle([false], 0);
        o.succeeded(0);
        expect(o.apply([false]), [true]); // still covered until a snapshot
        o.observe([true]);
        expect(o.isEmpty, isTrue);
        expect(o.apply([true]), [true]);
      },
    );

    test('a stale snapshot does not flip a pending item', () {
      final o = ChecklistOverlay();
      o.toggle([false], 0);
      o.observe([false]); // arrives while the write is in flight
      expect(o.apply([false]), [true]);
      o.succeeded(0);
      o.observe([false]); // still the old value right after completion
      expect(o.apply([false]), [true]);
      o.observe([true]); // the real one
      expect(o.isEmpty, isTrue);
    });

    test('a change made elsewhere is not hidden for ever', () {
      final o = ChecklistOverlay();
      o.toggle([false], 0);
      o.succeeded(0);
      o.observe([false]);
      o.observe([false]);
      expect(o.isEmpty, isTrue);
    });

    test('tapping again while settled starts a new write', () {
      final o = ChecklistOverlay();
      o.toggle([false], 0);
      o.succeeded(0);
      expect(o.toggle([false], 0), isFalse);
      o.observe([true]);
      expect(o.apply([true]), [false]); // pending write still wins
    });

    test('setChecklistItem sets, pads and keeps the others', () {
      expect(setChecklistItem([true], 2, true), [true, false, true]);
      expect(setChecklistItem([true, true], 0, false), [false, true]);
    });
  });
}

void gateTests() {
  group('checklistComplete', () {
    Map<String, dynamic> d(List items, List done) => {
      'checklistItems': items,
      'checklistDone': done,
    };
    test('closed when empty, missing or short', () {
      expect(checklistComplete(null), isFalse);
      expect(checklistComplete(d([], [])), isFalse);
      expect(checklistComplete(d([1, 2], [true])), isFalse);
      expect(
        checklistComplete({
          'checklistItems': [1],
        }),
        isFalse,
      );
    });
    test('closed with any false, open when all true', () {
      expect(checklistComplete(d([1, 2], [true, false])), isFalse);
      expect(checklistComplete(d([1, 2], [true, true])), isTrue);
      expect(checklistComplete(d([1], [true, false])), isTrue);
    });
  });

  group('drainWrites', () {
    test('saved when the queue finishes without failure', () async {
      final r = await drainWrites(
        Future.delayed(const Duration(milliseconds: 10)),
        hadFailure: () => false,
      );
      expect(r, DrainResult.saved);
    });
    test('failed when a write failed during the wait', () async {
      final r = await drainWrites(Future.value(), hadFailure: () => true);
      expect(r, DrainResult.failed);
    });
    test('times out instead of waiting for ever', () async {
      final r = await drainWrites(
        Completer<void>().future,
        hadFailure: () => false,
        timeout: const Duration(milliseconds: 50),
      );
      expect(r, DrainResult.timedOut);
    });
  });
}
