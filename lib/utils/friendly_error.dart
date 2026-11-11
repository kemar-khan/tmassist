import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;

import '../core/services/auth_service.dart' show AuthException;

/// An error whose [message] is already written for the user (for example a
/// business rule such as "Ticket can no longer be cancelled").
class FriendlyException implements Exception {
  const FriendlyException(this.message);
  final String message;

  @override
  String toString() => message;
}

const _offlineOrSlow =
    'No internet connection or the server is slow. Please try again.';

/// A one-line message the user can read, for any error. The raw exception text
/// is never part of it; unknown errors give [fallback]. In debug builds the
/// raw error (and [stackTrace]) is printed for developers.
String friendlyError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
  StackTrace? stackTrace,
}) {
  if (kDebugMode) {
    debugPrint('[friendlyError] $error');
    if (stackTrace != null) debugPrint('$stackTrace');
  }

  if (error is FriendlyException) return error.message;
  if (error is AuthException) {
    return error.message.isEmpty ? fallback : error.message;
  }

  // FirebaseAuthException is a FirebaseException, so it is checked first.
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return fallback;
    }
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return _offlineOrSlow;
      case 'permission-denied':
        return 'You do not have permission to do that.';
      case 'resource-exhausted':
        return 'The service is busy right now. Please try again later.';
      case 'not-found':
        return 'We could not find that item.';
      default:
        return fallback;
    }
  }

  if (error is SocketException ||
      error is ClientException ||
      error is TimeoutException) {
    return _offlineOrSlow;
  }

  return fallback;
}
