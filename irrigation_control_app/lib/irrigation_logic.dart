// Uygulamanın saf (UI ve Firebase'den bağımsız) iş kuralları.
// Ekranlar bu fonksiyonları kullanır; testler de doğrudan bunları doğrular.

/// Sulamayı kapatan SMS komutu.
const String irrigationOffCommand = 'OFF';

/// Sulamayı açan SMS komutu: süre seçildiyse "ON<dakika>", seçilmediyse süresiz "ON".
String irrigationStartCommand(Duration? selectedDuration) {
  if (selectedDuration != null) {
    return 'ON${selectedDuration.inMinutes}';
  }
  return 'ON';
}

/// Arazideki GSM cihazına gönderilecek SMS için `smsto:` URI'si.
Uri buildSmsUri(String phoneNumber, String command) {
  return Uri.parse('smsto:$phoneNumber?body=${Uri.encodeComponent(command)}');
}

/// WeatherAPI anahtarı; kaynak kodda tutulmaz, `.env` dosyasından derleme anında okunur:
/// `flutter run --dart-define-from-file=.env`
const String weatherApiKey = String.fromEnvironment('WEATHER_API_KEY');

/// Verilen koordinat için WeatherAPI anlık hava durumu isteği (Türkçe).
Uri weatherApiUri(double latitude, double longitude, String apiKey) {
  return Uri.https('api.weatherapi.com', '/v1/current.json', {
    'key': apiKey,
    'q': '$latitude,$longitude',
    'lang': 'tr',
  });
}

/// Hava durumu metnine ve gündüz/gece bilgisine göre ana ekran arka planı.
String backgroundImageFor(String conditionText, int isDay) {
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

/// Herhangi bir değeri güvenli biçimde double'a çevirir ("39,4" gibi virgüllü değerler dahil).
double? convertToDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    String cleaned = value.trim().replaceAll(',', '.');
    return double.tryParse(cleaned);
  }
  return null;
}

/// Firestore'daki uygulama kökü: artifacts/{appId}/users/{userId}/...
const String firestoreAppId = 'remote-irrigation-app';

/// Uygulamayı kullanabilecek hesapların listesi: authorized_users/{uid} = { email, role, active }.
const String authorizedUsersCollectionPath = 'artifacts/$firestoreAppId/authorized_users';

/// Kullanıcının (Firebase Auth uid'si) arazilerinin tutulduğu koleksiyon.
String landsCollectionPath(String userId) => 'artifacts/$firestoreAppId/users/$userId/lands';

/// Kullanıcının (Firebase Auth uid'si) sulama geçmişinin tutulduğu koleksiyon.
String historyCollectionPath(String userId) => 'artifacts/$firestoreAppId/users/$userId/history';

/// E-posta adresini Firestore yolunda kullanılabilecek kullanıcı kimliğine çevirir.
String userIdFromEmail(String email) {
  return email.replaceAll('.', '_').replaceAll('@', '_');
}

/// Ana ekrandaki geri sayım göstergesi: "SS:DD:ss".
String formatCountdown(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String hours = twoDigits(duration.inHours);
  String minutes = twoDigits(duration.inMinutes.remainder(60));
  String seconds = twoDigits(duration.inSeconds.remainder(60));
  return "$hours:$minutes:$seconds";
}

/// Geçmiş ekranındaki oturum süresi: "01sa 05dk 03sn"; süre yoksa oturum devam ediyordur.
String formatSessionDuration(Duration? duration) {
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
  // Saniyeler sadece dakika ve saat yoksa veya 0 değilse gösterilir
  if (duration.inSeconds > 0 || (duration.inHours == 0 && duration.inMinutes == 0)) {
    formattedDuration += "${twoDigitSeconds}sn";
  }

  return formattedDuration.trim();
}
