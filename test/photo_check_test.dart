import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/utils/photo_check.dart';

void main() {
  attachmentTests();
  bool ok(String name, int bytes) =>
      isAcceptableProofPhoto(fileName: name, bytes: bytes);

  test('accepts the listed image types, any case', () {
    for (final n in ['a.jpg', 'a.JPEG', 'a.png', 'a.WebP', 'a.heic']) {
      expect(ok(n, 1000), isTrue, reason: n);
    }
  });

  test('rejects other types and names without an extension', () {
    for (final n in ['a.pdf', 'a.gif', 'a.mp4', 'a', 'a.', 'jpg']) {
      expect(ok(n, 1000), isFalse, reason: n);
    }
  });

  test('size limit is 5 MB inclusive; empty files are rejected', () {
    expect(ok('a.jpg', maxProofPhotoBytes), isTrue);
    expect(ok('a.jpg', maxProofPhotoBytes + 1), isFalse);
    expect(ok('a.jpg', 0), isFalse);
  });

  test('only the last extension counts', () {
    expect(ok('photo.pdf.jpg', 10), isTrue);
    expect(ok('photo.jpg.exe', 10), isFalse);
  });
}

void attachmentTests() {
  group('isAcceptableAttachment', () {
    bool ok(String n, int b) => isAcceptableAttachment(fileName: n, bytes: b);

    test('images and PDF, any case', () {
      for (final n in [
        'a.jpg',
        'a.JPEG',
        'a.png',
        'a.webp',
        'a.HEIC',
        'a.PDF',
      ]) {
        expect(ok(n, 1000), isTrue, reason: n);
      }
    });

    test('other types and no extension are rejected', () {
      for (final n in ['a.gif', 'a.docx', 'a.mp4', 'a', 'a.']) {
        expect(ok(n, 1000), isFalse, reason: n);
      }
    });

    test('5 MB boundary and empty files', () {
      expect(ok('a.pdf', maxProofPhotoBytes), isTrue);
      expect(ok('a.pdf', maxProofPhotoBytes + 1), isFalse);
      expect(ok('a.jpg', 0), isFalse);
    });

    test('the proof-photo check still refuses PDF', () {
      expect(isAcceptableProofPhoto(fileName: 'a.pdf', bytes: 10), isFalse);
    });
  });
}
