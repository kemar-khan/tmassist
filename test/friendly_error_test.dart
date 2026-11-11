import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:tmassist/core/services/auth_service.dart';
import 'package:tmassist/utils/friendly_error.dart';

void main() {
  String auth(String code) =>
      friendlyError(FirebaseAuthException(code: code, message: 'RAW $code'));
  String store(String code) => friendlyError(
    FirebaseException(plugin: 'cloud_firestore', code: code, message: 'RAW'),
  );

  test('auth codes', () {
    for (final c in [
      'invalid-credential',
      'wrong-password',
      'user-not-found',
    ]) {
      expect(auth(c), 'Incorrect email or password.');
    }
    expect(
      auth('email-already-in-use'),
      'This email is already registered. Try signing in instead.',
    );
    expect(
      auth('weak-password'),
      'Password is too weak. Use at least 6 characters.',
    );
    expect(auth('invalid-email'), 'Please enter a valid email address.');
    expect(
      auth('network-request-failed'),
      'No internet connection. Please check your network and try again.',
    );
    expect(
      auth('too-many-requests'),
      'Too many attempts. Please wait a moment and try again.',
    );
    expect(auth('user-disabled'), 'This account has been disabled.');
  });

  test('firestore codes', () {
    const slow =
        'No internet connection or the server is slow. Please try again.';
    expect(store('unavailable'), slow);
    expect(store('deadline-exceeded'), slow);
    expect(
      store('permission-denied'),
      'You do not have permission to do that.',
    );
    expect(
      store('resource-exhausted'),
      'The service is busy right now. Please try again later.',
    );
    expect(store('not-found'), 'We could not find that item.');
  });

  test('network and timeout errors', () {
    const slow =
        'No internet connection or the server is slow. Please try again.';
    expect(friendlyError(const SocketException('RAW')), slow);
    expect(friendlyError(ClientException('RAW')), slow);
    expect(friendlyError(TimeoutException('RAW')), slow);
  });

  test('unknown errors use the fallback, default or given', () {
    expect(
      friendlyError(Exception('RAW boom')),
      'Something went wrong. Please try again.',
    );
    expect(
      friendlyError(StateError('RAW'), fallback: 'Could not do it.'),
      'Could not do it.',
    );
    expect(auth('some-new-code'), 'Something went wrong. Please try again.');
    expect(store('internal'), 'Something went wrong. Please try again.');
  });

  test('our own messages pass through', () {
    expect(
      friendlyError(
        const FriendlyException('Ticket can no longer be cancelled'),
      ),
      'Ticket can no longer be cancelled',
    );
    expect(
      friendlyError(AuthException(message: 'Email and password are required.')),
      'Email and password are required.',
    );
  });

  test('raw text never leaks', () {
    final errors = <Object>[
      Exception('RAW secret'),
      FirebaseAuthException(code: 'x', message: 'RAW secret'),
      FirebaseAuthException(code: 'invalid-email', message: 'RAW secret'),
      FirebaseException(plugin: 'p', code: 'x', message: 'RAW secret'),
      const SocketException('RAW secret'),
      TimeoutException('RAW secret'),
      'RAW secret',
    ];
    for (final e in errors) {
      expect(friendlyError(e), isNot(contains('RAW')));
      expect(friendlyError(e), isNot(contains('secret')));
    }
  });
}
