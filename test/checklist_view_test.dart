import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/core/theme/app_tokens.dart';
import 'package:tmassist/features/technician/checklist_screen.dart';
import 'package:tmassist/utils/subcategory_labels.dart';

const _fallbackNote = 'Generated from the TM knowledge base (AI unavailable)';

List<Map<String, dynamic>> _items(int n) => [
  for (var i = 1; i <= n; i++)
    {
      'title': 'Step $i',
      'detail': 'Detail $i',
      'priority': i == 1 ? 'High' : (i == 2 ? 'Medium' : 'Low'),
      'estimatedTime': '5 mins',
    },
];

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String subcategory = 'vlan_config',
    String confidence = 'high',
    bool fromKnowledgeBase = false,
    List<bool> done = const [false, false, false],
    int count = 3,
    bool isGenerating = false,
    bool showSlowHint = false,
    List<String> safetyNotes = const ['Inform the customer first'],
    VoidCallback? onGenerate,
    VoidCallback? onReady,
  }) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ChecklistView(
          ticketTitle: 'TV box shows no signal',
          category: 'Software',
          items: _items(count),
          done: done,
          isGenerating: isGenerating,
          showSlowHint: showSlowHint,
          detectedSubcategory: subcategory,
          detectedConfidence: confidence,
          fromKnowledgeBase: fromKnowledgeBase,
          safetyNotes: safetyNotes,
          onToggle: (_, _) {},
          onGenerate: onGenerate ?? () {},
          onReady: onReady ?? () {},
        ),
      ),
    );
  }

  /// How many of the three confidence segments are filled.
  int filled(WidgetTester tester) {
    var on = 0;
    var all = 0;
    for (var i = 0; i < 3; i++) {
      final isOn = find.byKey(ValueKey('confidence-segment-$i-on'));
      final isOff = find.byKey(ValueKey('confidence-segment-$i-off'));
      on += isOn.evaluate().length;
      all += isOn.evaluate().length + isOff.evaluate().length;
    }
    expect(all, 3);
    return on;
  }

  group('basedOnInfo', () {
    test('known subcategory, low, general, unknown and missing', () {
      expect(basedOnInfo('vlan_config', 'high'), (
        title: 'IPTV / VLAN configuration',
        level: 'High',
      ));
      expect(basedOnInfo('wifi_issue', 'MEDIUM')?.level, 'Medium');
      expect(basedOnInfo('general', 'low'), (
        title: generalProcedureText,
        level: 'Low',
      ));
      expect(basedOnInfo('fiber_loss', 'low'), (
        title: generalProcedureText,
        level: 'Low',
      ));
      expect(basedOnInfo('mystery', 'high'), (
        title: generalProcedureText,
        level: null,
      ));
      expect(basedOnInfo('fiber_loss', 'odd')?.level, isNull);
      expect(basedOnInfo('', ''), isNull);
      expect(basedOnInfo('fiber_loss', null), isNull);
    });
  });

  group('"Based on" card', () {
    for (final (confidence, word, segments) in [
      ('high', 'High', 3),
      ('medium', 'Medium', 2),
    ]) {
      testWidgets('$word: name, $segments segments and the word', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, confidence: confidence);

        expect(find.text('Based on'), findsOneWidget);
        expect(find.text('IPTV / VLAN configuration'), findsOneWidget);
        expect(find.text('Confidence'), findsOneWidget);
        expect(filled(tester), segments);
        expect(find.bySemanticsLabel('Confidence: $word'), findsOneWidget);
        semantics.dispose();
      });
    }

    testWidgets('the level is small plain text, like the label', (
      tester,
    ) async {
      await pump(tester);

      final label = tester.widget<Text>(find.text('Confidence')).style!;
      // "High" is also the priority chip of step 1; the card's comes first.
      final word = find.text('High').first;
      final style = tester.widget<Text>(word).style!;
      expect(style.fontSize, label.fontSize);
      expect(style.fontWeight, label.fontWeight);

      // No background or border between the word and the confidence row.
      final row = find.ancestor(of: word, matching: find.byType(Wrap));
      expect(
        find.ancestor(
          of: word,
          matching: find.descendant(of: row, matching: find.byType(Container)),
        ),
        findsNothing,
      );
    });

    testWidgets('general / low: the sentence, 1 segment and "Low"', (
      tester,
    ) async {
      await pump(tester, subcategory: 'general', confidence: 'low');

      expect(find.text(generalProcedureText), findsOneWidget);
      expect(filled(tester), 1);
      // The word beside the bar, plus the Low priority chip of step 3.
      expect(find.text('Low'), findsNWidgets(2));
    });

    testWidgets('unrecognised subcategory: the sentence and no bar', (
      tester,
    ) async {
      await pump(tester, subcategory: 'mystery', confidence: 'high');

      expect(find.text(generalProcedureText), findsOneWidget);
      expect(find.text('Confidence'), findsNothing);
      expect(
        find.byKey(const ValueKey('confidence-segment-0-on')),
        findsNothing,
      );
    });

    testWidgets('no saved detection: no card, note or safety notes', (
      tester,
    ) async {
      await pump(
        tester,
        subcategory: '',
        confidence: '',
        fromKnowledgeBase: true,
      );

      expect(find.text('Based on'), findsNothing);
      expect(find.text(_fallbackNote), findsNothing);
      expect(find.text('Safety Notes'), findsNothing);
    });
  });

  group('fallback note', () {
    testWidgets('shown for a fallback checklist, between the card and the '
        'safety notes', (tester) async {
      await pump(tester, fromKnowledgeBase: true);

      expect(find.text(_fallbackNote), findsOneWidget);
      final card = tester.getTopLeft(find.text('Based on')).dy;
      final note = tester.getTopLeft(find.text(_fallbackNote)).dy;
      final safety = tester.getTopLeft(find.text('Safety Notes')).dy;
      expect(card, lessThan(note));
      expect(note, lessThan(safety));
    });

    testWidgets('not shown for an AI checklist', (tester) async {
      await pump(tester);
      expect(find.text(_fallbackNote), findsNothing);
      expect(find.text('Inform the customer first'), findsOneWidget);
    });
  });

  group('safety notes card', () {
    const key = ValueKey('safety-notes-card');

    testWidgets('a plain white card: no bar or tint, dark bullet text', (
      tester,
    ) async {
      await pump(tester);

      final card = tester.widget<Container>(find.byKey(key));
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.surfaceCard);
      expect(decoration.borderRadius, AppRadius.brLg);
      expect(decoration.boxShadow, AppShadows.card);
      expect(decoration.border, isNull);

      // The card's own box is the only decoration: no accent bar inside it.
      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(DecoratedBox),
        ),
        findsOneWidget,
      );

      final note = tester.widget<Text>(find.text('Inform the customer first'));
      expect(note.style!.color, AppColors.ink);
      expect(find.text('\u2022'), findsOneWidget);
      expect(find.text('Safety Notes'), findsOneWidget);
    });

    testWidgets('no card when there are no notes', (tester) async {
      await pump(tester, safetyNotes: const []);

      expect(find.byKey(key), findsNothing);
      expect(find.text('Safety Notes'), findsNothing);
    });
  });

  group('pinned bar', () {
    testWidgets('not all ticked: only Regenerate, at the bottom', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, onGenerate: () => taps++);

      expect(find.text('Ticket Ready for Report'), findsNothing);
      final button = find.text('Regenerate Checklist');
      expect(
        find.ancestor(of: button, matching: find.byType(ListView)),
        findsNothing,
      );
      expect(tester.getCenter(button).dy, greaterThan(1500));
      await tester.tap(button);
      expect(taps, 1);
    });

    testWidgets('all ticked: Ready above Regenerate, list ends above them', (
      tester,
    ) async {
      var ready = 0;
      await pump(
        tester,
        done: const [true, true, true],
        onReady: () => ready++,
      );

      final readyText = find.text('Ticket Ready for Report');
      final regenerate = find.text('Regenerate Checklist');
      expect(
        tester.getCenter(readyText).dy,
        lessThan(tester.getCenter(regenerate).dy),
      );
      expect(
        tester.getBottomLeft(find.byType(ListView)).dy,
        lessThan(tester.getTopLeft(readyText).dy),
      );
      await tester.tap(readyText);
      expect(ready, 1);
    });

    testWidgets('generating: disabled, with the hint under the button', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        isGenerating: true,
        showSlowHint: true,
        onGenerate: () => taps++,
      );

      final button = find.text('Generating...');
      await tester.tap(button);
      expect(taps, 0);
      final hint = find.textContaining('Still working');
      expect(
        tester.getTopLeft(hint).dy,
        greaterThan(tester.getBottomLeft(button).dy),
      );
    });

    testWidgets('no checklist yet: the empty state and no bar', (tester) async {
      await pump(tester, count: 0, done: const []);

      expect(find.text('No checklist yet'), findsOneWidget);
      expect(find.text('Generate AI Checklist'), findsOneWidget);
      expect(find.text('Regenerate Checklist'), findsNothing);
    });

    testWidgets('a long list can be scrolled to its last item', (tester) async {
      await pump(tester, count: 12, done: List.filled(12, true));

      await tester.scrollUntilVisible(find.text('Detail 12'), 300);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(
        tester
            .getBottomLeft(find.byKey(const ValueKey('checklist-item-11')))
            .dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.text('Ticket Ready for Report')).dy,
        ),
      );
    });
  });

  group('ticked items', () {
    BoxDecoration card(WidgetTester tester, int i) {
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(ValueKey('checklist-item-$i')),
              matching: find.byType(Container),
            )
            .first,
      );
      return box.decoration! as BoxDecoration;
    }

    testWidgets('struck through with muted text; the card is unchanged', (
      tester,
    ) async {
      await pump(tester, done: const [true, false, false]);

      final ticked = tester.widget<Text>(find.text('Step 1')).style!;
      final open = tester.widget<Text>(find.text('Step 2')).style!;
      expect(ticked.decoration, TextDecoration.lineThrough);
      expect(ticked.color, AppColors.inkFaint);
      expect(open.decoration, isNot(TextDecoration.lineThrough));
      expect(open.color, AppColors.ink);

      for (final i in [0, 1]) {
        expect(card(tester, i).color, AppColors.surfaceCard);
        expect(card(tester, i).boxShadow, AppShadows.card);
        expect(card(tester, i).border, isNull);
      }
    });

    testWidgets('the checkbox tap area stays 44 px', (tester) async {
      await pump(tester);
      final tap = find.descendant(
        of: find.byKey(const ValueKey('checklist-item-0')),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(tap), const Size(44, 44));
    });
  });
}
