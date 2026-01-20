import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthService {
  static const String _keyLoggedIn = 'logged_in';
  static const String _keyEmail = 'user_email';
  // Yetkili kullanıcıları SharedPreferences'ta saklamak için yeni anahtar
  static const String _keyAuthUsers = 'authorized_users';

  // Başlangıçta yetkili olan kullanıcılar (Sadece ilk kurulum için kullanılır)
  // NOT: İlk kez çalıştırıldığında bu liste kaydedilir.
  static const Map<String, String> _initialUsers = {
    'admin@sirket.com': 'sifre123',
    'kurulum@sirket.com': '123456',
    'test@test.com': '123456',
  };

  // Yetkili kullanıcı listesini yerel depolamadan çeker.
  Future<Map<String, String>> _getAuthorizedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyAuthUsers);

    if (userJson != null) {
      // JSON'dan Map<String, dynamic> olarak alıp, Map<String, String>'e dönüştürüyoruz.
      return Map<String, String>.from(json.decode(userJson));
    }

    // Eğer depolamada liste yoksa, başlangıç listesini kaydet ve kullan.
    await _saveAuthorizedUsers(_initialUsers);
    return _initialUsers;
  }

  // Yetkili kullanıcı listesini yerel depolamaya kaydeder.
  Future<void> _saveAuthorizedUsers(Map<String, String> users) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = json.encode(users);
    await prefs.setString(_keyAuthUsers, userJson);
  }

  // YÖNETİCİ METOTLARI

  // YENİ METOT: Kullanıcı ekleme
  Future<void> addUser(String email, String password) async {
    final users = await _getAuthorizedUsers();
    if (users.containsKey(email)) {
      throw Exception('Bu e-posta adresi zaten kayıtlıdır.');
    }
    users[email] = password;
    await _saveAuthorizedUsers(users);
  }

  // YENİ METOT: Kullanıcı silme
  Future<void> removeUser(String email) async {
    final users = await _getAuthorizedUsers();
    if (users.remove(email) != null) {
      await _saveAuthorizedUsers(users);
    }
  }

  // YENİ METOT: Kullanıcı listesini Admin Page için döndürür
  Future<List<String>> getAllUserEmails() async {
    final users = await _getAuthorizedUsers();
    return users.keys.toList();
  }

  // YETKİLENDİRME VE DURUM METOTLARI

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  Future<void> login(String email, String password) async {
    final users = await _getAuthorizedUsers();

    if (!users.containsKey(email)) {
      throw Exception('Giriş Başarısız: Bu e-posta adresi yetkili kullanıcılar arasında bulunmamaktadır.');
    }

    if (users[email] != password) {
      throw Exception('Giriş Başarısız: Şifreniz hatalı.');
    }

    // Doğrulama başarılı
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, true);
    await prefs.setString(_keyEmail, email);
  }

  // YENİ METOT (HATAYI DÜZELTEN): Kullanıcının yönetici olup olmadığını kontrol etme
  Future<bool> isAdmin() async {
     final email = await getEmail();
     // Sadece 'admin@sirket.com' hesabı yöneticidir
     return email == 'admin@sirket.com';
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoggedIn);
    await prefs.remove(_keyEmail);
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }
}

