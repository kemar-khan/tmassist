import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  /// Convert Firebase auth errors to user-friendly messages
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password login is not enabled.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Login failed: ${e.message ?? 'Unknown error'}';
    }
  }

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
    } on FirebaseAuthException catch (e) {
      throw AuthException(message: _getErrorMessage(e), code: e.code);
    } catch (e) {
      throw AuthException(message: 'Registration failed: $e');
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
    } on FirebaseAuthException catch (e) {
      throw AuthException(message: _getErrorMessage(e), code: e.code);
    } catch (e) {
      throw AuthException(message: 'Login failed: $e');
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
