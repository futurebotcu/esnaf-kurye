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
flutter run -d chrome   # Web
flutter run              # Mobil
```

## Testler
```bash
cd backend && npm test
cd flutter_app && flutter test
cd flutter_app && flutter analyze
```

## Guvenlik
- `.env` dosyalari `.gitignore` ile korunur ve asla commit edilmez.
- `JWT_SECRET` ayarlanmadan sunucu baslamaz.
- Production'da `CORS_ORIGINS` zorunludur.
- Pre-commit hook secret leak'leri engeller.

## CI/CD
GitHub Actions: `.github/workflows/ci.yml`

## API Endpointleri
| Method | Endpoint | Aciklama |
|--------|----------|----------|
| POST | /api/auth/kayit | Yeni kullanici kaydi |
| POST | /api/auth/giris | Giris |
| GET | /api/esnaf/profil | Esnaf profili |
| POST | /api/esnaf/cagri | Teslimat cagrisi olustur |
| GET | /api/kurye/aktif-cagri | Kurye aktif cagrisi |
| POST | /api/kurye/cagri-kabul | Cagri kabul et |
| GET | /api/musteri/cevredeki-esnaflar | 5km icindeki esnaflar |
| GET | /api/musteri/aktif-cagri | Musteri aktif cagrisi |
| POST | /api/musteri/puanla | Teslimat puanla |
