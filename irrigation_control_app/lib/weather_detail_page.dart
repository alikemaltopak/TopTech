import 'package:flutter/material.dart';
import 'package:irrigation_control_app/my_lands_page.dart'; // Import Land class
import 'package:irrigation_control_app/land_service.dart'; // KRİTİK IMPORT EKLENDİ
class WeatherDetailPage extends StatelessWidget {
  final Map<String, dynamic>? weatherData;
  final Land? selectedLand; // New parameter

  const WeatherDetailPage({Key? key, this.weatherData, this.selectedLand}) : super(key: key);

  Widget _buildWeatherCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color.withOpacity(0.3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (weatherData == null) {
      // Sadece içerik döndürüyoruz, Scaffold değil
      return const Center(
        child: Text(
          'Hava durumu bilgisi mevcut değil.',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    final current = weatherData!['current'];
    final location = weatherData!['location'];

    // DÜZELTME: En dıştaki GEREKSİZ Scaffold kaldırıldı.
    // Ana ekranda (main.dart) zaten Scaffold sarmalaması var.
    return Container(
        // Arka plan rengi/gradiyanı, Ana Ekranın arka planını kapatmak için zorunlu.
        // Opak bir arka plan sağlamak için rengi/gradiyanı buraya ekliyoruz.
        decoration: BoxDecoration(
          color: Colors.white, // Varsayılan arka planı beyaza çekiyoruz
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade800,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Yenileme ikonu ve başlık kaldırıldı, MainScreen'deki AppBar kullanılıyor.

                  // Konum ve Tarih
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedLand?.name ?? 'Turgutlu, İğdecik Köyü',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Son Güncelleme: ${DateTime.now().hour}:${DateTime.now().minute}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      // Yenileme butonu kaldırıldı.
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Ana Sıcaklık ve Durum
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '${current['temp_c'].toStringAsFixed(1)}°C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          current['condition']['text'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Detaylı Bilgiler
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 2.3, // 2.5'ten 2.3'e düşürüldü (Yüksekliği biraz artırdı)
                    children: [
                      _buildWeatherCard(
                        'Nem',
                        '${current['humidity']}%',
                        Icons.water_drop,
                        Colors.blue,
                      ),
                      _buildWeatherCard(
                        'Rüzgar',
                        '${current['wind_kph']} km/s',
                        Icons.air,
                        Colors.cyan,
                      ),
                      _buildWeatherCard(
                        'Basınç',
                        '${current['pressure_mb']} mb',
                        Icons.speed,
                        Colors.purple,
                      ),
                      _buildWeatherCard(
                        'Hissedilen',
                        '${current['feelslike_c'].toStringAsFixed(1)}°C',
                        Icons.thermostat,
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Ek Bilgiler
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ek Bilgiler',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow('Görüş Mesafesi', '${current['vis_km']} km'),
                          _buildInfoRow('UV İndeksi', current['uv'].toString()),
                          _buildInfoRow('Bulut Oranı', '${current['cloud']}%'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}