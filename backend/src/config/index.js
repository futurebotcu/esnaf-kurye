require('dotenv').config();

// Zorunlu ortam değişkenleri kontrolü
if (!process.env.JWT_SECRET) {
  console.error('HATA: JWT_SECRET ortam değişkeni tanımlanmamış!');
  console.error('.env dosyanızda JWT_SECRET ayarlayın.');
  process.exit(1);
}

if (!process.env.DB_PASSWORD && process.env.NODE_ENV === 'production') {
  console.error('HATA: Üretim ortamında DB_PASSWORD zorunludur!');
  process.exit(1);
}

// CORS whitelist: virgülle ayrılmış origin'ler
// - env tanımsız → null (dev'de serbest, prod'da boot fail)
// - env boş/whitespace → [] (hiçbir origin'e izin yok)
// - env dolu → trim + boş eleman filtresi
const corsOrigins = process.env.CORS_ORIGINS != null
  ? process.env.CORS_ORIGINS.split(',').map(s => s.trim()).filter(Boolean)
  : null;

const nodeEnv = process.env.NODE_ENV || 'development';

// Production'da CORS_ORIGINS zorunlu
if (nodeEnv === 'production' && (!corsOrigins || corsOrigins.length === 0)) {
  console.error('HATA: Üretim ortamında CORS_ORIGINS zorunludur!');
  console.error('Örnek: CORS_ORIGINS=https://app.example.com,https://admin.example.com');
  process.exit(1);
}

module.exports = {
  port: parseInt(process.env.PORT) || 3000,
  nodeEnv,
  corsOrigins,
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  },
  fiyatlandirma: {
    kmBasi: parseFloat(process.env.FIYAT_KM_BASI) || 5.0,
    yagmurCarpani: parseFloat(process.env.FIYAT_YAGMUR_CARPANI) || 1.3,
    geceEkUcret: parseFloat(process.env.FIYAT_GECE_EK_UCRET) || 15.0,
    geceBaslangic: parseInt(process.env.FIYAT_GECE_BASLANGIC) || 22,
    minUcret: parseFloat(process.env.FIYAT_MIN_UCRET) || 20.0,
  },
  weatherApiKey: process.env.WEATHER_API_KEY || '',
};
