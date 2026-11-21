import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/contact_validation.dart';
import 'package:tmassist/utils/staff_id.dart';
import 'package:tmassist/utils/technician_access.dart';

void main() {
  group('technicianAccessState', () {
    test('approved true is approved', () {
      expect(
        technicianAccessState({'role': 'technician', 'approved': true}),
        TechnicianAccess.approved,
      );
    });

    test('approved false is pending', () {
      expect(
        technicianAccessState({'role': 'technician', 'approved': false}),
        TechnicianAccess.pending,
      );
    });

    test('a missing approved field is approved (existing accounts)', () {
      expect(
        technicianAccessState({'role': 'technician'}),
        TechnicianAccess.approved,
      );
    });

    test('rejected true is rejected', () {
      expect(
        technicianAccessState({'role': 'technician', 'rejected': true}),
        TechnicianAccess.rejected,
      );
    });

    test('rejected overrides approved', () {
      expect(
        technicianAccessState({'approved': true, 'rejected': true}),
        TechnicianAccess.rejected,
      );
      expect(
        technicianAccessState({'approved': false, 'rejected': true}),
        TechnicianAccess.rejected,
      );
    });

    test('rejected false does not block', () {
      expect(
        technicianAccessState({'approved': true, 'rejected': false}),
        TechnicianAccess.approved,
      );
    });
  });

  group('staff ID', () {
    test('normalises to upper case without spaces', () {
      expect(normalizeStaffId('TM571'), 'TM571');
      expect(normalizeStaffId('tm571'), 'TM571');
      expect(normalizeStaffId('TM 571'), 'TM571');
      expect(normalizeStaffId('  tm571  '), 'TM571');
    });

    test('rejects anything else', () {
      expect(normalizeStaffId('abc'), isNull);
      expect(normalizeStaffId(''), isNull);
      expect(normalizeStaffId(null), isNull);
      expect(normalizeStaffId('TM'), isNull);
      expect(normalizeStaffId('TM57a'), isNull);
      expect(normalizeStaffId('571'), isNull);
    });

    test('validator messages', () {
      expect(validateStaffId('TM571'), isNull);
      expect(validateStaffId('tm571'), isNull);
      expect(validateStaffId('TM 571'), isNull);
      expect(validateStaffId('abc'), isNotNull);
      expect(validateStaffId(''), isNotNull);
      expect(validateStaffId(null), isNotNull);
      expect(validateStaffId('TM'), isNotNull);
    });
  });

  group('email and phone validators', () {
    test('email', () {
      expect(validateEmail('you@example.com'), isNull);
      expect(validateEmail('a.b+c@mail.tm.com.my'), isNull);
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('a@'), isNotNull);
      expect(validateEmail('a@b'), isNotNull);
      expect(validateEmail('a@b.c'), isNotNull);
      expect(validateEmail('a b@c.com'), isNotNull);
      expect(validateEmail('a@@c.com'), isNotNull);
      expect(validateEmail('a..b@c.com'), isNotNull);
    });

    test('phone matches the customer rule', () {
      expect(validatePhone('012-345 6789'), isNull);
      expect(validatePhone('+60123456789'), isNull);
      expect(validatePhone(''), isNotNull);
      expect(validatePhone('12345'), isNotNull);
      expect(validatePhone('0123abc6789'), isNotNull);
    });
  });
}
