// README ekran görüntülerini üretir (normal `flutter test` çalıştırmasına dahil değildir):
//   flutter test tool/screenshots_test.dart --update-goldens
// Çıktılar: docs/screenshots/*.png
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrigation_control_app/admin_page.dart';
import 'package:irrigation_control_app/history_page.dart';
import 'package:irrigation_control_app/irrigation_logic.dart';
import 'package:irrigation_control_app/land_service.dart';
import 'package:irrigation_control_app/login_page.dart';
import 'package:irrigation_control_app/main.dart';
import 'package:irrigation_control_app/weather_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Flutter SDK içindeki gerçek Roboto ve Material ikon fontlarını yükle (testte varsayılan font kutucuktur).
Future<void> _loadFonts() async {
  final cache = File(Platform.resolvedExecutable).parent.parent.parent.parent; // bin/cache
  final fonts = Directory('${cache.path}/artifacts/material_fonts');
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('${fonts.path}/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

final _land = Land(id: 'l1', name: 'Zeytinlik', phoneNumber: '+905551112233', latitude: 38.49, longitude: 27.52);

final _weather = <String, dynamic>{
  'location': {'name': 'Turgutlu', 'region': 'Manisa', 'country': 'Turkey', 'localtime': '2026-10-21 10:00'},
  'current': {
    'temp_c': 24.6, 'feelslike_c': 25.1, 'humidity': 48, 'wind_kph': 11.2, 'wind_dir': 'NW',
    'pressure_mb': 1014.0, 'uv': 5.0, 'is_day': 1, 'precip_mm': 0.0, 'cloud': 10, 'vis_km': 10.0,
    'condition': {'text': 'Güneşli', 'icon': ''},
  },
};

Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen), useMaterial3: true, fontFamily: 'Roboto'),
      home: home,
    );

Future<void> _shoot(WidgetTester tester, Widget home, String name) async {
  debugDisableShadows = false; // gerçek gölgeler (test varsayılanı siyah çerçeve çizer)
  try {
    await _render(tester, home, name);
  } finally {
    debugDisableShadows = true;
  }
}

Future<void> _render(WidgetTester tester, Widget home, String name) async {
  await tester.pumpWidget(_app(home));
  // Arka plan görsellerini gerçekten yükle
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate().toList()) {
      await precacheImage((element.widget as Image).image, element);
    }
    for (final element in find.byType(Container).evaluate().toList()) {
      final decoration = (element.widget as Container).decoration;
      if (decoration is BoxDecoration && decoration.image != null) {
        await precacheImage(decoration.image!.image, element);
      }
    }
  });
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/screenshots/$name.png'));
}

void main() {
  setUpAll(_loadFonts);
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2340);
    view.devicePixelRatio = 2.625; // 411x891 dp telefon
    SharedPreferences.setMockInitialValues({'logged_in': true, 'user_email': 'admin@sirket.com'});
  });
  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset());

  testWidgets('giriş', (tester) => _shoot(tester, LoginPage(onLoggedIn: () {}), 'login'));

  testWidgets('ana ekran — sulama açık', (tester) => _shoot(
        tester,
        Scaffold(
          body: HomePageContent(
            isIrrigationOn: true,
            toggleIrrigation: () {},
            isLoading: false,
            errorMessage: '',
            weatherData: _weather,
            selectedDuration: const Duration(minutes: 30),
            remainingTime: const Duration(minutes: 18, seconds: 42),
            showDurationPicker: () {},
            resetTimer: () {},
            selectedLand: _land,
            onSuggest: () {},
            getBackgroundImage: backgroundImageFor,
          ),
          bottomNavigationBar: _nav(0),
        ),
        'home',
      ));

  testWidgets('hava durumu', (tester) => _shoot(
        tester,
        Scaffold(
          appBar: AppBar(backgroundColor: Colors.lightGreen.shade700, title: const Text('Hava Durumu Detayları', style: TextStyle(color: Colors.white))),
          body: WeatherDetailPage(weatherData: _weather, selectedLand: _land),
          bottomNavigationBar: _nav(1),
        ),
        'weather',
      ));

  testWidgets('geçmiş', (tester) {
    final now = DateTime.now();
    DateTime at(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
    return _shoot(
      tester,
      HistoryPage(
        selectedLand: _land,
        commandHistory: [
          IrrigationSession(at(5, 30), endTime: at(6, 0), landName: 'Zeytinlik'),
          IrrigationSession(at(18, 15), endTime: at(18, 27).add(const Duration(seconds: 40)), landName: 'Zeytinlik'),
        ],
      ),
      'history',
    );
  });

  testWidgets('yönetim', (tester) => _shoot(
        tester,
        Scaffold(
          appBar: AppBar(backgroundColor: Colors.lightGreen.shade700, title: const Text('Yönetim', style: TextStyle(color: Colors.white))),
          body: const AdminPage(),
          bottomNavigationBar: _nav(4),
        ),
        'admin',
      ));
}

Widget _nav(int index) => BottomNavigationBar(
      currentIndex: index,
      selectedItemColor: Colors.lightGreen[800],
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ana Sayfa'),
        BottomNavigationBarItem(icon: Icon(Icons.cloud), label: 'Hava Durumu'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Geçmiş'),
        BottomNavigationBarItem(icon: Icon(Icons.landscape), label: 'Arazilerim'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Yönetim'),
      ],
    );
