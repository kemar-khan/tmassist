import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/core/constants/service_areas.dart';
import 'package:tmassist/utils/area_grouping.dart';

void main() {
  test('the list has exactly the 11 names in order, no duplicates', () {
    expect(ServiceAreas.all, [
      'Kuala Lumpur',
      'Putrajaya',
      'Petaling Jaya',
      'Subang Jaya',
      'Shah Alam',
      'Puchong',
      'Klang',
      'Kajang',
      'Rawang',
      'Cyberjaya',
      'Other',
    ]);
    expect(ServiceAreas.all.toSet().length, ServiceAreas.all.length);
  });

  test('Other is last', () {
    expect(ServiceAreas.all.last, 'Other');
  });

  test('technician coverage choices exclude Other and keep the rest', () {
    final choices = ServiceAreas.coverageChoices;
    expect(choices, isNot(contains('Other')));
    expect(choices.length, 10);
    expect(choices, ServiceAreas.all.sublist(0, 10));
  });

  test('areaOfTicket maps an address with each name to that area', () {
    for (final name in ServiceAreas.all.where((a) => a != 'Other')) {
      expect(
        areaOfTicket(address: 'No 1, Jalan Test, ${name.toUpperCase()}, MY'),
        name,
        reason: name,
      );
    }
    expect(areaOfTicket(address: 'Presint 9, Putrajaya'), 'Putrajaya');
    expect(areaOfTicket(address: 'Bandar Baru Kajang, Selangor'), 'Kajang');
    expect(areaOfTicket(address: 'Rawang, Selangor'), 'Rawang');
    expect(
      areaOfTicket(address: 'Persiaran Multimedia, Cyberjaya'),
      'Cyberjaya',
    );
  });

  test('an unknown address is Other and a stored area wins', () {
    expect(areaOfTicket(address: 'Somewhere in Ipoh'), 'Other');
    expect(areaOfTicket(area: 'Klang', address: 'Rawang'), 'Klang');
  });
}
