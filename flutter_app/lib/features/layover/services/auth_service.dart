import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CrewUser {
  final String uid;
  final String email;
  final String name;
  final String rank;
  final String employeeId;
  final bool isAdmin;
  final DateTime joinedAt;

  const CrewUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.rank,
    required this.employeeId,
    required this.isAdmin,
    required this.joinedAt,
  });

  factory CrewUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CrewUser(
      uid: doc.id,
      email: d['email'] ?? '',
      name: d['name'] ?? d['displayName'] ?? '',
      // F28: registration (core/auth) writes `rankCode`; some legacy docs
      // carry `rank`. Accept either so the profile rank is never silently
      // empty for one writer family.
      rank: d['rank'] ?? d['rankCode'] ?? '',
      employeeId: d['employeeId'] ?? '',
      isAdmin: d['isAdmin'] ?? false,
      joinedAt: (d['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<CrewUser?> getCrewUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return CrewUser.fromFirestore(doc);
  }

  Stream<CrewUser?> crewUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
      (doc) => doc.exists ? CrewUser.fromFirestore(doc) : null,
    );
  }

  bool isAdmin(String email) => email == 'NajmAssistance@gmail.com';

  Future<void> signOut() => _auth.signOut();
}
