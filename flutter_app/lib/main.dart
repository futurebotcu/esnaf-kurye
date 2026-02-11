import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'constants/theme.dart';
import 'services/auth_service.dart';
import 'services/socket_service.dart';
import 'services/api_client.dart';
import 'screens/auth/giris_ekrani.dart';
import 'screens/auth/kayit_ekrani.dart';
import 'screens/esnaf/esnaf_ana_ekran.dart';
import 'screens/kurye/kurye_ana_ekran.dart';
import 'screens/musteri/musteri_ana_ekran.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EsnafKuryeApp());
}

class EsnafKuryeApp extends StatelessWidget {
  const EsnafKuryeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SocketService()),
      ],
      child: MaterialApp(
        title: 'Esnaf Kurye',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        scaffoldMessengerKey: ApiClient.scaffoldMessengerKey,
        navigatorKey: ApiClient.navigatorKey,
        home: const BaslangicEkrani(),
        routes: {
          '/giris': (_) => const GirisEkrani(),
          '/kayit': (_) => const KayitEkrani(),
          '/esnaf': (_) => const EsnafAnaEkran(),
          '/kurye': (_) => const KuryeAnaEkran(),
          '/musteri': (_) => const MusteriAnaEkran(),
        },
      ),
    );
  }
}

/// Uygulama başlangıcında token kontrolü yaparak
/// doğru ekrana yönlendiren widget
class BaslangicEkrani extends StatefulWidget {
  const BaslangicEkrani({super.key});

  @override
  State<BaslangicEkrani> createState() => _BaslangicEkraniState();
}

class _BaslangicEkraniState extends State<BaslangicEkrani> {
  @override
  void initState() {
    super.initState();
    _oturumKontrol();
  }

  Future<void> _oturumKontrol() async {
    final auth = context.read<AuthService>();
    await auth.baslangicKontrol();

    if (!mounted) return;

    if (auth.girisYapildi) {
      final hedef = switch (auth.kullanici!.rol) {
        'esnaf' => '/esnaf',
        'kurye' => '/kurye',
        'musteri' => '/musteri',
        _ => '/giris',
      };
      Navigator.pushReplacementNamed(context, hedef);
    } else {
      Navigator.pushReplacementNamed(context, '/giris');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_rounded,
              size: 80,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 16),
            const Text(
              'Esnaf Kurye',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
