import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../constants/theme.dart';

class KayitEkrani extends StatefulWidget {
  const KayitEkrani({super.key});

  @override
  State<KayitEkrani> createState() => _KayitEkraniState();
}

class _KayitEkraniState extends State<KayitEkrani> {
  final _formKey = GlobalKey<FormState>();
  final _adController = TextEditingController();
  final _soyadController = TextEditingController();
  final _telefonController = TextEditingController();
  final _sifreController = TextEditingController();
  String _seciliRol = 'esnaf';

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _telefonController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  Future<void> _kayitOl() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthService>();
    final sonuc = await auth.kayitOl(
      telefon: _telefonController.text.trim(),
      sifre: _sifreController.text,
      ad: _adController.text.trim(),
      soyad: _soyadController.text.trim(),
      rol: _seciliRol,
    );

    if (!mounted) return;

    if (sonuc['basarili']) {
      final hedef = switch (_seciliRol) {
        'esnaf' => '/esnaf',
        'kurye' => '/kurye',
        'musteri' => '/musteri',
        _ => '/giris',
      };
      Navigator.pushReplacementNamed(context, hedef);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sonuc['hata'] ?? 'Kayıt başarısız'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Rol Seçimi
              const Text(
                'Hesap Türü',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _RolSecimKarti(
                      baslik: 'Esnaf',
                      ikon: Icons.store,
                      secili: _seciliRol == 'esnaf',
                      onTap: () => setState(() => _seciliRol = 'esnaf'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RolSecimKarti(
                      baslik: 'Kurye',
                      ikon: Icons.delivery_dining,
                      secili: _seciliRol == 'kurye',
                      onTap: () => setState(() => _seciliRol = 'kurye'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RolSecimKarti(
                      baslik: 'Müşteri',
                      ikon: Icons.person,
                      secili: _seciliRol == 'musteri',
                      onTap: () => setState(() => _seciliRol = 'musteri'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Ad
              TextFormField(
                controller: _adController,
                decoration: const InputDecoration(
                  labelText: 'Ad',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ad gerekli' : null,
              ),
              const SizedBox(height: 16),

              // Soyad
              TextFormField(
                controller: _soyadController,
                decoration: const InputDecoration(
                  labelText: 'Soyad',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Soyad gerekli' : null,
              ),
              const SizedBox(height: 16),

              // Telefon
              TextFormField(
                controller: _telefonController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefon Numarası',
                  hintText: '05XX XXX XXXX',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Telefon gerekli';
                  if (v.trim().length < 10) return 'Geçerli bir numara girin';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Şifre
              TextFormField(
                controller: _sifreController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Şifre gerekli';
                  if (v.length < 6) return 'En az 6 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Kayıt Butonu
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: auth.yukleniyor ? null : _kayitOl,
                  child: auth.yukleniyor
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Kayıt Ol'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolSecimKarti extends StatelessWidget {
  final String baslik;
  final IconData ikon;
  final bool secili;
  final VoidCallback onTap;

  const _RolSecimKarti({
    required this.baslik,
    required this.ikon,
    required this.secili,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: secili ? AppTheme.primary.withValues(alpha: 0.1) : Colors.white,
          border: Border.all(
            color: secili ? AppTheme.primary : Colors.grey.shade300,
            width: secili ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(ikon,
                size: 40,
                color: secili ? AppTheme.primary : AppTheme.textSecondary),
            const SizedBox(height: 8),
            Text(
              baslik,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: secili ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
