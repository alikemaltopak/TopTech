import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:irrigation_control_app/auth_service.dart';
import 'package:irrigation_control_app/irrigation_logic.dart';
import 'package:irrigation_control_app/main.dart'; // IrrigationSession modelini buradan alıyoruz

class HistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Koleksiyon yolunu getir
  Future<String> _getCollectionPath() async {
    const appId = 'remote-irrigation-app';
    final userEmail = await _authService.getEmail();

    if (userEmail == null) {
      throw Exception('Kullanıcı oturumu açık değil.');
    }

    // E-postayı güvenli hale getir (dosya yolu için)
    final userId = userIdFromEmail(userEmail);

    // Veri yolu: users/$userId/history
    return 'users/$userId/history';
  }

  // Yeni oturum ekle
  Future<String> addSession(IrrigationSession session) async {
    final path = await _getCollectionPath();
    
    final data = {
      'landName': session.landName,
      'startTime': Timestamp.fromDate(session.startTime),
      'endTime': session.endTime != null ? Timestamp.fromDate(session.endTime!) : null,
      'status': session.endTime == null ? 'active' : 'completed',
    };

    final docRef = await _firestore.collection(path).add(data);
    return docRef.id;
  }

  // Oturumu güncelle (Bitiş zamanı ekle)
  Future<void> updateSession(String sessionId, DateTime endTime) async {
    final path = await _getCollectionPath();
    final data = {
      'endTime': Timestamp.fromDate(endTime),
      'status': 'completed',
    };
    await _firestore.collection(path).doc(sessionId).update(data);
  }

  // Geçmişi getir (Stream)
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
            final landName = data['landName'] as String;

            return IrrigationSession(startTime, endTime: endTime, landName: landName)
              ..id = doc.id; 
          }).toList();
        });
  }
}
