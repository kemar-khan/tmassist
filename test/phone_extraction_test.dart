import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/core/services/ai_extraction_service.dart';
import 'package:tmassist/utils/phone_clean.dart';

void main() {
  group('cleanExtractedPhone', () {
    test('Malaysian formats become digits starting with 0', () {
      expect(cleanExtractedPhone('012-345 6789'), '0123456789');
      expect(cleanExtractedPhone('0123456789'), '0123456789');
      expect(cleanExtractedPhone('03-1234 5678'), '0312345678');
      expect(cleanExtractedPhone('+60 12-345 6789'), '0123456789');
      expect(cleanExtractedPhone('6012 3456789'), '0123456789');
      expect(cleanExtractedPhone('+6012-3456789'), '0123456789');
      expect(cleanExtractedPhone('(012) 345-6789'), '0123456789');
    });

    test('9 and 11 digit numbers are accepted', () {
      expect(cleanExtractedPhone('03-1234567'), '031234567'); // 9 digits
      expect(cleanExtractedPhone('011-1234 5678'), '01112345678'); // 11
    });

    test('too short, too long, letters and empty are rejected', () {
      expect(cleanExtractedPhone('0123'), '');
      expect(cleanExtractedPhone('01234567'), ''); // 8 digits
      expect(cleanExtractedPhone('012345678901'), ''); // 12 digits
      expect(cleanExtractedPhone('012-ABC 6789'), '');
      expect(cleanExtractedPhone('call me maybe'), '');
      expect(cleanExtractedPhone(''), '');
      expect(cleanExtractedPhone(null), '');
      expect(cleanExtractedPhone('   '), '');
    });

    test('numbers that do not start with 0 are rejected', () {
      expect(cleanExtractedPhone('1234567890'), '');
      expect(cleanExtractedPhone('300'), '');
      expect(cleanExtractedPhone('+65 9123 4567'), '');
    });
  });

  group('parseExtraction', () {
    test('a response with a phone number', () {
      final r = AiExtractionService.parseExtraction('''
{
  "isRelevant": "true",
  "category": "Network",
  "title": "Internet Down",
  "description": "No internet since morning.",
  "address": "Puchong, Selangor",
  "area": "Puchong",
  "phone": "012-345 6789"
}''');
      expect(r['phone'], '0123456789');
      expect(r['category'], 'Network');
      expect(r['title'], 'Internet Down');
      expect(r['area'], 'Puchong');
    });

    test('a response with an empty phone', () {
      final r = AiExtractionService.parseExtraction(
        '{"isRelevant":"true","category":"Network","title":"t",'
        '"description":"d","address":"","area":"Klang","phone":""}',
      );
      expect(r['phone'], '');
      expect(r['area'], 'Klang');
    });

    test('a response with no phone key at all (and fenced JSON)', () {
      final r = AiExtractionService.parseExtraction('''```json
{"isRelevant":"true","category":"Hardware","title":"t","description":"d","address":"x","area":"Other"}
```''');
      expect(r['phone'], '');
      expect(r['category'], 'Hardware');
      expect(r.containsKey('phone'), isTrue);
    });

    test('an invalid phone is dropped', () {
      final r = AiExtractionService.parseExtraction(
        '{"isRelevant":"true","category":"Network","title":"t",'
        '"description":"d","address":"","area":"Klang","phone":"300Mbps"}',
      );
      expect(r['phone'], '');
    });

    test('a +60 number is turned into a local number', () {
      final r = AiExtractionService.parseExtraction(
        '{"isRelevant":"true","category":"Network","title":"t",'
        '"description":"d","address":"","area":"Klang","phone":"+60 12-345 6789"}',
      );
      expect(r['phone'], '0123456789');
    });

    test('the six existing keys are unchanged and always present', () {
      final r = AiExtractionService.parseExtraction('{"isRelevant":"false"}');
      expect(r.keys.toSet(), {
        'isRelevant',
        'category',
        'title',
        'description',
        'address',
        'area',
        'phone',
      });
      expect(r['isRelevant'], 'false');
      expect(r['phone'], '');
    });

    test('no JSON at all throws, as before', () {
      expect(
        () => AiExtractionService.parseExtraction('sorry, no'),
        throwsException,
      );
    });
  });
}
