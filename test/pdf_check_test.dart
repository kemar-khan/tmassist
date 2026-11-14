import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/pdf_check.dart';

void main() {
  test('empty or too short is invalid', () {
    expect(isValidPdfBytes(Uint8List(0)), isFalse);
    expect(isValidPdfBytes(Uint8List.fromList([0x25, 0x50, 0x44])), isFalse);
  });

  test('a wrong header is invalid', () {
    expect(isValidPdfBytes(Uint8List.fromList('<html>'.codeUnits)), isFalse);
    expect(isValidPdfBytes(Uint8List.fromList('%pdf-1.4'.codeUnits)), isFalse);
    expect(isValidPdfBytes(Uint8List.fromList([0, 0, 0, 0, 0])), isFalse);
  });

  test('the %PDF header is valid', () {
    expect(
      isValidPdfBytes(Uint8List.fromList('%PDF-1.4\n...'.codeUnits)),
      isTrue,
    );
    expect(
      isValidPdfBytes(Uint8List.fromList([0x25, 0x50, 0x44, 0x46])),
      isTrue,
    );
  });
}
