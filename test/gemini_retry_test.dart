import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:tmassist/utils/gemini_retry.dart';
import 'package:tmassist/utils/slow_hint.dart';

void main() {
  const pause = Duration(milliseconds: 5);

  // How many times the call ran for a list of failures (then success).
  Future<int> run(List<Object> failures) async {
    var calls = 0;
    try {
      await withGeminiRetry<int>(
        () async {
          final i = calls++;
          if (i < failures.length) throw failures[i];
          return 1;
        },
        label: 'test',
        pause: pause,
      );
    } catch (_) {}
    return calls;
  }

  test('retries once on 503', () async {
    expect(
      await run([GenerativeAIException('Server Error [503]: overloaded')]),
      2,
    );
  });

  test('retries once on 429 (resource exhausted)', () async {
    expect(
      await run([
        ServerException('Resource has been exhausted (e.g. check quota).'),
      ]),
      2,
    );
  });

  test('retries once on a network error', () async {
    expect(await run([const SocketException('down')]), 2);
  });

  test('does not retry on a timeout', () async {
    expect(await run([TimeoutException('slow')]), 1);
  });

  test('does not retry on 400, a bad key or other errors', () async {
    expect(
      await run([ServerException('Request contains an invalid argument.')]),
      1,
    );
    expect(await run([InvalidApiKey('API key not valid')]), 1);
    expect(await run([GenerativeAIException('Server Error [500]: boom')]), 1);
    expect(await run([StateError('x')]), 1);
  });

  test('at most one retry; the second failure is thrown', () async {
    var calls = 0;
    await expectLater(
      withGeminiRetry<int>(
        () async {
          calls++;
          throw GenerativeAIException('Server Error [503]: busy');
        },
        label: 'test',
        pause: pause,
      ),
      throwsA(isA<GenerativeAIException>()),
    );
    expect(calls, 2);
  });

  test('a retry that works returns its value', () async {
    var calls = 0;
    final v = await withGeminiRetry<int>(
      () async {
        if (calls++ == 0) throw GenerativeAIException('Server Error [503]: x');
        return 42;
      },
      label: 'test',
      pause: pause,
    );
    expect(v, 42);
  });

  test('waits the pause before retrying', () async {
    final watch = Stopwatch()..start();
    var calls = 0;
    await withGeminiRetry<int>(
      () async {
        if (calls++ == 0) throw const SocketException('x');
        return 1;
      },
      label: 'test',
      pause: const Duration(milliseconds: 80),
    );
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(70));
  });

  group('SlowHint', () {
    test('fires when not stopped in time', () async {
      var fired = 0;
      SlowHint(after: const Duration(milliseconds: 20)).start(() => fired++);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(fired, 1);
    });

    test('does not fire when stopped first', () async {
      var fired = 0;
      final h = SlowHint(after: const Duration(milliseconds: 40));
      h.start(() => fired++);
      h.stop();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(fired, 0);
    });
  });
}
