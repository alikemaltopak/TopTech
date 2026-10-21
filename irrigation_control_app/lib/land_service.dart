import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:irrigation_control_app/auth_service.dart';
import 'package:irrigation_control_app/irrigation_logic.dart';
import 'dart:async';

// Land Modeli, Firestore'a uygun yapıda tanımlandı.
class Land {
  final String id; // Firestore Doküman ID'si
  final String name;
  final String phoneNumber;
  final double? latitude;
  final double? longitude;

  Land({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.latitude,
    this.longitude,
  });

  // Firestore'dan okuma (fromMap)
  factory Land.fromMap(String id, Map<String, dynamic> map) {
    return Land(
      id: id,
      name: map['name'] ?? 'Bilinmeyen Arazi',
      phoneNumber: map['phoneNumber'] ?? '',
      // Double türü dönüşümlerini güvenli yap
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  // Firestore'a yazma (toMap)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': FieldValue.serverTimestamp(), // Oluşturma zamanını kaydet
    };
  }
}

class LandService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Firestore koleksiyon yolunu oluşturur
  Future<String> _getCollectionPath() async {
    const appId = 'remote-irrigation-app';
    final userEmail = await _authService.getEmail();

    if (userEmail == null) {
      throw Exception('Kullanıcı oturumu açık değil.');
    }

    // Kullanıcının E-posta adresini benzersiz UID olarak kullanıyoruz
    final userId = userIdFromEmail(userEmail);

    // Veri yolu: /artifacts/{appId}/users/{userId}/lands
    return 'artifacts/$appId/users/$userId/lands';
  }

  // YENİ METOT: Arazi ekleme
  Future<String> addLand(Land land) async {
    final path = await _getCollectionPath();
    final docRef = await _firestore.collection(path).add(land.toMap());
    return docRef.id;
  }

  // YENİ METOT: Arazi güncelleme
  Future<void> updateLand(Land land) async {
    final path = await _getCollectionPath();
    await _firestore.collection(path).doc(land.id).update(land.toMap());
  }

  // YENİ METOT: Arazi silme
  Future<void> deleteLand(String landId) async {
    final path = await _getCollectionPath();
    await _firestore.collection(path).doc(landId).delete();
  }

  // YENİ METOT: Arazi listesini gerçek zamanlı çekme
  Stream<List<Land>> getLands() async* {
    final path = await _getCollectionPath();

    // Firestore sorgusu: En yeni eklenen en üstte olacak şekilde sırala
    yield* _firestore.collection(path)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Land.fromMap(doc.id, doc.data())).toList();
    });
  }
}