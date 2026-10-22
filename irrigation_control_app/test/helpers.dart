import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:irrigation_control_app/auth_service.dart';
import 'package:irrigation_control_app/irrigation_logic.dart';

/// Parolayı gerçekten kontrol eden sahte Firebase Auth (e-posta → (uid, parola)).
class FakeAuth extends MockFirebaseAuth {
  final Map<String, (String, String)> accounts;
  FakeAuth(this.accounts) : super();

  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) {
    final account = accounts[email];
    if (account == null || account.$2 != password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    mockUser = MockUser(uid: account.$1, email: email);
    return super.signInWithEmailAndPassword(email: email, password: password);
  }
}

/// Örnek ortam: yönetici, kurulum yetkilisi, pasifleştirilmiş hesap ve listede olmayan bir Firebase hesabı.
class TestBackend {
  final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
  final FakeAuth auth = FakeAuth({
    'admin@sirket.com': ('a1', 'sifre123'),
    'kurulum@sirket.com': ('t1', '123456'),
    'eski@sirket.com': ('o1', '123456'),
    'yabanci@x.com': ('u9', '123456'),
  });
  late final AuthService authService = AuthService(
    auth: auth,
    firestore: firestore,
    createUser: (email, password) async {
      final uid = 'new${auth.accounts.length}';
      auth.accounts[email] = (uid, password);
      return uid;
    },
  );

  CollectionReference<Map<String, dynamic>> get authorizedUsers => firestore.collection(authorizedUsersCollectionPath);

  Future<TestBackend> seed() async {
    await authorizedUsers.doc('a1').set({'email': 'admin@sirket.com', 'role': 'admin', 'active': true});
    await authorizedUsers.doc('t1').set({'email': 'kurulum@sirket.com', 'role': 'installer', 'active': true});
    await authorizedUsers.doc('o1').set({'email': 'eski@sirket.com', 'role': 'installer', 'active': false});
    return this;
  }
}
