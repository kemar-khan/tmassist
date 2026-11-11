import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' show ClientException;

/// Whether a failed Gemini call is worth one more try: the service is
/// overloaded (HTTP 503), rate limited (429) or the network dropped. Timeouts
/// and rejected requests (400, 401, 403, a bad key, an unsupported location)
/// are never retried.
bool isRetryableGeminiError(Object error) {
  if (error is TimeoutException) return false;
  if (error is InvalidApiKey || error is UnsupportedUserLocation) return false;
  if (error is SocketException || error is ClientException) return true;

  if (error is GenerativeAIException) {
    final text = error.message.toLowerCase();
    // The SDK reports 5xx as "Server Error [503]: ..." and puts other API
    // errors into the message text.
    final status = RegExp(r'\[(\d{3})\]').firstMatch(text)?.group(1);
    if (status != null) return status == '503' || status == '429';
    return text.contains('overloaded') ||
        text.contains('resource has been exhausted') ||
        text.contains('rate limit');
  }
  return false;
}

/// Runs [call]; when it fails with a retryable error (see
/// [isRetryableGeminiError]) waits [pause] and runs it once more. At most one
/// retry. In debug builds it prints which call it was ([label]), how long each
/// attempt took and whether it was retried (never the API key).
Future<T> withGeminiRetry<T>(
  Future<T> Function() call, {
  required String label,
  Duration pause = const Duration(seconds: 2),
  bool Function(Object error)? isRetryable,
}) async {
  final retryable = isRetryable ?? isRetryableGeminiError;
  var attempt = 1;
  while (true) {
    final watch = Stopwatch()..start();
    try {
      final result = await call();
      _log(label, attempt, watch, 'ok');
      return result;
    } catch (e) {
      _log(label, attempt, watch, 'failed (${e.runtimeType})');
      if (attempt >= 2 || !retryable(e)) rethrow;
      attempt++;
      await Future<void>.delayed(pause);
    }
  }
}

void _log(String label, int attempt, Stopwatch watch, String outcome) {
  if (!kDebugMode) return;
  debugPrint(
    '[gemini:$label] attempt $attempt took ${watch.elapsedMilliseconds} ms, '
    '$outcome${attempt > 1 ? ' (retried)' : ''}',
  );
}
