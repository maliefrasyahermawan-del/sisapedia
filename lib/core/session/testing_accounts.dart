import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/models/user_model.dart';

/// Fixed credentials for the two "testing account" login buttons, so
/// tapping the same button on any device signs into the SAME real Firebase
/// identity — that's what lets two phones (one logged in as Sumber, one as
/// Pengolah) see each other's data live via Firestore, without either one
/// ever filling out a registration form.
class TestingAccount {
  const TestingAccount({
    required this.email,
    required this.password,
    required this.displayName,
    this.telepon,
  });

  final String email;
  final String password;
  final String displayName;
  final String? telepon;
}

const kTestingSumberAccount = TestingAccount(
  email: 'testing.sumber@sisapedia.app',
  password: 'SisaPedia-Testing-2026',
  displayName: 'Budi (Akun Testing)',
);

const kTestingPengolahAccount = TestingAccount(
  email: 'testing.pengolah@sisapedia.app',
  password: 'SisaPedia-Testing-2026',
  displayName: 'Bank Sampah Melati Bersih',
  telepon: '0812-3456-7890',
);

/// Signs into [account]'s fixed Firebase Auth identity, registering it on
/// first use (on whichever device happens to tap the button first) and
/// signing in normally on every later tap/device. `email-already-in-use`
/// on the create attempt is exactly how we detect "someone already claimed
/// this testing account" and fall back to sign-in — no separate check
/// needed, and it's safe under a race between two devices tapping at once.
Future<String> signInTestingAccount(TestingAccount account) async {
  final auth = FirebaseAuth.instance;
  UserCredential credential;
  try {
    credential = await auth.createUserWithEmailAndPassword(
      email: account.email,
      password: account.password,
    );
    await credential.user?.updateDisplayName(account.displayName);
  } on FirebaseAuthException catch (e) {
    if (e.code != 'email-already-in-use') rethrow;
    credential = await auth.signInWithEmailAndPassword(
      email: account.email,
      password: account.password,
    );
  }
  final uid = credential.user!.uid;

  if (account.email == kTestingSumberAccount.email) {
    final usersRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await usersRef.get();
    if (!snap.exists) {
      final profile = UserModel(
        uid: uid,
        name: account.displayName,
        email: account.email,
      );
      await usersRef.set(profile.toMap());
    }
  }

  return uid;
}
