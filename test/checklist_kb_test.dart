import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/core/services/checklist_service.dart';
import 'package:tmassist/utils/checklist_kb.dart';

const sample = '''
TM Example — Field Procedures:

Common Causes:
- Something broke

Field Procedures:
1. Check the ONU LAN1 LED is white and that LAN1 connects to the PG WAN port
2. Verify the VLAN for the affected service: internet 500, IPTV 600, voice 400
3. Reboot in order: ONU, then PG, then STB (general practice)

Safety Notes:
- Changing VLAN settings causes a brief outage, so inform the customer first
- Record the original settings before changing them

Source: TM Training Centre
''';

const noSafety = '''
Title:

Field Procedures:
1. Do the first thing
2. Do the second thing
''';

void main() {
  group('safetyNotesFromKb', () {
    test('normal entry: the bullet lines, stopping at the blank line', () {
      expect(safetyNotesFromKb(sample), [
        'Changing VLAN settings causes a brief outage, so inform the customer first',
        'Record the original settings before changing them',
      ]);
    });

    test('stops at a Source line with no blank line before it', () {
      const kb = 'Safety Notes:\n- One\n- Two\nSource: x\n- Three';
      expect(safetyNotesFromKb(kb), ['One', 'Two']);
    });

    test('an entry without a safety section gives nothing', () {
      expect(safetyNotesFromKb(noSafety), isEmpty);
      expect(safetyNotesFromKb(''), isEmpty);
    });
  });

  group('field procedures and the fallback', () {
    test('numbered lines under Field Procedures, in order', () {
      expect(fieldProceduresFromKb(sample), [
        'Check the ONU LAN1 LED is white and that LAN1 connects to the PG WAN port',
        'Verify the VLAN for the affected service: internet 500, IPTV 600, voice 400',
        'Reboot in order: ONU, then PG, then STB (general practice)',
      ]);
    });

    test('short titles are action phrases of at most 8 words', () {
      expect(
        shortActionTitle(
          'Check the ONU LAN1 LED is white and that LAN1 connects to the PG WAN port',
        ),
        'Check the ONU LAN1 LED is white',
      );
      expect(
        shortActionTitle(
          'Verify the VLAN for the affected service: internet 500',
        ),
        'Verify the VLAN for the affected service',
      );
      expect(
        shortActionTitle('Reboot in order: ONU, then PG, then STB'),
        'Reboot in order',
      );
      expect(
        shortActionTitle('One two three four five six seven eight nine ten'),
        'One two three four five six seven eight',
      );
    });

    test('priority by position, detail exact, time 5 mins, max 8', () {
      final kb = [
        'Field Procedures:',
        for (var i = 1; i <= 10; i++) '$i. Step number $i here',
      ].join('\n');
      final items = fallbackChecklistFromKb(kb);
      expect(items.length, 8);
      expect(
        [for (final i in items) i['priority']],
        ['High', 'High', 'High', 'Medium', 'Medium', 'Medium', 'Low', 'Low'],
      );
      expect(items.first['detail'], 'Step number 1 here');
      expect(items.every((i) => i['estimatedTime'] == '5 mins'), isTrue);
    });

    void checkEntry(String subcategory) {
      final items = ChecklistService.fallbackChecklistFor(subcategory);
      expect(items, isNotEmpty, reason: subcategory);
      expect(items.length, lessThanOrEqualTo(8));
      for (final i in items) {
        expect(i['title'], isNotEmpty);
        expect(i['title']!.split(' ').length, lessThanOrEqualTo(8));
        expect(i['detail'], isNotEmpty);
        expect(['High', 'Medium', 'Low'], contains(i['priority']));
        expect(i['estimatedTime'], '5 mins');
      }
    }

    test('vlan_config fallback', () {
      checkEntry('vlan_config');
      final items = ChecklistService.fallbackChecklistFor('vlan_config');
      expect(items.length, 8);
      expect(
        items.first['detail'],
        'Confirm which service is affected: internet, IPTV or voice',
      );
      expect(items.first['priority'], 'High');
      expect(items.last['priority'], 'Low');
    });

    test('fiber_loss fallback', () {
      checkEntry('fiber_loss');
    });

    test('general fallback (the default entry)', () {
      checkEntry('general');
      expect(
        ChecklistService.fallbackChecklistFor('no_such_entry'),
        isNotEmpty,
      );
    });

    test('safety notes of the real entries', () {
      expect(ChecklistService.safetyNotesFor('vlan_config'), [
        'Changing VLAN settings causes a brief outage, so inform the customer first',
        'Record the original settings before changing them',
      ]);
      // Every entry can be read without error; none keeps a bullet marker.
      for (final id in [
        'fiber_loss',
        'onu_auth_failure',
        'wifi_issue',
        'speed_degradation',
        'intermittent',
        'ont_failure',
        'router_failure',
        'cable_damage',
        'pppoe_auth',
        'vlan_config',
        'voip_issue',
        'dns_issue',
        'general',
      ]) {
        for (final note in ChecklistService.safetyNotesFor(id)) {
          expect(note.startsWith('- '), isFalse, reason: id);
          expect(note, isNotEmpty);
        }
      }
    });
  });

  group('knowledge-base sourcing (Step C)', () {
    const twelve = [
      'fiber_loss',
      'onu_auth_failure',
      'wifi_issue',
      'speed_degradation',
      'intermittent',
      'ont_failure',
      'router_failure',
      'cable_damage',
      'pppoe_auth',
      'vlan_config',
      'voip_issue',
      'dns_issue',
    ];
    // The default entry is what any other id returns.
    const all = [...twelve, 'general'];

    String kb(String id) => ChecklistService.knowledgeBaseFor(id);

    test('every entry has a Source line', () {
      for (final id in all) {
        final lines = kb(id).split('\n');
        expect(
          lines.where((l) => l.startsWith('Source:')).length,
          1,
          reason: '$id needs exactly one Source: line',
        );
      }
      expect(kb('no_such_entry'), kb('general'));
    });

    test('no entry contains streamyx.com or unifi.my', () {
      for (final id in all) {
        expect(kb(id).contains('streamyx.com'), isFalse, reason: id);
        expect(kb(id).contains('unifi.my'), isFalse, reason: id);
      }
    });

    test('dns_issue: DNS is only changed temporarily, and restored', () {
      final entry = kb('dns_issue');
      final steps = fieldProceduresFromKb(entry);
      expect(steps.length, 8);

      // Step 5 is temporary and says not to leave it changed.
      expect(steps[4], contains('Temporarily'));
      expect(steps[4], contains('do not leave it changed'));
      expect(steps.any((s) => s.startsWith('Change primary DNS')), isFalse);

      // 8.8.8.8 appears only in steps 1 and 5.
      final withIp = [
        for (var i = 0; i < steps.length; i++)
          if (steps[i].contains('8.8.8.8')) i + 1,
      ];
      expect(withIp, [1, 5]);
      expect('8.8.8.8'.allMatches(entry).length, 2);

      // Step 7 restores the original setting.
      expect(steps[6], contains('restore the original DNS setting'));

      // The safety note is the restore line.
      expect(ChecklistService.safetyNotesFor('dns_issue'), [
        'Note the original DNS addresses before any test and restore them afterwards',
      ]);
    });

    test('pppoe_auth: step 3 uses the username@unifi format', () {
      final steps = fieldProceduresFromKb(kb('pppoe_auth'));
      expect(
        steps[2],
        'Verify PPPoE username format — TM format: username@unifi or username@streamyx',
      );
      expect(steps[2], contains('username@unifi'));
      // The portal, NOC and RADIUS steps are still there.
      expect(steps.any((s) => s.contains('technician portal')), isTrue);
      expect(
        steps.any((s) => s.contains('RADIUS') && s.contains('NOC')),
        isTrue,
      );
    });

    test('safety notes and the fallback work for every entry; Source is not '
        'a checklist item or a safety note', () {
      for (final id in all) {
        final notes = ChecklistService.safetyNotesFor(id);
        expect(notes.any((n) => n.startsWith('Source')), isFalse, reason: id);

        final steps = fieldProceduresFromKb(kb(id));
        expect(steps, isNotEmpty, reason: id);
        expect(steps.any((s) => s.startsWith('Source')), isFalse, reason: id);

        final items = ChecklistService.fallbackChecklistFor(id);
        expect(items, isNotEmpty, reason: id);
        expect(items.length, lessThanOrEqualTo(8), reason: id);
        for (final item in items) {
          expect(item['detail']!.startsWith('Source'), isFalse, reason: id);
          expect(item['title'], isNotEmpty, reason: id);
        }
      }
    });
  });
}
