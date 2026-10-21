# 💧 Sulama Kontrol Uygulaması

Tarladaki **GSM modüllü sulama kontrol cihazını SMS komutlarıyla** yöneten Flutter uygulaması. Sahada internet olmasa bile telefonun SMS uygulaması üzerinden vanayı açar/kapatır; sulama geçmişini ve arazileri **Firebase Firestore**'da saklar, seçili arazinin hava durumunu gösterir.

<p align="center">
  <img src="docs/screenshots/login.png" width="160" alt="Giriş" />
  <img src="docs/screenshots/home.png" width="160" alt="Ana ekran" />
  <img src="docs/screenshots/weather.png" width="160" alt="Hava durumu" />
  <img src="docs/screenshots/history.png" width="160" alt="Geçmiş" />
  <img src="docs/screenshots/admin.png" width="160" alt="Yönetim" />
</p>

---

## 📱 Ekranlar ve ne yaptıkları

| Ekran | Görünüm | Ne yapar? |
|---|:-:|---|
| **Yetkili Girişi** | <img src="docs/screenshots/login.png" width="180" /> | Sadece yöneticinin tanımladığı e-posta/şifre ile giriş yapılır. Oturum telefonda saklanır, uygulama tekrar açıldığında yeniden giriş istemez. |
| **Ana Sayfa** | <img src="docs/screenshots/home.png" width="180" /> | Seçili arazinin anlık hava durumu (arka plan hava durumuna ve gündüz/geceye göre değişir). **KUR** ile süre seçilir, **ÖNERİ** 30 dk önerir, **SIFIRLA** süreyi temizler. **AÇ** cihaza `ON<dakika>` (süre yoksa `ON`), **KAPAT** `OFF` SMS'i gönderir. Süre dolunca sulama kendiliğinden kapanır. |
| **Hava Durumu** | <img src="docs/screenshots/weather.png" width="180" /> | Arazinin koordinatlarına göre sıcaklık, nem, rüzgâr, basınç, hissedilen sıcaklık, görüş, UV ve bulut oranı (WeatherAPI). |
| **Komut Geçmişi** | <img src="docs/screenshots/history.png" width="180" /> | Seçili arazinin, seçilen güne ait sulama oturumları: açılış/kapanış zamanı ve toplam süre. Kayıtlar Firestore'dan canlı okunur. |
| **Yönetim** | <img src="docs/screenshots/admin.png" width="180" /> | Sadece `admin@sirket.com` görür. Kurulum yetkilisi ekler/siler; ana yönetici ve oturumu açık kullanıcı silinemez. |

---

## ⚙️ Nasıl çalışır?

### Genel mimari

```mermaid
flowchart LR
    U([👨‍🌾 Kullanıcı]) --> APP[📱 Flutter Uygulaması]
    APP -- "SMS: ON30 / ON / OFF" --> SMS[📨 Telefonun SMS uygulaması]
    SMS -- GSM şebekesi --> DEV[🔌 Tarladaki GSM kontrol cihazı]
    DEV --> V[🚰 Selenoid vana / pompa]
    APP -- "Araziler + sulama geçmişi" --> FS[(🔥 Firebase Firestore)]
    APP -- "enlem, boylam" --> W[🌤️ WeatherAPI]
    APP -- "giriş + yetkili listesi" --> SP[(💾 SharedPreferences)]
```

### Bir sulama oturumu

```mermaid
sequenceDiagram
    actor K as Kullanıcı
    participant A as Uygulama
    participant S as SMS uygulaması
    participant C as GSM cihazı
    participant F as Firestore

    K->>A: KUR → 30 dk seç, AÇ'a bas
    A->>F: history/{id} ekle (status: active, startTime)
    A->>S: smsto:+90555…?body=ON30
    S->>C: "ON30"
    C-->>C: Vana açılır
    loop Her saniye
        A-->>K: Geri sayım 00:29:59 …
    end
    alt Süre doldu veya KAPAT'a basıldı
        A->>S: smsto:+90555…?body=OFF
        S->>C: "OFF"
        A->>F: history/{id} güncelle (endTime, durationSeconds, status: completed)
    end
    F-->>A: Geçmiş ekranı canlı güncellenir
```

### Ekran akışı

```mermaid
flowchart TD
    S[Uygulama açılır] --> L{Oturum açık mı?}
    L -- Hayır --> G[Yetkili Girişi] --> M
    L -- Evet --> M[Ana Sayfa]
    M --- H[Hava Durumu]
    M --- C[Komut Geçmişi]
    M --- AR[Arazilerim<br/>ekle / düzenle / sil / seç]
    M --- Y{Yönetici mi?}
    Y -- Evet --> YP[Yönetim paneli]
    AR -- arazi seçilince --> M
```

### Firestore veri yapısı

```
artifacts/remote-irrigation-app/users/{kullanici_id}/      ← e-posta: "ali.k@x.com" → "ali_k_x_com"
├── lands/{arazi_id}
│     name, phoneNumber, latitude, longitude, createdAt
└── history/{oturum_id}
      landId, landName, startTime, endTime, durationSeconds, status ("active" | "completed")
```

### SMS komutları

