import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/area_grouping.dart';
import 'package:tmassist/utils/canonical_area.dart';

void main() {
  test('an exact name stays as it is', () {
    expect(canonicalArea('Puchong'), 'Puchong');
    expect(canonicalArea('Subang Jaya'), 'Subang Jaya');
    expect(canonicalArea('Other'), 'Other');
  });

  test('lowercase and uppercase give the canonical spelling', () {
    expect(canonicalArea('puchong'), 'Puchong');
    expect(canonicalArea('PUCHONG'), 'Puchong');
    expect(canonicalArea('kuala lumpur'), 'Kuala Lumpur');
    expect(canonicalArea('SHAH ALAM'), 'Shah Alam');
  });

  test('extra spaces around the name are ignored', () {
    expect(canonicalArea('  puchong '), 'Puchong');
    expect(canonicalArea('\tKlang\n'), 'Klang');
  });

  test('spaces inside the name still have to match', () {
    expect(canonicalArea('Subang  Jaya'), isNull);
    expect(canonicalArea('SubangJaya'), isNull);
  });

  test('an unknown name, null and empty give null', () {
    expect(canonicalArea('Ipoh'), isNull);
    expect(canonicalArea('Pucong'), isNull);
    expect(canonicalArea(null), isNull);
    expect(canonicalArea(''), isNull);
    expect(canonicalArea('   '), isNull);
  });

  test('areaOfTicket already matches an address ignoring case', () {
    expect(
      areaOfTicket(address: 'no 8, jalan ss 15/4, SUBANG JAYA'),
      'Subang Jaya',
    );
    expect(areaOfTicket(address: 'puchong perdana'), 'Puchong');
  });
}
