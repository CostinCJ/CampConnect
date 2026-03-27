import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/app_user.dart';
import '../domain/camp_code.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // --- Guide Registration & Login ---

  Future<AppUser> registerGuide({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    final appUser = AppUser(
      uid: uid,
      role: AppConstants.roleGuide,
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set(appUser.toFirestore());

    return appUser;
  }

  Future<AppUser> signInGuide({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return getAppUser(credential.user!.uid);
  }

  // --- Kid Code-Based Login ---

  Future<AppUser> signInWithCode({
    required String code,
    required String campId,
  }) async {
    // Validate the code exists and is unused
    final codeDoc = await _firestore
        .collection(AppConstants.campsCollection)
        .doc(campId)
        .collection(AppConstants.codesSubcollection)
        .doc(code)
        .get();

    if (!codeDoc.exists) {
      throw FirebaseAuthException(
        code: 'invalid-code',
        message: 'This camp code does not exist.',
      );
    }

    final campCode = CampCode.fromFirestore(codeDoc);

    if (campCode.used) {
      throw FirebaseAuthException(
        code: 'code-used',
        message: 'This camp code has already been used.',
      );
    }

    // Check if camp session has ended
    final campDoc = await _firestore
        .collection(AppConstants.campsCollection)
        .doc(campId)
        .get();

    if (campDoc.exists) {
      final endDate = (campDoc.data()!['endDate'] as Timestamp).toDate();
      if (DateTime.now().isAfter(endDate)) {
        throw FirebaseAuthException(
          code: 'session-expired',
          message: 'This camp session has ended.',
        );
      }
    }

    // Sign in anonymously
    final credential = await _auth.signInAnonymously();
    final uid = credential.user!.uid;

    // Create user document
    final appUser = AppUser(
      uid: uid,
      role: AppConstants.roleKid,
      displayName: campCode.displayName,
      campId: campId,
      team: campCode.team,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set(appUser.toFirestore());

    // Mark code as used
    await _firestore
        .collection(AppConstants.campsCollection)
        .doc(campId)
        .collection(AppConstants.codesSubcollection)
        .doc(code)
        .update({
      'used': true,
      'usedBy': uid,
    });

    return appUser;
  }

  // --- Shared ---

  Future<AppUser> getAppUser(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();

    if (!doc.exists) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'User profile not found.',
      );
    }

    return AppUser.fromFirestore(doc);
  }

  Future<void> updateUserCampId(String uid, String campId) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({'campId': campId});
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

class FirebaseAuthException implements Exception {
  final String code;
  final String message;

  FirebaseAuthException({required this.code, required this.message});

  @override
  String toString() => message;
}
