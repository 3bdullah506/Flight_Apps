import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      throw Exception('فشل تسجيل الدخول: ${e.toString()}');
    }
  }

  Future<User?> registerWithEmail(
      String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user != null) {
        await _db.collection('users').doc(result.user!.uid).set({
          'name': name,
          'email': email,
          'phone': '',
          'address': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return result.user;
    } catch (e) {
      throw Exception('فشل إنشاء الحساب: ${e.toString()}');
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);

      if (result.additionalUserInfo?.isNewUser == true) {
        await _db.collection('users').doc(result.user!.uid).set({
          'name': result.user!.displayName ?? '',
          'email': result.user!.email ?? '',
          'phone': '',
          'address': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return result.user;
    } catch (e) {
      throw Exception('فشل تسجيل الدخول بـ Google: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
