import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/core/services/cloudinary_service.dart';
import 'package:tmassist/utils/friendly_error.dart';

void main() {
  const message = 'Could not upload the file. Please try again.';

  test('a good response returns the secure url', () {
    expect(
      parseUploadResponse(
        200,
        '{"secure_url":"https://res.cloudinary.com/x.jpg"}',
      ),
      'https://res.cloudinary.com/x.jpg',
    );
    expect(
      parseUploadResponse(
        201,
        '{"secure_url":"https://res.cloudinary.com/x.pdf"}',
      ),
      'https://res.cloudinary.com/x.pdf',
    );
  });

  test('bad status, missing url or bad body give the friendly message', () {
    final bodies = <(int, String)>[
      (400, '{"error":{"message":"RAW secret"}}'),
      (500, 'RAW secret'),
      (200, '{}'),
      (200, '{"secure_url":""}'),
      (200, '{"secure_url":"http://insecure"}'),
      (200, '{"secure_url":5}'),
      (200, 'not json RAW secret'),
      (200, '[1,2]'),
    ];
    for (final (status, body) in bodies) {
      expect(
        () => parseUploadResponse(status, body),
        throwsA(
          isA<FriendlyException>().having((e) => e.message, 'message', message),
        ),
        reason: '$status $body',
      );
    }
  });
}
