// fake_async comes with flutter_test; it is not a direct dependency.
// ignore_for_file: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/checklist_summary.dart';
import 'package:tmassist/utils/debouncer.dart';

void main() {
  const delay = Duration(seconds: 1);

  group('Debouncer', () {
    test('rapid calls collapse into one, after the last call', () {
      fakeAsync((async) {
        final d = Debouncer(delay: delay);
        var calls = 0;
        d.run(() => calls++);
        async.elapse(const Duration(milliseconds: 600));
        d.run(() => calls++);
        async.elapse(const Duration(milliseconds: 600));
        d.run(() => calls++);
        async.elapse(const Duration(milliseconds: 900));
        expect(calls, 0); // still waiting: each call restarted the wait
        async.elapse(const Duration(milliseconds: 200));
        expect(calls, 1);
        async.elapse(const Duration(seconds: 5));
        expect(calls, 1);
      });
    });

    test('the latest action is the one that runs', () {
      fakeAsync((async) {
        final d = Debouncer(delay: delay);
        final seen = <int>[];
        d.run(() => seen.add(1));
        d.run(() => seen.add(2));
        async.elapse(delay);
        expect(seen, [2]);
      });
    });

    test('flush runs the pending action at once, once', () {
      fakeAsync((async) {
        final d = Debouncer(delay: delay);
        var calls = 0;
        d.run(() => calls++);
        expect(d.isPending, isTrue);
        d.flush();
        expect(calls, 1);
        expect(d.isPending, isFalse);
        async.elapse(const Duration(seconds: 5));
        expect(calls, 1); // the timer does not run it a second time
        d.flush();
        expect(calls, 1); // nothing pending
      });
    });

    test('cancel prevents the call', () {
      fakeAsync((async) {
        final d = Debouncer(delay: delay);
        var calls = 0;
        d.run(() => calls++);
        d.cancel();
        async.elapse(const Duration(seconds: 5));
        d.flush();
        expect(calls, 0);
        expect(d.isPending, isFalse);
      });
    });

    test('can be used again after firing', () {
      fakeAsync((async) {
        final d = Debouncer(delay: delay);
        var calls = 0;
        d.run(() => calls++);
        async.elapse(delay);
        d.run(() => calls++);
        async.elapse(delay);
        expect(calls, 2);
      });
    });
  });

  group('checklist summary', () {
    test('counts done items against the items list', () {
      final c = checklistCounts({
        'checklistItems': [1, 2, 3],
        'checklistDone': [true, false, true],
      });
      expect((c.done, c.total), (2, 3));
    });

    test('missing or short data is safe', () {
      expect(checklistCounts(null), (done: 0, total: 0));
      expect(
        checklistCounts({
          'checklistItems': [1, 2],
        }),
        (done: 0, total: 2),
      );
      expect(
        checklistCounts({
          'checklistItems': [1],
          'checklistDone': [true, true, true],
        }),
        (done: 1, total: 1),
      );
    });

    test('saved counts need both fields; old reports give null', () {
      expect(savedChecklistCounts({'resolutionSummary': 'x'}), isNull);
      expect(savedChecklistCounts({'checklistCompletedCount': 3}), isNull);
      expect(savedChecklistCounts({'checklistTotalCount': 3}), isNull);
      expect(savedChecklistCounts(null), isNull);
      expect(
        savedChecklistCounts({
          'checklistCompletedCount': 3,
          'checklistTotalCount': 4,
        }),
        (done: 3, total: 4),
      );
    });

    test('the line reads "Checklist: X of Y Completed"', () {
      expect(checklistSummaryLine(5, 5), 'Checklist: 5 of 5 Completed');
    });
  });
}
