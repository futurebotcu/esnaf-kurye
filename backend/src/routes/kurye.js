const express = require('express');
const Joi = require('joi');
const db = require('../config/database');
const { authMiddleware, rolKontrol } = require('../middleware/auth');
const { enYakinKuryeleri, siraliKuryeBildirimGonder } = require('../services/kuryeBul');

const router = express.Router();

router.use(authMiddleware);
router.use(rolKontrol('kurye'));

/**
 * POST /api/kurye/profil
 * Kurye profili oluştur/güncelle
 */
router.post('/profil', async (req, res) => {
  try {
    const sema = Joi.object({
      arac_tipi: Joi.string().valid('motorsiklet', 'bisiklet', 'otomobil', 'yaya').required(),
    });

    const { error, value } = sema.validate(req.body);
    if (error) return res.status(400).json({ hata: error.details[0].message });

    const mevcut = await db.query(
      'SELECT id FROM kuryeler WHERE kullanici_id = $1',
      [req.kullanici.id]
    );

    let result;
    if (mevcut.rows.length > 0) {
      result = await db.query(
        'UPDATE kuryeler SET arac_tipi = $1 WHERE kullanici_id = $2 RETURNING *',
        [value.arac_tipi, req.kullanici.id]
      );
    } else {
      result = await db.query(
        'INSERT INTO kuryeler (kullanici_id, arac_tipi) VALUES ($1, $2) RETURNING *',
        [req.kullanici.id, value.arac_tipi]
      );
    }

    res.json({ mesaj: 'Profil kaydedildi', kurye: result.rows[0] });
  } catch (error) {
    console.error('Kurye profil hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

/**
 * PUT /api/kurye/konum
 * Kurye konumunu güncelle (GPS takibi)
 */
router.put('/konum', async (req, res) => {
  try {
    const sema = Joi.object({
      lat: Joi.number().min(-90).max(90).required(),
      lon: Joi.number().min(-180).max(180).required(),
    });

    const { error, value } = sema.validate(req.body);
    if (error) return res.status(400).json({ hata: error.details[0].message });

    await db.query(
      `UPDATE kuryeler SET
        konum = ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
        son_konum_zamani = NOW()
       WHERE kullanici_id = $3`,
      [value.lon, value.lat, req.kullanici.id]
    );

    res.json({ mesaj: 'Konum güncellendi' });
  } catch (error) {
    console.error('Konum güncelleme hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

/**
 * PUT /api/kurye/durum
 * Kurye durumunu değiştir (müsait/meşgul/çevrimdışı)
 */
router.put('/durum', async (req, res) => {
  try {
    const sema = Joi.object({
      durum: Joi.string().valid('musait', 'mesgul', 'cevrimdisi').required(),
    });

    const { error, value } = sema.validate(req.body);
    if (error) return res.status(400).json({ hata: error.details[0].message });

    await db.query(
      'UPDATE kuryeler SET durum = $1 WHERE kullanici_id = $2',
      [value.durum, req.kullanici.id]
    );

    res.json({ mesaj: `Durum "${value.durum}" olarak güncellendi` });
  } catch (error) {
    console.error('Durum güncelleme hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

/**
 * GET /api/kurye/aktif-cagrilar
 * Kuryenin görebileceği aktif çağrılar
 */
router.get('/aktif-cagrilar', async (req, res) => {
  try {
    const kuryeResult = await db.query(
      `SELECT id, ST_Y(konum::geometry) as lat, ST_X(konum::geometry) as lon
       FROM kuryeler WHERE kullanici_id = $1`,
      [req.kullanici.id]
    );

    if (kuryeResult.rows.length === 0) {
      return res.status(404).json({ hata: 'Kurye profili bulunamadı' });
    }

    const kurye = kuryeResult.rows[0];

    // Bu kuryeye gönderilmiş bekleyen bildirimleri getir
    const result = await db.query(
      `SELECT c.*, e.dukkan_adi, e.kategori, e.adres as esnaf_adres,
              ST_Y(e.konum::geometry) as esnaf_lat, ST_X(e.konum::geometry) as esnaf_lon,
              cb.sira, cb.id as bildirim_id
       FROM cagri_bildirimleri cb
       JOIN cagrilar c ON c.id = cb.cagri_id
       JOIN esnaflar e ON e.id = c.esnaf_id
       WHERE cb.kurye_id = $1
         AND cb.durum = 'gonderildi'
         AND c.durum = 'beklemede'
       ORDER BY cb.gonderim_zamani DESC`,
      [kurye.id]
    );

    res.json({ cagrilar: result.rows });
  } catch (error) {
    console.error('Aktif çağrı listeleme hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

/**
 * POST /api/kurye/cagri-kabul/:cagriId
 * Çağrıyı kabul et
 */
router.post('/cagri-kabul/:cagriId', async (req, res) => {
  try {
    const { cagriId } = req.params;

    const kuryeResult = await db.query(
      'SELECT id FROM kuryeler WHERE kullanici_id = $1',
      [req.kullanici.id]
    );
    const kuryeId = kuryeResult.rows[0].id;

    // Çağrıyı kontrol et
    const cagriCheck = await db.query(
      "SELECT id FROM cagrilar WHERE id = $1 AND durum = 'beklemede'",
      [cagriId]
    );
    if (cagriCheck.rows.length === 0) {
      return res.status(400).json({ hata: 'Bu çağrı artık müsait değil' });
    }

    // Çağrıyı ata
    await db.query(
      `UPDATE cagrilar SET
        kurye_id = $1, durum = 'atandi', atanma_zamani = NOW()
       WHERE id = $2`,
      [kuryeId, cagriId]
    );

    // Kurye durumunu meşgul yap
    await db.query(
      "UPDATE kuryeler SET durum = 'mesgul' WHERE id = $1",
      [kuryeId]
    );

    // Bildirim durumunu güncelle
    await db.query(
      `UPDATE cagri_bildirimleri SET durum = 'kabul', yanit_zamani = NOW()
       WHERE cagri_id = $1 AND kurye_id = $2`,
      [cagriId, kuryeId]
    );

    // Esnafa bildir
    const io = req.app.get('io');
    if (io) {
      const cagriDetay = await db.query(
        'SELECT esnaf_id FROM cagrilar WHERE id = $1',
        [cagriId]
      );
      io.to(`esnaf_${cagriDetay.rows[0].esnaf_id}`).emit('cagri_kabul_edildi', {
        cagri_id: cagriId,
        kurye_ad: req.kullanici.ad,
        kurye_soyad: req.kullanici.soyad,
      });
    }

    res.json({ mesaj: 'Çağrı kabul edildi' });
  } catch (error) {
    console.error('Çağrı kabul hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

/**
 * POST /api/kurye/cagri-reddet/:cagriId
 * Çağrıyı reddet, bir sonraki kuryeye gönder
 */
router.post('/cagri-reddet/:cagriId', async (req, res) => {
  try {
    const { cagriId } = req.params;

    const kuryeResult = await db.query(
      'SELECT id FROM kuryeler WHERE kullanici_id = $1',
      [req.kullanici.id]
    );
    const kuryeId = kuryeResult.rows[0].id;

    // Bildirim durumunu güncelle
    await db.query(
      `UPDATE cagri_bildirimleri SET durum = 'red', yanit_zamani = NOW()
       WHERE cagri_id = $1 AND kurye_id = $2`,
      [cagriId, kuryeId]
    );

    // Çağrı bilgisini al
    const cagriResult = await db.query(
      `SELECT c.*, ST_Y(c.baslangic_konum::geometry) as baslangic_lat,
              ST_X(c.baslangic_konum::geometry) as baslangic_lon
       FROM cagrilar c WHERE c.id = $1`,
      [cagriId]
    );
    const cagri = cagriResult.rows[0];

    // Sıradaki kuryeye gönder
    const { enYakinKuryeleri: yakinkuryeler } = require('../services/kuryeBul');
    const kuryeler = await enYakinKuryeleri(cagri.baslangic_lat, cagri.baslangic_lon);
    const io = req.app.get('io');
    await siraliKuryeBildirimGonder(cagriId, kuryeler, cagri.bildirim_sirasi + 1, io);

    res.json({ mesaj: 'Çağrı reddedildi, sıradaki kuryeye gönderiliyor' });
  } catch (error) {
    console.error('Çağrı reddetme hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

/**
 * PUT /api/kurye/teslim-aldim/:cagriId
 * Paketi teslim aldım
 */
router.put('/teslim-aldim/:cagriId', async (req, res) => {
  try {
    await db.query(
      `UPDATE cagrilar SET durum = 'teslim_alindi', teslim_alma_zamani = NOW()
       WHERE id = $1`,
      [req.params.cagriId]
    );

    const io = req.app.get('io');
    if (io) {
      const cagri = await db.query(
        'SELECT esnaf_id FROM cagrilar WHERE id = $1',
        [req.params.cagriId]
      );
      io.to(`esnaf_${cagri.rows[0].esnaf_id}`).emit('teslim_alindi', {
        cagri_id: req.params.cagriId,
      });
    }

    res.json({ mesaj: 'Teslim alındı olarak işaretlendi' });
  } catch (error) {
    console.error('Teslim alma hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

/**
 * PUT /api/kurye/teslim-ettim/:cagriId
 * Paketi teslim ettim
 */
router.put('/teslim-ettim/:cagriId', async (req, res) => {
  try {
    const sema = Joi.object({
      odeme_yontemi: Joi.string().valid('nakit', 'sanal_pos').required(),
    });

    const { error, value } = sema.validate(req.body);
    if (error) return res.status(400).json({ hata: error.details[0].message });

    // Çağrıyı tamamla
    await db.query(
      `UPDATE cagrilar SET durum = 'tamamlandi', teslim_etme_zamani = NOW()
       WHERE id = $1`,
      [req.params.cagriId]
    );

    // Kuryeyi müsait yap ve teslimat sayısını artır
    const kuryeResult = await db.query(
      'SELECT id FROM kuryeler WHERE kullanici_id = $1',
      [req.kullanici.id]
    );
    await db.query(
      `UPDATE kuryeler SET durum = 'musait', toplam_teslimat = toplam_teslimat + 1
       WHERE id = $1`,
      [kuryeResult.rows[0].id]
    );

    // Ödeme kaydı oluştur
    const cagri = await db.query(
      'SELECT toplam_ucret, esnaf_id, musteri_id FROM cagrilar WHERE id = $1',
      [req.params.cagriId]
    );

    await db.query(
      `INSERT INTO odemeler (cagri_id, tutar, yontem, durum, dogrulama_zamani)
       VALUES ($1, $2, $3, 'dogrulandi', NOW())`,
      [req.params.cagriId, cagri.rows[0].toplam_ucret, value.odeme_yontemi]
    );

    // Esnafa ve müşteriye bildir
    const io = req.app.get('io');
    if (io) {
      const teslimData = {
        cagri_id: req.params.cagriId,
        odeme_yontemi: value.odeme_yontemi,
      };
      io.to(`esnaf_${cagri.rows[0].esnaf_id}`).emit('teslim_tamamlandi', teslimData);

      if (cagri.rows[0].musteri_id) {
        io.to(`musteri_${cagri.rows[0].musteri_id}`).emit('teslim_tamamlandi', teslimData);
      }
    }

    res.json({ mesaj: 'Teslimat tamamlandı' });
  } catch (error) {
    console.error('Teslim etme hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

module.exports = router;
