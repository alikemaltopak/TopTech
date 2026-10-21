# TopTech — Uzaktan Sulama Kontrolü

Tarladaki GSM modüllü sulama cihazını SMS ile açıp kapatan, sulama geçmişini Firebase Firestore'da tutan Flutter uygulaması.

<p align="center">
  <img src="irrigation_control_app/docs/screenshots/home.png" width="180" alt="Ana ekran" />
  <img src="irrigation_control_app/docs/screenshots/weather.png" width="180" alt="Hava durumu" />
  <img src="irrigation_control_app/docs/screenshots/history.png" width="180" alt="Geçmiş" />
</p>

```mermaid
flowchart LR
    APP[📱 Uygulama] -- "SMS: ON30 / OFF" --> DEV[🔌 GSM cihazı] --> V[🚰 Vana]
    APP <--> FS[(🔥 Firestore<br/>araziler + geçmiş)]
    APP --> W[🌤️ WeatherAPI]
```

Ekranlar, çalışma mantığı, kurulum (`.env`) ve test sonuçları için: **[irrigation_control_app/README.md](irrigation_control_app/README.md)**

```bash
cd irrigation_control_app
cp .env.example .env        # WEATHER_API_KEY=...
flutter pub get
flutter run --dart-define-from-file=.env
flutter test                # 53 test
```
