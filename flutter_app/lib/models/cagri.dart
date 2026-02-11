class Cagri {
  final String id;
  final String esnafId;
  final String? kuryeId;
  final String hedefAdres;
  final double mesafeKm;
  final double bazUcret;
  final double havaCarpani;
  final double geceEkUcret;
  final double toplamUcret;
  final String durum;
  final String? aciklama;
  final String? kuryeAd;
  final String? kuryeSoyad;
  final String? dukkanAdi;
  final String? kategori;
  final String? esnafAdres;
  final double? esnafLat;
  final double? esnafLon;
  final DateTime olusturulmaZamani;

  Cagri({
    required this.id,
    required this.esnafId,
    this.kuryeId,
    required this.hedefAdres,
    required this.mesafeKm,
    required this.bazUcret,
    required this.havaCarpani,
    required this.geceEkUcret,
    required this.toplamUcret,
    required this.durum,
    this.aciklama,
    this.kuryeAd,
    this.kuryeSoyad,
    this.dukkanAdi,
    this.kategori,
    this.esnafAdres,
    this.esnafLat,
    this.esnafLon,
    required this.olusturulmaZamani,
  });

  factory Cagri.fromJson(Map<String, dynamic> json) {
    return Cagri(
      id: json['id'],
      esnafId: json['esnaf_id'],
      kuryeId: json['kurye_id'],
      hedefAdres: json['hedef_adres'],
      mesafeKm: (json['mesafe_km'] as num).toDouble(),
      bazUcret: (json['baz_ucret'] as num).toDouble(),
      havaCarpani: (json['hava_carpani'] as num).toDouble(),
      geceEkUcret: (json['gece_ek_ucret'] as num).toDouble(),
      toplamUcret: (json['toplam_ucret'] as num).toDouble(),
      durum: json['durum'],
      aciklama: json['aciklama'],
      kuryeAd: json['kurye_ad'],
      kuryeSoyad: json['kurye_soyad'],
      dukkanAdi: json['dukkan_adi'],
      kategori: json['kategori'],
      esnafAdres: json['esnaf_adres'],
      esnafLat: json['esnaf_lat'] != null ? (json['esnaf_lat'] as num).toDouble() : null,
      esnafLon: json['esnaf_lon'] != null ? (json['esnaf_lon'] as num).toDouble() : null,
      olusturulmaZamani: DateTime.parse(json['olusturulma_zamani']),
    );
  }

  String get durumMetni {
    switch (durum) {
      case 'beklemede':
        return 'Kurye Aranıyor';
      case 'atandi':
        return 'Kurye Atandı';
      case 'teslim_alindi':
        return 'Teslim Alındı';
      case 'teslimde':
        return 'Yolda';
      case 'tamamlandi':
        return 'Tamamlandı';
      case 'iptal':
        return 'İptal Edildi';
      default:
        return durum;
    }
  }
}
