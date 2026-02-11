class FiyatBilgisi {
  final double mesafeKm;
  final double bazUcret;
  final String havaDurumu;
  final double havaCarpani;
  final double geceEkUcret;
  final double toplamUcret;

  FiyatBilgisi({
    required this.mesafeKm,
    required this.bazUcret,
    required this.havaDurumu,
    required this.havaCarpani,
    required this.geceEkUcret,
    required this.toplamUcret,
  });

  factory FiyatBilgisi.fromJson(Map<String, dynamic> json) {
    return FiyatBilgisi(
      mesafeKm: (json['mesafe_km'] as num).toDouble(),
      bazUcret: (json['baz_ucret'] as num).toDouble(),
      havaDurumu: json['hava_durumu'],
      havaCarpani: (json['hava_carpani'] as num).toDouble(),
      geceEkUcret: (json['gece_ek_ucret'] as num).toDouble(),
      toplamUcret: (json['toplam_ucret'] as num).toDouble(),
    );
  }
}
