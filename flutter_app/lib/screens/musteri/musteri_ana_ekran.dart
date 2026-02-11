import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../services/api_client.dart';
import '../../constants/api.dart';
import '../../constants/theme.dart';
import '../../models/esnaf.dart';
import '../../models/cagri.dart';

class MusteriAnaEkran extends StatefulWidget {
  const MusteriAnaEkran({super.key});

  @override
  State<MusteriAnaEkran> createState() => _MusteriAnaEkranState();
}

class _MusteriAnaEkranState extends State<MusteriAnaEkran> {
  GoogleMapController? _mapController;
  LatLng? _musteriKonum;
  String _adresMetni = 'Konum alınıyor...';
  List<EsnafBilgi> _esnaflar = [];
  Cagri? _aktifCagri;
  LatLng? _kuryeKonum;
  bool _yukleniyor = true;
  late final ApiClient _api;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(context.read<AuthService>());
    _basla();
    _socketDinle();
  }

  Future<void> _basla() async {
    await _konumAl();
    if (_musteriKonum != null) {
      await Future.wait([
        _adresCevir(),
        _esnaflariYukle(),
        _aktifCagriKontrol(),
      ]);
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _konumAl() async {
    try {
      LocationPermission izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin == LocationPermission.denied ||
          izin == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _adresMetni = 'Konum izni reddedildi');
        }
        return;
      }

      final pozisyon = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _musteriKonum = LatLng(pozisyon.latitude, pozisyon.longitude);
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_musteriKonum!, 14),
        );
      }
    } catch (e) {
      debugPrint('Konum hatası: $e');
      if (mounted) setState(() => _adresMetni = 'Konum alınamadı');
    }
  }

  Future<void> _adresCevir() async {
    if (_musteriKonum == null) return;
    try {
      final placemarks = await placemarkFromCoordinates(
        _musteriKonum!.latitude,
        _musteriKonum!.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        setState(() {
          _adresMetni = [p.thoroughfare, p.subLocality, p.locality]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');
          if (_adresMetni.isEmpty) _adresMetni = 'Konum bulundu';
        });
      }
    } catch (e) {
      debugPrint('Geocoding hatası: $e');
    }
  }

  Future<void> _esnaflariYukle() async {
    if (_musteriKonum == null) return;
    final response = await _api.get(
      ApiConstants.cevredekiEsnaflar(
        _musteriKonum!.latitude,
        _musteriKonum!.longitude,
      ),
    );
    if (response.basarili && response.data != null && mounted) {
      setState(() {
        _esnaflar = (response.data['esnaflar'] as List)
            .map((e) => EsnafBilgi.fromJson(e))
            .toList();
      });
    }
  }

  Future<void> _aktifCagriKontrol() async {
    final response = await _api.get(ApiConstants.musteriAktifCagri);
    if (response.basarili && response.data != null && mounted) {
      final cagriData = response.data['cagri'];
      setState(() {
        _aktifCagri = cagriData != null ? Cagri.fromJson(cagriData) : null;
      });
    }
  }

  void _socketDinle() {
    final socket = context.read<SocketService>();
    final auth = context.read<AuthService>();

    if (!socket.bagli && auth.token != null) {
      socket.baglan(auth.token!);
    }

    socket.dinle('kurye:konum', (data) {
      if (mounted) {
        setState(() {
          _kuryeKonum = LatLng(
            (data['lat'] as num).toDouble(),
            (data['lon'] as num).toDouble(),
          );
        });
      }
    });

    socket.dinle('teslim_tamamlandi', (data) {
      if (mounted) {
        final cagriId = data['cagri_id'];
        setState(() {
          _aktifCagri = null;
          _kuryeKonum = null;
        });
        _puanlamaDialogGoster(cagriId);
      }
    });
  }

  Set<Marker> get _markerlar {
    final markers = <Marker>{};

    // Müşteri konumu (mavi)
    if (_musteriKonum != null) {
      markers.add(Marker(
        markerId: const MarkerId('musteri'),
        position: _musteriKonum!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Konumunuz'),
      ));
    }

    // Esnaflar (turuncu)
    for (final esnaf in _esnaflar) {
      markers.add(Marker(
        markerId: MarkerId('esnaf_${esnaf.id}'),
        position: LatLng(esnaf.lat, esnaf.lon),
        icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onTap: () => _esnafDetayGoster(esnaf),
      ));
    }

    // Kurye (yeşil)
    if (_kuryeKonum != null) {
      markers.add(Marker(
        markerId: const MarkerId('kurye'),
        position: _kuryeKonum!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Kurye'),
      ));
    }

    return markers;
  }

  void _esnafDetayGoster(EsnafBilgi esnaf) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.accent.withValues(alpha:0.1),
                  child:
                      const Icon(Icons.store, color: AppTheme.accent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esnaf.dukkanAdi,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          esnaf.kategori,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Puan
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  esnaf.ortalamaPuan > 0
                      ? esnaf.ortalamaPuan.toStringAsFixed(1)
                      : 'Henüz puan yok',
                  style: const TextStyle(fontSize: 15),
                ),
                if (esnaf.mesafeMetre != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.location_on,
                      color: AppTheme.textSecondary, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    esnaf.mesafeMetni,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Adres
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place,
                    color: AppTheme.textSecondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    esnaf.adres,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _puanlamaDialogGoster(String cagriId) {
    int seciliPuan = 0;
    final yorumController = TextEditingController();
    bool gonderiliyor = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Teslimat Tamamlandı!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Kuryeyi puanlayın:'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final yildiz = i + 1;
                  return IconButton(
                    onPressed: () =>
                        setDialogState(() => seciliPuan = yildiz),
                    icon: Icon(
                      yildiz <= seciliPuan ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yorumController,
                decoration: const InputDecoration(
                  labelText: 'Yorum (isteğe bağlı)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Geç'),
            ),
            ElevatedButton(
              onPressed: gonderiliyor || seciliPuan == 0
                  ? null
                  : () async {
                      setDialogState(() => gonderiliyor = true);
                      final response = await _api.post(
                        ApiConstants.musteriPuanla,
                        body: {
                          'cagri_id': cagriId,
                          'puan': seciliPuan,
                          'yorum': yorumController.text,
                        },
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (response.basarili) {
                        ApiClient.basariBildirimi('Puanlama kaydedildi!');
                      }
                    },
              child: Text(gonderiliyor ? 'Gönderiliyor...' : 'GÖNDER'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    final socket = context.read<SocketService>();
    socket.dinlemeyi_birak('kurye:konum');
    socket.dinlemeyi_birak('teslim_tamamlandi');
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.location_on, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _adresMetni,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _yukleniyor = true);
              _basla();
            },
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
                // Harita (üst kısım)
                Expanded(
                  flex: 3,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _musteriKonum ?? const LatLng(39.9208, 32.8541),
                      zoom: 14,
                    ),
                    onMapCreated: (controller) =>
                        _mapController = controller,
                    markers: _markerlar,
                    myLocationEnabled: false,
                    zoomControlsEnabled: true,
                  ),
                ),
                // Alt panel
                Expanded(
                  flex: 2,
                  child: _aktifCagri != null
                      ? _AktifCagriPaneli(
                          cagri: _aktifCagri!,
                          kuryeKonum: _kuryeKonum,
                        )
                      : _EsnafListePaneli(
                          esnaflar: _esnaflar,
                          onEsnafTap: _esnafDetayGoster,
                        ),
                ),
              ],
            ),
    );
  }
}

