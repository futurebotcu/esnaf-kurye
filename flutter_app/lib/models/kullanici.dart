class Kullanici {
  final String id;
  final String telefon;
  final String ad;
  final String soyad;
  final String rol;
  final String? email;

  Kullanici({
    required this.id,
    required this.telefon,
    required this.ad,
    required this.soyad,
    required this.rol,
    this.email,
  });

  factory Kullanici.fromJson(Map<String, dynamic> json) {
    return Kullanici(
      id: json['id'],
      telefon: json['telefon'],
      ad: json['ad'],
      soyad: json['soyad'],
      rol: json['rol'],
      email: json['email'],
    );
  }
}
