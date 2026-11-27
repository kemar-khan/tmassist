import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/features/technician/checklist_screen.dart';

const _items = [
  {
    'title': 'Check the ONU',
    'detail': 'Check the LEDs.',
    'priority': 'High',
    'estimatedTime': '5 mins',
  },
];

void main() {
  group('runChecklistGeneration', () {
    late int saves;

    setUp(() => saves = 0);

    Future<ChecklistMessage> run({
      required bool hasExisting,
      bool fallback = false,
      List<Map<String, String>> items = _items,
      Object? generateError,
      Object? saveError,
    }) {
      return runChecklistGeneration(
        hasExisting: hasExisting,
        generate: () async {
          if (generateError != null) throw generateError;
          return items;
        },
        usedFallback: () => fallback,
        save: (_) async {
          saves++;
          if (saveError != null) throw saveError;
        },
      );
    }

    group('replacing an existing checklist', () {
      test('an AI result is saved once', () async {
        final m = await run(hasExisting: true);
        expect(m, checklistGenerated);
        expect(saves, 1);
      });

      test('a fallback writes nothing', () async {
        final m = await run(hasExisting: true, fallback: true);
        expect(m, checklistKeptAiUnavailable);
        expect(
          m.text,
          'AI unavailable. Your current checklist was kept. Please try again.',
        );
        expect(saves, 0);
      });

      test('an empty result writes nothing', () async {
        final m = await run(hasExisting: true, items: const []);
        expect(m, checklistKeptAiUnavailable);
        expect(saves, 0);
      });

      test('an error writes nothing', () async {
        final m = await run(
          hasExisting: true,
          generateError: Exception('Checklist generation failed'),
        );
        expect(m, checklistKeptAiUnavailable);
        expect(saves, 0);
      });

      test('the outer timeout writes nothing, with its own message', () async {
        final m = await run(
          hasExisting: true,
          generateError: TimeoutException('slow'),
        );
        expect(m, checklistKeptTooSlow);
        expect(
          m.text,
          'Taking too long. Your current checklist was kept. Please try again.',
        );
        expect(saves, 0);
      });

      test('a failed save keeps the generic message', () async {
        final m = await run(hasExisting: true, saveError: Exception('offline'));
        expect(m, checklistFailed);
      });
    });

    group('first-time generation', () {
      test('an AI result is saved', () async {
        expect(await run(hasExisting: false), checklistGenerated);
        expect(saves, 1);
      });

      test('a fallback is saved and says so', () async {
        final m = await run(hasExisting: false, fallback: true);
        expect(m, checklistFromKnowledgeBase);
        expect(m.text, contains('AI was unavailable'));
        expect(saves, 1);
      });

      test('empty, error and timeout write nothing', () async {
        expect(await run(hasExisting: false, items: const []), checklistFailed);
        expect(
          await run(hasExisting: false, generateError: Exception('x')),
          checklistFailed,
        );
        expect(
          await run(hasExisting: false, generateError: TimeoutException('x')),
          checklistFailed,
        );
        expect(saves, 0);
      });
    });

    test('the fallback flag is read after generation finishes', () async {
      var fallback = true; // left over from before this run
      final m = await runChecklistGeneration(
        hasExisting: true,
        generate: () async {
          fallback = false;
          return _items;
        },
        usedFallback: () => fallback,
        save: (_) async => saves++,
      );
      expect(m, checklistGenerated);
      expect(saves, 1);
    });
  });

  group('confirmRegenerate', () {
    Future<List<bool>> openDialog(WidgetTester tester) async {
      final answers = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    answers.add(await confirmRegenerate(context)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return answers;
    }

    testWidgets('shows only Cancel and Replace', (tester) async {
      await openDialog(tester);
      expect(find.text('Regenerate checklist?'), findsOneWidget);
      expect(
        find.text('This replaces the current checklist and clears all ticks.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
      expect(find.text('Add New Items'), findsNothing);
    });

    testWidgets('Replace confirms', (tester) async {
      final answers = await openDialog(tester);
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(answers, [true]);
    });

    testWidgets('Cancel does not', (tester) async {
      final answers = await openDialog(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(answers, [false]);
    });

    testWidgets('tapping outside does not', (tester) async {
      final answers = await openDialog(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Regenerate checklist?'), findsNothing);
      expect(answers, [false]);
    });
  });
}
