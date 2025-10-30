import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  Future<UserCredential> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final uname = _normalizeUsername(username);
    late final UserCredential cred;

    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    }

    final uid = cred.user!.uid;
    final unameRef = _db.collection('usernames').doc(uname);
    final userRef = _db.collection('users').doc(uid);

    try {
      await _db.runTransaction((tx) async {
        final existing = await tx.get(unameRef);
        if (existing.exists) {
          throw UsernameTakenException();
        }

        tx.set(unameRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.set(userRef, {
          'uid': uid,
          'username': uname,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      return cred;
    } catch (e) {
      try {
        await cred.user?.delete();
      } catch (_) {}

      if (e is UsernameTakenException) {
        throw FirebaseAuthException(
          code: 'username-already-in-use',
          message: 'Username already taken.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCred =
          await _auth.signInWithCredential(credential);
      final User user = userCred.user!;

      final userRef = _db.collection('users').doc(user.uid);
      final doc = await userRef.get();

      bool firstTime = false;

      if (!doc.exists) {
        firstTime = true;

        final uname = _normalizeUsername(
            user.displayName ?? user.email!.split('@').first);
        final unameRef = _db.collection('usernames').doc(uname);
        final unameExists = await unameRef.get();
        String finalUname = uname;

        if (unameExists.exists) {
          finalUname = '$uname-${user.uid.substring(0, 5)}';
        }

        await _db.runTransaction((tx) async {
          tx.set(unameRef, {'uid': user.uid});
          tx.set(userRef, {
            'uid': user.uid,
            'username': finalUname,
            'email': user.email,
            'displayName': user.displayName,
            'photoURL': user.photoURL,
            'authProvider': 'google',
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
      }

      return {'user': user, 'firstTime': firstTime};
    } catch (e) {
      print('❌ Google Sign-In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<bool> isUsernameAvailable(String raw) async {
    final uname = _normalizeUsername(raw);
    if (uname.isEmpty) return false;
    final doc = await _db.collection('usernames').doc(uname).get();
    return !doc.exists;
  }

  String _normalizeUsername(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.-]'), '');
}

class UsernameTakenException implements Exception {}
