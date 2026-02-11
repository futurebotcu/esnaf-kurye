const axios = require('axios');
const config = require('../config');

/**
 * Dinamik Fiyatlandırma Motoru
 *
 * Hesaplama: (Mesafe x KM Birim Fiyat) x Hava Çarpanı + Gece Ek Ücreti
 *
 * - Mesafe: KM başına sabit ücret
 * - Hava: Yağmurlu havada %30 zam (çarpan: 1.30)
 * - Gece: 22:00 sonrası sabit ek ücret
 */

/**
 * İki koordinat arası mesafeyi Haversine formülü ile hesaplar (km)
 */
function mesafeHesapla(lat1, lon1, lat2, lon2) {
  const R = 6371; // Dünya yarıçapı (km)
  const dLat = dereceyiRadyana((lat2 - lat1));
  const dLon = dereceyiRadyana((lon2 - lon1));
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(dereceyiRadyana(lat1)) * Math.cos(dereceyiRadyana(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function dereceyiRadyana(derece) {
  return derece * (Math.PI / 180);
}

/**
 * Hava durumu bilgisini OpenWeatherMap API'den çeker
 * Yağmur varsa çarpan 1.30, yoksa 1.00
 */
async function havaDurumuCarpaniGetir(lat, lon) {
  try {
    if (!config.weatherApiKey) {
      // API key yoksa varsayılan normal hava döndür
      return { carpan: 1.0, durum: 'bilinmiyor' };
    }

    const url = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&appid=${config.weatherApiKey}`;
    const response = await axios.get(url, { timeout: 5000 });
    const weatherId = response.data.weather[0].id;

    // OpenWeatherMap: 2xx = Fırtına, 3xx = Çisenti, 5xx = Yağmur, 6xx = Kar
    if (weatherId >= 200 && weatherId < 700) {
      return {
        carpan: config.fiyatlandirma.yagmurCarpani,
        durum: 'yagmurlu',
      };
    }

    return { carpan: 1.0, durum: 'normal' };
  } catch (error) {
    console.error('Hava durumu API hatası:', error.message);
    return { carpan: 1.0, durum: 'bilinmiyor' };
  }
}

/**
 * Gece saati kontrolü - 22:00 sonrası ek ücret
 */
function geceEkUcretiHesapla() {
  const saat = new Date().getHours();
  if (saat >= config.fiyatlandirma.geceBaslangic || saat < 6) {
    return config.fiyatlandirma.geceEkUcret;
  }
  return 0;
}

/**
 * ANA FONKSİYON: Toplam ücreti hesaplar
 *
 * @param {number} baslatLat - Başlangıç enlem
 * @param {number} baslatLon - Başlangıç boylam
 * @param {number} hedefLat - Hedef enlem
 * @param {number} hedefLon - Hedef boylam
 * @returns {Object} Fiyat detayları
 */
async function ucretHesapla(baslatLat, baslatLon, hedefLat, hedefLon) {
  // 1. Mesafe hesapla
  const mesafeKm = mesafeHesapla(baslatLat, baslatLon, hedefLat, hedefLon);
  const yuvarlanmisMesafe = Math.round(mesafeKm * 100) / 100;

  // 2. Baz ücret
  const bazUcret = yuvarlanmisMesafe * config.fiyatlandirma.kmBasi;

  // 3. Hava durumu çarpanı
  const havaDurumu = await havaDurumuCarpaniGetir(baslatLat, baslatLon);

  // 4. Gece ek ücreti
  const geceEk = geceEkUcretiHesapla();

  // 5. Toplam hesapla
  let toplamUcret = (bazUcret * havaDurumu.carpan) + geceEk;

  // Minimum ücret kontrolü
  toplamUcret = Math.max(toplamUcret, config.fiyatlandirma.minUcret);

  // Yuvarla (2 ondalık)
  toplamUcret = Math.round(toplamUcret * 100) / 100;

  return {
    mesafe_km: yuvarlanmisMesafe,
    baz_ucret: Math.round(bazUcret * 100) / 100,
    hava_durumu: havaDurumu.durum,
    hava_carpani: havaDurumu.carpan,
    gece_ek_ucret: geceEk,
    toplam_ucret: toplamUcret,
    hesaplama_zamani: new Date().toISOString(),
  };
}

module.exports = {
  ucretHesapla,
  mesafeHesapla,
  havaDurumuCarpaniGetir,
  geceEkUcretiHesapla,
};
