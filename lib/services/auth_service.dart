import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.displayName,
    this.email = '',
  });

  final String id;
  final String displayName;
  final String email;
}

abstract class AuthService {
  Stream<AuthUser?> authStateChanges();
  AuthUser? get currentUser;
  Future<void> signInWithGoogle();
  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    required this.auth,
    required this.firestore,
    GoogleSignIn? googleSignIn,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final GoogleSignIn _googleSignIn;

  @override
  Stream<AuthUser?> authStateChanges() => auth.authStateChanges().map(
    (user) => user == null
        ? null
        : AuthUser(
            id: user.uid,
            displayName: user.displayName ?? 'User',
            email: user.email ?? '',
          ),
  );

  @override
  AuthUser? get currentUser {
    final user = auth.currentUser;
    return user == null
        ? null
        : AuthUser(
            id: user.uid,
            displayName: user.displayName ?? 'User',
            email: user.email ?? '',
          );
  }

  @override
  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await auth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) return;

    final reference = firestore.collection('users').doc(user.uid);
    await firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      final data = <String, Object?>{
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'lastLoginAt': FieldValue.serverTimestamp(),
      };
      if (!existing.exists) data['createdAt'] = FieldValue.serverTimestamp();
      transaction.set(reference, data, SetOptions(merge: true));
    });
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await auth.signOut();
  }
}
