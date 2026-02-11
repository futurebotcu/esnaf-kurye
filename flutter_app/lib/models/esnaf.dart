class EsnafBilgi {
  final String id;
  final String dukkanAdi;
  final String kategori;
  final String adres;
  final double lat;
  final double lon;
  final double ortalamaPuan;
  final double? mesafeMetre;

  EsnafBilgi({
    required this.id,
    required this.dukkanAdi,
    required this.kategori,
    required this.adres,
    required this.lat,
    required this.lon,
    required this.ortalamaPuan,
    this.mesafeMetre,
  });

  factory EsnafBilgi.fromJson(Map<String, dynamic> json) {
    return EsnafBilgi(
      id: json['id'],
      dukkanAdi: json['dukkan_adi'],
      kategori: json['kategori'],
      adres: json['adres'],
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      ortalamaPuan: (json['ortalama_puan'] as num?)?.toDouble() ?? 0.0,
      mesafeMetre: json['mesafe_metre'] != null
          ? (json['mesafe_metre'] as num).toDouble()
          : null,
    );
  }

  String get mesafeMetni {
    if (mesafeMetre == null) return '';
    if (mesafeMetre! < 1000) {
      return '${mesafeMetre!.round()} m';
    }
    return '${(mesafeMetre! / 1000).toStringAsFixed(1)} km';
  }
}
