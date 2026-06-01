import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String? _verificationId;
  int? _resendToken;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;
  bool get isLoggedIn => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
    void Function(PhoneAuthCredential credential)? onAutoVerify,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: _resendToken,
      verificationCompleted: (credential) async {
        if (onAutoVerify != null) onAutoVerify(credential);
      },
      verificationFailed: (e) {
        String msg = 'Verification failed';
        if (e.code == 'invalid-phone-number') {
          msg = 'Invalid phone number';
        } else if (e.code == 'too-many-requests') {
          msg = 'Too many requests. Try again later.';
        } else if (e.message != null) {
          msg = e.message!;
        }
        onError(msg);
      },
      codeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        onCodeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<UserCredential?> verifyOtp(String otp) async {
    if (_verificationId == null) throw Exception('No verification in progress');

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );

    return await _auth.signInWithCredential(credential);
  }

  Future<UserCredential?> signInWithCredential(
      PhoneAuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }

  Future<bool> isPartnerRegistered(String uid) async {
    final doc = await _db.collection('partners').doc(uid).get();
    return doc.exists;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