// ─── Alt Widget'lar ───────────────────────────────────

class _AktifCagriPaneli extends StatelessWidget {
  final Cagri cagri;
  final LatLng? kuryeKonum;

  const _AktifCagriPaneli({required this.cagri, this.kuryeKonum});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Durum başlığı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppTheme.success.withValues(alpha:0.1),
            child: Row(
              children: [
                const Icon(Icons.delivery_dining, color: AppTheme.success),
                const SizedBox(width: 8),
                Text(
                  'Aktif Teslimat: ${cagri.durumMetni}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cagri.dukkanAdi != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.store,
                            color: AppTheme.accent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          cagri.dukkanAdi!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: AppTheme.textSecondary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cagri.hedefAdres,
                          style: const TextStyle(color: AppTheme.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (cagri.kuryeAd != null)
                    Row(
                      children: [
                        const Icon(Icons.person,
                            color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Kurye: ${cagri.kuryeAd} ${cagri.kuryeSoyad ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${cagri.mesafeKm.toStringAsFixed(1)} km',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      Text(
                        '${cagri.toplamUcret.toStringAsFixed(2)} TL',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EsnafListePaneli extends StatelessWidget {
  final List<EsnafBilgi> esnaflar;
  final Function(EsnafBilgi) onEsnafTap;

  const _EsnafListePaneli({
    required this.esnaflar,
    required this.onEsnafTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Çevredeki Esnaflar (${esnaflar.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: esnaflar.isEmpty
                ? const Center(
                    child: Text(
                      'Yakında esnaf bulunamadı',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: esnaflar.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final esnaf = esnaflar[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.accent.withValues(alpha:0.1),
                          child: const Icon(Icons.store,
                              color: AppTheme.accent, size: 20),
                        ),
                        title: Text(
                          esnaf.dukkanAdi,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Row(
                          children: [
                            Text(esnaf.kategori),
                            if (esnaf.ortalamaPuan > 0) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 14),
                              Text(
                                ' ${esnaf.ortalamaPuan.toStringAsFixed(1)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                        trailing: Text(
                          esnaf.mesafeMetni,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        onTap: () => onEsnafTap(esnaf),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
