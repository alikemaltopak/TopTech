import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrigation_control_app/admin_page.dart';
import 'package:irrigation_control_app/history_page.dart';
import 'package:irrigation_control_app/irrigation_logic.dart';
import 'package:irrigation_control_app/land_service.dart';
import 'package:irrigation_control_app/login_page.dart';
import 'package:irrigation_control_app/main.dart';
import 'package:irrigation_control_app/weather_detail_page.dart';

import 'helpers.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

final zeytinlik = Land(id: 'l1', name: 'Zeytinlik', phoneNumber: '+905551112233', latitude: 38.49, longitude: 27.52);

final weatherData = <String, dynamic>{
  'location': {'name': 'Turgutlu', 'region': 'Manisa', 'country': 'Turkey'},
  'current': {
    'temp_c': 27.4,
    'feelslike_c': 28.1,
    'humidity': 41,
    'wind_kph': 12.6,
    'pressure_mb': 1013.0,
    'uv': 6.0,
    'is_day': 1,
    'condition': {'text': 'Güneşli', 'icon': ''},
  },
};

void main() {
  late TestBackend backend;
  setUp(() async => backend = await TestBackend().seed());

  group('Uygulama girişi', () {
    testWidgets('oturum yoksa uygulama "Yetkili Girişi" ekranıyla açılır', (tester) async {
      await tester.pumpWidget(MyApp(authService: backend.authService));
      await tester.pumpAndSettle();
      expect(find.text('Yetkili Girişi'), findsOneWidget);
      expect(find.text('Giriş Yap'), findsOneWidget);
    });

    testWidgets('doğru bilgilerle giriş yapılınca onLoggedIn çağrılır', (tester) async {
      var loggedIn = false;
      await tester.pumpWidget(MaterialApp(home: LoginPage(onLoggedIn: () => loggedIn = true, authService: backend.authService)));
      await tester.enterText(find.widgetWithText(TextField, 'E-posta Adresi'), 'kurulum@sirket.com');
      await tester.enterText(find.widgetWithText(TextField, 'Şifre'), '123456');
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();
      expect(loggedIn, isTrue);
      expect(await backend.authService.isLoggedIn(), isTrue);
    });

    testWidgets('yanlış şifrede hata mesajı gösterilir ve giriş yapılmaz', (tester) async {
      var loggedIn = false;
      await tester.pumpWidget(MaterialApp(home: LoginPage(onLoggedIn: () => loggedIn = true, authService: backend.authService)));
      await tester.enterText(find.widgetWithText(TextField, 'E-posta Adresi'), 'kurulum@sirket.com');
      await tester.enterText(find.widgetWithText(TextField, 'Şifre'), 'yanlis');
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();
      expect(loggedIn, isFalse);
      expect(find.text('Giriş Başarısız: E-posta veya şifre hatalı.'), findsOneWidget);
    });

    testWidgets('yetkili listesinde olmayan Firebase hesabı giremez', (tester) async {
      var loggedIn = false;
      await tester.pumpWidget(MaterialApp(home: LoginPage(onLoggedIn: () => loggedIn = true, authService: backend.authService)));
      await tester.enterText(find.widgetWithText(TextField, 'E-posta Adresi'), 'yabanci@x.com');
      await tester.enterText(find.widgetWithText(TextField, 'Şifre'), '123456');
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();
      expect(loggedIn, isFalse);
      expect(find.textContaining('yetkili kullanıcılar arasında bulunmamaktadır'), findsOneWidget);
    });
  });

  group('Yönetim paneli', () {
    Future<void> openAdmin(WidgetTester tester, {String email = 'admin@sirket.com', String password = 'sifre123'}) async {
      await backend.authService.login(email, password);
      await tester.pumpWidget(MaterialApp(home: AdminPage(authService: backend.authService)));
      await tester.pumpAndSettle();
    }

    testWidgets('yetkili kullanıcıları listeler; yönetici hesabı silinemez', (tester) async {
      await openAdmin(tester);
      expect(find.text('admin@sirket.com'), findsOneWidget);
      expect(find.text('kurulum@sirket.com'), findsOneWidget);
      expect(find.text('eski@sirket.com'), findsNothing); // erişimi kaldırılmış
      expect(find.text('Yönetici'), findsOneWidget);
      final adminDelete = tester.widget<IconButton>(
        find.descendant(of: find.widgetWithText(ListTile, 'admin@sirket.com'), matching: find.byType(IconButton)),
      );
      expect(adminDelete.onPressed, isNull);
    });

    testWidgets('yeni kurulum yetkilisi eklenebilir', (tester) async {
      await openAdmin(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'E-posta'), 'saha@sirket.com');
      await tester.enterText(find.widgetWithText(TextField, 'Şifre'), 'parola123');
      await tester.tap(find.text('Ekle'));
      await tester.pumpAndSettle();
      expect(find.text('saha@sirket.com'), findsOneWidget);
      expect(find.text('Kullanıcı başarıyla eklendi.'), findsOneWidget);
      expect(await backend.authService.getAllUserEmails(), contains('saha@sirket.com'));
    });

    testWidgets('kullanıcının erişimi onay sonrası kaldırılır', (tester) async {
      await openAdmin(tester);
      await tester.tap(find.descendant(of: find.widgetWithText(ListTile, 'kurulum@sirket.com'), matching: find.byIcon(Icons.delete)));
      await tester.pumpAndSettle();
      expect(find.text('kurulum@sirket.com kullanıcısını silmek istediğinizden emin misiniz?'), findsOneWidget);
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(find.text('kurulum@sirket.com'), findsNothing);
      expect(await backend.authService.getAllUserEmails(), isNot(contains('kurulum@sirket.com')));
    });

    testWidgets('oturumu açık olan kullanıcı kendini silemez', (tester) async {
      await openAdmin(tester, email: 'kurulum@sirket.com', password: '123456');
      await tester.tap(find.descendant(of: find.widgetWithText(ListTile, 'kurulum@sirket.com'), matching: find.byIcon(Icons.delete)));
      await tester.pumpAndSettle();
      expect(find.text('Oturumu açık olan kullanıcıyı silemezsiniz.'), findsOneWidget);
      expect(await backend.authService.getAllUserEmails(), contains('kurulum@sirket.com'));
    });
  });

  group('Komut geçmişi', () {
    final now = DateTime.now();
    final sessions = [
      IrrigationSession(now.subtract(const Duration(minutes: 20)),
          endTime: now.subtract(const Duration(minutes: 5)), landName: 'Zeytinlik'),
      IrrigationSession(now.subtract(const Duration(minutes: 2)), landName: 'Zeytinlik'), // devam ediyor
      IrrigationSession(now.subtract(const Duration(minutes: 30)),
          endTime: now.subtract(const Duration(minutes: 29)), landName: 'Sera'),
      IrrigationSession(now.subtract(const Duration(days: 3)),
          endTime: now.subtract(const Duration(days: 3)).add(const Duration(minutes: 7)), landName: 'Zeytinlik'),
    ];

    testWidgets('sadece seçili arazinin bugünkü oturumları listelenir', (tester) async {
      await tester.pumpWidget(MaterialApp(home: HistoryPage(commandHistory: sessions, selectedLand: zeytinlik)));
      await tester.pumpAndSettle();
      expect(find.text('Seçili Arazi: Zeytinlik'), findsOneWidget);
      expect(find.text('4 Oturum'), findsOneWidget);
      expect(find.text(formatSessionDuration(const Duration(minutes: 15))), findsOneWidget); // "15dk"
      expect(find.text('Devam Ediyor'), findsWidgets); // bitmemiş oturum
      expect(find.text(formatSessionDuration(const Duration(minutes: 1))), findsNothing); // Sera'nın oturumu
      expect(find.text(formatSessionDuration(const Duration(minutes: 7))), findsNothing); // 3 gün önceki
    });

    testWidgets('kayıt yoksa boş durum mesajı gösterilir', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HistoryPage(commandHistory: [])));
      await tester.pumpAndSettle();
      expect(find.text('Henüz bir sulama geçmişi yok'), findsOneWidget);
    });
  });

  group('Hava durumu detayları', () {
    testWidgets('veri yoksa bilgilendirme mesajı', (tester) async {
      await tester.pumpWidget(wrap(const WeatherDetailPage()));
      expect(find.text('Hava durumu bilgisi mevcut değil.'), findsOneWidget);
    });

    testWidgets('seçili arazinin adı ve hava durumu değerleri gösterilir', (tester) async {
      await tester.pumpWidget(wrap(WeatherDetailPage(weatherData: weatherData, selectedLand: zeytinlik)));
      await tester.pumpAndSettle();
      expect(find.text('Zeytinlik'), findsOneWidget);
      expect(find.textContaining('27'), findsWidgets);
      expect(find.textContaining('Güneşli'), findsWidgets);
      expect(find.textContaining('41'), findsWidgets); // nem
    });
  });

  group('Ana ekran (sulama kontrolü)', () {
    // Uzun telefon ekranı (412x1200 dp): tüm kontroller kaydırmadan görünsün
    setUp(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(1236, 3600);
      view.devicePixelRatio = 3.0;
    });
    tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset());

    Widget home({
      bool isOn = false,
      Duration? selected,
      Duration remaining = Duration.zero,
      VoidCallback? toggle,
      VoidCallback? suggest,
      VoidCallback? reset,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: HomePageContent(
            isIrrigationOn: isOn,
            toggleIrrigation: toggle ?? () {},
            isLoading: false,
            errorMessage: '',
            weatherData: weatherData,
            selectedDuration: selected,
            remainingTime: remaining,
            showDurationPicker: () {},
            resetTimer: reset ?? () {},
            selectedLand: zeytinlik,
            onSuggest: suggest ?? () {},
            getBackgroundImage: backgroundImageFor,
          ),
        ),
      );
    }

    testWidgets('arazi adı, sıcaklık ve hava durumu gösterilir', (tester) async {
      await tester.pumpWidget(home());
      expect(find.text('Zeytinlik'), findsWidgets);
      expect(find.text('27.4°C'), findsOneWidget);
      expect(find.text('Güneşli'), findsWidgets);
    });

    testWidgets('sulama kapalıyken AÇ aktif, KAPAT pasif; AÇ sulamayı tetikler', (tester) async {
      var toggled = 0;
      await tester.pumpWidget(home(toggle: () => toggled++));
      final ac = tester.widget<ButtonStyleButton>(find.ancestor(of: find.text('AÇ'), matching: find.bySubtype<ButtonStyleButton>()));
      final kapat = tester.widget<ButtonStyleButton>(find.ancestor(of: find.text('KAPAT'), matching: find.bySubtype<ButtonStyleButton>()));
      expect(ac.onPressed, isNotNull);
      expect(kapat.onPressed, isNull);
      await tester.tap(find.text('AÇ'));
      expect(toggled, 1);
    });

    testWidgets('sulama açıkken KAPAT aktif ve kalan süre geri sayımı gösterilir', (tester) async {
      var toggled = 0;
      await tester.pumpWidget(home(
        isOn: true,
        selected: const Duration(minutes: 30),
        remaining: const Duration(minutes: 12, seconds: 5),
        toggle: () => toggled++,
      ));
      expect(find.text('00:12:05'), findsOneWidget);
      final ac = tester.widget<ButtonStyleButton>(find.ancestor(of: find.text('AÇ'), matching: find.bySubtype<ButtonStyleButton>()));
      expect(ac.onPressed, isNull);
      await tester.tap(find.text('KAPAT'));
      expect(toggled, 1);
    });

    testWidgets('ÖNERİ ve SIFIRLA butonları ilgili işlemleri tetikler', (tester) async {
      var suggested = 0, reset = 0;
      await tester.pumpWidget(home(selected: const Duration(minutes: 30), suggest: () => suggested++, reset: () => reset++));
      expect(find.text('00:30:00'), findsOneWidget);
      await tester.tap(find.text('ÖNERİ'));
      await tester.tap(find.text('SIFIRLA'));
      expect(suggested, 1);
      expect(reset, 1);
    });
  });
}
