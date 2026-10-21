# Sulama Kontrol Uygulaması (irrigation_control_app)

Tarladaki GSM modüllü sulama kontrol cihazlarını **SMS komutlarıyla** yöneten Flutter uygulaması.

- **Yetkili girişi** — yalnızca yönetici tarafından tanımlanan e-posta/şifre ile giriş (`AuthService`, SharedPreferences)
- **Sulama kontrolü** — seçili arazinin GSM numarasına `ON`, `ON<dakika>` ve `OFF` SMS komutları (`smsto:` URI)
- **Zamanlayıcı** — seçilen süre için geri sayım; süre dolunca otomatik `OFF`
- **Arazilerim** — arazi adı, telefon numarası ve koordinatlarıyla Firestore'da saklanan çoklu arazi desteği
- **Hava durumu** — seçili arazinin koordinatlarına göre WeatherAPI verisi ve hava durumuna göre arka plan
- **Komut geçmişi** — arazi ve güne göre filtrelenen sulama oturumları
- **Yönetim** — `admin@sirket.com` hesabı yetkili kullanıcı ekleyip silebilir

## Çalıştırma

```bash
flutter pub get
flutter run
```

## 🧪 Testler ve Doğrulama Sonuçları

Uygulamanın yapmak istediği şeyleri gerçekten yapıp yapmadığını doğrulayan birim ve widget testleri `test/` klasöründedir. UI ve Firebase'den bağımsız iş kuralları (SMS komutları, koordinat dönüştürme, süre biçimleri vb.) test edilebilmeleri için `lib/irrigation_logic.dart` dosyasında toplanmıştır; ekranlar bu fonksiyonları kullanır.

```bash
flutter test
```

### Son çalıştırma sonucu

> 21 Ekim 2026 · Flutter 3.47.7 (stable) · Dart 3.13.5 — **4 dosya, 44 test, 44 başarılı ✅, 0 başarısız**

| Test dosyası | Test | Sonuç | Doğrulanan davranış |
|---|:-:|:-:|---|
| `test/irrigation_logic_test.dart` | 15 | ✅ | `ON<dakika>` / `ON` / `OFF` komutları, `smsto:<numara>?body=<komut>` URI'si ve URL kodlaması, hava durumuna göre gündüz/gece arka planı, virgüllü koordinatların ayrıştırılması, e-postadan Firestore kimliği, geri sayım ve oturum süresi biçimleri |
| `test/auth_service_test.dart` | 10 | ✅ | Doğru şifreyle giriş ve oturumun kalıcı olması, yanlış şifre / yetkisiz e-posta reddi, çıkış, yalnızca `admin@sirket.com`'un yönetici olması, kullanıcı ekleme/silme ve tekrar eklemenin engellenmesi |
| `test/models_test.dart` | 4 | ✅ | `Land` modelinin Firestore dokümanından okunması ve eksik alan varsayılanları, `IrrigationSession` süre hesabı |
| `test/widgets_test.dart` | 15 | ✅ | Oturum yoksa giriş ekranıyla açılış, giriş başarı/hata akışı; yönetim panelinde listeleme, kullanıcı ekleme, onaylı silme, ana yöneticinin ve oturumdaki kullanıcının silinememesi; geçmişin araziye ve güne göre filtrelenmesi; hava durumu detayları; ana ekranda AÇ/KAPAT durumları, geri sayım, ÖNERİ ve SIFIRLA |

### Testlerin ortaya çıkardığı hatalar ve eksikler

| # | Bulgu | Durum |
|---|---|---|
| 1 | **İlk kurulumda kullanıcı ekleme/silme çöküyordu:** `AuthService` kayıtlı liste yokken `const` başlangıç haritasını döndürdüğü için `addUser`/`removeUser` "Cannot modify unmodifiable map" hatası veriyordu. | ✅ Düzeltildi — `lib/auth_service.dart` |
| 2 | **"KUR" (süre ayarla) butonu çalışmıyor:** `_showDurationPicker` boş bir fonksiyon. Süreli sulama yalnızca "ÖNERİ" (sabit 30 dk) ile başlatılabiliyor; `NotificationService.scheduleAt` hiç çağrılmıyor, yani süre bitiminde alarm bildirimi planlanmıyor. | ⚠️ Açık |
| 3 | **Sulama geçmişi kalıcı değil:** `lib/history_service.dart` derlenmiyor (`IrrigationSession` sınıfında `id` alanı yok) ve hiçbir yerde kullanılmıyor; geçmiş yalnızca bellekte tutulduğu için uygulama kapanınca kayboluyor. | ⚠️ Açık |
| 4 | Firestore yolları tutarsız: araziler `artifacts/remote-irrigation-app/users/{id}/lands`, geçmiş servisi ise `users/{id}/history` yoluna yazıyor. | ⚠️ Açık |
| 5 | WeatherAPI anahtarı kaynak kodda (`lib/main.dart`) açık duruyor; yapılandırma/ortam değişkenine taşınmalı. | ⚠️ Açık |

### Test kapsamı dışında kalanlar

`MainScreen` ve `MyLandsPage` oluşturulurken doğrudan `FirebaseFirestore.instance` kullandığından, Firebase emülatörü veya bağımlılık enjeksiyonu olmadan widget testinde açılamıyor. Bu yüzden Firestore'a gerçek arazi ekleme/güncelleme, canlı WeatherAPI çağrısı, telefonda SMS uygulamasının açılması ve yerel bildirimler otomatik testlerde doğrulanmamıştır; gerçek cihazda manuel test önerilir.
