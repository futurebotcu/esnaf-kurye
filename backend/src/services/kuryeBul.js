const db = require('../config/database');

/**
 * Esnafın konumuna en yakın müsait kuryeleri bulur
 * PostGIS mesafe sıralamasıyla döndürür
 *
 * @param {number} lat - Esnaf enlem
 * @param {number} lon - Esnaf boylam
 * @param {number} limit - Maksimum kurye sayısı
 * @returns {Array} Yakın kuryeler listesi
 */
async function enYakinKuryeleri(lat, lon, limit = 10) {
  const result = await db.query(
    `SELECT
      k.id,
      k.kullanici_id,
      u.ad,
      u.soyad,
      u.telefon,
      k.arac_tipi,
      k.ortalama_puan,
      k.toplam_teslimat,
      ST_Distance(k.konum, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) / 1000 AS mesafe_km
    FROM kuryeler k
    JOIN kullanicilar u ON u.id = k.kullanici_id
    WHERE k.durum = 'musait'
      AND k.aktif = true
      AND k.konum IS NOT NULL
      AND ST_DWithin(k.konum, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 5000)
    ORDER BY k.konum <-> ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
    LIMIT $3`,
    [lon, lat, limit]
  );

  return result.rows;
}

/**
 * Sıradaki kuryeye bildirim gönderir
 * Zincir mantığı: Ret gelirse bir sonraki kuryeye geçer
 */
async function siraliKuryeBildirimGonder(cagriId, kuryeListesi, sira, io) {
  if (sira >= kuryeListesi.length) {
    // Tüm kuryeler reddetti veya listede kurye kalmadı
    await db.query(
      "UPDATE cagrilar SET durum = 'iptal', iptal_zamani = NOW() WHERE id = $1",
      [cagriId]
    );
    return { basarili: false, mesaj: 'Uygun kurye bulunamadı' };
  }

  const kurye = kuryeListesi[sira];

  // Bildirim kaydı oluştur
  await db.query(
    `INSERT INTO cagri_bildirimleri (cagri_id, kurye_id, sira)
     VALUES ($1, $2, $3)`,
    [cagriId, kurye.id, sira]
  );

  // Çağrı sırasını güncelle
  await db.query(
    'UPDATE cagrilar SET bildirim_sirasi = $1 WHERE id = $2',
    [sira, cagriId]
  );

  // Socket.io ile kuryeye bildirim gönder (çağrı detaylarıyla birlikte)
  if (io) {
    const cagriDetay = await db.query(
      `SELECT c.*, e.dukkan_adi, e.kategori, e.adres as esnaf_adres,
              ST_Distance(k2.konum, c.baslangic_konum) / 1000 AS mesafe_km
       FROM cagrilar c
       JOIN esnaflar e ON e.id = c.esnaf_id
       LEFT JOIN kuryeler k2 ON k2.id = $2
       WHERE c.id = $1`,
      [cagriId, kurye.id]
    );
    const detay = cagriDetay.rows[0] || {};
    io.to(`kurye_${kurye.id}`).emit('yeni_cagri', {
      cagri_id: cagriId,
      dukkan_adi: detay.dukkan_adi,
      kategori: detay.kategori,
      esnaf_adres: detay.esnaf_adres,
      hedef_adres: detay.hedef_adres,
      toplam_ucret: detay.toplam_ucret,
      mesafe_km: detay.mesafe_km,
      mesaj: 'Yeni teslimat çağrısı!',
    });
  }

  return { basarili: true, kurye_id: kurye.id, sira };
}

module.exports = {
  enYakinKuryeleri,
  siraliKuryeBildirimGonder,
};
