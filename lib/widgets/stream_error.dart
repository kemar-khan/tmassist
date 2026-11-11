import 'package:flutter/material.dart';

import '../utils/friendly_error.dart';
import 'empty_state.dart';

/// A friendly error screen for a failed load, built on [EmptyState]. Pass the
/// [error] (shown through [friendlyError], never as raw text) or a ready
/// [message]. A "Try Again" button appears when [onRetry] is given, and a
/// "Log Out" button when [onLogOut] is given.
class StreamError extends StatelessWidget {
  const StreamError({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.onLogOut,
  });

  final Object? error;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onLogOut;

  @override
  Widget build(BuildContext context) {
    final text =
        message ??
        (error == null
            ? 'Something went wrong. Please try again.'
            : friendlyError(error!));

    final buttons = <Widget>[
      if (onRetry != null)
        ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
      if (onLogOut != null)
        TextButton(onPressed: onLogOut, child: const Text('Log Out')),
    ];

    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: text,
      action: buttons.isEmpty
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: buttons),
    );
  }
}
