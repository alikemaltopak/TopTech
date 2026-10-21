import 'package:flutter_test/flutter_test.dart';
import 'package:irrigation_control_app/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthService auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = AuthService();
  });

  group('Yetkili girişi', () {
    test('başlangıçta oturum kapalı', () async {
      expect(await auth.isLoggedIn(), isFalse);
      expect(await auth.getEmail(), isNull);
    });

    test('yetkili kullanıcı doğru şifreyle giriş yapar ve oturum saklanır', () async {
      await auth.login('test@test.com', '123456');
      expect(await auth.isLoggedIn(), isTrue);
      expect(await auth.getEmail(), 'test@test.com');
      // Yeni bir servis örneği aynı oturumu görür (uygulama yeniden açıldığında)
      expect(await AuthService().isLoggedIn(), isTrue);
    });

    test('yanlış şifre reddedilir', () async {
      await expectLater(
        auth.login('test@test.com', 'yanlis'),
        throwsA(predicate((e) => e.toString().contains('Şifreniz hatalı'))),
      );
      expect(await auth.isLoggedIn(), isFalse);
    });

    test('listede olmayan e-posta reddedilir', () async {
      await expectLater(
        auth.login('yabanci@x.com', '123456'),
        throwsA(predicate((e) => e.toString().contains('yetkili kullanıcılar arasında bulunmamaktadır'))),
      );
      expect(await auth.isLoggedIn(), isFalse);
    });

    test('çıkış yapınca oturum ve e-posta temizlenir', () async {
      await auth.login('test@test.com', '123456');
      await auth.logout();
      expect(await auth.isLoggedIn(), isFalse);
      expect(await auth.getEmail(), isNull);
    });
  });

  group('Yönetici yetkileri', () {
    test('sadece admin@sirket.com yöneticidir', () async {
      await auth.login('admin@sirket.com', 'sifre123');
      expect(await auth.isAdmin(), isTrue);
      await auth.logout();
      await auth.login('kurulum@sirket.com', '123456');
      expect(await auth.isAdmin(), isFalse);
    });

    test('ilk kurulumda 3 yetkili kullanıcı tanımlı', () async {
      expect(await auth.getAllUserEmails(), unorderedEquals(['admin@sirket.com', 'kurulum@sirket.com', 'test@test.com']));
    });

    test('eklenen kullanıcı kalıcı olur ve giriş yapabilir', () async {
      await auth.addUser('yeni@sirket.com', 'parola');
      expect(await AuthService().getAllUserEmails(), contains('yeni@sirket.com'));
      await auth.login('yeni@sirket.com', 'parola');
      expect(await auth.isLoggedIn(), isTrue);
    });

    test('aynı e-posta ikinci kez eklenemez', () async {
      await expectLater(auth.addUser('test@test.com', 'x'), throwsA(predicate((e) => e.toString().contains('zaten kayıtlı'))));
    });

    test('silinen kullanıcı artık giriş yapamaz', () async {
      await auth.removeUser('test@test.com');
      expect(await auth.getAllUserEmails(), isNot(contains('test@test.com')));
      await expectLater(auth.login('test@test.com', '123456'), throwsException);
    });
  });
}
