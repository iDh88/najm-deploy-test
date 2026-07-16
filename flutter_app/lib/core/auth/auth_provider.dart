import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../../shared/constants/constants.dart';

// ─── Firebase Auth instance ───────────────────────────────────────────────────
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// ─── Auth State Stream ────────────────────────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// ─── Current CIP User ────────────────────────────────────────────────────────
final currentUserProvider = StreamProvider<CIPUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) => doc.exists ? CIPUser.fromFirestore(doc) : null);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// ─── Auth Service ─────────────────────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({required FirebaseAuth auth, required FirebaseFirestore firestore})
      : _auth = auth,
        _firestore = firestore;

  // ── Sign Up ──────────────────────────────────────────────────────────────
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String crewId,
    required String name,
    required String nameAr,
    required String baseStation,
    required CrewRank rank,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = CIPUser(
        id: credential.user!.uid,
        crewId: crewId,
        name: name,
        nameAr: nameAr,
        rank: rank,
        baseStation: baseStation,
        email: email,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(_userToFirestore(user));

      return AuthResult.success(credential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e));
    }
  }

  // ── Sign In ──────────────────────────────────────────────────────────────
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check account status
      final userDoc = await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .get();
      
      final status = userDoc.data()?['accountStatus'] as String? ?? 'pending';
      
      if (status == 'suspended') {
        await _auth.signOut();
        return AuthResult.failure('account_suspended');
      }
      if (status == 'rejected') {
        await _auth.signOut();
        return AuthResult.failure('account_rejected');
      }

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .update({'lastActiveAt': FieldValue.serverTimestamp()});

      return AuthResult.success(credential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e));
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Password Reset ───────────────────────────────────────────────────────
  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e));
    }
  }

  // ── Update User Profile ──────────────────────────────────────────────────
  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    await _firestore.collection('users').doc(userId).update({
      ...updates,
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Update User Mode ─────────────────────────────────────────────────────
  Future<void> updateUserMode(String userId, UserMode mode) async {
    await _firestore.collection('users').doc(userId).update({
      'userMode': mode.name,
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Update Preferences ───────────────────────────────────────────────────
  Future<void> updatePreferences(String userId, UserPreferences prefs) async {
    await _firestore.collection('users').doc(userId).update({
      'preferences': _prefsToFirestore(prefs),
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Delete Account ───────────────────────────────────────────────────────
  Future<void> deleteAccount(String userId) async {
    // Trigger server-side deletion pipeline via Cloud Function
    await _firestore.collection('deletionRequests').add({
      'userId': userId,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    await _auth.currentUser?.delete();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Map<String, dynamic> _userToFirestore(CIPUser user) {
    return {
      'crewId': user.crewId,
      'name': user.name,
      'nameAr': user.nameAr,
      'rank': user.rank.name,
      'baseStation': user.baseStation,
      'fleetTypes': user.fleetTypes,
      'email': user.email,
      'phone': user.phone,
      'preferences': _prefsToFirestore(user.preferences),
      'userMode': user.userMode.name,
      'subscriptionTier': user.subscriptionTier.name,
      'coldStartPhase': user.coldStartPhase,
      'totalMonthsActive': user.totalMonthsActive,
      'privacyConsents': {
        'behaviorTracking': user.privacyConsents.behaviorTracking,
        'collaborativeFiltering': user.privacyConsents.collaborativeFiltering,
        'consentDate': user.privacyConsents.consentDate != null
            ? Timestamp.fromDate(user.privacyConsents.consentDate!)
            : null,
      },
      'locale': user.locale,
      'accountStatus': 'pending',
      'rankCode': user.rank.name,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _prefsToFirestore(UserPreferences prefs) {
    return {
      'preferredDest': prefs.preferredDest,
      'avoidedDest': prefs.avoidedDest,
      'preferredOff': prefs.preferredOff,
      'maxDutyHours': prefs.maxDutyHours,
      'minRestHours': prefs.minRestHours,
      'homebaseReturn': prefs.homebaseReturn,
    };
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found': return 'auth_error_user_not_found';
      case 'wrong-password': return 'auth_error_wrong_password';
      case 'email-already-in-use': return 'auth_error_email_in_use';
      case 'weak-password': return 'auth_error_weak_password';
      case 'invalid-email': return 'auth_error_invalid_email';
      case 'too-many-requests': return 'auth_error_too_many_requests';
      case 'network-request-failed': return 'auth_error_network';
      case 'account_suspended': return 'Your account has been suspended. Contact '
          '${AppConstants.supportEmail}';
      case 'account_rejected': return 'Your account registration was not approved. Contact '
          '${AppConstants.supportEmail}';
      default: return 'auth_error_unknown';
    }
  }
}

// ─── Auth Result ─────────────────────────────────────────────────────────────
class AuthResult {
  final User? user;
  final String? error;
  bool get isSuccess => error == null;

  const AuthResult._({this.user, this.error});
  factory AuthResult.success(User? user) => AuthResult._(user: user);
  factory AuthResult.failure(String error) => AuthResult._(error: error);
}
