// lib/main.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/config/timeouts.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load local secrets (GEMINI_API_KEY) before anything can call Gemini.
  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ONE decision at startup, from the session Firebase saved on the phone.
  // There is deliberately no live auth listener at the app root: registration
  // signs the user in before the profile document exists.
  runApp(App(signedIn: await _hasSavedSession()));
}

/// Whether a user is already signed in, using only the locally restored
/// session (no network). Waits briefly for the first auth state, then falls
/// back to the current user.
Future<bool> _hasSavedSession() async {
  final auth = FirebaseAuth.instance;
  try {
    final user = await auth.authStateChanges().first.timeout(
      Timeouts.authRestore,
    );
    return user != null;
  } catch (_) {
    return auth.currentUser != null;
  }
}
