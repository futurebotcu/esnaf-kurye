import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiConstants {
  static String get _host {
    if (kIsWeb) return 'localhost'; // Chrome / Flutter Web
    if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2'; // Android emulator
    return 'localhost'; // iOS simulator / desktop
  }

  static String get baseUrl => 'http://$_host:3000/api';
  static String get socketUrl => 'http://$_host:3000';

  // Auth
  static String get kayit => '$baseUrl/auth/kayit';
  static String get giris => '$baseUrl/auth/giris';

  // Esnaf
  static String get esnafProfil => '$baseUrl/esnaf/profil';
  static String get fiyatHesapla => '$baseUrl/esnaf/fiyat-hesapla';
  static String get cagriOlustur => '$baseUrl/esnaf/cagri-olustur';
  static String get cagrilarim => '$baseUrl/esnaf/cagrilarim';

  // Kurye
  static String get kuryeProfil => '$baseUrl/kurye/profil';
  static String get kuryeKonum => '$baseUrl/kurye/konum';
  static String get kuryeDurum => '$baseUrl/kurye/durum';
  static String get aktifCagrilar => '$baseUrl/kurye/aktif-cagrilar';
  static String cagriKabul(String id) => '$baseUrl/kurye/cagri-kabul/$id';
  static String cagriReddet(String id) => '$baseUrl/kurye/cagri-reddet/$id';
  static String teslimAldim(String id) => '$baseUrl/kurye/teslim-aldim/$id';
  static String teslimEttim(String id) => '$baseUrl/kurye/teslim-ettim/$id';

  // Musteri
  static String cevredekiEsnaflar(double lat, double lon) =>
      '$baseUrl/musteri/cevredeki-esnaflar?lat=$lat&lon=$lon';
  static String get musteriAktifCagri => '$baseUrl/musteri/aktif-cagri';
  static String get musteriPuanla => '$baseUrl/musteri/puanla';
}
