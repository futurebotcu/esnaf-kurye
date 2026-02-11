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

### Backend
- `backend/.env.example` -> `backend/.env` kopyala
```bash
cd backend
npm ci
node src/migrations/run.js
npm run dev
```

### Flutter
```bash
cd flutter_app
flutter pub get
flutter run
```

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
