import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrigation_control_app/history_service.dart';
import 'package:irrigation_control_app/land_service.dart';
import 'package:irrigation_control_app/main.dart';

import 'helpers.dart';

// Veriler e-posta yerine Firebase Auth uid'si altında (kurulum@sirket.com → t1)
const historyPath = 'artifacts/remote-irrigation-app/users/t1/history';
const landsPath = 'artifacts/remote-irrigation-app/users/t1/lands';

void main() {
  late TestBackend backend;
  late FakeFirebaseFirestore firestore;
  late HistoryService history;
  late LandService lands;

  setUp(() async {
    backend = await TestBackend().seed();
    await backend.authService.login('kurulum@sirket.com', '123456');
    firestore = backend.firestore;
    history = HistoryService(firestore: firestore, authService: backend.authService);
    lands = LandService(firestore: firestore, authService: backend.authService);
  });

  group('Sulama geçmişi Firestore kaydı', () {
    test('sulama başlayınca oturum "active" olarak kullanıcının geçmişine yazılır', () async {
      final start = DateTime(2026, 10, 21, 5, 30);
      final session = IrrigationSession(start, landName: 'Zeytinlik', landId: 'l1');
      final id = await history.addSession(session);

      expect(session.id, id);
      final doc = await firestore.collection(historyPath).doc(id).get();
      expect(doc.exists, isTrue);
      expect(doc['landName'], 'Zeytinlik');
      expect(doc['landId'], 'l1');
      expect((doc['startTime'] as Timestamp).toDate(), start);
      expect(doc['endTime'], isNull);
      expect(doc['status'], 'active');
    });

    test('sulama bitince bitiş zamanı, süre ve "completed" durumu yazılır', () async {
      final start = DateTime(2026, 10, 21, 5, 30);
      final id = await history.addSession(IrrigationSession(start, landName: 'Zeytinlik'));
      await history.updateSession(id, start.add(const Duration(minutes: 12, seconds: 30)));

      final doc = await firestore.collection(historyPath).doc(id).get();
      expect((doc['endTime'] as Timestamp).toDate(), DateTime(2026, 10, 21, 5, 42, 30));
      expect(doc['durationSeconds'], 750);
      expect(doc['status'], 'completed');
    });

    test('geçmiş en yeni oturum üstte olacak şekilde okunur (uygulama yeniden açıldığında da)', () async {
      final d1 = DateTime(2026, 10, 20, 6, 0);
      final d2 = DateTime(2026, 10, 21, 6, 0);
      final id1 = await history.addSession(IrrigationSession(d1, landName: 'Sera', endTime: d1.add(const Duration(minutes: 5))));
      final id2 = await history.addSession(IrrigationSession(d2, landName: 'Zeytinlik'));

      // Yeni bir servis örneği (= uygulamanın yeniden açılması) aynı veriyi görür
      final sessions = await HistoryService(firestore: firestore, authService: backend.authService).getHistory().first;
      expect(sessions.map((s) => s.id), [id2, id1]);
      expect(sessions[0].landName, 'Zeytinlik');
      expect(sessions[0].duration, isNull); // devam ediyor
      expect(sessions[1].duration, const Duration(minutes: 5));
    });

    test('oturum açık değilse kayıt yapılmaz', () async {
      await backend.authService.logout();
      await expectLater(
        history.addSession(IrrigationSession(DateTime.now(), landName: 'X')),
        throwsA(predicate((e) => e.toString().contains('oturumu açık değil'))),
      );
    });

    test('her kullanıcının geçmişi ayrı tutulur', () async {
      await history.addSession(IrrigationSession(DateTime.now(), landName: 'Zeytinlik'));
      await backend.authService.logout();
      await backend.authService.login('admin@sirket.com', 'sifre123');
      expect(await history.getHistory().first, isEmpty);
    });
  });

  group('Arazi Firestore kaydı', () {
    test('arazi eklenir, listelenir, güncellenir ve silinir', () async {
      final id = await lands.addLand(Land(id: '', name: 'Bağ', phoneNumber: '+905557778899', latitude: 38.5, longitude: 27.5));
      expect((await firestore.collection(landsPath).doc(id).get())['name'], 'Bağ');

      var list = await lands.getLands().first;
      expect(list.single.id, id);
      expect(list.single.phoneNumber, '+905557778899');

      await lands.updateLand(Land(id: id, name: 'Büyük Bağ', phoneNumber: '+905557778899', latitude: 38.5, longitude: 27.5));
      list = await lands.getLands().first;
      expect(list.single.name, 'Büyük Bağ');

      await lands.deleteLand(id);
      expect(await lands.getLands().first, isEmpty);
    });

    test('araziler ve geçmiş aynı kullanıcı kökü altında tutulur', () {
      expect(landsPath.replaceAll('/lands', ''), historyPath.replaceAll('/history', ''));
    });
  });
}