| Komut | Ne zaman | Anlamı |
|---|---|---|
| `ON30` | Süre seçiliyken AÇ | 30 dakika sula, sonra kendiliğinden kapan |
| `ON` | Süre seçilmeden AÇ | Süresiz sula (KAPAT'a kadar) |
| `OFF` | KAPAT veya süre bittiğinde | Sulamayı durdur |

---

## 🚀 Kurulum ve çalıştırma

1. Bağımlılıkları yükleyin:
   ```bash
   flutter pub get
   ```
2. Hava durumu anahtarı için `.env` dosyası oluşturun (bu dosya **git'e eklenmez**, `.gitignore`'dadır):
   ```bash
   cp .env.example .env
   # .env içine: WEATHER_API_KEY=<weatherapi.com anahtarınız>
   ```
3. Uygulamayı `.env` ile çalıştırın:
   ```bash
   flutter run --dart-define-from-file=.env
   flutter build apk --dart-define-from-file=.env
   ```
   VS Code'da kök klasördeki `.vscode/launch.json` bu parametreyi otomatik verir. Anahtar verilmezse ana ekranda hava durumu yerine uyarı mesajı görünür; sulama kontrolü yine çalışır.

> ⚠️ Eski WeatherAPI anahtarı daha önce `lib/main.dart` içinde git'e gönderilmişti. Kaynaktan kaldırıldı, ancak git geçmişinde hâlâ duruyor; **weatherapi.com panelinden anahtarı yenileyip** yenisini `.env`'e yazın.

---

## 🧪 Testler ve doğrulama sonuçları

```bash
flutter test
```

UI ve Firebase'den bağımsız iş kuralları (SMS komutları, koordinat dönüştürme, Firestore yolları, süre biçimleri, WeatherAPI isteği) `lib/irrigation_logic.dart` içindedir. Firestore servisleri testlerde [`fake_cloud_firestore`](https://pub.dev/packages/fake_cloud_firestore) ile gerçek bağlantı olmadan doğrulanır.

### Son çalıştırma sonucu

> 21 Ekim 2026 · Flutter 3.47.7 (stable) · Dart 3.13.5 — **5 dosya, 53 test, 53 başarılı ✅, 0 başarısız**

| Test dosyası | Test | Sonuç | Doğrulanan davranış |
|---|:-:|:-:|---|
| `test/irrigation_logic_test.dart` | 17 | ✅ | `ON<dakika>` / `ON` / `OFF` komutları, `smsto:` URI'si ve URL kodlaması, WeatherAPI isteği, Firestore yolları, gündüz/gece arka planı, virgüllü koordinatlar, süre biçimleri |
| `test/firestore_services_test.dart` | 7 | ✅ | Sulama başlayınca oturumun `active` kaydı, bitince `endTime` + `durationSeconds` + `completed`, uygulama yeniden açıldığında geçmişin en yeniden eskiye okunması, kullanıcı bazlı ayrım, arazi ekle/listele/güncelle/sil |
| `test/auth_service_test.dart` | 10 | ✅ | Giriş ve kalıcı oturum, yanlış şifre / yetkisiz e-posta reddi, çıkış, yönetici yetkisi, kullanıcı ekleme/silme |
| `test/models_test.dart` | 4 | ✅ | `Land` modelinin Firestore'dan okunması, `IrrigationSession` süre hesabı |
| `test/widgets_test.dart` | 15 | ✅ | Giriş ekranı akışı, yönetim paneli, geçmişin araziye/güne göre filtrelenmesi, hava durumu detayları, ana ekranda AÇ/KAPAT, geri sayım, ÖNERİ, SIFIRLA |

### Testlerle bulunan ve düzeltilen hatalar

| # | Bulgu | Durum |
|---|---|---|
| 1 | İlk kurulumda kullanıcı ekleme/silme "Cannot modify unmodifiable map" hatasıyla çöküyordu (`AuthService` sabit haritayı döndürüyordu). | ✅ Düzeltildi |
| 2 | Sulama geçmişi Firestore'a kaydedilmiyordu: `history_service.dart` derlenmiyordu ve hiç kullanılmıyordu, geçmiş uygulama kapanınca kayboluyordu. | ✅ Düzeltildi — oturumlar başlangıçta kaydedilip bitişte güncelleniyor, geçmiş ekranı Firestore'dan canlı okuyor |
| 3 | Araziler ve geçmiş farklı Firestore köklerine yazılıyordu. | ✅ Düzeltildi — ikisi de `artifacts/remote-irrigation-app/users/{id}/` altında |
| 4 | WeatherAPI anahtarı kaynak kodda açıktı. | ✅ `.env` + `--dart-define-from-file` (anahtarın yenilenmesi önerilir) |
| 5 | Hava durumu ekranında rüzgâr hızı `km/s` yazıyor (`km/sa` olmalı). | ⚠️ Kozmetik, açık |

> Not: **KUR** butonu yazılım tarafında çalışıyor (saat/dakika seçici açılıyor). Sahadaki devrede arızalı bir bileşen değiştirilene kadar cihaz tarafında süreli çalışma beklemede.

### Test kapsamı dışında kalanlar

`MainScreen` ve `MyLandsPage` doğrudan Firebase'e bağlandığı için widget testinde açılamıyor; bu ekranların akışı servis testleri üzerinden doğrulandı. Telefonda SMS uygulamasının gerçekten açılması, mesajın cihaza ulaşması, canlı WeatherAPI yanıtı ve yerel bildirimler gerçek cihazda manuel test edilmelidir.

### Ekran görüntülerini yeniden üretmek

README'deki görseller uygulamanın gerçek widget'ları (gerçek Roboto fontu ve asset'lerle) çizilerek üretilir:

```bash
flutter test tool/screenshots_test.dart --update-goldens   # → docs/screenshots/*.png
```
