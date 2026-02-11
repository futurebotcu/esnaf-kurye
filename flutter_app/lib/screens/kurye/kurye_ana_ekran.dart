import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../services/api_client.dart';
import '../../constants/api.dart';
import '../../constants/theme.dart';
import '../../models/cagri.dart';

class KuryeAnaEkran extends StatefulWidget {
  const KuryeAnaEkran({super.key});

  @override
  State<KuryeAnaEkran> createState() => _KuryeAnaEkranState();
}

class _KuryeAnaEkranState extends State<KuryeAnaEkran> {
  bool _musait = false;
  List<Cagri> _bekleyenCagrilar = [];
  Cagri? _aktifCagri;
  GoogleMapController? _mapController;
  LatLng _mevcutKonum = const LatLng(37.0, 35.3); // Varsayılan
  Timer? _konumTimer;
  bool _yukleniyor = true;

  late final ApiClient _api = ApiClient(context.read<AuthService>());

  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _baslat();
  }

  Future<void> _baslat() async {
    await _konumIzniAl();
    _socketBaglan();
    await _cagrilariYukle();
    _konumTakibiBaslat();
    setState(() => _yukleniyor = false);
  }

  Future<void> _konumIzniAl() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _mevcutKonum = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('Konum alma hatası: $e');
    }
  }

  void _konumTakibiBaslat() {
    // Her 5 saniyede konum gönder
    _konumTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_musait && _aktifCagri == null) return;

      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        setState(() {
          _mevcutKonum = LatLng(position.latitude, position.longitude);
        });

        // Socket ile konum gönder
        final socket = context.read<SocketService>();
        socket.konumGonder(position.latitude, position.longitude);

        // REST API ile de güncelle
        await _api.put(
          ApiConstants.kuryeKonum,
          body: {
            'lat': position.latitude,
            'lon': position.longitude,
          },
        );
      } catch (e) {
        debugPrint('Konum güncelleme hatası: $e');
      }
    });
  }

  void _socketBaglan() {
    final socket = context.read<SocketService>();
    final auth = context.read<AuthService>();

    if (!socket.bagli && auth.token != null) {
      socket.baglan(auth.token!);
    }

    // Yeni çağrı bildirimi - tam ekran dialog
    socket.dinle('yeni_cagri', (data) {
      if (mounted) {
        _cagrilariYukle();
        _yeniCagriBildirimDialog(data);
      }
    });
  }

  void _yeniCagriBildirimDialog(dynamic data) {
    final cagriId = data['cagri_id']?.toString() ?? '';
    final dukkanAdi = data['dukkan_adi']?.toString() ?? 'Esnaf';
    final kategori = data['kategori']?.toString();
    final esnafAdres = data['esnaf_adres']?.toString() ?? '';
    final hedefAdres = data['hedef_adres']?.toString() ?? '';
    final toplamUcret = (data['toplam_ucret'] as num?)?.toDouble() ?? 0;
    final mesafeKm = (data['mesafe_km'] as num?)?.toDouble();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delivery_dining, color: AppTheme.accent, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Yeni Teslimat Cagrisi!'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dükkan bilgisi
            Row(
              children: [
                const Icon(Icons.store, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dukkanAdi,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (kategori != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      kategori,
                      style: TextStyle(fontSize: 12, color: AppTheme.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Adres bilgileri
            if (esnafAdres.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.storefront, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Alış: $esnafAdres',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (hedefAdres.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 16, color: AppTheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Teslimat: $hedefAdres',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            // Mesafe ve ücret
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (mesafeKm != null)
                  Column(
                    children: [
                      const Icon(Icons.straighten, color: AppTheme.primary),
                      const SizedBox(height: 4),
                      Text(
                        '${mesafeKm.toStringAsFixed(1)} km',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Mesafe', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                Column(
                  children: [
                    const Icon(Icons.payments, color: AppTheme.success),
                    const SizedBox(height: 4),
                    Text(
                      '${toplamUcret.toStringAsFixed(2)} TL',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.accent,
                      ),
                    ),
                    Text('Ucret', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          SizedBox(
            width: 130,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                if (cagriId.isNotEmpty) _cagriReddet(cagriId);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
              ),
              icon: const Icon(Icons.close),
              label: const Text('REDDET'),
            ),
          ),
          SizedBox(
            width: 130,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                if (cagriId.isNotEmpty) _cagriKabul(cagriId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
              ),
              icon: const Icon(Icons.check),
              label: const Text('KABUL ET'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cagrilariYukle() async {
    final response = await _api.get(ApiConstants.aktifCagrilar);
    if (response.basarili && response.data != null) {
      setState(() {
        _bekleyenCagrilar = (response.data['cagrilar'] as List)
            .map((c) => Cagri.fromJson(c))
            .toList();
        _markerGuncelle();
      });
    }
  }

  void _markerGuncelle() {
    _markers.clear();
    // Kendi konumum
    _markers.add(
      Marker(
        markerId: const MarkerId('ben'),
        position: _mevcutKonum,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Konumum'),
      ),
    );
    // Esnaf çağrıları - gerçek esnaf konumunu kullan
    for (var cagri in _bekleyenCagrilar) {
      final esnafKonum = (cagri.esnafLat != null && cagri.esnafLon != null)
          ? LatLng(cagri.esnafLat!, cagri.esnafLon!)
          : _mevcutKonum;
      _markers.add(
        Marker(
          markerId: MarkerId(cagri.id),
          position: esnafKonum,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: cagri.dukkanAdi ?? 'Esnaf',
            snippet: '${cagri.toplamUcret.toStringAsFixed(2)} TL',
          ),
        ),
      );
    }
  }

  Future<void> _durumDegistir(bool yeniDurum) async {
    final response = await _api.put(
      ApiConstants.kuryeDurum,
      body: {'durum': yeniDurum ? 'musait' : 'cevrimdisi'},
    );
    if (response.basarili) {
      setState(() => _musait = yeniDurum);
      if (yeniDurum) _cagrilariYukle();
    }
  }

  Future<void> _cagriKabul(String cagriId) async {
    final response = await _api.post(ApiConstants.cagriKabul(cagriId));
    if (response.basarili) {
      setState(() {
        _aktifCagri = _bekleyenCagrilar.firstWhere((c) => c.id == cagriId);
        _bekleyenCagrilar.removeWhere((c) => c.id == cagriId);
      });
      ApiClient.basariBildirimi('Cagri kabul edildi!');
    }
  }

  Future<void> _cagriReddet(String cagriId) async {
    await _api.post(ApiConstants.cagriReddet(cagriId));
    setState(() {
      _bekleyenCagrilar.removeWhere((c) => c.id == cagriId);
    });
  }

  Future<void> _teslimAldim() async {
    if (_aktifCagri == null) return;
    final response = await _api.put(ApiConstants.teslimAldim(_aktifCagri!.id));
    if (response.basarili) {
      ApiClient.basariBildirimi('Teslim alindi olarak isaretlendi');
      _cagrilariYukle();
    }
  }

  Future<void> _teslimEttim() async {
    if (_aktifCagri == null) return;

    // Ödeme yöntemi seç
    final odemeYontemi = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odeme Yontemi'),
        content: const Text('Musteri nasıl odeme yaptı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'nakit'),
            child: const Text('Nakit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'sanal_pos'),
            child: const Text('Sanal POS'),
          ),
        ],
      ),
    );

    if (odemeYontemi == null) return;

    final response = await _api.put(
      ApiConstants.teslimEttim(_aktifCagri!.id),
      body: {'odeme_yontemi': odemeYontemi},
    );
    if (response.basarili) {
      setState(() => _aktifCagri = null);
      ApiClient.basariBildirimi('Teslimat tamamlandı!');
      _cagrilariYukle();
    }
  }

  @override
  void dispose() {
    _konumTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kurye Paneli'),
        actions: [
          // Müsaitlik Switch'i
          Row(
            children: [
              Text(
                _musait ? 'Musait' : 'Kapalı',
                style: const TextStyle(fontSize: 14),
              ),
              Switch(
                value: _musait,
                onChanged: _aktifCagri != null ? null : _durumDegistir,
                activeThumbColor: Colors.white,
                activeTrackColor: AppTheme.success,
              ),
            ],
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
          : Column(
              children: [
                // Harita
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _mevcutKonum,
                          zoom: 14,
                        ),
                        onMapCreated: (controller) =>
                            _mapController = controller,
                        markers: _markers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                      ),
                      // Durum göstergesi
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _musait ? AppTheme.success : Colors.grey,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _musait ? 'MUSAIT' : 'CEVRIMDISI',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Alt Panel - Çağrılar veya Aktif Teslimat
                Expanded(
                  flex: 2,
                  child: _aktifCagri != null
                      ? _AktifTeslimatPaneli(
                          cagri: _aktifCagri!,
                          onTeslimAldim: _teslimAldim,
                          onTeslimEttim: _teslimEttim,
                        )
                      : _BekleyenCagrilarPaneli(
                          cagrilar: _bekleyenCagrilar,
                          musait: _musait,
                          onKabul: _cagriKabul,
                          onReddet: _cagriReddet,
                        ),
                ),
              ],
            ),
    );
  }
}

// ─── Aktif Teslimat Paneli ──────────────────────────────

class _AktifTeslimatPaneli extends StatelessWidget {
  final Cagri cagri;
  final VoidCallback onTeslimAldim;
  final VoidCallback onTeslimEttim;

  const _AktifTeslimatPaneli({
    required this.cagri,
    required this.onTeslimAldim,
    required this.onTeslimEttim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping,
                    color: AppTheme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aktif Teslimat',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.accent,
                      ),
                    ),
                    Text(
                      cagri.durumMetni,
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                '${cagri.toplamUcret.toStringAsFixed(2)} TL',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Adres
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppTheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cagri.hedefAdres,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Aksiyon Butonları
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: cagri.durum == 'atandi' ? onTeslimAldim : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    icon: const Icon(Icons.inventory_2),
                    label: const Text('TESLIM ALDIM'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: cagri.durum == 'teslim_alindi'
                        ? onTeslimEttim
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('TESLIM ETTIM'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Bekleyen Çağrılar Paneli ───────────────────────────

class _BekleyenCagrilarPaneli extends StatelessWidget {
  final List<Cagri> cagrilar;
  final bool musait;
  final Function(String) onKabul;
  final Function(String) onReddet;

  const _BekleyenCagrilarPaneli({
    required this.cagrilar,
    required this.musait,
    required this.onKabul,
    required this.onReddet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Gelen Cagrilar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${cagrilar.length} adet',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!musait)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Cagri almak icin "Musait" durumuna gecin',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else if (cagrilar.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bekleyen cagri yok',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: cagrilar.length,
                itemBuilder: (ctx, i) {
                  final cagri = cagrilar[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.store,
                                  color: AppTheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                cagri.dukkanAdi ?? 'Esnaf',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              if (cagri.kategori != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.primaryLight.withValues(alpha:0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    cagri.kategori!,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primary),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                '${cagri.toplamUcret.toStringAsFixed(2)} TL',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cagri.hedefAdres,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${cagri.mesafeKm.toStringAsFixed(1)} km',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => onReddet(cagri.id),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.error,
                                    side: const BorderSide(
                                        color: AppTheme.error),
                                  ),
                                  child: const Text('REDDET'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => onKabul(cagri.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.success,
                                  ),
                                  child: const Text('KABUL ET'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
