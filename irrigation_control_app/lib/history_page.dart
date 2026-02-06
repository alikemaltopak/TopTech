import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:irrigation_control_app/main.dart'; // IrrigationSession için import
import 'package:irrigation_control_app/land_service.dart'; // Land sınıfı için import
import 'package:irrigation_control_app/history_service.dart'; // HistoryService eklendi

class HistoryPage extends StatefulWidget {
  // commandHistory artık zorunlu değil çünkü servisten çekilecek, 
  // ancak geriye dönük uyumluluk veya geçiş için opsiyonel bırakabiliriz.
  // Ama temiz olması için kaldırıyoruz, MainScreen'den buraya artık parametre geçmeye gerek yok (selectedLand hariç).
  final Land? selectedLand; // Seçili arsa bilgisi

  const HistoryPage({Key? key, this.selectedLand}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime _selectedDate = DateTime.now();
  final HistoryService _historyService = HistoryService(); // Servis örneği

  // Filtreleme artık Stream içindeki dataya yapılacak
  List<IrrigationSession> _filterHistory(List<IrrigationSession> allSessions) {
    return allSessions.where((session) {
      // Önce seçili arsaya göre filtrele
      if (widget.selectedLand != null && session.landName != widget.selectedLand!.name) {
        return false;
      }
      // Sonra tarihe göre filtrele
      final DateTime sessionDate = session.startTime;
      return sessionDate.year == _selectedDate.year &&
             sessionDate.month == _selectedDate.month &&
             sessionDate.day == _selectedDate.day;
    }).toList();
  }

  // Süreyi formatlayan yardımcı fonksiyon
  String _formatDuration(Duration? duration) {
    if (duration == null) {
      return 'Devam Ediyor';
    }
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String twoDigitHours = twoDigits(duration.inHours);

    String formattedDuration = '';
    if (duration.inHours > 0) {
      formattedDuration += "${twoDigitHours}sa ";
    }
    if (duration.inMinutes > 0) {
      formattedDuration += "${twoDigitMinutes}dk ";
    }
    if (duration.inSeconds > 0 || (duration.inHours == 0 && duration.inMinutes == 0)) {
      formattedDuration += "${twoDigitSeconds}sn";
    }

    return formattedDuration.trim();
  }

  @override
  Widget build(BuildContext context) {
    final Color greenColor = const Color(0xFF70DE56);
    final Color redColor = const Color(0xFFFF5252);
    final Color lightBlueColor = const Color(0xFF7EF1FF);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Komut Geçmişi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
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
        // StreamBuilder ile verileri dinliyoruz
        child: StreamBuilder<List<IrrigationSession>>(
          stream: _historyService.getHistory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
            }

            final allHistory = snapshot.data ?? [];
            final filteredHistory = _filterHistory(allHistory);

            return SafeArea(
              child: Column(
                children: [
                  // Başlık ve İstatistikler
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Seçili Arazi: ${widget.selectedLand?.name ?? 'Tümü'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${filteredHistory.length} Oturum',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Yatay Tarih Seçici
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 365,
                      reverse: true,
                      itemBuilder: (context, index) {
                        DateTime date = DateTime.now().subtract(Duration(days: index));
                        bool isSelected = date.day == _selectedDate.day &&
                            date.month == _selectedDate.month &&
                            date.year == _selectedDate.year;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = date;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('dd').format(date),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM').format(date),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Geçmiş Listesi
                  Expanded(
                    child: filteredHistory.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Bu tarihte kayıt bulunamadı',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredHistory.length,
                            itemBuilder: (context, index) {
                              final session = filteredHistory[index];
                              final startSessionDate = DateFormat('dd/MM/yyyy').format(session.startTime);
                              final startSessionTime = DateFormat('HH:mm:ss').format(session.startTime);
                              final endSessionDate = session.endTime != null ? DateFormat('dd/MM/yyyy').format(session.endTime!) : '-';
                              final endSessionTime = session.endTime != null ? DateFormat('HH:mm:ss').format(session.endTime!) : '-';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: Stack(
                                      children: [
                                        Row(
                                          children: [
                                            // Yeşil Kısım (AÇILDI)
                                            Expanded(
                                              child: Container(
                                                height: 120,
                                                color: greenColor,
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 20.0, top: 16.0),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Text(
                                                            'AÇILDI',
                                                            style: TextStyle(
                                                              color: Colors.black,
                                                              fontSize: 20,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          // Arazi ismini göster
                                                          Text(
                                                            session.landName,
                                                            style: TextStyle(
                                                              color: Colors.black.withOpacity(0.6),
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 20.0, bottom: 16.0),
                                                      child: Text(
                                                        '$startSessionDate $startSessionTime',
                                                        style: const TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // Kırmızı Kısım (KAPANDI)
                                            Expanded(
                                              child: Container(
                                                height: 120,
                                                color: redColor,
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    const Padding(
                                                      padding: EdgeInsets.only(right: 20.0, top: 16.0),
                                                      child: Text(
                                                        'KAPANDI',
                                                        style: TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 20,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.only(right: 20.0, bottom: 16.0),
                                                      child: Text(
                                                        session.endTime != null ? '$endSessionDate $endSessionTime' : 'Devam Ediyor',
                                                        style: const TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Siyah Üçgen
                                        const Align(
                                          alignment: Alignment.topCenter,
                                          child: CustomPaint(
                                            painter: TrianglePainter(),
                                            size: Size(32, 20),
                                          ),
                                        ),
                                        // TOPLAM SÜRE Kutusu
                                        Align(
                                          alignment: Alignment.center,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: lightBlueColor,
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  'TOPLAM SÜRE',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _formatDuration(session.duration),
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
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
          },
        ),
      ),
    );
  }
}

// Siyah üçgeni çizmek için CustomPainter
class TrianglePainter extends CustomPainter {
  const TrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, 0); // Üst orta nokta
    path.lineTo(0, size.height); // Sol alt nokta
    path.lineTo(size.width, size.height); // Sağ alt nokta
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}