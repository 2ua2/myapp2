import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current Firebase user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register parent with email and password
  Future<UserModel?> registerParent({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) return null;

      await user.updateDisplayName(name);

      final userModel = UserModel(
        uid: user.uid,
        name: name,
        email: email,
        role: 'parent',
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toMap());

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Registration failed. Please try again.');
    }
  }

  // Register a new parent account and save their profile to Firestore.
  // familyId is set to the parent's own uid so children can later join it.
  Future<UserModel?> signUpParent({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) return null;

      await user.updateDisplayName(name);

      final userModel = UserModel(
        uid: user.uid,
        name: name,
        email: email,
        role: 'parent',
        createdAt: DateTime.now(),
        familyId: user.uid,
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toMap());

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign up failed. Please try again.');
    }
  }

  // Sign in with email and password
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) return null;

      return await getUserModel(user.uid);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign in failed. Please try again.');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed. Please try again.');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to send reset email. Please try again.');
    }
  }

  // Get user model from Firestore
  Future<UserModel?> getUserModel(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!);
    } catch (e) {
      return null;
    }
  }

  // Update FCM token in Firestore
  Future<void> updateFcmToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    } catch (e) {
      // Silent fail - non-critical
    }
  }

  // Look up the parent by email, generate a 6-digit code, and store it in
  // Firestore with a 10-minute expiry. The parent reads the code from their
  // app and shares it verbally with the child.
  // Sending codes by email requires Cloud Functions + a mail provider and is
  // not implemented here.
  Future<void> sendChildVerificationCode(String parentEmail) async {
    try {
      // Confirm a parent account exists with this email
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: parentEmail)
          .where('role', isEqualTo: 'parent')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('No parent account found with this email.');
      }

      final parentDoc = query.docs.first;
      // Fall back to the document ID if familyId was never written (legacy accounts)
      final familyId =
          parentDoc.data()['familyId'] as String? ?? parentDoc.id;

      // Use a cryptographically strong source for the code
      final code = (100000 + Random.secure().nextInt(900000)).toString();
      final expiresAt = DateTime.now().add(const Duration(minutes: 10));

      await _firestore
          .collection('verification_codes')
          .doc(parentEmail)
          .set({
        'code': code,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'familyId': familyId,
        'parentUid': parentDoc.id,
      });
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'Failed to generate verification code.');
    } catch (e) {
      rethrow;
    }
  }

  // Validate the 6-digit code, register the child under the parent's family,
  // and persist the child role in SharedPreferences so the session survives
  // app restarts without a Firebase Auth account.
  Future<String> verifyChildCode(String parentEmail, String code) async {
    try {
      final doc = await _firestore
          .collection('verification_codes')
          .doc(parentEmail)
          .get();

      if (!doc.exists) {
        throw Exception(
            'No verification code found. Please request a new code.');
      }

      final data = doc.data()!;

      if ((data['code'] as String) != code) {
        throw Exception('Incorrect code. Please check and try again.');
      }

      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception('Code has expired. Please request a new one.');
      }

      final familyId = data['familyId'] as String;

      // Generate a stable device-level child ID on first link
      final prefs = await SharedPreferences.getInstance();
      String? childId = prefs.getString('child_id');
      if (childId == null) {
        childId = const Uuid().v4();
        await prefs.setString('child_id', childId);
      }

      // Write child document into the parent's family subcollection
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('children')
          .doc(childId)
          .set({
        'childId': childId,
        'familyId': familyId,
        'linkedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Persist role locally — this is the child's auth session
      await prefs.setString('user_role', 'child');
      await prefs.setString('family_id', familyId);

      // One-time code consumed — delete it
      await _firestore
          .collection('verification_codes')
          .doc(parentEmail)
          .delete();

      return familyId;
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'Verification failed. Please try again.');
    } catch (e) {
      rethrow;
    }
  }

  // Handle Firebase Auth exceptions and return readable messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}