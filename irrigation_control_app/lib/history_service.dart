import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:irrigation_control_app/auth_service.dart';
import 'package:irrigation_control_app/irrigation_logic.dart';
import 'package:irrigation_control_app/main.dart'; // IrrigationSession modelini buradan alıyoruz

class HistoryService {
  final FirebaseFirestore _firestore;
  final AuthService _authService;

  // Testlerde sahte Firestore verilebilmesi için bağımlılıklar dışarıdan alınabilir.
  HistoryService({FirebaseFirestore? firestore, AuthService? authService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _authService = authService ?? AuthService();

  // Koleksiyon yolunu getir (araziler ile aynı kök: artifacts/{appId}/users/{userId})
  Future<String> _getCollectionPath() async {
    final userEmail = await _authService.getEmail();

    if (userEmail == null) {
      throw Exception('Kullanıcı oturumu açık değil.');
    }

    return historyCollectionPath(userIdFromEmail(userEmail));
  }

  // Yeni oturum ekle
  Future<String> addSession(IrrigationSession session) async {
    final path = await _getCollectionPath();

    final data = {
      'landId': session.landId,
      'landName': session.landName,
      'startTime': Timestamp.fromDate(session.startTime),
      'endTime': session.endTime != null ? Timestamp.fromDate(session.endTime!) : null,
      'durationSeconds': session.duration?.inSeconds,
      'status': session.endTime == null ? 'active' : 'completed',
    };

    final docRef = await _firestore.collection(path).add(data);
    session.id = docRef.id;
    return docRef.id;
  }

  // Oturumu güncelle (Bitiş zamanı ekle)
  Future<void> updateSession(String sessionId, DateTime endTime) async {
    final path = await _getCollectionPath();
    final docRef = _firestore.collection(path).doc(sessionId);
    final snapshot = await docRef.get();
    final startTime = (snapshot.data()?['startTime'] as Timestamp?)?.toDate();
    await docRef.update({
      'endTime': Timestamp.fromDate(endTime),
      'durationSeconds': startTime != null ? endTime.difference(startTime).inSeconds : null,
      'status': 'completed',
    });
  }

  // Geçmişi getir (Stream) — en yeni oturum en üstte
  Stream<List<IrrigationSession>> getHistory() async* {
    final path = await _getCollectionPath();

    yield* _firestore.collection(path)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final startTime = (data['startTime'] as Timestamp).toDate();
            final endTime = data['endTime'] != null ? (data['endTime'] as Timestamp).toDate() : null;

            return IrrigationSession(
              startTime,
              endTime: endTime,
              landName: data['landName'] as String? ?? 'Bilinmeyen Arazi',
              landId: data['landId'] as String?,
            )..id = doc.id;
          }).toList();
        });
  }
}
