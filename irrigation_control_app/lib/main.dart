import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_cupertino_datetime_picker/flutter_cupertino_datetime_picker.dart';

// Firestore için gerekli importlar
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

// Projenin diğer dosyaları
import 'package:irrigation_control_app/weather_detail_page.dart';
import 'package:irrigation_control_app/history_page.dart';
import 'package:irrigation_control_app/my_lands_page.dart';
import 'package:irrigation_control_app/notification_service.dart';
import 'package:irrigation_control_app/auth_service.dart';
import 'package:irrigation_control_app/login_page.dart';
import 'package:irrigation_control_app/admin_page.dart';
import 'package:irrigation_control_app/land_service.dart'; // Land modelini buradan alıyoruz

// Firestore kurulumu için sabit ID
const String APP_ID = 'remote-irrigation-app';

// HATA ÇÖZÜMÜ: Firebase'i gerçekten başlatan fonksiyon.
Future<void> _initializeFirebase() async {
  await Firebase.initializeApp();
}

// Model Sınıfları
class SuggestionResult {
  final Duration recommendedDuration;
  final String rationale;

  SuggestionResult({required this.recommendedDuration, required this.rationale});
}

class IrrigationSession {
  DateTime startTime;
  DateTime? endTime;
  String landName;

  IrrigationSession(this.startTime, {this.endTime, required this.landName});

  Duration? get duration => endTime?.difference(startTime);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  await NotificationService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _loading = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final logged = await AuthService().isLoggedIn();
    setState(() {
      _loggedIn = logged;
      _loading = false;
    });
  }

  void _onLoggedIn() {
    setState(() {
      _loggedIn = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sulama Kontrol Uygulaması',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
        useMaterial3: true,
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (_loggedIn
          ? const MainScreen()
          : LoginPage(onLoggedIn: _onLoggedIn)),
    );
  }
}

