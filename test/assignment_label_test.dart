import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/assignment_label.dart';

void main() {
  test('AUTO and MANUAL have a label', () {
    expect(assignmentSourceLabel('AUTO'), 'Assigned Automatically');
    expect(assignmentSourceLabel('MANUAL'), 'Assigned by Your Supervisor');
  });

  test('missing, empty and unknown values give nothing', () {
    expect(assignmentSourceLabel(null), isNull);
    expect(assignmentSourceLabel(''), isNull);
    expect(assignmentSourceLabel('auto'), isNull);
    expect(assignmentSourceLabel('SOMETHING'), isNull);
  });
}
