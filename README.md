# Esnaf Kurye - Lojistik Koprusu

Yerel esnaflar ile kuryeler arasinda canli teslimat yonetimi saglayan full-stack platform.

## Roller
- **Esnaf**: Dukkan profili olusturma, teslimat cagrisi gonderme, kurye takibi
- **Kurye**: Cagri bildirimi alma, teslimat kabul/red, konum paylasimi
- **Musteri**: Cevredeki esnaflari haritada gorme, canli kurye takibi, puanlama

## Teknoloji
| Katman | Teknoloji |
|--------|-----------|
| Frontend | Flutter (Android, iOS, Web) |
| Backend | Node.js, Express, Socket.io |
| Veritabani | PostgreSQL + PostGIS |
| Harita | Google Maps (Flutter) + Geolocator |
| Auth | JWT + bcrypt |

## Proje yapisi
- `backend/` : Node.js API + Socket.io
- `flutter_app/` : Flutter uygulamasi

## Kurulum

### Gereksinimler

- Node.js 20+
- PostgreSQL 15+ (PostGIS extension)
- Flutter SDK 3.x
- Google Maps API Key

### Backend

```bash
cd backend
cp .env.example .env
# .env dosyasini duzenleyin (JWT_SECRET, DB_PASSWORD, WEATHER_API_KEY)
npm install
npm run migrate
npm start
```

**Onemli:** `JWT_SECRET` ayarlanmazsa sunucu baslamaz.

### Flutter

```bash
cd flutter_app
flutter pub get

# Web icin: flutter_app/web/index.html dosyasinda
# YOUR_GOOGLE_MAPS_API_KEY yerine gercek API key yazin

flutter run -d chrome   # Web
flutter run              # Mobil
```

### Google Maps API Key

1. [Google Cloud Console](https://console.cloud.google.com/apis/credentials) adresine gidin
2. Maps JavaScript API ve Maps SDK for Android/iOS etkinlestirin
3. API key olusturun
4. `flutter_app/web/index.html` dosyasinda `YOUR_GOOGLE_MAPS_API_KEY` yerine yazin
5. Android: `android/app/src/main/AndroidManifest.xml`
6. iOS: `ios/Runner/AppDelegate.swift`

## Test ve kalite
```bash
cd backend
npm test
npm audit --audit-level=high
cd ../flutter_app
flutter analyze --no-fatal-infos
flutter test
```

## Guvenlik
- `.env` dosyalari `.gitignore` ile korunur ve asla commit edilmez.
- `backend/.env.example` sablondur, gercek deger icermez.
- `JWT_SECRET` ayarlanmadan sunucu baslamaz.
- Production'da `CORS_ORIGINS` ayarlanmalidir.
- Pre-commit hook staged dosyalarda olasi secret leak pattern'lerini bloklar.

## CI/CD
GitHub Actions workflow: `.github/workflows/ci.yml`
