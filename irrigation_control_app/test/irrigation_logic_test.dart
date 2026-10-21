import 'package:flutter_test/flutter_test.dart';
import 'package:irrigation_control_app/irrigation_logic.dart';

void main() {
  group('SMS sulama komutları', () {
    test('süre seçilmişse "ON<dakika>" komutu üretilir', () {
      expect(irrigationStartCommand(const Duration(minutes: 30)), 'ON30');
      expect(irrigationStartCommand(const Duration(hours: 1, minutes: 15)), 'ON75');
    });

    test('süre seçilmemişse süresiz "ON" komutu üretilir', () {
      expect(irrigationStartCommand(null), 'ON');
    });

    test('kapatma komutu "OFF"', () {
      expect(irrigationOffCommand, 'OFF');
    });

    test('SMS URI\'si arazinin GSM numarasına ve komut gövdesine sahip', () {
      final uri = buildSmsUri('+905551112233', 'ON10');
      expect(uri.scheme, 'smsto');
      expect(uri.toString(), 'smsto:+905551112233?body=ON10');
      expect(uri.queryParameters['body'], 'ON10');
    });

    test('komut gövdesindeki özel karakterler URL-encode edilir', () {
      final uri = buildSmsUri('05551112233', 'ON 10&X');
      expect(uri.toString(), 'smsto:05551112233?body=ON%2010%26X');
      expect(uri.queryParameters['body'], 'ON 10&X');
    });
  });

  group('Hava durumuna göre arka plan', () {
    test('gündüz açık/güneşli → clear_day', () {
      expect(backgroundImageFor('Güneşli', 1), 'assets/images/clear_day.png');
      expect(backgroundImageFor('Açık', 1), 'assets/images/clear_day.png');
    });

    test('gece açık → clear_night', () {
      expect(backgroundImageFor('Açık', 0), 'assets/images/clear_night.jpeg');
    });

    test('bulutlu/kapalı → overcast (gündüz ve gece)', () {
      expect(backgroundImageFor('Parçalı bulutlu', 1), 'assets/images/cloudy_overcast_day.jpg');
      expect(backgroundImageFor('Kapalı', 1), 'assets/images/cloudy_overcast_day.jpg');
      expect(backgroundImageFor('Parçalı bulutlu', 0), 'assets/images/cloudy_overcast_night.jpeg');
      expect(backgroundImageFor('Kapalı', 0), 'assets/images/cloudy_overcast_night.jpeg');
    });

    test('tanınmayan durum için varsayılan görsel', () {
      expect(backgroundImageFor('Hafif yağmur', 1), 'assets/images/cloudy_overcast_day.jpg');
    });
  });

  group('Koordinat dönüştürme', () {
    test('sayı, metin ve Türkçe virgüllü ondalıkları double\'a çevirir', () {
      expect(convertToDouble(38.49), 38.49);
      expect(convertToDouble(27), 27.0);
      expect(convertToDouble(' 39.408435 '), 39.408435);
      expect(convertToDouble('32,912238'), 32.912238);
    });

    test('geçersiz değerlerde null döner', () {
      expect(convertToDouble(null), isNull);
      expect(convertToDouble('abc'), isNull);
      expect(convertToDouble(''), isNull);
      expect(convertToDouble(true), isNull);
    });
  });

  test('e-posta Firestore yolu için güvenli kimliğe çevrilir', () {
    expect(userIdFromEmail('ali.kemal@sirket.com'), 'ali_kemal_sirket_com');
  });

  group('Süre biçimlendirme', () {
    test('geri sayım SS:DD:ss formatında', () {
      expect(formatCountdown(const Duration(minutes: 30)), '00:30:00');
      expect(formatCountdown(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
      expect(formatCountdown(Duration.zero), '00:00:00');
    });

    test('geçmiş oturum süresi okunabilir biçimde', () {
      expect(formatSessionDuration(const Duration(seconds: 42)), '42sn');
      expect(formatSessionDuration(const Duration(minutes: 5, seconds: 7)), '05dk 07sn');
      expect(formatSessionDuration(const Duration(hours: 1, minutes: 5, seconds: 3)), '01sa 05dk 03sn');
      expect(formatSessionDuration(Duration.zero), '00sn');
    });

    test('bitmemiş oturum "Devam Ediyor" olarak gösterilir', () {
      expect(formatSessionDuration(null), 'Devam Ediyor');
    });
  });
}
