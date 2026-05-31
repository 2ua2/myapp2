import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/child_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current Firebase user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

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

      final userModel = UserModel(
        uid: user.uid,
        name: name,
        email: email.toLowerCase(),
        role: 'parent',
        createdAt: DateTime.now(),
        familyId: user.uid,
      );

      // Write the Firestore document first so the authStateChanges listener
      // can read it if it fires before updateDisplayName completes.
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toMap());

      await user.updateDisplayName(name);

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
    User? firebaseUser;
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      firebaseUser = credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
    if (firebaseUser == null) return null;
    // Firestore read is outside the Firebase Auth catch block so its
    // exceptions propagate directly to the caller without being swallowed.
    return await getUserModel(firebaseUser.uid);
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed. Please try again.');
    }
  }

  // Clears the Firebase Auth session only. Does not touch SharedPreferences
  // so any existing child session remains intact after this call.
  Future<void> silentSignOut() async {
    await _auth.signOut();
  }

  // Signs the child device in anonymously so Firestore writes that require
  // an authenticated uid (saveChildInfo) succeed. Returns the uid on success,
  // null on any error.
  Future<String?> signInChildAnonymously() async {
    try {
      final existing = FirebaseAuth.instance.currentUser;
      if (existing != null) {
        print('already signed in: ${existing.uid}');
        return existing.uid;
      }
      final credential =
          await FirebaseAuth.instance.signInAnonymously();
      print('anonymous sign in success: ${credential.user?.uid}');
      return credential.user?.uid;
    } catch (e) {
      print('signInChildAnonymously ERROR: $e');
      return null;
    }
  }

  // Real-time stream of all children under a parent's family.
  // Each map includes 'id' (doc key) plus all stored fields.
  Stream<List<Map<String, dynamic>>> childrenStream(String parentUid) {
    return FirebaseFirestore.instance
        .collection('families')
        .doc(parentUid)
        .collection('children')
        .where('status', isEqualTo: 'linked')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList())
        .handleError((e) {
      print('childrenStream ERROR: $e');
      return <Map<String, dynamic>>[];
    });
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

  // Get user model from Firestore. Throws if the document is missing or
  // if the read fails — callers are responsible for handling the exception.
  Future<UserModel?> getUserModel(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) throw Exception('User document not found.');
    return UserModel.fromMap(doc.data()!);
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

  // Generates a 6-digit numeric link code and writes it to /link_codes/{code}.
  // Must be called by a signed-in parent. The parent reads the code from the
  // app and shares it verbally with the child. The code expires in 10 minutes
  // and is marked used:false so verifyLinkCode can consume it exactly once.
  Future<String> generateLinkCode() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to generate a code.');
    }

    final code = (100000 + Random.secure().nextInt(900000)).toString();
    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(minutes: 10)),
    );

    await _firestore.collection('link_codes').doc(code).set({
      'familyId': user.uid,
      'parentName': user.displayName ?? '',
      'createdAt': Timestamp.now(),
      'expiresAt': expiresAt,
      'used': false,
    });

    return code;
  }

  // Validates a link code entered by the child, registers the child under the
  // parent's family in Firestore, and persists the child session in
  // SharedPreferences so the app can restore it after a restart.
  // Throws a readable Exception on any validation or Firestore failure.
  Future<ChildModel> verifyLinkCode(String code, String childName) async {
    try {
      final doc = await _firestore.collection('link_codes').doc(code).get();

      if (!doc.exists) {
        throw Exception('Invalid code. Please check and try again.');
      }

      final data = doc.data()!;

      if (data['used'] == true) {
        throw Exception(
            'This code has already been used. Ask your parent for a new one.');
      }

      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception(
            'This code has expired. Ask your parent for a new one.');
      }

      final familyId = data['familyId'] as String;
      final parentName = data['parentName'] as String? ?? '';

      // Mark the code used before writing the child document so a second
      // device cannot consume the same code concurrently.
      await _firestore
          .collection('link_codes')
          .doc(code)
          .update({'used': true});

      final childId = const Uuid().v4();
      final child = ChildModel(
        childId: childId,
        familyId: familyId,
        linkedAt: DateTime.now(),
        isActive: true,
      );

      // Write ChildModel fields and childName so the parent can identify
      // which child is linked (ChildModel itself has no name field).
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('children')
          .doc(childId)
          .set({...child.toMap(), 'childName': childName, 'status': 'linked'});

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'child');
      await prefs.setString('child_id', childId);
      await prefs.setString('family_id', familyId);
      await prefs.setString('child_name', childName);
      await prefs.setString('parent_name', parentName);

      return child;
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'Verification failed. Please try again.');
    } catch (e) {
      rethrow;
    }
  }

  // TODO Phase 6: listen to /link_requests where
  // parentEmail == current parent email, status == pending
  // show notification to parent with Approve/Deny options
  // on Approve: set status='approved', generate 4-digit PIN,
  // write pin + parentId + familyId to the request doc

  // Look up a parent's uid (= familyId) by email. Returns null if not found or on error.
  Future<String?> getParentFamilyIdByEmail(String email) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .where('role', isEqualTo: 'parent')
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return query.docs.first.id;
    } catch (e) {
      return null;
    }
  }

  // Returns true if an approved link_request exists for this familyId + pin.
  // Pin comparison is done in Dart rather than in the Firestore query to avoid
  // silent type-mismatch failures when the stored pin is a String.
  Future<bool> verifyChildPin({
    required String familyId,
    required String pin,
  }) async {
    try {
      print('verifyChildPin: familyId=$familyId pin=$pin');

      final query = await _firestore
          .collection('link_requests')
          .where('familyId', isEqualTo: familyId)
          .where('status', isEqualTo: 'approved')
          .get();

      print('verifyChildPin: found ${query.docs.length} approved requests');

      for (final doc in query.docs) {
        final data = doc.data();
        print('verifyChildPin: checking doc=${doc.id} pin=${data['pin']} vs input=$pin');
        if (data['pin']?.toString() == pin.trim()) {
          print('verifyChildPin: PIN matched on doc=${doc.id}');
          return true;
        }
      }

      print('verifyChildPin: no match found');
      return false;
    } catch (e) {
      print('verifyChildPin ERROR: $e');
      return false;
    }
  }

  // Writes child profile to /users/{uid} and /families/{familyId}/children/{uid},
  // then stamps the approved link_request with the child's uid.
  Future<bool> saveChildInfo({
    required String familyId,
    required String name,
    required String age,
    required String phone,
  }) async {
    if (familyId.isEmpty) {
      print('saveChildInfo: familyId is empty');
      return false;
    }

    final user = _auth.currentUser;
    if (user == null) {
      print('saveChildInfo: currentUser is null');
      return false;
    }
    final uid = user.uid;
    print('DIAG-9 saveChildInfo uid=$uid familyId=$familyId');

    // Critical write: flips status to 'linked'. Must succeed before returning true.
    try {
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('children')
          .doc(uid)
          .set({
        'childName': name,
        'parentId': familyId,
        'childId': uid,
        'age': age,
        'phone': phone,
        'linkedAt': FieldValue.serverTimestamp(),
        'status': 'linked',
      }, SetOptions(merge: true));
      print('DIAG-11 wrote /families/$familyId/children/$uid');
    } catch (e) {
      print('saveChildInfo: families write failed: $e');
      return false;
    }

    // Secondary write: metadata only. Failure does not block linking.
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'role': 'child',
        'familyId': familyId,
        'phoneNumber': phone,
        'age': int.tryParse(age) ?? 0,
        'createdAt': Timestamp.now(),
      });
      print('DIAG-10 wrote /users/$uid');
    } catch (e) {
      print('saveChildInfo: users write failed (non-critical): $e');
    }

    // link_requests update is optional — failure does not block onboarding.
    try {
      final requestQuery = await _firestore
          .collection('link_requests')
          .where('familyId', isEqualTo: familyId)
          .where('childId', isEqualTo: uid)
          .limit(1)
          .get();

      if (requestQuery.docs.isNotEmpty) {
        await requestQuery.docs.first.reference.update({
          'age': age,
          'phone': phone,
        });
      }
    } catch (e) {
      print('saveChildInfo: link_request update error: $e');
    }

    return true;
  }

  // Creates a pending link request in /link_requests for the parent to approve.
  // Returns the requestId on success so the caller can stamp childId onto it.
  // expiresAt enables a Firestore TTL policy to auto-delete abandoned requests
  // (child scanned QR but never completed onboarding) after 24 hours.
  Future<String?> createLinkRequest({
    required String familyId,
    required String childName,
  }) async {
    try {
      final requestId = const Uuid().v4();
      await _firestore.collection('link_requests').doc(requestId).set({
        'requestId': requestId,
        'childName': childName,
        'familyId': familyId,
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'childId': '',
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24)),
        ),
      });
      return requestId;
    } catch (e) {
      print('createLinkRequest ERROR: $e');
      return null;
    }
  }

  // Approves a pending link request. Before writing the new child record,
  // deletes every existing doc in families/{familyId}/children so the
  // subcollection always holds exactly one entry (the current child).
  // Writes the new doc with status:'linked' so childrenStream picks it up
  // immediately without waiting for the child to call saveChildInfo.
  // Returns the 4-digit PIN that the parent must read aloud to the child.
  // Throws a readable Exception on validation or critical-write failure.
  Future<String> approveRequest({required String requestId}) async {
    // Read the request doc to get authoritative field values.
    final requestDoc = await _firestore
        .collection('link_requests')
        .doc(requestId)
        .get();

    if (!requestDoc.exists) {
      throw Exception('Request not found.');
    }

    final data = requestDoc.data()!;
    final childId = data['childId'] as String? ?? '';
    final childName = data['childName'] as String? ?? '';
    final familyId = data['familyId'] as String? ?? '';

    print('approveRequest: childId=$childId childName=$childName familyId=$familyId');

    if (childId.isEmpty || familyId.isEmpty) {
      throw Exception('Cannot approve: child has not scanned QR yet.');
    }

    // Delete ALL existing children docs before writing the new one.
    // Failure is non-blocking — log and continue so the new write still lands.
    try {
      final existing = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('children')
          .get();
      if (existing.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in existing.docs) {
          print('[CLEANUP-DELETED] childId=${doc.id}');
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      print('[CLEANUP-DONE] count=${existing.docs.length}');
    } catch (e) {
      print('[CLEANUP-FAILED] $e');
    }

    // Write the new child doc. status:'linked' is set here directly so
    // childrenStream surfaces the child immediately on the parent side.
    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('children')
        .doc(childId)
        .set({
      'childName': childName,
      'parentId': familyId,
      'childId': childId,
      'linkedAt': FieldValue.serverTimestamp(),
      'status': 'linked',
      'age': '',
      'phone': '',
    });
    print('approveRequest: wrote families/$familyId/children/$childId status=linked');

    // Generate 4-digit PIN and stamp the link_request as approved.
    final pin = (Random.secure().nextInt(9000) + 1000).toString();
    try {
      await _firestore
          .collection('link_requests')
          .doc(requestId)
          .update({
        'status': 'approved',
        'pin': pin,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      print('approveRequest: link_request=$requestId status=approved pin=$pin');
    } catch (e) {
      print('approveRequest: link_request update FAILED: $e');
    }

    return pin;
  }

  // Deletes all approved link_requests for a family once the child has
  // finished onboarding. The permanent child record in families/children
  // is not touched — only the temporary linking documents are removed.
  Future<void> cleanupLinkRequests(String familyId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('link_requests')
          .where('familyId', isEqualTo: familyId)
          .where('status', isEqualTo: 'approved')
          .get();
      for (final doc in query.docs) {
        await doc.reference.delete();
        print('cleanupLinkRequests: deleted ${doc.id}');
      }
    } catch (e) {
      print('cleanupLinkRequests ERROR: $e');
    }
  }

  // Handle Firebase Auth exceptions and return readable messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'email-already-in-use':
        return 'This email is linked to a pre-existing account';
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