import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

/// Harita üzerinde sürüklenebilir marker ile konum seçme widget'ı.
/// Profil oluşturma ve çağrı gönderme dialoglarında kullanılır.
class KonumSecici extends StatefulWidget {
  final LatLng? baslangicKonum;
  final ValueChanged<LatLng> onKonumSecildi;
  final double yukseklik;

  const KonumSecici({
    super.key,
    this.baslangicKonum,
    required this.onKonumSecildi,
    this.yukseklik = 200,
  });

  @override
  State<KonumSecici> createState() => _KonumSeciciState();
}

class _KonumSeciciState extends State<KonumSecici> {
  late LatLng _secilenKonum;
  GoogleMapController? _mapController;
  bool _konumAliniyor = true;
  String? _adresMetni;

  @override
  void initState() {
    super.initState();
    _secilenKonum = widget.baslangicKonum ?? const LatLng(39.9208, 32.8541); // Ankara varsayılan
    _konumBelirle();
  }

  Future<void> _konumBelirle() async {
    if (widget.baslangicKonum != null) {
      setState(() => _konumAliniyor = false);
      _adresCoz(_secilenKonum);
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _konumAliniyor = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _konumAliniyor = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _konumAliniyor = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final yeniKonum = LatLng(position.latitude, position.longitude);
      setState(() {
        _secilenKonum = yeniKonum;
        _konumAliniyor = false;
      });
      widget.onKonumSecildi(yeniKonum);
      _mapController?.animateCamera(CameraUpdate.newLatLng(yeniKonum));
      _adresCoz(yeniKonum);
    } catch (e) {
      debugPrint('Konum alma hatası: $e');
      setState(() => _konumAliniyor = false);
    }
  }

  Future<void> _adresCoz(LatLng konum) async {
    try {
      List<geocoding.Placemark> placemarks =
          await geocoding.placemarkFromCoordinates(
        konum.latitude,
        konum.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        setState(() {
          _adresMetni = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
          ].where((s) => s != null && s.isNotEmpty).join(', ');
        });
      }
    } catch (e) {
      debugPrint('Geocoding hatası: $e');
    }
  }

  void _markerSuruklendi(LatLng yeniKonum) {
    setState(() => _secilenKonum = yeniKonum);
    widget.onKonumSecildi(yeniKonum);
    _adresCoz(yeniKonum);
  }

  void _haritayaTiklandi(LatLng konum) {
    setState(() => _secilenKonum = konum);
    widget.onKonumSecildi(konum);
    _adresCoz(konum);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: widget.yukseklik,
            child: _konumAliniyor
                ? Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Konum alınıyor...'),
                        ],
                      ),
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _secilenKonum,
                      zoom: 15,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    onTap: _haritayaTiklandi,
                    markers: {
                      Marker(
                        markerId: const MarkerId('secilen'),
                        position: _secilenKonum,
                        draggable: true,
                        onDragEnd: _markerSuruklendi,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                      ),
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                  ),
          ),
        ),
        const SizedBox(height: 8),
        // Koordinat ve adres bilgisi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pin_drop, size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Text(
                    '${_secilenKonum.latitude.toStringAsFixed(5)}, ${_secilenKonum.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              if (_adresMetni != null) ...[
                const SizedBox(height: 4),
                Text(
                  _adresMetni!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
