import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static String get initialRoute => isLoggedIn ? '/home' : '/login';
  static bool get isLoggedIn => _auth.currentUser != null;
  static String? get uid => _auth.currentUser?.uid;
  static String? get email => _auth.currentUser?.email;
  static String displayName() => _auth.currentUser?.displayName ?? email ?? 'Farmer';

  static Future<void> signUp(String email, String pass, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: pass);
    await cred.user?.updateDisplayName(name);
  }

  static Future<void> signIn(String email, String pass) async {
    await _auth.signInWithEmailAndPassword(email: email, password: pass);
  }

  static Future<void> signOut() => _auth.signOut();
}
