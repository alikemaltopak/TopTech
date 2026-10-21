import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:google_maps_url_extractor/google_maps_url_extractor.dart'; // Artık koordinatları tek string'den alıyoruz, bu paketi kaldırdık.
import 'package:irrigation_control_app/land_service.dart'; // Land modelini ve servisi buradan alıyoruz.
import 'package:irrigation_control_app/irrigation_logic.dart';

// NOT: Land sınıfı artık land_service.dart dosyasından gelmektedir ve bu dosyadan kaldırılmıştır.

class MyLandsPage extends StatefulWidget {
  final List<Land> lands;
  // Fonksiyon imzaları LandService'e göre güncellendi. Artık onAddLand kullanılmıyor.
  // onAddLand yerine _showAddLandDialog metodu main.dart'a taşındı ve direkt LandService kullanacak.
  final Function(Land) onAddLand; // Bu satırı koruyoruz, ancak MainScreen'de boş bir fonksiyon atanacak.
  final Function(Land) onLandSelected;
  // Land objesi artık Firestore'dan gelen id içerdiği için update'e id'li Land gönderilir.
  final Function(Land) onUpdateLand; // updateLand metodu artık sadece tek Land objesi alacak
  final Function(Land) onDeleteLand;
  final Land? selectedLand;

  const MyLandsPage({
    Key? key,
    required this.lands,
    required this.onAddLand,
    required this.onLandSelected,
    required this.onUpdateLand,
    required this.onDeleteLand,
    this.selectedLand,
  }) : super(key: key);

  @override
  State<MyLandsPage> createState() => _MyLandsPageState();
}

class _MyLandsPageState extends State<MyLandsPage> {
  // LandService örneği oluşturuldu
  final LandService _landService = LandService();

  // NOT: Arazi Ekleme Diyaloğu (AddLandDialog) MainScreen'e taşındığı için bu metot artık kullanılmaz.
  // Ancak düzenleme mantığını burada tutuyoruz.

  // Yeni eklenen yardımcı fonksiyon: Herhangi bir değeri double'a güvenli bir şekilde dönüştürme (main.dart'tan kopyalandı)
  double? _convertToDouble(dynamic value) => convertToDouble(value);

  void _showEditLandDialog(Land land) {
    // Controller'lar dialog içinde yeniden tanımlanacak
    final _nameController = TextEditingController(text: land.name);
    final _phoneController = TextEditingController(text: land.phoneNumber);
    // Koordinatlar: Enlem, Boylam formatında string olarak gösterilir.
    final _coordinateController = TextEditingController(
        text: land.latitude != null && land.longitude != null
            ? '${land.latitude}, ${land.longitude}'
            : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arazi Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Arazi Adı'),
              ),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Telefon Numarası'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              const Text(
                'Konum Koordinatları:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Enlem ve Boylam koordinatlarını aralarına virgül koyarak yapıştırın (örn: 39.408435, 32.912238).',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _coordinateController,
                      decoration: const InputDecoration(labelText: 'Enlem, Boylam'),
                      keyboardType: TextInputType.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty && _phoneController.text.isNotEmpty) {

                List<String> parts = _coordinateController.text.trim().split(',');
                double? lat;
                double? lon;

                if (parts.length == 2) {
                  lat = _convertToDouble(parts[0]);
                  lon = _convertToDouble(parts[1]);
                } else {
                   // Eğer koordinat alanı boş bırakılırsa eski koordinatlar korunur.
                   lat = land.latitude;
                   lon = land.longitude;
                }

                if (lat == null || lon == null) {
                   ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Hata: Geçerli Enlem, Boylam formatı girilmedi veya boş bırakıldı.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                }

                // GÜNCELLEME: LandService'i kullanarak Firestore'a yaz
                final updatedLand = Land(
                  id: land.id, // ID'yi koru
                  name: _nameController.text,
                  phoneNumber: _phoneController.text,
                  latitude: lat,
                  longitude: lon,
                );

                await _landService.updateLand(updatedLand);

                Navigator.pop(context);
              }
            },
            child: const Text('Güncelle'),
          ),
          TextButton(
            onPressed: () async {
              // SİLME: LandService'i kullanarak Firestore'dan sil
              await _landService.deleteLand(land.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // --- BUILD METODU ---

  @override
  Widget build(BuildContext context) {
    // FloatingActionButton artık MainScreen'de olduğu için buradaki padding kaldırıldı.
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade300,
            Colors.blue.shade700,
          ],
        ),
      ),
      child: Column(
        children: [
          // Navigasyon çubuğu boşluğu, MainScreen'de AppBar olduğu için bu boşluk uygun.
          SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight - 50),

          // Arazi Ekle butonu MainScreen'in FloatingActionButton'una taşındığı için kaldırıldı.
          // Padding(
          //   padding: const EdgeInsets.all(16.0),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //     children: [],
          //   ),
          // ),

          Expanded(
            child: widget.lands.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.landscape,
                          size: 64,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz kayıtlı arazi yok.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Arazi ekleme talimatı
                        Text(
                          'Yeni arazi eklemek için sağ alttaki artı (+) butonunu kullanın.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: widget.lands.length,
                    itemBuilder: (context, index) {
                      final land = widget.lands[index];
                      final isSelected = widget.selectedLand?.id == land.id; // Seçimi ID'ye göre kontrol et
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        color: isSelected ? Colors.green.shade100 : Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: InkWell(
                          onTap: () => widget.onLandSelected(land),
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.green.shade600 : Colors.white,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        land.name,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.black,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected)
                                          const Icon(Icons.check_circle, color: Colors.white, size: 24),
                                        if (isSelected) const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(Icons.edit, color: isSelected ? Colors.white : Colors.black),
                                          onPressed: () => _showEditLandDialog(land),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  land.phoneNumber,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white70 : Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                                if (land.latitude != null && land.longitude != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Konum: ${land.latitude!.toStringAsFixed(6)}, ${land.longitude!.toStringAsFixed(6)}',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white70 : Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}