import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/app_user.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ??
           FirebaseFunctions.instanceFor(region: AppConstants.functionsRegion);

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Guide Registration & Login

  Future<AppUser> registerGuide({
    required String email,
    required String password,
    required String displayName,
    String? joinOrgCode,
    String? newOrgName,
  }) async {
    // Registration is fully server-side (org resolution + Auth user +
    // profile with role + claims). The client never writes a role.
    try {
      await _functions.httpsCallable('registerGuide').call({
        'email': email,
        'password': password,
        'displayName': displayName,
        'joinOrgCode': ?joinOrgCode,
        'newOrgName': ?newOrgName,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AuthFailure(
        code: e.message ?? e.code,
        message: e.message ?? e.code,
      );
    }

    // Now sign in with the freshly created credentials.
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return getAppUser(credential.user!.uid);
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

  // Kid Code-Based Login

  Future<AppUser> signInWithCode({required String code}) async {
    // Sign in anonymously first so the callable has an auth context.
    UserCredential credential;
    try {
      credential = await _auth.signInAnonymously();
    } catch (_) {
      throw AuthFailure(
        code: 'auth-error',
        message: 'Unable to sign in. Please try again.',
      );
    }
    final uid = credential.user!.uid;

    try {
      final result = await _functions.httpsCallable('claimCampCode').call({
        'code': code,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return AppUser(
        uid: uid,
        role: AppConstants.roleKid,
        displayName: data['displayName'] as String? ?? 'Campist',
        campId: data['campId'] as String?,
        team: data['team'] as String?,
        createdAt: DateTime.now(),
      );
    } on FirebaseFunctionsException catch (e) {
      // Clean up the anonymous user on any claim failure. Best-effort only —
      // a cleanup failure must not mask the real reason the claim failed.
      try {
        await _auth.currentUser?.delete();
        await _auth.signOut();
      } catch (_) {
        // Ignored: surfacing the original AuthFailure below matters more.
      }
      throw AuthFailure(
        code: e.message ?? e.code,
        message: e.message ?? e.code,
      );
    }
  }

  // Shared

  Future<AppUser> getAppUser(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();

    if (!doc.exists) {
      throw AuthFailure(
        code: 'user-not-found',
        message: 'User profile not found.',
      );
    }

    return AppUser.fromFirestore(doc);
  }

  Future<void> updateUserCampId(String uid, String campId) async {
    await _firestore.collection(AppConstants.usersCollection).doc(uid).update({
      'campId': campId,
    });
  }

  /// Forces a fresh ID token so custom-claim changes made server-side (e.g.
  /// the orgId set by the joinOrganization callable) take effect in security
  /// rules immediately instead of on the SDK's ~hourly auto-refresh.
  Future<void> refreshIdToken() async {
    await _auth.currentUser?.getIdToken(true);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Deletes the signed-in user's account server-side (guide: also their org
  /// if they own it; kid: their anonymous account + profile), then signs out.
  Future<void> deleteMyAccount() async {
    final callable = _functions.httpsCallable('deleteMyAccount');
    await callable.call();
    await _auth.signOut();
  }
}

class AuthFailure implements Exception {
  final String code;
  final String message;

  AuthFailure({required this.code, required this.message});

  @override
  String toString() => message;
}
