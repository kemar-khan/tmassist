import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/report_draft.dart';

void main() {
  final items = [
    {'title': 'Check the cable', 'detail': 'x'},
    {'title': 'Restart the router'},
  ];

  Map<String, dynamic> draft({
    String? sig,
    String steps = '✓ Check the cable',
  }) => {
    'issueSummary': 'Slow internet',
    'stepsTaken': steps,
    'resolutionSummary': 'Fixed',
    'technicianNotes': 'My notes',
    'proofUrl': 'https://x/p.jpg',
    'checklistSignature': ?sig,
  };

  test('signature is the titles in order and ignores other fields', () {
    expect(checklistSignature(items), 'Check the cable\nRestart the router');
    expect(
      checklistSignature([
        {'title': ' Check the cable ', 'detail': 'changed'},
        {'title': 'Restart the router'},
      ]),
      checklistSignature(items),
    );
    expect(checklistSignature(null), '');
    expect(checklistSignature([]), '');
  });

  test('a matching draft restores everything', () {
    final r = restoreDraft(draft(sig: checklistSignature(items)), items);
    expect(r.generated, isTrue);
    expect(r.stepsTaken, '✓ Check the cable');
    expect(r.issueSummary, 'Slow internet');
    expect(r.resolutionSummary, 'Fixed');
    expect(r.notes, 'My notes');
    expect(r.proofUrl, 'https://x/p.jpg');
  });

  test(
    'a changed checklist ignores the generated part, keeps notes and photo',
    () {
      final newItems = [
        {'title': 'Replace the modem'},
      ];
      final r = restoreDraft(draft(sig: checklistSignature(items)), newItems);
      expect(r.generated, isFalse);
      expect(r.stepsTaken, '');
      expect(r.issueSummary, '');
      expect(r.resolutionSummary, '');
      expect(r.notes, 'My notes');
      expect(r.proofUrl, 'https://x/p.jpg');
    },
  );

  test('items added or reordered make the draft stale', () {
    final sig = checklistSignature(items);
    expect(
      restoreDraft(draft(sig: sig), [
        ...items,
        {'title': 'New'},
      ]).generated,
      isFalse,
    );
    expect(
      restoreDraft(draft(sig: sig), items.reversed.toList()).generated,
      isFalse,
    );
  });

  test('a draft without a signature is never trusted', () {
    final r = restoreDraft(draft(), items);
    expect(r.generated, isFalse);
    expect(r.stepsTaken, '');
    expect(r.notes, 'My notes');
  });

  test('a cleared draft (no steps) is not generated even if signed', () {
    final r = restoreDraft(
      draft(sig: checklistSignature(items), steps: ''),
      items,
    );
    expect(r.generated, isFalse);
    expect(r.proofUrl, 'https://x/p.jpg');
  });

  test('no draft at all', () {
    final r = restoreDraft(null, items);
    expect(r.generated, isFalse);
    expect(r.notes, '');
  });

  test('the cleared fields never include notes or the photo', () {
    expect(staleDraftFields.keys, [
      'issueSummary',
      'stepsTaken',
      'resolutionSummary',
    ]);
  });
}
