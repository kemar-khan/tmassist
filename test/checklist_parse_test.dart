import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/checklist_parse.dart';

void main() {
  const clean = '''
[
  {"title": "Check the LED", "detail": "Look at the ONU LEDs.", "priority": "High", "estimatedTime": "5 mins"},
  {"title": "Test the line", "detail": "Run the check.", "priority": "Medium", "estimatedTime": "10 mins"}
]''';

  test('clean JSON', () {
    final items = parseChecklistResponse(clean);
    expect(items.length, 2);
    expect(items.first, {
      'title': 'Check the LED',
      'detail': 'Look at the ONU LEDs.',
      'priority': 'High',
      'estimatedTime': '5 mins',
    });
    expect(items.last['priority'], 'Medium');
  });

  test('fenced JSON, with and without the language tag', () {
    expect(parseChecklistResponse('```json\n$clean\n```').length, 2);
    expect(parseChecklistResponse('```\n$clean\n```').length, 2);
    expect(
      parseChecklistResponse('Here you go:\n```json\n$clean\n```').length,
      2,
    );
  });

  test('escaped quotes and braces inside a value', () {
    const raw = r'''[
  {"title": "Read the \"AUTH\" LED", "detail": "Note the {state} and the JSON-like {\"a\": 1} text.", "priority": "High", "estimatedTime": "5 mins"}
]''';
    final items = parseChecklistResponse(raw);
    expect(items.length, 1);
    expect(items.first['title'], 'Read the "AUTH" LED');
    expect(
      items.first['detail'],
      'Note the {state} and the JSON-like {"a": 1} text.',
    );
  });

  test('items are validated: bad priority and missing time get defaults', () {
    final items = parseChecklistResponse(
      '[{"title":"A","detail":"B","priority":"urgent"},'
      '{"title":"C","detail":"D","priority":"low","estimatedTime":""}]',
    );
    expect(items[0]['priority'], 'Medium');
    expect(items[0]['estimatedTime'], '10 mins');
    expect(items[1]['priority'], 'Low');
    expect(items[1]['estimatedTime'], '10 mins');
  });

  test('items without a title or detail are skipped', () {
    final items = parseChecklistResponse(
      '[{"title":"","detail":"x"},{"detail":"y"},'
      '{"title":"ok","detail":"fine","priority":"High","estimatedTime":"5 mins"},'
      '"just a string", 7]',
    );
    expect(items.length, 1);
    expect(items.single['title'], 'ok');
  });

  test('a wrapped object with items is accepted', () {
    final items = parseChecklistResponse(
      '{"items": [{"title":"A","detail":"B","priority":"High","estimatedTime":"5 mins"}]}',
    );
    expect(items.length, 1);
  });

  test('broken JSON falls back to the regex reader', () {
    // A trailing comma and a missing bracket make jsonDecode fail.
    const raw = '''[
  {"title": "One", "detail": "First step", "priority": "High", "estimatedTime": "5 mins"},
  {"title": "Two", "detail": "Second step", "priority": "Low", "estimatedTime": "10 mins"},
''';
    final items = parseChecklistResponse(raw);
    expect(items.length, 2);
    expect(items.first['title'], 'One');
    expect(items.last['priority'], 'Low');
  });

  test('garbage and empty input give an empty list', () {
    expect(parseChecklistResponse('I am sorry, I cannot do that.'), isEmpty);
    expect(parseChecklistResponse(''), isEmpty);
    expect(parseChecklistResponse('[[[ not json ]]]'), isEmpty);
    expect(parseChecklistResponse('{"a": 1}'), isEmpty);
    expect(parseChecklistResponse('[]'), isEmpty);
  });
}
