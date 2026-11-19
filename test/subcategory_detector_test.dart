import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/core/services/subcategory_detector.dart';

SubcategoryResult run(String text, String category, {String title = ''}) =>
    SubcategoryDetector.detect(
      category: category,
      title: title,
      description: text,
    );

void main() {
  // text, category, accepted subcategories
  final table = <(int, String, String, Set<String>)>[
    (
      1,
      'Internet down since last night, got red light on the box. Puchong.',
      'Network',
      {'fiber_loss'},
    ),
    (
      2,
      'No internet at all, tried restarting many times still the same. Subang Jaya.',
      'Network',
      {'fiber_loss'},
    ),
    (
      3,
      'Internet very slow, cannot even watch YouTube. Plan is 100Mbps. Shah Alam.',
      'Network',
      {'speed_degradation'},
    ),
    (
      4,
      'Wifi keeps disconnecting every few minutes, very annoying. Klang.',
      'Network',
      {'intermittent'},
    ),
    (
      5,
      'Internet cuts off then comes back by itself, happens many times a day. Cheras.',
      'Network',
      {'intermittent'},
    ),
    (
      6,
      'Wifi weak in my bedroom, cannot get signal there. Petaling Jaya.',
      'Network',
      {'wifi_issue'},
    ),
    (
      7,
      'Internet tak boleh guna, lampu merah. Puchong.',
      'Network',
      {'fiber_loss'},
    ),
    (
      8,
      "The box has no light at all, I think it's spoilt. Kuala Lumpur.",
      'Hardware',
      {'ont_failure'},
    ),
    (
      9,
      'Wire from the wall to the box got bent by my cat, now no internet. Subang Jaya.',
      'Hardware',
      {'cable_damage'},
    ),
    (
      10,
      'My router is hot and keeps restarting. Klang.',
      'Hardware',
      {'router_failure'},
    ),
    (
      11,
      'TV box not working, shows no signal. Shah Alam.',
      'Network',
      {'vlan_config'},
    ),
    (
      12,
      'Home phone cannot make or receive calls. Cheras.',
      'Network',
      {'voip_issue'},
    ),
    (
      13,
      'Cannot log in to my Unifi, says wrong password. Puchong.',
      'Software',
      {'pppoe_auth'},
    ),
    (
      14,
      "Some websites won't open but others are fine. Subang Jaya.",
      'Network',
      {'dns_issue'},
    ),
    (
      15,
      'Technician came last month and changed something, now the internet is not stable. Kuala Lumpur.',
      'Network',
      {'intermittent'},
    ),
    (
      16,
      'My service has a problem, please help. Shah Alam.',
      'Other',
      {'general'},
    ),
  ];

  group('ticket table', () {
    for (final (n, text, category, expected) in table) {
      test('row $n -> ${expected.join(' / ')}', () {
        final r = run(text, category);
        expect(
          expected,
          contains(r.subcategory),
          reason:
              '"$text" ($category) gave ${r.subcategory} '
              '[${r.confidence}, score ${r.score}, ${r.matchedTerms}]',
        );
        if (r.subcategory == 'general') {
          expect(r.confidence, 'low');
          expect(r.matchedTerms, isEmpty);
        } else {
          expect(r.matchedTerms, isNotEmpty);
        }
      });
    }

    test('row 16 is general with low confidence', () {
      final r = run(table.last.$2, 'Other');
      expect(r.subcategory, 'general');
      expect(r.confidence, 'low');
      expect(r.score, 0);
    });
  });

  group('extra cases', () {
    test('TV shows no signal -> vlan_config', () {
      expect(run('TV shows no signal', 'Network').subcategory, 'vlan_config');
    });

    test('TV box not turning on -> ont_failure (power rule beats tv)', () {
      final r = run('TV box not turning on', 'Software');
      expect(r.subcategory, 'ont_failure');
      expect(r.confidence, 'high');
    });

    test('Internet is dead -> fiber_loss', () {
      expect(run('Internet is dead', 'Network').subcategory, 'fiber_loss');
    });

    test('wifi keeps disconnecting -> intermittent', () {
      expect(
        run('wifi keeps disconnecting', 'Network').subcategory,
        'intermittent',
      );
    });

    test('empty title and description -> general, low', () {
      final r = run('', 'Network');
      expect(r.subcategory, 'general');
      expect(r.confidence, 'low');
      expect(r.matchedTerms, isEmpty);
    });

    test('short terms match whole words only', () {
      // "ont" in monthly, "tel1" in tellers, "dns" in dnsx must not count.
      final r = run('monthly tellers dnsx', 'Network');
      expect(r.subcategory, 'general');
      expect(run('monthly bill', 'Other').subcategory, 'general');
      expect(run('tellers', 'Other').subcategory, 'general');
      expect(run('dnsx', 'Other').subcategory, 'general');
      // The same words as whole words do count.
      expect(run('dns problem', 'Other').subcategory, 'dns_issue');
      expect(run('the ont is faulty', 'Other').subcategory, 'ont_failure');
    });

    test('the category is only a hint', () {
      expect(run('Internet is slow', 'Other').subcategory, 'speed_degradation');
      expect(
        run('Internet is slow', 'Software').subcategory,
        'speed_degradation',
      );
    });

    test('the category adds a point only to a subcategory that matched', () {
      final withHint = run('Internet is slow', 'Network');
      final without = run('Internet is slow', 'Other');
      expect(withHint.score, without.score + 1);
      // Hardware has no speed subcategory, so there is no bonus.
      expect(run('Internet is slow', 'Hardware').score, without.score);
    });

    test('a weight-3 term with no rival is high confidence', () {
      final r = run('VoIP is not working', 'Other');
      expect(r.subcategory, 'voip_issue');
      expect(r.score, 3);
      expect(r.confidence, 'high');
    });

    test('a weak match is medium, the fallback is low', () {
      expect(run('Wifi weak in my bedroom', 'Network').confidence, 'medium');
      expect(run('hello', 'Network').confidence, 'low');
    });

    test('a tie goes to the fixed priority order', () {
      // speed_degradation (slow 1) and wifi_issue (wifi 1) tie at 1.
      final r = run('slow wifi', 'Other');
      expect(r.subcategory, 'speed_degradation');
      expect(r.score, 1);
      expect(r.confidence, 'medium');
    });

    test('plain tv wins on score, not on the tie list', () {
      // vlan_config: tv 3. fiber_loss: no signal 1 + Network 1 = 2.
      final r = run('TV shows no signal', 'Network');
      expect(r.subcategory, 'vlan_config');
      expect(r.score, 3);
      expect(r.confidence, 'high');
      // Even with the tie list reversed in favour of fiber_loss, 3 beats 2.
      expect(r.score, greaterThan(2));
    });

    test('a power fault does not override an ONU auth term', () {
      final r = run('power LED on but auth LED red', 'Network');
      expect(r.subcategory, 'onu_auth_failure');
      // The power rule still works without an auth term.
      expect(
        run('TV box not turning on', 'Network').subcategory,
        'ont_failure',
      );
      expect(
        run('TV box not turning on', 'Software').subcategory,
        'ont_failure',
      );
      expect(run('power led is off', 'Network').subcategory, 'ont_failure');
    });

    test('an auth term is not outscored by the category hint', () {
      // Hardware would add +1 to ont_failure (power led 3 -> 4) and beat the
      // auth term (3); with an auth term the bonus goes to auth only.
      final hardware = run('power LED on but auth LED red', 'Hardware');
      expect(hardware.subcategory, 'onu_auth_failure');
      final network = run('power LED on but auth LED red', 'Network');
      expect(network.subcategory, 'onu_auth_failure');
      expect(network.score, 4); // 3 + the Network hint, on auth only
      // Without an auth term the Hardware hint still counts for ont_failure.
      expect(run('power led is off', 'Hardware').subcategory, 'ont_failure');
    });

    test('voice is a whole word: invoice does not match', () {
      final r = run('question about my invoice', 'Other');
      expect(r.subcategory, 'general');
      expect(r.confidence, 'low');
      // As a word it still counts.
      expect(run('no voice on the line', 'Other').subcategory, 'voip_issue');
      expect(run('voice problem', 'Other').subcategory, 'voip_issue');
    });

    test('Malay terms work', () {
      expect(run('internet lambat', 'Other').subcategory, 'speed_degradation');
      expect(run('wifi lemah di bilik', 'Other').subcategory, 'wifi_issue');
      expect(
        run('telefon rumah tiada nada dail', 'Other').subcategory,
        'voip_issue',
      );
      expect(run('kabel rosak', 'Other').subcategory, 'cable_damage');
      expect(run('putus-putus', 'Other').subcategory, 'intermittent');
      expect(run('lampu merah', 'Other').subcategory, 'fiber_loss');
      expect(run('laman web tak boleh buka', 'Other').subcategory, 'dns_issue');
      expect(run('tiada kuasa pada modem', 'Other').subcategory, 'ont_failure');
      expect(run('siaran tv tiada', 'Other').subcategory, 'vlan_config');
    });

    test('the title counts as well as the description', () {
      expect(
        run('please help', 'Other', title: 'DNS problem').subcategory,
        'dns_issue',
      );
    });

    test('internet down phrases -> fiber_loss', () {
      expect(run('Internet down', 'Network').subcategory, 'fiber_loss');
      expect(
        run('Internet is down since this morning', 'Other').subcategory,
        'fiber_loss',
      );
      expect(run('Internet not working', 'Network').subcategory, 'fiber_loss');
      expect(
        run('internet outage in my area', 'Other').subcategory,
        'fiber_loss',
      );
      expect(run('internet mati', 'Other').subcategory, 'fiber_loss');
      expect(run('internet tak jalan', 'Other').subcategory, 'fiber_loss');
    });

    test('plain "down" is not a fiber_loss term', () {
      final tv = run('TV is down', 'Software');
      expect(tv.subcategory, isNot('fiber_loss'));
      expect(['general', 'vlan_config'], contains(tv.subcategory));
      expect(run('the server is down', 'Network').subcategory, 'general');
    });

    test('"down" inside download does not match', () {
      expect(
        run('download is slow', 'Network').subcategory,
        'speed_degradation',
      );
      // Not even as part of "internet download".
      final r = run('internet download is slow', 'Other');
      expect(r.subcategory, 'speed_degradation');
      expect(r.matchedTerms, isNot(contains('internet down')));
    });

    test('new wifi phrases: tak boleh / tak dapat connect', () {
      expect(
        run('wifi tak boleh connect', 'Network').subcategory,
        'wifi_issue',
      );
      expect(
        run('laptop tak dapat connect ke wifi', 'Other').subcategory,
        'wifi_issue',
      );
    });

    test('new intermittent phrases: putus sambung / sambung putus', () {
      expect(
        run('internet putus sambung', 'Network').subcategory,
        'intermittent',
      );
      expect(
        run('line sambung putus sepanjang hari', 'Other').subcategory,
        'intermittent',
      );
    });

    test('new dns phrases: some / certain sites, some apps', () {
      expect(run('some sites not opening', 'Network').subcategory, 'dns_issue');
      expect(
        run('certain sites will not load', 'Other').subcategory,
        'dns_issue',
      );
      expect(
        run('some apps will not load', 'Network').subcategory,
        'dns_issue',
      );
      // No app or site names were added as terms.
      expect(run('Netflix will not load', 'Network').subcategory, 'general');
    });

    test('lights-off phrases -> ont_failure', () {
      expect(
        run('all lights off on the modem', 'Hardware').subcategory,
        'ont_failure',
      );
      expect(run('semua lampu padam', 'Hardware').subcategory, 'ont_failure');
      expect(run('lampu padam pada modem', 'Other').subcategory, 'ont_failure');
      // "lampu mati" is deliberately not a term.
      expect(run('lampu mati', 'Hardware').subcategory, 'general');
    });

    test('"kejap ada kejap tak" -> intermittent', () {
      expect(
        run(
          'Technician pasang fiber semalam, tapi hari ni internet kejap ada kejap tak',
          'Network',
        ).subcategory,
        'intermittent',
      );
    });

    test('internet down with a red light is still fiber_loss', () {
      expect(
        run('Internet down, red light on the box', 'Network').subcategory,
        'fiber_loss',
      );
    });

    test('the tie priority list has every subcategory once', () {
      expect(SubcategoryDetector.tiePriority.length, 12);
      expect(SubcategoryDetector.tiePriority.toSet().length, 12);
    });
  });
}
