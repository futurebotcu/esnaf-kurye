import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Merkezi HTTP istemci sınıfı.
/// Tüm API çağrılarını tek noktadan yönetir.
/// Otomatik auth header, hata yönetimi ve global SnackBar desteği sağlar.
class ApiClient {
  final AuthService _auth;

  /// Global SnackBar erişimi için ScaffoldMessengerState key'i.
  /// main.dart'ta tanımlanır ve MaterialApp'e bağlanır.
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Global Navigator key - 401'de otomatik çıkış için.
  static final navigatorKey = GlobalKey<NavigatorState>();

  ApiClient(this._auth);

  Map<String, String> get _headers => _auth.authHeaders;

  Future<ApiResponse> get(String url) async {
    return _handleRequest(() => http.get(Uri.parse(url), headers: _headers));
  }

  Future<ApiResponse> post(String url, {Map<String, dynamic>? body}) async {
    return _handleRequest(() => http.post(
          Uri.parse(url),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<ApiResponse> put(String url, {Map<String, dynamic>? body}) async {
    return _handleRequest(() => http.put(
          Uri.parse(url),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<ApiResponse> _handleRequest(
      Future<http.Response> Function() request) async {
    try {
      final response = await request();

      debugPrint('[API] ${response.request?.method} ${response.request?.url} → ${response.statusCode}');

      final data = response.body.isNotEmpty ? jsonDecode(response.body) : null;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(basarili: true, data: data, statusCode: response.statusCode);
      }

      // Hata durumları
      final hataMesaji = _hataMesajiOlustur(response.statusCode, data);

      if (response.statusCode == 401) {
        // Token expired - otomatik çıkış
        _bildirimGoster(hataMesaji, hata: true);
        await _auth.cikisYap();
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/giris', (_) => false);
        return ApiResponse(basarili: false, hataMesaji: hataMesaji, statusCode: 401);
      }

      _bildirimGoster(hataMesaji, hata: true);
      return ApiResponse(basarili: false, data: data, hataMesaji: hataMesaji, statusCode: response.statusCode);
    } on http.ClientException {
      const mesaj = 'Baglanti hatasi. Interneti kontrol edin.';
      _bildirimGoster(mesaj, hata: true);
      return const ApiResponse(basarili: false, hataMesaji: mesaj, statusCode: 0);
    } catch (e) {
      final mesaj = 'Beklenmeyen hata: $e';
      debugPrint('[API] Hata: $e');
      _bildirimGoster(mesaj, hata: true);
      return ApiResponse(basarili: false, hataMesaji: mesaj, statusCode: 0);
    }
  }

  String _hataMesajiOlustur(int statusCode, dynamic data) {
    final serverMesaj = data is Map ? (data['hata'] ?? data['mesaj']) : null;

    switch (statusCode) {
      case 400:
        return serverMesaj?.toString() ?? 'Gecersiz istek';
      case 401:
        return 'Oturum suresi doldu. Tekrar giris yapin.';
      case 403:
        return 'Bu isleme yetkiniz yok.';
      case 404:
        return serverMesaj?.toString() ?? 'Kayit bulunamadi';
      case 500:
        return 'Sunucu hatasi. Lutfen tekrar deneyin.';
      default:
        return serverMesaj?.toString() ?? 'Bir hata olustu (HTTP $statusCode)';
    }
  }

  static void _bildirimGoster(String mesaj, {bool hata = false}) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: hata ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Başarı bildirimi göstermek için statik yardımcı
  static void basariBildirimi(String mesaj) {
    _bildirimGoster(mesaj, hata: false);
  }
}

/// API yanıt modeli
class ApiResponse {
  final bool basarili;
  final dynamic data;
  final String? hataMesaji;
  final int statusCode;

  const ApiResponse({
    required this.basarili,
    this.data,
    this.hataMesaji,
    required this.statusCode,
  });
}
