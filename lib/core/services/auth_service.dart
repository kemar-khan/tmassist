import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/friendly_error.dart';

/// Custom exception for authentication errors
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException({required this.message, this.code});

  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> registerCustomer({
    required String fullName,
    required String email,
    required String phone,
    required String address,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = credential.user;
      if (user == null) {
        throw AuthException(message: 'User registration failed.');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'fullName': fullName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return credential;
    } on FirebaseAuthException catch (e, st) {
      throw AuthException(
        message: friendlyError(
          e,
          fallback: 'Registration failed. Please try again.',
          stackTrace: st,
        ),
        code: e.code,
      );
    } catch (e, st) {
      throw AuthException(
        message: friendlyError(
          e,
          fallback: 'Registration failed. Please try again.',
          stackTrace: st,
        ),
      );
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw AuthException(message: 'Email and password are required.');
      }

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e, st) {
      throw AuthException(
        message: friendlyError(
          e,
          fallback: 'Login failed. Please try again.',
          stackTrace: st,
        ),
        code: e.code,
      );
    } catch (e, st) {
      throw AuthException(
        message: friendlyError(
          e,
          fallback: 'Login failed. Please try again.',
          stackTrace: st,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
