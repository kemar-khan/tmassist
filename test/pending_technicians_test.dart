import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/pending_technicians.dart';

void main() {
  Map<String, dynamic> tech([Map<String, dynamic> extra = const {}]) => {
    'role': 'technician',
    ...extra,
  };

  group('isPendingTechnician', () {
    test('approved false is pending', () {
      expect(isPendingTechnician(tech({'approved': false})), isTrue);
    });

    test('approved true is not pending', () {
      expect(isPendingTechnician(tech({'approved': true})), isFalse);
    });

    test('a missing approved field is not pending (old accounts)', () {
      expect(isPendingTechnician(tech()), isFalse);
    });

    test('rejected true is not pending', () {
      expect(
        isPendingTechnician(tech({'approved': false, 'rejected': true})),
        isFalse,
      );
    });

    test('rejected overrides approved', () {
      expect(
        isPendingTechnician(tech({'approved': true, 'rejected': true})),
        isFalse,
      );
    });

    test('other roles are ignored', () {
      expect(
        isPendingTechnician({'role': 'customer', 'approved': false}),
        isFalse,
      );
      expect(
        isPendingTechnician({'role': 'supervisor', 'approved': false}),
        isFalse,
      );
      expect(isPendingTechnician({'approved': false}), isFalse);
    });

    test('counting a mixed list', () {
      final users = [
        tech({'approved': false}),
        tech({'approved': false}),
        tech({'approved': false, 'rejected': true}),
        tech({'approved': true}),
        tech(),
        {'role': 'customer'},
      ];
      expect(users.where(isPendingTechnician).length, 2);
    });
  });

  group('assignable technicians', () {
    final users = {
      'old': tech(), // no approved field
      'approved': tech({'approved': true}),
      'pending': tech({'approved': false}),
      'rejected': tech({'approved': false, 'rejected': true}),
      'rejectedApproved': tech({'approved': true, 'rejected': true}),
    };

    test('pending and rejected technicians are never chosen', () {
      final ids = assignableOnly(users.keys, (k) => users[k]!);
      expect(ids, ['old', 'approved']);
    });

    test('old technicians without approved still are', () {
      expect(isAssignableTechnician(tech()), isTrue);
      expect(isAssignableTechnician(tech({'approved': true})), isTrue);
    });

    test('an all-pending list leaves nobody', () {
      final only = [
        tech({'approved': false}),
        tech({'rejected': true}),
      ];
      expect(assignableOnly(only, (m) => m), isEmpty);
    });
  });

  test('formatRequestedDate', () {
    expect(formatRequestedDate(DateTime(2026, 11, 21)), '21 Nov 2026');
    expect(formatRequestedDate(DateTime(2026, 1, 5)), '5 Jan 2026');
  });
}
