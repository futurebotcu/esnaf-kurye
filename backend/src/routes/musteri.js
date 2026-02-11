const express = require('express');
const Joi = require('joi');
const db = require('../config/database');
const { authMiddleware, rolKontrol } = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);
router.use(rolKontrol('musteri'));

/**
 * GET /api/musteri/cevredeki-esnaflar?lat=X&lon=Y
 * Müşteri konumuna 5km yarıçapta esnafları listele
 */
router.get('/cevredeki-esnaflar', async (req, res) => {
  try {
    const sema = Joi.object({
      lat: Joi.number().min(-90).max(90).required(),
      lon: Joi.number().min(-180).max(180).required(),
    });

    const { error, value } = sema.validate(req.query);
    if (error) return res.status(400).json({ hata: error.details[0].message });

    const result = await db.query(
      `SELECT e.id, e.dukkan_adi, e.kategori, e.adres,
              ST_Y(e.konum::geometry) as lat,
              ST_X(e.konum::geometry) as lon,
              COALESCE(puan_agg.ortalama_puan, 0) as ortalama_puan,
              ST_Distance(
                e.konum,
                ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
              ) as mesafe_metre
       FROM esnaflar e
       LEFT JOIN (
         SELECT p.degerlendirilen_id, AVG(p.puan) as ortalama_puan
         FROM puanlamalar p
         GROUP BY p.degerlendirilen_id
       ) puan_agg ON puan_agg.degerlendirilen_id = e.kullanici_id
       WHERE e.aktif = true
         AND ST_DWithin(
           e.konum,
           ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
           5000
         )
       ORDER BY mesafe_metre ASC`,
      [value.lon, value.lat]
    );

    const esnaflar = result.rows.map(e => ({
      ...e,
      ortalama_puan: parseFloat(e.ortalama_puan) || 0,
    }));

    res.json({ esnaflar });
  } catch (error) {
    console.error('Çevredeki esnaflar hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

/**
 * GET /api/musteri/aktif-cagri
 * Müşterinin aktif çağrısını getir
 */
router.get('/aktif-cagri', async (req, res) => {
  try {
    const result = await db.query(
      `SELECT c.*, e.dukkan_adi, e.kategori, e.adres as esnaf_adres,
              ST_Y(e.konum::geometry) as esnaf_lat,
              ST_X(e.konum::geometry) as esnaf_lon,
              ku.ad as kurye_ad, ku.soyad as kurye_soyad
       FROM cagrilar c
       JOIN esnaflar e ON e.id = c.esnaf_id
       LEFT JOIN kuryeler kr ON kr.id = c.kurye_id
       LEFT JOIN kullanicilar ku ON ku.id = kr.kullanici_id
       WHERE c.musteri_id = $1
         AND c.durum IN ('beklemede', 'atandi', 'teslim_alindi', 'teslimde')
       ORDER BY c.olusturulma_zamani DESC
       LIMIT 1`,
      [req.kullanici.id]
    );

    if (result.rows.length === 0) {
      return res.json({ cagri: null });
    }

    res.json({ cagri: result.rows[0] });
  } catch (error) {
    console.error('Aktif çağrı hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

/**
 * POST /api/musteri/puanla
 * Kurye puanlama
 */
router.post('/puanla', async (req, res) => {
  try {
    const sema = Joi.object({
      cagri_id: Joi.string().uuid().required(),
      puan: Joi.number().integer().min(1).max(5).required(),
      yorum: Joi.string().max(500).optional().allow(''),
    });

    const { error, value } = sema.validate(req.body);
    if (error) return res.status(400).json({ hata: error.details[0].message });

    // Çağrı kontrolü
    const cagriResult = await db.query(
      `SELECT c.kurye_id, kr.kullanici_id as kurye_kullanici_id
       FROM cagrilar c
       JOIN kuryeler kr ON kr.id = c.kurye_id
       WHERE c.id = $1 AND c.musteri_id = $2 AND c.durum = 'tamamlandi'`,
      [value.cagri_id, req.kullanici.id]
    );

    if (cagriResult.rows.length === 0) {
      return res.status(400).json({ hata: 'Puanlanacak çağrı bulunamadı' });
    }

    // Daha önce puanlanmış mı kontrol et
    const mevcutPuan = await db.query(
      'SELECT id FROM puanlamalar WHERE cagri_id = $1 AND degerlendiren_id = $2',
      [value.cagri_id, req.kullanici.id]
    );

    if (mevcutPuan.rows.length > 0) {
      return res.status(400).json({ hata: 'Bu çağrı zaten puanlanmış' });
    }

    const kurye = cagriResult.rows[0];

    // Puanlama ekle (trigger otomatik ortalama günceller)
    await db.query(
      `INSERT INTO puanlamalar (cagri_id, degerlendiren_id, degerlendirilen_id, puan, yorum)
       VALUES ($1, $2, $3, $4, $5)`,
      [value.cagri_id, req.kullanici.id, kurye.kurye_kullanici_id, value.puan, value.yorum || null]
    );

    res.json({ mesaj: 'Puanlama kaydedildi' });
  } catch (error) {
    console.error('Puanlama hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

module.exports = router;
