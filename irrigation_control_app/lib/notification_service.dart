import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart'; // ScaffoldMessenger için eklendi

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Alarm kanalının ID'si
  static const String alarmChannelId = 'alarm_channel_irrigation';
  static const String alarmChannelName = 'Sulama Alarmı';

  Future<void> initialize() async {
    if (_initialized) return;

    // YENİ: Android 12+ (API 31+) için tam ekran izinlerini manuel olarak isteme (opsiyonel ancak önerilir)
    // Bu, Android'in tam ekran intentlerini kısıtlamasını engellemeye yardımcı olur.
    // _requestPermissions();

    // Android Ayarları: Varsayılan ic_launcher kullanılır.
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Ayarları: İzin isteme
    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(initSettings);

    // Timezone setup for scheduled notifications
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.local);
    _initialized = true;
  }

  // Bildirim detaylarını, alarm sesi ve tam ekran ile oluşturur
  AndroidNotificationDetails _createAlarmAndroidDetails() {
    return const AndroidNotificationDetails(
      alarmChannelId, // Farklı bir ID kullanın
      alarmChannelName,
      channelDescription: 'Sulama süresi bittiğinde alarm olarak çalar.',
      importance: Importance.max,
      priority: Priority.max,

      // KRİTİK: Alarm sesi, titreşim ve tam ekran intent ayarları
      fullScreenIntent: true, // Uygulama kilitliyken bile tam ekran gösterir
      sound: RawResourceAndroidNotificationSound('alarm'), // Varsayılan alarm sesini kullanır (assets/raw/alarm.mp3 yoksa varsayılan sesi çalabilir)
      enableVibration: true,

      // Bildirim çubuğunda yüksek görünürlük sağlar
      showWhen: false,
      usesChronometer: false,
    );
  }


  Future<void> showInstant(String title, String body) async {
    final AndroidNotificationDetails android = _createAlarmAndroidDetails();
    const DarwinNotificationDetails ios = DarwinNotificationDetails();

    // HATA DÜZELTİLDİ: 'const' kaldırıldı çünkü 'android' sabit değil.
    final NotificationDetails details = NotificationDetails(android: android, iOS: ios);

    await _plugin.show(DateTime.now().millisecondsSinceEpoch % 100000, title, body, details);
  }

  Future<int> scheduleAt(DateTime when, String title, String body) async {
    final int id = when.millisecondsSinceEpoch % 100000;

    // YENİ KANAL KULLANILARAK ALARM ÖZELLİKLERİ EKLENDİ
    final AndroidNotificationDetails android = _createAlarmAndroidDetails();

    const DarwinNotificationDetails ios = DarwinNotificationDetails();

    // HATA DÜZELTİLDİ: 'const' kaldırıldı çünkü 'android' sabit değil.
    final NotificationDetails details = NotificationDetails(android: android, iOS: ios);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      details,
      // Dikkat: androidScheduleMode yerine 'exactAllowWhileIdle' kullanmak daha iyi olabilir
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
    return id;
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }
}


