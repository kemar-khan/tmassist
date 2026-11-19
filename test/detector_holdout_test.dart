// A hold-out accuracy MEASUREMENT for SubcategoryDetector, not a regression
// gate: it never fails when a row misses. It prints one line per row, then the
// hit rate and the misses. Add your own rows to [holdoutRows].
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/core/services/subcategory_detector.dart';

/// One hold-out row: the ticket text, the Gemini category and the subcategory
/// that should be found.
typedef HoldoutRow = (String text, String category, String expected);

/// HOLD-OUT TABLE, round 1. Add your own rows at the end.
const List<HoldoutRow> holdoutRows = [
  (
    'Wifi tak boleh connect langsung, tapi lampu internet kat router hijau',
    'Network',
    'wifi_issue',
  ),
  ('Lampu LOS merah berkelip', 'Network', 'fiber_loss'),
  ('No dial tone on my home phone since yesterday', 'Software', 'voip_issue'),
  (
    'Internet slow only during night time, 8pm to midnight',
    'Network',
    'speed_degradation',
  ),
  ('Router panas dan restart sendiri', 'Hardware', 'router_failure'),
  ('My internet keeps dropping every hour', 'Network', 'intermittent'),
  (
    'Cannot access Netflix and YouTube but WhatsApp works',
    'Network',
    'dns_issue',
  ),
  ('ONU green light but AUTH light is off', 'Network', 'onu_auth_failure'),
  (
    'Wire on the wall socket is loose and the cover is broken',
    'Hardware',
    'cable_damage',
  ),
  (
    'Cannot login to my Unifi account, forgot password',
    'Software',
    'pppoe_auth',
  ),
  ('I want to change my package to 300Mbps', 'Other', 'general'),
  ('Bill bulan ni mahal sangat, tolong check', 'Other', 'general'),
  ('TV channel hilang separuh, ada yang tak keluar', 'Software', 'vlan_config'),
  ('Internet putus sambung putus sambung', 'Network', 'intermittent'),
  (
    'Speedtest shows only 20Mbps but I pay for 100Mbps',
    'Network',
    'speed_degradation',
  ),
  ('ONU is burning hot and smells', 'Hardware', 'ont_failure'),
];

/// HOLD-OUT TABLE, round 2 (author-written). Add your own rows at the end.
const List<HoldoutRow> holdoutRowsRound2 = [
  (
    'Dah 2 hari tak ada internet, semua lampu kat modem padam',
    'Network',
    'ont_failure',
  ),
  ('Wifi kat bilik atas lemah sangat, kat bawah okay', 'Network', 'wifi_issue'),
  (
    'TV Unifi tiba-tiba takde channel langsung, skrin hitam',
    'Software',
    'vlan_config',
  ),
  (
    'Telefon rumah berbunyi sibuk je bila call keluar',
    'Software',
    'voip_issue',
  ),
  (
    'Speed laju waktu pagi tapi lembap gila lepas maghrib',
    'Network',
    'speed_degradation',
  ),
  (
    'Technician pasang fiber semalam, tapi hari ni internet kejap ada kejap tak',
    'Network',
    'intermittent',
  ),
  ('My cat chewed the fibre cable near the router', 'Hardware', 'cable_damage'),
  (
    'Unifi app says authentication failed, password sudah betul',
    'Software',
    'pppoe_auth',
  ),
  ('Boleh tak check kenapa bil naik RM30 bulan ni?', 'Other', 'general'),
  (
    'Saya nak pindah rumah hujung bulan, macam mana nak transfer Unifi?',
    'Other',
    'general',
  ),
];

/// Runs one table and prints a line per row. Returns the misses as
/// "label: one-line reason" strings.
({int hits, List<String> misses}) runRound(
  String label,
  List<HoldoutRow> rows,
) {
  final misses = <String>[];
  var hits = 0;

  print('');
  print('=== $label ===');
  for (var i = 0; i < rows.length; i++) {
    final (text, category, expected) = rows[i];
    final r = SubcategoryDetector.detect(
      category: category,
      title: '',
      description: text,
    );
    final hit = r.subcategory == expected;
    if (hit) hits++;

    // The runner-up (second best subcategory with any match) and, when the
    // expected answer is not the winner, what the expected one scored.
    final ranked = SubcategoryDetector.rank(
      category: category,
      title: '',
      description: text,
    );
    final runnerUp = ranked.length > 1 ? ranked[1] : null;
    final expectedEntry = ranked.where((e) => e.subcategory == expected);
    final runnerUpText = runnerUp == null
        ? 'none'
        : '${runnerUp.subcategory} score=${runnerUp.score} '
              'matched=${runnerUp.matchedTerms}';
    final expectedText = expected == 'general'
        ? ''
        : (expectedEntry.isEmpty
              ? ' | expected scored: no match at all'
              : ' | expected scored: score=${expectedEntry.first.score} '
                    'matched=${expectedEntry.first.matchedTerms}');

    print(
      '#${i + 1} expected=$expected got=${r.subcategory} '
      'confidence=${r.confidence} score=${r.score} '
      'matched=${r.matchedTerms} ${hit ? 'HIT' : 'MISS'}',
    );
    print('     runner-up: $runnerUpText${hit ? '' : expectedText}');

    if (!hit) {
      misses.add(
        '$label #${i + 1} "$text": expected $expected, got ${r.subcategory} '
        '(score ${r.score}, matched ${r.matchedTerms}); '
        'runner-up $runnerUpText${expectedText.isEmpty ? '' : expectedText}',
      );
    }
  }

  final percent = (hits * 100 / rows.length).toStringAsFixed(1);
  print('--- $label hit rate: $hits/${rows.length} ($percent%)');
  return (hits: hits, misses: misses);
}

void main() {
  test('hold-out accuracy (measurement only, never fails on a miss)', () {
    final r1 = runRound('Round 1', holdoutRows);
    final r2 = runRound('Round 2 (author-written)', holdoutRowsRound2);

    final total = holdoutRows.length + holdoutRowsRound2.length;
    final hits = r1.hits + r2.hits;
    final percent = (hits * 100 / total).toStringAsFixed(1);
    print('');
    print('=== Combined ===');
    print('Round 1: ${r1.hits}/${holdoutRows.length}');
    print('Round 2: ${r2.hits}/${holdoutRowsRound2.length}');
    print('Total: $hits/$total ($percent%)');
    final misses = [...r1.misses, ...r2.misses];
    print('Misses (${misses.length}):');
    for (final m in misses) {
      print('  - $m');
    }
    if (misses.isEmpty) print('  none');

    // A measurement: only checks that it ran.
    expect(total, greaterThan(0));
  });
}
