import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore eklendi
import 'package:shared_preferences/shared_preferences.dart'; 

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore örneği

  // O anki kullanıcıyı döndürür
  User? get currentUser => _auth.currentUser;

  // Kullanıcı giriş yapmış mı kontrolü
  Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  // Kullanıcı Dokümanını oluştur/güncelle (Helper Metot)
  Future<void> _ensureUserDoc(User user) async {
    final userEmail = user.email;
    if (userEmail == null) return;
    
    // E-postayı güvenli ID'ye çevir
    final userId = userEmail.replaceAll('.', '_').replaceAll('@', '_');
    final userDocRef = _firestore.collection('users').doc(userId);

    // Belge var mı kontrol et
    final docSnapshot = await userDocRef.get();

    if (!docSnapshot.exists) {
       // Yeni kullanıcı kaydı
       await userDocRef.set({
         'email': userEmail,
         'createdAt': FieldValue.serverTimestamp(),
         'lastLogin': FieldValue.serverTimestamp(),
       });
    } else {
      // Sadece son giriş zamanını güncelle
      await userDocRef.update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    }
  }


  // Email ve Şifre ile Giriş
  Future<UserCredential> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Başarılı giriş sonrası kullanıcı kaydını doğrula/güncelle
      if (credential.user != null) {
        await _ensureUserDoc(credential.user!);
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Bu e-posta adresi ile kayıtlı kullanıcı bulunamadı.');
      } else if (e.code == 'wrong-password') {
        throw Exception('Şifre yanlış.');
      } else {
        throw Exception('Giriş başarısız: ${e.message}');
      }
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // Kayıt Olma
  Future<UserCredential> register(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Kayıt başarılıysa Firestore'a kullanıcıyı ekle
      if (credential.user != null) {
        await _ensureUserDoc(credential.user!);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception('Şifre çok zayıf.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('Bu e-posta adresi zaten kullanımda.');
      } else {
        throw Exception('Kayıt başarısız: ${e.message}');
      }
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // Google ile Giriş
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Google Sign In sürecini başlat
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google girişi iptal edildi.');
      }

      // Google kimlik doğrulama detaylarını al
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase için yeni bir credential oluştur
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase'e giriş yap
      final userCredential = await _auth.signInWithCredential(credential);

      // Başarılı giriş/kayıt sonrası Firestore'u güncelle
      if (userCredential.user != null) {
        await _ensureUserDoc(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      throw Exception('Google ile giriş başarısız: $e');
    }
  }

  // Çıkış Yap
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Kullanıcı e-postasını getir
  Future<String?> getEmail() async {
    return _auth.currentUser?.email;
  }

  // Admin kontrolü
  Future<bool> isAdmin() async {
    final email = _auth.currentUser?.email;
    return email == 'admin@sirket.com';
  }
  
  // Admin Metotları (Dummy)
  
  Future<List<String>> getAllUserEmails() async {
    // Normalde bu işlem için Cloud Functions veya Admin SDK gerekir.
    // Şimdilik sadece mevcut kullanıcının emailini veya sabit bir liste döndürebiliriz.
    return ['admin@sirket.com', 'demo@test.com']; 
  }

  Future<void> addUser(String email, String password) async {
     // Client SDK ile başka kullanıcı oluşturmak, oturumu o kullanıcıya geçirir.
     // Bu metot admin panelinden başkasını eklemek için kullanılıyorsa, Firebase Console kullanılmalıdır.
     throw Exception("Kullanıcı ekleme işlemi Firebase Konsolu üzerinden yapılmalıdır.");
  }

  Future<void> removeUser(String email) async {
    throw Exception("Kullanıcı silme işlemi Firebase Konsolu üzerinden yapılmalıdır.");
  }
}
