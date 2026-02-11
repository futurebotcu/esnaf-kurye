import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../constants/theme.dart';

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _formKey = GlobalKey<FormState>();
  final _telefonController = TextEditingController();
  final _sifreController = TextEditingController();

  @override
  void dispose() {
    _telefonController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  Future<void> _girisYap() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthService>();
    final sonuc = await auth.girisYap(
      telefon: _telefonController.text.trim(),
      sifre: _sifreController.text,
    );

    if (!mounted) return;

    if (sonuc['basarili']) {
      // Ana ekrana yönlendir — rol bazlı
      final hedef = switch (auth.kullanici!.rol) {
        'esnaf' => '/esnaf',
        'kurye' => '/kurye',
        'musteri' => '/musteri',
        _ => '/giris',
      };
      Navigator.pushReplacementNamed(context, hedef);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sonuc['hata'] ?? 'Giriş başarısız'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                // Logo / Başlık
                const Icon(
                  Icons.local_shipping_rounded,
                  size: 80,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Esnaf Kurye',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lojistik Köprüsü',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),

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
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Giriş Butonu
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.yukleniyor ? null : _girisYap,
                    child: auth.yukleniyor
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Giriş Yap'),
                  ),
                ),
                const SizedBox(height: 16),

                // Kayıt ol linki
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/kayit'),
                  child: const Text(
                    'Hesabınız yok mu? Kayıt Olun',
                    style: TextStyle(color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