// ====================================================================================
// BAŞLANGIÇ: Ana Ekran ve Navigasyon Hatalarının Çözüldüğü Sınıf
// ====================================================================================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final LandService _landService = LandService();

  int _selectedIndex = 0;
  // PageController kaldırıldı, artık index ile sayfa yönetimi yapılacak

  bool _isIrrigationOn = false;
  Map<String, dynamic>? _weatherData;
  bool _isLoading = true;
  String _errorMessage = '';
  List<IrrigationSession> _commandHistory = [];
  IrrigationSession? _currentSession;
  Duration? _selectedDuration;
  Timer? _timer;
  Duration _remainingTime = Duration.zero;

  List<Land> _lands = [];
  Land? _selectedLand;
  int? _scheduledNotificationId;

  bool _isAdmin = false;

  final double _turgutluLatitude = 38.493017;
  final double _turgutluLongitude = 27.529632;

  // YENİ: Tüm sayfaları tutan liste
  List<Widget> _widgetOptions(List<Land> lands) {
    return <Widget>[
      // Index 0: Ana Sayfa (Background'ı kendi içinde tutacak)
      HomePageContent(
        isIrrigationOn: _isIrrigationOn,
        toggleIrrigation: _toggleIrrigation,
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        weatherData: _weatherData,
        selectedDuration: _selectedDuration,
        remainingTime: _remainingTime,
        showDurationPicker: _showDurationPicker,
        resetTimer: _resetTimer,
        selectedLand: _selectedLand,
        onSuggest: () {
          final result = SuggestionResult(
            recommendedDuration: const Duration(minutes: 30),
            rationale: "Öneri servisi geçici olarak devredışı.",
          );
          setState(() {
            _selectedDuration = result.recommendedDuration;
            _remainingTime = result.recommendedDuration;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Önerilen süre: ${result.recommendedDuration.inMinutes} dk. ${result.rationale}')),
          );
        },
        getBackgroundImage: _getBackgroundImage, // Arka plan fonksiyonu iletildi
      ),

      // Index 1: Hava Durumu Detayları (Opak Scaffold içinde)
      Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: const Text('Hava Durumu Detayları', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: WeatherDetailPage(weatherData: _weatherData, selectedLand: _selectedLand),
      ),

      // Index 2: Geçmiş (Opak Scaffold içinde)
      Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: const Text('Komut Geçmişi', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: HistoryPage(commandHistory: _commandHistory, selectedLand: _selectedLand),
      ),

      // Index 3: Arazilerim (Opak Scaffold içinde)
      Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: const Text('Arazilerim', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: MyLandsPage(
          lands: lands,
          onAddLand: (land) {},
          onLandSelected: _selectLand,
          selectedLand: _selectedLand,
          onUpdateLand: (land) {},
          onDeleteLand: _deleteLand,
        ),
      ),

      // Index 4: Yönetim (Opak Scaffold içinde)
      Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: const Text('Yönetim', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isAdmin ? const AdminPage() : const Center(child: Text("Bu sayfaya erişim yetkiniz yoktur.", style: TextStyle(color: Colors.black, fontSize: 18))),
      ),
    ];
  }


  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _getWeatherData();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await AuthService().isAdmin();
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double? _convertToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      String cleaned = value.trim().replaceAll(',', '.');
      return double.tryParse(cleaned);
    }
    return null;
  }

  Future<void> _getWeatherData({double? latitude, double? longitude}) async {
    final double lat = latitude ?? _turgutluLatitude;
    final double lon = longitude ?? _turgutluLongitude;

    try {
      final response = await http.get(Uri.parse(
          'https://api.weatherapi.com/v1/current.json?key=62a6672b147c4304bf4115523251006&q=$lat,$lon&lang=tr'));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _weatherData = json.decode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Hava durumu bilgisi alınamadı: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Bir hata oluştu: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendSmsCommand(String command) async {
    if (_selectedLand == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce sulamak istediğiniz araziyi seçin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final Uri smsLaunchUri = Uri.parse('smsto:${_selectedLand!.phoneNumber}?body=${Uri.encodeComponent(command)}');

    if (await canLaunchUrl(smsLaunchUri)) {
      await launchUrl(smsLaunchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS gönderilemedi. Telefonunuzda bir SMS uygulaması bulunamadı.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startTimer() async {
    if (_selectedDuration == null) return;

    _remainingTime = _selectedDuration!;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime.inSeconds > 0) {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        } else {
          _timer?.cancel();
          if (_isIrrigationOn) {
            _toggleIrrigation();
          }
        }
      });
    });
  }

  void _showDurationPicker() async {
    int selectedHour = _selectedDuration?.inHours ?? 0;
    int selectedMinute = _selectedDuration != null ? _selectedDuration!.inMinutes % 60 : 30;
    Duration? picked;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text('Süre Seç', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(initialItem: selectedHour),
                        itemExtent: 40,
                        onSelectedItemChanged: (val) {
                          selectedHour = val;
                        },
                        children: List.generate(24, (i) => Center(child: Text('$i saat'))),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(initialItem: selectedMinute),
                        itemExtent: 40,
                        onSelectedItemChanged: (val) {
                          selectedMinute = val;
                        },
                        children: List.generate(60, (i) => Center(child: Text('$i dakika'))),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  picked = Duration(hours: selectedHour, minutes: selectedMinute);
                  Navigator.of(context).pop();
                },
                child: const Text('Onayla'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
    if (picked != null && picked!.inMinutes > 0) {
      setState(() {
        _selectedDuration = picked;
        _remainingTime = picked!;
      });
    }
  }

  Future<void> _toggleIrrigation() async {
    setState(() {
      _isIrrigationOn = !_isIrrigationOn;
      if (_isIrrigationOn) {
        _currentSession = IrrigationSession(DateTime.now(), landName: _selectedLand!.name);
        _commandHistory.add(_currentSession!);
      } else {
        if (_currentSession != null && _currentSession!.endTime == null) {
          _currentSession!.endTime = DateTime.now();
        }
        _timer?.cancel();
        _remainingTime = Duration.zero;
        if (_scheduledNotificationId != null) {
          NotificationService().cancel(_scheduledNotificationId!);
          _scheduledNotificationId = null;
        }
      }
    });

    if (_isIrrigationOn) {
      try {
        if (_selectedDuration != null) {
          await _startTimer();
          int minutes = _selectedDuration!.inMinutes;
          final smsCommand = "ON$minutes";

          await Future.delayed(const Duration(seconds: 1));

          await _sendSmsCommand(smsCommand);
        } else {
          final smsCommand = "ON";

          await Future.delayed(const Duration(seconds: 1));

          await _sendSmsCommand(smsCommand);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('HATA: Sulama açma sırasında beklenmedik bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      await _sendSmsCommand("OFF");
    }
  }

  // YENİ: onItemTapped artık sadece index'i değiştiriyor ve _widgetOptions'tan sayfayı yüklüyor.
  void _onItemTapped(int index) {
    if (index == 4 && !_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu bölüme erişim yetkiniz yok.')),
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  String _getBackgroundImage(String conditionText, int isDay) {
    conditionText = conditionText.toLowerCase();
    if (isDay == 1) {
      if (conditionText.contains('açık') || conditionText.contains('güneşli')) return 'assets/images/clear_day.png';
      if (conditionText.contains('parçalı bulutlu') || conditionText.contains('bulutlu')) return 'assets/images/cloudy_overcast_day.jpg';
      if (conditionText.contains('kapalı')) return 'assets/images/cloudy_overcast_day.jpg';
    } else {
      if (conditionText.contains('açık') || conditionText.contains('güneşli')) return 'assets/images/clear_night.jpeg';
      if (conditionText.contains('parçalı bulutlu') || conditionText.contains('bulutlu')) return 'assets/images/cloudy_overcast_night.jpeg';
      if (conditionText.contains('kapalı')) return 'assets/images/cloudy_overcast_night.jpeg';
    }
    return 'assets/images/cloudy_overcast_day.jpg';
  }

  void _resetTimer() {
    setState(() {
      _selectedDuration = null;
      _remainingTime = Duration.zero;
      _timer?.cancel();
      if (_scheduledNotificationId != null) {
        NotificationService().cancel(_scheduledNotificationId!);
        _scheduledNotificationId = null;
      }
    });
  }

  void _updateLandsFromStream(List<Land> newLands) {
    _lands = newLands;

    if (_selectedLand != null) {
      final currentId = _selectedLand!.id;
      final matchingLand = _lands.where((l) => l.id == currentId).firstOrNull;
      _selectedLand = matchingLand;
    }

    if (_selectedLand == null && _lands.isNotEmpty) {
      _selectedLand = _lands.first;
    }

    if (_isLoading && _selectedLand != null && _selectedLand!.latitude != null) {
      _getWeatherData(
        latitude: _selectedLand!.latitude,
        longitude: _selectedLand!.longitude,
      );
    }
  }

  Future<void> _addLand(Land tempLand, {required double? latitude, required double? longitude}) async {
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hata: Koordinatlar eksik. Lütfen Enlem ve Boylam alanlarını doldurun.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newLand = Land(
      id: '',
      name: tempLand.name,
      phoneNumber: tempLand.phoneNumber,
      latitude: latitude,
      longitude: longitude,
    );

    await _landService.addLand(newLand);
  }

  void _updateLand(Land land) {
    // LandService'i direkt çağırdığı için boş kalabilir.
  }

  void _deleteLand(Land land) async {
    await _landService.deleteLand(land.id);
  }

  void _selectLand(Land land) {
    setState(() {
      _selectedLand = land;
      if (land.latitude != null && land.longitude != null) {
        _getWeatherData(latitude: land.latitude, longitude: land.longitude);
      } else {
        _getWeatherData();
      }
    });
    _onItemTapped(0); // Arazi seçilince ana sayfaya dön
  }

  void _showAddLandDialog() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController nameController = TextEditingController();
        TextEditingController phoneController = TextEditingController();
        TextEditingController coordinateController = TextEditingController();

        return AlertDialog(
          title: const Text('Arazi Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Adı'),
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Telefon Numarası'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Konum Koordinatları:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Google Haritalar\'dan Enlem ve Boylam koordinatlarını aralarına virgül koyarak yapıştırın (örn: 39.408435, 32.912238).',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: coordinateController,
                        decoration: const InputDecoration(labelText: 'Enlem, Boylam'),
                        keyboardType: TextInputType.text,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.map),
                  onPressed: () async {
                    final Uri googleMapsUri = Uri.parse('https://www.google.com/maps/@0,0,10z');
                    if (await canLaunchUrl(googleMapsUri)) {
                      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Harita açılamadı. Tarayıcınızda https://www.google.com/maps adresini açmayı deneyin.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {

                  List<String> parts = coordinateController.text.trim().split(',');
                  double? lat;
                  double? lon;

                  if (parts.length == 2) {
                    lat = _convertToDouble(parts[0]);
                    lon = _convertToDouble(parts[1]);
                  }

                  if (lat == null || lon == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Hata: Geçerli Enlem, Boylam formatı girilmedi (Örn: 39.408435, 32.912238).'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  _addLand(
                    Land(
                      id: '',
                      name: nameController.text,
                      phoneNumber: phoneController.text,
                      latitude: null,
                      longitude: null,
                    ),
                    latitude: lat,
                    longitude: lon,
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Land>>(
      stream: _landService.getLands(),
      builder: (context, snapshot) {
        final lands = snapshot.data ?? [];
        _updateLandsFromStream(lands);

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Veri yüklenirken hata oluştu: ${snapshot.error}')));
        }

        // Body, seçilen indekse göre doğru widget'ı yüklüyor.
        return Scaffold(
          appBar: null,
          body: _widgetOptions(lands).elementAt(_selectedIndex), // <-- Düzeltilen kısım

          bottomNavigationBar: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ana Sayfa'),
              const BottomNavigationBarItem(icon: Icon(Icons.cloud), label: 'Hava Durumu'),
              const BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Geçmiş'),
              const BottomNavigationBarItem(icon: Icon(Icons.landscape), label: 'Arazilerim'),
              if (_isAdmin)
                const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Yönetim'),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.lightGreen[800],
            unselectedItemColor: Colors.grey,
            onTap: (index) {
              if (index == 4 && !_isAdmin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bu bölüme erişim yetkiniz yok.')),
                );
                return;
              }
              _onItemTapped(index);
            },
          ),

          // FloatingActionButton sadece Arazilerim sekmesinde görünüyor.
          floatingActionButton: _selectedIndex == 3
              ? FloatingActionButton.extended(
            onPressed: () {
              _showAddLandDialog();
            },
            label: const Text('Arazi Ekle', style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.add, color: Colors.white),
            backgroundColor: Colors.green.shade600,
          )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }
}
// ====================================================================================
// SON: Ana Ekran ve Navigasyon Hatalarının Çözüldüğü Sınıf
// ====================================================================================


// ====================================================================================
// BAŞLANGIÇ: Ana Sayfa İçeriği (Background Yönetimi Düzeltildi)
// ====================================================================================
class HomePageContent extends StatelessWidget {
  final bool isIrrigationOn;
  final VoidCallback toggleIrrigation;
  final bool isLoading;
  final String errorMessage;
  final Map<String, dynamic>? weatherData;
  final Duration? selectedDuration;
  final Duration remainingTime;
  final VoidCallback showDurationPicker;
  final VoidCallback resetTimer;
  final Land? selectedLand;
  final VoidCallback onSuggest;
  final String Function(String conditionText, int isDay) getBackgroundImage; // Arka plan fonksiyonu MainScreen'den alınıyor.

  const HomePageContent({
    Key? key,
    required this.isIrrigationOn,
    required this.toggleIrrigation,
    required this.isLoading,
    required this.errorMessage,
    required this.selectedDuration,
    required this.remainingTime,
    required this.showDurationPicker,
    required this.resetTimer,
    this.weatherData,
    this.selectedLand,
    required this.onSuggest,
    required this.getBackgroundImage,
  }) : super(key: key);

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    // Arka Plan (Background) artık sadece bu widget'ı sarıyor.
    return Container(
      decoration: weatherData != null
          ? BoxDecoration(
        image: DecorationImage(
          image: AssetImage(getBackgroundImage(
            weatherData!['current']['condition']['text'],
            weatherData!['current']['is_day'],
          )),
          fit: BoxFit.cover,
        ),
      )
          : BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade300,
            Colors.blue.shade700,
          ],
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            expandedHeight: 0,
            pinned: false,
            floating: true,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sulama Kontrol', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(Icons.logout, color: Colors.white),
                  onPressed: () async {
                    await AuthService().logout();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => LoginPage(onLoggedIn: () {
                        final myAppState = context.findAncestorStateOfType<_MyAppState>();
                        myAppState?._onLoggedIn();
                      })),
                          (Route<dynamic> route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (isLoading)
                        const CircularProgressIndicator(color: Colors.white)
                      else if (errorMessage.isNotEmpty)
                        Text(
                          errorMessage,
                          style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                        )
                      else if (weatherData != null)
                          Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            color: Colors.white.withOpacity(0.8),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Hava Durumu',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    selectedLand?.name ?? 'Turgutlu, İğdecik Köyü',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade700),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${weatherData!['current']['temp_c'].toStringAsFixed(1)}°C',
                                    style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    weatherData!['current']['condition']['text'],
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      const SizedBox(height: 40),
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        color: Colors.white.withOpacity(0.8),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Zamanlayıcı',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              const SizedBox(height: 16),
                              if (selectedDuration != null && isIrrigationOn)
                                SizedBox(
                                  width: 150,
                                  height: 150,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 150,
                                        height: 150,
                                        child: CircularProgressIndicator(
                                          value: selectedDuration!.inSeconds > 0 ? remainingTime.inSeconds / selectedDuration!.inSeconds : 0.0,
                                          strokeWidth: 10,
                                          backgroundColor: Colors.grey.shade300,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(remainingTime),
                                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                      ),
                                    ],
                                  ),
                                )
                              else if (selectedDuration != null)
                                Text(
                                  _formatDuration(selectedDuration!),
                                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                )
                              else
                                Text(
                                  '00:00:00',
                                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
                                ),
                              const SizedBox(height: 16),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: showDurationPicker,
                                    icon: const Icon(Icons.timer, size: 18),
                                    label: const Text('KUR', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: onSuggest,
                                    icon: const Icon(Icons.lightbulb, size: 18),
                                    label: const Text('ÖNERİ', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: resetTimer,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('SIFIRLA', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        isIrrigationOn ? 'Sulama Sistemi: AÇIK' : 'Sulama Sistemi: KAPALI',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.black.withOpacity(0.5),
                              offset: Offset(2.0, 2.0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isIrrigationOn ? null : toggleIrrigation,
                              icon: const Icon(Icons.play_arrow, size: 28),
                              label: const Text('AÇ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isIrrigationOn ? toggleIrrigation : null,
                              icon: const Icon(Icons.stop, size: 28),
                              label: const Text('KAPAT', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
// ====================================================================================
// SON: Ana Sayfa İçeriği (Background Yönetimi Düzeltildi)
// ====================================================================================