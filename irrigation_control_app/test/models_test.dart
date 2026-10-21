import 'package:flutter_test/flutter_test.dart';
import 'package:irrigation_control_app/land_service.dart';
import 'package:irrigation_control_app/main.dart';

void main() {
  group('Land modeli (Firestore eşlemesi)', () {
    test('Firestore dokümanından eksiksiz okunur', () {
      final land = Land.fromMap('abc', {
        'name': 'Zeytinlik',
        'phoneNumber': '+905551112233',
        'latitude': 38.49,
        'longitude': 27,
      });
      expect(land.id, 'abc');
      expect(land.name, 'Zeytinlik');
      expect(land.phoneNumber, '+905551112233');
      expect(land.latitude, 38.49);
      expect(land.longitude, 27.0); // int → double
    });

    test('eksik alanlarda güvenli varsayılanlar kullanılır', () {
      final land = Land.fromMap('x', {});
      expect(land.name, 'Bilinmeyen Arazi');
      expect(land.phoneNumber, '');
      expect(land.latitude, isNull);
      expect(land.longitude, isNull);
    });
  });

  group('IrrigationSession', () {
    test('bitiş zamanı varsa süre hesaplanır', () {
      final start = DateTime(2026, 10, 21, 5, 30);
      final s = IrrigationSession(start, endTime: start.add(const Duration(minutes: 12, seconds: 5)), landName: 'Bahçe');
      expect(s.duration, const Duration(minutes: 12, seconds: 5));
    });

    test('devam eden oturumun süresi yoktur', () {
      final s = IrrigationSession(DateTime.now(), landName: 'Bahçe');
      expect(s.duration, isNull);
    });
  });
}
