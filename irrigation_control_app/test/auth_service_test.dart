import 'package:flutter_test/flutter_test.dart';
import 'package:irrigation_control_app/auth_service.dart';

import 'helpers.dart';

void main() {
  late TestBackend backend;
  late AuthService auth;

  setUp(() async {
    backend = await TestBackend().seed();
    auth = backend.authService;
  });

  group('Yetkili girişi (Firebase Authentication)', () {
    test('başlangıçta oturum kapalı', () async {
      expect(await auth.isLoggedIn(), isFalse);
      expect(await auth.getEmail(), isNull);
    });

    test('yetkili hesap doğru şifreyle giriş yapar', () async {
      await auth.login('kurulum@sirket.com', '123456');
      expect(await auth.isLoggedIn(), isTrue);
      expect(await auth.getEmail(), 'kurulum@sirket.com');
      expect(auth.currentUid, 't1');
    });

    test('yanlış şifre reddedilir; hangi bilginin yanlış olduğu söylenmez', () async {
      await expectLater(
        auth.login('kurulum@sirket.com', 'yanlis'),
        throwsA(predicate((e) => e.toString().contains('E-posta veya şifre hatalı'))),
      );
      expect(await auth.isLoggedIn(), isFalse);
    });

    test('Firebase hesabı olan ama yetkili listesinde olmayan kişi giremez ve oturumu kapatılır', () async {
      await expectLater(
        auth.login('yabanci@x.com', '123456'),
        throwsA(predicate((e) => e.toString().contains('yetkili kullanıcılar arasında bulunmamaktadır'))),
      );
      expect(backend.auth.currentUser, isNull);
    });

    test('erişimi kaldırılmış (pasif) hesap giremez', () async {
      await expectLater(auth.login('eski@sirket.com', '123456'), throwsException);
      expect(backend.auth.currentUser, isNull);
    });

    test('oturum açıkken erişimi kaldırılırsa bir sonraki kontrolde oturum kapatılır', () async {
      await auth.login('kurulum@sirket.com', '123456');
      await backend.authorizedUsers.doc('t1').update({'active': false});
      expect(await auth.isLoggedIn(), isFalse);
      expect(backend.auth.currentUser, isNull);
    });

    test('çıkış yapınca oturum kapanır', () async {
      await auth.login('kurulum@sirket.com', '123456');
      await auth.logout();
      expect(await auth.isLoggedIn(), isFalse);
    });

    test('Firebase hata kodları Türkçe mesaja çevrilir', () {
      expect(loginErrorMessage('too-many-requests'), contains('Çok fazla deneme'));
      expect(loginErrorMessage('user-not-found'), loginErrorMessage('wrong-password'));
      expect(createUserErrorMessage('weak-password'), contains('en az 6 karakter'));
    });
  });

  group('Yönetici yetkileri', () {
    test('sadece "admin" rolündeki hesap yöneticidir', () async {
      await auth.login('admin@sirket.com', 'sifre123');
      expect(await auth.isAdmin(), isTrue);
      await auth.logout();
      await auth.login('kurulum@sirket.com', '123456');
      expect(await auth.isAdmin(), isFalse);
    });

    test('etkin yetkililer listelenir, yönetici en üstte; pasif hesap listede yok', () async {
      final users = await auth.getAllUsers();
      expect(users.map((u) => u.email), ['admin@sirket.com', 'kurulum@sirket.com']);
      expect(users.first.isAdmin, isTrue);
    });

    test('eklenen kullanıcı Firebase hesabıyla oluşturulur, listeye girer ve giriş yapabilir', () async {
      await auth.addUser('Saha@Sirket.com ', 'parola123');
      final added = (await backend.authorizedUsers.where('email', isEqualTo: 'saha@sirket.com').get()).docs.single;
      expect(added.data(), containsPair('role', 'installer'));
      expect(added.data(), containsPair('active', true));
      await auth.login('saha@sirket.com', 'parola123');
      expect(await auth.isLoggedIn(), isTrue);
    });

    test('parola hiçbir yerde saklanmaz (sadece Firebase Authentication\'da)', () async {
      await auth.addUser('saha@sirket.com', 'parola123');
      final docs = (await backend.authorizedUsers.get()).docs;
      for (final d in docs) {
        expect(d.data().keys, isNot(contains('password')));
        expect(d.data().values, isNot(contains('parola123')));
      }
    });

    test('etkin bir e-posta ikinci kez eklenemez; pasif hesap yeniden etkinleştirilir', () async {
      await expectLater(auth.addUser('kurulum@sirket.com', 'x123456'), throwsA(predicate((e) => e.toString().contains('zaten kayıtlı'))));
      await auth.addUser('eski@sirket.com', 'yeniparola');
      expect((await backend.authorizedUsers.doc('o1').get()).data()!['active'], isTrue);
    });

    test('kullanıcı silinince erişimi kalkar ve giriş yapamaz; yönetici silinemez', () async {
      await auth.removeUser('kurulum@sirket.com');
      expect((await backend.authorizedUsers.doc('t1').get()).data()!['active'], isFalse);
      await expectLater(auth.login('kurulum@sirket.com', '123456'), throwsException);
      await expectLater(auth.removeUser('admin@sirket.com'), throwsA(predicate((e) => e.toString().contains('Yönetici'))));
    });
  });
}
