import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/similar_cases.dart';
import 'package:tmassist/utils/subcategory_labels.dart';

const goodNote = 'Replaced the damaged fibre patch cord at the ONU';

SimilarCandidate c(String id, String? sub, {String? notes = goodNote}) =>
    SimilarCandidate(id: id, subcategory: sub, notes: notes);

List<String> ids(SimilarSelection s) => [for (final x in s.chosen) x.id];

void main() {
  group('chooseSimilarCases', () {
    test('only the same subcategory, at most 3, input order kept', () {
      final s = chooseSimilarCases(
        [
          c('a', 'dns_issue'),
          c('b', 'fiber_loss'),
          c('c', 'fiber_loss'),
          c('d', 'fiber_loss'),
          c('e', 'fiber_loss'),
        ],
        currentSubcategory: 'fiber_loss',
        currentTicketId: 'cur',
      );
      expect(ids(s), ['b', 'c', 'd']);
    });

    test('no same-category fill-in: other subcategories are never used', () {
      final s = chooseSimilarCases(
        [
          c('a', 'dns_issue'),
          c('b', 'fiber_loss'),
          c('c', null),
          c('d', 'wifi_issue'),
        ],
        currentSubcategory: 'fiber_loss',
        currentTicketId: 'cur',
      );
      expect(ids(s), ['b']);
    });

    test('none qualify: empty, so the prompt has no past-cases section', () {
      final s = chooseSimilarCases(
        [c('a', 'dns_issue'), c('b', null), c('c', 'wifi_issue')],
        currentSubcategory: 'fiber_loss',
        currentTicketId: 'cur',
      );
      expect(s.chosen, isEmpty);
    });

    test('same-subcategory tickets without a usable report are skipped', () {
      final s = chooseSimilarCases(
        [
          c('a', 'fiber_loss', notes: 'ok'),
          c('b', 'fiber_loss', notes: 'ok'),
          c('c', 'fiber_loss'),
          c('d', 'dns_issue'),
        ],
        currentSubcategory: 'fiber_loss',
        currentTicketId: 'cur',
      );
      expect(ids(s), ['c']);
    });

    test('the current ticket is excluded', () {
      final s = chooseSimilarCases(
        [c('cur', 'fiber_loss'), c('a', 'fiber_loss'), c('b', 'fiber_loss')],
        currentSubcategory: 'fiber_loss',
        currentTicketId: 'cur',
      );
      expect(ids(s), ['a', 'b']);
    });

    test('older tickets without a saved subcategory are never chosen', () {
      final s = chooseSimilarCases(
        [c('a', null), c('b', null), c('c', null)],
        currentSubcategory: 'fiber_loss',
        currentTicketId: 'cur',
      );
      expect(s.chosen, isEmpty);
    });

    test('the general subcategory only matches general tickets', () {
      final s = chooseSimilarCases(
        [c('a', 'general'), c('b', 'fiber_loss'), c('c', null)],
        currentSubcategory: 'general',
        currentTicketId: 'cur',
      );
      expect(ids(s), ['a']);
    });
  });

  group('isMeaningfulNote', () {
    test('needs 20 characters and 4 words', () {
      expect(isMeaningfulNote(goodNote), isTrue);
      expect(isMeaningfulNote('Replaced the patch cord at ONU'), isTrue);
      expect(isMeaningfulNote('gud'), isFalse);
      expect(isMeaningfulNote('ok'), isFalse);
      expect(isMeaningfulNote(null), isFalse);
      expect(isMeaningfulNote('   '), isFalse);
      // 20+ characters but only 3 words.
      expect(
        isMeaningfulNote('Replacedtheentirepatchcord quickly done'),
        isFalse,
      );
      // 4 words but under 20 characters.
      expect(isMeaningfulNote('a b c d'), isFalse);
      expect(minNoteChars, 20);
      expect(minNoteWords, 4);
    });

    test('only meaningful notes make a candidate usable', () {
      expect(c('a', 'x').usable, isTrue);
      expect(c('a', 'x', notes: 'gud').usable, isFalse);
      expect(c('a', 'x', notes: null).usable, isFalse);
    });
  });

  group('basedOnLine', () {
    test('high and medium show the name and confidence', () {
      expect(
        basedOnLine('fiber_loss', 'high'),
        'Based on: Fiber loss / no connection | Confidence: High',
      );
      expect(
        basedOnLine('wifi_issue', 'medium'),
        'Based on: Wi-Fi issue | Confidence: Medium',
      );
    });

    test('low or general show the general line', () {
      const general = 'General procedure: the issue was not clearly identified';
      expect(basedOnLine('general', 'low'), general);
      expect(basedOnLine('general', 'high'), general);
      expect(basedOnLine('fiber_loss', 'low'), general);
      expect(basedOnLine('mystery', 'high'), general);
    });

    test('old tickets without the fields show nothing', () {
      expect(basedOnLine(null, null), isNull);
      expect(basedOnLine('', ''), isNull);
      expect(basedOnLine('fiber_loss', null), isNull);
      expect(basedOnLine(null, 'high'), isNull);
    });

    test('every subcategory id has a readable name', () {
      expect(subcategoryNames.length, 13);
      expect(subcategoryNames.values.toSet().length, 13);
    });
  });
}
