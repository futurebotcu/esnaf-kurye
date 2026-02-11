import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api.dart';
import '../models/kullanici.dart';

class AuthService extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  Kullanici? _kullanici;
  String? _token;
  bool _yukleniyor = false;

  Kullanici? get kullanici => _kullanici;
  String? get token => _token;
  bool get yukleniyor => _yukleniyor;
  bool get girisYapildi => _token != null && _kullanici != null;

  Future<void> baslangicKontrol() async {
    _token = await _storage.read(key: 'token');
    final kullaniciJson = await _storage.read(key: 'kullanici');
    if (_token != null && kullaniciJson != null) {
      _kullanici = Kullanici.fromJson(jsonDecode(kullaniciJson));
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> kayitOl({
    required String telefon,
    required String sifre,
    required String ad,
    required String soyad,
    required String rol,
  }) async {
    _yukleniyor = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.kayit),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'telefon': telefon,
          'sifre': sifre,
          'ad': ad,
          'soyad': soyad,
          'rol': rol,
        }),
      );

      debugPrint('[KAYIT] Status: ${response.statusCode}');
      debugPrint('[KAYIT] Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        await _oturumuKaydet(data);
        return {'basarili': true};
      }
      return {'basarili': false, 'hata': data['hata'] ?? 'Bilinmeyen hata'};
    } catch (e) {
      debugPrint('[KAYIT] Hata: $e');
      return {'basarili': false, 'hata': 'Bağlantı hatası: $e'};
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> girisYap({
    required String telefon,
    required String sifre,
  }) async {
    _yukleniyor = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.giris),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'telefon': telefon,
          'sifre': sifre,
        }),
      );

      debugPrint('[GİRİŞ] Status: ${response.statusCode}');
      debugPrint('[GİRİŞ] Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _oturumuKaydet(data);
        return {'basarili': true};
      }
      return {'basarili': false, 'hata': data['hata'] ?? 'Bilinmeyen hata'};
    } catch (e) {
      debugPrint('[GİRİŞ] Hata: $e');
      return {'basarili': false, 'hata': 'Bağlantı hatası: $e'};
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  Future<void> _oturumuKaydet(Map<String, dynamic> data) async {
    _token = data['token'];
    _kullanici = Kullanici.fromJson(data['kullanici']);
    await _storage.write(key: 'token', value: _token);
    await _storage.write(
        key: 'kullanici', value: jsonEncode(data['kullanici']));
  }

  Future<void> cikisYap() async {
    _kullanici = null;
    _token = null;
    await _storage.deleteAll();
    notifyListeners();
  }

  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };
}
