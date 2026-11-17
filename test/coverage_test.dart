import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/coverage.dart';

void main() {
  const areas = ['Puchong', 'Klang'];

  test('Other, empty and null areas are never outside coverage', () {
    for (final a in ['Other', '', null]) {
      expect(isOutsideCoverage(areas, a), isFalse, reason: '$a');
      expect(isOutsideCoverage(const [], a), isFalse, reason: '$a');
      expect(isOutsideCoverage(null, a), isFalse, reason: '$a');
    }
  });

  test('an exact match is covered', () {
    expect(coversArea(areas, 'Puchong'), isTrue);
    expect(isOutsideCoverage(areas, 'Klang'), isFalse);
  });

  test('a different area is outside', () {
    expect(isOutsideCoverage(areas, 'Shah Alam'), isTrue);
  });

  test('a different case or spelling is outside', () {
    expect(isOutsideCoverage(areas, 'puchong'), isTrue);
    expect(isOutsideCoverage(areas, 'PUCHONG'), isTrue);
    expect(isOutsideCoverage(areas, 'Puchong '), isTrue);
    expect(isOutsideCoverage(areas, 'Pucong'), isTrue);
  });

  test('an empty or null coverage list with a real area is outside', () {
    expect(isOutsideCoverage(const [], 'Puchong'), isTrue);
    expect(isOutsideCoverage(null, 'Puchong'), isTrue);
  });

  test('isAnyArea', () {
    expect(isAnyArea(null), isTrue);
    expect(isAnyArea(''), isTrue);
    expect(isAnyArea('Other'), isTrue);
    expect(isAnyArea('Puchong'), isFalse);
    expect(isAnyArea('other'), isFalse);
  });
}
