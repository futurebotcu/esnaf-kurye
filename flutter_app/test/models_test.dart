import 'package:flutter_test/flutter_test.dart';
import 'package:esnaf_kurye/models/kullanici.dart';
import 'package:esnaf_kurye/models/cagri.dart';
import 'package:esnaf_kurye/models/fiyat.dart';
import 'package:esnaf_kurye/models/esnaf.dart';

void main() {
  group('Kullanici.fromJson', () {
    test('tüm alanları doğru parse eder', () {
      final json = {
        'id': 'abc-123',
        'telefon': '5551234567',
        'ad': 'Ali',
        'soyad': 'Yılmaz',
        'rol': 'musteri',
        'email': 'ali@test.com',
      };
      final k = Kullanici.fromJson(json);
      expect(k.id, 'abc-123');
      expect(k.telefon, '5551234567');
      expect(k.ad, 'Ali');
      expect(k.soyad, 'Yılmaz');
      expect(k.rol, 'musteri');
      expect(k.email, 'ali@test.com');
    });

    test('email null olabilir', () {
      final json = {
        'id': 'x',
        'telefon': '5550000000',
        'ad': 'Test',
        'soyad': 'User',
        'rol': 'esnaf',
        'email': null,
      };
      final k = Kullanici.fromJson(json);
      expect(k.email, isNull);
    });
  });

  group('Cagri.fromJson', () {
    test('zorunlu alanları doğru parse eder', () {
      final json = {
        'id': 'cagri-1',
        'esnaf_id': 'esnaf-1',
        'kurye_id': null,
        'hedef_adres': 'Test Mah.',
        'mesafe_km': 3.5,
        'baz_ucret': 17.5,
        'hava_carpani': 1.0,
        'gece_ek_ucret': 0,
        'toplam_ucret': 20.0,
        'durum': 'beklemede',
        'aciklama': null,
        'kurye_ad': null,
        'kurye_soyad': null,
        'dukkan_adi': null,
        'kategori': null,
        'esnaf_adres': null,
        'esnaf_lat': null,
        'esnaf_lon': null,
        'olusturulma_zamani': '2024-01-15T14:00:00.000Z',
      };
      final c = Cagri.fromJson(json);
      expect(c.id, 'cagri-1');
      expect(c.mesafeKm, 3.5);
      expect(c.toplamUcret, 20.0);
      expect(c.durum, 'beklemede');
      expect(c.kuryeId, isNull);
    });

    test('durumMetni doğru döner', () {
      final json = {
        'id': 'c1',
        'esnaf_id': 'e1',
        'hedef_adres': 'Adres',
        'mesafe_km': 1,
        'baz_ucret': 5,
        'hava_carpani': 1,
        'gece_ek_ucret': 0,
        'toplam_ucret': 20,
        'durum': 'teslimde',
        'olusturulma_zamani': '2024-01-15T14:00:00.000Z',
      };
      final c = Cagri.fromJson(json);
      expect(c.durumMetni, 'Yolda');
    });

    test('integer num alanları double olarak parse edilir', () {
      final json = {
        'id': 'c2',
        'esnaf_id': 'e1',
        'hedef_adres': 'Adres',
        'mesafe_km': 5,
        'baz_ucret': 25,
        'hava_carpani': 1,
        'gece_ek_ucret': 15,
        'toplam_ucret': 40,
        'durum': 'beklemede',
        'olusturulma_zamani': '2024-01-15T23:00:00.000Z',
      };
      final c = Cagri.fromJson(json);
      expect(c.mesafeKm, isA<double>());
      expect(c.geceEkUcret, 15.0);
    });
  });

  group('FiyatBilgisi.fromJson', () {
    test('tüm alanları doğru parse eder', () {
      final json = {
        'mesafe_km': 4.2,
        'baz_ucret': 21.0,
        'hava_durumu': 'yagmurlu',
        'hava_carpani': 1.3,
        'gece_ek_ucret': 15.0,
        'toplam_ucret': 42.3,
      };
      final f = FiyatBilgisi.fromJson(json);
      expect(f.mesafeKm, 4.2);
      expect(f.havaDurumu, 'yagmurlu');
      expect(f.havaCarpani, 1.3);
      expect(f.geceEkUcret, 15.0);
      expect(f.toplamUcret, 42.3);
    });
  });

  group('EsnafBilgi.fromJson', () {
    test('tüm alanları doğru parse eder', () {
      final json = {
        'id': 'esnaf-1',
        'dukkan_adi': 'Test Cafe',
        'kategori': 'Kafe',
        'adres': 'Test Sok. No:1',
        'lat': 41.0082,
        'lon': 28.9784,
        'ortalama_puan': 4.5,
        'mesafe_metre': 1250.0,
      };
      final e = EsnafBilgi.fromJson(json);
      expect(e.id, 'esnaf-1');
      expect(e.dukkanAdi, 'Test Cafe');
      expect(e.kategori, 'Kafe');
      expect(e.lat, 41.0082);
      expect(e.ortalamaPuan, 4.5);
      expect(e.mesafeMetre, 1250.0);
    });

    test('mesafeMetni km formatında döner', () {
      final json = {
        'id': 'e1',
        'dukkan_adi': 'X',
        'kategori': 'Y',
        'adres': 'Z',
        'lat': 41.0,
        'lon': 29.0,
        'ortalama_puan': 0,
        'mesafe_metre': 2500.0,
      };
      final e = EsnafBilgi.fromJson(json);
      expect(e.mesafeMetni, '2.5 km');
    });

    test('mesafeMetni metre formatında döner', () {
      final json = {
        'id': 'e2',
        'dukkan_adi': 'X',
        'kategori': 'Y',
        'adres': 'Z',
        'lat': 41.0,
        'lon': 29.0,
        'ortalama_puan': null,
        'mesafe_metre': 450.0,
      };
      final e = EsnafBilgi.fromJson(json);
      expect(e.mesafeMetni, '450 m');
      expect(e.ortalamaPuan, 0.0);
    });

    test('mesafe null olduğunda boş string döner', () {
      final json = {
        'id': 'e3',
        'dukkan_adi': 'X',
        'kategori': 'Y',
        'adres': 'Z',
        'lat': 41.0,
        'lon': 29.0,
        'ortalama_puan': 3.0,
        'mesafe_metre': null,
      };
      final e = EsnafBilgi.fromJson(json);
      expect(e.mesafeMetni, '');
    });
  });
}
