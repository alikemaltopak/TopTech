import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:irrigation_control_app/irrigation_logic.dart';

/// Yeni bir Firebase Auth hesabı açıp uid'sini döndürür (yönetici kullanıcı eklerken).
typedef UserCreator = Future<String> Function(String email, String password);

/// Yetkili listesindeki bir hesap.
class AuthorizedUser {
  final String uid;
  final String email;
  final String role; // 'admin' | 'installer'
  final bool active;

  const AuthorizedUser({required this.uid, required this.email, required this.role, required this.active});

  bool get isAdmin => role == 'admin';
}

/// Giriş Firebase Authentication ile yapılır; parolalar uygulamada veya telefonda SAKLANMAZ.
/// Uygulamayı sadece yöneticinin yetkilendirdiği hesaplar kullanabilir:
///   artifacts/remote-irrigation-app/authorized_users/{uid} = { email, role, active }
/// Firestore kuralları da aynı listeyi kontrol eder; listede olmayan hesap hiçbir veriyi göremez.
class AuthService {
  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  final UserCreator? _userCreatorOverride;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore, UserCreator? createUser})
      : _authOverride = auth,
        _firestoreOverride = firestore,
        _userCreatorOverride = createUser;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _authorizedUsers =>
      _firestore.collection(authorizedUsersCollectionPath);

  /// Oturumdaki kullanıcının uid'si (yoksa null).
  String? get currentUid => _auth.currentUser?.uid;

  Future<AuthorizedUser?> _authorizedUser(String uid) async {
    final snap = await _authorizedUsers.doc(uid).get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    return AuthorizedUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'installer',
      active: data['active'] == true,
    );
  }

  // YETKİLENDİRME VE DURUM METOTLARI

  /// Oturum açık VE hesap hâlâ yetkili mi? Yetkisi kaldırılmışsa oturum kapatılır.
  Future<bool> isLoggedIn() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final account = await _authorizedUser(user.uid);
      if (account == null || !account.active) {
        await _auth.signOut();
        return false;
      }
      return true;
    } on FirebaseException {
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw Exception(loginErrorMessage(e.code));
    }

    final account = await _authorizedUser(_auth.currentUser!.uid).catchError((_) => null);
    if (account == null || !account.active) {
      await _auth.signOut();
      throw Exception('Giriş Başarısız: Bu e-posta adresi yetkili kullanıcılar arasında bulunmamaktadır.');
    }
  }

  Future<bool> isAdmin() async {
    final uid = currentUid;
    if (uid == null) return false;
    final account = await _authorizedUser(uid);
    return account != null && account.active && account.isAdmin;
  }

  Future<void> logout() => _auth.signOut();

  Future<String?> getEmail() async => _auth.currentUser?.email;

  // YÖNETİCİ METOTLARI (Firestore kuralları sadece yöneticilere izin verir)

  /// Yeni kurulum yetkilisi ekler. Hesap daha önce pasifleştirildiyse yeniden etkinleştirilir.
  Future<void> addUser(String email, String password) async {
    email = email.trim().toLowerCase();
    final existing = await _authorizedUsers.where('email', isEqualTo: email).get();
    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      if (doc.data()['active'] == true) {
        throw Exception('Bu e-posta adresi zaten kayıtlıdır.');
      }
      await doc.reference.update({'active': true});
      return;
    }

    final String uid;
    try {
      uid = await (_userCreatorOverride ?? _createWithSecondaryApp)(email, password);
    } on FirebaseAuthException catch (e) {
      throw Exception(createUserErrorMessage(e.code));
    }
    await _authorizedUsers.doc(uid).set({
      'email': email,
      'role': 'installer',
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Kullanıcının erişimini kaldırır (hesap pasifleştirilir; Firebase Auth hesabını konsoldan silebilirsiniz).
  Future<void> removeUser(String email) async {
    final matches = await _authorizedUsers.where('email', isEqualTo: email.trim().toLowerCase()).get();
    for (final doc in matches.docs) {
      if (doc.data()['role'] == 'admin') {
        throw Exception('Yönetici hesabı silinemez.');
      }
      await doc.reference.update({'active': false});
    }
  }

  /// Etkin yetkili hesaplar (yönetim sayfası için).
  Future<List<AuthorizedUser>> getAllUsers() async {
    final snap = await _authorizedUsers.where('active', isEqualTo: true).get();
    final users = snap.docs
        .map((d) => AuthorizedUser(
              uid: d.id,
              email: d.data()['email'] as String? ?? '',
              role: d.data()['role'] as String? ?? 'installer',
              active: true,
            ))
        .toList()
      ..sort((a, b) => a.isAdmin == b.isAdmin ? a.email.compareTo(b.email) : (a.isAdmin ? -1 : 1));
    return users;
  }

  Future<List<String>> getAllUserEmails() async => (await getAllUsers()).map((u) => u.email).toList();

  /// Yöneticinin kendi oturumunu kapatmadan yeni hesap açmak için ikinci bir Firebase örneği kullanılır.
  static Future<String> _createWithSecondaryApp(String email, String password) async {
    final app = await Firebase.initializeApp(
      name: 'user-admin-${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: app);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(email: email, password: password);
      await secondaryAuth.signOut();
      return credential.user!.uid;
    } finally {
      await app.delete();
    }
  }
}

/// Firebase giriş hata kodlarını kullanıcıya gösterilecek Türkçe mesaja çevirir.
String loginErrorMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'Giriş Başarısız: E-posta adresi geçersiz.';
    case 'user-disabled':
      return 'Giriş Başarısız: Bu hesap devre dışı bırakılmış.';
    case 'too-many-requests':
      return 'Giriş Başarısız: Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.';
    case 'network-request-failed':
      return 'Giriş Başarısız: İnternet bağlantısı kurulamadı.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    default:
      // Hangi bilginin yanlış olduğu söylenmez (hesap varlığını sızdırmamak için)
      return 'Giriş Başarısız: E-posta veya şifre hatalı.';
  }
}

/// Yeni kullanıcı oluşturma hata kodlarını Türkçe mesaja çevirir.
String createUserErrorMessage(String code) {
  switch (code) {
    case 'email-already-in-use':
      return 'Bu e-posta ile zaten bir hesap var. Firebase konsolundan hesabı kontrol edin.';
    case 'weak-password':
      return 'Şifre en az 6 karakter olmalıdır.';
    case 'invalid-email':
      return 'E-posta adresi geçersiz.';
    default:
      return 'Kullanıcı oluşturulamadı ($code).';
  }
}
