import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<bool> isUsernameAvailable(String raw) async {
    final uname = _normalizeUsername(raw);
    if (uname.isEmpty) return false;
    final doc = await _db.collection('usernames').doc(uname).get();
    return !doc.exists;
  }

  Future<UserCredential> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final uname = _normalizeUsername(username);


    late final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException {
      rethrow; 
    }

    final uid = cred.user!.uid;
    final unameRef = _db.collection('usernames').doc(uname);
    final userRef  = _db.collection('users').doc(uid);

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
      try { await cred.user?.delete(); } catch (_) {}
      if (e is UsernameTakenException) {
        throw FirebaseAuthException(code: 'username-already-in-use', message: 'Username already taken.');
      }
      rethrow;
    }
  }

  String _normalizeUsername(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.-]'), '').replaceAll(RegExp(r'\s+'), '');
}

class UsernameTakenException implements Exception {}
