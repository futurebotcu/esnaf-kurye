import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../services/api_client.dart';
import '../../constants/api.dart';
import '../../constants/theme.dart';
import '../../models/cagri.dart';
import '../../models/fiyat.dart';
import '../../widgets/konum_secici.dart';

class EsnafAnaEkran extends StatefulWidget {
  const EsnafAnaEkran({super.key});

  @override
  State<EsnafAnaEkran> createState() => _EsnafAnaEkranState();
}

class _EsnafAnaEkranState extends State<EsnafAnaEkran> {
  Map<String, dynamic>? _esnafProfil;
  List<Cagri> _cagrilar = [];
  bool _yukleniyor = true;
  Cagri? _aktifCagri;

  // Kurye takibi
  LatLng? _kuryeKonum;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _verileriYukle();
    _socketDinle();
  }

  void _socketDinle() {
    final socket = context.read<SocketService>();
    final auth = context.read<AuthService>();

    if (!socket.bagli && auth.token != null) {
      socket.baglan(auth.token!);
    }

    // Kurye konum güncellemesini dinle
    socket.dinle('kurye:konum', (data) {
      if (mounted) {
        setState(() {
          _kuryeKonum = LatLng(
            (data['lat'] as num).toDouble(),
            (data['lon'] as num).toDouble(),
          );
        });
        // Haritayı kuryeye odakla
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_kuryeKonum!),
        );
      }
    });

    // Çağrı durumu güncellemeleri
    socket.dinle('cagri_kabul_edildi', (data) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Kurye bulundu: ${data['kurye_ad']} ${data['kurye_soyad']}'),
            backgroundColor: AppTheme.success,
          ),
        );
        _cagrilariYukle();
      }
    });

    socket.dinle('teslim_alindi', (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kurye paketi teslim aldı!'),
            backgroundColor: AppTheme.success,
          ),
        );
        _cagrilariYukle();
      }
    });

    socket.dinle('teslim_tamamlandi', (data) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Teslimat tamamlandı! (${data['odeme_yontemi'] == 'nakit' ? 'Nakit' : 'Sanal POS'})'),
            backgroundColor: AppTheme.success,
          ),
        );
        setState(() {
          _aktifCagri = null;
          _kuryeKonum = null;
        });
        _cagrilariYukle();
      }
    });
  }

  Future<void> _verileriYukle() async {
    await Future.wait([
      _profilYukle(),
      _cagrilariYukle(),
    ]);
    setState(() => _yukleniyor = false);
  }

  late final ApiClient _api = ApiClient(context.read<AuthService>());

  Future<void> _profilYukle() async {
    final response = await _api.get(ApiConstants.esnafProfil);
    if (response.basarili && response.data != null) {
      setState(() => _esnafProfil = response.data['esnaf']);
    }
  }

  Future<void> _cagrilariYukle() async {
    final response = await _api.get(ApiConstants.cagrilarim);
    if (response.basarili && response.data != null) {
      setState(() {
        _cagrilar = (response.data['cagrilar'] as List)
            .map((c) => Cagri.fromJson(c))
            .toList();
        _aktifCagri = _cagrilar.where((c) =>
            c.durum == 'beklemede' ||
            c.durum == 'atandi' ||
            c.durum == 'teslim_alindi').firstOrNull;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_esnafProfil?['dukkan_adi'] ?? 'Esnaf Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _verileriYukle,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              context.read<SocketService>().kes();
              await auth.cikisYap();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/giris');
              }
            },
          ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _verileriYukle,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dükkan Bilgi Kartı
                    _DukkanBilgiKarti(
                      profil: _esnafProfil,
                      onProfilOlustur: () => _profilOlusturDialog(context),
                    ),
                    const SizedBox(height: 16),

                    // Aktif Çağrı / Kurye Takip Haritası
                    if (_aktifCagri != null) ...[
                      _AktifCagriKarti(
                        cagri: _aktifCagri!,
                        kuryeKonum: _kuryeKonum,
                        onMapOlustur: (controller) =>
                            _mapController = controller,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // KURYE ÇAĞIR BUTONU
                    SizedBox(
                      height: 72,
                      child: ElevatedButton.icon(
                        onPressed: _aktifCagri != null
                            ? null
                            : () => _kuryeCagirDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          disabledBackgroundColor: Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        icon: const Icon(Icons.delivery_dining, size: 32),
                        label: Text(
                          _aktifCagri != null
                              ? 'Aktif Teslimat Var'
                              : 'KURYE CAGIR',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Son Çağrılar
                    const Text(
                      'Son Teslimatlar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_cagrilar.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'Henüz teslimat yok',
                              style:
                                  TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                      )
                    else
                      ..._cagrilar.take(10).map(
                            (cagri) => _CagriKarti(cagri: cagri),
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  void _profilOlusturDialog(BuildContext context) {
    final dukkanAdiController = TextEditingController();
    final kategoriController = TextEditingController();
    final adresController = TextEditingController();
    final telefonController = TextEditingController();
    final aciklamaController = TextEditingController();
    LatLng secilenKonum = const LatLng(39.9208, 32.8541);
    bool kaydediyor = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Dukkan Profili Olustur',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: dukkanAdiController,
                  decoration: const InputDecoration(
                    labelText: 'Dukkan Adi *',
                    prefixIcon: Icon(Icons.store),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: kategoriController,
                  decoration: const InputDecoration(
                    labelText: 'Kategori *',
                    hintText: 'ornek: market, kebapci, eczane',
                    prefixIcon: Icon(Icons.category),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: adresController,
                  decoration: const InputDecoration(
                    labelText: 'Adres *',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telefonController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon *',
                    hintText: '05XX XXX XX XX',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Dukkan Konumu',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                KonumSecici(
                  onKonumSecildi: (konum) {
                    secilenKonum = konum;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: aciklamaController,
                  decoration: const InputDecoration(
                    labelText: 'Aciklama (istege bagli)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: kaydediyor
                        ? null
                        : () async {
                            if (dukkanAdiController.text.isEmpty ||
                                kategoriController.text.isEmpty ||
                                adresController.text.isEmpty ||
                                telefonController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Zorunlu alanlari doldurun'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                              return;
                            }
                            setSheetState(() => kaydediyor = true);
                            final response = await _api.post(
                              ApiConstants.esnafProfil,
                              body: {
                                'dukkan_adi': dukkanAdiController.text,
                                'kategori': kategoriController.text,
                                'adres': adresController.text,
                                'telefon': telefonController.text,
                                'lat': secilenKonum.latitude,
                                'lon': secilenKonum.longitude,
                                'aciklama': aciklamaController.text.isNotEmpty
                                    ? aciklamaController.text
                                    : null,
                              },
                            );

                            if (ctx.mounted) Navigator.pop(ctx);

                            if (mounted && response.basarili) {
                              ApiClient.basariBildirimi('Dukkan profili kaydedildi!');
                              _verileriYukle();
                            }
                            setSheetState(() => kaydediyor = false);
                          },
                    icon: const Icon(Icons.save),
                    label: Text(kaydediyor ? 'Kaydediliyor...' : 'KAYDET'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _kuryeCagirDialog(BuildContext context) {
    final adresController = TextEditingController();
    LatLng hedefKonum = const LatLng(39.9208, 32.8541);
    FiyatBilgisi? fiyat;
    bool hesaplaniyor = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sürükle göstergesi
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Kurye Cagir',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Hedef Adres
                TextFormField(
                  controller: adresController,
                  decoration: const InputDecoration(
                    labelText: 'Teslimat Adresi',
                    hintText: 'Hedef adresi girin...',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // Harita ile konum seçimi
                const Text(
                  'Teslimat Konumu',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                KonumSecici(
                  onKonumSecildi: (konum) {
                    hedefKonum = konum;
                  },
                ),
                const SizedBox(height: 16),

                // Fiyat Hesapla
                OutlinedButton.icon(
                  onPressed: hesaplaniyor
                      ? null
                      : () async {
                          setSheetState(() => hesaplaniyor = true);
                          final response = await _api.post(
                            ApiConstants.fiyatHesapla,
                            body: {
                              'hedef_lat': hedefKonum.latitude,
                              'hedef_lon': hedefKonum.longitude,
                            },
                          );
                          if (response.basarili && response.data != null) {
                            setSheetState(() {
                              fiyat = FiyatBilgisi.fromJson(response.data['fiyat']);
                            });
                          }
                          setSheetState(() => hesaplaniyor = false);
                        },
                  icon: const Icon(Icons.calculate),
                  label: Text(hesaplaniyor ? 'Hesaplanıyor...' : 'Fiyat Hesapla'),
                ),
                const SizedBox(height: 12),

                // Fiyat Detayı
                if (fiyat != null) ...[
                  Card(
                    color: AppTheme.primary.withValues(alpha:0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _FiyatSatiri(
                              'Mesafe', '${fiyat!.mesafeKm.toStringAsFixed(1)} km'),
                          _FiyatSatiri(
                              'Baz Ucret', '${fiyat!.bazUcret.toStringAsFixed(2)} TL'),
                          _FiyatSatiri('Hava Durumu', fiyat!.havaDurumu == 'yagmurlu'
                              ? 'Yagmurlu (+%30)'
                              : 'Normal'),
                          if (fiyat!.geceEkUcret > 0)
                            _FiyatSatiri(
                                'Gece Ek Ucret', '${fiyat!.geceEkUcret.toStringAsFixed(2)} TL'),
                          const Divider(),
                          _FiyatSatiri(
                            'TOPLAM',
                            '${fiyat!.toplamUcret.toStringAsFixed(2)} TL',
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Onayla ve Gönder
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _cagriGonder(
                        ctx,
                        adresController.text,
                        hedefKonum.latitude,
                        hedefKonum.longitude,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                      ),
                      icon: const Icon(Icons.send),
                      label: const Text('ONAYLA VE KURYE CAGIR'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cagriGonder(
      BuildContext ctx, String adres, double lat, double lon) async {
    final response = await _api.post(
      ApiConstants.cagriOlustur,
      body: {
        'hedef_adres': adres,
        'hedef_lat': lat,
        'hedef_lon': lon,
      },
    );

    if (ctx.mounted) Navigator.pop(ctx);

    if (mounted && response.basarili) {
      ApiClient.basariBildirimi('Cagri olusturuldu, kurye aranıyor...');
      _cagrilariYukle();
    }
  }
}

// ─── Alt Widget'lar ───────────────────────────────────

class _DukkanBilgiKarti extends StatelessWidget {
  final Map<String, dynamic>? profil;
  final VoidCallback onProfilOlustur;
  const _DukkanBilgiKarti({this.profil, required this.onProfilOlustur});

  @override
  Widget build(BuildContext context) {
    if (profil == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.store, size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 8),
              const Text('Dukkan profilinizi olusturun'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onProfilOlustur,
                child: const Text('Profil Olustur'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primary.withValues(alpha:0.1),
              child: Icon(Icons.store, color: AppTheme.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profil!['dukkan_adi'] ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          profil!['kategori'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profil!['adres'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AktifCagriKarti extends StatelessWidget {
  final Cagri cagri;
  final LatLng? kuryeKonum;
  final Function(GoogleMapController) onMapOlustur;

  const _AktifCagriKarti({
    required this.cagri,
    this.kuryeKonum,
    required this.onMapOlustur,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Durum başlığı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha:0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.delivery_dining,
                    color: AppTheme.success),
                const SizedBox(width: 8),
                Text(
                  'Aktif: ${cagri.durumMetni}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                  ),
                ),
                const Spacer(),
                Text(
                  '${cagri.toplamUcret.toStringAsFixed(2)} TL',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          // Kurye Takip Haritası
          if (kuryeKonum != null || cagri.durum == 'atandi')
            SizedBox(
              height: 200,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: kuryeKonum ?? const LatLng(37.0, 35.3),
                  zoom: 14,
                ),
                onMapCreated: onMapOlustur,
                markers: {
                  if (kuryeKonum != null)
                    Marker(
                      markerId: const MarkerId('kurye'),
                      position: kuryeKonum!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen),
                      infoWindow: const InfoWindow(title: 'Kurye'),
                    ),
                },
                myLocationEnabled: false,
                zoomControlsEnabled: false,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              cagri.hedefAdres,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _CagriKarti extends StatelessWidget {
  final Cagri cagri;
  const _CagriKarti({required this.cagri});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _durumRengi.withValues(alpha:0.1),
          child: Icon(_durumIkon, color: _durumRengi, size: 20),
        ),
        title: Text(
          cagri.hedefAdres,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${cagri.mesafeKm.toStringAsFixed(1)} km - ${cagri.durumMetni}',
        ),
        trailing: Text(
          '${cagri.toplamUcret.toStringAsFixed(2)} TL',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Color get _durumRengi {
    switch (cagri.durum) {
      case 'tamamlandi':
        return AppTheme.success;
      case 'iptal':
        return AppTheme.error;
      case 'beklemede':
        return AppTheme.warning;
      default:
        return AppTheme.primary;
    }
  }

  IconData get _durumIkon {
    switch (cagri.durum) {
      case 'tamamlandi':
        return Icons.check_circle;
      case 'iptal':
        return Icons.cancel;
      case 'beklemede':
        return Icons.hourglass_bottom;
      default:
        return Icons.delivery_dining;
    }
  }
}

class _FiyatSatiri extends StatelessWidget {
  final String etiket;
  final String deger;
  final bool bold;
  const _FiyatSatiri(this.etiket, this.deger, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiket,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(deger,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 18 : 14)),
        ],
      ),
    );
  }
}
